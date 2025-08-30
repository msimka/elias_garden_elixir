defmodule Tiki.Validatable do
  @moduledoc """
  Tiki Validatable Behavior - Interface for managers to support Tiki integration
  
  Per Architect guidance: Each manager implements this behavior to enable
  Tiki specification validation, testing, and integration support without
  disrupting their core responsibilities.
  
  This maintains the 6-manager architecture while providing system-wide
  Tiki capabilities through distributed integration.
  """
  
  @doc """
  Validate the manager's Tiki specification against its current implementation.
  
  Returns:
    - {:ok, validation_results} - All validations passed or have warnings only
    - {:error, validation_errors} - Critical validation failures found
  """
  @callback validate_tiki_spec() :: {:ok, map()} | {:error, [map()]}
  
  @doc """
  Get the manager's current Tiki specification data.
  
  Returns the loaded and parsed .tiki specification for this manager,
  including metadata, dependency information, and code references.
  """
  @callback get_tiki_spec() :: {:ok, map()} | {:error, term()}
  
  @doc """
  Handle hot-reload of Tiki specification.
  
  Called by UFM when .tiki specifications are updated. The manager
  should reload its spec, validate against current state, and apply
  any configuration changes that don't require restart.
  """
  @callback reload_tiki_spec() :: :ok | {:error, term()}
  
  @doc """
  Get manager's current validation status for Tiki integration.
  
  Returns summary of manager's integration with Tiki system,
  including last validation time, status, and any issues.
  """
  @callback get_tiki_status() :: map()
  
  @doc """
  Execute Tiki tree testing for this manager's component tree.
  
  Performs hierarchical testing following Architect's guidance:
  - Breadth-first for coverage
  - Mock generation for failed components  
  - Depth-first isolation on failures
  
  Args:
    - component_id: Specific component to test (nil for full manager)
    - opts: Testing options (parallel, mock_strategy, cache, etc.)
  """
  @callback run_tiki_test(component_id :: binary() | nil, opts :: keyword()) ::
    {:ok, map()} | {:error, term()}
  
  @doc """
  Support Tiki debugging for known failures in this manager.
  
  Implements tree-traversal debugging to isolate failures to atomic
  components using model-generated mocks and direct implementations.
  
  Args:
    - failure_id: Identifier for the known failure
    - context: Additional context about the failure
  """
  @callback debug_tiki_failure(failure_id :: binary(), context :: map()) ::
    {:ok, map()} | {:error, term()}
  
  @doc """
  Provide dependency information for System Harmonizer analysis.
  
  Returns this manager's dependencies and components that depend on it,
  used for impact radius calculation during integration validation.
  """
  @callback get_tiki_dependencies() :: %{
    dependencies: [binary()],
    dependents: [binary()],
    internal_components: [binary()],
    external_interfaces: [binary()]
  }
  
  @doc """
  Get performance metrics for Tiki integration analysis.
  
  Returns current performance data used for regression detection
  and System Harmonizer approval thresholds.
  """
  @callback get_tiki_metrics() :: %{
    latency_ms: number(),
    memory_usage_mb: number(), 
    cpu_usage_percent: number(),
    success_rate_percent: number(),
    last_measured: DateTime.t()
  }
  
  # Optional callbacks with default implementations
  
  @doc """
  Called before System Harmonizer integration testing.
  
  Allows manager to prepare for integration testing of new components.
  Default implementation does nothing.
  """
  @callback prepare_for_harmonizer_test(new_component :: binary(), opts :: keyword()) ::
    :ok | {:error, term()}
  
  @doc """
  Called after System Harmonizer integration testing.
  
  Allows manager to clean up after integration testing.
  Default implementation does nothing.
  """
  @callback cleanup_after_harmonizer_test(new_component :: binary(), results :: map()) ::
    :ok
  
  # Provide default implementations for optional callbacks
  defmacro __using__(_opts) do
    quote do
      @behaviour Tiki.Validatable
      
      # Default implementations for optional callbacks
      def prepare_for_harmonizer_test(_new_component, _opts), do: :ok
      def cleanup_after_harmonizer_test(_new_component, _results), do: :ok
      
      defoverridable prepare_for_harmonizer_test: 2, cleanup_after_harmonizer_test: 2
    end
  end
end