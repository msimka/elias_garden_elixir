defmodule EliasCore.RuleDistributor do
  @moduledoc """
  Rule distribution system for .md file updates (APEMACS.md, manager specs)
  Coordinates hot-reload of rules across the federation via P2P network
  """
  
  use GenServer
  require Logger

  defstruct [
    :watched_files,
    :file_checksums,
    :distribution_log,
    :client_registry
  ]

  # Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def distribute_rule_update(rule_type, file_path, content) do
    GenServer.cast(__MODULE__, {:distribute_update, rule_type, file_path, content})
  end

  def register_client(client_node, rule_types) do
    GenServer.cast(__MODULE__, {:register_client, client_node, rule_types})
  end

  def get_distribution_status do
    GenServer.call(__MODULE__, :get_distribution_status)
  end

  def force_sync_rules do
    GenServer.cast(__MODULE__, :force_sync_rules)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📡 EliasCore.RuleDistributor starting rule distribution system...")
    
    # Watch for file changes
    watched_files = get_watched_files()
    
    state = %__MODULE__{
      watched_files: watched_files,
      file_checksums: %{},
      distribution_log: [],
      client_registry: %{}
    }
    
    # Initialize file checksums
    initial_state = initialize_file_watching(state)
    
    # Schedule periodic sync check
    schedule_sync_check()
    
    Logger.info("✅ EliasCore.RuleDistributor initialized, watching #{map_size(watched_files)} files")
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_distribution_status, _from, state) do
    status = %{
      watched_files_count: map_size(state.watched_files),
      registered_clients: map_size(state.client_registry),
      distributions_sent: length(state.distribution_log),
      last_distribution: List.first(state.distribution_log)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:distribute_update, rule_type, file_path, content}, state) do
    Logger.info("📤 Distributing rule update: #{rule_type} (#{file_path})")
    
    # Create update package
    update_package = create_update_package(rule_type, file_path, content)
    
    # Get target clients for this rule type
    target_clients = get_clients_for_rule_type(state.client_registry, rule_type)
    
    # Distribute to clients
    distribution_results = distribute_to_clients(target_clients, update_package)
    
    # Log distribution event
    distribution_event = %{
      timestamp: DateTime.utc_now(),
      rule_type: rule_type,
      file_path: file_path,
      target_clients: target_clients,
      results: distribution_results,
      checksum: update_package.checksum
    }
    
    # Update file checksum
    file_checksums = Map.put(state.file_checksums, file_path, update_package.checksum)
    
    # Log to blockchain
    EliasCore.ApeHarmony.record_event("rule_distributed", %{
      rule_type: rule_type,
      target_count: length(target_clients),
      successful_count: count_successful_distributions(distribution_results)
    })
    
    new_state = %{state |
      file_checksums: file_checksums,
      distribution_log: [distribution_event | state.distribution_log]
    }
    
    {:noreply, new_state}
  end

  def handle_cast({:register_client, client_node, rule_types}, state) do
    Logger.info("🔌 Client registered: #{client_node} for #{inspect(rule_types)}")
    
    client_registry = Map.put(state.client_registry, client_node, %{
      rule_types: rule_types,
      registered_at: DateTime.utc_now(),
      last_seen: DateTime.utc_now()
    })
    
    new_state = %{state | client_registry: client_registry}
    {:noreply, new_state}
  end

  def handle_cast(:force_sync_rules, state) do
    Logger.info("🔄 Force syncing all rules to clients...")
    
    # Check all watched files and distribute updates
    updated_state = state.watched_files
    |> Enum.reduce(state, fn {file_path, rule_type}, acc_state ->
      case File.read(file_path) do
        {:ok, content} ->
          current_checksum = calculate_checksum(content)
          stored_checksum = Map.get(acc_state.file_checksums, file_path)
          
          if current_checksum != stored_checksum do
            Logger.info("📝 File changed, distributing: #{file_path}")
            
            # Create and distribute update
            update_package = create_update_package(rule_type, file_path, content)
            target_clients = get_clients_for_rule_type(acc_state.client_registry, rule_type)
            distribution_results = distribute_to_clients(target_clients, update_package)
            
            # Update state
            new_checksums = Map.put(acc_state.file_checksums, file_path, current_checksum)
            distribution_event = %{
              timestamp: DateTime.utc_now(),
              rule_type: rule_type,
              file_path: file_path,
              target_clients: target_clients,
              results: distribution_results,
              checksum: current_checksum
            }
            
            %{acc_state |
              file_checksums: new_checksums,
              distribution_log: [distribution_event | acc_state.distribution_log]
            }
          else
            acc_state
          end
        
        {:error, reason} ->
          Logger.warning("⚠️ Could not read file #{file_path}: #{reason}")
          acc_state
      end
    end)
    
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:sync_check, state) do
    # Periodically check for file changes
    GenServer.cast(self(), :force_sync_rules)
    schedule_sync_check()
    {:noreply, state}
  end

  def handle_info({:rule_update_response, client_node, success}, state) do
    Logger.debug("📨 Rule update response from #{client_node}: #{success}")
    
    # Update client last_seen timestamp
    client_registry = case Map.get(state.client_registry, client_node) do
      nil -> 
        state.client_registry
      
      client_info ->
        updated_info = %{client_info | last_seen: DateTime.utc_now()}
        Map.put(state.client_registry, client_node, updated_info)
    end
    
    new_state = %{state | client_registry: client_registry}
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled RuleDistributor message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private Functions

  defp get_watched_files do
    case EliasCore.node_type() do
      :full_node ->
        %{
          # Manager specification files
          "/Users/mikesimka/elias_garden_elixir/apps/elias_server/priv/manager_specs/UFM.md" => :manager_rules,
          "/Users/mikesimka/elias_garden_elixir/apps/elias_server/priv/manager_specs/UCM.md" => :manager_rules,
          "/Users/mikesimka/elias_garden_elixir/apps/elias_server/priv/manager_specs/UAM.md" => :manager_rules,
          "/Users/mikesimka/elias_garden_elixir/apps/elias_server/priv/manager_specs/UIM.md" => :manager_rules,
          "/Users/mikesimka/elias_garden_elixir/apps/elias_server/priv/manager_specs/URM.md" => :manager_rules,
          
          # APEMACS rules for distribution to clients
          "/Users/mikesimka/.apemacs/APEMACS.md" => :apemacs_rules
        }
      
      :client ->
        %{
          # Only watch APEMACS.md on clients
          "/Users/mikesimka/.apemacs/APEMACS.md" => :apemacs_rules
        }
    end
  end

  defp initialize_file_watching(state) do
    file_checksums = state.watched_files
    |> Enum.map(fn {file_path, _rule_type} ->
      checksum = case File.read(file_path) do
        {:ok, content} -> calculate_checksum(content)
        {:error, _} -> nil
      end
      {file_path, checksum}
    end)
    |> Map.new()
    
    %{state | file_checksums: file_checksums}
  end

  defp create_update_package(rule_type, file_path, content) do
    checksum = calculate_checksum(content)
    
    %{
      rule_type: rule_type,
      file_path: file_path,
      content: content,
      checksum: checksum,
      version: generate_version(),
      updated_at: DateTime.utc_now(),
      source_node: node()
    }
  end

  defp calculate_checksum(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp generate_version do
    DateTime.utc_now() |> DateTime.to_string() |> String.replace(" ", "T")
  end

  defp get_clients_for_rule_type(client_registry, rule_type) do
    client_registry
    |> Enum.filter(fn {_node, info} -> rule_type in info.rule_types end)
    |> Enum.map(fn {node, _info} -> node end)
  end

  defp distribute_to_clients([], _update_package), do: []
  
  defp distribute_to_clients(target_clients, update_package) do
    target_clients
    |> Enum.map(fn client_node ->
      result = send_update_to_client(client_node, update_package)
      {client_node, result}
    end)
  end

  defp send_update_to_client(client_node, update_package) do
    try do
      # Send via P2P network
      EliasCore.P2P.send_to_node(client_node, {:rule_update, update_package})
      
      # Wait for acknowledgment (with timeout)
      receive do
        {:rule_update_response, ^client_node, success} -> 
          if success, do: :ok, else: :error
      after
        5000 -> :timeout
      end
    rescue
      e ->
        Logger.error("❌ Failed to send rule update to #{client_node}: #{inspect(e)}")
        :error
    end
  end

  defp count_successful_distributions(distribution_results) do
    distribution_results
    |> Enum.count(fn {_client, result} -> result == :ok end)
  end

  defp schedule_sync_check do
    # Check for file changes every 30 seconds
    Process.send_after(self(), :sync_check, 30_000)
  end
end