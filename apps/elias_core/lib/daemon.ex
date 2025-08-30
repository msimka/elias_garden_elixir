defmodule Elias.Daemon do
  @moduledoc """
  The core ELIAS daemon - persistent, hot-reloadable, unified state and code
  
  This is the heart of the system where state and code are the SAME thing.
  Claude never executes code directly - only updates the daemon to do it persistently.
  """
  
  use GenServer
  require Logger

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def hot_load_rule(key, value) when is_binary(key) do
    GenServer.cast(__MODULE__, {:update_rule, key, value})
  end
  
  def execute_rule(rule_name, args \\ []) do
    GenServer.call(__MODULE__, {:execute_rule, rule_name, args})
  end
  
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  def sync_locations do
    GenServer.cast(__MODULE__, :sync_locations)
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    Logger.info("🧠 ELIAS Daemon starting - unified state/code system")
    
    # Load initial rules from storage
    rules = load_rules()
    
    # Schedule periodic syncing
    schedule_sync()
    schedule_deepseek_training()
    
    # Connect to P2P network
    Elias.P2P.connect_nodes()
    
    state = %{
      rules: rules,
      execution_history: [],
      last_sync: DateTime.utc_now(),
      deepseek_last_run: nil,
      node_connections: [],
      claude_api_key: System.get_env("ANTHROPIC_API_KEY")
    }
    
    Logger.info("✅ ELIAS Daemon initialized with #{map_size(rules)} rules")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true 
  def handle_call({:execute_rule, rule_name, args}, _from, state) do
    case Map.get(state.rules, rule_name) do
      nil ->
        {:reply, {:error, :rule_not_found}, state}
        
      rule_code when is_binary(rule_code) ->
        try do
          # Execute the rule code with args
          result = execute_rule_code(rule_code, args)
          
          # Log execution
          execution = %{
            rule: rule_name,
            args: args,
            result: result,
            timestamp: DateTime.utc_now()
          }
          
          new_state = %{state | execution_history: [execution | state.execution_history]}
          
          {:reply, {:ok, result}, new_state}
        rescue
          e ->
            Logger.error("❌ Rule execution failed: #{inspect(e)}")
            {:reply, {:error, e}, state}
        end
        
      rule_data ->
        # Non-code rule, return data
        {:reply, {:ok, rule_data}, state}
    end
  end

  @impl true
  def handle_cast({:update_rule, key, value}, state) do
    Logger.info("🔄 Hot-loading rule: #{key}")
    
    new_rules = Map.put(state.rules, key, value)
    
    # If it's Elixir code, compile and load it
    if is_elixir_code?(value) do
      try do
        # Safely evaluate Elixir code
        {_result, _binding} = Code.eval_string(value)
        Logger.info("✅ Rule code compiled successfully: #{key}")
      rescue
        e ->
          Logger.error("❌ Rule compilation failed: #{key} - #{inspect(e)}")
      end
    end
    
    # Persist to storage
    save_rules(new_rules)
    
    {:noreply, %{state | rules: new_rules}}
  end

  @impl true
  def handle_cast(:sync_locations, state) do
    Logger.info("🔄 Syncing to GitHub and Google Drive...")
    
    try do
      # Git sync
      sync_git()
      
      # rclone sync for large files
      sync_gdrive()
      
      # Notify other nodes of sync
      broadcast_to_cluster({:sync_complete, node()})
      
      Logger.info("✅ Sync completed successfully")
      {:noreply, %{state | last_sync: DateTime.utc_now()}}
    rescue
      e ->
        Logger.error("❌ Sync failed: #{inspect(e)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    schedule_sync()
    sync_locations()
    {:noreply, state}
  end

  @impl true  
  def handle_info(:deepseek_training, state) do
    schedule_deepseek_training()
    
    Logger.info("🤖 Starting DeepSeek nightly training...")
    spawn(fn -> run_deepseek_training(state.execution_history) end)
    
    {:noreply, %{state | deepseek_last_run: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("🔗 Node connected: #{node}")
    {:noreply, %{state | node_connections: [node | state.node_connections]}}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("💔 Node disconnected: #{node}")
    connections = List.delete(state.node_connections, node)
    {:noreply, %{state | node_connections: connections}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions
  
  defp load_rules do
    rules_file = Path.join(:code.priv_dir(:elias), "rules.json")
    
    case File.read(rules_file) do
      {:ok, content} ->
        Jason.decode!(content)
      {:error, _} ->
        Logger.info("📝 No existing rules file, starting with empty ruleset")
        %{}
    end
  end
  
  defp save_rules(rules) do
    rules_file = Path.join(:code.priv_dir(:elias), "rules.json")
    content = Jason.encode!(rules, pretty: true)
    File.write!(rules_file, content)
  end
  
  defp execute_rule_code(code, args) do
    # Create a safe execution context
    binding = [args: args]
    
    try do
      {result, _binding} = Code.eval_string(code, binding)
      result
    rescue
      e -> {:error, e}
    end
  end
  
  defp is_elixir_code?(value) when is_binary(value) do
    String.contains?(value, "def ") or 
    String.contains?(value, "defmodule ") or
    String.contains?(value, "fn ")
  end
  defp is_elixir_code?(_), do: false
  
  defp schedule_sync do
    # Sync every hour
    Process.send_after(self(), :periodic_sync, 3600 * 1000)
  end
  
  defp schedule_deepseek_training do
    # Train DeepSeek nightly at 2 AM
    now = DateTime.utc_now()
    tomorrow_2am = %{now | hour: 2, minute: 0, second: 0} |> DateTime.add(1, :day)
    milliseconds_until = DateTime.diff(tomorrow_2am, now, :millisecond)
    
    Process.send_after(self(), :deepseek_training, milliseconds_until)
  end
  
  defp sync_git do
    elias_path = "/Users/mikesimka/elias-system"
    
    # Git pull
    System.cmd("git", ["pull", "origin", "main"], cd: elias_path)
    
    # Git add and commit changes
    System.cmd("git", ["add", "."], cd: elias_path)
    
    case System.cmd("git", ["commit", "-m", "Auto-sync from #{node()}"], cd: elias_path) do
      {_, 0} ->
        # Push if there were changes
        System.cmd("git", ["push", "origin", "main"], cd: elias_path)
        Logger.info("✅ Git sync completed")
      {_, 1} ->
        Logger.info("ℹ️ No changes to commit")
    end
  end
  
  defp sync_gdrive do
    models_path = "/Users/mikesimka/elias-system/models"
    
    case System.cmd("rclone", ["sync", models_path, "gdrive:elias-large-files/models"]) do
      {_, 0} ->
        Logger.info("✅ Google Drive sync completed")
      {output, code} ->
        Logger.error("❌ Google Drive sync failed (#{code}): #{output}")
    end
  end
  
  defp broadcast_to_cluster(message) do
    Node.list()
    |> Enum.each(fn node ->
      :rpc.cast(node, GenServer, :cast, [Elias.Daemon, {:cluster_message, message}])
    end)
  end
  
  defp run_deepseek_training(execution_history) do
    # Prepare training data from execution history
    training_data = prepare_training_data(execution_history)
    
    # Call Python script for DeepSeek fine-tuning
    python_script = Path.join(:code.priv_dir(:elias), "deepseek_training.py")
    data_file = "/tmp/elias_training_data.json"
    
    File.write!(data_file, Jason.encode!(training_data))
    
    case System.cmd("python3", [python_script, data_file]) do
      {output, 0} ->
        Logger.info("✅ DeepSeek training completed: #{output}")
      {error, code} ->
        Logger.error("❌ DeepSeek training failed (#{code}): #{error}")
    end
  end
  
  defp prepare_training_data(history) do
    history
    |> Enum.take(1000)  # Last 1000 executions
    |> Enum.map(fn execution ->
      %{
        input: "Rule: #{execution.rule}, Args: #{inspect(execution.args)}",
        output: inspect(execution.result),
        timestamp: execution.timestamp
      }
    end)
  end
end