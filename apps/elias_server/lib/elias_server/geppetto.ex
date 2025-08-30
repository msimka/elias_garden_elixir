defmodule EliasServer.Geppetto do
  @moduledoc """
  Geppetto - ML Integration via Python Ports
  Manages DeepSeek model interface and other ML operations
  Integrates with UAM for model management
  """
  
  use GenServer
  require Logger

  defstruct [
    :deepseek_port,
    :model_status,
    :port_config,
    :pending_requests
  ]

  @python_scripts_path Path.join([Application.app_dir(:elias_server), "priv", "ml"])

  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def query_deepseek(prompt, options \\ %{}) do
    GenServer.call(__MODULE__, {:deepseek_query, prompt, options}, 30_000)
  end

  def train_model(model_type, training_data, options \\ %{}) do
    GenServer.call(__MODULE__, {:train_model, model_type, training_data, options}, 300_000)
  end

  def get_model_status do
    GenServer.call(__MODULE__, :get_model_status)
  end

  # GenServer Callbacks

  @impl true
  def init(state) do
    Logger.info("🤖 Geppetto: Starting ML integration daemon")
    
    # Initialize Python environment and DeepSeek model
    case initialize_deepseek_model() do
      {:ok, port} ->
        new_state = %{state |
          deepseek_port: port,
          model_status: :ready,
          pending_requests: %{}
        }
        Logger.info("✅ Geppetto: DeepSeek model ready")
        {:ok, new_state}
      
      {:error, reason} ->
        Logger.error("❌ Geppetto: Failed to initialize DeepSeek: #{reason}")
        # Continue without DeepSeek but log the issue
        new_state = %{state |
          deepseek_port: nil,
          model_status: :unavailable,
          pending_requests: %{}
        }
        {:ok, new_state}
    end
  end

  @impl true
  def handle_call({:deepseek_query, prompt, options}, from, state) do
    if state.model_status != :ready do
      {:reply, {:error, :model_unavailable}, state}
    else
      request_id = generate_request_id()
      
      # Send query to Python via Port
      query_data = %{
        request_id: request_id,
        type: "query",
        prompt: prompt,
        options: options
      }
      
      case send_to_python_port(state.deepseek_port, query_data) do
        :ok ->
          # Store pending request
          pending_requests = Map.put(state.pending_requests, request_id, from)
          new_state = %{state | pending_requests: pending_requests}
          {:noreply, new_state}
        
        {:error, reason} ->
          Logger.error("🚨 Geppetto: Failed to send query to Python: #{reason}")
          {:reply, {:error, :communication_failed}, state}
      end
    end
  end

  def handle_call({:train_model, model_type, training_data, options}, from, state) do
    request_id = generate_request_id()
    
    training_request = %{
      request_id: request_id,
      type: "train",
      model_type: model_type,
      training_data: training_data,
      options: options
    }
    
    case send_to_python_port(state.deepseek_port, training_request) do
      :ok ->
        pending_requests = Map.put(state.pending_requests, request_id, from)
        new_state = %{state | pending_requests: pending_requests}
        {:noreply, new_state}
      
      {:error, reason} ->
        Logger.error("🚨 Geppetto: Failed to send training request: #{reason}")
        {:reply, {:error, :training_failed}, state}
    end
  end

  def handle_call(:get_model_status, _from, state) do
    status_info = %{
      deepseek_status: state.model_status,
      pending_requests: map_size(state.pending_requests),
      port_active: state.deepseek_port != nil
    }
    {:reply, status_info, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{deepseek_port: port} = state) when is_port(port) do
    # Handle response from Python Port
    case decode_python_response(data) do
      {:ok, response} ->
        handle_python_response(response, state)
      
      {:error, reason} ->
        Logger.error("🚨 Geppetto: Failed to decode Python response: #{reason}")
        {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, status}}, %{deepseek_port: port} = state) when is_port(port) do
    Logger.warning("⚠️ Geppetto: Python port exited with status #{status}")
    
    # Attempt to restart the Python process
    case initialize_deepseek_model() do
      {:ok, new_port} ->
        Logger.info("♻️ Geppetto: Successfully restarted DeepSeek model")
        new_state = %{state | deepseek_port: new_port, model_status: :ready}
        {:noreply, new_state}
      
      {:error, reason} ->
        Logger.error("❌ Geppetto: Failed to restart DeepSeek: #{reason}")
        new_state = %{state | deepseek_port: nil, model_status: :unavailable}
        {:noreply, new_state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("🤖 Geppetto: Received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp initialize_deepseek_model do
    deepseek_script = Path.join(@python_scripts_path, "deepseek_interface.py")
    
    case File.exists?(deepseek_script) do
      true ->
        # Start Python process via Port
        port_options = [
          :binary,
          :exit_status,
          {:packet, 4},  # 4-byte length prefix
          {:cd, @python_scripts_path}
        ]
        
        try do
          port = Port.open({:spawn, "python3 #{deepseek_script}"}, port_options)
          
          # Wait for initialization confirmation
          receive do
            {^port, {:data, data}} ->
              case decode_python_response(data) do
                {:ok, %{"status" => "ready"}} ->
                  {:ok, port}
                {:ok, %{"status" => "error", "message" => reason}} ->
                  Port.close(port)
                  {:error, reason}
                _ ->
                  Port.close(port)
                  {:error, "Invalid initialization response"}
              end
          after
            30_000 ->  # 30 second timeout
              Port.close(port)
              {:error, "Initialization timeout"}
          end
        rescue
          e ->
            Logger.error("🚨 Geppetto: Exception starting Python port: #{inspect(e)}")
            {:error, "Port creation failed"}
        end
      
      false ->
        Logger.error("🚨 Geppetto: DeepSeek script not found: #{deepseek_script}")
        {:error, "Script not found"}
    end
  end

  defp send_to_python_port(port, data) when is_port(port) do
    try do
      encoded_data = Jason.encode!(data)
      Port.command(port, encoded_data)
      :ok
    rescue
      e ->
        Logger.error("🚨 Geppetto: Error sending to Python port: #{inspect(e)}")
        {:error, "Port communication failed"}
    end
  end

  defp send_to_python_port(nil, _data), do: {:error, "Port not available"}

  defp decode_python_response(data) do
    try do
      response = Jason.decode!(data)
      {:ok, response}
    rescue
      e ->
        Logger.error("🚨 Geppetto: JSON decode error: #{inspect(e)}")
        {:error, "Invalid JSON response"}
    end
  end

  defp handle_python_response(%{"request_id" => request_id} = response, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        Logger.warning("⚠️ Geppetto: Received response for unknown request: #{request_id}")
        {:noreply, state}
      
      from ->
        # Reply to the waiting caller
        result = case response do
          %{"status" => "success", "result" => result} -> {:ok, result}
          %{"status" => "error", "message" => message} -> {:error, message}
          _ -> {:error, "Invalid response format"}
        end
        
        GenServer.reply(from, result)
        
        # Remove from pending requests
        pending_requests = Map.delete(state.pending_requests, request_id)
        new_state = %{state | pending_requests: pending_requests}
        
        {:noreply, new_state}
    end
  end

  defp handle_python_response(response, state) do
    Logger.warning("⚠️ Geppetto: Received response without request_id: #{inspect(response)}")
    {:noreply, state}
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end