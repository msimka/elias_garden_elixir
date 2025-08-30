defmodule Elias.RuleDistributor do
  @moduledoc """
  Rule Distribution System for APEMACS.md updates
  
  Manages distribution of APEMACS.md rule updates to all connected ApeMacs clients
  via the P2P network. Ensures all clients stay synchronized with the latest rules.
  """
  
  use GenServer
  require Logger

  @doc """
  Start the rule distributor service
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Distribute a new APEMACS.md update to all clients
  """
  def distribute_apemacs_update(update_content, version \\ nil) do
    GenServer.cast(__MODULE__, {:distribute_update, update_content, version})
  end

  @doc """
  Register an ApeMacs client for rule updates
  """
  def register_client(client_node, client_info \\ %{}) do
    GenServer.cast(__MODULE__, {:register_client, client_node, client_info})
  end

  @doc """
  Unregister an ApeMacs client
  """
  def unregister_client(client_node) do
    GenServer.cast(__MODULE__, {:unregister_client, client_node})
  end

  @doc """
  Get current client registry status
  """
  def get_client_status do
    GenServer.call(__MODULE__, :get_client_status)
  end

  @doc """
  Force sync APEMACS.md to specific client
  """
  def sync_to_client(client_node) do
    GenServer.cast(__MODULE__, {:sync_to_client, client_node})
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📡 Rule Distributor starting for APEMACS.md updates...")
    
    # Monitor node connections for automatic client registration
    :net_kernel.monitor_nodes(true)
    
    state = %{
      registered_clients: %{},
      current_apemacs_version: load_current_version(),
      distribution_history: [],
      failed_distributions: %{}
    }
    
    # Auto-register existing connected nodes
    register_existing_nodes(state)
    
    Logger.info("✅ Rule Distributor initialized")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_client_status, _from, state) do
    status = %{
      registered_clients: map_size(state.registered_clients),
      current_version: state.current_apemacs_version,
      distribution_history_count: length(state.distribution_history),
      failed_distributions: map_size(state.failed_distributions),
      clients: Map.keys(state.registered_clients)
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:distribute_update, update_content, version}, state) do
    new_version = version || generate_version()
    
    Logger.info("📡 Distributing APEMACS.md update v#{new_version} to #{map_size(state.registered_clients)} clients")
    
    # Create update package
    update_package = %{
      version: new_version,
      content: update_content,
      timestamp: DateTime.utc_now(),
      source_node: node(),
      checksum: calculate_checksum(update_content)
    }
    
    # Distribute to all registered clients
    {successful, failed} = distribute_to_clients(state.registered_clients, update_package)
    
    # Record distribution history
    distribution_record = %{
      version: new_version,
      timestamp: DateTime.utc_now(),
      successful_clients: successful,
      failed_clients: failed,
      total_clients: map_size(state.registered_clients)
    }
    
    # Log to APE HARMONY blockchain
    Elias.ApeHarmony.record_event(:apemacs_update_distributed, %{
      version: new_version,
      clients_count: map_size(state.registered_clients),
      successful_count: length(successful),
      failed_count: length(failed)
    })
    
    new_state = %{state |
      current_apemacs_version: new_version,
      distribution_history: [distribution_record | state.distribution_history],
      failed_distributions: update_failed_distributions(state.failed_distributions, failed)
    }
    
    Logger.info("✅ APEMACS.md v#{new_version} distributed: #{length(successful)} success, #{length(failed)} failed")
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:register_client, client_node, client_info}, state) do
    Logger.info("📱 Registering ApeMacs client: #{client_node}")
    
    client_record = %{
      node: client_node,
      info: client_info,
      registered_at: DateTime.utc_now(),
      last_sync: nil,
      sync_failures: 0
    }
    
    new_clients = Map.put(state.registered_clients, client_node, client_record)
    
    # Send current APEMACS.md version to new client
    if state.current_apemacs_version do
      spawn(fn -> sync_current_version_to_client(client_node, state.current_apemacs_version) end)
    end
    
    # Log to blockchain
    Elias.ApeHarmony.record_event(:apemacs_client_registered, %{
      client_node: client_node,
      client_info: client_info
    })
    
    {:noreply, %{state | registered_clients: new_clients}}
  end

  @impl true
  def handle_cast({:unregister_client, client_node}, state) do
    Logger.info("📱 Unregistering ApeMacs client: #{client_node}")
    
    new_clients = Map.delete(state.registered_clients, client_node)
    
    {:noreply, %{state | registered_clients: new_clients}}
  end

  @impl true
  def handle_cast({:sync_to_client, client_node}, state) do
    case Map.get(state.registered_clients, client_node) do
      nil ->
        Logger.warning("⚠️ Cannot sync to unregistered client: #{client_node}")
        {:noreply, state}
        
      _client_record ->
        Logger.info("🔄 Force syncing APEMACS.md to #{client_node}")
        
        if state.current_apemacs_version do
          spawn(fn -> sync_current_version_to_client(client_node, state.current_apemacs_version) end)
        end
        
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("🔗 Node connected, checking for ApeMacs: #{node}")
    
    # Check if this node runs ApeMacs and auto-register
    spawn(fn -> maybe_register_apemacs_node(node) end)
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("💔 Node disconnected: #{node}")
    
    # Remove from registered clients if present
    new_clients = Map.delete(state.registered_clients, node)
    
    {:noreply, %{state | registered_clients: new_clients}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled message in RuleDistributor: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp load_current_version do
    # Load current APEMACS.md version from storage or generate initial
    apemacs_file = Path.join(:code.priv_dir(:elias), "APEMACS.md")
    
    case File.read(apemacs_file) do
      {:ok, content} ->
        # Extract version from content or generate based on modification time
        extract_version_from_content(content) || generate_version()
      {:error, _} ->
        nil
    end
  end

  defp extract_version_from_content(content) do
    # Look for version marker in APEMACS.md
    case Regex.run(~r/<!-- Version: ([\d\.]+) -->/, content) do
      [_, version] -> version
      _ -> nil
    end
  end

  defp generate_version do
    now = DateTime.utc_now()
    "#{now.year}.#{now.month}.#{now.day}.#{now.hour}#{now.minute}"
  end

  defp calculate_checksum(content) when is_binary(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp distribute_to_clients(clients, update_package) do
    clients
    |> Map.keys()
    |> Enum.reduce({[], []}, fn client_node, {successful, failed} ->
      case send_update_to_client(client_node, update_package) do
        :ok -> {[client_node | successful], failed}
        {:error, _reason} -> {successful, [client_node | failed]}
      end
    end)
  end

  defp send_update_to_client(client_node, update_package) do
    try do
      case :rpc.call(client_node, Elias.ApeMacs, :receive_apemacs_update, [update_package]) do
        {:ok, _} -> 
          Logger.debug("✅ APEMACS.md update sent to #{client_node}")
          :ok
        {:error, reason} -> 
          Logger.warning("⚠️ Failed to send update to #{client_node}: #{inspect(reason)}")
          {:error, reason}
        {:badrpc, reason} -> 
          Logger.error("❌ RPC failed to #{client_node}: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("❌ Exception sending update to #{client_node}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp sync_current_version_to_client(client_node, version) do
    # Load current APEMACS.md content and send to client
    apemacs_file = Path.join(:code.priv_dir(:elias), "APEMACS.md")
    
    case File.read(apemacs_file) do
      {:ok, content} ->
        update_package = %{
          version: version,
          content: content,
          timestamp: DateTime.utc_now(),
          source_node: node(),
          checksum: calculate_checksum(content),
          sync_type: :initial_sync
        }
        
        send_update_to_client(client_node, update_package)
        
      {:error, reason} ->
        Logger.error("❌ Failed to read APEMACS.md for sync: #{inspect(reason)}")
    end
  end

  defp maybe_register_apemacs_node(node) do
    # Check if the node has ApeMacs running
    case :rpc.call(node, Process, :whereis, [Elias.ApeMacs]) do
      pid when is_pid(pid) ->
        Logger.info("🎯 ApeMacs detected on #{node}, auto-registering")
        register_client(node, %{auto_registered: true})
      _ ->
        Logger.debug("🔍 No ApeMacs found on #{node}")
    end
  end

  defp register_existing_nodes(state) do
    # Register any currently connected nodes that have ApeMacs
    Node.list()
    |> Enum.each(&maybe_register_apemacs_node/1)
    
    state
  end

  defp update_failed_distributions(failed_dist, new_failed) do
    # Track repeated failures for each client
    Enum.reduce(new_failed, failed_dist, fn client, acc ->
      current_failures = Map.get(acc, client, 0)
      Map.put(acc, client, current_failures + 1)
    end)
  end
end