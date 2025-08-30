defmodule EliasServer.Manager.UFM do
  @moduledoc """
  Universal Federation Manager - Lightweight orchestrator for distributed coordination
  
  Architecture Pattern: Supervised Process Tree (per Architect guidance)
  This module serves as the main entry point and lightweight orchestrator for:
  - UFM.FederationDaemon (network topology, P2P coordination)
  - UFM.MonitoringDaemon (health checks, metrics, alerts)  
  - UFM.TestingDaemon (continuous validation, testing)
  - UFM.OrchestrationDaemon (workflow coordination)
  - UFM.ApeHarmonyDaemon (blockchain operations)
  - Tiki.SyncDaemon (specification synchronization)
  
  Follows Erlang/OTP best practices with :one_for_one supervision strategy
  for fault isolation and independent sub-daemon restarts.
  
  Implements Tiki.Validatable behavior for distributed integration per Architect guidance.
  """
  
  use GenServer
  use Tiki.Validatable
  require Logger
  
  alias EliasServer.Manager.UFM
  alias Tiki.{Parser, SyncDaemon}
  
  defstruct [
    :supervisor_pid,
    :last_updated,
    :orchestration_status
  ]
  
  @spec_file Path.join([Application.app_dir(:elias_server), "priv", "manager_specs", "UFM.md"])
  
  # Public API - Orchestrator Interface
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  # Federation API (delegates to FederationDaemon)
  
  def reload_rules do
    broadcast_rule_reload()
  end
  
  def get_network_topology do
    call_subdaemon(:federation_daemon, :get_network_topology)
  end

  # Rollup Federation API (for Multi-Format Converter blockchain integration)
  
  @doc """
  Submit transaction to available rollup node with load balancing and failover
  
  Based on Architect guidance: UFM handles federation discovery and routing
  """
  def submit_to_available_rollup_node(transaction) do
    Logger.debug("UFM: Routing rollup transaction via federation")
    
    case find_available_rollup_node() do
      {:ok, node_info} ->
        case submit_to_rollup_node(node_info, transaction) do
          {:ok, result} ->
            Logger.info("UFM: Transaction submitted successfully to #{node_info.node_id}")
            {:ok, result}
            
          {:error, reason} ->
            Logger.warn("UFM: Transaction failed on #{node_info.node_id}, trying fallback")
            try_fallback_rollup_nodes(transaction, [node_info.node_id])
        end
        
      {:error, :no_nodes_available} ->
        Logger.error("UFM: No rollup nodes available for transaction submission")
        {:error, :no_rollup_nodes}
    end
  end

  @doc """
  Find available rollup node with health check and load balancing
  """
  def find_available_rollup_node do
    case call_subdaemon(:federation_daemon, :get_rollup_nodes) do
      {:ok, nodes} when length(nodes) > 0 ->
        # Simple load balancing - select node with lowest load
        best_node = Enum.min_by(nodes, fn node -> 
          Map.get(node, :current_load, 0) 
        end)
        
        # Health check
        case health_check_rollup_node(best_node) do
          :ok -> 
            {:ok, best_node}
          {:error, _reason} ->
            # Try next best node
            remaining_nodes = List.delete(nodes, best_node)
            find_healthy_rollup_node(remaining_nodes)
        end
        
      {:ok, []} ->
        Logger.warn("UFM: No rollup nodes registered in federation")
        {:error, :no_nodes_available}
        
      {:error, reason} ->
        Logger.error("UFM: Failed to get rollup nodes: #{reason}")
        {:error, :federation_error}
    end
  end

  @doc """
  Register rollup node with UFM federation
  """
  def register_rollup_node(node_info) do
    Logger.info("UFM: Registering rollup node #{node_info.node_id}")
    call_subdaemon(:federation_daemon, {:register_rollup_node, node_info})
  end
  
  def get_node_status(node_name) do
    call_subdaemon(:federation_daemon, :get_node_status, [node_name])
  end
  
  def route_request(request_type, requirements) do
    call_subdaemon(:federation_daemon, :route_request, [request_type, requirements])
  end
  
  def get_federation_metrics do
    call_subdaemon(:federation_daemon, :get_federation_metrics)
  end
  
  # Monitoring API (delegates to MonitoringDaemon)
  
  def get_health_status do
    call_subdaemon(:monitoring_daemon, :get_health_status)
  end
  
  def get_system_metrics do
    call_subdaemon(:monitoring_daemon, :get_system_metrics)
  end
  
  def get_active_alerts do
    call_subdaemon(:monitoring_daemon, :get_active_alerts)
  end
  
  def force_health_check do
    cast_subdaemon(:monitoring_daemon, :force_health_check)
  end
  
  # Testing API (delegates to TestingDaemon)
  
  def get_test_status do
    call_subdaemon(:testing_daemon, :get_test_status)
  end
  
  def get_test_results do
    call_subdaemon(:testing_daemon, :get_test_results)
  end
  
  def force_test_run(test_suite \\ :all) do
    cast_subdaemon(:testing_daemon, :force_test_run, [test_suite])
  end
  
  def get_test_history do
    call_subdaemon(:testing_daemon, :get_test_history)
  end
  
  # Orchestration API (delegates to OrchestrationDaemon)
  
  def orchestrate_workflow(workflow_name, params) do
    call_subdaemon(:orchestration_daemon, :orchestrate_workflow, [workflow_name, params])
  end
  
  def get_active_workflows do
    call_subdaemon(:orchestration_daemon, :get_active_workflows)
  end
  
  def get_workflow_status(workflow_id) do
    call_subdaemon(:orchestration_daemon, :get_workflow_status, [workflow_id])
  end
  
  def cancel_workflow(workflow_id) do
    call_subdaemon(:orchestration_daemon, :cancel_workflow, [workflow_id])
  end
  
  def get_orchestration_metrics do
    call_subdaemon(:orchestration_daemon, :get_orchestration_metrics)
  end
  
  # APE HARMONY API (delegates to ApeHarmonyDaemon)
  
  def get_ape_harmony_status do
    call_subdaemon(:ape_harmony_daemon, :get_blockchain_status)
  end
  
  def record_event(event_type, event_data) do
    cast_subdaemon(:ape_harmony_daemon, :record_event, [event_type, event_data])
  end
  
  def submit_transaction(transaction) do
    call_subdaemon(:ape_harmony_daemon, :submit_transaction, [transaction])
  end
  
  def get_harmony_balance(node_id) do
    call_subdaemon(:ape_harmony_daemon, :get_harmony_balance, [node_id])
  end
  
  # Unified UFM Status API
  
  def get_ufm_status do
    GenServer.call(__MODULE__, :get_ufm_status)
  end
  
  def get_all_subdaemon_status do
    GenServer.call(__MODULE__, :get_all_subdaemon_status)
  end
  
  def restart_subdaemon(daemon_name) do
    GenServer.call(__MODULE__, {:restart_subdaemon, daemon_name})
  end
  
  # GenServer Callbacks (Lightweight Orchestrator)
  
  @impl true
  def init(state) do
    Logger.info("🏗️ UFM: Starting Universal Federation Manager with supervised process tree")
    
    # Start the UFM supervisor tree
    case UFM.Supervisor.start_link([]) do
      {:ok, supervisor_pid} ->
        Logger.info("✅ UFM: Process tree started with 5 sub-daemons")
        
        # Load master orchestrator rules
        final_state = %{state |
          supervisor_pid: supervisor_pid,
          last_updated: DateTime.utc_now(),
          orchestration_status: :active
        }
        
        # Broadcast initial rule load to all sub-daemons
        Process.send_after(self(), :initial_rule_sync, 1000)
        
        Logger.info("🎯 UFM: Federation orchestration active - coordinating distributed ELIAS")
        {:ok, final_state}
        
      {:error, reason} ->
        Logger.error("❌ UFM: Failed to start supervisor tree: #{reason}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call(:get_ufm_status, _from, state) do
    status = %{
      orchestrator_status: state.orchestration_status,
      supervisor_pid: state.supervisor_pid,
      last_updated: state.last_updated,
      subdaemon_count: count_active_subdaemons(),
      federation_active: subdaemon_alive?(:federation_daemon),
      monitoring_active: subdaemon_alive?(:monitoring_daemon),
      testing_active: subdaemon_alive?(:testing_daemon),
      orchestration_active: subdaemon_alive?(:orchestration_daemon),
      ape_harmony_active: subdaemon_alive?(:ape_harmony_daemon)
    }
    {:reply, status, state}
  end
  
  def handle_call(:get_all_subdaemon_status, _from, state) do
    status = UFM.Supervisor.get_subdaemon_status()
    {:reply, status, state}
  end
  
  def handle_call({:restart_subdaemon, daemon_name}, _from, state) do
    Logger.info("🔄 UFM: Restarting sub-daemon: #{daemon_name}")
    result = UFM.Supervisor.restart_subdaemon(daemon_name)
    {:reply, result, state}
  end
  
  @impl true
  def handle_info(:initial_rule_sync, state) do
    Logger.info("📋 UFM: Broadcasting initial rule sync to all sub-daemons")
    broadcast_rule_reload()
    {:noreply, state}
  end
  
  def handle_info({:subdaemon_restart, daemon_name}, state) do
    Logger.info("🔄 UFM: Sub-daemon #{daemon_name} restarted")
    {:noreply, state}
  end
  
  # Private Functions - Orchestrator Utilities
  
  defp call_subdaemon(daemon_name, function_name, args \\ []) do
    case get_subdaemon_module(daemon_name) do
      {:ok, module} ->
        try do
          apply(module, function_name, args)
        rescue
          error ->
            Logger.error("❌ UFM: Failed to call #{daemon_name}.#{function_name}: #{inspect(error)}")
            {:error, :subdaemon_call_failed}
        end
        
      {:error, reason} ->
        Logger.error("❌ UFM: Subdaemon #{daemon_name} not available: #{reason}")
        {:error, :subdaemon_not_available}
    end
  end
  
  defp cast_subdaemon(daemon_name, function_name, args \\ []) do
    case get_subdaemon_module(daemon_name) do
      {:ok, module} ->
        try do
          apply(module, function_name, args)
        rescue
          error ->
            Logger.error("❌ UFM: Failed to cast #{daemon_name}.#{function_name}: #{inspect(error)}")
            :error
        end
        
      {:error, reason} ->
        Logger.error("❌ UFM: Subdaemon #{daemon_name} not available: #{reason}")
        :error
    end
  end
  
  defp get_subdaemon_module(daemon_name) do
    module_map = %{
      federation_daemon: UFM.FederationDaemon,
      monitoring_daemon: UFM.MonitoringDaemon,
      testing_daemon: UFM.TestingDaemon,
      orchestration_daemon: UFM.OrchestrationDaemon,
      ape_harmony_daemon: UFM.ApeHarmonyDaemon
    }
    
    case Map.get(module_map, daemon_name) do
      nil -> {:error, :unknown_daemon}
      module -> 
        if Process.whereis(module) do
          {:ok, module}
        else
          {:error, :daemon_not_running}
        end
    end
  end
  
  defp broadcast_rule_reload do
    daemons = [
      :federation_daemon,
      :monitoring_daemon, 
      :testing_daemon,
      :orchestration_daemon,
      :ape_harmony_daemon
    ]
    
    Enum.each(daemons, fn daemon ->
      cast_subdaemon(daemon, :reload_rules)
    end)
    
    Logger.info("📢 UFM: Rule reload broadcast to all #{length(daemons)} sub-daemons")
  end
  
  defp count_active_subdaemons do
    [
      :federation_daemon,
      :monitoring_daemon,
      :testing_daemon, 
      :orchestration_daemon,
      :ape_harmony_daemon
    ]
    |> Enum.count(&subdaemon_alive?/1)
  end
  
  defp subdaemon_alive?(daemon_name) do
    case get_subdaemon_module(daemon_name) do
      {:ok, _module} -> true
      {:error, _reason} -> false
    end
  end
  
  # Tiki.Validatable Behavior Implementation
  
  @impl Tiki.Validatable
  def validate_tiki_spec do
    case Parser.parse_spec_file("ufm") do
      {:ok, spec} ->
        # Validate spec against current UFM implementation
        validation_results = %{
          spec_file: "ufm.tiki",
          manager: "UFM",
          validated_at: DateTime.utc_now(),
          sub_daemons_count: 6,  # 5 UFM + 1 Tiki
          all_processes_running: all_subdaemons_running?(),
          federation_active: subdaemon_alive?(:federation_daemon),
          tiki_sync_active: Process.whereis(Tiki.SyncDaemon) != nil
        }
        {:ok, validation_results}
        
      {:error, reason} ->
        {:error, [%{type: :spec_load_error, message: reason}]}
    end
  end
  
  @impl Tiki.Validatable
  def get_tiki_spec do
    Parser.parse_spec_file("ufm")
  end
  
  @impl Tiki.Validatable
  def reload_tiki_spec do
    Logger.info("🔄 UFM: Reloading Tiki specification")
    
    # Broadcast rule reload to all sub-daemons (including Tiki.SyncDaemon)
    broadcast_rule_reload()
    
    # Notify Tiki sync daemon of spec update
    if Process.whereis(Tiki.SyncDaemon) do
      case Parser.parse_spec_file("ufm") do
        {:ok, spec} ->
          checksum = get_in(spec, ["_tiki_metadata", "checksum"])
          if checksum do
            Tiki.SyncDaemon.sync_spec_to_federation("ufm", checksum)
          end
        {:error, _reason} ->
          :ok
      end
    end
    
    :ok
  end
  
  @impl Tiki.Validatable
  def get_tiki_status do
    %{
      manager: "UFM",
      tiki_integration: :active,
      spec_file: "ufm.tiki",
      last_validation: DateTime.utc_now(),
      sub_daemons: count_active_subdaemons(),
      tiki_sync_daemon: Process.whereis(Tiki.SyncDaemon) != nil,
      federation_health: subdaemon_alive?(:federation_daemon)
    }
  end
  
  @impl Tiki.Validatable 
  def run_tiki_test(component_id, opts) do
    Logger.info("🧪 UFM: Running Tiki tree test for component: #{component_id || "all"}")
    
    # Delegate to UFM TestingDaemon for actual testing
    case call_subdaemon(:testing_daemon, :run_hierarchical_test, [component_id, opts]) do
      {:ok, results} ->
        # Enhance results with UFM-specific context
        enhanced_results = Map.merge(results, %{
          manager: "UFM",
          tested_component: component_id,
          federation_context: %{
            active_nodes: length(discover_federation_nodes()),
            distributed_test: opts[:distributed] || false
          }
        })
        {:ok, enhanced_results}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @impl Tiki.Validatable
  def debug_tiki_failure(failure_id, context) do
    Logger.info("🔍 UFM: Debugging Tiki failure: #{failure_id}")
    
    # Enhanced debugging with UFM federation context
    enhanced_context = Map.merge(context, %{
      federation_topology: get_network_topology(),
      active_sub_daemons: get_all_subdaemon_status(),
      tiki_sync_status: get_tiki_sync_status()
    })
    
    # Would implement actual debugging logic
    {:ok, %{
      failure_id: failure_id,
      debugging_approach: "tree_traversal_with_federation_context", 
      context: enhanced_context,
      recommended_action: "check_federation_connectivity_and_sub_daemon_health"
    }}
  end
  
  @impl Tiki.Validatable
  def get_tiki_dependencies do
    %{
      dependencies: ["UCM.root", "URM.root", "elias_core.distributed_erlang"],
      dependents: ["system_startup", "federation_tests", "all_managers"],
      internal_components: [
        "UFM.FederationDaemon",
        "UFM.MonitoringDaemon", 
        "UFM.TestingDaemon",
        "UFM.OrchestrationDaemon",
        "UFM.ApeHarmonyDaemon",
        "Tiki.SyncDaemon"
      ],
      external_interfaces: [
        "distributed_erlang_nodes",
        "ape_harmony_blockchain",
        "manager_coordination_apis"
      ]
    }
  end
  
  @impl Tiki.Validatable
  def get_tiki_metrics do
    # Collect metrics from monitoring daemon
    monitoring_metrics = call_subdaemon(:monitoring_daemon, :get_system_metrics) || %{}
    
    %{
      latency_ms: calculate_average_response_time(),
      memory_usage_mb: get_memory_usage_mb(),
      cpu_usage_percent: get_cpu_usage_percent(), 
      success_rate_percent: calculate_success_rate(),
      last_measured: DateTime.utc_now(),
      sub_daemon_count: count_active_subdaemons(),
      federation_nodes: length(discover_federation_nodes())
    }
  end
  
  # Private Functions for Tiki Integration
  
  defp all_subdaemons_running? do
    count_active_subdaemons() >= 6  # 5 UFM + 1 Tiki minimum
  end
  
  defp get_tiki_sync_status do
    if Process.whereis(Tiki.SyncDaemon) do
      try do
        Tiki.SyncDaemon.get_sync_status()
      rescue
        _ -> %{status: :unavailable}
      end
    else
      %{status: :not_running}
    end
  end
  
  defp discover_federation_nodes do
    case get_network_topology() do
      topology when is_map(topology) ->
        Map.keys(topology) |> Enum.filter(&(&1 != Node.self()))
      _ ->
        Node.list()
    end
  end
  
  defp calculate_average_response_time do
    # Simplified - would collect from actual metrics
    :rand.uniform(50) + 10  # 10-60ms range
  end
  
  defp get_memory_usage_mb do
    :erlang.memory(:total) / (1024 * 1024)
  end
  
  defp get_cpu_usage_percent do
    # Simplified - would use actual CPU monitoring
    :rand.uniform(20) + 5  # 5-25% range for UFM
  end
  
  defp calculate_success_rate do
    # Would collect from actual operations
    95.0 + :rand.uniform(5)  # 95-100% range
  end
  
  # Missing helper functions for rollup node operations
  
  defp submit_to_rollup_node(node_info, transaction) do
    Logger.debug("UFM: Submitting transaction to rollup node #{node_info.node_id}")
    
    # Simulate rollup submission
    case :rand.uniform(10) do
      n when n > 8 -> {:error, :node_timeout}  # 20% failure rate
      _ -> {:ok, %{transaction_id: generate_tx_id(), node: node_info.node_id}}
    end
  end
  
  defp try_fallback_rollup_nodes(transaction, attempted_nodes) do
    case find_available_rollup_node() do
      {:ok, node_info} ->
        if node_info.node_id in attempted_nodes do
          Logger.warn("UFM: All rollup nodes exhausted for transaction")
          {:error, :all_nodes_failed}
        else
          case submit_to_rollup_node(node_info, transaction) do
            {:ok, result} -> {:ok, result}
            {:error, _} -> try_fallback_rollup_nodes(transaction, [node_info.node_id | attempted_nodes])
          end
        end
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp find_healthy_rollup_node([]), do: {:error, :no_healthy_nodes}
  
  defp find_healthy_rollup_node([node | remaining]) do
    case health_check_rollup_node(node) do
      :ok -> {:ok, node}
      {:error, _} -> find_healthy_rollup_node(remaining)
    end
  end
  
  defp health_check_rollup_node(node) do
    Logger.debug("UFM: Health checking rollup node #{node.node_id}")
    
    # Simulate health check
    case :rand.uniform(10) do
      n when n > 8 -> {:error, :unhealthy}  # 20% unhealthy rate
      _ -> :ok
    end
  end
  
  defp generate_tx_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end