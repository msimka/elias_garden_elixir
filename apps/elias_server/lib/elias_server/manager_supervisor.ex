defmodule EliasServer.ManagerSupervisor do
  @moduledoc """
  Supervisor for all 6 deterministic manager daemons.
  Each manager is an always-on GenServer that loads its behavior from .md files.
  """
  
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Priority 1: Network/P2P Management
      {EliasServer.Manager.UFM, []},
      
      # Priority 2: Communication/Request Orchestration  
      {EliasServer.Manager.UCM, []},
      
      # Priority 3: AI Asset Management
      {EliasServer.Manager.UAM, []},
      
      # Priority 4: Interface Management (MacGyver)
      {EliasServer.Manager.UIM, []},
      
      # Priority 5: Resource Management
      {EliasServer.Manager.URM, []},
      
      # Priority 6: Learning and Harmonization Management
      {EliasServer.Manager.ULM, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Reload rules for a specific manager from its .md file
  """
  def reload_manager_rules(manager_name) when manager_name in [:UFM, :UCM, :UAM, :UIM, :URM, :ULM] do
    manager_module = Module.concat([EliasServer.Manager, manager_name])
    manager_module.reload_rules()
  end

  @doc """
  Reload rules for all managers (triggered by rule distribution updates)
  """
  def reload_all_manager_rules do
    [:UFM, :UCM, :UAM, :UIM, :URM, :ULM]
    |> Enum.each(&reload_manager_rules/1)
  end

  @doc """
  Get status of all manager daemons
  """
  def manager_status do
    [:UFM, :UCM, :UAM, :UIM, :URM, :ULM]
    |> Enum.map(fn manager_name ->
      manager_module = Module.concat([EliasServer.Manager, manager_name])
      
      status = case GenServer.whereis(manager_module) do
        nil -> :not_running
        pid when is_pid(pid) -> :running
      end
      
      {manager_name, status}
    end)
    |> Map.new()
  end
end