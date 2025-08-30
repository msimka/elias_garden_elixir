#!/usr/bin/env elixir
# Proper distributed Erlang test using modern peer module

defmodule ProperDistributedTest do
  @moduledoc """
  Test distributed communication using modern Erlang :peer module
  """

  def run do
    IO.puts("🧪 ELIAS Garden Proper Distributed Test")
    IO.puts("=" |> String.duplicate(45))
    
    # Ensure we're on a distributed node
    ensure_distributed_node()
    
    # Show current node info
    show_node_info()
    
    # Test peer node creation (modern way)
    test_peer_node_creation()
    
    # Test two-node communication
    test_two_node_setup()
    
    IO.puts("\n✅ Distributed tests completed!")
  end

  defp ensure_distributed_node do
    unless Node.alive?() do
      IO.puts("🚀 Starting distributed node...")
      :net_kernel.start([:main_test, :shortnames])
      :net_kernel.set_net_ticktime(10)
      Node.set_cookie(:elias_test_cookie)
    end
  end

  defp show_node_info do
    IO.puts("\n🔍 Current Node Information:")
    IO.puts("   Node: #{node()}")
    IO.puts("   Alive: #{Node.alive?()}")
    IO.puts("   Cookie: #{:erlang.get_cookie()}")
    IO.puts("   EPMD port: 4369")
    IO.puts("   Connected nodes: #{inspect(Node.list())}")
  end

  defp test_peer_node_creation do
    IO.puts("\n🤝 Testing modern peer node creation...")
    
    # Use peer module (modern replacement for slave)
    case :peer.start(%{name: :worker_test, host: ~c"localhost"}) do
      {:ok, peer, worker_node} ->
        IO.puts("✅ Started peer node: #{worker_node}")
        
        # Test basic communication
        result = :rpc.call(worker_node, :erlang, :node, [])
        IO.puts("   Worker node reports: #{result}")
        
        # Test message passing
        test_message_passing_peer(worker_node)
        
        # Clean up
        :peer.stop(peer)
        IO.puts("🧹 Cleaned up peer node")
        
      {:error, reason} ->
        IO.puts("❌ Failed to start peer node: #{inspect(reason)}")
        IO.puts("   Falling back to manual testing...")
        test_manual_node_simulation()
    end
  end

  defp test_message_passing_peer(worker_node) do
    IO.puts("📨 Testing message passing with #{worker_node}...")
    
    # Start a simple process on the worker node
    worker_pid = :rpc.call(worker_node, :erlang, :spawn, [fn ->
      receive do
        {sender, message} ->
          send(sender, {:response, "Peer got: #{message}"})
      end
    end])
    
    # Send message from main node to worker
    send(worker_pid, {self(), "Hello from main node!"})
    
    # Wait for response
    receive do
      {:response, response} ->
        IO.puts("   Main node received: #{response}")
        IO.puts("✅ Peer message passing successful")
    after
      2000 ->
        IO.puts("⏰ Peer message passing timed out")
    end
  end

  defp test_manual_node_simulation do
    IO.puts("🔧 Testing manual distributed simulation...")
    
    # Simulate what would happen between actual nodes
    # This tests the pattern we'll use in production
    
    # Start GenServer representing remote service
    {:ok, remote_service} = GenServer.start_link(RemoteServiceSim, :ok)
    
    # Test local "P2P" call pattern
    result = GenServer.call(remote_service, {:federated_request, "Test Federation"})
    IO.puts("   Federated call result: #{result}")
    
    # Test async message pattern
    GenServer.cast(remote_service, {:async_federation_message, "Async Test"})
    :timer.sleep(100)
    
    messages = GenServer.call(remote_service, :get_messages)
    IO.puts("   Messages received: #{inspect(messages)}")
    
    IO.puts("✅ Manual distributed patterns work")
  end

  defp test_two_node_setup do
    IO.puts("\n🔗 Testing two-node communication setup...")
    
    # This simulates our elias_server <-> apemacs_client pattern
    {:ok, server_sim} = GenServer.start_link(ServerSim, :elias_server_sim, name: :server_sim)
    {:ok, client_sim} = GenServer.start_link(ClientSim, :apemacs_client_sim, name: :client_sim)
    
    # Test client -> server communication (like ApeMacs reporting issue)
    GenServer.cast(:client_sim, {:report_to_server, :server_sim, "System issue detected"})
    
    # Test server -> client communication (like rule update)
    GenServer.cast(:server_sim, {:update_client, :client_sim, "New rules available"})
    
    :timer.sleep(200)
    
    # Check results
    server_messages = GenServer.call(:server_sim, :get_messages)
    client_messages = GenServer.call(:client_sim, :get_messages)
    
    IO.puts("   Server received: #{inspect(server_messages)}")
    IO.puts("   Client received: #{inspect(client_messages)}")
    
    if length(server_messages) > 0 and length(client_messages) > 0 do
      IO.puts("✅ Two-node communication patterns successful")
    else
      IO.puts("❌ Two-node communication incomplete")
    end
  end
end

defmodule RemoteServiceSim do
  use GenServer
  
  def init(:ok) do
    {:ok, %{messages: []}}
  end
  
  def handle_call({:federated_request, request}, _from, state) do
    response = "Federation processed: #{request}"
    {:reply, response, state}
  end
  
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
  
  def handle_cast({:async_federation_message, message}, state) do
    new_messages = [message | state.messages]
    {:noreply, %{state | messages: new_messages}}
  end
end

defmodule ServerSim do
  use GenServer
  
  def init(type) do
    {:ok, %{type: type, messages: []}}
  end
  
  def handle_cast({:receive_from_client, client_node, message}, state) do
    IO.puts("🖥️  Server received from #{client_node}: #{message}")
    new_messages = [{client_node, message, DateTime.utc_now()} | state.messages]
    {:noreply, %{state | messages: new_messages}}
  end
  
  def handle_cast({:update_client, client_name, update}, state) do
    # Simulate sending update to client
    GenServer.cast(client_name, {:receive_from_server, state.type, update})
    {:noreply, state}
  end
  
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
end

defmodule ClientSim do
  use GenServer
  
  def init(type) do
    {:ok, %{type: type, messages: []}}
  end
  
  def handle_cast({:report_to_server, server_name, issue}, state) do
    # Simulate sending issue report to server
    GenServer.cast(server_name, {:receive_from_client, state.type, issue})
    {:noreply, state}
  end
  
  def handle_cast({:receive_from_server, server_node, message}, state) do
    IO.puts("💻 Client received from #{server_node}: #{message}")
    new_messages = [{server_node, message, DateTime.utc_now()} | state.messages]
    {:noreply, %{state | messages: new_messages}}
  end
  
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
end

# Run the test
ProperDistributedTest.run()