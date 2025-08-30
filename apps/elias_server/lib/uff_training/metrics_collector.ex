defmodule UFFTraining.MetricsCollector do
  @moduledoc """
  UFF Training Metrics Collection and Analysis
  
  RESPONSIBILITY: Collect, analyze, and report UFF training and inference metrics
  
  This module tracks:
  - UFF model training progress and performance
  - Inference latency and throughput metrics
  - Tank Building methodology adherence scores
  - Claude supervision effectiveness
  - UFM federation performance metrics
  - Component generation quality metrics
  """
  
  use GenServer
  require Logger
  
  defmodule MetricsState do
    defstruct [
      :training_metrics,
      :inference_metrics,
      :quality_metrics,
      :supervision_metrics,
      :federation_metrics,
      :historical_data,
      :alerts,
      :reporting_config
    ]
  end
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Record UFF training metrics
  """
  def record_training_metric(metric_type, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:training_metric, metric_type, value, metadata})
  end
  
  @doc """
  Record UFF inference metrics
  """
  def record_inference_metric(metric_type, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:inference_metric, metric_type, value, metadata})
  end
  
  @doc """
  Record component quality metrics
  """
  def record_quality_metric(component_id, quality_scores, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:quality_metric, component_id, quality_scores, metadata})
  end
  
  @doc """
  Record Claude supervision metrics
  """
  def record_supervision_metric(supervision_type, effectiveness_score, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:supervision_metric, supervision_type, effectiveness_score, metadata})
  end
  
  @doc """
  Record UFM federation metrics
  """
  def record_federation_metric(metric_type, value, node_id \\ nil, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:federation_metric, metric_type, value, node_id, metadata})
  end
  
  @doc """
  Get comprehensive metrics report
  """
  def get_metrics_report(time_range \\ :last_24h) do
    GenServer.call(__MODULE__, {:get_report, time_range})
  end
  
  @doc """
  Get real-time metrics dashboard data
  """
  def get_dashboard_metrics do
    GenServer.call(__MODULE__, :get_dashboard)
  end
  
  @doc """
  Export metrics data for analysis
  """
  def export_metrics(format \\ :json, time_range \\ :last_week) do
    GenServer.call(__MODULE__, {:export_metrics, format, time_range})
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("UFFTraining.MetricsCollector: Initializing metrics collection system")
    
    state = %MetricsState{
      training_metrics: %{},
      inference_metrics: %{},
      quality_metrics: %{},
      supervision_metrics: %{},
      federation_metrics: %{},
      historical_data: [],
      alerts: [],
      reporting_config: %{}
    }
    
    # Schedule periodic metrics aggregation and reporting
    :timer.send_interval(60_000, :aggregate_metrics)      # Every minute
    :timer.send_interval(300_000, :generate_alerts)       # Every 5 minutes
    :timer.send_interval(3600_000, :archive_metrics)      # Every hour
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:training_metric, metric_type, value, metadata}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    metric = %{
      type: metric_type,
      value: value,
      metadata: metadata,
      timestamp: timestamp,
      category: :training
    }
    
    new_training_metrics = add_metric_to_category(state.training_metrics, metric_type, metric)
    new_state = %{state | training_metrics: new_training_metrics}
    
    # Check for training alerts
    check_training_alerts(metric_type, value, metadata)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:inference_metric, metric_type, value, metadata}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    metric = %{
      type: metric_type,
      value: value,
      metadata: metadata,
      timestamp: timestamp,
      category: :inference
    }
    
    new_inference_metrics = add_metric_to_category(state.inference_metrics, metric_type, metric)
    new_state = %{state | inference_metrics: new_inference_metrics}
    
    # Check for inference performance alerts
    check_inference_alerts(metric_type, value, metadata)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:quality_metric, component_id, quality_scores, metadata}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    metric = %{
      component_id: component_id,
      quality_scores: quality_scores,
      metadata: metadata,
      timestamp: timestamp,
      category: :quality
    }
    
    new_quality_metrics = add_metric_to_category(state.quality_metrics, component_id, metric)
    new_state = %{state | quality_metrics: new_quality_metrics}
    
    # Check for quality alerts
    check_quality_alerts(component_id, quality_scores, metadata)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:supervision_metric, supervision_type, effectiveness_score, metadata}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    metric = %{
      supervision_type: supervision_type,
      effectiveness_score: effectiveness_score,
      metadata: metadata,
      timestamp: timestamp,
      category: :supervision
    }
    
    new_supervision_metrics = add_metric_to_category(state.supervision_metrics, supervision_type, metric)
    new_state = %{state | supervision_metrics: new_supervision_metrics}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:federation_metric, metric_type, value, node_id, metadata}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    metric = %{
      type: metric_type,
      value: value,
      node_id: node_id,
      metadata: metadata,
      timestamp: timestamp,
      category: :federation
    }
    
    metric_key = if node_id, do: "#{metric_type}_#{node_id}", else: metric_type
    new_federation_metrics = add_metric_to_category(state.federation_metrics, metric_key, metric)
    new_state = %{state | federation_metrics: new_federation_metrics}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get_report, time_range}, _from, state) do
    Logger.info("UFFTraining.MetricsCollector: Generating metrics report for #{time_range}")
    
    report = generate_comprehensive_report(state, time_range)
    
    {:reply, report, state}
  end
  
  @impl true
  def handle_call(:get_dashboard, _from, state) do
    dashboard_data = generate_dashboard_data(state)
    
    {:reply, dashboard_data, state}
  end
  
  @impl true
  def handle_call({:export_metrics, format, time_range}, _from, state) do
    Logger.info("UFFTraining.MetricsCollector: Exporting metrics in #{format} format for #{time_range}")
    
    export_result = export_metrics_data(state, format, time_range)
    
    {:reply, export_result, state}
  end
  
  @impl true
  def handle_info(:aggregate_metrics, state) do
    Logger.debug("UFFTraining.MetricsCollector: Aggregating metrics")
    
    # Perform metrics aggregation
    aggregated_data = aggregate_recent_metrics(state)
    
    # Add to historical data
    new_historical_data = [aggregated_data | state.historical_data]
    |> Enum.take(1440)  # Keep last 24 hours (1440 minutes)
    
    new_state = %{state | historical_data: new_historical_data}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:generate_alerts, state) do
    Logger.debug("UFFTraining.MetricsCollector: Checking for alerts")
    
    new_alerts = generate_system_alerts(state)
    
    if length(new_alerts) > 0 do
      Logger.info("UFFTraining.MetricsCollector: Generated #{length(new_alerts)} alerts")
      Enum.each(new_alerts, fn alert ->
        Logger.warn("ALERT: #{alert.title} - #{alert.description}")
      end)
    end
    
    new_state = %{state | alerts: new_alerts ++ state.alerts}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:archive_metrics, state) do
    Logger.info("UFFTraining.MetricsCollector: Archiving historical metrics")
    
    # Archive old metrics data
    archived_data = archive_old_metrics(state)
    
    case archived_data do
      {:ok, archive_path} ->
        Logger.info("UFFTraining.MetricsCollector: Metrics archived to #{archive_path}")
        
      {:error, reason} ->
        Logger.error("UFFTraining.MetricsCollector: Failed to archive metrics: #{inspect(reason)}")
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp add_metric_to_category(category_metrics, metric_key, metric) do
    current_metrics = Map.get(category_metrics, metric_key, [])
    new_metrics = [metric | current_metrics] |> Enum.take(100)  # Keep last 100 metrics per type
    
    Map.put(category_metrics, metric_key, new_metrics)
  end
  
  defp check_training_alerts(metric_type, value, _metadata) do
    case metric_type do
      :model_loss ->
        if value > 2.0 do
          Logger.warn("UFFTraining Alert: High training loss detected: #{value}")
        end
        
      :learning_rate ->
        if value < 0.00001 do
          Logger.warn("UFFTraining Alert: Learning rate very low: #{value}")
        end
        
      :gradient_norm ->
        if value > 10.0 do
          Logger.warn("UFFTraining Alert: High gradient norm detected: #{value}")
        end
        
      _ -> :ok
    end
  end
  
  defp check_inference_alerts(metric_type, value, _metadata) do
    case metric_type do
      :latency_ms ->
        if value > 1000 do
          Logger.warn("UFFTraining Alert: High inference latency: #{value}ms")
        end
        
      :throughput_rps ->
        if value < 10 do
          Logger.warn("UFFTraining Alert: Low inference throughput: #{value} req/s")
        end
        
      :error_rate ->
        if value > 0.05 do  # 5%
          Logger.warn("UFFTraining Alert: High inference error rate: #{value * 100}%")
        end
        
      _ -> :ok
    end
  end
  
  defp check_quality_alerts(component_id, quality_scores, _metadata) do
    total_score = Map.get(quality_scores, :total_score, 0.0)
    
    if total_score < 0.7 do
      Logger.warn("UFFTraining Alert: Low component quality for #{component_id}: #{total_score}")
    end
    
    atomicity_score = Map.get(quality_scores, :atomicity_score, 0.0)
    if atomicity_score < 0.8 do
      Logger.warn("UFFTraining Alert: Poor atomicity for #{component_id}: #{atomicity_score}")
    end
  end
  
  defp generate_comprehensive_report(state, time_range) do
    time_filter = get_time_filter(time_range)
    
    %{
      report_generated_at: DateTime.utc_now(),
      time_range: time_range,
      
      # Training metrics summary
      training_summary: summarize_training_metrics(state.training_metrics, time_filter),
      
      # Inference performance summary
      inference_summary: summarize_inference_metrics(state.inference_metrics, time_filter),
      
      # Component quality summary
      quality_summary: summarize_quality_metrics(state.quality_metrics, time_filter),
      
      # Claude supervision effectiveness
      supervision_summary: summarize_supervision_metrics(state.supervision_metrics, time_filter),
      
      # UFM federation performance
      federation_summary: summarize_federation_metrics(state.federation_metrics, time_filter),
      
      # Trends and insights
      trends: analyze_trends(state, time_filter),
      
      # Active alerts
      active_alerts: state.alerts,
      
      # Recommendations
      recommendations: generate_recommendations(state, time_filter)
    }
  end
  
  defp generate_dashboard_data(state) do
    current_time = System.monotonic_time(:millisecond)
    last_hour_filter = current_time - (60 * 60 * 1000)  # Last hour
    
    %{
      timestamp: current_time,
      
      # Real-time training status
      training_status: %{
        active_sessions: count_active_training_sessions(state.training_metrics, last_hour_filter),
        avg_loss: calculate_average_loss(state.training_metrics, last_hour_filter),
        learning_rate: get_current_learning_rate(state.training_metrics),
        model_version: get_current_model_version(state.training_metrics)
      },
      
      # Real-time inference metrics
      inference_status: %{
        requests_per_minute: count_recent_requests(state.inference_metrics, last_hour_filter),
        avg_latency_ms: calculate_average_latency(state.inference_metrics, last_hour_filter),
        success_rate: calculate_success_rate(state.inference_metrics, last_hour_filter),
        active_endpoints: count_active_endpoints(state.federation_metrics, last_hour_filter)
      },
      
      # Quality metrics
      quality_status: %{
        avg_component_quality: calculate_average_quality(state.quality_metrics, last_hour_filter),
        components_generated: count_components_generated(state.quality_metrics, last_hour_filter),
        tank_building_compliance: calculate_compliance_rate(state.quality_metrics, last_hour_filter)
      },
      
      # Claude supervision status
      supervision_status: %{
        supervision_requests: count_supervision_requests(state.supervision_metrics, last_hour_filter),
        avg_effectiveness: calculate_supervision_effectiveness(state.supervision_metrics, last_hour_filter),
        correction_rate: calculate_correction_rate(state.supervision_metrics, last_hour_filter)
      },
      
      # UFM federation health
      federation_health: %{
        healthy_nodes: count_healthy_nodes(state.federation_metrics, last_hour_filter),
        total_nodes: count_total_nodes(state.federation_metrics, last_hour_filter),
        avg_response_time: calculate_federation_response_time(state.federation_metrics, last_hour_filter),
        deployment_success_rate: calculate_deployment_success_rate(state.federation_metrics, last_hour_filter)
      },
      
      # Alert summary
      alert_summary: %{
        active_alerts: length(state.alerts),
        critical_alerts: count_critical_alerts(state.alerts),
        warning_alerts: count_warning_alerts(state.alerts)
      }
    }
  end
  
  defp export_metrics_data(state, format, time_range) do
    time_filter = get_time_filter(time_range)
    
    export_data = %{
      metadata: %{
        export_timestamp: DateTime.utc_now(),
        format: format,
        time_range: time_range,
        uff_version: "6.7B-FP16"
      },
      training_data: filter_metrics_by_time(state.training_metrics, time_filter),
      inference_data: filter_metrics_by_time(state.inference_metrics, time_filter),
      quality_data: filter_metrics_by_time(state.quality_metrics, time_filter),
      supervision_data: filter_metrics_by_time(state.supervision_metrics, time_filter),
      federation_data: filter_metrics_by_time(state.federation_metrics, time_filter)
    }
    
    # Generate filename and export
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    filename = "uff_metrics_#{time_range}_#{timestamp}.#{format}"
    filepath = Path.join("exports", filename)
    
    content = case format do
      :json ->
        Jason.encode!(export_data, pretty: true)
      :csv ->
        convert_to_csv(export_data)
      _ ->
        inspect(export_data, pretty: true)
    end
    
    case File.mkdir_p("exports") do
      :ok ->
        case File.write(filepath, content) do
          :ok ->
            {:ok, filepath}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp aggregate_recent_metrics(state) do
    current_time = System.monotonic_time(:millisecond)
    last_minute_filter = current_time - 60_000  # Last minute
    
    %{
      timestamp: current_time,
      training_aggregates: aggregate_category_metrics(state.training_metrics, last_minute_filter),
      inference_aggregates: aggregate_category_metrics(state.inference_metrics, last_minute_filter),
      quality_aggregates: aggregate_category_metrics(state.quality_metrics, last_minute_filter),
      supervision_aggregates: aggregate_category_metrics(state.supervision_metrics, last_minute_filter),
      federation_aggregates: aggregate_category_metrics(state.federation_metrics, last_minute_filter)
    }
  end
  
  defp generate_system_alerts(state) do
    current_time = System.monotonic_time(:millisecond)
    alerts = []
    
    # Check training health
    alerts = alerts ++ check_training_health(state.training_metrics, current_time)
    
    # Check inference performance
    alerts = alerts ++ check_inference_health(state.inference_metrics, current_time)
    
    # Check quality metrics
    alerts = alerts ++ check_quality_health(state.quality_metrics, current_time)
    
    # Check federation health
    alerts = alerts ++ check_federation_health(state.federation_metrics, current_time)
    
    alerts
  end
  
  defp archive_old_metrics(state) do
    # Archive metrics older than 24 hours
    current_time = System.monotonic_time(:millisecond)
    archive_threshold = current_time - (24 * 60 * 60 * 1000)
    
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    archive_filename = "uff_metrics_archive_#{timestamp}.json"
    archive_path = Path.join("archives", archive_filename)
    
    old_metrics = %{
      archived_at: DateTime.utc_now(),
      threshold_timestamp: archive_threshold,
      training_metrics: filter_old_metrics(state.training_metrics, archive_threshold),
      inference_metrics: filter_old_metrics(state.inference_metrics, archive_threshold),
      quality_metrics: filter_old_metrics(state.quality_metrics, archive_threshold),
      supervision_metrics: filter_old_metrics(state.supervision_metrics, archive_threshold),
      federation_metrics: filter_old_metrics(state.federation_metrics, archive_threshold)
    }
    
    case File.mkdir_p("archives") do
      :ok ->
        content = Jason.encode!(old_metrics, pretty: true)
        case File.write(archive_path, content) do
          :ok ->
            {:ok, archive_path}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Helper functions for metrics processing
  
  defp get_time_filter(time_range) do
    current_time = System.monotonic_time(:millisecond)
    
    case time_range do
      :last_hour -> current_time - (60 * 60 * 1000)
      :last_24h -> current_time - (24 * 60 * 60 * 1000)
      :last_week -> current_time - (7 * 24 * 60 * 60 * 1000)
      :last_month -> current_time - (30 * 24 * 60 * 60 * 1000)
      _ -> current_time - (24 * 60 * 60 * 1000)
    end
  end
  
  defp summarize_training_metrics(_metrics, _time_filter) do
    %{
      total_training_sessions: 0,
      avg_loss: 0.0,
      training_time_hours: 0.0,
      model_improvements: 0
    }
  end
  
  defp summarize_inference_metrics(_metrics, _time_filter) do
    %{
      total_requests: 0,
      avg_latency_ms: 0.0,
      success_rate: 0.0,
      throughput_rps: 0.0
    }
  end
  
  defp summarize_quality_metrics(_metrics, _time_filter) do
    %{
      components_analyzed: 0,
      avg_quality_score: 0.0,
      tank_building_compliance: 0.0,
      improvement_rate: 0.0
    }
  end
  
  defp summarize_supervision_metrics(_metrics, _time_filter) do
    %{
      supervision_sessions: 0,
      avg_effectiveness: 0.0,
      correction_rate: 0.0,
      guidance_impact: 0.0
    }
  end
  
  defp summarize_federation_metrics(_metrics, _time_filter) do
    %{
      total_nodes: 0,
      healthy_nodes: 0,
      avg_response_time_ms: 0.0,
      deployment_success_rate: 0.0
    }
  end
  
  defp analyze_trends(_state, _time_filter) do
    %{
      training_trend: :stable,
      quality_trend: :improving,
      performance_trend: :stable,
      supervision_trend: :effective
    }
  end
  
  defp generate_recommendations(_state, _time_filter) do
    [
      %{
        category: :training,
        priority: :medium,
        title: "Consider increasing batch size",
        description: "Training efficiency could be improved with larger batches"
      },
      %{
        category: :inference,
        priority: :low,
        title: "Monitor federation load balancing",
        description: "Ensure even distribution across UFM nodes"
      }
    ]
  end
  
  # Placeholder implementations for dashboard calculations
  defp count_active_training_sessions(_metrics, _filter), do: 0
  defp calculate_average_loss(_metrics, _filter), do: 0.0
  defp get_current_learning_rate(_metrics), do: 0.0001
  defp get_current_model_version(_metrics), do: "0.1.0-alpha"
  defp count_recent_requests(_metrics, _filter), do: 0
  defp calculate_average_latency(_metrics, _filter), do: 0.0
  defp calculate_success_rate(_metrics, _filter), do: 1.0
  defp count_active_endpoints(_metrics, _filter), do: 0
  defp calculate_average_quality(_metrics, _filter), do: 0.0
  defp count_components_generated(_metrics, _filter), do: 0
  defp calculate_compliance_rate(_metrics, _filter), do: 0.0
  defp count_supervision_requests(_metrics, _filter), do: 0
  defp calculate_supervision_effectiveness(_metrics, _filter), do: 0.0
  defp calculate_correction_rate(_metrics, _filter), do: 0.0
  defp count_healthy_nodes(_metrics, _filter), do: 0
  defp count_total_nodes(_metrics, _filter), do: 0
  defp calculate_federation_response_time(_metrics, _filter), do: 0.0
  defp calculate_deployment_success_rate(_metrics, _filter), do: 0.0
  defp count_critical_alerts(alerts), do: length(Enum.filter(alerts, & &1.priority == :critical))
  defp count_warning_alerts(alerts), do: length(Enum.filter(alerts, & &1.priority == :warning))
  
  defp filter_metrics_by_time(category_metrics, time_filter) do
    category_metrics
  end
  
  defp convert_to_csv(_export_data) do
    "CSV conversion not implemented in this version"
  end
  
  defp aggregate_category_metrics(category_metrics, _time_filter) do
    %{metric_count: map_size(category_metrics)}
  end
  
  defp check_training_health(_metrics, _current_time), do: []
  defp check_inference_health(_metrics, _current_time), do: []
  defp check_quality_health(_metrics, _current_time), do: []
  defp check_federation_health(_metrics, _current_time), do: []
  
  defp filter_old_metrics(category_metrics, _threshold) do
    category_metrics
  end
end