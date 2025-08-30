defmodule Elias.P2P do
  @moduledoc """
  P2P communication layer for distributed ELIAS nodes
  
  Handles communication between Griffith (Linux) and Gracey (macOS)
  and manages the wider P2P network for ELIAS federation.
  """
  
  require Logger

  @cookie :elias_distributed_system
  
  def connect_nodes do
    Logger.info("🔗 Starting P2P node connections...")
    
    # Start distributed Erlang
    result = case Node.start(node_name()) do
      {:ok, _} ->
        Logger.info("✅ Node started: #{node()}")
        :ok
      {:error, {:already_started, _}} ->
        Logger.info("ℹ️ Node already started: #{node()}")
        :ok
      {:error, reason} ->
        Logger.warning("⚠️ P2P node failed to start: #{inspect(reason)}")
        Logger.info("🔄 Running in standalone mode (P2P disabled)")
        :standalone
    end
    
    # Only set cookie if we successfully started distributed mode
    case result do
      :ok ->
        # Set secure cookie
        Node.set_cookie(@cookie)
        Logger.info("🔐 Node cookie set for distributed operation")
      :standalone ->
        Logger.info("🏠 Running in standalone mode - no distributed connectivity")
    end
    
    # Connect to known peer nodes only if in distributed mode
    case result do
      :ok ->
        peer_nodes()
        |> Enum.each(&connect_to_peer/1)
        
        # Set up node monitoring
        :net_kernel.monitor_nodes(true)
        {:ok, node()}
      :standalone ->
        {:ok, :standalone}
    end
  end
  
  def send_message(to_node, message) when is_atom(to_node) do
    case Node.ping(to_node) do
      :pong ->
        :rpc.cast(to_node, GenServer, :cast, [Elias.Daemon, {:p2p_message, node(), message}])
        {:ok, :sent}
      :pang ->
        Logger.warning("⚠️ Cannot reach node: #{to_node}")
        {:error, :unreachable}
    end
  end
  
  def broadcast_message(message) do
    Node.list()
    |> Enum.map(fn node ->
      send_message(node, message)
    end)
  end
  
  def get_cluster_status do
    %{
      current_node: node(),
      connected_nodes: Node.list(),
      node_info: Node.get_cookie(),
      cluster_size: length(Node.list()) + 1
    }
  end
  
  def sync_rules_across_cluster do
    Logger.info("🔄 Syncing rules across cluster...")
    
    state = Elias.Daemon.get_state()
    message = {:rules_sync, state.rules}
    
    broadcast_message(message)
  end
  
  def request_rules_from_peer(peer_node) do
    message = {:request_rules, node()}
    send_message(peer_node, message)
  end

  # Private Functions
  
  defp node_name do
    hostname = 
      case System.cmd("hostname", []) do
        {hostname, 0} -> String.trim(hostname)
        _ -> "unknown"
      end
    
    # Clean hostname and create node name
    clean_hostname = 
      hostname
      |> String.replace(~r/\.local$/, "")  # Remove .local suffix if present
      |> String.downcase()
    
    case clean_hostname do
      "griffith" -> :"elias@172.20.35.144"  # Use IP for Griffith
      name when name in ["mikes-macbook-pro-2", "gracey"] -> :"elias@gracey"
      name -> :"elias@#{name}"
    end
  end
  
  defp peer_nodes do
    current = node_name()
    all_known = [
      :"elias@172.20.35.144",  # Griffith IP
      :"elias@gracey"
    ]
    
    List.delete(all_known, current)
  end
  
  defp connect_to_peer(peer_node) do
    Logger.info("🔗 Connecting to peer: #{peer_node}")
    
    case Node.connect(peer_node) do
      true ->
        Logger.info("✅ Connected to #{peer_node}")
        :ok
      false ->
        Logger.warning("⚠️ Could not connect to #{peer_node}")
        :error
      :ignored ->
        Logger.info("ℹ️ Connection to #{peer_node} ignored (already connected)")
        :ok
    end
  end
end