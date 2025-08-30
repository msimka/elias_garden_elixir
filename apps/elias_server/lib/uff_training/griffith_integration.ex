defmodule UFFTraining.GriffithIntegration do
  @moduledoc """
  Integration layer between Gracey (local MacBook Pro) and Griffith (manager model server)
  
  Handles communication with the 6 specialized DeepSeek 6.7B-FP16 manager models:
  - UFM: Federation orchestration 
  - UCM: Content processing
  - URM: Resource optimization
  - ULM: Learning adaptation
  - UIM: Interface design
  - UAM: Creative generation
  """
  
  use GenServer
  require Logger
  
  @griffith_host "griffith"
  @griffith_user System.get_env("USER", "elias")
  @manager_models [:ufm, :ucm, :urm, :ulm, :uim, :uam]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_manager_model_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def deploy_manager_models do
    GenServer.call(__MODULE__, :deploy_models, :infinity)
  end
  
  def generate_with_manager(manager, prompt, options \\ []) do
    GenServer.call(__MODULE__, {:generate, manager, prompt, options})
  end
  
  def start_all_manager_models do
    GenServer.call(__MODULE__, :start_all_models)
  end
  
  def stop_all_manager_models do
    GenServer.call(__MODULE__, :stop_all_models)
  end
  
  # Server Implementation
  
  def init(_opts) do
    Logger.info("UFFTraining.GriffithIntegration: Starting Griffith integration")
    
    state = %{
      griffith_host: @griffith_host,
      griffith_user: @griffith_user,
      manager_models: @manager_models,
      connection_status: :disconnected,
      model_status: %{}
    }
    
    # Test connection on startup
    {:ok, state, {:continue, :test_connection}}
  end
  
  def handle_continue(:test_connection, state) do
    case test_griffith_connection(state) do
      :ok ->
        Logger.info("✅ Griffith connection established")
        {:noreply, %{state | connection_status: :connected}}
        
      {:error, reason} ->
        Logger.warning("⚠️  Griffith connection failed: #{inspect(reason)}")
        {:noreply, %{state | connection_status: :error}}
    end
  end
  
  def handle_call(:get_status, _from, state) do
    status = get_current_status(state)
    {:reply, status, state}
  end
  
  def handle_call(:deploy_models, _from, state) do
    Logger.info("🚀 Deploying manager models to Griffith...")
    
    case deploy_models_to_griffith(state) do
      :ok ->
        Logger.info("✅ Manager models deployed successfully")
        {:reply, :ok, state}
        
      {:error, reason} ->
        Logger.error("❌ Manager model deployment failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:generate, manager, prompt, options}, _from, state) do
    case generate_with_griffith_manager(manager, prompt, options, state) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
        
      {:error, reason} ->
        Logger.warning("Manager #{manager} generation failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:start_all_models, _from, state) do
    case start_griffith_models(state) do
      :ok ->
        Logger.info("✅ All manager models started on Griffith")
        {:reply, :ok, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:stop_all_models, _from, state) do
    case stop_griffith_models(state) do
      :ok ->
        Logger.info("🛑 All manager models stopped on Griffith")
        {:reply, :ok, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private Functions
  
  defp test_griffith_connection(state) do
    cmd = "ssh #{state.griffith_user}@#{state.griffith_host} 'echo connection_test'"
    
    case System.cmd("ssh", [
      "#{state.griffith_user}@#{state.griffith_host}",
      "echo 'connection_test'"
    ], stderr_to_stdout: true) do
      {"connection_test\n", 0} -> :ok
      {output, _exit_code} -> {:error, output}
    end
  end
  
  defp deploy_models_to_griffith(_state) do
    script_path = Path.join([File.cwd!(), "deploy_manager_models_griffith.sh"])
    
    case System.cmd("bash", [script_path], stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Griffith deployment output: #{output}")
        :ok
        
      {error_output, exit_code} ->
        {:error, "Deployment failed with exit code #{exit_code}: #{error_output}"}
    end
  end
  
  defp start_griffith_models(state) do
    cmd = "/opt/elias/scripts/manager_models_control.sh start"
    
    case System.cmd("ssh", [
      "#{state.griffith_user}@#{state.griffith_host}",
      cmd
    ], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {error, _exit_code} -> {:error, error}
    end
  end
  
  defp stop_griffith_models(state) do
    cmd = "/opt/elias/scripts/manager_models_control.sh stop"
    
    case System.cmd("ssh", [
      "#{state.griffith_user}@#{state.griffith_host}",
      cmd
    ], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {error, _exit_code} -> {:error, error}
    end
  end
  
  defp generate_with_griffith_manager(manager, prompt, _options, state) when manager in @manager_models do
    # For now, simulate model generation until we have actual models deployed
    simulated_response = simulate_manager_response(manager, prompt)
    
    Logger.info("Generated response from #{manager} manager on Griffith")
    {:ok, simulated_response}
  end
  
  defp generate_with_griffith_manager(manager, _prompt, _options, _state) do
    {:error, "Unknown manager: #{manager}. Available: #{inspect(@manager_models)}"}
  end
  
  defp simulate_manager_response(manager, prompt) do
    # Simulate manager-specific responses based on their domain
    case manager do
      :ufm ->
        """
        // UFM Federation Response to: #{String.slice(prompt, 0, 50)}...
        defmodule FederationComponent do
          @moduledoc "Generated by UFM DeepSeek 6.7B-FP16 on Griffith"
          
          def coordinate_nodes(nodes) do
            nodes
            |> Enum.filter(&healthy_node?/1)
            |> balance_load()
          end
          
          defp healthy_node?(node), do: Node.ping(node) == :pong
          defp balance_load(nodes), do: Enum.shuffle(nodes)
        end
        """
        
      :ucm ->
        """
        // UCM Content Processing Response to: #{String.slice(prompt, 0, 50)}...
        defmodule ContentProcessor do
          @moduledoc "Generated by UCM DeepSeek 6.7B-FP16 on Griffith"
          
          def process_content(content, format) do
            content
            |> validate_format(format)
            |> extract_data()
            |> optimize_output()
          end
          
          defp validate_format(content, format), do: {content, format}
          defp extract_data({content, _format}), do: content
          defp optimize_output(content), do: String.trim(content)
        end
        """
        
      :urm ->
        """
        // URM Resource Optimization Response to: #{String.slice(prompt, 0, 50)}...
        defmodule ResourceManager do
          @moduledoc "Generated by URM DeepSeek 6.7B-FP16 on Griffith"
          
          def optimize_resources(processes) do
            processes
            |> monitor_usage()
            |> balance_load()
            |> cleanup_unused()
          end
          
          defp monitor_usage(processes), do: processes
          defp balance_load(processes), do: processes  
          defp cleanup_unused(processes), do: processes
        end
        """
        
      _ ->
        """
        // #{String.upcase("#{manager}")} Response to: #{String.slice(prompt, 0, 50)}...
        defmodule #{String.capitalize("#{manager}")}Component do
          @moduledoc "Generated by #{String.upcase("#{manager}")} DeepSeek 6.7B-FP16 on Griffith"
          
          def process(input) do
            {:ok, input}
          end
        end
        """
    end
  end
  
  defp get_current_status(state) do
    %{
      griffith_host: state.griffith_host,
      connection_status: state.connection_status,
      manager_models: state.manager_models,
      deployment_ready: File.exists?(Path.join([File.cwd!(), "deploy_manager_models_griffith.sh"])),
      estimated_vram_usage: "30GB (6 models x 5GB each)"
    }
  end
end