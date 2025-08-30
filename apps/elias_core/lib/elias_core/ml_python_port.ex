defmodule EliasCore.MLPythonPort do
  @moduledoc """
  ML Python integration via Erlang Ports
  
  Provides interface to Python ML models and processing while maintaining
  the pure Elixir ELIAS architecture. Uses Ports for secure, isolated communication.
  """
  
  use GenServer
  require Logger

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def infer(model_name, input_data, timeout \\ 30_000) do
    GenServer.call(__MODULE__, {:infer, model_name, input_data}, timeout)
  end
  
  def load_model(model_name, model_path) do
    GenServer.call(__MODULE__, {:load_model, model_name, model_path})
  end
  
  def unload_model(model_name) do
    GenServer.call(__MODULE__, {:unload_model, model_name})
  end
  
  def get_loaded_models do
    GenServer.call(__MODULE__, :get_loaded_models)
  end
  
  def get_port_status do
    GenServer.call(__MODULE__, :get_port_status)
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    Logger.info("🐍 MLPythonPort starting - Python ML integration via Ports")
    
    # Get Python script path
    python_script = get_python_script_path()
    
    # Start Python port
    case start_python_port(python_script) do
      {:ok, port} ->
        state = %{
          port: port,
          python_script: python_script,
          loaded_models: %{},
          request_counter: 0,
          pending_requests: %{},
          port_alive: true,
          last_heartbeat: DateTime.utc_now()
        }
        
        # Schedule periodic heartbeat
        schedule_heartbeat()
        
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to start Python port: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:infer, model_name, input_data}, from, state) do
    Logger.debug("MLPythonPort inference request: #{model_name}")
    
    case Map.get(state.loaded_models, model_name) do
      nil ->
        {:reply, {:error, :model_not_loaded}, state}
        
      _model_info ->
        # Generate request ID
        request_id = state.request_counter + 1
        
        # Create inference request
        request = %{
          action: "infer",
          request_id: request_id,
          model_name: model_name,
          input_data: input_data
        }
        
        # Send to Python port
        case send_to_python(state.port, request) do
          :ok ->
            # Track pending request
            new_pending = Map.put(state.pending_requests, request_id, {from, DateTime.utc_now()})
            new_state = %{state | 
              request_counter: request_id,
              pending_requests: new_pending
            }
            
            {:noreply, new_state}
            
          {:error, reason} ->
            Logger.error("Failed to send inference request: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:load_model, model_name, model_path}, from, state) do
    Logger.info("MLPythonPort loading model: #{model_name} from #{model_path}")
    
    request_id = state.request_counter + 1
    
    request = %{
      action: "load_model",
      request_id: request_id,
      model_name: model_name,
      model_path: model_path
    }
    
    case send_to_python(state.port, request) do
      :ok ->
        new_pending = Map.put(state.pending_requests, request_id, {from, DateTime.utc_now()})
        new_state = %{state | 
          request_counter: request_id,
          pending_requests: new_pending
        }
        
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_model, model_name}, from, state) do
    Logger.info("MLPythonPort unloading model: #{model_name}")
    
    request_id = state.request_counter + 1
    
    request = %{
      action: "unload_model", 
      request_id: request_id,
      model_name: model_name
    }
    
    case send_to_python(state.port, request) do
      :ok ->
        new_pending = Map.put(state.pending_requests, request_id, {from, DateTime.utc_now()})
        new_state = %{state | 
          request_counter: request_id,
          pending_requests: new_pending
        }
        
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_loaded_models, _from, state) do
    {:reply, Map.keys(state.loaded_models), state}
  end
  
  @impl true
  def handle_call(:get_port_status, _from, state) do
    status = %{
      port_alive: state.port_alive,
      loaded_models: map_size(state.loaded_models),
      pending_requests: map_size(state.pending_requests),
      last_heartbeat: state.last_heartbeat,
      request_counter: state.request_counter
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Received data from Python port
    case parse_python_response(data) do
      {:ok, response} ->
        handle_python_response(response, state)
        
      {:error, reason} ->
        Logger.error("Failed to parse Python response: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Python port exited with status: #{status}")
    
    # Reply to all pending requests with error
    Enum.each(state.pending_requests, fn {_id, {from, _timestamp}} ->
      GenServer.reply(from, {:error, :port_died})
    end)
    
    new_state = %{state | 
      port_alive: false,
      pending_requests: %{}
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:heartbeat, state) do
    # Send heartbeat to Python port
    heartbeat = %{
      action: "heartbeat",
      timestamp: DateTime.utc_now() |> DateTime.to_unix()
    }
    
    case send_to_python(state.port, heartbeat) do
      :ok ->
        schedule_heartbeat()
        {:noreply, %{state | last_heartbeat: DateTime.utc_now()}}
        
      {:error, _reason} ->
        Logger.warn("Heartbeat failed - Python port may be unresponsive")
        {:noreply, %{state | port_alive: false}}
    end
  end
  
  @impl true
  def handle_info({:timeout_request, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        {:noreply, state}
        
      {from, _timestamp} ->
        Logger.warn("Request #{request_id} timed out")
        GenServer.reply(from, {:error, :timeout})
        
        new_pending = Map.delete(state.pending_requests, request_id)
        {:noreply, %{state | pending_requests: new_pending}}
    end
  end

  # Private Functions
  
  defp get_python_script_path do
    # Look for ML Python script in expected locations
    possible_paths = [
      "/Users/mikesimka/elias_garden_elixir/apps/elias_core/priv/ml_interface.py",
      "/Users/mikesimka/elias-system/elias-python/ml_interface.py"
    ]
    
    Enum.find(possible_paths, fn path ->
      File.exists?(path)
    end) || create_default_ml_script()
  end
  
  defp create_default_ml_script do
    script_dir = "/Users/mikesimka/elias_garden_elixir/apps/elias_core/priv"
    script_path = Path.join(script_dir, "ml_interface.py")
    
    File.mkdir_p!(script_dir)
    
    default_script = """
#!/usr/bin/env python3
# ELIAS ML Interface - Python Port Communication
import sys
import json
import traceback
from datetime import datetime

class EliasMLInterface:
    def __init__(self):
        self.loaded_models = {}
        
    def load_model(self, model_name, model_path):
        \"\"\"Load an ML model (placeholder implementation)\"\"\"
        try:
            # Placeholder - in real implementation, load actual models
            # e.g., torch.load(model_path), joblib.load(model_path), etc.
            
            model_info = {
                'name': model_name,
                'path': model_path,
                'loaded_at': datetime.now().isoformat(),
                'type': 'placeholder'
            }
            
            self.loaded_models[model_name] = model_info
            
            return {
                'status': 'success',
                'message': f'Model {model_name} loaded successfully',
                'model_info': model_info
            }
            
        except Exception as e:
            return {
                'status': 'error',
                'message': f'Failed to load model {model_name}: {str(e)}'
            }
    
    def unload_model(self, model_name):
        \"\"\"Unload an ML model\"\"\"
        if model_name in self.loaded_models:
            del self.loaded_models[model_name]
            return {
                'status': 'success',
                'message': f'Model {model_name} unloaded'
            }
        else:
            return {
                'status': 'error',
                'message': f'Model {model_name} not loaded'
            }
    
    def infer(self, model_name, input_data):
        \"\"\"Run inference on loaded model\"\"\"
        if model_name not in self.loaded_models:
            return {
                'status': 'error',
                'message': f'Model {model_name} not loaded'
            }
        
        try:
            # Placeholder inference - in real implementation, run actual model
            result = {
                'model': model_name,
                'input_shape': str(type(input_data)),
                'output': f'Processed by {model_name}',
                'confidence': 0.95,
                'processing_time_ms': 42
            }
            
            return {
                'status': 'success',
                'result': result
            }
            
        except Exception as e:
            return {
                'status': 'error', 
                'message': f'Inference failed: {str(e)}'
            }

def main():
    ml_interface = EliasMLInterface()
    
    try:
        while True:
            # Read line from Elixir port
            line = sys.stdin.readline()
            if not line:
                break
                
            # Parse JSON request
            try:
                request = json.loads(line.strip())
            except json.JSONDecodeError as e:
                response = {
                    'status': 'error',
                    'message': f'Invalid JSON: {str(e)}'
                }
                print(json.dumps(response))
                sys.stdout.flush()
                continue
            
            # Handle request
            action = request.get('action')
            request_id = request.get('request_id')
            
            if action == 'heartbeat':
                response = {
                    'action': 'heartbeat_response',
                    'timestamp': datetime.now().isoformat(),
                    'loaded_models': list(ml_interface.loaded_models.keys())
                }
            
            elif action == 'load_model':
                model_name = request.get('model_name')
                model_path = request.get('model_path')
                response = ml_interface.load_model(model_name, model_path)
                response['request_id'] = request_id
                response['action'] = 'load_model_response'
            
            elif action == 'unload_model':
                model_name = request.get('model_name')
                response = ml_interface.unload_model(model_name)
                response['request_id'] = request_id
                response['action'] = 'unload_model_response'
            
            elif action == 'infer':
                model_name = request.get('model_name')
                input_data = request.get('input_data')
                response = ml_interface.infer(model_name, input_data)
                response['request_id'] = request_id
                response['action'] = 'infer_response'
            
            else:
                response = {
                    'status': 'error',
                    'message': f'Unknown action: {action}',
                    'request_id': request_id
                }
            
            # Send response back to Elixir
            print(json.dumps(response))
            sys.stdout.flush()
            
    except Exception as e:
        error_response = {
            'status': 'error',
            'message': f'Python interface error: {str(e)}',
            'traceback': traceback.format_exc()
        }
        print(json.dumps(error_response))
        sys.stdout.flush()

if __name__ == '__main__':
    main()
"""
    
    File.write!(script_path, default_script)
    System.cmd("chmod", ["+x", script_path])
    
    Logger.info("Created default ML interface script: #{script_path}")
    script_path
  end
  
  defp start_python_port(script_path) do
    Logger.info("Starting Python ML port: #{script_path}")
    
    try do
      port = Port.open({:spawn, "python3 #{script_path}"}, [
        :binary,
        :exit_status,
        {:line, 8192}
      ])
      
      {:ok, port}
    rescue
      e ->
        {:error, e}
    end
  end
  
  defp send_to_python(port, data) do
    try do
      json_data = Jason.encode!(data)
      Port.command(port, json_data <> "\n")
      :ok
    rescue
      e ->
        {:error, e}
    end
  end
  
  defp parse_python_response({:eol, data}) when is_binary(data) do
    parse_python_response(data)
  end
  
  defp parse_python_response(data) when is_binary(data) do
    try do
      response = Jason.decode!(data)
      {:ok, response}
    rescue
      e ->
        {:error, e}
    end
  end
  
  defp handle_python_response(%{"action" => "heartbeat_response"} = response, state) do
    Logger.debug("Received Python heartbeat response")
    loaded_models_list = Map.get(response, "loaded_models", [])
    
    # Update loaded models tracking
    new_loaded_models = Enum.reduce(loaded_models_list, %{}, fn model_name, acc ->
      Map.put(acc, model_name, %{name: model_name, status: :loaded})
    end)
    
    new_state = %{state | 
      loaded_models: new_loaded_models,
      port_alive: true,
      last_heartbeat: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end
  
  defp handle_python_response(%{"request_id" => request_id} = response, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        Logger.warn("Received response for unknown request: #{request_id}")
        {:noreply, state}
        
      {from, _timestamp} ->
        # Reply to waiting caller
        action = Map.get(response, "action")
        status = Map.get(response, "status")
        
        reply = case {action, status} do
          {_, "success"} ->
            {:ok, Map.delete(response, "request_id")}
          {_, "error"} ->
            message = Map.get(response, "message", "Unknown error")
            {:error, message}
          _ ->
            {:ok, response}
        end
        
        GenServer.reply(from, reply)
        
        # Update state if model operation
        new_state = case action do
          "load_model_response" ->
            if status == "success" do
              model_name = get_in(response, ["model_info", "name"])
              model_info = Map.get(response, "model_info", %{})
              new_models = Map.put(state.loaded_models, model_name, model_info)
              %{state | loaded_models: new_models}
            else
              state
            end
            
          "unload_model_response" ->
            if status == "success" do
              # Need to track which model was unloaded - this is simplified
              state
            else
              state
            end
            
          _ ->
            state
        end
        
        # Remove from pending requests
        new_pending = Map.delete(new_state.pending_requests, request_id)
        final_state = %{new_state | pending_requests: new_pending}
        
        {:noreply, final_state}
    end
  end
  
  defp handle_python_response(response, state) do
    Logger.warn("Received unhandled Python response: #{inspect(response)}")
    {:noreply, state}
  end
  
  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, 10_000)  # Every 10 seconds
  end
end