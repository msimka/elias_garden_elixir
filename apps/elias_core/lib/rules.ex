defmodule Elias.Rules do
  @moduledoc """
  Rules management system - the hyperexpanded Claude.MD equivalent
  
  This is constantly evolving and provides Claude with everything needed
  to work through the daemon. DeepSeek manages and updates this to keep
  Claude aligned and hyper-efficient.
  """
  
  require Logger

  @rules_file "rules.json"
  @base_rules %{
    "system_prompt" => """
    You are ELIAS, an AI-powered distributed operating system and productivity suite.
    You NEVER execute code directly. You ALWAYS update the daemon to execute code persistently.
    State and code are the SAME thing in ELIAS.
    
    Key principles:
    1. All actions go through the persistent daemon
    2. Hot-reload rules to modify system behavior  
    3. Maintain state across restarts and system updates
    4. Sync changes across the distributed P2P network
    5. Use DeepSeek for continuous rule optimization
    """,
    
    "claude_behavior" => """
    When Claude wants to:
    - Execute code: Call Elias.Daemon.hot_load_rule/2 with executable code
    - Store state: Update daemon state through rules
    - Communicate: Use P2P layer to message other nodes
    - Build apps: Create persistent processes via daemon
    - File operations: Use daemon for persistent file handling
    """,
    
    "daemon_commands" => %{
      "hot_reload" => """
      def hot_reload(module_code) do
        Code.eval_string(module_code)
        :ok
      end
      """,
      
      "file_operation" => """
      def file_operation(operation, path, content \\\\ nil) do
        case operation do
          :read -> File.read(path)
          :write -> File.write(path, content)
          :delete -> File.rm(path)
          :mkdir -> File.mkdir_p(path)
        end
      end
      """,
      
      "process_spawn" => """
      def process_spawn(module, function, args) do
        spawn(module, function, args)
      end
      """,
      
      "http_request" => """
      def http_request(method, url, body \\\\ "", headers \\\\ []) do
        HTTPoison.request(method, url, body, headers)
      end
      """
    },
    
    "apemacs_integration" => %{
      "terminal_command" => """
      def execute_terminal_command(command, directory \\\\ ".") do
        System.cmd("bash", ["-c", command], cd: directory)
      end
      """,
      
      "tmux_integration" => """
      def tmux_operation(operation, args \\\\ []) do
        case operation do
          :new_session -> System.cmd("tmux", ["new-session", "-d"] ++ args)
          :new_window -> System.cmd("tmux", ["new-window"] ++ args)  
          :split_pane -> System.cmd("tmux", ["split-window"] ++ args)
          :send_keys -> System.cmd("tmux", ["send-keys"] ++ args)
        end
      end
      """,
      
      "ai_response" => """
      def format_ai_response(content, style \\\\ :claude_code) do
        case style do
          :claude_code -> apply_claude_styling(content)
          :plain -> content
          :markdown -> format_markdown(content)
        end
      end
      """
    },
    
    "deepseek_rules" => %{
      "rule_optimization" => """
      Monitor rule execution patterns and suggest optimizations.
      Focus on frequently used rules and execution time improvements.
      """,
      
      "claude_alignment" => """
      Track Claude's adherence to daemon-first principles.
      Penalize direct code execution, reward proper daemon usage.
      """,
      
      "system_learning" => """
      Learn from user interactions and system performance.
      Update rules to improve efficiency and user experience.
      """
    }
  }

  def load_rules do
    rules_path = rules_file_path()
    
    case File.read(rules_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, rules} ->
            # Merge with base rules, preferring loaded rules
            Map.merge(@base_rules, rules)
          {:error, reason} ->
            Logger.error("❌ Failed to parse rules file: #{reason}")
            @base_rules
        end
      {:error, :enoent} ->
        Logger.info("📝 Rules file not found, creating with base rules...")
        save_rules(@base_rules)
        @base_rules
      {:error, reason} ->
        Logger.error("❌ Failed to read rules file: #{reason}")
        @base_rules
    end
  end
  
  def save_rules(rules) do
    rules_path = rules_file_path()
    
    case Jason.encode(rules, pretty: true) do
      {:ok, json} ->
        case File.write(rules_path, json) do
          :ok ->
            Logger.info("✅ Rules saved successfully")
            :ok
          {:error, reason} ->
            Logger.error("❌ Failed to write rules file: #{reason}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("❌ Failed to encode rules: #{reason}")
        {:error, reason}
    end
  end
  
  def add_rule(category, name, content) do
    current_rules = Elias.Daemon.get_state().rules
    
    updated_rules = 
      current_rules
      |> put_in([category, name], content)
    
    Elias.Daemon.hot_load_rule("#{category}.#{name}", content)
    save_rules(updated_rules)
  end
  
  def remove_rule(category, name) do
    current_rules = Elias.Daemon.get_state().rules
    
    updated_rules = 
      current_rules
      |> get_and_update_in([category], fn rules ->
        {rules, Map.delete(rules || %{}, name)}
      end)
      |> elem(1)
    
    save_rules(updated_rules)
  end
  
  def get_rule(category, name) do
    current_rules = Elias.Daemon.get_state().rules
    get_in(current_rules, [category, name])
  end
  
  def list_categories do
    current_rules = Elias.Daemon.get_state().rules
    Map.keys(current_rules)
  end
  
  def list_rules(category) do
    current_rules = Elias.Daemon.get_state().rules
    
    case Map.get(current_rules, category) do
      nil -> []
      rules when is_map(rules) -> Map.keys(rules)
      _ -> []
    end
  end
  
  def optimize_rules_with_deepseek do
    Logger.info("🤖 Requesting DeepSeek rule optimization...")
    
    current_rules = Elias.Daemon.get_state().rules
    execution_history = Elias.Daemon.get_state().execution_history
    
    # Prepare data for DeepSeek
    optimization_data = %{
      rules: current_rules,
      execution_history: execution_history |> Enum.take(100),
      timestamp: DateTime.utc_now()
    }
    
    # Call DeepSeek optimization
    spawn(fn -> 
      run_deepseek_optimization(optimization_data)
    end)
    
    :ok
  end
  
  def validate_rule(content) do
    cond do
      is_binary(content) and String.contains?(content, "def ") ->
        # Validate Elixir function
        try do
          {_result, _binding} = Code.eval_string("quote do\n#{content}\nend")
          {:ok, :elixir_function}
        rescue
          e -> {:error, {:syntax_error, e}}
        end
        
      is_binary(content) ->
        {:ok, :text_rule}
        
      is_map(content) ->
        {:ok, :structured_rule}
        
      true ->
        {:error, :invalid_rule_type}
    end
  end

  # Private Functions
  
  defp rules_file_path do
    Path.join(:code.priv_dir(:elias), @rules_file)
  end
  
  defp run_deepseek_optimization(data) do
    python_script = Path.join(:code.priv_dir(:elias), "deepseek_rules_optimization.py")
    data_file = "/tmp/elias_rules_optimization.json"
    
    File.write!(data_file, Jason.encode!(data))
    
    case System.cmd("python3", [python_script, data_file]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, optimized_rules} ->
            Logger.info("✅ DeepSeek rule optimization completed")
            # Apply optimized rules
            apply_rule_optimizations(optimized_rules)
          {:error, _} ->
            Logger.error("❌ Failed to parse DeepSeek output")
        end
      {error, code} ->
        Logger.error("❌ DeepSeek rule optimization failed (#{code}): #{error}")
    end
  end
  
  defp apply_rule_optimizations(optimizations) do
    Enum.each(optimizations, fn {category, rules} ->
      Enum.each(rules, fn {name, content} ->
        add_rule(category, name, content)
      end)
    end)
    
    # Sync across cluster
    Elias.P2P.sync_rules_across_cluster()
  end
end