defmodule EliasClient do
  @moduledoc """
  ELIAS Distributed OS Client - Main Interface
  
  Provides client-side interface for ELIAS distributed operating system services.
  Connects to federated ELIAS server network for package management, resource 
  allocation, and AI-driven optimization.
  """

  @doc """
  Install package via ELIAS distributed package management
  
  ## Examples
  
      iex> EliasClient.install_package("npm:express@4.18.0")
      {:ok, %{ecosystem: "npm", package: "express", version: "4.18.0"}}
      
      iex> EliasClient.install_package("pip:fastapi")
      {:ok, %{ecosystem: "pip", package: "fastapi", version: "latest"}}
  """
  def install_package(package_spec, opts \\ %{}) do
    EliasClient.PackageClient.install(package_spec, opts)
  end

  @doc """
  Install packages from TIKI declarative configuration
  
  ## Examples
  
      iex> EliasClient.install_from_config("./my_project.tiki")
      {:ok, [%{ecosystem: "npm", package: "express"}, %{ecosystem: "pip", package: "fastapi"}]}
  """
  def install_from_config(tiki_path) do
    EliasClient.PackageClient.install_from_config(tiki_path)
  end

  @doc """
  Verify package integrity via blockchain verification (Phase 2)
  
  ## Examples
  
      iex> EliasClient.verify_package("npm:express@4.18.0")
      {:ok, %{verified: true, method: "blockchain_verification"}}
  """
  def verify_package(package_spec) do
    EliasClient.PackageClient.verify(package_spec)
  end

  @doc """
  Get list of available ELIAS servers in the network
  
  ## Examples
  
      iex> EliasClient.get_available_servers()
      %{:"elias_server@localhost" => %{status: :active, capabilities: ["UPM", "URM"]}}
  """
  def get_available_servers do
    EliasClient.ServerDiscovery.get_available_servers()
  end

  @doc """
  Get client status and connection information
  
  ## Examples
  
      iex> EliasClient.get_client_status()
      %{interface_type: :lightweight_client, connected_servers: [:"elias_server@localhost"]}
  """
  def get_client_status do
    EliasClient.Manager.UIM.get_interface_status()
  end

  @doc """
  Get communication statistics with ELIAS servers
  
  ## Examples
  
      iex> EliasClient.get_communication_stats()
      %{messages_sent: 25, messages_received: 23, connected_servers: 1}
  """
  def get_communication_stats do
    EliasClient.Manager.UCM.get_communication_stats()
  end

  @doc """
  Get local cache statistics and performance metrics
  
  ## Examples
  
      iex> EliasClient.get_cache_stats()
      %{hits: 45, misses: 12, hit_rate: 78.9, package_cache_size: 25}
  """
  def get_cache_stats do
    EliasClient.LocalCache.get_cache_stats()
  end

  @doc """
  Connect to specific ELIAS server node
  
  ## Examples
  
      iex> EliasClient.connect_to_server(:"elias_server@localhost")
      {:ok, :connected}
  """
  def connect_to_server(server_node) do
    EliasClient.Manager.UIM.connect_to_server(server_node)
  end

  @doc """
  Discover available ELIAS servers on the network
  
  ## Examples
  
      iex> EliasClient.discover_servers()
      :ok
  """
  def discover_servers do
    EliasClient.ServerDiscovery.discover_servers()
  end

  @doc """
  Clear all local caches
  
  ## Examples
  
      iex> EliasClient.clear_caches()
      :ok
  """
  def clear_caches do
    EliasClient.LocalCache.clear_all_caches()
  end
end
