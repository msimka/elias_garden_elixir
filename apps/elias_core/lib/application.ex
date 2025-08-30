defmodule Elias.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    node_type = System.get_env("ELIAS_NODE_TYPE", "full_node")
    
    children = base_children() ++ mode_specific_children(node_type)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elias.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp base_children do
    [
      # Core daemon - always running
      Elias.Daemon,
      
      # APE HARMONY blockchain for distributed coordination logging
      Elias.ApeHarmony,
      
      # Rule distributor for APEMACS.md updates
      Elias.RuleDistributor,
      
      # Request Pool - GenStage producer for distributed requests
      Elias.RequestPool,
      
      # Request Consumer - processes requests from pool
      Elias.RequestConsumer,
      
      # ApeMacs daemon with ALWAYS ON supervisor
      Elias.ApeMacsSupervisor,
      
      # P2P communication layer
      {Cluster.Supervisor, [topologies(), [name: Elias.ClusterSupervisor]]},
      
      # Distributed registry for P2P
      {Horde.Registry, [name: Elias.Registry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: Elias.DynamicSupervisor, strategy: :one_for_one]}
    ]
  end
  
  defp mode_specific_children("full_node") do
    [
      # HTTP server for ELIAS API (full node only)
      {Plug.Cowboy, scheme: :http, plug: Elias.Router, options: [port: 4000]},
      
      # HTTP server for ApeMacs API (full node only)
      {Plug.Cowboy, scheme: :http, plug: Elias.ApeMacsRouter, options: [port: 4001]},
      
      # Scheduled jobs (full node only)
      Elias.Scheduler
    ]
  end
  
  defp mode_specific_children("client") do
    [
      # Client-only HTTP server for local ApeMacs (different port)
      {Plug.Cowboy, scheme: :http, plug: Elias.ApeMacsRouter, options: [port: 4101]}
    ]
  end
  
  defp mode_specific_children(_), do: []

  defp topologies do
    [
      elias_cluster: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"elias@172.20.35.144",  # Griffith IP - Full node with DeepSeek  
            :"elias@gracey"          # MacBook - Client node
          ]
        ]
      ]
    ]
  end
end