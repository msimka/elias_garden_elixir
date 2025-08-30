defmodule Elias.RequestPool do
  @moduledoc """
  Request Pool system using GenStage for distributed request handling.
  
  ApeMacs clients push requests here, available ELIAS nodes consume them.
  All activity logged to APE HARMONY blockchain.
  """
  
  use GenStage
  require Logger

  @doc """
  Start the request pool producer
  """
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submit a request from ApeMacs client to the pool
  """
  def submit_request(request_type, payload, client_node \\ node()) do
    request = %{
      id: generate_request_id(),
      type: request_type,
      payload: payload,
      client_node: client_node,
      submitted_at: DateTime.utc_now(),
      status: :pending,
      priority: get_request_priority(request_type)
    }
    
    Logger.info("📥 Request submitted to pool: #{request.id} from #{client_node}")
    GenStage.cast(__MODULE__, {:new_request, request})
    {:ok, request.id}
  end

  @doc """
  Get pool status and metrics
  """
  def get_status do
    GenStage.call(__MODULE__, :get_status)
  end

  # GenStage Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🏊 Request Pool starting (GenStage Producer)")
    
    state = %{
      pending_requests: :queue.new(),
      active_requests: %{},
      completed_requests: [],
      consumer_nodes: MapSet.new(),
      metrics: %{
        total_submitted: 0,
        total_completed: 0,
        average_processing_time: 0
      }
    }
    
    # Monitor node connections for consumer management
    :net_kernel.monitor_nodes(true)
    
    {:producer, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      pending_count: :queue.len(state.pending_requests),
      active_count: map_size(state.active_requests),
      completed_count: length(state.completed_requests),
      consumer_nodes: MapSet.to_list(state.consumer_nodes),
      metrics: state.metrics
    }
    
    {:reply, status, [], state}
  end

  @impl true
  def handle_cast({:new_request, request}, state) do
    Logger.info("🔄 Adding request #{request.id} to pool")
    
    # Add to pending queue (priority queue based on request priority)
    new_queue = :queue.in(request, state.pending_requests)
    
    # Update metrics
    new_metrics = %{state.metrics | total_submitted: state.metrics.total_submitted + 1}
    
    # Broadcast to APE HARMONY blockchain (placeholder)
    broadcast_to_blockchain(:request_submitted, request)
    
    new_state = %{state | 
      pending_requests: new_queue,
      metrics: new_metrics
    }
    
    {:noreply, [], new_state}
  end

  @impl true
  def handle_cast({:request_completed, request_id, result, processing_time}, state) do
    case Map.pop(state.active_requests, request_id) do
      {nil, _} ->
        Logger.warning("⚠️ Completed request not found in active: #{request_id}")
        {:noreply, [], state}
        
      {request, new_active} ->
        completed_request = %{request | 
          status: :completed,
          result: result,
          completed_at: DateTime.utc_now(),
          processing_time: processing_time
        }
        
        Logger.info("✅ Request completed: #{request_id} in #{processing_time}ms")
        
        # Update metrics
        new_avg_time = calculate_average_processing_time(
          state.metrics.average_processing_time,
          state.metrics.total_completed,
          processing_time
        )
        
        new_metrics = %{state.metrics |
          total_completed: state.metrics.total_completed + 1,
          average_processing_time: new_avg_time
        }
        
        # Broadcast completion to blockchain
        broadcast_to_blockchain(:request_completed, completed_request)
        
        new_state = %{state |
          active_requests: new_active,
          completed_requests: [completed_request | state.completed_requests],
          metrics: new_metrics
        }
        
        {:noreply, [], new_state}
    end
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    Logger.debug("🎯 Consumer demanding #{demand} requests")
    {events, new_queue} = take_requests(state.pending_requests, demand, [])
    
    # Move events to active requests
    new_active = Enum.reduce(events, state.active_requests, fn request, acc ->
      updated_request = %{request | status: :active, started_at: DateTime.utc_now()}
      Map.put(acc, request.id, updated_request)
    end)
    
    new_state = %{state |
      pending_requests: new_queue,
      active_requests: new_active
    }
    
    {:noreply, events, new_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("🔗 Consumer node connected: #{node}")
    new_consumers = MapSet.put(state.consumer_nodes, node)
    {:noreply, [], %{state | consumer_nodes: new_consumers}}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.info("💔 Consumer node disconnected: #{node}")
    new_consumers = MapSet.delete(state.consumer_nodes, node)
    
    # Handle orphaned requests from this node
    {orphaned, remaining_active} = Map.split_with(state.active_requests, fn {_id, req} ->
      req.processing_node == node
    end)
    
    if map_size(orphaned) > 0 do
      Logger.warning("🔄 Re-queueing #{map_size(orphaned)} orphaned requests")
      requeued = Enum.reduce(orphaned, state.pending_requests, fn {_id, req}, queue ->
        reset_request = %{req | status: :pending, started_at: nil, processing_node: nil}
        :queue.in(reset_request, queue)
      end)
      
      new_state = %{state |
        consumer_nodes: new_consumers,
        pending_requests: requeued,
        active_requests: remaining_active
      }
      
      {:noreply, [], new_state}
    else
      {:noreply, [], %{state | consumer_nodes: new_consumers}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔄 Unhandled message in RequestPool: #{inspect(msg)}")
    {:noreply, [], state}
  end

  # Private Functions

  defp take_requests(queue, 0, acc), do: {Enum.reverse(acc), queue}
  defp take_requests(queue, demand, acc) do
    case :queue.out(queue) do
      {{:value, request}, new_queue} ->
        updated_request = %{request | processing_node: node()}
        take_requests(new_queue, demand - 1, [updated_request | acc])
      {:empty, queue} ->
        {Enum.reverse(acc), queue}
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_request_priority(:rule_execution), do: :high
  defp get_request_priority(:system_issue), do: :high
  defp get_request_priority(:feature_request), do: :medium
  defp get_request_priority(:log_transmission), do: :low
  defp get_request_priority(:file_operation), do: :medium
  defp get_request_priority(:sync_operation), do: :low
  defp get_request_priority(:deepseek_query), do: :high
  defp get_request_priority(_), do: :medium

  defp calculate_average_processing_time(_current_avg, completed_count, new_time) when completed_count == 0 do
    new_time
  end
  defp calculate_average_processing_time(current_avg, completed_count, new_time) do
    (current_avg * completed_count + new_time) / (completed_count + 1)
  end

  defp broadcast_to_blockchain(event_type, data) do
    # Record event to APE HARMONY blockchain
    blockchain_entry = %{
      event: event_type,
      data: sanitize_for_blockchain(data),
      timestamp: DateTime.utc_now(),
      node: node()
    }
    
    Logger.debug("🔗 Broadcasting to APE HARMONY: #{inspect(blockchain_entry)}")
    
    # Record to APE HARMONY blockchain
    Elias.ApeHarmony.record_event(event_type, blockchain_entry)
  end

  defp sanitize_for_blockchain(data) when is_map(data) do
    # Remove sensitive data before blockchain logging
    data
    |> Map.drop([:api_key, :password, :secret])
    |> Map.put(:payload_hash, hash_payload(data[:payload]))
    |> Map.drop([:payload])  # Store hash instead of full payload
  end

  defp hash_payload(nil), do: nil
  defp hash_payload(payload) do
    :crypto.hash(:sha256, inspect(payload)) |> Base.encode16(case: :lower)
  end
end