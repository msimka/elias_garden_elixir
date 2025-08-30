defmodule MultiFormatConverter.AtomicComponent do
  @moduledoc """
  Behavior for Atomic Components in Multi-Format Text Converter
  
  Based on Architect guidance:
  - Each atomic component performs exactly one function
  - Components must be testable in isolation with real verification
  - All test results are cryptographically signed and submitted to blockchain
  - Components are composable into larger functional units
  
  This behavior ensures consistency across all atomic components.
  """

  @doc """
  Returns the unique component ID as defined in TIKI specification
  """
  @callback component_id() :: String.t()

  @doc """
  Returns the human-readable component name
  """
  @callback component_name() :: String.t()

  @doc """
  Returns list of atomic responsibilities for this component
  Each component should have exactly one core responsibility
  """
  @callback component_responsibilities() :: [String.t()]

  @doc """
  Returns list of expected inputs with types
  """
  @callback component_inputs() :: [String.t()]

  @doc """
  Returns list of outputs with types
  """
  @callback component_outputs() :: [String.t()]

  @doc """
  Returns list of component dependencies (other atomic components)
  Leaf components return empty list
  """
  @callback component_dependencies() :: [String.t()]

  @doc """
  Run real verification tests for this atomic component
  
  Must test actual functionality with real files/data, not mocks
  Returns comprehensive test report with blockchain verification data
  """
  @callback run_component_tests() :: %{
    component_id: String.t(),
    test_results: [map()],
    verification_results: map(),
    blockchain_data: map(),
    overall_status: :passed | :failed
  }

  @doc """
  Verify blockchain-signed test results by replaying tests
  
  Used to verify that component tests actually passed as claimed
  """
  @callback verify_blockchain_signature(signature :: String.t()) :: 
    {:ok, :verified} | {:error, :verification_failed}

  @doc """
  Optional: Get component metadata for TIKI specification compliance
  """
  @callback get_component_metadata() :: map()

  # Default implementation for optional callback
  defmacro __using__(_opts) do
    quote do
      @behaviour MultiFormatConverter.AtomicComponent

      # Provide default implementation for optional callback
      def get_component_metadata do
        %{
          id: component_id(),
          name: component_name(),
          responsibilities: component_responsibilities(),
          inputs: component_inputs(),
          outputs: component_outputs(),
          dependencies: component_dependencies(),
          atomic: true,
          blockchain_verified: true,
          tank_building_stage: "stage_1_brute_force"
        }
      end

      defoverridable get_component_metadata: 0
    end
  end
end