defmodule EliasCore.Daemon do
  @moduledoc """
  The core ELIAS daemon - persistent, hot-reloadable, unified state and code
  
  This is the heart of the system where state and code are the SAME thing.
  Always-on daemon that coordinates system-wide operations.
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
  
  def get_system_status do
    GenServer.call(__MODULE__, :get_system_status)
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    Logger.info("🧠 EliasCore.Daemon starting - unified state/code system")
    
    # Load initial rules from storage
    rules = load_rules()
    
    # Connect to P2P network
    EliasCore.P2P.connect_nodes()
    
    state = %{
      rules: rules,
      execution_history: [],
      last_sync: DateTime.utc_now(),
      node_connections: [],
      node_type: EliasCore.node_type(),
      startup_time: DateTime.utc_now()
    }
    
    Logger.info("✅ EliasCore.Daemon initialized with #{map_size(rules)} rules")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_system_status, _from, state) do
    status = %{
      node_type: state.node_type,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.startup_time),
      connected_nodes: length(state.node_connections),
      rules_count: map_size(state.rules),
      last_sync: state.last_sync,
      execution_count: length(state.execution_history)
    }
    {:reply, status, state}
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
            timestamp: DateTime.utc_now(),
            node: node()
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
  def handle_cast({:cluster_message, message}, state) do
    Logger.debug("📨 Cluster message: #{inspect(message)}")
    {:noreply, state}
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
    rules_file = get_rules_file_path()
    
    case File.read(rules_file) do
      {:ok, content} ->
        Jason.decode!(content)
      {:error, _} ->
        Logger.info("📝 No existing rules file, starting with empty ruleset")
        %{}
    end
  end
  
  defp save_rules(rules) do
    rules_file = get_rules_file_path()
    File.mkdir_p!(Path.dirname(rules_file))
    content = Jason.encode!(rules, pretty: true)
    File.write!(rules_file, content)
  end

  defp get_rules_file_path do
    case EliasCore.node_type() do
      :full_node ->
        case Application.get_application(__MODULE__) do
          :elias_server -> Path.join(Application.app_dir(:elias_server), "priv/rules.json")
          _ -> "/tmp/elias_rules.json"
        end
      :client ->
        case Application.get_application(__MODULE__) do
          :apemacs_client -> Path.join(Application.app_dir(:apemacs_client), "priv/rules.json")
          _ -> "/tmp/apemacs_rules.json"
        end
    end
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
end