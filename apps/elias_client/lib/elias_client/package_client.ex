defmodule EliasClient.PackageClient do
  @moduledoc """
  Client-side package management interface
  
  Communicates with federated ELIAS servers for package operations
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{
      server_nodes: [],
      cache: :ets.new(:package_cache, [:set, :public]),
      config: load_client_config()
    }}
  end

  # Public Client API

  @doc "Install package via ELIAS distributed package management"
  def install(package_spec, opts \\ %{}) do
    GenServer.call(__MODULE__, {:install, package_spec, opts})
  end

  @doc "Install from TIKI declarative configuration"  
  def install_from_config(tiki_path) do
    GenServer.call(__MODULE__, {:install_from_config, tiki_path})
  end

  @doc "Verify package integrity via blockchain (Phase 2)"
  def verify(package_spec) do
    GenServer.call(__MODULE__, {:verify, package_spec})
  end

  # GenServer Implementation

  def handle_call({:install, package_spec, opts}, _from, state) do
    case find_available_server(state.server_nodes) do
      {:ok, server_node} ->
        # Forward to server URM for actual installation
        result = :rpc.call(server_node, EliasServer.Manager.URM, :install_package, [package_spec, opts])
        {:reply, result, state}
        
      {:error, :no_servers} ->
        # Fallback: direct installation if no servers available
        result = direct_install_fallback(package_spec, opts)
        {:reply, result, state}
    end
  end

  def handle_call({:install_from_config, tiki_path}, _from, state) do
    case find_available_server(state.server_nodes) do
      {:ok, server_node} ->
        result = :rpc.call(server_node, EliasServer.Manager.URM, :install_from_tiki, [tiki_path])
        {:reply, result, state}
        
      {:error, :no_servers} ->
        {:reply, {:error, "No ELIAS servers available for distributed installation"}, state}
    end
  end

  def handle_call({:verify, package_spec}, _from, state) do
    case find_available_server(state.server_nodes) do
      {:ok, server_node} ->
        case String.split(package_spec, ":") do
          [ecosystem, package_name] ->
            # Extract version if present
            {name, version} = case String.split(package_name, "@") do
              [n, v] -> {n, v}
              [n] -> {n, "latest"}
            end
            
            result = :rpc.call(server_node, EliasServer.Manager.URM, :verify_package, [ecosystem, name, version])
            {:reply, result, state}
            
          _ ->
            {:reply, {:error, "Invalid package specification"}, state}
        end
        
      {:error, :no_servers} ->
        {:reply, {:error, "No ELIAS servers available for verification"}, state}
    end
  end

  defp find_available_server([]), do: {:error, :no_servers}
  defp find_available_server([server | _rest]) do
    case :net_adm.ping(server) do
      :pong -> {:ok, server}
      :pang -> {:error, :server_unavailable}
    end
  end

  defp direct_install_fallback(package_spec, _opts) do
    # Phase 1: Basic fallback to direct system commands
    case String.split(package_spec, ":") do
      [ecosystem, package] ->
        case ecosystem do
          "npm" -> System.cmd("npm", ["install", package])
          "pip" -> System.cmd("pip", ["install", package])
          "gem" -> System.cmd("gem", ["install", package])
          "apt" -> System.cmd("apt", ["install", "-y", package])
          "brew" -> System.cmd("brew", ["install", package])
          "cargo" -> System.cmd("cargo", ["install", package])
          _ -> {:error, "Unsupported ecosystem: #{ecosystem}"}
        end
      _ -> {:error, "Invalid package specification"}
    end
  end

  defp load_client_config do
    # Load client configuration (server discovery, preferences)
    %{
      server_discovery: :auto,
      prefer_local_cache: true,
      blockchain_verification: :auto, # Phase 2
      fallback_to_direct: true
    }
  end
end