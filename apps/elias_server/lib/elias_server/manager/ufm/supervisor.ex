defmodule EliasServer.Manager.UFM.Supervisor do
  @moduledoc """
  UFM Supervision Tree - Manages all Universal Federation Manager sub-daemons
  
  Architecture per Architect guidance:
  - :one_for_one strategy for independent fault isolation
  - Sub-daemons: Federation, Monitoring, Testing, Orchestration, ApeHarmony
  - Registry for dynamic sub-daemon lookup
  - Hierarchical Tiki specs support
  """
  
  use Supervisor
  require Logger
  
  alias EliasServer.Manager.SupervisorHelper
  alias EliasServer.Manager.UFM
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    Logger.info("🏗️ UFM.Supervisor: Starting Federation Manager process tree")
    
    # Register sub-daemon namespace
    SupervisorHelper.setup_registry(:ufm_subdaemons)
    
    children = [
      # Core federation daemon (always first)
      {UFM.FederationDaemon, []},
      
      # Independent monitoring daemon
      {UFM.MonitoringDaemon, []},
      
      # Continuous testing daemon  
      {UFM.TestingDaemon, []},
      
      # Workflow orchestration daemon
      {UFM.OrchestrationDaemon, []},
      
      # APE HARMONY blockchain daemon
      {UFM.ApeHarmonyDaemon, []},
      
      # Tiki integration sub-daemons (per Architect distributed integration guidance)
      {Tiki.SyncDaemon, []}
    ]
    
    Logger.info("✅ UFM.Supervisor: Process tree configured with #{length(children)} sub-daemons")
    
    # :one_for_one = each child independent, restart only failed ones
    # :transient = restart on abnormal exit only
    Supervisor.init(children, strategy: :one_for_one, restart: :transient)
  end
  
  # Public API for managing sub-daemons
  
  def get_subdaemon_status do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {id, pid, type, modules} ->
      status = if Process.alive?(pid), do: :running, else: :stopped
      %{
        daemon: id,
        pid: pid,
        type: type,
        modules: modules,
        status: status
      }
    end)
  end
  
  def restart_subdaemon(daemon_name) do
    case Supervisor.restart_child(__MODULE__, daemon_name) do
      {:ok, _pid} -> 
        Logger.info("🔄 UFM.Supervisor: Restarted #{daemon_name}")
        :ok
      {:error, reason} ->
        Logger.error("❌ UFM.Supervisor: Failed to restart #{daemon_name}: #{reason}")
        {:error, reason}
    end
  end
  
  def get_subdaemon_pid(daemon_name) do
    SupervisorHelper.lookup_process(:ufm_subdaemons, daemon_name)
  end
end