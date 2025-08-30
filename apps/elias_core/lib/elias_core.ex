defmodule EliasCore do
  @moduledoc """
  EliasCore - Shared libraries for ELIAS Garden distributed architecture
  
  Contains common functionality used by both elias_server (full node) 
  and apemacs_client (lightweight client):
  
  - P2P communication and distributed coordination
  - APE HARMONY blockchain for distributed logging
  - Rule distribution system for .md file updates  
  - Request pool architecture with GenStage
  - Core daemon functionality
  """
  
  @doc """
  Returns the version of the EliasCore shared library
  """
  def version do
    case Application.spec(:elias_core, :vsn) do
      nil -> "dev"
      vsn -> List.to_string(vsn)
    end
  end

  @doc """
  Get node type from environment (client vs full_node)
  """
  def node_type do
    case System.get_env("ELIAS_NODE_TYPE", "client") do
      "full_node" -> :full_node
      "client" -> :client
      _ -> :client
    end
  end

  @doc """
  Check if current node is a full node
  """
  def full_node? do
    node_type() == :full_node
  end

  @doc """
  Check if current node is a client
  """
  def client? do
    node_type() == :client
  end

  @doc """
  Get the federation node name for this instance
  """
  def federation_node_name do
    case node_type() do
      :full_node -> :"elias_server@#{get_hostname()}"
      :client -> :"apemacs_client@#{get_hostname()}"
    end
  end

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> List.to_string(hostname)
      {:error, _} -> "localhost"
    end
  end
end
