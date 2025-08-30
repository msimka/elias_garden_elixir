defmodule Elias.RequestConsumer do
  @moduledoc """
  GenStage Consumer that processes requests from the RequestPool.
  
  Each ELIAS node runs consumers to pull and process requests.
  Communicates results back to requesting ApeMacs clients.
  """
  
  use GenStage
  require Logger

  @doc """
  Start the request consumer
  """
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenStage Callbacks

  @impl true
  def init(opts) do
    Logger.info("🏃 Request Consumer starting on #{node()}")
    
    state = %{
      node_id: node(),
      max_demand: opts[:max_demand] || 5,
      processing_requests: %{},
      node_capabilities: determine_node_capabilities()
    }
    
    # Subscribe to the RequestPool producer
    subscribe_opts = [
      max_demand: state.max_demand,
      min_demand: 1
    ]
    
    {:consumer, state, subscribe_to: [{Elias.RequestPool, subscribe_opts}]}
  end

  @impl true
  def handle_events(requests, _from, state) do
    Logger.info("📋 Processing #{length(requests)} requests on #{node()}")
    
    # Process each request asynchronously
    new_processing = Enum.reduce(requests, state.processing_requests, fn request, acc ->
      Logger.info("🔄 Starting request #{request.id}: #{request.type}")
      
      # Spawn async task to process request
      task = Task.async(fn -> process_request(request) end)
      
      Map.put(acc, request.id, %{request: request, task: task, started_at: DateTime.utc_now()})
    end)
    
    new_state = %{state | processing_requests: new_processing}
    
    # Check for completed tasks
    check_completed_tasks(new_state)
  end

  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Task completed
    Process.demonitor(ref, [:flush])
    
    # Find which request this was
    case find_request_by_task_ref(state.processing_requests, ref) do
      {request_id, request_info} ->
        Logger.info("✅ Request #{request_id} completed with result: #{inspect(result)}")
        
        processing_time = DateTime.diff(DateTime.utc_now(), request_info.started_at, :millisecond)
        
        # Notify the RequestPool of completion
        GenStage.cast(Elias.RequestPool, {:request_completed, request_id, result, processing_time})
        
        # Send result back to requesting client if it's on a different node
        if request_info.request.client_node != node() do
          send_result_to_client(request_info.request, result)
        end
        
        # Remove from processing
        new_processing = Map.delete(state.processing_requests, request_id)
        {:noreply, [], %{state | processing_requests: new_processing}}
        
      nil ->
        Logger.warning("⚠️ Could not find request for completed task: #{inspect(ref)}")
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # Task crashed
    case find_request_by_task_ref(state.processing_requests, ref) do
      {request_id, request_info} ->
        Logger.error("❌ Request #{request_id} failed: #{inspect(reason)}")
        
        processing_time = DateTime.diff(DateTime.utc_now(), request_info.started_at, :millisecond)
        error_result = {:error, reason}
        
        # Notify the RequestPool of failure
        GenStage.cast(Elias.RequestPool, {:request_completed, request_id, error_result, processing_time})
        
        # Send error back to client
        if request_info.request.client_node != node() do
          send_result_to_client(request_info.request, error_result)
        end
        
        # Remove from processing
        new_processing = Map.delete(state.processing_requests, request_id)
        {:noreply, [], %{state | processing_requests: new_processing}}
        
      nil ->
        {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled message in RequestConsumer: #{inspect(msg)}")
    {:noreply, [], state}
  end

  # Private Functions

  defp process_request(request) do
    Logger.info("🔧 Processing #{request.type} request: #{request.id}")
    
    case request.type do
      :rule_execution ->
        process_rule_execution(request.payload)
        
      :file_operation ->
        process_file_operation(request.payload)
        
      :sync_operation ->
        process_sync_operation(request.payload)
        
      :system_issue ->
        process_system_issue(request.payload)
        
      :feature_request ->
        process_feature_request(request.payload)
        
      :log_transmission ->
        process_log_transmission(request.payload)
        
      :deepseek_query ->
        process_deepseek_query(request.payload)
        
      _ ->
        {:error, {:unknown_request_type, request.type}}
    end
  end

  defp process_claude_query(%{prompt: _prompt, context: _context}) do
    # Claude queries should NOT go through the request pool
    # Users talk to Claude directly on their own account via ApeMacs
    {:error, :claude_queries_not_supported_in_pool}
  end

  defp process_rule_execution(%{rule_name: rule_name, args: args}) do
    # Execute rule via daemon
    case GenServer.call(Elias.Daemon, {:execute_rule, rule_name, args}) do
      {:ok, result} -> 
        {:ok, %{result: result, executed_by: node()}}
      error -> 
        error
    end
  end

  defp process_file_operation(%{operation: op, path: path} = payload) do
    content = Map.get(payload, :content)
    
    case GenServer.call(Elias.Daemon, {:execute_rule, "daemon_commands.file_operation", [op, path, content]}) do
      {:ok, result} -> 
        {:ok, %{result: result, operation: op, path: path}}
      error -> 
        error
    end
  end

  defp process_sync_operation(%{type: sync_type}) do
    case sync_type do
      :git ->
        GenServer.cast(Elias.Daemon, :sync_locations)
        {:ok, %{message: "Git sync initiated", node: node()}}
        
      :rules ->
        Elias.P2P.sync_rules_across_cluster()
        {:ok, %{message: "Rules sync initiated", node: node()}}
        
      _ ->
        {:error, {:unknown_sync_type, sync_type}}
    end
  end

  defp process_system_issue(%{description: description, logs: logs, client_info: client_info}) do
    Logger.warning("🚨 System issue reported from #{client_info.node}: #{description}")
    
    # Log the issue for analysis
    issue_record = %{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      description: description,
      logs: logs,
      client_info: client_info,
      reported_at: DateTime.utc_now(),
      processed_by: node(),
      status: :acknowledged
    }
    
    # TODO: Store in issue database for tracking
    # TODO: Possibly trigger automated diagnostics
    
    {:ok, %{
      message: "System issue acknowledged",
      issue_id: issue_record.id,
      next_steps: ["Issue logged for analysis", "Check ELIAS.md for updates"],
      processed_by: node()
    }}
  end
  
  defp process_feature_request(%{description: description, client_info: client_info}) do
    Logger.info("💡 Feature request from #{client_info.node}: #{description}")
    
    feature_request = %{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      description: description,
      client_info: client_info,
      requested_at: DateTime.utc_now(),
      processed_by: node(),
      status: :under_review,
      priority: determine_feature_priority(description)
    }
    
    # TODO: Add to feature backlog
    # TODO: Estimate implementation effort
    
    {:ok, %{
      message: "Feature request received",
      request_id: feature_request.id,
      estimated_timeline: "Will be reviewed in next development cycle",
      priority: feature_request.priority,
      processed_by: node()
    }}
  end
  
  defp process_log_transmission(%{logs: logs, client_info: client_info, timestamp: timestamp}) do
    Logger.info("📊 Logs received from #{client_info.node} (#{map_size(logs)} log types)")
    
    # Process and analyze the logs
    log_analysis = analyze_system_logs(logs, client_info)
    
    # TODO: Store logs for trend analysis
    # TODO: Detect performance issues or anomalies
    # TODO: Update system health dashboard
    
    {:ok, %{
      message: "Logs processed successfully",
      analysis: log_analysis,
      recommendations: generate_recommendations(log_analysis),
      processed_by: node(),
      processed_at: DateTime.utc_now()
    }}
  end

  defp process_deepseek_query(%{prompt: _prompt, context: _context}) do
    # Route to Geppetto (DeepSeek model) - only available on full nodes
    if node_has_geppetto?() do
      # TODO: Implement actual DeepSeek integration
      {:ok, %{
        response: "DeepSeek response would be here",
        model: "deepseek-coder-6.7b-fp16",
        processed_by: node(),
        tokens_used: 85
      }}
    else
      {:error, :geppetto_not_available}
    end
  end

  defp send_result_to_client(request, result) do
    client_node = String.to_atom(to_string(request.client_node))
    
    Logger.info("📤 Sending result to client #{client_node} for request #{request.id}")
    
    message = {:request_result, request.id, result}
    
    case :rpc.cast(client_node, Elias.ApeMacs, :handle_request_result, [message]) do
      true ->
        Logger.info("✅ Result sent to #{client_node}")
      false ->
        Logger.warning("⚠️ Failed to send result to #{client_node}")
    end
  end

  defp find_request_by_task_ref(processing, ref) do
    Enum.find_value(processing, fn {id, info} ->
      if info.task.ref == ref, do: {id, info}, else: nil
    end)
  end

  defp check_completed_tasks(state) do
    # This is called to handle any race conditions with task completion
    {:noreply, [], state}
  end

  # Helper functions for ApeMacs-ELIAS communication
  
  defp determine_feature_priority(description) do
    description_lower = String.downcase(description)
    
    cond do
      String.contains?(description_lower, ["urgent", "critical", "broken", "error", "crash"]) -> :high
      String.contains?(description_lower, ["improvement", "optimize", "enhance"]) -> :medium
      true -> :low
    end
  end
  
  defp analyze_system_logs(logs, client_info) do
    # Analyze logs for patterns, errors, and performance issues
    %{
      error_count: count_errors(logs),
      performance_score: calculate_performance_score(logs),
      recommendations: []  # Will be filled by analysis
    }
  end
  
  defp count_errors(%{error_logs: error_logs}), do: length(error_logs)
  defp count_errors(_), do: 0
  
  defp calculate_performance_score(%{performance_metrics: %{system_responsiveness: responsiveness}}) do
    case responsiveness do
      "excellent" -> 95
      "good" -> 85
      "average" -> 70
      "poor" -> 50
      _ -> 75
    end
  end
  defp calculate_performance_score(_), do: 75
  
  defp generate_recommendations(log_analysis) do
    recommendations = []
    
    recommendations = if log_analysis.error_count > 5 do
      ["Consider investigating recurring errors" | recommendations]
    else
      recommendations
    end
    
    recommendations = if log_analysis.performance_score < 70 do
      ["System performance may need optimization" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["System appears to be running normally"]
    else
      recommendations
    end
  end

  defp determine_node_capabilities do
    # Determine what this node can process
    # NOTE: claude_query removed - users talk to Claude directly via ApeMacs
    capabilities = [:rule_execution, :file_operation, :sync_operation, 
                   :system_issue, :feature_request, :log_transmission]
    
    # Add Geppetto capability if this is a full node
    if node_has_geppetto?() do
      [:deepseek_query | capabilities]
    else
      capabilities
    end
  end

  defp node_has_geppetto? do
    # Check if this node has the Geppetto model available
    System.get_env("ELIAS_NODE_TYPE", "client") == "full_node"
  end
end