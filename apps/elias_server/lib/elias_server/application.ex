defmodule EliasServer.Application do
  # ELIAS Server (Griffith Full Node) - Complete Distributed AI Operating System
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core ELIAS components from elias_core
      {EliasCore.Daemon, []},
      {EliasCore.ApeHarmony, []},
      {EliasCore.RequestPool, []},
      {EliasCore.RequestConsumer, []},
      {EliasCore.RuleDistributor, []},
      
      # Manager Supervisor - All 5 deterministic manager daemons
      EliasServer.ManagerSupervisor,
      
      # ML Integration (Python via Ports)
      EliasServer.Geppetto,
      
      # Full node HTTP APIs
      {Plug.Cowboy, scheme: :http, plug: EliasServer.Router, options: [port: 4000]},
      
      # Scheduled jobs for full node operations
      EliasServer.Scheduler,
      
      # P2P cluster coordination
      {Cluster.Supervisor, [topologies(), [name: EliasServer.ClusterSupervisor]]},
      {Horde.Registry, [name: EliasServer.Registry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: EliasServer.DynamicSupervisor, strategy: :one_for_one]}
    ]

    opts = [strategy: :one_for_one, name: EliasServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp topologies do
    [
      elias_federation: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"elias_server@172.20.35.144",  # Griffith Full Node
            :"apemacs_client@gracey"        # Gracey Client Node
          ]
        ]
      ]
    ]
  end
end