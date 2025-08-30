defmodule Elias.DistributedStatus do
  @moduledoc """
  Module to check distributed node status and connectivity
  """
  
  def get_status do
    %{
      current_node: node(),
      connected_nodes: Node.list(),
      cluster_size: length(Node.list()) + 1,
      cookie: Node.get_cookie(),
      epmd_names: get_epmd_names()
    }
  end
  
  def test_connection_to_all do
    Node.list()
    |> Enum.map(fn node ->
      ping_result = Node.ping(node)
      {node, ping_result}
    end)
  end
  
  def get_cluster_status do
    Elias.P2P.get_cluster_status()
  end
  
  defp get_epmd_names do
    case System.cmd("epmd", ["-names"]) do
      {output, 0} -> output
      {error, _} -> "Error: #{error}"
    end
  end
end