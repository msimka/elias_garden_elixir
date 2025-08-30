defmodule Tiki.Engine do
  @moduledoc """
  Core Tiki Language Methodology Engine
  
  Implements the four pillars of Tiki system per Architect guidance:
  1. Hierarchical Specification Loading and Validation
  2. Tree-Traversal Testing with Mock Generation  
  3. Failure Isolation Debugging
  4. Pseudo-Compilation Integration Analysis
  
  Following Erlang/OTP patterns with ETS caching and distributed execution.
  """
  
  use GenServer
  require Logger
  
  alias Tiki.{SpecLoader, TreeTester, DebugEngine, PseudoCompiler}
  
  defstruct [
    :spec_cache_table,
    :test_cache_table,
    :dependency_graph,
    :active_sessions,
    :pseudo_compiler_rules
  ]
  
  # Public API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end
  
  def load_spec(spec_file) do
    GenServer.call(__MODULE__, {:load_spec, spec_file})
  end
  
  def validate_spec(spec_file) do
    GenServer.call(__MODULE__, {:validate_spec, spec_file})
  end
  
  def run_tree_test(component_id, opts \\ []) do
    GenServer.call(__MODULE__, {:run_tree_test, component_id, opts}, 60_000)
  end
  
  def debug_failure(failure_id, context) do
    GenServer.call(__MODULE__, {:debug_failure, failure_id, context}, 120_000)
  end
  
  def pseudo_compile_integration(new_component, opts \\ []) do
    GenServer.call(__MODULE__, {:pseudo_compile_integration, new_component, opts}, 300_000)
  end
  
  def get_dependency_graph do
    GenServer.call(__MODULE__, :get_dependency_graph)
  end
  
  def rebuild_caches do
    GenServer.cast(__MODULE__, :rebuild_caches)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(state) do
    Logger.info("🎭 Tiki.Engine: Starting Tiki Language Methodology engine")
    
    # Create ETS tables for caching (per Architect guidance)
    spec_cache = :ets.new(:tiki_spec_cache, [:set, :protected, :named_table])
    test_cache = :ets.new(:tiki_test_cache, [:set, :protected, :named_table])
    
    # Initialize state
    initial_state = %{state |
      spec_cache_table: spec_cache,
      test_cache_table: test_cache,
      dependency_graph: %{},
      active_sessions: %{},
      harmonizer_rules: load_harmonizer_rules()
    }
    
    # Build initial dependency graph
    GenServer.cast(self(), :build_dependency_graph)
    
    Logger.info("✅ Tiki.Engine: Engine initialized with caching and dependency analysis")
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:load_spec, spec_file}, _from, state) do
    case SpecLoader.load_spec(spec_file, state.spec_cache_table) do
      {:ok, spec} ->
        Logger.info("📋 Tiki.Engine: Loaded spec #{spec_file}")
        {:reply, {:ok, spec}, state}
        
      {:error, reason} ->
        Logger.error("❌ Tiki.Engine: Failed to load spec #{spec_file}: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:validate_spec, spec_file}, _from, state) do
    case SpecLoader.validate_spec(spec_file, state.spec_cache_table) do
      {:ok, validation_results} ->
        Logger.info("✅ Tiki.Engine: Validated spec #{spec_file}")
        {:reply, {:ok, validation_results}, state}
        
      {:error, validation_errors} ->
        Logger.warning("⚠️ Tiki.Engine: Spec validation failed for #{spec_file}")
        {:reply, {:error, validation_errors}, state}
    end
  end
  
  def handle_call({:run_tree_test, component_id, opts}, _from, state) do
    session_id = generate_session_id()
    Logger.info("🧪 Tiki.Engine: Starting tree test for #{component_id} (session: #{session_id})")
    
    # Create test session
    test_session = %{
      session_id: session_id,
      component_id: component_id,
      started_at: DateTime.utc_now(),
      status: :running,
      opts: opts
    }
    
    updated_sessions = Map.put(state.active_sessions, session_id, test_session)
    
    # Run tree testing (this would be async in production)
    case TreeTester.run_hierarchical_test(component_id, opts, state.spec_cache_table, state.test_cache_table) do
      {:ok, test_results} ->
        Logger.info("✅ Tiki.Engine: Tree test completed for #{component_id}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:ok, test_results}, %{state | active_sessions: final_sessions}}
        
      {:error, reason} ->
        Logger.error("❌ Tiki.Engine: Tree test failed for #{component_id}: #{reason}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:error, reason}, %{state | active_sessions: final_sessions}}
    end
  end
  
  def handle_call({:debug_failure, failure_id, context}, _from, state) do
    session_id = generate_session_id()
    Logger.info("🔍 Tiki.Engine: Starting debug session for #{failure_id} (session: #{session_id})")
    
    debug_session = %{
      session_id: session_id,
      failure_id: failure_id,
      context: context,
      started_at: DateTime.utc_now(),
      status: :debugging
    }
    
    updated_sessions = Map.put(state.active_sessions, session_id, debug_session)
    
    case DebugEngine.isolate_failure(failure_id, context, state.spec_cache_table, state.dependency_graph) do
      {:ok, debug_results} ->
        Logger.info("🎯 Tiki.Engine: Debug isolation completed for #{failure_id}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:ok, debug_results}, %{state | active_sessions: final_sessions}}
        
      {:error, reason} ->
        Logger.error("💥 Tiki.Engine: Debug failed for #{failure_id}: #{reason}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:error, reason}, %{state | active_sessions: final_sessions}}
    end
  end
  
  def handle_call({:pseudo_compile_integration, new_component, opts}, _from, state) do
    session_id = generate_session_id()
    Logger.info("🛡️ Tiki.Engine: Starting Pseudo-Compilation analysis for #{new_component} (session: #{session_id})")
    
    pseudo_compiler_session = %{
      session_id: session_id,
      new_component: new_component,
      started_at: DateTime.utc_now(),
      status: :analyzing,
      opts: opts
    }
    
    updated_sessions = Map.put(state.active_sessions, session_id, pseudo_compiler_session)
    
    case PseudoCompiler.analyze_integration(new_component, opts, state.dependency_graph, state.pseudo_compiler_rules) do
      {:ok, pseudo_compiler_results} ->
        Logger.info("✅ Tiki.Engine: Pseudo-Compilation completed for #{new_component}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:ok, pseudo_compiler_results}, %{state | active_sessions: final_sessions}}
        
      {:error, reason} ->
        Logger.error("❌ Tiki.Engine: Pseudo-Compilation failed for #{new_component}: #{reason}")
        final_sessions = Map.delete(updated_sessions, session_id)
        {:reply, {:error, reason}, %{state | active_sessions: final_sessions}}
    end
  end
  
  def handle_call(:get_dependency_graph, _from, state) do
    {:reply, state.dependency_graph, state}
  end
  
  @impl true
  def handle_cast(:rebuild_caches, state) do
    Logger.info("🔄 Tiki.Engine: Rebuilding caches and dependency graph")
    
    # Clear existing caches
    :ets.delete_all_objects(state.spec_cache_table)
    :ets.delete_all_objects(state.test_cache_table)
    
    # Rebuild dependency graph
    GenServer.cast(self(), :build_dependency_graph)
    
    {:noreply, state}
  end
  
  def handle_cast(:build_dependency_graph, state) do
    Logger.info("📊 Tiki.Engine: Building dependency graph from specifications")
    
    # This would scan all .tiki files and build comprehensive dependency graph
    dependency_graph = build_global_dependency_graph()
    
    Logger.info("✅ Tiki.Engine: Dependency graph built with #{map_size(dependency_graph)} components")
    {:noreply, %{state | dependency_graph: dependency_graph}}
  end
  
  # Private Functions
  
  defp generate_session_id do
    "tiki_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
  
  defp load_harmonizer_rules do
    # Load System Harmonizer rules from configuration
    %{
      impact_radius: 3,
      required_tests: ["unit", "integration", "distributed"],
      approval_thresholds: %{
        test_success_rate: 95.0,
        performance_degradation_max: 10.0,
        dependency_conflicts: 0
      },
      rollback_triggers: ["supervisor_crash", "memory_leak", "network_partition"]
    }
  end
  
  defp build_global_dependency_graph do
    # This would implement full dependency analysis across all .tiki specs
    # For now, return a simplified example
    %{
      "UFM.root" => %{
        dependencies: ["UCM.root", "URM.root"],
        dependents: ["system_startup", "federation_tests"],
        component_type: :manager,
        criticality: :high
      },
      "UFM.federation_daemon" => %{
        dependencies: ["distributed_erlang", "UCM.broadcast"],
        dependents: ["UFM.monitoring_daemon", "request_routing"],
        component_type: :subdaemon,
        criticality: :critical
      },
      "UCM.root" => %{
        dependencies: ["elias_core.messaging"],
        dependents: ["UFM.root", "UAM.root", "URM.root"],
        component_type: :manager,
        criticality: :critical
      }
    }
  end
end