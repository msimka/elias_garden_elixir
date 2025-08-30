defmodule Elias.TestDistributed do
  @moduledoc """
  Test module for distributed communication between ELIAS nodes
  """
  
  require Logger

  def test_connection do
    nodes = Node.list()
    Logger.info("Connected nodes: #{inspect(nodes)}")
    
    case nodes do
      [] ->
        Logger.warning("No nodes connected")
        {:error, :no_nodes}
      _ ->
        test_rpc_calls(nodes)
    end
  end
  
  def test_rpc_calls(nodes) do
    Enum.map(nodes, fn node ->
      Logger.info("Testing RPC to node: #{node}")
      
      # Test basic RPC call
      result = :rpc.call(node, IO, :puts, ["🔗 RPC test from #{node()} to #{node}"])
      Logger.info("RPC result: #{inspect(result)}")
      
      # Test ELIAS daemon status
      daemon_status = :rpc.call(node, GenServer, :call, [Elias.Daemon, :get_status])
      Logger.info("Daemon status: #{inspect(daemon_status)}")
      
      {node, result}
    end)
  end
  
  def send_test_message(to_node, message) do
    Logger.info("Sending message to #{to_node}: #{message}")
    
    case Node.ping(to_node) do
      :pong ->
        # Send via P2P module
        Elias.P2P.send_message(to_node, {:test_message, node(), message})
      :pang ->
        Logger.warning("Node #{to_node} not reachable")
        {:error, :unreachable}
    end
  end
end