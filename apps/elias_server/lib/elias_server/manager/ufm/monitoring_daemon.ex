defmodule EliasServer.Manager.UFM.MonitoringDaemon do
  @moduledoc """
  UFM Monitoring Sub-Daemon - Always-on system monitoring and health management
  
  Responsibilities:
  - Continuous health checks of all ELIAS components
  - System metrics collection and analysis
  - Alert generation and threshold monitoring
  - Performance tracking across distributed nodes
  - Hot-reload from UFM_Monitoring.md spec
  """
  
  use GenServer
  require Logger
  
  alias EliasServer.Manager.SupervisorHelper
  
  defstruct [
    :rules,
    :last_updated,
    :checksum,
    :monitoring_metrics,
    :active_alerts,
    :health_status,
    :system_thresholds,
    :monitoring_intervals,
    :health_check_timer,
    :metrics_collection_timer,
    :alert_check_timer
  ]
  
  @spec_file Path.join([Application.app_dir(:elias_server), "priv", "manager_specs", "UFM_Monitoring.md"])
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end
  
  def get_system_metrics do
    GenServer.call(__MODULE__, :get_system_metrics)
  end
  
  def get_active_alerts do
    GenServer.call(__MODULE__, :get_active_alerts)
  end
  
  def record_federation_event(event_type, data) do
    GenServer.cast(__MODULE__, {:record_federation_event, event_type, data})
  end
  
  def force_health_check do
    GenServer.cast(__MODULE__, :force_health_check)
  end
  
  def reload_rules do
    GenServer.cast(__MODULE__, :reload_rules)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("📊 UFM.MonitoringDaemon: Starting always-on monitoring daemon")
    
    # Register in sub-daemon registry
    SupervisorHelper.register_process(:ufm_subdaemons, :monitoring_daemon, self())
    
    # Load monitoring rules from hierarchical spec
    new_state = load_monitoring_rules(state)
    
    # Initialize monitoring state
    initial_state = %{new_state |
      monitoring_metrics: initialize_metrics(),
      active_alerts: [],
      health_status: %{},
      system_thresholds: initialize_thresholds(new_state.rules)
    }
    
    # Start periodic monitoring tasks
    final_state = start_monitoring_timers(initial_state)
    
    # Perform initial health check
    GenServer.cast(self(), :force_health_check)
    
    Logger.info("✅ UFM.MonitoringDaemon: Always-on monitoring active")
    {:ok, final_state}
  end
  
  @impl true
  def handle_call(:get_health_status, _from, state) do
    {:reply, state.health_status, state}
  end
  
  def handle_call(:get_system_metrics, _from, state) do
    {:reply, state.monitoring_metrics, state}
  end
  
  def handle_call(:get_active_alerts, _from, state) do
    {:reply, state.active_alerts, state}
  end
  
  @impl true
  def handle_cast(:reload_rules, state) do
    Logger.info("🔄 UFM.MonitoringDaemon: Hot-reloading monitoring rules")
    new_state = load_monitoring_rules(state)
    updated_state = apply_monitoring_rule_changes(state, new_state)
    {:noreply, updated_state}
  end
  
  def handle_cast(:force_health_check, state) do
    updated_state = perform_comprehensive_health_check(state)
    {:noreply, updated_state}
  end
  
  def handle_cast({:record_federation_event, event_type, data}, state) do
    # Record federation events for monitoring analysis
    event_entry = %{
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now(),
      source: :federation_daemon
    }
    
    updated_metrics = update_federation_metrics(state.monitoring_metrics, event_entry)
    
    Logger.debug("📈 UFM.MonitoringDaemon: Recorded federation event: #{event_type}")
    
    {:noreply, %{state | monitoring_metrics: updated_metrics}}
  end
  
  @impl true
  def handle_info(:health_check_cycle, state) do
    # Continuous health monitoring - never stops
    updated_state = perform_comprehensive_health_check(state)
    
    # Schedule next health check
    health_check_timer = schedule_health_check(updated_state.rules)
    final_state = %{updated_state | health_check_timer: health_check_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:metrics_collection_cycle, state) do
    # Continuous metrics collection
    updated_state = collect_system_metrics(state)
    
    # Schedule next metrics collection
    metrics_timer = schedule_metrics_collection(updated_state.rules)
    final_state = %{updated_state | metrics_collection_timer: metrics_timer}
    
    {:noreply, final_state}
  end
  
  def handle_info(:alert_check_cycle, state) do
    # Continuous alert evaluation
    updated_state = evaluate_alerts(state)
    
    # Schedule next alert check
    alert_timer = schedule_alert_check(updated_state.rules)
    final_state = %{updated_state | alert_check_timer: alert_timer}
    
    {:noreply, final_state}
  end
  
  # Private Functions
  
  defp load_monitoring_rules(state) do
    case File.read(@spec_file) do
      {:ok, content} ->
        {rules, checksum} = parse_monitoring_md_rules(content)
        %{state |
          rules: rules,
          last_updated: DateTime.utc_now(),
          checksum: checksum
        }
      {:error, reason} ->
        Logger.error("❌ UFM.MonitoringDaemon: Could not load UFM_Monitoring.md: #{reason}")
        # Use default monitoring rules
        %{state |
          rules: default_monitoring_rules(),
          last_updated: DateTime.utc_now()
        }
    end
  end
  
  defp parse_monitoring_md_rules(content) do
    # Extract monitoring-specific YAML configuration
    [frontmatter_str | _] = String.split(content, "---", parts: 3, trim: true)
    
    frontmatter = YamlElixir.read_from_string(frontmatter_str) || %{}
    checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    
    rules = %{
      health_check_interval: get_in(frontmatter, ["monitoring", "health_check_interval"]) || 30000,
      metrics_collection_interval: get_in(frontmatter, ["monitoring", "metrics_collection_interval"]) || 60000,
      alert_check_interval: get_in(frontmatter, ["monitoring", "alert_check_interval"]) || 15000,
      cpu_threshold: get_in(frontmatter, ["monitoring", "thresholds", "cpu_percent"]) || 80.0,
      memory_threshold: get_in(frontmatter, ["monitoring", "thresholds", "memory_percent"]) || 85.0,
      disk_threshold: get_in(frontmatter, ["monitoring", "thresholds", "disk_percent"]) || 90.0,
      enabled_checks: get_in(frontmatter, ["monitoring", "enabled_checks"]) || ["managers", "system", "network"]
    }
    
    {rules, checksum}
  end
  
  defp default_monitoring_rules do
    %{
      health_check_interval: 30000,    # 30 seconds
      metrics_collection_interval: 60000,  # 1 minute
      alert_check_interval: 15000,     # 15 seconds
      cpu_threshold: 80.0,
      memory_threshold: 85.0, 
      disk_threshold: 90.0,
      enabled_checks: ["managers", "system", "network"]
    }
  end
  
  defp initialize_metrics do
    %{
      system_metrics: %{
        cpu_usage: 0.0,
        memory_usage: 0.0,
        disk_usage: 0.0,
        uptime: System.system_time(:second),
        process_count: 0
      },
      manager_metrics: %{},
      federation_events: [],
      network_metrics: %{
        active_connections: 0,
        message_throughput: 0.0
      },
      collection_timestamp: DateTime.utc_now()
    }
  end
  
  defp initialize_thresholds(rules) do
    %{
      cpu_percent: Map.get(rules, :cpu_threshold, 80.0),
      memory_percent: Map.get(rules, :memory_threshold, 85.0),
      disk_percent: Map.get(rules, :disk_threshold, 90.0)
    }
  end
  
  defp start_monitoring_timers(state) do
    health_timer = schedule_health_check(state.rules)
    metrics_timer = schedule_metrics_collection(state.rules)
    alert_timer = schedule_alert_check(state.rules)
    
    %{state |
      health_check_timer: health_timer,
      metrics_collection_timer: metrics_timer,
      alert_check_timer: alert_timer
    }
  end
  
  defp schedule_health_check(rules) do
    interval = Map.get(rules, :health_check_interval, 30000)
    Process.send_after(self(), :health_check_cycle, interval)
  end
  
  defp schedule_metrics_collection(rules) do
    interval = Map.get(rules, :metrics_collection_interval, 60000)
    Process.send_after(self(), :metrics_collection_cycle, interval)
  end
  
  defp schedule_alert_check(rules) do
    interval = Map.get(rules, :alert_check_interval, 15000)
    Process.send_after(self(), :alert_check_cycle, interval)
  end
  
  defp perform_comprehensive_health_check(state) do
    enabled_checks = Map.get(state.rules, :enabled_checks, ["managers", "system", "network"])
    
    health_results = %{}
    |> maybe_check_managers(enabled_checks)
    |> maybe_check_system_health(enabled_checks)
    |> maybe_check_network_health(enabled_checks)
    
    Logger.debug("🔍 UFM.MonitoringDaemon: Health check completed - #{map_size(health_results)} components checked")
    
    %{state | health_status: health_results}
  end
  
  defp maybe_check_managers(results, enabled_checks) do
    if "managers" in enabled_checks do
      manager_health = check_manager_health()
      Map.put(results, :managers, manager_health)
    else
      results
    end
  end
  
  defp maybe_check_system_health(results, enabled_checks) do
    if "system" in enabled_checks do
      system_health = check_system_health()
      Map.put(results, :system, system_health)
    else
      results
    end
  end
  
  defp maybe_check_network_health(results, enabled_checks) do
    if "network" in enabled_checks do
      network_health = check_network_health()
      Map.put(results, :network, network_health)
    else
      results
    end
  end
  
  defp check_manager_health do
    # Check all ELIAS managers
    managers = [:UAM, :UCM, :UFM, :UIM, :URM, :ULM]
    
    managers
    |> Enum.map(fn manager ->
      module = Module.concat([EliasServer.Manager, manager])
      status = if Process.whereis(module), do: :healthy, else: :unhealthy
      {manager, status}
    end)
    |> Map.new()
  end
  
  defp check_system_health do
    # System resource checks
    %{
      vm_status: :healthy,  # Simplified - could use :recon for real metrics
      memory_usage: get_memory_usage(),
      process_count: Process.list() |> length(),
      scheduler_utilization: get_scheduler_utilization()
    }
  end
  
  defp check_network_health do
    # Network connectivity checks
    %{
      node_connectivity: check_node_connectivity(),
      port_bindings: check_port_bindings(),
      erlang_distribution: check_erlang_distribution()
    }
  end
  
  defp get_memory_usage do
    # Simplified memory check - could use more sophisticated monitoring
    {:memory, memory_info} = :erlang.memory() |> List.keyfind(:total, 0, {:total, 0})
    memory_info / (1024 * 1024)  # Convert to MB
  end
  
  defp get_scheduler_utilization do
    # Simplified scheduler check
    :erlang.system_info(:scheduler_wall_time_all)
    |> length()
  end
  
  defp check_node_connectivity do
    Node.list()
    |> Enum.map(fn node ->
      status = case :net_adm.ping(node) do
        :pong -> :connected
        :pang -> :disconnected
      end
      {node, status}
    end)
    |> Map.new()
  end
  
  defp check_port_bindings do
    # Check if required ports are available
    # This would be more sophisticated in production
    %{status: :available}
  end
  
  defp check_erlang_distribution do
    %{
      node_name: Node.self(),
      cookie_set: Node.get_cookie() != :nocookie,
      distribution_enabled: Node.alive?()
    }
  end
  
  defp collect_system_metrics(state) do
    new_metrics = %{state.monitoring_metrics |
      system_metrics: %{
        cpu_usage: get_cpu_usage(),
        memory_usage: get_memory_usage(),
        disk_usage: get_disk_usage(),
        uptime: System.system_time(:second),
        process_count: Process.list() |> length()
      },
      collection_timestamp: DateTime.utc_now()
    }
    
    Logger.debug("📈 UFM.MonitoringDaemon: System metrics collected")
    %{state | monitoring_metrics: new_metrics}
  end
  
  defp get_cpu_usage do
    # Simplified CPU monitoring - would use :cpu_sup or similar in production
    :rand.uniform(100) * 0.1  # Mock value for now
  end
  
  defp get_disk_usage do
    # Simplified disk monitoring
    :rand.uniform(100) * 0.5  # Mock value for now
  end
  
  defp update_federation_metrics(metrics, event_entry) do
    current_events = Map.get(metrics, :federation_events, [])
    
    # Keep last 100 federation events for analysis
    updated_events = [event_entry | current_events]
    |> Enum.take(100)
    
    %{metrics | federation_events: updated_events}
  end
  
  defp evaluate_alerts(state) do
    current_alerts = []
    |> check_cpu_alert(state)
    |> check_memory_alert(state)
    |> check_manager_alerts(state)
    
    # Only log if alerts changed
    if length(current_alerts) != length(state.active_alerts) do
      Logger.info("🚨 UFM.MonitoringDaemon: Active alerts: #{length(current_alerts)}")
    end
    
    %{state | active_alerts: current_alerts}
  end
  
  defp check_cpu_alert(alerts, state) do
    cpu_usage = get_in(state.monitoring_metrics, [:system_metrics, :cpu_usage]) || 0.0
    threshold = Map.get(state.system_thresholds, :cpu_percent, 80.0)
    
    if cpu_usage > threshold do
      alert = %{
        type: :high_cpu,
        severity: :warning,
        message: "CPU usage #{cpu_usage}% exceeds threshold #{threshold}%",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp check_memory_alert(alerts, state) do
    memory_usage = get_in(state.monitoring_metrics, [:system_metrics, :memory_usage]) || 0.0
    threshold = Map.get(state.system_thresholds, :memory_percent, 85.0)
    
    if memory_usage > threshold do
      alert = %{
        type: :high_memory,
        severity: :warning,
        message: "Memory usage #{memory_usage}% exceeds threshold #{threshold}%",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
  end
  
  defp check_manager_alerts(alerts, state) do
    case get_in(state.health_status, [:managers]) do
      nil -> alerts
      manager_statuses ->
        unhealthy_managers = manager_statuses
        |> Enum.filter(fn {_manager, status} -> status != :healthy end)
        
        if length(unhealthy_managers) > 0 do
          alert = %{
            type: :unhealthy_managers,
            severity: :critical,
            message: "Unhealthy managers detected: #{inspect(unhealthy_managers)}",
            timestamp: DateTime.utc_now()
          }
          [alert | alerts]
        else
          alerts
        end
    end
  end
  
  defp apply_monitoring_rule_changes(old_state, new_state) do
    # Handle timer rescheduling if intervals changed
    changes = []
    |> maybe_reschedule_health_check(old_state, new_state)
    |> maybe_reschedule_metrics_collection(old_state, new_state)
    |> maybe_reschedule_alert_check(old_state, new_state)
    
    if length(changes) > 0 do
      Logger.info("🔄 UFM.MonitoringDaemon: Applied #{length(changes)} configuration changes")
    end
    
    new_state
  end
  
  defp maybe_reschedule_health_check(changes, old_state, new_state) do
    if old_state.rules[:health_check_interval] != new_state.rules[:health_check_interval] do
      if old_state.health_check_timer, do: Process.cancel_timer(old_state.health_check_timer)
      health_timer = schedule_health_check(new_state.rules)
      new_state = %{new_state | health_check_timer: health_timer}
      [:health_check_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_reschedule_metrics_collection(changes, old_state, new_state) do
    if old_state.rules[:metrics_collection_interval] != new_state.rules[:metrics_collection_interval] do
      if old_state.metrics_collection_timer, do: Process.cancel_timer(old_state.metrics_collection_timer)
      metrics_timer = schedule_metrics_collection(new_state.rules)
      new_state = %{new_state | metrics_collection_timer: metrics_timer}
      [:metrics_rescheduled | changes]
    else
      changes
    end
  end
  
  defp maybe_reschedule_alert_check(changes, old_state, new_state) do
    if old_state.rules[:alert_check_interval] != new_state.rules[:alert_check_interval] do
      if old_state.alert_check_timer, do: Process.cancel_timer(old_state.alert_check_timer)
      alert_timer = schedule_alert_check(new_state.rules)
      new_state = %{new_state | alert_check_timer: alert_timer}
      [:alert_check_rescheduled | changes]
    else
      changes
    end
  end
end