defmodule Elias.ApeMacs do
  @moduledoc """
  ApeMacs Elixir Daemon - AI-powered terminal interface
  Persistent daemon for ApeMacs functionality integrated with ELIAS
  """
  
  use GenServer
  require Logger

  @default_port 4001
  @tmux_session "apemacs"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Logger.info("🚀 ApeMacs Daemon starting (ALWAYS ON mode)...")
    
    state = %{
      port: opts[:port] || @default_port,
      tmux_session: @tmux_session,
      active_conversations: %{},
      clipboard_history: [],
      terminal_history: [],
      running: true,
      always_on: true,  # Core principle: ALWAYS ON
      hidden: false,    # Can be hidden but still running
      auto_restart: true
    }
    
    # Initialize tmux session
    setup_tmux_session(state.tmux_session)
    
    Logger.info("✅ ApeMacs Daemon ALWAYS ON - ready on port #{state.port}")
    Logger.info("🔄 Auto-restart enabled - daemon will survive crashes")
    {:ok, state}
  end

  # Public API
  def send_to_claude(message) do
    # ApeMacs users talk to Claude DIRECTLY on their own account
    # This goes through user's Claude Pro/Max subscription, NOT through ELIAS pool
    GenServer.call(__MODULE__, {:claude_request, message})
  end
  
  def handle_request_result({:request_result, request_id, result}) do
    GenServer.cast(__MODULE__, {:request_result_received, request_id, result})
  end
  
  def execute_terminal_command(command, directory \\ ".") do
    # ApeMacs executes commands locally, doesn't need ELIAS pool for this
    GenServer.call(__MODULE__, {:terminal_command, command, directory})
  end
  
  def report_system_issue(issue_description, logs \\ []) do
    # Report problems to ELIAS for assistance
    case Elias.RequestPool.submit_request(:system_issue, %{
      description: issue_description,
      logs: logs,
      client_info: get_client_info()
    }) do
      {:ok, request_id} ->
        Logger.info("🚨 System issue reported to ELIAS: #{request_id}")
        {:ok, request_id}
      error ->
        error
    end
  end
  
  def request_feature(feature_description) do
    # Request new functionality from ELIAS
    case Elias.RequestPool.submit_request(:feature_request, %{
      description: feature_description,
      client_info: get_client_info()
    }) do
      {:ok, request_id} ->
        Logger.info("💡 Feature request submitted to ELIAS: #{request_id}")
        {:ok, request_id}
      error ->
        error
    end
  end
  
  def send_logs_to_elias do
    # Send system logs and performance data to ELIAS
    logs = collect_system_logs()
    case Elias.RequestPool.submit_request(:log_transmission, %{
      logs: logs,
      client_info: get_client_info(),
      timestamp: DateTime.utc_now()
    }) do
      {:ok, request_id} ->
        Logger.info("📊 Logs sent to ELIAS: #{request_id}")
        {:ok, request_id}
      error ->
        error
    end
  end
  
  def tmux_operation(operation, args \\ []) do
    GenServer.call(__MODULE__, {:tmux_operation, operation, args})
  end
  
  def get_clipboard() do
    GenServer.call(__MODULE__, :get_clipboard)
  end
  
  def set_clipboard(content) do
    GenServer.call(__MODULE__, {:set_clipboard, content})
  end
  
  def hide_daemon() do
    GenServer.call(__MODULE__, :hide)
  end
  
  def show_daemon() do
    GenServer.call(__MODULE__, :show)
  end
  
  def receive_apemacs_update(update_package) do
    # Receive APEMACS.md update from rule distributor
    GenServer.call(__MODULE__, {:receive_apemacs_update, update_package})
  end
  
  def toggle_visibility() do
    GenServer.call(__MODULE__, :toggle_visibility)
  end
  
  def force_shutdown() do
    Logger.warning("⚠️  Force shutdown requested - ApeMacs prefers ALWAYS ON mode")
    GenServer.call(__MODULE__, :force_shutdown)
  end

  # GenServer Callbacks
  def handle_call({:claude_request, message}, _from, state) do
    # Send to ELIAS daemon instead of direct Claude
    result = send_to_elias_daemon(message, state)
    
    # Store conversation
    conversation_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    updated_conversations = Map.put(state.active_conversations, conversation_id, %{
      request: message,
      response: result,
      timestamp: DateTime.utc_now()
    })
    
    new_state = %{state | active_conversations: updated_conversations}
    {:reply, result, new_state}
  end
  
  def handle_call({:terminal_command, command, directory}, _from, state) do
    Logger.info("🔧 Executing: #{command} in #{directory}")
    
    result = case System.cmd("bash", ["-c", command], cd: directory) do
      {output, 0} -> 
        {:ok, output}
      {error, code} -> 
        {:error, {code, error}}
    end
    
    # Store in history
    history_entry = %{
      command: command,
      directory: directory,
      result: result,
      timestamp: DateTime.utc_now()
    }
    
    new_history = [history_entry | state.terminal_history] |> Enum.take(100)
    new_state = %{state | terminal_history: new_history}
    
    {:reply, result, new_state}
  end
  
  def handle_call({:tmux_operation, operation, args}, _from, state) do
    result = case operation do
      :new_session -> 
        System.cmd("tmux", ["new-session", "-d", "-s"] ++ args)
        
      :new_window -> 
        System.cmd("tmux", ["new-window", "-t", state.tmux_session] ++ args)
        
      :split_pane -> 
        System.cmd("tmux", ["split-window", "-t", state.tmux_session] ++ args)
        
      :send_keys -> 
        System.cmd("tmux", ["send-keys", "-t", state.tmux_session] ++ args ++ ["Enter"])
        
      :list_sessions ->
        System.cmd("tmux", ["list-sessions"])
        
      :list_windows ->
        System.cmd("tmux", ["list-windows", "-t", state.tmux_session])
        
      _ -> 
        {:error, "Unknown tmux operation: #{operation}"}
    end
    
    {:reply, result, state}
  end
  
  def handle_call(:get_clipboard, _from, state) do
    result = case System.cmd("pbpaste", []) do
      {content, 0} -> {:ok, content}
      {error, code} -> {:error, {code, error}}
    end
    
    {:reply, result, state}
  end
  
  def handle_call({:set_clipboard, content}, _from, state) do
    result = case System.cmd("pbcopy", [], input: content) do
      {_, 0} -> 
        # Add to clipboard history
        history_entry = %{
          content: content,
          timestamp: DateTime.utc_now()
        }
        new_history = [history_entry | state.clipboard_history] |> Enum.take(50)
        new_state = %{state | clipboard_history: new_history}
        
        {:reply, {:ok, "Clipboard updated"}, new_state}
        
      {error, code} -> 
        {:reply, {:error, {code, error}}, state}
    end
    
    result
  end
  
  def handle_call({:receive_apemacs_update, update_package}, _from, state) do
    Logger.info("📋 Received APEMACS.md update v#{update_package.version} from #{update_package.source_node}")
    
    # Validate update package
    case validate_update_package(update_package) do
      :ok ->
        # Save the update to local APEMACS.md
        case apply_apemacs_update(update_package) do
          :ok ->
            Logger.info("✅ APEMACS.md updated successfully to v#{update_package.version}")
            
            # Register with rule distributor if not already registered
            Elias.RuleDistributor.register_client(node(), %{
              last_update: update_package.version,
              updated_at: DateTime.utc_now()
            })
            
            {:reply, {:ok, update_package.version}, state}
            
          {:error, reason} ->
            Logger.error("❌ Failed to apply APEMACS.md update: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
        
      {:error, reason} ->
        Logger.warning("⚠️ Invalid APEMACS.md update package: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:hide, _from, state) do
    Logger.info("👻 ApeMacs daemon hidden (but still running)")
    new_state = %{state | hidden: true}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:show, _from, state) do
    Logger.info("👁️  ApeMacs daemon visible")
    new_state = %{state | hidden: false}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:toggle_visibility, _from, state) do
    new_hidden = !state.hidden
    status = if new_hidden, do: "hidden", else: "visible"
    Logger.info("🔄 ApeMacs daemon now #{status}")
    
    new_state = %{state | hidden: new_hidden}
    {:reply, {:ok, status}, new_state}
  end
  
  def handle_call(:force_shutdown, _from, state) do
    Logger.warning("🛑 ApeMacs daemon force shutdown (against ALWAYS ON principle)")
    {:stop, :shutdown, :ok, state}
  end

  # Private Functions
  defp send_to_elias_daemon(message, state) do
    # Format message for ELIAS daemon
    daemon_request = %{
      source: "apemacs",
      message: message,
      context: %{
        session: state.tmux_session,
        terminal_history: Enum.take(state.terminal_history, 5),
        timestamp: DateTime.utc_now()
      }
    }
    
    # Send to ELIAS daemon via hot_load_rule
    rule_name = "apemacs_request_#{:crypto.strong_rand_bytes(4) |> Base.encode16()}"
    
    rule_code = """
    def handle_apemacs_request(request) do
      # Process ApeMacs request through ELIAS
      case request do
        %{message: msg, context: ctx} ->
          # This would be handled by Claude through the daemon
          Logger.info("📝 ApeMacs request: \#{msg}")
          
          # Return structured response
          {:ok, %{
            response: "ELIAS daemon processing: \#{msg}",
            suggestions: ["Try 'tmux list-sessions'", "Check 'git status'"],
            timestamp: DateTime.utc_now()
          }}
          
        _ -> 
          {:error, "Invalid ApeMacs request format"}
      end
    end
    """
    
    # Hot-load the rule and execute it
    case Elias.Daemon.hot_load_rule(rule_name, rule_code) do
      :ok ->
        Elias.Daemon.execute_rule(rule_name, [daemon_request])
      error ->
        Logger.error("Failed to send to ELIAS daemon: #{inspect(error)}")
        {:error, "ELIAS daemon unavailable"}
    end
  end
  
  # Helper functions for ELIAS communication
  
  defp get_client_info do
    %{
      node: node(),
      hostname: System.get_env("HOSTNAME", "unknown"),
      version: "1.0.0",
      os: System.get_env("OS", "unknown"),
      uptime: :erlang.statistics(:wall_clock)
    }
  end
  
  defp collect_system_logs do
    # Collect recent ApeMacs logs and system performance data
    %{
      apemacs_logs: get_recent_logs(),
      system_stats: get_system_stats(),
      error_logs: get_error_logs(),
      performance_metrics: get_performance_metrics()
    }
  end
  
  defp get_recent_logs do
    # Return recent log entries
    []  # Placeholder - would integrate with Logger
  end
  
  defp get_system_stats do
    %{
      memory_usage: :erlang.memory(),
      process_count: length(Process.list()),
      node_uptime: :erlang.statistics(:wall_clock)
    }
  end
  
  defp get_error_logs do
    # Return recent error logs  
    []  # Placeholder - would integrate with Logger
  end
  
  defp get_performance_metrics do
    %{
      command_execution_times: [],
      claude_response_times: [],
      system_responsiveness: "good"
    }
  end
  
  # APEMACS.md Update Functions
  
  defp validate_update_package(update_package) do
    required_fields = [:version, :content, :timestamp, :source_node, :checksum]
    
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(update_package, field) or is_nil(Map.get(update_package, field))
    end)
    
    if length(missing_fields) > 0 do
      {:error, {:missing_fields, missing_fields}}
    else
      # Validate checksum
      calculated_checksum = :crypto.hash(:sha256, update_package.content) 
                           |> Base.encode16(case: :lower)
      
      if calculated_checksum == update_package.checksum do
        :ok
      else
        {:error, :checksum_mismatch}
      end
    end
  end
  
  defp apply_apemacs_update(update_package) do
    # Determine where to save APEMACS.md
    apemacs_dir = Path.join([System.user_home(), ".apemacs"])
    File.mkdir_p!(apemacs_dir)
    
    apemacs_file = Path.join(apemacs_dir, "APEMACS.md")
    
    # Add version header to content
    versioned_content = """
    <!-- Version: #{update_package.version} -->
    <!-- Updated: #{update_package.timestamp} -->
    <!-- Source: #{update_package.source_node} -->
    
    #{update_package.content}
    """
    
    case File.write(apemacs_file, versioned_content) do
      :ok ->
        Logger.info("📁 APEMACS.md saved to #{apemacs_file}")
        
        # Create backup
        backup_file = Path.join(apemacs_dir, "APEMACS.#{update_package.version}.backup")
        File.write(backup_file, versioned_content)
        
        :ok
        
      {:error, reason} ->
        Logger.error("❌ Failed to write APEMACS.md: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp setup_tmux_session(session_name) do
    Logger.info("🖥️  Setting up tmux session: #{session_name}")
    
    # Check if session exists
    case System.cmd("tmux", ["has-session", "-t", session_name]) do
      {_, 0} -> 
        Logger.info("✅ Tmux session '#{session_name}' already exists")
        
      {_, _} ->
        # Create new session
        case System.cmd("tmux", ["new-session", "-d", "-s", session_name]) do
          {_, 0} -> 
            Logger.info("✅ Created tmux session '#{session_name}'")
            
            # Set up default windows
            System.cmd("tmux", ["new-window", "-t", session_name, "-n", "elias", 
              "cd /Users/mikesimka/elias-system/elias-elixir"])
            System.cmd("tmux", ["new-window", "-t", session_name, "-n", "code", 
              "cd /Users/mikesimka/elias-system"])
              
          {error, code} ->
            Logger.error("❌ Failed to create tmux session: #{error} (#{code})")
        end
    end
  end
  
  defp start_http_server(port) do
    Logger.info("🌐 Starting ApeMacs HTTP server on port #{port}")
    
    # This would be handled by a separate HTTP router
    # For now, just log that we would start it
    Logger.info("✅ ApeMacs HTTP server ready (placeholder)")
  end
end