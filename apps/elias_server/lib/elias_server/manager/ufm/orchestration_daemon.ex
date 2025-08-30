defmodule EliasServer.Manager.UFM.OrchestrationDaemon do
  @moduledoc """
  UFM Orchestration Sub-Daemon - Always-on workflow orchestration and coordination
  
  Responsibilities:
  - Multi-manager workflow orchestration
  - Complex task coordination across distributed nodes
  - Workflow state management and recovery
  - Resource allocation for orchestrated processes
  - Hot-reload from UFM_Orchestration.md spec
  
  Follows "always-on daemon" philosophy - never stops orchestrating!
  """
  
  use GenServer
  require Logger
  
  alias EliasServer.Manager.SupervisorHelper
  
  defstruct [
    :rules,
    :last_updated,
    :checksum,
    :active_workflows,
    :workflow_templates,
    :orchestration_queue,
    :workflow_history,
    :resource_allocations,
    :workflow_monitor_timer,
    :queue_processor_timer
  ]
  
  @spec_file Path.join([Application.app_dir(:elias_server), "priv", "manager_specs", "UFM_Orchestration.md"])
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def orchestrate_workflow(workflow_name, params) do
    GenServer.call(__MODULE__, {:orchestrate_workflow, workflow_name, params})
  end
  
  def get_active_workflows do
    GenServer.call(__MODULE__, :get_active_workflows)
  end
  
  def get_workflow_status(workflow_id) do
    GenServer.call(__MODULE__, {:get_workflow_status, workflow_id})
  end
  
  def cancel_workflow(workflow_id) do
    GenServer.call(__MODULE__, {:cancel_workflow, workflow_id})
  end
  
  def get_workflow_templates do
    GenServer.call(__MODULE__, :get_workflow_templates)
  end
  
  def get_orchestration_metrics do
    GenServer.call(__MODULE__, :get_orchestration_metrics)
  end
  
  def reload_rules do
    GenServer.cast(__MODULE__, :reload_rules)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("🎭 UFM.OrchestrationDaemon: Starting always-on workflow orchestration daemon")
    
    # Register in sub-daemon registry
    SupervisorHelper.register_process(:ufm_subdaemons, :orchestration_daemon, self())
    
    # Load orchestration rules from hierarchical spec
    new_state = load_orchestration_rules(state)
    
    # Initialize orchestration state
    initial_state = %{new_state |
      active_workflows: %{},
      workflow_templates: load_workflow_templates(new_state.rules),
      orchestration_queue: :queue.new(),
      workflow_history: [],
      resource_allocations: %{}
    }
    
    # Start continuous orchestration processes
    final_state = start_orchestration_timers(initial_state)
    
    Logger.info("✅ UFM.OrchestrationDaemon: Always-on orchestration active - ready to coordinate workflows!")
    {:ok, final_state}
  end
  
  @impl true
  def handle_call({:orchestrate_workflow, workflow_name, params}, _from, state) do
    workflow_id = generate_workflow_id()
    Logger.info("🚀 UFM.OrchestrationDaemon: Starting workflow '#{workflow_name}' (ID: #{workflow_id})")
    
    case create_workflow_instance(workflow_name, params, workflow_id, state) do
      {:ok, workflow_instance, updated_state} ->
        # Start workflow execution
        final_state = begin_workflow_execution(workflow_instance, updated_state)
        {:reply, {:ok, workflow_id}, final_state}
        
      {:error, reason} ->
        Logger.error("❌ UFM.OrchestrationDaemon: Failed to create workflow '#{workflow_name}': #{reason}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_active_workflows, _from, state) do
    workflow_summary = state.active_workflows
    |> Enum.map(fn {id, workflow} ->
      %{
        id: id,
        name: workflow.name,
        status: workflow.status,
        started_at: workflow.started_at,
        current_step: workflow.current_step,
        progress: calculate_workflow_progress(workflow)
      }
    end)
    {:reply, workflow_summary, state}
  end
  
  def handle_call({:get_workflow_status, workflow_id}, _from, state) do
    case Map.get(state.active_workflows, workflow_id) do
      nil -> {:reply, {:error, :workflow_not_found}, state}
      workflow -> {:reply, {:ok, workflow}, state}
    end
  end
  
  def handle_call({:cancel_workflow, workflow_id}, _from, state) do
    case Map.get(state.active_workflows, workflow_id) do
      nil -> 
        {:reply, {:error, :workflow_not_found}, state}
      workflow ->
        Logger.info("🛑 UFM.OrchestrationDaemon: Cancelling workflow #{workflow_id}")
        updated_state = cancel_workflow_execution(workflow, state)
        {:reply, :ok, updated_state}
    end
  end
  
  def handle_call(:get_workflow_templates, _from, state) do
    {:reply, state.workflow_templates, state}
  end
  
  def handle_call(:get_orchestration_metrics, _from, state) do
    metrics = %{
      active_workflows: map_size(state.active_workflows),
      queued_workflows: :queue.len(state.orchestration_queue),
      total_workflows_run: length(state.workflow_history),
      resource_utilization: calculate_resource_utilization(state.resource_allocations)
    }
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_cast(:reload_rules, state) do
    Logger.info("🔄 UFM.OrchestrationDaemon: Hot-reloading orchestration rules")
    new_state = load_orchestration_rules(state)
    updated_state = apply_orchestration_rule_changes(state, new_state)
    {:noreply, updated_state}
  end
  
  @impl true
  def handle_info(:workflow_monitor_cycle, state) do
    # Monitor all active workflows - never stops checking
    updated_state = monitor_active_workflows(state)
    
    # Schedule next monitoring cycle
    monitor_timer = schedule_workflow_monitoring(updated_state.rules)
    final_state = %{updated_state | workflow_monitor_timer: monitor_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:queue_processor_cycle, state) do
    # Process orchestration queue - always running
    updated_state = process_orchestration_queue(state)
    
    # Schedule next queue processing
    queue_timer = schedule_queue_processing(updated_state.rules)
    final_state = %{updated_state | queue_processor_timer: queue_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info({:workflow_step_completed, workflow_id, step_result}, state) do
    Logger.debug("✅ UFM.OrchestrationDaemon: Workflow #{workflow_id} step completed")
    
    case Map.get(state.active_workflows, workflow_id) do
      nil ->
        Logger.warning("⚠️ UFM.OrchestrationDaemon: Received step completion for unknown workflow #{workflow_id}")
        {:noreply, state}
      workflow ->
        updated_state = advance_workflow_step(workflow, step_result, state)
        {:noreply, updated_state}
    end
  end
  
  def handle_info({:workflow_completed, workflow_id, final_result}, state) do
    Logger.info("🎯 UFM.OrchestrationDaemon: Workflow #{workflow_id} completed successfully")
    updated_state = complete_workflow(workflow_id, final_result, state)
    {:noreply, updated_state}
  end
  
  def handle_info({:workflow_failed, workflow_id, error}, state) do
    Logger.error("💥 UFM.OrchestrationDaemon: Workflow #{workflow_id} failed: #{inspect(error)}")
    updated_state = fail_workflow(workflow_id, error, state)
    {:noreply, updated_state}
  end
  
  # Private Functions
  
  defp load_orchestration_rules(state) do
    case File.read(@spec_file) do
      {:ok, content} ->
        {rules, checksum} = parse_orchestration_md_rules(content)
        %{state |
          rules: rules,
          last_updated: DateTime.utc_now(),
          checksum: checksum
        }
      {:error, reason} ->
        Logger.error("❌ UFM.OrchestrationDaemon: Could not load UFM_Orchestration.md: #{reason}")
        # Use default orchestration rules
        %{state |
          rules: default_orchestration_rules(),
          last_updated: DateTime.utc_now()
        }
    end
  end
  
  defp parse_orchestration_md_rules(content) do
    # Extract orchestration-specific YAML configuration
    [frontmatter_str | _] = String.split(content, "---", parts: 3, trim: true)
    
    frontmatter = YamlElixir.read_from_string(frontmatter_str) || %{}
    checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    
    rules = %{
      workflow_monitor_interval: get_in(frontmatter, ["orchestration", "monitor_interval"]) || 10000,
      queue_processor_interval: get_in(frontmatter, ["orchestration", "queue_interval"]) || 5000,
      max_concurrent_workflows: get_in(frontmatter, ["orchestration", "max_concurrent"]) || 10,
      workflow_timeout_minutes: get_in(frontmatter, ["orchestration", "timeout_minutes"]) || 60,
      retry_failed_steps: get_in(frontmatter, ["orchestration", "retry_failed_steps"]) || true,
      max_step_retries: get_in(frontmatter, ["orchestration", "max_retries"]) || 3
    }
    
    {rules, checksum}
  end
  
  defp default_orchestration_rules do
    %{
      workflow_monitor_interval: 10000,    # 10 seconds - active monitoring
      queue_processor_interval: 5000,     # 5 seconds - queue processing
      max_concurrent_workflows: 10,       # Limit concurrent workflows
      workflow_timeout_minutes: 60,       # 1 hour timeout
      retry_failed_steps: true,
      max_step_retries: 3
    }
  end
  
  defp load_workflow_templates(rules) do
    # Define built-in workflow templates
    %{
      "ml_training_pipeline" => %{
        name: "ML Training Pipeline",
        description: "End-to-end ML model training and deployment",
        steps: [
          %{name: "prepare_data", manager: :URM, action: "prepare_training_data"},
          %{name: "train_model", manager: :ULM, action: "train_ml_model"},
          %{name: "validate_model", manager: :UFM, action: "run_validation_tests"},
          %{name: "deploy_model", manager: :UAM, action: "deploy_to_production"}
        ],
        timeout_minutes: 120,
        retry_policy: :retry_failed_steps
      },
      
      "creative_workflow" => %{
        name: "Creative Content Pipeline",
        description: "Multi-stage creative content generation",
        steps: [
          %{name: "generate_concept", manager: :UAM, action: "generate_creative_concept"},
          %{name: "create_assets", manager: :UAM, action: "create_visual_assets"},
          %{name: "process_media", manager: :UIM, action: "process_multimedia"},
          %{name: "distribute_content", manager: :UCM, action: "distribute_to_channels"}
        ],
        timeout_minutes: 45,
        retry_policy: :retry_failed_steps
      },
      
      "system_maintenance" => %{
        name: "System Maintenance Workflow",
        description: "Automated system maintenance and optimization",
        steps: [
          %{name: "health_check", manager: :UFM, action: "comprehensive_health_check"},
          %{name: "cleanup_resources", manager: :URM, action: "cleanup_unused_resources"},
          %{name: "update_packages", manager: :URM, action: "update_system_packages"},
          %{name: "restart_services", manager: :UFM, action: "rolling_service_restart"}
        ],
        timeout_minutes: 90,
        retry_policy: :retry_failed_steps
      },
      
      "federation_sync" => %{
        name: "Federation Synchronization",
        description: "Synchronize state across distributed nodes",
        steps: [
          %{name: "check_topology", manager: :UFM, action: "verify_network_topology"},
          %{name: "sync_state", manager: :UFM, action: "synchronize_distributed_state"},
          %{name: "validate_consistency", manager: :UFM, action: "validate_state_consistency"}
        ],
        timeout_minutes: 30,
        retry_policy: :retry_failed_steps
      }
    }
  end
  
  defp start_orchestration_timers(state) do
    monitor_timer = schedule_workflow_monitoring(state.rules)
    queue_timer = schedule_queue_processing(state.rules)
    
    %{state |
      workflow_monitor_timer: monitor_timer,
      queue_processor_timer: queue_timer
    }
  end
  
  defp schedule_workflow_monitoring(rules) do
    interval = Map.get(rules, :workflow_monitor_interval, 10000)
    Process.send_after(self(), :workflow_monitor_cycle, interval)
  end
  
  defp schedule_queue_processing(rules) do
    interval = Map.get(rules, :queue_processor_interval, 5000)
    Process.send_after(self(), :queue_processor_cycle, interval)
  end
  
  defp create_workflow_instance(workflow_name, params, workflow_id, state) do
    case Map.get(state.workflow_templates, workflow_name) do
      nil -> 
        {:error, :template_not_found}
      template ->
        workflow_instance = %{
          id: workflow_id,
          name: workflow_name,
          template: template,
          params: params,
          status: :initializing,
          started_at: DateTime.utc_now(),
          current_step: 0,
          step_results: [],
          retry_counts: %{},
          resource_assignments: %{}
        }
        
        updated_workflows = Map.put(state.active_workflows, workflow_id, workflow_instance)
        updated_state = %{state | active_workflows: updated_workflows}
        
        {:ok, workflow_instance, updated_state}
    end
  end
  
  defp begin_workflow_execution(workflow, state) do
    Logger.info("🎬 UFM.OrchestrationDaemon: Beginning execution of workflow #{workflow.id}")
    
    # Check resource availability
    case allocate_workflow_resources(workflow, state) do
      {:ok, resource_allocations, updated_state} ->
        # Update workflow with resource allocations
        updated_workflow = %{workflow | 
          status: :running,
          resource_assignments: resource_allocations
        }
        
        # Start first step
        execute_workflow_step(updated_workflow, 0, updated_state)
        
      {:error, reason} ->
        Logger.error("❌ UFM.OrchestrationDaemon: Failed to allocate resources for workflow #{workflow.id}: #{reason}")
        fail_workflow(workflow.id, {:resource_allocation_failed, reason}, state)
    end
  end
  
  defp execute_workflow_step(workflow, step_index, state) do
    steps = workflow.template.steps
    
    if step_index >= length(steps) do
      # Workflow completed successfully
      send(self(), {:workflow_completed, workflow.id, workflow.step_results})
      state
    else
      step = Enum.at(steps, step_index)
      Logger.debug("🔄 UFM.OrchestrationDaemon: Executing step #{step_index + 1}/#{length(steps)}: #{step.name}")
      
      # Execute step asynchronously
      Task.start(fn ->
        step_result = execute_step_action(step, workflow.params)
        send(self(), {:workflow_step_completed, workflow.id, {step_index, step_result}})
      end)
      
      # Update workflow status
      updated_workflow = %{workflow | 
        current_step: step_index,
        status: :running
      }
      
      updated_workflows = Map.put(state.active_workflows, workflow.id, updated_workflow)
      %{state | active_workflows: updated_workflows}
    end
  end
  
  defp execute_step_action(step, workflow_params) do
    try do
      # Route action to appropriate manager
      case step.manager do
        :UAM -> call_manager_action(EliasServer.Manager.UAM, step.action, workflow_params)
        :UCM -> call_manager_action(EliasServer.Manager.UCM, step.action, workflow_params)
        :UFM -> call_ufm_action(step.action, workflow_params)
        :UIM -> call_manager_action(EliasServer.Manager.UIM, step.action, workflow_params)
        :URM -> call_manager_action(EliasServer.Manager.URM, step.action, workflow_params)
        :ULM -> call_manager_action(EliasServer.Manager.ULM, step.action, workflow_params)
        _ -> {:error, :unknown_manager}
      end
    rescue
      error ->
        Logger.error("💥 UFM.OrchestrationDaemon: Step execution failed: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp call_manager_action(manager_module, action, params) do
    # Generic manager action call - would be customized per manager
    case manager_module do
      module when is_atom(module) ->
        if Process.whereis(module) do
          # Simulate successful action execution
          {:ok, %{action: action, params: params, completed_at: DateTime.utc_now()}}
        else
          {:error, :manager_not_available}
        end
      _ ->
        {:error, :invalid_manager}
    end
  end
  
  defp call_ufm_action(action, params) do
    # UFM-specific actions handled internally
    case action do
      "comprehensive_health_check" ->
        # Delegate to monitoring daemon
        health_status = EliasServer.Manager.UFM.MonitoringDaemon.get_health_status()
        {:ok, %{action: action, health_status: health_status}}
        
      "verify_network_topology" ->
        # Delegate to federation daemon
        topology = EliasServer.Manager.UFM.FederationDaemon.get_network_topology()
        {:ok, %{action: action, topology: topology}}
        
      _ ->
        {:ok, %{action: action, params: params, completed_at: DateTime.utc_now()}}
    end
  end
  
  defp advance_workflow_step(workflow, {step_index, step_result}, state) do
    case step_result do
      {:ok, result} ->
        # Step succeeded, move to next step
        updated_step_results = workflow.step_results ++ [result]
        updated_workflow = %{workflow | step_results: updated_step_results}
        
        # Execute next step
        execute_workflow_step(updated_workflow, step_index + 1, state)
        
      {:error, error} ->
        # Step failed, check retry policy
        handle_step_failure(workflow, step_index, error, state)
    end
  end
  
  defp handle_step_failure(workflow, step_index, error, state) do
    retry_policy = Map.get(workflow.template, :retry_policy, :no_retry)
    max_retries = Map.get(state.rules, :max_step_retries, 3)
    
    current_retries = Map.get(workflow.retry_counts, step_index, 0)
    
    if retry_policy == :retry_failed_steps and current_retries < max_retries do
      Logger.info("🔄 UFM.OrchestrationDaemon: Retrying step #{step_index} (attempt #{current_retries + 1})")
      
      # Update retry count
      updated_retry_counts = Map.put(workflow.retry_counts, step_index, current_retries + 1)
      updated_workflow = %{workflow | retry_counts: updated_retry_counts}
      
      # Retry the step after a delay
      Process.send_after(self(), {:retry_workflow_step, workflow.id, step_index}, 5000)
      
      updated_workflows = Map.put(state.active_workflows, workflow.id, updated_workflow)
      %{state | active_workflows: updated_workflows}
    else
      # Max retries exceeded or no retry policy, fail the workflow
      send(self(), {:workflow_failed, workflow.id, error})
      state
    end
  end
  
  defp complete_workflow(workflow_id, final_result, state) do
    case Map.get(state.active_workflows, workflow_id) do
      nil -> state
      workflow ->
        Logger.info("🎯 UFM.OrchestrationDaemon: Workflow #{workflow_id} completed successfully")
        
        # Move to history
        completed_workflow = %{workflow | 
          status: :completed,
          completed_at: DateTime.utc_now(),
          final_result: final_result
        }
        
        updated_history = [completed_workflow | state.workflow_history] |> Enum.take(1000)
        updated_workflows = Map.delete(state.active_workflows, workflow_id)
        
        # Release allocated resources
        updated_allocations = release_workflow_resources(workflow, state.resource_allocations)
        
        %{state |
          active_workflows: updated_workflows,
          workflow_history: updated_history,
          resource_allocations: updated_allocations
        }
    end
  end
  
  defp fail_workflow(workflow_id, error, state) do
    case Map.get(state.active_workflows, workflow_id) do
      nil -> state
      workflow ->
        Logger.error("💥 UFM.OrchestrationDaemon: Workflow #{workflow_id} failed: #{inspect(error)}")
        
        # Move to history as failed
        failed_workflow = %{workflow | 
          status: :failed,
          completed_at: DateTime.utc_now(),
          error: error
        }
        
        updated_history = [failed_workflow | state.workflow_history] |> Enum.take(1000)
        updated_workflows = Map.delete(state.active_workflows, workflow_id)
        
        # Release allocated resources
        updated_allocations = release_workflow_resources(workflow, state.resource_allocations)
        
        %{state |
          active_workflows: updated_workflows,
          workflow_history: updated_history,
          resource_allocations: updated_allocations
        }
    end
  end
  
  defp cancel_workflow_execution(workflow, state) do
    # Cancel any running tasks and clean up
    updated_history = [%{workflow | status: :cancelled, completed_at: DateTime.utc_now()} | state.workflow_history] |> Enum.take(1000)
    updated_workflows = Map.delete(state.active_workflows, workflow.id)
    updated_allocations = release_workflow_resources(workflow, state.resource_allocations)
    
    %{state |
      active_workflows: updated_workflows,
      workflow_history: updated_history,
      resource_allocations: updated_allocations
    }
  end
  
  defp monitor_active_workflows(state) do
    timeout_minutes = Map.get(state.rules, :workflow_timeout_minutes, 60)
    timeout_threshold = DateTime.utc_now() |> DateTime.add(-timeout_minutes, :minute)
    
    {timed_out_workflows, active_workflows} = state.active_workflows
    |> Enum.split_with(fn {_id, workflow} ->
      DateTime.compare(workflow.started_at, timeout_threshold) == :lt
    end)
    
    # Handle timed out workflows
    final_state = Enum.reduce(timed_out_workflows, state, fn {workflow_id, _workflow}, acc_state ->
      Logger.warning("⏰ UFM.OrchestrationDaemon: Workflow #{workflow_id} timed out")
      fail_workflow(workflow_id, :timeout, acc_state)
    end)
    
    Logger.debug("👁️ UFM.OrchestrationDaemon: Monitoring #{map_size(active_workflows)} active workflows")
    final_state
  end
  
  defp process_orchestration_queue(state) do
    max_concurrent = Map.get(state.rules, :max_concurrent_workflows, 10)
    current_active = map_size(state.active_workflows)
    available_slots = max(0, max_concurrent - current_active)
    
    if available_slots > 0 and not :queue.is_empty(state.orchestration_queue) do
      Logger.debug("📥 UFM.OrchestrationDaemon: Processing orchestration queue")
      # Would process queued workflows here
    end
    
    state
  end
  
  defp allocate_workflow_resources(_workflow, state) do
    # Simplified resource allocation - would be more sophisticated in production
    resource_allocations = %{
      cpu_cores: 2,
      memory_mb: 512,
      disk_mb: 1024
    }
    
    {:ok, resource_allocations, state}
  end
  
  defp release_workflow_resources(_workflow, resource_allocations) do
    # Release resources back to the pool
    resource_allocations
  end
  
  defp calculate_workflow_progress(workflow) do
    total_steps = length(workflow.template.steps)
    completed_steps = workflow.current_step
    
    if total_steps > 0 do
      (completed_steps / total_steps) * 100.0
    else
      0.0
    end
  end
  
  defp calculate_resource_utilization(resource_allocations) do
    # Simplified resource utilization calculation
    %{
      cpu_utilization: 0.0,
      memory_utilization: 0.0,
      active_allocations: map_size(resource_allocations)
    }
  end
  
  defp generate_workflow_id do
    "workflow_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
  
  defp apply_orchestration_rule_changes(old_state, new_state) do
    # Handle configuration changes
    changes = []
    |> maybe_reschedule_workflow_monitoring(old_state, new_state)
    |> maybe_reschedule_queue_processing(old_state, new_state)
    
    if length(changes) > 0 do
      Logger.info("🔄 UFM.OrchestrationDaemon: Applied #{length(changes)} orchestration configuration changes")
    end
    
    new_state
  end
  
  defp maybe_reschedule_workflow_monitoring(changes, old_state, new_state) do
    if old_state.rules[:workflow_monitor_interval] != new_state.rules[:workflow_monitor_interval] do
      if old_state.workflow_monitor_timer, do: Process.cancel_timer(old_state.workflow_monitor_timer)
      monitor_timer = schedule_workflow_monitoring(new_state.rules)
      new_state = %{new_state | workflow_monitor_timer: monitor_timer}
      [:workflow_monitoring_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_reschedule_queue_processing(changes, old_state, new_state) do
    if old_state.rules[:queue_processor_interval] != new_state.rules[:queue_processor_interval] do
      if old_state.queue_processor_timer, do: Process.cancel_timer(old_state.queue_processor_timer)
      queue_timer = schedule_queue_processing(new_state.rules)
      new_state = %{new_state | queue_processor_timer: queue_timer}
      [:queue_processing_rescheduled | changes]
    else
      changes
    end
  end
end