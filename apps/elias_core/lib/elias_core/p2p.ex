defmodule EliasCore.P2P do
  @moduledoc """
  P2P communication layer for ELIAS federation
  Handles node discovery, connection management, and distributed messaging
  """
  
  use GenServer
  require Logger

  defstruct [
    :cluster_name,
    :node_type,
    :connected_nodes,
    :last_discovery,
    :cluster_info
  ]

  # Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connect_nodes do
    GenServer.cast(__MODULE__, :connect_nodes)
  end

  def get_connected_nodes do
    GenServer.call(__MODULE__, :get_connected_nodes)
  end

  def broadcast_message(message, target_nodes \\ :all) do
    GenServer.cast(__MODULE__, {:broadcast_message, message, target_nodes})
  end

  def send_to_node(node, message) do
    GenServer.cast(__MODULE__, {:send_to_node, node, message})
  end

  def get_cluster_status do
    GenServer.call(__MODULE__, :get_cluster_status)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    Logger.info("🌐 EliasCore.P2P starting P2P communication layer")
    
    # Monitor node up/down events
    :net_kernel.monitor_nodes(true)
    
    # Set up distributed Erlang
    setup_distribution()
    
    state = %__MODULE__{
      cluster_name: "elias_federation",
      node_type: EliasCore.node_type(),
      connected_nodes: [],
      last_discovery: nil,
      cluster_info: %{}
    }
    
    # Start connection process
    connect_nodes()
    
    Logger.info("✅ EliasCore.P2P initialized")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_connected_nodes, _from, state) do
    current_nodes = Node.list()
    {:reply, current_nodes, %{state | connected_nodes: current_nodes}}
  end

  def handle_call(:get_cluster_status, _from, state) do
    status = %{
      node_type: state.node_type,
      connected_nodes: Node.list(),
      cluster_name: state.cluster_name,
      last_discovery: state.last_discovery,
      self_node: node()
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast(:connect_nodes, state) do
    Logger.info("🔍 Discovering and connecting to federation nodes...")
    
    # Get target nodes based on node type
    target_nodes = get_target_nodes(state.node_type)
    
    # Attempt to connect to each target
    connected = target_nodes
    |> Enum.map(&attempt_connection/1)
    |> Enum.filter(fn {result, _node} -> result == :connected end)
    |> Enum.map(fn {_, node} -> node end)
    
    if length(connected) > 0 do
      Logger.info("🎉 Connected to #{length(connected)} federation nodes: #{inspect(connected)}")
    else
      Logger.warning("⚠️ No federation nodes available for connection")
    end
    
    new_state = %{state | 
      connected_nodes: Node.list(),
      last_discovery: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  def handle_cast({:broadcast_message, message, target_nodes}, state) do
    nodes = case target_nodes do
      :all -> Node.list()
      nodes when is_list(nodes) -> nodes
      node when is_atom(node) -> [node]
    end
    
    Logger.debug("📢 Broadcasting message to #{length(nodes)} nodes")
    
    nodes
    |> Enum.each(fn node ->
      :rpc.cast(node, GenServer, :cast, [EliasCore.P2P, {:receive_broadcast, node(), message}])
    end)
    
    {:noreply, state}
  end

  def handle_cast({:send_to_node, target_node, message}, state) do
    case Node.ping(target_node) do
      :pong ->
        :rpc.cast(target_node, GenServer, :cast, [EliasCore.P2P, {:receive_message, node(), message}])
        Logger.debug("📤 Sent message to #{target_node}")
      
      :pang ->
        Logger.warning("⚠️ Cannot reach node #{target_node}")
    end
    
    {:noreply, state}
  end

  def handle_cast({:receive_broadcast, from_node, message}, state) do
    Logger.debug("📨 Received broadcast from #{from_node}: #{inspect(message)}")
    
    # Handle specific message types
    handle_received_message(message, from_node)
    
    {:noreply, state}
  end

  def handle_cast({:receive_message, from_node, message}, state) do
    Logger.debug("📩 Received direct message from #{from_node}: #{inspect(message)}")
    
    # Handle specific message types
    handle_received_message(message, from_node)
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("🔗 Node joined federation: #{node}")
    
    # Update connected nodes list
    connected_nodes = [node | state.connected_nodes] |> Enum.uniq()
    
    # Broadcast node join event
    broadcast_message({:node_joined, node(), get_node_info()})
    
    {:noreply, %{state | connected_nodes: connected_nodes}}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("💔 Node left federation: #{node}")
    
    # Update connected nodes list
    connected_nodes = List.delete(state.connected_nodes, node)
    
    {:noreply, %{state | connected_nodes: connected_nodes}}
  end

  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled P2P message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp setup_distribution do
    # Ensure distributed Erlang is started
    case Node.alive?() do
      true ->
        Logger.info("✅ Distributed Erlang already running: #{node()}")
      
      false ->
        # This should be handled at application startup
        Logger.warning("⚠️ Distributed Erlang not running - federation features limited")
    end
    
    # Set up security cookie if not set
    setup_security_cookie()
  end

  defp setup_security_cookie do
    case System.get_env("ERL_COOKIE") do
      nil ->
        Logger.warning("⚠️ No ERL_COOKIE set - using default (insecure)")
      
      cookie ->
        :erlang.set_cookie(node(), String.to_atom(cookie))
        Logger.info("🔐 Security cookie configured")
    end
  end

  defp get_target_nodes(:full_node) do
    [
      :"elias_server@172.20.35.144",    # Griffith full node
      :"apemacs_client@gracey"          # Gracey client node
    ]
  end

  defp get_target_nodes(:client) do
    [
      :"elias_server@172.20.35.144"     # Connect clients to full node
    ]
  end

  defp attempt_connection(target_node) do
    case Node.ping(target_node) do
      :pong ->
        Logger.info("✅ Connected to #{target_node}")
        {:connected, target_node}
      
      :pang ->
        Logger.debug("⚠️ Could not connect to #{target_node}")
        {:failed, target_node}
    end
  end

  defp handle_received_message({:node_joined, joining_node, node_info}, _from_node) do
    Logger.info("🎉 Node #{joining_node} joined with info: #{inspect(node_info)}")
    
    # Could update local node registry here
  end

  defp handle_received_message({:rule_update, rule_type, rule_data}, from_node) do
    Logger.info("📝 Received rule update from #{from_node}: #{rule_type}")
    
    # Forward to appropriate handler based on rule type
    case rule_type do
      :apemacs_rules ->
        # Forward to ApeMacs client if this is a client node
        if EliasCore.client?() do
          GenServer.cast(ApemacsClient.RuleProcessor, {:rule_update, rule_data})
        end
      
      :manager_rules ->
        # Forward to manager supervisor if this is a full node
        if EliasCore.full_node?() do
          GenServer.cast(EliasServer.ManagerSupervisor, {:rule_update, rule_data})
        end
      
      _ ->
        Logger.debug("Unknown rule type: #{rule_type}")
    end
  end

  defp handle_received_message(message, from_node) do
    Logger.debug("🤷 Unknown message type from #{from_node}: #{inspect(message)}")
  end

  defp get_node_info do
    %{
      node_type: EliasCore.node_type(),
      capabilities: get_node_capabilities(),
      version: EliasCore.version(),
      started_at: DateTime.utc_now()
    }
  end

  defp get_node_capabilities do
    case EliasCore.node_type() do
      :full_node ->
        ["blockchain_mining", "ml_processing", "manager_daemons", "heavy_compute"]
      
      :client ->
        ["apemacs", "light_requests", "rule_distribution"]
    end
  end
end