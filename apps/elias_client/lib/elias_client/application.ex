defmodule EliasClient.Application do
  @moduledoc """
  ELIAS Distributed OS Client - Lightweight Overlay Client
  
  Connects to federated ELIAS server network for:
  - Package management via URM/UPM
  - Resource allocation and distributed services
  - AI-driven optimization via ULM
  
  Runs minimal managers: UIM (interface) + UCM (communication)
  """
  
  use Application

  def start(_type, _args) do
    children = [
      # Core client managers
      {EliasClient.Manager.UIM, []},  # Interface management
      {EliasClient.Manager.UCM, []},  # Communication with servers
      
      # Client services
      {EliasClient.PackageClient, []}, # UPM client interface
      {EliasClient.ServerDiscovery, []}, # Find ELIAS server nodes
      {EliasClient.LocalCache, []}     # Local caching for performance
    ]
    
    opts = [strategy: :one_for_one, name: EliasClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end