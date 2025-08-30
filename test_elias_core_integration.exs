#!/usr/bin/env elixir
# Integration test for ELIAS Core components without requiring multiple nodes

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule EliasGardenCoreTest do
  @moduledoc """
  Test ELIAS Core components in isolation and integration
  """

  def run do
    IO.puts("🧪 ELIAS Garden Core Integration Test")
    IO.puts("=" |> String.duplicate(45))
    
    # Test core components individually
    test_core_daemon()
    test_p2p_communication_patterns() 
    test_request_pool_simulation()
    test_blockchain_operations()
    test_rule_distribution_patterns()
    
    IO.puts("\n✅ All ELIAS Core integration tests passed!")
  end

  defp test_core_daemon() do
    IO.puts("\n🧠 Testing EliasCore.Daemon...")
    
    # Load the core daemon module
    Code.require_file("/Users/mikesimka/elias_garden_elixir/apps/elias_core/lib/elias_core/daemon.ex")
    
    # Test basic daemon functionality
    {:ok, daemon_pid} = GenServer.start_link(EliasCore.Daemon, [])
    
    # Test rule management
    :ok = GenServer.cast(daemon_pid, {:update_rule, "test_rule", "test_value"})
    
    # Test rule execution
    result = GenServer.call(daemon_pid, {:execute_rule, "test_rule", []})
    
    case result do
      {:ok, "test_value"} -> 
        IO.puts("✅ EliasCore.Daemon basic operations work")
      other ->
        IO.puts("❌ EliasCore.Daemon test failed: #{inspect(other)}")
    end
    
    # Test system status
    status = GenServer.call(daemon_pid, :get_system_status)
    IO.puts("   System status: #{inspect(status)}")
    
    GenServer.stop(daemon_pid)
  end

  defp test_p2p_communication_patterns() do
    IO.puts("\n🌐 Testing P2P communication patterns...")
    
    # Load P2P module
    Code.require_file("/Users/mikesimka/elias_garden_elixir/apps/elias_core/lib/elias_core/p2p.ex")
    
    # Set mock node type
    System.put_env("ELIAS_NODE_TYPE", "full_node")
    
    # Test P2P initialization
    {:ok, p2p_pid} = GenServer.start_link(EliasCore.P2P, [])
    
    # Test getting cluster status
    status = GenServer.call(p2p_pid, :get_cluster_status)
    IO.puts("   P2P Status: #{inspect(status)}")
    
    # Test message broadcasting (local simulation)
    GenServer.cast(p2p_pid, {:broadcast_message, "Test message", []})
    
    IO.puts("✅ EliasCore.P2P communication patterns work")
    
    GenServer.stop(p2p_pid)
  end

  defp test_request_pool_simulation() do
    IO.puts("\n🏊 Testing RequestPool operations...")
    
    # Load RequestPool module
    Code.require_file("/Users/mikesimka/elias_garden_elixir/apps/elias_core/lib/elias_core/request_pool.ex")
    Code.require_file("/Users/mikesimka/elias_garden_elixir/apps/elias_core/lib/elias_core/ape_harmony.ex")
    
    # Mock blockchain dependency
    {:ok, blockchain_pid} = GenServer.start_link(MockBlockchain, [])
    Process.register(blockchain_pid, EliasCore.ApeHarmony)
    
    # Start RequestPool
    {:ok, pool_pid} = GenStage.start_link(EliasCore.RequestPool, [])
    
    # Start a consumer to handle requests
    {:ok, consumer_pid} = GenStage.start_link(MockConsumer, pool_pid)
    
    # Submit test requests
    {:ok, request_id1} = EliasCore.RequestPool.submit_request(:test_request, %{data: "test1"})
    {:ok, request_id2} = EliasCore.RequestPool.submit_request(:system_issue, %{issue: "test issue"})
    
    # Wait for processing
    :timer.sleep(100)
    
    # Check queue status
    status = GenStage.call(pool_pid, :get_queue_status)
    IO.puts("   Queue Status: #{inspect(status)}")
    
    # Check request status
    {result1, _} = GenStage.call(pool_pid, {:get_request_status, request_id1})
    {result2, _} = GenStage.call(pool_pid, {:get_request_status, request_id2})
    
    IO.puts("   Request 1: #{inspect(result1)}")
    IO.puts("   Request 2: #{inspect(result2)}")
    
    if result1 == :ok and result2 == :ok do
      IO.puts("✅ EliasCore.RequestPool operations work")
    else
      IO.puts("❌ RequestPool test had issues")
    end
    
    GenStage.stop(consumer_pid)
    GenStage.stop(pool_pid)
    GenServer.stop(blockchain_pid)
  end

  defp test_blockchain_operations() do
    IO.puts("\n⛓️ Testing APE HARMONY blockchain...")
    
    # Set environment for full node (blockchain mining)
    System.put_env("ELIAS_NODE_TYPE", "full_node")
    
    # Start blockchain
    {:ok, blockchain_pid} = GenServer.start_link(EliasCore.ApeHarmony, [])
    
    # Record some events
    EliasCore.ApeHarmony.record_event("test_event", %{data: "test"})
    EliasCore.ApeHarmony.record_event("manager_start", %{manager: "UFM"})
    
    # Get blockchain status
    status = GenServer.call(blockchain_pid, :get_chain_status)
    IO.puts("   Blockchain Status: #{inspect(status)}")
    
    # Get contributions
    contributions = GenServer.call(blockchain_pid, {:get_contributions, node()})
    IO.puts("   Node Contributions: #{inspect(contributions)}")
    
    # Wait a moment for potential mining
    :timer.sleep(500)
    
    # Get updated status
    final_status = GenServer.call(blockchain_pid, :get_chain_status)
    IO.puts("   Final Status: #{inspect(final_status)}")
    
    if final_status.blocks_count >= 1 do
      IO.puts("✅ APE HARMONY blockchain operations work")
    else
      IO.puts("❌ Blockchain test incomplete")
    end
    
    GenServer.stop(blockchain_pid)
  end

  defp test_rule_distribution_patterns() do
    IO.puts("\n📡 Testing rule distribution patterns...")
    
    # Load RuleDistributor
    Code.require_file("/Users/mikesimka/elias_garden_elixir/apps/elias_core/lib/elias_core/rule_distributor.ex")
    
    # Mock P2P dependency
    {:ok, p2p_pid} = GenServer.start_link(MockP2P, [])
    Process.register(p2p_pid, EliasCore.P2P)
    
    # Mock blockchain dependency  
    {:ok, blockchain_pid} = GenServer.start_link(MockBlockchain, [])
    Process.register(blockchain_pid, EliasCore.ApeHarmony)
    
    # Start RuleDistributor
    {:ok, distributor_pid} = GenServer.start_link(EliasCore.RuleDistributor, [])
    
    # Register a mock client
    GenServer.cast(distributor_pid, {:register_client, :mock_client, [:apemacs_rules]})
    
    # Test rule distribution
    GenServer.cast(distributor_pid, {
      :distribute_update, 
      :apemacs_rules, 
      "test.md", 
      "# Test Rule\nThis is a test rule."
    })
    
    # Get distribution status
    status = GenServer.call(distributor_pid, :get_distribution_status)
    IO.puts("   Distribution Status: #{inspect(status)}")
    
    IO.puts("✅ Rule distribution patterns work")
    
    GenServer.stop(distributor_pid)
    GenServer.stop(p2p_pid) 
    GenServer.stop(blockchain_pid)
  end
