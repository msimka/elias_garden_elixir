#!/usr/bin/env elixir
# Simple distributed Erlang test for ELIAS Garden

# Start distributed node if not already started
unless Node.alive?() do
  :net_kernel.start([:test_node, :shortnames])
  :net_kernel.set_net_ticktime(10)
end

defmodule DistributedTest do
  @moduledoc """
  Test distributed communication for ELIAS Garden architecture
  """

  def run do
    IO.puts("🧪 ELIAS Garden Distributed Test")
    IO.puts("=" |> String.duplicate(40))
    
    # Show current node info
    show_node_info()
    
    # Test creating a second node manually
    test_node_creation()
    
    # Test basic GenServer on distributed nodes
    test_distributed_genserver()
    
    IO.puts("\n✅ Distributed tests completed!")
  end

  defp show_node_info do
    IO.puts("\n🔍 Current Node Information:")
    IO.puts("   Node: #{node()}")
    IO.puts("   Alive: #{Node.alive?()}")
    IO.puts("   Cookie: #{:erlang.get_cookie()}")
    IO.puts("   Connected nodes: #{inspect(Node.list())}")
  end

  defp test_node_creation do
    IO.puts("\n🚀 Testing manual node creation...")
    
    # Try to start another node
    case :slave.start_link(:localhost, :test_worker, ~c"-setcookie elias_test") do
      {:ok, worker_node} ->
        IO.puts("✅ Started worker node: #{worker_node}")
        
        # Test basic communication
        result = :rpc.call(worker_node, :erlang, :node, [])
        IO.puts("   Worker node reports: #{result}")
        
        # Test message passing
        test_message_passing(worker_node)
        
        # Clean up
        :slave.stop(worker_node)
        IO.puts("🧹 Cleaned up worker node")
        
      {:error, reason} ->
        IO.puts("❌ Failed to start worker node: #{inspect(reason)}")
        IO.puts("   This is expected if EPMD is not running or slave nodes are restricted")
    end
  end

  defp test_message_passing(worker_node) do
    IO.puts("📨 Testing message passing with #{worker_node}...")
    
    # Start a simple process on the worker node
    worker_pid = :rpc.call(worker_node, :erlang, :spawn, [fn ->
      receive do
        {sender, message} ->
          send(sender, {:response, "Got: #{message}"})
          IO.puts("   Worker received: #{message}")
      end
    end])
    
    # Send message from main node to worker
    send(worker_pid, {self(), "Hello from main node!"})
    
    # Wait for response
    receive do
      {:response, response} ->
        IO.puts("   Main node received: #{response}")
        IO.puts("✅ Message passing successful")
    after
      2000 ->
        IO.puts("⏰ Message passing timed out")
    end
  end

  defp test_distributed_genserver do
    IO.puts("\n🔄 Testing distributed GenServer simulation...")
    
    # Start a simple GenServer locally
    {:ok, _pid} = GenServer.start_link(TestServer, :ok, name: :test_server)
    
    # Test local calls
    result1 = GenServer.call(:test_server, {:echo, "Hello Local"})
    IO.puts("   Local call result: #{result1}")
    
    # Simulate distributed call pattern (what we'd use between nodes)
    case node() do
      current_node when current_node != :nonode@nohost ->
        # We have a distributed node, test remote-style calling
        result2 = GenServer.call({:test_server, node()}, {:echo, "Hello Distributed Style"})
        IO.puts("   Distributed-style call result: #{result2}")
        IO.puts("✅ GenServer distributed patterns work")
      
      _ ->
        IO.puts("   Skipping distributed GenServer test (not on distributed node)")
    end
  end
end

defmodule TestServer do
  use GenServer
  
  def init(:ok) do
    {:ok, %{messages: []}}
  end
  
  def handle_call({:echo, message}, _from, state) do
    new_messages = [message | state.messages]
    {:reply, "Echo: #{message}", %{state | messages: new_messages}}
  end
end

# Run the test
DistributedTest.run()