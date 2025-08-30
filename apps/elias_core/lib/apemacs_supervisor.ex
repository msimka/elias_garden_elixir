defmodule Elias.ApeMacsSupervisor do
  @moduledoc """
  ApeMacs Supervisor - Ensures ALWAYS ON behavior
  Implements aggressive restart strategies to maintain 24/7 operation
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("🛡️  ApeMacs Supervisor starting - ALWAYS ON protection")
    
    children = [
      # ApeMacs daemon with restart strategy
      %{
        id: Elias.ApeMacs,
        start: {Elias.ApeMacs, :start_link, [[]]},
        restart: :permanent,  # Always restart if it crashes
        shutdown: 5000,       # Give it 5 seconds to shutdown gracefully
        type: :worker
      }
    ]

    # Aggressive restart strategy for ALWAYS ON
    opts = [
      strategy: :one_for_one,
      max_restarts: 10,     # Allow up to 10 restarts
      max_seconds: 60       # Within 60 seconds
    ]

    Logger.info("✅ ApeMacs ALWAYS ON protection active")
    Supervisor.init(children, opts)
  end
  
  def restart_daemon() do
    Logger.info("🔄 Manual restart of ApeMacs daemon requested")
    
    case Supervisor.terminate_child(__MODULE__, Elias.ApeMacs) do
      :ok ->
        case Supervisor.restart_child(__MODULE__, Elias.ApeMacs) do
          {:ok, _} -> 
            Logger.info("✅ ApeMacs daemon restarted successfully")
            :ok
          {:error, reason} ->
            Logger.error("❌ Failed to restart ApeMacs daemon: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to terminate ApeMacs daemon: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  def get_daemon_status() do
    children = Supervisor.which_children(__MODULE__)
    
    case Enum.find(children, fn {id, _, _, _} -> id == Elias.ApeMacs end) do
      {Elias.ApeMacs, pid, :worker, [Elias.ApeMacs]} when is_pid(pid) ->
        %{
          status: :running,
          pid: pid,
          always_on: true,
          restart_count: get_restart_count(pid)
        }
        
      {Elias.ApeMacs, :undefined, :worker, [Elias.ApeMacs]} ->
        %{
          status: :restarting,
          pid: nil,
          always_on: true,
          restart_count: "unknown"
        }
        
      nil ->
        %{
          status: :not_found,
          pid: nil,
          always_on: false,
          restart_count: 0
        }
    end
  end
  
  defp get_restart_count(pid) do
    # This is a simplified implementation
    # In production, you might want to track this in the daemon state
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        Keyword.get(dict, :restart_count, 0)
      _ ->
        0
    end
  end
end