defmodule MultiFormatConverter.Optimization.PerformanceMonitor do
  @moduledoc """
  Performance Monitoring System for Multi-Format Converter
  
  RESPONSIBILITY: Monitor and optimize pipeline performance across all stages
  
  Tank Building Stage 3: Optimize
  - Performance metrics collection and analysis
  - Bottleneck detection and reporting
  - Memory usage tracking
  - Throughput optimization recommendations
  - Component-level performance profiling
  
  Integration with ELIAS ULM (User Logging Manager) for distributed monitoring
  """
  
  use GenServer
  require Logger

  # Performance tracking configuration
  @performance_history_size 1000
  @memory_warning_threshold 100 * 1024 * 1024  # 100MB
  @slowdown_warning_threshold 5000  # 5 seconds

  # Performance metrics structure
  defmodule PerformanceMetrics do
    defstruct [
      :operation_id,
      :operation_type,
      :start_time,
      :end_time,
      :duration_ms,
      :input_size_bytes,
      :output_size_bytes,
      :memory_used_bytes,
      :component_timings,
      :success,
      :error_reason,
      :optimization_score
    ]
  end

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start tracking a new operation
  
  Returns operation_id for tracking throughout pipeline
  """
  def start_operation(operation_type, input_size \\ 0) do
    operation_id = generate_operation_id()
    
    GenServer.cast(__MODULE__, {
      :start_operation,
      operation_id,
      operation_type,
      input_size,
      System.monotonic_time(:millisecond)
    })
    
    operation_id
  end

  @doc """
  Record component timing within an operation
  """
  def record_component_timing(operation_id, component_name, duration_ms) do
    GenServer.cast(__MODULE__, {
      :record_component_timing,
      operation_id,
      component_name,
      duration_ms
    })
  end

  @doc """
  Complete operation tracking
  """
  def complete_operation(operation_id, success \\ true, output_size \\ 0, error_reason \\ nil) do
    GenServer.cast(__MODULE__, {
      :complete_operation,
      operation_id,
      success,
      output_size,
      error_reason,
      System.monotonic_time(:millisecond)
    })
  end

  @doc """
  Get current performance statistics
  """
  def get_performance_stats do
    GenServer.call(__MODULE__, :get_performance_stats)
  end

  @doc """
  Get optimization recommendations based on performance data
  """
  def get_optimization_recommendations do
    GenServer.call(__MODULE__, :get_optimization_recommendations)
  end

  @doc """
  Get detailed performance report
  """
  def get_performance_report do
    GenServer.call(__MODULE__, :get_performance_report)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("PerformanceMonitor: Starting optimization monitoring")
    
    state = %{
      active_operations: %{},
      completed_operations: [],
      performance_history: [],
      system_metrics: %{
        total_operations: 0,
        successful_operations: 0,
        failed_operations: 0,
        total_processing_time: 0,
        total_bytes_processed: 0
      }
    }
    
    # Schedule periodic system metrics collection
    :timer.send_interval(30_000, :collect_system_metrics)
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:start_operation, operation_id, operation_type, input_size, start_time}, state) do
    Logger.debug("PerformanceMonitor: Starting operation #{operation_id} (#{operation_type})")
    
    operation = %{
      operation_id: operation_id,
      operation_type: operation_type,
      start_time: start_time,
      input_size_bytes: input_size,
      component_timings: %{},
      memory_at_start: get_memory_usage()
    }
    
    new_active = Map.put(state.active_operations, operation_id, operation)
    
    {:noreply, %{state | active_operations: new_active}}
  end

  @impl true
  def handle_cast({:record_component_timing, operation_id, component_name, duration_ms}, state) do
    case Map.get(state.active_operations, operation_id) do
      nil ->
        Logger.warn("PerformanceMonitor: Unknown operation #{operation_id}")
        {:noreply, state}
        
      operation ->
        updated_timings = Map.put(operation.component_timings, component_name, duration_ms)
        updated_operation = %{operation | component_timings: updated_timings}
        new_active = Map.put(state.active_operations, operation_id, updated_operation)
        
        {:noreply, %{state | active_operations: new_active}}
    end
  end

  @impl true
  def handle_cast({:complete_operation, operation_id, success, output_size, error_reason, end_time}, state) do
    case Map.get(state.active_operations, operation_id) do
      nil ->
        Logger.warn("PerformanceMonitor: Cannot complete unknown operation #{operation_id}")
        {:noreply, state}
        
      operation ->
        # Calculate final metrics
        duration_ms = end_time - operation.start_time
        memory_used = get_memory_usage() - operation.memory_at_start
        
        completed_metrics = %PerformanceMetrics{
          operation_id: operation_id,
          operation_type: operation.operation_type,
          start_time: operation.start_time,
          end_time: end_time,
          duration_ms: duration_ms,
          input_size_bytes: operation.input_size_bytes,
          output_size_bytes: output_size,
          memory_used_bytes: max(memory_used, 0),
          component_timings: operation.component_timings,
          success: success,
          error_reason: error_reason,
          optimization_score: calculate_optimization_score(duration_ms, operation.input_size_bytes, memory_used)
        }
        
        # Update system metrics
        new_system_metrics = update_system_metrics(state.system_metrics, completed_metrics)
        
        # Add to performance history (keep last N operations)
        new_history = [completed_metrics | state.performance_history]
        |> Enum.take(@performance_history_size)
        
        # Remove from active operations
        new_active = Map.delete(state.active_operations, operation_id)
        
        # Log performance warnings if needed
        log_performance_warnings(completed_metrics)
        
        Logger.info("PerformanceMonitor: Completed operation #{operation_id} in #{duration_ms}ms")
        
        {:noreply, %{
          state |
          active_operations: new_active,
          performance_history: new_history,
          system_metrics: new_system_metrics
        }}
    end
  end

  @impl true
  def handle_call(:get_performance_stats, _from, state) do
    stats = %{
      active_operations_count: map_size(state.active_operations),
      completed_operations_count: length(state.performance_history),
      system_metrics: state.system_metrics,
      recent_performance: Enum.take(state.performance_history, 10),
      memory_usage: get_memory_usage(),
      uptime_ms: System.monotonic_time(:millisecond)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_optimization_recommendations, _from, state) do
    recommendations = generate_optimization_recommendations(state)
    {:reply, recommendations, state}
  end

  @impl true
  def handle_call(:get_performance_report, _from, state) do
    report = generate_detailed_performance_report(state)
    {:reply, report, state}
  end

  @impl true
  def handle_info(:collect_system_metrics, state) do
    # Collect system-wide metrics periodically
    Logger.debug("PerformanceMonitor: Collecting system metrics")
    {:noreply, state}
  end

  # Private Implementation

  defp generate_operation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_memory_usage do
    :erlang.memory(:total)
  end

  defp calculate_optimization_score(duration_ms, input_size_bytes, memory_used_bytes) do
    # Simple scoring: lower is better
    # Factors: speed (ms/MB), memory efficiency (bytes/input_byte)
    
    input_mb = max(input_size_bytes / (1024 * 1024), 0.1)
    speed_score = duration_ms / input_mb  # ms per MB
    memory_score = memory_used_bytes / max(input_size_bytes, 1)  # memory overhead ratio
    
    # Combine scores (lower is better)
    speed_score * 0.7 + memory_score * 0.3
  end

  defp update_system_metrics(system_metrics, completed_metrics) do
    %{
      total_operations: system_metrics.total_operations + 1,
      successful_operations: system_metrics.successful_operations + if(completed_metrics.success, do: 1, else: 0),
      failed_operations: system_metrics.failed_operations + if(completed_metrics.success, do: 0, else: 1),
      total_processing_time: system_metrics.total_processing_time + completed_metrics.duration_ms,
      total_bytes_processed: system_metrics.total_bytes_processed + completed_metrics.input_size_bytes
    }
  end

  defp log_performance_warnings(metrics) do
    cond do
      metrics.duration_ms > @slowdown_warning_threshold ->
        Logger.warn("PerformanceMonitor: Slow operation detected: #{metrics.operation_id} took #{metrics.duration_ms}ms")
        
      metrics.memory_used_bytes > @memory_warning_threshold ->
        Logger.warn("PerformanceMonitor: High memory usage: #{metrics.operation_id} used #{format_bytes(metrics.memory_used_bytes)}")
        
      metrics.optimization_score > 100 ->
        Logger.warn("PerformanceMonitor: Poor optimization score: #{Float.round(metrics.optimization_score, 2)} for #{metrics.operation_id}")
        
      true ->
        :ok
    end
  end

  defp generate_optimization_recommendations(state) do
    recent_operations = Enum.take(state.performance_history, 50)
    
    recommendations = []
    
    # Analyze average processing time
    recommendations = if length(recent_operations) > 0 do
      avg_duration = recent_operations
      |> Enum.map(&(&1.duration_ms))
      |> Enum.sum()
      |> Kernel./(length(recent_operations))
      
      if avg_duration > 1000 do
        [
          %{
            type: :performance,
            priority: :high,
            title: "High average processing time",
            description: "Average processing time is #{Float.round(avg_duration, 1)}ms. Consider pipeline parallelization.",
            recommendation: "Implement parallel component processing"
          }
          | recommendations
        ]
      else
        recommendations
      end
    else
      recommendations
    end
    
    # Analyze memory usage patterns
    recommendations = if length(recent_operations) > 0 do
      high_memory_ops = recent_operations
      |> Enum.filter(&(&1.memory_used_bytes > @memory_warning_threshold))
      |> length()
      
      if high_memory_ops > length(recent_operations) * 0.2 do
        [
          %{
            type: :memory,
            priority: :medium,
            title: "High memory usage detected",
            description: "#{high_memory_ops}/#{length(recent_operations)} operations used excessive memory.",
            recommendation: "Implement streaming processing for large files"
          }
          | recommendations
        ]
      else
        recommendations
      end
    else
      recommendations
    end
    
    # Analyze component bottlenecks
    component_analysis = analyze_component_bottlenecks(recent_operations)
    recommendations = recommendations ++ component_analysis
    
    %{
      total_recommendations: length(recommendations),
      high_priority: Enum.count(recommendations, &(&1.priority == :high)),
      medium_priority: Enum.count(recommendations, &(&1.priority == :medium)),
      low_priority: Enum.count(recommendations, &(&1.priority == :low)),
      recommendations: recommendations
    }
  end

  defp analyze_component_bottlenecks(operations) do
    # Find components that consistently take the most time
    component_times = operations
    |> Enum.flat_map(fn op ->
      Enum.map(op.component_timings, fn {component, time} -> {component, time} end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {component, times} ->
      avg_time = Enum.sum(times) / length(times)
      {component, avg_time, length(times)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Generate recommendations for slow components
    Enum.take(component_times, 2)
    |> Enum.filter(fn {_component, avg_time, _count} -> avg_time > 500 end)
    |> Enum.map(fn {component, avg_time, count} ->
      %{
        type: :component_bottleneck,
        priority: :medium,
        title: "Component bottleneck detected",
        description: "#{component} averages #{Float.round(avg_time, 1)}ms (#{count} samples)",
        recommendation: "Optimize #{component} implementation or add caching"
      }
    end)
  end

  defp generate_detailed_performance_report(state) do
    recent_ops = Enum.take(state.performance_history, 100)
    
    %{
      report_generated_at: DateTime.utc_now(),
      monitoring_period: "Last #{length(recent_ops)} operations",
      system_metrics: state.system_metrics,
      performance_summary: %{
        average_duration_ms: calculate_average_duration(recent_ops),
        average_throughput_mbps: calculate_average_throughput(recent_ops),
        success_rate: calculate_success_rate(recent_ops),
        memory_efficiency: calculate_memory_efficiency(recent_ops)
      },
      component_performance: analyze_component_performance(recent_ops),
      optimization_opportunities: generate_optimization_recommendations(state),
      trend_analysis: analyze_performance_trends(recent_ops)
    }
  end

  defp calculate_average_duration(operations) when length(operations) > 0 do
    operations |> Enum.map(&(&1.duration_ms)) |> Enum.sum() |> Kernel./(length(operations))
  end
  defp calculate_average_duration(_), do: 0

  defp calculate_average_throughput(operations) when length(operations) > 0 do
    total_mb = operations |> Enum.map(&(&1.input_size_bytes)) |> Enum.sum() |> Kernel./(1024 * 1024)
    total_seconds = operations |> Enum.map(&(&1.duration_ms)) |> Enum.sum() |> Kernel./(1000)
    if total_seconds > 0, do: total_mb / total_seconds, else: 0
  end
  defp calculate_average_throughput(_), do: 0

  defp calculate_success_rate(operations) when length(operations) > 0 do
    successful = operations |> Enum.count(&(&1.success))
    successful / length(operations) * 100
  end
  defp calculate_success_rate(_), do: 0

  defp calculate_memory_efficiency(operations) when length(operations) > 0 do
    # Memory efficiency: lower memory per byte processed is better
    total_memory = operations |> Enum.map(&(&1.memory_used_bytes)) |> Enum.sum()
    total_input = operations |> Enum.map(&(&1.input_size_bytes)) |> Enum.sum()
    if total_input > 0, do: total_memory / total_input, else: 0
  end
  defp calculate_memory_efficiency(_), do: 0

  defp analyze_component_performance(operations) do
    operations
    |> Enum.flat_map(&Map.to_list(&1.component_timings))
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {component, times} ->
      %{
        component: component,
        average_time_ms: Enum.sum(times) / length(times),
        min_time_ms: Enum.min(times),
        max_time_ms: Enum.max(times),
        sample_count: length(times)
      }
    end)
    |> Enum.sort_by(&(&1.average_time_ms), :desc)
  end

  defp analyze_performance_trends(operations) when length(operations) > 20 do
    # Simple trend analysis: compare first half vs second half
    mid_point = div(length(operations), 2)
    {recent, older} = Enum.split(operations, mid_point)
    
    recent_avg = calculate_average_duration(recent)
    older_avg = calculate_average_duration(older)
    
    trend = cond do
      recent_avg < older_avg * 0.9 -> :improving
      recent_avg > older_avg * 1.1 -> :degrading
      true -> :stable
    end
    
    %{
      trend: trend,
      recent_average_ms: recent_avg,
      historical_average_ms: older_avg,
      change_percent: ((recent_avg - older_avg) / older_avg) * 100
    }
  end
  defp analyze_performance_trends(_), do: %{trend: :insufficient_data}

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end