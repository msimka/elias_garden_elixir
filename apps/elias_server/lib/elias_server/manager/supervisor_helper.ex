defmodule EliasServer.Manager.SupervisorHelper do
  @moduledoc """
  Reusable supervisor template for ELIAS Manager process trees.
  
  Provides standardized supervision patterns following Architect guidance:
  - :one_for_one strategy for independent subsystems
  - :transient restart for abnormal exits
  - Registry for dynamic sub-daemon lookup
  - Built-in telemetry and logging
  """

  @doc """
  Creates a standardized supervisor spec for a manager's process tree.
  
  ## Parameters
  - `manager_name`: Atom identifier (e.g., :ufm, :urm)
  - `sub_daemons`: List of {module, args} tuples for child processes
  - `strategy`: Supervision strategy (defaults to :one_for_one)
  
  ## Example
      children = [
        {UFM.FederationDaemon, []},
        {UFM.MonitoringDaemon, []},
        {UFM.TestingDaemon, []}
      ]
      
      SupervisorHelper.manager_supervisor_spec(:ufm, children)
  """
  def manager_supervisor_spec(manager_name, sub_daemons, strategy \\ :one_for_one) do
    supervisor_name = Module.concat([EliasServer.Manager, String.upcase(to_string(manager_name)), Supervisor])
    
    children = Enum.map(sub_daemons, fn {module, args} ->
      %{
        id: module,
        start: {module, :start_link, [args]},
        restart: :transient,  # Restart on abnormal exit only
        shutdown: 5_000,      # 5 second graceful shutdown
        type: :worker
      }
    end)
    
    opts = [
      strategy: strategy,
      name: supervisor_name,
      max_restarts: 3,
      max_seconds: 5
    ]
    
    {supervisor_name, children, opts}
  end

  @doc """
  Start a manager's process tree supervisor.
  """
  def start_manager_supervisor(manager_name, sub_daemons, strategy \\ :one_for_one) do
    {supervisor_name, children, opts} = manager_supervisor_spec(manager_name, sub_daemons, strategy)
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        setup_manager_registry(manager_name)
        {:ok, pid}
      error -> error
    end
  end

  @doc """
  Setup Registry for sub-daemon lookup within a manager.
  """
  def setup_manager_registry(manager_name) do
    registry_name = registry_name(manager_name)
    
    case Registry.start_link(keys: :unique, name: registry_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @doc """
  Register a sub-daemon in the manager's registry.
  """
  def register_sub_daemon(manager_name, daemon_type, pid \\ self()) do
    registry_name = registry_name(manager_name)
    Registry.register(registry_name, daemon_type, pid)
  end

  @doc """
  Find a sub-daemon by type within a manager.
  """
  def find_sub_daemon(manager_name, daemon_type) do
    registry_name = registry_name(manager_name)
    
    case Registry.lookup(registry_name, daemon_type) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
      multiple -> {:error, {:multiple_found, multiple}}
    end
  end

  @doc """
  Get all sub-daemons for a manager.
  """
  def list_sub_daemons(manager_name) do
    registry_name = registry_name(manager_name)
    Registry.select(registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Send message to a specific sub-daemon type.
  """
  def cast_to_sub_daemon(manager_name, daemon_type, message) do
    case find_sub_daemon(manager_name, daemon_type) do
      {:ok, pid} -> GenServer.cast(pid, message)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Call a specific sub-daemon type.
  """
  def call_sub_daemon(manager_name, daemon_type, message, timeout \\ 5000) do
    case find_sub_daemon(manager_name, daemon_type) do
      {:ok, pid} -> GenServer.call(pid, message, timeout)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Broadcast message to all sub-daemons in a manager.
  """
  def broadcast_to_sub_daemons(manager_name, message) do
    manager_name
    |> list_sub_daemons()
    |> Enum.each(fn {_type, pid} ->
      GenServer.cast(pid, message)
    end)
  end

  # Private helper functions

  defp registry_name(manager_name) do
    Module.concat([EliasServer.Manager, String.upcase(to_string(manager_name)), Registry])
  end

  @doc """
  Standard telemetry events for manager supervision.
  """
  def emit_telemetry(manager_name, event, metadata \\ %{}) do
    :telemetry.execute(
      [:elias, :manager, String.to_atom(to_string(manager_name)), event],
      %{timestamp: System.monotonic_time()},
      metadata
    )
  end

  @doc """
  Standard logging for manager events.
  """
  def log_manager_event(manager_name, level, message, metadata \\ []) do
    require Logger
    
    formatted_message = "[#{String.upcase(to_string(manager_name))}] #{message}"
    
    case level do
      :debug -> Logger.debug(formatted_message, metadata)
      :info -> Logger.info(formatted_message, metadata)
      :warn -> Logger.warn(formatted_message, metadata)
      :error -> Logger.error(formatted_message, metadata)
    end
  end

  @doc """
  Health check for all sub-daemons in a manager.
  """
  def health_check(manager_name) do
    sub_daemons = list_sub_daemons(manager_name)
    
    results = Enum.map(sub_daemons, fn {type, pid} ->
      status = if Process.alive?(pid) do
        :healthy
      else
        :unhealthy
      end
      
      {type, status, pid}
    end)
    
    overall_status = if Enum.all?(results, fn {_type, status, _pid} -> status == :healthy end) do
      :healthy
    else
      :degraded
    end
    
    %{
      overall_status: overall_status,
      sub_daemons: results,
      total_count: length(results),
      healthy_count: Enum.count(results, fn {_type, status, _pid} -> status == :healthy end)
    }
  end
end