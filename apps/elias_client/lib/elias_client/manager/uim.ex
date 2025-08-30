defmodule EliasClient.Manager.UIM do
  @moduledoc """
  Universal Interface Manager (UIM) - Client version
  
  Lightweight client interface for distributed ELIAS network
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("🖥️  UIM (Client): Starting interface management")
    
    {:ok, %{
      interface_type: :lightweight_client,
      server_connections: %{},
      last_heartbeat: DateTime.utc_now(),
      client_config: load_client_interface_config()
    }}
  end

  # Public API for client interface

  @doc "Connect to ELIAS server for distributed services"
  def connect_to_server(server_node) do
    GenServer.call(__MODULE__, {:connect_server, server_node})
  end

  @doc "Get client interface status"
  def get_interface_status do
    GenServer.call(__MODULE__, :get_interface_status)
  end

  @doc "Send heartbeat to connected servers"
  def send_heartbeat do
    GenServer.cast(__MODULE__, :send_heartbeat)
  end

  # GenServer Implementation

  def handle_call({:connect_server, server_node}, _from, state) do
    case :net_adm.ping(server_node) do
      :pong ->
        new_connections = Map.put(state.server_connections, server_node, %{
          connected_at: DateTime.utc_now(),
          status: :connected,
          last_ping: DateTime.utc_now()
        })
        
        Logger.info("UIM Client: Connected to server #{server_node}")
        {:reply, {:ok, :connected}, %{state | server_connections: new_connections}}
        
      :pang ->
        Logger.warn("UIM Client: Failed to connect to server #{server_node}")
        {:reply, {:error, :connection_failed}, state}
    end
  end

  def handle_call(:get_interface_status, _from, state) do
    status = %{
      interface_type: state.interface_type,
      connected_servers: Map.keys(state.server_connections),
      last_heartbeat: state.last_heartbeat,
      client_uptime: DateTime.diff(DateTime.utc_now(), state.last_heartbeat, :second)
    }
    
    {:reply, status, state}
  end

  def handle_cast(:send_heartbeat, state) do
    # Send heartbeat to all connected servers
    Enum.each(state.server_connections, fn {server_node, _connection_info} ->
      try do
        :rpc.call(server_node, EliasServer.Manager.UIM, :receive_client_heartbeat, [node()])
      rescue
        _ -> Logger.debug("Failed to send heartbeat to #{server_node}")
      end
    end)
    
    new_state = %{state | last_heartbeat: DateTime.utc_now()}
    
    # Schedule next heartbeat
    Process.send_after(self(), :schedule_heartbeat, 30_000)
    
    {:noreply, new_state}
  end

  def handle_info(:schedule_heartbeat, state) do
    GenServer.cast(self(), :send_heartbeat)
    {:noreply, state}
  end

  defp load_client_interface_config do
    %{
      heartbeat_interval: 30_000,
      reconnect_attempts: 3,
      interface_mode: :distributed_client,
      auto_discovery: true
    }
  end
end