defmodule Elias.ApeMacsCLI do
  @moduledoc """
  ApeMacs Command Line Interface
  Terminal interface for interacting with ApeMacs daemon
  """
  
  require Logger

  def main(args \\ []) do
    case args do
      [] -> 
        interactive_mode()
        
      ["start"] ->
        start_daemon()
        
      ["hide"] ->
        hide_daemon()
        
      ["show"] ->
        show_daemon()
        
      ["toggle"] ->
        toggle_visibility()
        
      ["force-stop"] ->
        force_stop_daemon()
        
      ["status"] ->
        show_status()
        
      ["claude" | message_parts] ->
        message = Enum.join(message_parts, " ")
        send_claude_message(message)
        
      ["tmux", operation | tmux_args] ->
        tmux_command(operation, tmux_args)
        
      ["clipboard", "get"] ->
        get_clipboard()
        
      ["clipboard", "set" | content_parts] ->
        content = Enum.join(content_parts, " ")
        set_clipboard(content)
        
      ["exec" | command_parts] ->
        command = Enum.join(command_parts, " ")
        execute_command(command)
        
      _ ->
        show_help()
    end
  end

  defp interactive_mode() do
    IO.puts("""
    🤖 ApeMacs v2.0 - Elixir Daemon
    ================================
    
    Welcome to ApeMacs interactive mode!
    Type 'help' for commands or 'quit' to exit.
    """)
    
    interactive_loop()
  end

  defp interactive_loop() do
    input = IO.gets("apemacs> ") |> String.trim()
    
    case input do
      "quit" -> 
        IO.puts("👋 Goodbye!")
        
      "help" ->
        show_help()
        interactive_loop()
        
      "hide" ->
        hide_daemon()
        interactive_loop()
        
      "show" ->
        show_daemon()
        interactive_loop()
        
      "toggle" ->
        toggle_visibility()
        interactive_loop()
        
      "status" ->
        show_status()
        interactive_loop()
        
      "clear" ->
        IO.write("\e[H\e[2J")
        interactive_loop()
        
      "" ->
        interactive_loop()
        
      command ->
        process_interactive_command(command)
        interactive_loop()
    end
  end

  defp process_interactive_command("claude " <> message) do
    send_claude_message(message)
  end
  
  defp process_interactive_command("tmux " <> tmux_cmd) do
    [operation | args] = String.split(tmux_cmd)
    tmux_command(operation, args)
  end
  
  defp process_interactive_command("exec " <> command) do
    execute_command(command)
  end
  
  defp process_interactive_command(command) do
    IO.puts("❓ Unknown command: #{command}")
    IO.puts("Type 'help' for available commands")
  end

  defp start_daemon() do
    IO.puts("🚀 Starting ApeMacs daemon...")
    
    case Elias.ApeMacs.start_link() do
      {:ok, _pid} -> 
        IO.puts("✅ ApeMacs daemon started successfully")
        
      {:error, {:already_started, _}} ->
        IO.puts("ℹ️  ApeMacs daemon already running")
        
      {:error, reason} ->
        IO.puts("❌ Failed to start ApeMacs daemon: #{inspect(reason)}")
    end
  end

  defp hide_daemon() do
    IO.puts("👻 Hiding ApeMacs daemon (still running in background)...")
    
    case Elias.ApeMacs.hide_daemon() do
      :ok -> 
        IO.puts("✅ ApeMacs daemon hidden (ALWAYS ON)")
      {:error, reason} ->
        IO.puts("❌ Failed to hide daemon: #{inspect(reason)}")
    end
  end
  
  defp show_daemon() do
    IO.puts("👁️  Showing ApeMacs daemon...")
    
    case Elias.ApeMacs.show_daemon() do
      :ok -> 
        IO.puts("✅ ApeMacs daemon visible")
      {:error, reason} ->
        IO.puts("❌ Failed to show daemon: #{inspect(reason)}")
    end
  end
  
  defp toggle_visibility() do
    IO.puts("🔄 Toggling ApeMacs visibility...")
    
    case Elias.ApeMacs.toggle_visibility() do
      {:ok, status} -> 
        IO.puts("✅ ApeMacs daemon now #{status}")
      {:error, reason} ->
        IO.puts("❌ Failed to toggle visibility: #{inspect(reason)}")
    end
  end
  
  defp force_stop_daemon() do
    IO.puts("⚠️  FORCE STOPPING ApeMacs daemon (against ALWAYS ON principle)...")
    IO.puts("Are you sure? ApeMacs is designed to be ALWAYS ON. [y/N]")
    
    case IO.gets("") |> String.trim() |> String.downcase() do
      "y" ->
        case Elias.ApeMacs.force_shutdown() do
          :ok -> 
            IO.puts("💀 ApeMacs daemon force stopped (will auto-restart)")
          {:error, reason} ->
            IO.puts("❌ Failed to force stop: #{inspect(reason)}")
        end
      _ ->
        IO.puts("✅ Cancelled - ApeMacs remains ALWAYS ON")
    end
  end

  defp show_status() do
    try do
      # Try to contact the daemon
      case HTTPoison.get("http://localhost:4001/api/status") do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          status = Jason.decode!(body)
          IO.puts("""
          📊 ApeMacs Status
          ================
          Status: #{status["status"]}
          Version: #{status["version"]}
          Uptime: #{status["uptime"]}s
          """)
          
        _ ->
          IO.puts("❌ ApeMacs daemon is not running")
      end
    rescue
      _ ->
        IO.puts("❌ Unable to connect to ApeMacs daemon")
    end
  end

  defp send_claude_message(message) do
    IO.puts("💭 Sending to Claude: #{message}")
    
    case Elias.ApeMacs.send_to_claude(message) do
      {:ok, response} ->
        IO.puts("🤖 Claude: #{inspect(response)}")
        
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  defp tmux_command(operation, args) do
    IO.puts("🖥️  Tmux #{operation}: #{inspect(args)}")
    
    case Elias.ApeMacs.tmux_operation(String.to_atom(operation), args) do
      {output, 0} ->
        IO.puts("✅ #{String.trim(output)}")
        
      {error, code} ->
        IO.puts("❌ Error (#{code}): #{String.trim(error)}")
        
      {:error, reason} ->
        IO.puts("❌ #{reason}")
    end
  end

  defp get_clipboard() do
    case Elias.ApeMacs.get_clipboard() do
      {:ok, content} ->
        IO.puts("📋 Clipboard: #{String.trim(content)}")
        
      {:error, reason} ->
        IO.puts("❌ Clipboard error: #{inspect(reason)}")
    end
  end

  defp set_clipboard(content) do
    case Elias.ApeMacs.set_clipboard(content) do
      {:ok, _} ->
        IO.puts("✅ Clipboard updated")
        
      {:error, reason} ->
        IO.puts("❌ Clipboard error: #{inspect(reason)}")
    end
  end

  defp execute_command(command) do
    IO.puts("🔧 Executing: #{command}")
    
    case Elias.ApeMacs.execute_terminal_command(command) do
      {:ok, output} ->
        IO.puts("✅ Output:")
        IO.puts(output)
        
      {:error, {code, error}} ->
        IO.puts("❌ Error (#{code}):")
        IO.puts(error)
    end
  end

  defp show_help() do
    IO.puts("""
    📚 ApeMacs Commands
    ==================
    
    Daemon Control (ALWAYS ON):
      start                 - Start ApeMacs daemon (if not running)
      hide                  - Hide daemon (still running in background)
      show                  - Show daemon
      toggle                - Toggle visibility
      force-stop            - Force stop (against ALWAYS ON principle)
      status                - Show daemon status
    
    AI Interaction:
      claude <message>      - Send message to Claude via ELIAS
    
    Terminal:
      exec <command>        - Execute shell command
      tmux <operation>      - Tmux operations (new-session, list-sessions, etc.)
    
    Clipboard:
      clipboard get         - Get clipboard contents
      clipboard set <text>  - Set clipboard contents
    
    Interactive Mode:
      help                  - Show this help
      clear                 - Clear screen
      quit                  - Exit ApeMacs
    """)
  end
end