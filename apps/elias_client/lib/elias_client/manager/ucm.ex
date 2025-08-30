defmodule EliasClient.Manager.UCM do
  @moduledoc """
  Universal Communication Manager (UCM) - Client version
  
  Lightweight communication layer for connecting to ELIAS server network
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("📡 UCM (Client): Starting communication management")
    
    {:ok, %{
      server_connections: %{},
      message_queue: :queue.new(),
      communication_stats: %{
        messages_sent: 0,
        messages_received: 0,
        connection_attempts: 0,
        successful_connections: 0
      },
      client_config: load_client_communication_config()
    }}
  end

  # Public API

  @doc "Send message to ELIAS server"
  def send_to_server(server_node, message, priority \\ :medium) do
    GenServer.call(__MODULE__, {:send_message, server_node, message, priority})
  end

  @doc "Broadcast message to all connected servers"
  def broadcast_to_servers(message, priority \\ :medium) do
    GenServer.cast(__MODULE__, {:broadcast, message, priority})
  end

  @doc "Get communication statistics"
  def get_communication_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Implementation

  def handle_call({:send_message, server_node, message, priority}, _from, state) do
    case ensure_server_connection(server_node, state) do
      {:ok, new_state} ->
        case send_message_to_server(server_node, message, priority) do
          {:ok, response} ->
            updated_stats = %{new_state.communication_stats | 
              messages_sent: new_state.communication_stats.messages_sent + 1
            }
            final_state = %{new_state | communication_stats: updated_stats}
            {:reply, {:ok, response}, final_state}
            
          {:error, reason} ->
            {:reply, {:error, reason}, new_state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats = Map.merge(state.communication_stats, %{
      connected_servers: Map.keys(state.server_connections),
      queue_size: :queue.len(state.message_queue),
      last_updated: DateTime.utc_now()
    })
    
    {:reply, stats, state}
  end

  def handle_cast({:broadcast, message, priority}, state) do
    # Broadcast to all connected servers
    Enum.each(state.server_connections, fn {server_node, _connection} ->
      spawn(fn -> send_message_to_server(server_node, message, priority) end)
    end)
    
    updated_stats = %{state.communication_stats | 
      messages_sent: state.communication_stats.messages_sent + map_size(state.server_connections)
    }
    
    new_state = %{state | communication_stats: updated_stats}
    {:noreply, new_state}
  end

  def handle_info({:server_message, server_node, message}, state) do
    Logger.debug("UCM Client: Received message from #{server_node}: #{inspect(message)}")
    
    # Update stats
    updated_stats = %{state.communication_stats | 
      messages_received: state.communication_stats.messages_received + 1
    }
    
    # Process the message based on type
    case message do
      {:package_install_complete, package_info} ->
        Logger.info("Package installation completed: #{inspect(package_info)}")
        
      {:resource_alert, alert_info} ->
        Logger.warn("Resource alert from server: #{inspect(alert_info)}")
        
      _ ->
        Logger.debug("Unhandled server message: #{inspect(message)}")
    end
    
    new_state = %{state | communication_stats: updated_stats}
    {:noreply, new_state}
  end

  # Private Functions

  defp ensure_server_connection(server_node, state) do
    case Map.has_key?(state.server_connections, server_node) do
      true ->
        {:ok, state}
        
      false ->
        case :net_adm.ping(server_node) do
          :pong ->
            new_connections = Map.put(state.server_connections, server_node, %{
              connected_at: DateTime.utc_now(),
              status: :active
            })
            
            updated_stats = %{state.communication_stats | 
              connection_attempts: state.communication_stats.connection_attempts + 1,
              successful_connections: state.communication_stats.successful_connections + 1
            }
            
            new_state = %{state | 
              server_connections: new_connections,
              communication_stats: updated_stats
            }
            
            Logger.info("UCM Client: Established connection to #{server_node}")
            {:ok, new_state}
            
          :pang ->
            updated_stats = %{state.communication_stats | 
              connection_attempts: state.communication_stats.connection_attempts + 1
            }
            
            new_state = %{state | communication_stats: updated_stats}
            Logger.warn("UCM Client: Failed to connect to #{server_node}")
            {:error, :connection_failed}
        end
    end
  end

  defp send_message_to_server(server_node, message, priority) do
    try do
      case :rpc.call(server_node, EliasServer.Manager.UCM, :receive_client_message, [node(), message, priority], 5000) do
        {:badrpc, reason} ->
          Logger.error("Failed to send message to #{server_node}: #{inspect(reason)}")
          {:error, reason}
          
        response ->
          {:ok, response}
      end
    rescue
      error ->
        Logger.error("Error sending message to #{server_node}: #{inspect(error)}")
        {:error, :communication_error}
    end
  end

  defp load_client_communication_config do
    %{
      connection_timeout: 5000,
      message_retry_attempts: 3,
      heartbeat_interval: 30_000,
      max_queue_size: 1000
    }
  end
end