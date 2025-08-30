defmodule EliasCore.RequestPool do
  @moduledoc """
  GenStage producer for distributed request handling across the federation
  Manages request queues, priorities, and distribution to consumer nodes
  """
  
  use GenStage
  require Logger

  defstruct [
    :pending_requests,
    :request_counter,
    :priority_queues,
    :node_capabilities,
    :consumer_demand
  ]

  # Public API
  
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def submit_request(request_type, payload, options \\ %{}) do
    request = create_request(request_type, payload, options)
    GenStage.cast(__MODULE__, {:new_request, request})
    {:ok, request.id}
  end

  def get_queue_status do
    GenStage.call(__MODULE__, :get_queue_status)
  end

  def get_request_status(request_id) do
    GenStage.call(__MODULE__, {:get_request_status, request_id})
  end

  # GenStage Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🏊 EliasCore.RequestPool starting GenStage producer...")
    
    state = %__MODULE__{
      pending_requests: %{},
      request_counter: 0,
      priority_queues: initialize_priority_queues(),
      node_capabilities: %{},
      consumer_demand: 0
    }
    
    # Schedule periodic cleanup of completed requests
    schedule_cleanup()
    
    Logger.info("✅ EliasCore.RequestPool initialized")
    {:producer, state}
  end

  @impl true
  def handle_demand(demand, state) do
    Logger.debug("📈 RequestPool demand: #{demand} (total: #{state.consumer_demand + demand})")
    
    # Update total consumer demand
    new_demand = state.consumer_demand + demand
    
    # Dispatch available requests to meet demand
    {events, new_state} = dispatch_requests(%{state | consumer_demand: new_demand})
    
    {:noreply, events, new_state}
  end

  @impl true
  def handle_cast({:new_request, request}, state) do
    Logger.info("📨 New request received: #{request.type} (#{request.id})")
    
    # Add to pending requests
    pending_requests = Map.put(state.pending_requests, request.id, request)
    
    # Add to appropriate priority queue
    priority_queues = add_to_priority_queue(state.priority_queues, request)
    
    # Log request to blockchain
    EliasCore.ApeHarmony.record_event("request_submitted", %{
      request_id: request.id,
      request_type: request.type,
      priority: request.priority,
      client_node: request.client_node
    })
    
    # Dispatch if there's consumer demand
    new_state = %{state | 
      pending_requests: pending_requests,
      priority_queues: priority_queues,
      request_counter: state.request_counter + 1
    }
    
    {events, final_state} = dispatch_requests(new_state)
    
    {:noreply, events, final_state}
  end

  @impl true
  def handle_cast({:request_completed, request_id, result}, state) do
    Logger.info("✅ Request completed: #{request_id}")
    
    case Map.get(state.pending_requests, request_id) do
      nil ->
        Logger.warning("⚠️ Completed request not found: #{request_id}")
        {:noreply, [], state}
      
      request ->
        # Update request status
        completed_request = %{request | 
          status: :completed,
          result: result,
          completed_at: DateTime.utc_now()
        }
        
        # Update pending requests
        pending_requests = Map.put(state.pending_requests, request_id, completed_request)
        
        # Log completion to blockchain
        EliasCore.ApeHarmony.record_event("request_completed", %{
          request_id: request_id,
          processing_time_ms: DateTime.diff(completed_request.completed_at, request.submitted_at, :millisecond),
          processor_node: node()
        })
        
        new_state = %{state | pending_requests: pending_requests}
        {:noreply, [], new_state}
    end
  end

  @impl true
  def handle_cast({:request_failed, request_id, error}, state) do
    Logger.error("❌ Request failed: #{request_id} - #{inspect(error)}")
    
    case Map.get(state.pending_requests, request_id) do
      nil ->
        Logger.warning("⚠️ Failed request not found: #{request_id}")
        {:noreply, [], state}
      
      request ->
        # Update request status
        failed_request = %{request | 
          status: :failed,
          error: error,
          failed_at: DateTime.utc_now()
        }
        
        # Update pending requests
        pending_requests = Map.put(state.pending_requests, request_id, failed_request)
        
        # Log failure to blockchain
        EliasCore.ApeHarmony.record_event("request_failed", %{
          request_id: request_id,
          error: inspect(error),
          processor_node: node()
        })
        
        new_state = %{state | pending_requests: pending_requests}
        {:noreply, [], new_state}
    end
  end

  @impl true
  def handle_call(:get_queue_status, _from, state) do
    status = %{
      total_pending: map_size(state.pending_requests),
      high_priority: queue_size(state.priority_queues.high),
      medium_priority: queue_size(state.priority_queues.medium),
      low_priority: queue_size(state.priority_queues.low),
      consumer_demand: state.consumer_demand,
      total_processed: state.request_counter
    }
    {:reply, status, [], state}
  end

  def handle_call({:get_request_status, request_id}, _from, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        {:reply, {:error, :not_found}, [], state}
      
      request ->
        status = %{
          id: request.id,
          type: request.type,
          status: request.status,
          priority: request.priority,
          submitted_at: request.submitted_at,
          client_node: request.client_node
        }
        {:reply, {:ok, status}, [], state}
    end
  end

  @impl true
  def handle_info(:cleanup_completed_requests, state) do
    Logger.debug("🧹 Cleaning up completed requests...")
    
    # Remove requests completed more than 1 hour ago
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)
    
    cleaned_requests = state.pending_requests
    |> Enum.filter(fn {_id, request} ->
      case request.status do
        :completed -> DateTime.compare(request.completed_at || request.submitted_at, cutoff_time) == :gt
        :failed -> DateTime.compare(request.failed_at || request.submitted_at, cutoff_time) == :gt
        _ -> true  # Keep pending requests
      end
    end)
    |> Map.new()
    
    removed_count = map_size(state.pending_requests) - map_size(cleaned_requests)
    
    if removed_count > 0 do
      Logger.info("🧹 Cleaned up #{removed_count} completed requests")
    end
    
    schedule_cleanup()
    
    new_state = %{state | pending_requests: cleaned_requests}
    {:noreply, [], new_state}
  end

  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled RequestPool message: #{inspect(msg)}")
    {:noreply, [], state}
  end

  # Private Functions

  defp create_request(request_type, payload, options) do
    %{
      id: generate_request_id(),
      type: request_type,
      payload: payload,
      priority: Map.get(options, :priority, get_default_priority(request_type)),
      client_node: Map.get(options, :client_node, node()),
      submitted_at: DateTime.utc_now(),
      status: :pending,
      requirements: Map.get(options, :requirements, %{})
    }
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_default_priority(request_type) do
    case request_type do
      :system_issue -> :high
      :feature_request -> :medium
      :log_transmission -> :low
      :rule_update -> :high
      :ai_query -> :medium
      :background_task -> :low
      _ -> :medium
    end
  end

  defp initialize_priority_queues do
    %{
      high: :queue.new(),
      medium: :queue.new(),
      low: :queue.new()
    }
  end

  defp add_to_priority_queue(priority_queues, request) do
    queue = Map.get(priority_queues, request.priority, priority_queues.medium)
    updated_queue = :queue.in(request, queue)
    Map.put(priority_queues, request.priority, updated_queue)
  end

  defp dispatch_requests(state) when state.consumer_demand <= 0 do
    {[], state}
  end

  defp dispatch_requests(state) do
    # Dispatch requests by priority: high -> medium -> low
    {dispatched, remaining_queues, remaining_demand} = 
      [:high, :medium, :low]
      |> Enum.reduce({[], state.priority_queues, state.consumer_demand}, fn priority, {acc_dispatched, acc_queues, acc_demand} ->
        if acc_demand > 0 do
          {priority_dispatched, updated_queue, new_demand} = 
            dispatch_from_queue(Map.get(acc_queues, priority), acc_demand)
          
          updated_queues = Map.put(acc_queues, priority, updated_queue)
          {acc_dispatched ++ priority_dispatched, updated_queues, new_demand}
        else
          {acc_dispatched, acc_queues, acc_demand}
        end
      end)
    
    # Update request status to processing
    updated_requests = dispatched
    |> Enum.reduce(state.pending_requests, fn request, acc ->
      processing_request = %{request | status: :processing}
      Map.put(acc, request.id, processing_request)
    end)
    
    new_state = %{state |
      priority_queues: remaining_queues,
      consumer_demand: remaining_demand,
      pending_requests: updated_requests
    }
    
    if length(dispatched) > 0 do
      Logger.debug("📤 Dispatched #{length(dispatched)} requests to consumers")
    end
    
    {dispatched, new_state}
  end

  defp dispatch_from_queue(queue, demand) do
    dispatch_from_queue_recursive(queue, demand, [])
  end

  defp dispatch_from_queue_recursive(queue, demand, acc) when demand <= 0 do
    {Enum.reverse(acc), queue, demand}
  end

  defp dispatch_from_queue_recursive(queue, demand, acc) do
    case :queue.out(queue) do
      {{:value, request}, remaining_queue} ->
        dispatch_from_queue_recursive(remaining_queue, demand - 1, [request | acc])
      
      {:empty, queue} ->
        {Enum.reverse(acc), queue, demand}
    end
  end

  defp queue_size(queue) do
    :queue.len(queue)
  end

  defp schedule_cleanup do
    # Clean up completed requests every 30 minutes
    Process.send_after(self(), :cleanup_completed_requests, 30 * 60 * 1000)
  end
end