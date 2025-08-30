#!/usr/bin/env elixir
# Test script for P2P communication in new elias_garden_elixir structure

Mix.install([
  {:jason, "~> 1.4"},
  {:local_cluster, "~> 1.2"}
])

defmodule P2PTest do
  @moduledoc """
  Test P2P communication between elias_server and apemacs_client nodes
  """

  def run_test do
    IO.puts("🧪 Testing ELIAS Garden P2P Communication")
    IO.puts("=" |> String.duplicate(50))
    
    # Start test nodes
    {:ok, [server_node, client_node]} = start_test_nodes()
    
    # Test basic connectivity
    test_basic_connectivity(server_node, client_node)
    
    # Test message passing
    test_message_passing(server_node, client_node)
    
    # Test distributed GenServer calls
    test_distributed_calls(server_node, client_node)
    
    # Cleanup
    LocalCluster.stop()
    
    IO.puts("\n✅ P2P Communication tests completed!")
  end

  defp start_test_nodes do
    IO.puts("🚀 Starting test nodes...")
    
    # Start test nodes using LocalCluster
    nodes = LocalCluster.start_nodes("test", 2, applications: [
      :logger,
      :crypto,
      :jason
    ])
    
    # Wait for nodes to start
    :timer.sleep(1000)
    
    [server_node, client_node] = nodes
    
    IO.puts("✅ Test nodes started:")
    IO.puts("   Server: #{inspect(server_node)}")
    IO.puts("   Client: #{inspect(client_node)}")
    
    {:ok, [server_node, client_node]}
  end

  defp test_basic_connectivity(server_node, client_node) do
    IO.puts("\n🔌 Testing basic node connectivity...")
    
    # Test ping between nodes
    server_ping = :rpc.call(client_node, Node, :ping, [server_node])
    client_ping = :rpc.call(server_node, Node, :ping, [client_node])
    
    case {server_ping, client_ping} do
      {:pong, :pong} ->
        IO.puts("✅ Nodes can ping each other successfully")
      
      {server_result, client_result} ->
        IO.puts("❌ Ping test failed:")
        IO.puts("   Server -> Client: #{inspect(server_result)}")
        IO.puts("   Client -> Server: #{inspect(client_result)}")
    end
    
    # Test node list visibility
    server_nodes = :rpc.call(server_node, Node, :list, [])
    client_nodes = :rpc.call(client_node, Node, :list, [])
    
    IO.puts("📋 Node visibility:")
    IO.puts("   Server sees: #{inspect(server_nodes)}")
    IO.puts("   Client sees: #{inspect(client_nodes)}")
  end

  defp test_message_passing(server_node, client_node) do
    IO.puts("\n📨 Testing message passing...")
    
    # Start test GenServers on each node
    start_test_servers(server_node, client_node)
    
    # Test server -> client message
    :rpc.call(server_node, TestP2PServer, :send_message, [
      client_node, 
      "Hello from server!"
    ])
    
    :timer.sleep(500)
    
    # Test client -> server message  
    :rpc.call(client_node, TestP2PClient, :send_message, [
      server_node,
      "Hello from client!"
    ])
    
    :timer.sleep(500)
    
    # Check message logs
    server_messages = :rpc.call(server_node, TestP2PServer, :get_messages, [])
    client_messages = :rpc.call(client_node, TestP2PClient, :get_messages, [])
    
    IO.puts("📬 Messages received:")
    IO.puts("   Server received: #{inspect(server_messages)}")
    IO.puts("   Client received: #{inspect(client_messages)}")
  end

  defp test_distributed_calls(server_node, client_node) do
    IO.puts("\n🔄 Testing distributed GenServer calls...")
    
    # Test synchronous calls between nodes
    try do
      server_response = :rpc.call(client_node, GenServer, :call, [
        {TestP2PServer, server_node},
        :get_status
      ])
      
      client_response = :rpc.call(server_node, GenServer, :call, [
        {TestP2PClient, client_node}, 
        :get_status
      ])
      
      IO.puts("✅ Distributed calls successful:")
      IO.puts("   Server status: #{inspect(server_response)}")
      IO.puts("   Client status: #{inspect(client_response)}")
      
    rescue
      e ->
        IO.puts("❌ Distributed calls failed: #{inspect(e)}")
    end
  end

  defp start_test_servers(server_node, client_node) do
    # Start test server on server node
    :rpc.call(server_node, GenServer, :start_link, [
      TestP2PServer,
      [],
      [name: TestP2PServer]
    ])
    
    # Start test client on client node
    :rpc.call(client_node, GenServer, :start_link, [
      TestP2PClient, 
      [],
      [name: TestP2PClient]
    ])
    
    :timer.sleep(100)
  end
end

defmodule TestP2PServer do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end
  
  def send_message(target_node, message) do
    :rpc.cast(target_node, GenServer, :cast, [TestP2PClient, {:message, node(), message}])
  end
  
  def get_messages do
    GenServer.call(__MODULE__, :get_messages)
  end
  
  def init(_) do
    {:ok, %{messages: []}}
  end
  
  def handle_call(:get_status, _from, state) do
    {:reply, %{node: node(), message_count: length(state.messages)}, state}
  end
  
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
  
  def handle_cast({:message, from_node, message}, state) do
    IO.puts("🖥️  Server received: '#{message}' from #{from_node}")
    new_messages = [{from_node, message, DateTime.utc_now()} | state.messages]
    {:noreply, %{state | messages: new_messages}}
  end
end

defmodule TestP2PClient do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end
  
  def send_message(target_node, message) do
    :rpc.cast(target_node, GenServer, :cast, [TestP2PServer, {:message, node(), message}])
  end
  
  def get_messages do
    GenServer.call(__MODULE__, :get_messages)
  end
  
  def init(_) do
    {:ok, %{messages: []}}
  end
  
  def handle_call(:get_status, _from, state) do
    {:reply, %{node: node(), message_count: length(state.messages)}, state}
  end
  
  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
  
  def handle_cast({:message, from_node, message}, state) do
    IO.puts("💻 Client received: '#{message}' from #{from_node}")
    new_messages = [{from_node, message, DateTime.utc_now()} | state.messages]
    {:noreply, %{state | messages: new_messages}}
  end
end

# Run the test
P2PTest.run_test()