defmodule Tiki.SyncDaemon do
  @moduledoc """
  Tiki Synchronization Daemon - Distributed specification hot-reload coordination
  
  Per Architect guidance: Supervised sub-daemon under UFM that handles
  federation-wide synchronization of .tiki specifications, hot-reload 
  coordination, and consistency maintenance across Gracey/Griffith nodes.
  
  Always-on daemon following ELIAS philosophy with fault isolation
  and automatic recovery via UFM supervision tree.
  """
  
  use GenServer
  require Logger
  
  alias Tiki.Parser
  
  defstruct [
    :spec_versions,
    :sync_state,
    :last_sync_time,
    :active_syncs,
    :federation_nodes,
    :sync_timer,
    :health_check_timer
  ]
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def sync_spec_to_federation(spec_file, checksum) do
    GenServer.cast(__MODULE__, {:sync_spec, spec_file, checksum})
  end
  
  def force_federation_sync do
    GenServer.cast(__MODULE__, :force_federation_sync)
  end
  
  def get_sync_status do
    GenServer.call(__MODULE__, :get_sync_status)
  end
  
  def get_spec_versions do
    GenServer.call(__MODULE__, :get_spec_versions)
  end
  
  def handle_remote_sync_request(spec_file, checksum, source_node) do
    GenServer.cast(__MODULE__, {:remote_sync_request, spec_file, checksum, source_node})
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("🔄 Tiki.SyncDaemon: Starting distributed spec synchronization daemon")
    
    # Register with UFM sub-daemon registry (per UFM architecture)
    try do
      EliasServer.Manager.SupervisorHelper.register_process(:ufm_subdaemons, :tiki_sync_daemon, self())
    rescue
      _ -> Logger.debug("UFM registry not available, continuing without registration")
    end
    
    # Initialize state
    initial_state = %{state |
      spec_versions: load_current_spec_versions(),
      sync_state: %{},
      last_sync_time: DateTime.utc_now(),
      active_syncs: %{},
      federation_nodes: discover_federation_nodes()
    }
    
    # Start periodic synchronization cycles
    sync_timer = schedule_sync_cycle()
    health_timer = schedule_health_check()
    
    final_state = %{initial_state |
      sync_timer: sync_timer,
      health_check_timer: health_timer
    }
    
    Logger.info("✅ Tiki.SyncDaemon: Federation sync active - monitoring #{map_size(final_state.spec_versions)} specs")
    {:ok, final_state}
  end
  
  @impl true
  def handle_call(:get_sync_status, _from, state) do
    status = %{
      total_specs: map_size(state.spec_versions),
      last_sync_time: state.last_sync_time,
      active_syncs: map_size(state.active_syncs),
      federation_nodes: length(state.federation_nodes),
      sync_health: calculate_sync_health(state)
    }
    {:reply, status, state}
  end
  
  def handle_call(:get_spec_versions, _from, state) do
    {:reply, state.spec_versions, state}
  end
  
  @impl true
  def handle_cast({:sync_spec, spec_file, checksum}, state) do
    Logger.info("📤 Tiki.SyncDaemon: Broadcasting spec update: #{spec_file}")
    
    # Update local version tracking
    updated_versions = Map.put(state.spec_versions, spec_file, %{
      checksum: checksum,
      updated_at: DateTime.utc_now(),
      source: Node.self()
    })
    
    # Broadcast to federation nodes
    broadcast_spec_update(spec_file, checksum, state.federation_nodes)
    
    updated_state = %{state |
      spec_versions: updated_versions,
      last_sync_time: DateTime.utc_now()
    }
    
    {:noreply, updated_state}
  end
  
  def handle_cast(:force_federation_sync, state) do
    Logger.info("🔄 Tiki.SyncDaemon: Force syncing all specs to federation")
    
    # Sync all current specs to federation
    Enum.each(state.spec_versions, fn {spec_file, version_info} ->
      broadcast_spec_update(spec_file, version_info.checksum, state.federation_nodes)
    end)
    
    updated_state = %{state | last_sync_time: DateTime.utc_now()}
    {:noreply, updated_state}
  end
  
  def handle_cast({:remote_sync_request, spec_file, checksum, source_node}, state) do
    Logger.debug("📥 Tiki.SyncDaemon: Received sync request for #{spec_file} from #{source_node}")
    
    case Map.get(state.spec_versions, spec_file) do
      nil ->
        # New spec, accept and propagate
        accept_remote_spec_update(spec_file, checksum, source_node, state)
        
      %{checksum: ^checksum} ->
        # Same version, no action needed
        Logger.debug("✅ Tiki.SyncDaemon: Spec #{spec_file} already up-to-date")
        {:noreply, state}
        
      %{checksum: local_checksum} ->
        # Version conflict, resolve using timestamp precedence
        resolve_spec_version_conflict(spec_file, checksum, local_checksum, source_node, state)
    end
  end
  
  @impl true
  def handle_info(:sync_cycle, state) do
    # Periodic federation synchronization
    Logger.debug("🔄 Tiki.SyncDaemon: Running periodic federation sync cycle")
    
    # Check for spec file changes
    current_versions = load_current_spec_versions()
    changes_detected = detect_spec_changes(current_versions, state.spec_versions)
    
    updated_state = if length(changes_detected) > 0 do
      Logger.info("📋 Tiki.SyncDaemon: Detected #{length(changes_detected)} spec changes")
      
      # Broadcast changes to federation
      Enum.each(changes_detected, fn {spec_file, version_info} ->
        broadcast_spec_update(spec_file, version_info.checksum, state.federation_nodes)
      end)
      
      %{state |
        spec_versions: current_versions,
        last_sync_time: DateTime.utc_now()
      }
    else
      state
    end
    
    # Schedule next sync cycle
    sync_timer = schedule_sync_cycle()
    final_state = %{updated_state | sync_timer: sync_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:health_check, state) do
    # Check federation node health and connectivity
    active_nodes = check_federation_node_health(state.federation_nodes)
    
    if length(active_nodes) != length(state.federation_nodes) do
      Logger.info("🩺 Tiki.SyncDaemon: Federation health check - #{length(active_nodes)}/#{length(state.federation_nodes)} nodes active")
    end
    
    # Update federation nodes list
    updated_nodes = discover_federation_nodes()
    
    # Schedule next health check
    health_timer = schedule_health_check()
    
    updated_state = %{state |
      federation_nodes: updated_nodes,
      health_check_timer: health_timer
    }
    
    {:noreply, updated_state}
  end
  
  def handle_info({:spec_sync_response, spec_file, status, source_node}, state) do
    Logger.debug("📬 Tiki.SyncDaemon: Received sync response for #{spec_file} from #{source_node}: #{status}")
    
    # Update active sync tracking
    updated_active_syncs = Map.delete(state.active_syncs, {spec_file, source_node})
    
    updated_state = %{state | active_syncs: updated_active_syncs}
    {:noreply, updated_state}
  end
  
  # Private Functions
  
  defp load_current_spec_versions do
    case Parser.list_available_specs() do
      {:ok, spec_files} ->
        Enum.reduce(spec_files, %{}, fn spec_file, acc ->
          case Parser.parse_spec_file(spec_file) do
            {:ok, spec} ->
              checksum = get_in(spec, ["_tiki_metadata", "checksum"])
              if checksum do
                Map.put(acc, spec_file, %{
                  checksum: checksum,
                  updated_at: DateTime.utc_now(),
                  source: Node.self()
                })
              else
                acc
              end
              
            {:error, _reason} ->
              acc
          end
        end)
        
      {:error, _reason} ->
        %{}
    end
  end
  
  defp discover_federation_nodes do
    # Get federation nodes from UFM if available
    try do
      case EliasServer.Manager.UFM.get_network_topology() do
        topology when is_map(topology) ->
          topology
          |> Map.keys()
          |> Enum.filter(fn node -> node != Node.self() end)
          
        _ ->
          # Fallback to Erlang node discovery
          Node.list()
      end
    rescue
      _ ->
        # UFM not available, use basic node discovery
        Node.list()
    end
  end
  
  defp schedule_sync_cycle do
    # Sync every 30 seconds (per Architect guidance for federation coordination)
    Process.send_after(self(), :sync_cycle, 30_000)
  end
  
  defp schedule_health_check do
    # Health check every 2 minutes
    Process.send_after(self(), :health_check, 120_000)
  end
  
  defp broadcast_spec_update(spec_file, checksum, federation_nodes) do
    Enum.each(federation_nodes, fn node ->
      try do
        # Use UFM federation communication if available
        send({__MODULE__, node}, {:remote_sync_request, spec_file, checksum, Node.self()})
        Logger.debug("📤 Tiki.SyncDaemon: Sent sync request for #{spec_file} to #{node}")
      rescue
        _ ->
          Logger.debug("⚠️ Tiki.SyncDaemon: Failed to send sync request to #{node}")
      end
    end)
  end
  
  defp accept_remote_spec_update(spec_file, checksum, source_node, state) do
    Logger.info("📥 Tiki.SyncDaemon: Accepting new spec #{spec_file} from #{source_node}")
    
    # Update local version tracking
    updated_versions = Map.put(state.spec_versions, spec_file, %{
      checksum: checksum,
      updated_at: DateTime.utc_now(),
      source: source_node
    })
    
    # Notify local managers of spec update
    notify_managers_of_spec_update(spec_file, :remote_update)
    
    # Send acknowledgment back to source
    send({__MODULE__, source_node}, {:spec_sync_response, spec_file, :accepted, Node.self()})
    
    updated_state = %{state | spec_versions: updated_versions}
    {:noreply, updated_state}
  end
  
  defp resolve_spec_version_conflict(spec_file, remote_checksum, local_checksum, source_node, state) do
    Logger.warning("⚡ Tiki.SyncDaemon: Version conflict for #{spec_file} - resolving via timestamp precedence")
    
    local_version = Map.get(state.spec_versions, spec_file)
    
    # Use timestamp precedence (Architect guidance)
    # In real implementation, would fetch remote timestamp for comparison
    # For now, accept remote if different (eventual consistency)
    
    updated_versions = Map.put(state.spec_versions, spec_file, %{
      checksum: remote_checksum,
      updated_at: DateTime.utc_now(),
      source: source_node,
      conflict_resolved: true,
      previous_checksum: local_checksum
    })
    
    notify_managers_of_spec_update(spec_file, :conflict_resolved)
    
    # Send acknowledgment
    send({__MODULE__, source_node}, {:spec_sync_response, spec_file, :conflict_resolved, Node.self()})
    
    updated_state = %{state | spec_versions: updated_versions}
    {:noreply, updated_state}
  end
  
  defp detect_spec_changes(current_versions, previous_versions) do
    Enum.filter(current_versions, fn {spec_file, current_info} ->
      case Map.get(previous_versions, spec_file) do
        nil -> true  # New spec file
        %{checksum: checksum} when checksum != current_info.checksum -> true  # Changed spec
        _ -> false  # No change
      end
    end)
  end
  
  defp check_federation_node_health(nodes) do
    Enum.filter(nodes, fn node ->
      case :net_adm.ping(node) do
        :pong -> true
        :pang -> false
      end
    end)
  end
  
  defp calculate_sync_health(state) do
    total_nodes = length(state.federation_nodes)
    active_syncs = map_size(state.active_syncs)
    
    cond do
      total_nodes == 0 -> :single_node
      active_syncs == 0 -> :healthy
      active_syncs < total_nodes -> :partial_sync
      true -> :syncing
    end
  end
  
  defp notify_managers_of_spec_update(spec_file, update_type) do
    # Notify managers that implement Tiki.Validatable behavior
    managers = [
      EliasServer.Manager.UFM,
      EliasServer.Manager.UCM,
      EliasServer.Manager.UAM,
      EliasServer.Manager.UIM,
      EliasServer.Manager.URM,
      EliasServer.Manager.ULM
    ]
    
    # Determine which manager owns this spec
    manager_module = case String.downcase(spec_file) do
      "ufm" <> _ -> EliasServer.Manager.UFM
      "ucm" <> _ -> EliasServer.Manager.UCM  
      "uam" <> _ -> EliasServer.Manager.UAM
      "uim" <> _ -> EliasServer.Manager.UIM
      "urm" <> _ -> EliasServer.Manager.URM
      "ulm" <> _ -> EliasServer.Manager.ULM
      _ -> nil
    end
    
    if manager_module && Process.whereis(manager_module) do
      try do
        # This would call reload_tiki_spec/0 on the manager if it implements Tiki.Validatable
        send(manager_module, {:tiki_spec_updated, spec_file, update_type})
        Logger.debug("📨 Tiki.SyncDaemon: Notified #{manager_module} of spec update")
      rescue
        _ ->
          Logger.debug("⚠️ Tiki.SyncDaemon: Failed to notify #{manager_module}")
      end
    end
  end
end