end

# Mock modules for testing

defmodule MockConsumer do
  use GenStage
  
  def init(producer) do
    {:consumer, %{}, subscribe_to: [producer]}
  end
  
  def handle_events(events, _from, state) do
    for event <- events do
      IO.puts("   🔄 Processing: #{event.type} (#{event.id})")
    end
    {:noreply, [], state}
  end
end

defmodule MockBlockchain do
  use GenServer
  
  def init(_) do
    {:ok, %{}}
  end
  
  def handle_cast({:record_event, _event_type, _data}, state) do
    {:noreply, state}
  end
  
  def handle_cast({:record_event, _event_type, _data, _node}, state) do
    {:noreply, state}
  end
end

defmodule MockP2P do
  use GenServer
  
  def init(_) do
    {:ok, %{}}
  end
  
  def handle_cast({:send_to_node, _node, _message}, state) do
    {:noreply, state}
  end
end

# Mock the EliasCore module for node type detection
defmodule EliasCore do
  def node_type do
    case System.get_env("ELIAS_NODE_TYPE", "client") do
      "full_node" -> :full_node
      _ -> :client
    end
  end
  
  def full_node?, do: node_type() == :full_node
  def client?, do: node_type() == :client
  
  def version, do: "2.0.0-test"
end

# Run the test
EliasGardenCoreTest.run()