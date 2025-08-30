defmodule EliasServer.Manager.UFM.FederationDaemon do
  @moduledoc """
  UFM Federation Sub-Daemon - Core distributed coordination functionality
  
  Responsibilities:
  - Network topology management
  - Node discovery and heartbeat monitoring  
  - P2P coordination between ELIAS nodes
  - Load balancing and request routing
  - Hot-reload from UFM_Federation.md spec
  """
  
  use GenServer
  require Logger
  
  alias EliasServer.Manager.SupervisorHelper
  
  defstruct [
    :rules,
    :last_updated,
    :checksum,
    :network_topology,
    :node_metrics,
    :heartbeat_timer,
    :discovery_timer
  ]
  
  @spec_file Path.join([Application.app_dir(:elias_server), "priv", "manager_specs", "UFM_Federation.md"])
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def reload_rules do
    GenServer.cast(__MODULE__, :reload_rules)
  end
  
  def get_network_topology do
    GenServer.call(__MODULE__, :get_network_topology)
  end
  
  def get_node_status(node_name) do
    GenServer.call(__MODULE__, {:get_node_status, node_name})
  end
  
  def route_request(request_type, requirements) do
    GenServer.call(__MODULE__, {:route_request, request_type, requirements})
  end
  
  def get_federation_metrics do
    GenServer.call(__MODULE__, :get_federation_metrics)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("🌐 UFM.FederationDaemon: Starting core federation daemon")
    
    # Register in sub-daemon registry
    SupervisorHelper.register_process(:ufm_subdaemons, :federation_daemon, self())
    
    # Load rules from hierarchical spec
    new_state = load_federation_rules(state)
    
    # Initialize network topology
    topology = initialize_network_topology()
    
    # Start periodic federation tasks
    heartbeat_timer = schedule_heartbeat(new_state.rules)
    discovery_timer = schedule_node_discovery(new_state.rules)
    
    final_state = %{new_state |
      network_topology: topology,
      node_metrics: %{},
      heartbeat_timer: heartbeat_timer,
      discovery_timer: discovery_timer
    }
    
    Logger.info("✅ UFM.FederationDaemon: Core federation ready - monitoring #{map_size(topology)} nodes")
    {:ok, final_state}
  end
  
  @impl true
  def handle_call(:get_network_topology, _from, state) do
    {:reply, state.network_topology, state}
  end
  
  def handle_call({:get_node_status, node_name}, _from, state) do
    status = Map.get(state.network_topology, node_name, :unknown)
    {:reply, status, state}
  end
  
  def handle_call({:route_request, request_type, requirements}, _from, state) do
    optimal_node = select_optimal_node(request_type, requirements, state)
    {:reply, optimal_node, state}
  end
  
  def handle_call(:get_federation_metrics, _from, state) do
    metrics = %{
      total_nodes: map_size(state.network_topology),
      healthy_nodes: count_healthy_nodes(state.network_topology),
      last_topology_update: state.last_updated,
      network_partitions: detect_partitions(state.network_topology)
    }
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_cast(:reload_rules, state) do
    Logger.info("🔄 UFM.FederationDaemon: Hot-reloading federation rules")
    new_state = load_federation_rules(state)
    updated_state = apply_federation_rule_changes(state, new_state)
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info(:heartbeat_check, state) do
    # Core federation responsibility: maintain network topology
    updated_topology = perform_heartbeat_checks(state.network_topology, state.rules)
    
    # Detect and broadcast topology changes
    if topology_changed?(state.network_topology, updated_topology) do
      Logger.info("🔄 UFM.FederationDaemon: Network topology changed")
      broadcast_topology_update(updated_topology)
      notify_monitoring_daemon(:topology_change, updated_topology)
    end
    
    # Schedule next heartbeat
    heartbeat_timer = schedule_heartbeat(state.rules)
    
    new_state = %{state |
      network_topology: updated_topology,
      heartbeat_timer: heartbeat_timer,
      last_updated: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end
  
  def handle_info(:node_discovery, state) do
    # Scan for new federation nodes
    discovered_nodes = discover_new_nodes(state.rules)
    
    updated_topology = integrate_discovered_nodes(state.network_topology, discovered_nodes)
    
    if length(discovered_nodes) > 0 do
      Logger.info("🆕 UFM.FederationDaemon: Discovered #{length(discovered_nodes)} new nodes")
      broadcast_topology_update(updated_topology)
      notify_monitoring_daemon(:nodes_discovered, discovered_nodes)
    end
    
    # Schedule next discovery scan
    discovery_timer = schedule_node_discovery(state.rules)
    
    new_state = %{state |
      network_topology: updated_topology,
      discovery_timer: discovery_timer
    }
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp load_federation_rules(state) do
    case File.read(@spec_file) do
      {:ok, content} ->
        {rules, checksum} = parse_federation_md_rules(content)
        %{state |
          rules: rules,
          last_updated: DateTime.utc_now(),
          checksum: checksum
        }
      {:error, reason} ->
        Logger.error("❌ UFM.FederationDaemon: Could not load UFM_Federation.md: #{reason}")
        # Use default federation rules
        %{state | 
          rules: default_federation_rules(),
          last_updated: DateTime.utc_now()
        }
    end
  end
  
  defp parse_federation_md_rules(content) do
    # Extract YAML frontmatter specific to federation
    [frontmatter_str | _] = String.split(content, "---", parts: 3, trim: true)
    
    frontmatter = YamlElixir.read_from_string(frontmatter_str) || %{}
    checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    
    rules = %{
      heartbeat_interval: get_in(frontmatter, ["federation", "heartbeat_interval"]) || 15000,
      node_timeout: get_in(frontmatter, ["federation", "node_timeout"]) || 30000,
      reconnect_interval: get_in(frontmatter, ["federation", "reconnect_interval"]) || 30000,
      max_reconnect_attempts: get_in(frontmatter, ["federation", "max_reconnect_attempts"]) || 10,
      node_types: get_in(frontmatter, ["federation", "node_types"]) || %{},
      require_tls: get_in(frontmatter, ["federation", "require_tls"]) || true,
      auto_discovery: get_in(frontmatter, ["federation", "auto_discovery"]) || true
    }
    
    {rules, checksum}
  end
  
  defp default_federation_rules do
    %{
      heartbeat_interval: 15000,
      node_timeout: 30000,
      reconnect_interval: 30000,
      max_reconnect_attempts: 10,
      node_types: %{"gracey" => "client", "griffith" => "full_node"},
      require_tls: false,  # Set to false for development
      auto_discovery: true
    }
  end
  
  defp initialize_network_topology do
    # Start with current node and known cluster nodes
    cluster_nodes = [Node.self() | Node.list()]
    
    cluster_nodes
    |> Enum.map(fn node ->
      node_type = determine_node_type(node)
      capabilities = get_node_capabilities(node_type)
      
      {node, %{
        type: node_type,
        capabilities: capabilities,
        status: :healthy,
        last_heartbeat: DateTime.utc_now(),
        load_metrics: %{concurrent_requests: 0}
      }}
    end)
    |> Map.new()
  end
  
  defp determine_node_type(node) do
    node_string = Atom.to_string(node)
    cond do
      String.contains?(node_string, "gracey") -> :client
      String.contains?(node_string, "griffith") -> :full_node  
      String.contains?(node_string, "apemacs_client") -> :client
      String.contains?(node_string, "elias_server") -> :full_node
      true -> :unknown
    end
  end
  
  defp get_node_capabilities(:client), do: ["apemacs", "light_requests", "rule_distribution"]
  defp get_node_capabilities(:full_node), do: ["all_requests", "blockchain_mining", "ml_processing", "heavy_compute"]
  defp get_node_capabilities(_), do: []
  
  defp schedule_heartbeat(rules) do
    interval = Map.get(rules, :heartbeat_interval, 15000)
    Process.send_after(self(), :heartbeat_check, interval)
  end
  
  defp schedule_node_discovery(rules) do
    # Discovery runs less frequently than heartbeat
    interval = Map.get(rules, :heartbeat_interval, 15000) * 4
    Process.send_after(self(), :node_discovery, interval)
  end
  
  defp perform_heartbeat_checks(topology, rules) do
    topology
    |> Enum.map(fn {node, node_info} ->
      status = if node == Node.self() do
        :healthy  # Always consider self healthy
      else
        case :net_adm.ping(node) do
          :pong -> :healthy
          :pang -> :unhealthy
        end
      end
      
      updated_info = %{node_info |
        status: status,
        last_heartbeat: if(status == :healthy, do: DateTime.utc_now(), else: node_info.last_heartbeat)
      }
      
      {node, updated_info}
    end)
    |> Map.new()
  end
  
  defp count_healthy_nodes(topology) do
    topology
    |> Enum.count(fn {_node, info} -> info.status == :healthy end)
  end
  
  defp detect_partitions(topology) do
    # Simple partition detection - could be enhanced
    unhealthy_count = map_size(topology) - count_healthy_nodes(topology)
    if unhealthy_count > 0, do: 1, else: 0
  end
  
  defp topology_changed?(old_topology, new_topology) do
    old_statuses = old_topology |> Enum.map(fn {node, info} -> {node, info.status} end) |> Map.new()
    new_statuses = new_topology |> Enum.map(fn {node, info} -> {node, info.status} end) |> Map.new()
    
    old_statuses != new_statuses
  end
  
  defp discover_new_nodes(rules) do
    if Map.get(rules, :auto_discovery, true) do
      # Use EPMD or libcluster for discovery
      current_nodes = MapSet.new([Node.self() | Node.list()])
      
      # Placeholder for actual discovery mechanism
      []
    else
      []
    end
  end
  
  defp integrate_discovered_nodes(topology, []), do: topology
  defp integrate_discovered_nodes(topology, discovered_nodes) do
    new_entries = discovered_nodes
    |> Enum.map(fn node ->
      node_type = determine_node_type(node)
      capabilities = get_node_capabilities(node_type)
      
      {node, %{
        type: node_type,
        capabilities: capabilities,
        status: :healthy,
        last_heartbeat: DateTime.utc_now(),
        load_metrics: %{concurrent_requests: 0}
      }}
    end)
    |> Map.new()
    
    Map.merge(topology, new_entries)
  end
  
  defp select_optimal_node(request_type, requirements, state) do
    eligible_nodes = state.network_topology
    |> Enum.filter(fn {_node, info} ->
      info.status == :healthy and
      has_required_capabilities?(info.capabilities, requirements)
    end)
    
    case eligible_nodes do
      [] -> {:error, :no_eligible_nodes}
      nodes ->
        # Load balancing - select node with lowest concurrent requests
        {optimal_node, _info} = Enum.min_by(nodes, fn {_node, info} ->
          info.load_metrics.concurrent_requests
        end)
        {:ok, optimal_node}
    end
  end
  
  defp has_required_capabilities?(node_capabilities, requirements) do
    required_caps = Map.get(requirements, :capabilities, [])
    MapSet.subset?(MapSet.new(required_caps), MapSet.new(node_capabilities))
  end
  
  defp apply_federation_rule_changes(old_state, new_state) do
    # Handle configuration changes that affect timers
    cond do
      old_state.rules[:heartbeat_interval] != new_state.rules[:heartbeat_interval] ->
        # Reschedule heartbeat with new interval
        if old_state.heartbeat_timer, do: Process.cancel_timer(old_state.heartbeat_timer)
        heartbeat_timer = schedule_heartbeat(new_state.rules)
        %{new_state | heartbeat_timer: heartbeat_timer}
      
      true ->
        new_state
    end
  end
  
  defp broadcast_topology_update(topology) do
    # Broadcast to other UFM sub-daemons and external systems
    Logger.debug("📡 UFM.FederationDaemon: Broadcasting topology update")
    
    # Notify other managers via UCM
    try do
      EliasServer.Manager.UCM.broadcast_system_event(:topology_update, %{
        source: :ufm_federation,
        topology: topology,
        timestamp: DateTime.utc_now()
      })
    rescue
      _ -> Logger.debug("UCM not available for broadcast")
    end
  end
  
  defp notify_monitoring_daemon(event_type, data) do
    # Send notification to monitoring sub-daemon
    try do
      EliasServer.Manager.UFM.MonitoringDaemon.record_federation_event(event_type, data)
    rescue
      _ -> Logger.debug("Monitoring daemon not available")
    end
  end
end