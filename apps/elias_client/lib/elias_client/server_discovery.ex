defmodule EliasClient.ServerDiscovery do
  @moduledoc """
  Server Discovery Service for ELIAS Client
  
  Automatically discovers available ELIAS servers in the network
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("🔍 ServerDiscovery: Starting ELIAS server discovery")
    
    # Start discovery process
    schedule_discovery()
    
    {:ok, %{
      discovered_servers: %{},
      discovery_config: load_discovery_config(),
      last_discovery: DateTime.utc_now()
    }}
  end

  # Public API

  @doc "Get list of discovered ELIAS servers"
  def get_available_servers do
    GenServer.call(__MODULE__, :get_servers)
  end

  @doc "Manually trigger server discovery"
  def discover_servers do
    GenServer.cast(__MODULE__, :discover)
  end

  @doc "Add known server to discovery list"
  def add_known_server(server_node, server_info \\ %{}) do
    GenServer.call(__MODULE__, {:add_server, server_node, server_info})
  end

  # GenServer Implementation

  def handle_call(:get_servers, _from, state) do
    active_servers = state.discovered_servers
    |> Enum.filter(fn {_node, info} -> info.status == :active end)
    |> Enum.into(%{})
    
    {:reply, active_servers, state}
  end

  def handle_call({:add_server, server_node, server_info}, _from, state) do
    new_server_info = Map.merge(%{
      added_at: DateTime.utc_now(),
      status: :unknown,
      last_ping: nil,
      capabilities: []
    }, server_info)
    
    new_servers = Map.put(state.discovered_servers, server_node, new_server_info)
    new_state = %{state | discovered_servers: new_servers}
    
    # Immediately ping the new server
    GenServer.cast(self(), {:ping_server, server_node})
    
    {:reply, :ok, new_state}
  end

  def handle_cast(:discover, state) do
    Logger.info("ServerDiscovery: Starting server discovery scan")
    
    discovered = discover_elias_servers()
    updated_servers = merge_discovered_servers(state.discovered_servers, discovered)
    
    new_state = %{state | 
      discovered_servers: updated_servers,
      last_discovery: DateTime.utc_now()
    }
    
    Logger.info("ServerDiscovery: Found #{map_size(updated_servers)} servers")
    
    {:noreply, new_state}
  end

  def handle_cast({:ping_server, server_node}, state) do
    case ping_elias_server(server_node) do
      {:ok, server_info} ->
        updated_info = Map.merge(
          Map.get(state.discovered_servers, server_node, %{}),
          %{
            status: :active,
            last_ping: DateTime.utc_now(),
            capabilities: server_info[:capabilities] || [],
            version: server_info[:version]
          }
        )
        
        new_servers = Map.put(state.discovered_servers, server_node, updated_info)
        Logger.info("ServerDiscovery: Server #{server_node} is active")
        
        {:noreply, %{state | discovered_servers: new_servers}}
        
      {:error, _reason} ->
        case Map.get(state.discovered_servers, server_node) do
          nil -> 
            {:noreply, state}
          server_info ->
            updated_info = %{server_info | status: :inactive, last_ping: DateTime.utc_now()}
            new_servers = Map.put(state.discovered_servers, server_node, updated_info)
            {:noreply, %{state | discovered_servers: new_servers}}
        end
    end
  end

  def handle_info(:scheduled_discovery, state) do
    GenServer.cast(self(), :discover)
    schedule_discovery()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_discovery do
    Process.send_after(self(), :scheduled_discovery, 60_000) # Discovery every minute
  end

  defp discover_elias_servers do
    # Phase 1: Simple network discovery methods
    discovered = %{}
    
    # Method 1: Check common ELIAS node names
    common_names = [
      :"elias_server@localhost",
      :"elias_server@#{get_hostname()}",
      :"elias1@localhost",
      :"elias2@localhost"
    ]
    
    discovered = Enum.reduce(common_names, discovered, fn node_name, acc ->
      case :net_adm.ping(node_name) do
        :pong -> Map.put(acc, node_name, %{discovered_via: :common_name})
        :pang -> acc
      end
    end)
    
    # Method 2: Check environment variable for known servers
    case System.get_env("ELIAS_SERVERS") do
      nil -> discovered
      servers_str ->
        servers_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
        |> Enum.reduce(discovered, fn node_name, acc ->
          case :net_adm.ping(node_name) do
            :pong -> Map.put(acc, node_name, %{discovered_via: :env_variable})
            :pang -> acc
          end
        end)
    end
  end

  defp merge_discovered_servers(existing, discovered) do
    Enum.reduce(discovered, existing, fn {node_name, discovery_info}, acc ->
      case Map.get(acc, node_name) do
        nil ->
          # New server
          Map.put(acc, node_name, Map.merge(%{
            first_discovered: DateTime.utc_now(),
            status: :unknown
          }, discovery_info))
          
        existing_info ->
          # Update existing server
          Map.put(acc, node_name, Map.merge(existing_info, discovery_info))
      end
    end)
  end

  defp ping_elias_server(server_node) do
    try do
      case :rpc.call(server_node, EliasServer.Manager.UIM, :get_server_info, [], 5000) do
        {:badrpc, _reason} ->
          {:error, :rpc_failed}
          
        server_info when is_map(server_info) ->
          {:ok, server_info}
          
        _ ->
          {:error, :invalid_response}
      end
    rescue
      _ ->
        {:error, :ping_failed}
    end
  end

  defp get_hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> List.to_string(hostname)
      _ -> "localhost"
    end
  end

  defp load_discovery_config do
    %{
      discovery_interval: 60_000,
      ping_timeout: 5000,
      max_servers: 10,
      discovery_methods: [:common_names, :env_variable, :mdns] # Phase 2: add mDNS
    }
  end
end