defmodule ApemacsClient.Application do
  # ApeMacs Client (Gracey) - Always-On AI Assistant Client
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core ApeMacs daemon (always on)
      {ApemacsClient.Daemon, []},
      
      # Claude API integration (direct user connection)
      {ApemacsClient.ClaudeAPI, []},
      
      # Terminal and tmux integration
      {ApemacsClient.Terminal, []},
      
      # ELIAS communication (issues/features/logs only)
      {ApemacsClient.EliasClient, []},
      
      # Rule processor for APEMACS.md updates
      {ApemacsClient.RuleProcessor, []},
      
      # Local HTTP API for client operations
      {Plug.Cowboy, scheme: :http, plug: ApemacsClient.Router, options: [port: 4101]},
      
      # P2P connection to federation (lightweight client mode)
      {Cluster.Supervisor, [topologies(), [name: ApemacsClient.ClusterSupervisor]]},
      {Horde.Registry, [name: ApemacsClient.Registry, keys: :unique]}
    ]

    opts = [strategy: :one_for_one, name: ApemacsClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp topologies do
    [
      elias_federation: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"elias_server@172.20.35.144",  # Connect to Griffith Full Node
            :"apemacs_client@gracey"        # Self (for local development)
          ]
        ]
      ]
    ]
  end
end