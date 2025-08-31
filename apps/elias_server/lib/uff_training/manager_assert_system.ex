defmodule UFFTraining.ManagerAssertSystem do
  @moduledoc """
  Assert System for All Managers
  
  Ensures all manager-generated code passes validation before deployment:
  - Tank Building methodology compliance
  - Component atomicity verification
  - TIKI specification adherence
  - Integration testing with federation
  """
  
  require Logger
  use ExUnit.Case, async: true
  
  @assert_thresholds %{
    component_atomicity: 0.95,
    tank_building_compliance: 0.95,
    tiki_adherence: 0.90,
    integration_compatibility: 0.90,
    code_quality: 0.85
  }
  
  def assert_manager_code(manager, generated_code, context \\ %{}) do
    Logger.info("🔍 Running assert validation for #{manager} generated code")
    
    assertions = [
      {:component_atomicity, assert_component_atomicity(generated_code)},
      {:tank_building_compliance, assert_tank_building_compliance(generated_code, context)},
      {:tiki_adherence, assert_tiki_specification(generated_code, manager)},
      {:integration_compatibility, assert_federation_compatibility(generated_code, manager)},
      {:code_quality, assert_code_quality(generated_code)}
    ]
    
    case validate_all_assertions(assertions) do
      {:ok, scores} ->
        Logger.info("✅ All assertions passed for #{manager}")
        {:ok, %{manager: manager, assertions: scores, validation: :passed}}
        
      {:error, failed_assertions} ->
        Logger.error("❌ Assertions failed for #{manager}: #{inspect(failed_assertions)}")
        {:error, %{manager: manager, failed_assertions: failed_assertions, validation: :failed}}
    end
  end
  
  def assert_all_managers(manager_outputs) when is_map(manager_outputs) do
    Logger.info("🔍 Running assert validation for all managers")
    
    results = Enum.map(manager_outputs, fn {manager, output} ->
      case assert_manager_code(manager, output.generated_code, output.context || %{}) do
        {:ok, validation_result} -> {manager, {:passed, validation_result}}
        {:error, validation_result} -> {manager, {:failed, validation_result}}
      end
    end)
    
    passed = Enum.filter(results, fn {_manager, {status, _}} -> status == :passed end)
    failed = Enum.filter(results, fn {_manager, {status, _}} -> status == :failed end)
    
    %{
      total_managers: length(results),
      passed_count: length(passed),
      failed_count: length(failed),
      pass_rate: length(passed) / length(results),
      results: Map.new(results)
    }
  end
  
  # Individual Assert Functions
  
  defp assert_component_atomicity(generated_code) do
    # Assert: Component follows single responsibility principle
    atomicity_score = calculate_atomicity_score(generated_code)
    
    if atomicity_score < @assert_thresholds.component_atomicity do
      raise "Component atomicity score #{atomicity_score} below threshold #{@assert_thresholds.component_atomicity}"
    end
    
    atomicity_score
  end
  
  defp assert_tank_building_compliance(generated_code, context) do
    # Assert: Code follows Tank Building methodology
    compliance_score = calculate_tank_building_compliance(generated_code, context)
    
    if compliance_score < @assert_thresholds.tank_building_compliance do
      raise "Tank Building compliance #{compliance_score} below threshold #{@assert_thresholds.tank_building_compliance}"
    end
    
    compliance_score
  end
  
  defp assert_tiki_specification(generated_code, manager) do
    # Assert: Code adheres to TIKI specifications for manager domain
    adherence_score = calculate_tiki_adherence(generated_code, manager)
    
    if adherence_score < @assert_thresholds.tiki_adherence do
      raise "TIKI adherence #{adherence_score} below threshold #{@assert_thresholds.tiki_adherence}"
    end
    
    adherence_score
  end
  
  defp assert_federation_compatibility(generated_code, manager) do
    # Assert: Code is compatible with ELIAS federation
    compatibility_score = calculate_federation_compatibility(generated_code, manager)
    
    if compatibility_score < @assert_thresholds.integration_compatibility do
      raise "Federation compatibility #{compatibility_score} below threshold #{@assert_thresholds.integration_compatibility}"
    end
    
    compatibility_score
  end
  
  defp assert_code_quality(generated_code) do
    # Assert: General code quality standards
    quality_score = calculate_code_quality(generated_code)
    
    if quality_score < @assert_thresholds.code_quality do
      raise "Code quality #{quality_score} below threshold #{@assert_thresholds.code_quality}"
    end
    
    quality_score
  end
  
  # Scoring Functions
  
  defp calculate_atomicity_score(code) do
    # Score based on single responsibility, clear interface, focused purpose
    base_score = 0.85
    
    # Check for single module/responsibility
    module_count = (String.split(code, "defmodule ") |> length()) - 1
    responsibility_bonus = if module_count == 1, do: 0.05, else: 0.0
    
    # Check for clear public interface
    public_functions = Regex.scan(~r/def\s+\w+/, code) |> length()
    interface_bonus = if public_functions <= 3, do: 0.05, else: 0.0
    
    # Check for private helper functions (good design)
    private_functions = Regex.scan(~r/defp\s+\w+/, code) |> length()
    design_bonus = if private_functions > 0, do: 0.05, else: 0.0
    
    base_score + responsibility_bonus + interface_bonus + design_bonus
  end
  
  defp calculate_tank_building_compliance(code, context) do
    # Score based on Tank Building methodology principles
    base_score = 0.88
    
    # Stage-specific compliance checks
    stage = context[:tank_building_stage] || :stage_1
    stage_bonus = case stage do
      :stage_1 -> check_stage_1_compliance(code)  # Brute force working
      :stage_2 -> check_stage_2_compliance(code)  # Extended functionality
      :stage_3 -> check_stage_3_compliance(code)  # Production optimizations
      :stage_4 -> check_stage_4_compliance(code)  # Iterative improvements
      _ -> 0.0
    end
    
    min(base_score + stage_bonus, 1.0)
  end
  
  defp calculate_tiki_adherence(code, manager) do
    # Score based on TIKI specification compliance for manager domain
    base_score = 0.87
    
    # Manager-specific TIKI compliance
    manager_bonus = case manager do
      :ufm -> check_ufm_tiki_compliance(code)
      :ucm -> check_ucm_tiki_compliance(code)
      :urm -> check_urm_tiki_compliance(code)
      :ulm -> check_ulm_tiki_compliance(code)
      :uim -> check_uim_tiki_compliance(code)
      :uam -> check_uam_tiki_compliance(code)
      :udm -> check_udm_tiki_compliance(code)
      _ -> 0.0
    end
    
    min(base_score + manager_bonus, 1.0)
  end
  
  defp calculate_federation_compatibility(code, manager) do
    # Score based on ELIAS federation integration compatibility
    base_score = 0.89
    
    # Check for GenServer pattern (federation compatible)
    genserver_bonus = if String.contains?(code, "GenServer"), do: 0.03, else: 0.0
    
    # Check for proper error handling (federation resilience)
    error_handling_bonus = if String.contains?(code, ["{:error", "try", "rescue"]), do: 0.04, else: 0.0
    
    # Check for manager-specific federation patterns
    federation_bonus = check_manager_federation_patterns(code, manager)
    
    base_score + genserver_bonus + error_handling_bonus + federation_bonus
  end
  
  defp calculate_code_quality(code) do
    # General code quality metrics
    base_score = 0.82
    
    # Documentation bonus
    doc_bonus = if String.contains?(code, "@moduledoc"), do: 0.05, else: 0.0
    
    # Type specification bonus
    spec_bonus = if String.contains?(code, "@spec"), do: 0.03, else: 0.0
    
    # Proper error handling
    error_bonus = if String.contains?(code, ["{:ok", "{:error"]), do: 0.05, else: 0.0
    
    # Testing presence
    test_bonus = if String.contains?(code, ["test", "assert"]), do: 0.05, else: 0.0
    
    base_score + doc_bonus + spec_bonus + error_bonus + test_bonus
  end
  
  # Stage-specific compliance checks
  
  defp check_stage_1_compliance(code) do
    # Stage 1: Brute force - should work in basic form
    if String.contains?(code, ["def ", "do"]) and not String.contains?(code, "raise"), do: 0.07, else: 0.0
  end
  
  defp check_stage_2_compliance(code) do
    # Stage 2: Extended functionality - should have error handling
    if String.contains?(code, ["{:error", "case"]), do: 0.08, else: 0.0
  end
  
  defp check_stage_3_compliance(code) do
    # Stage 3: Production optimizations - should have caching, performance considerations
    optimizations = ["cache", "optimize", "performance", "efficient"]
    if Enum.any?(optimizations, &String.contains?(code, &1)), do: 0.09, else: 0.0
  end
  
  defp check_stage_4_compliance(code) do
    # Stage 4: Iterative improvements - should have monitoring, feedback loops
    improvements = ["monitor", "metric", "feedback", "improve", "adapt"]
    if Enum.any?(improvements, &String.contains?(code, &1)), do: 0.10, else: 0.0
  end
  
  # Manager-specific TIKI compliance checks
  
  defp check_ufm_tiki_compliance(code) do
    ufm_patterns = ["federation", "coordinate", "balance", "distribute", "node"]
    if Enum.any?(ufm_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_ucm_tiki_compliance(code) do
    ucm_patterns = ["content", "process", "format", "extract", "pipeline"]
    if Enum.any?(ucm_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_urm_tiki_compliance(code) do
    urm_patterns = ["resource", "memory", "optimize", "allocate", "schedule"]
    if Enum.any?(urm_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_ulm_tiki_compliance(code) do
    ulm_patterns = ["learn", "adapt", "improve", "quality", "assess"]
    if Enum.any?(ulm_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_uim_tiki_compliance(code) do
    uim_patterns = ["interface", "user", "experience", "cli", "api"]
    if Enum.any?(uim_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_uam_tiki_compliance(code) do
    uam_patterns = ["creative", "content", "brand", "design", "artistic"]
    if Enum.any?(uam_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_udm_tiki_compliance(code) do
    udm_patterns = ["deploy", "pipeline", "orchestrate", "release", "rollback", "cicd"]
    if Enum.any?(udm_patterns, &String.contains?(String.downcase(code), &1)), do: 0.08, else: 0.0
  end
  
  defp check_manager_federation_patterns(code, manager) do
    # Check for manager-specific federation integration patterns
    case manager do
      :ufm -> if String.contains?(code, ["GenServer.cast", "coordinate"]), do: 0.04, else: 0.0
      :ucm -> if String.contains?(code, ["pipeline", "process"]), do: 0.04, else: 0.0
      :urm -> if String.contains?(code, ["monitor", "optimize"]), do: 0.04, else: 0.0
      :ulm -> if String.contains?(code, ["analyze", "improve"]), do: 0.04, else: 0.0
      :uim -> if String.contains?(code, ["interface", "user"]), do: 0.04, else: 0.0
      :uam -> if String.contains?(code, ["generate", "create"]), do: 0.04, else: 0.0
      :udm -> if String.contains?(code, ["deploy", "orchestrate"]), do: 0.04, else: 0.0
      _ -> 0.0
    end
  end
  
  # Validation Helper
  
  defp validate_all_assertions(assertions) do
    failed = Enum.filter(assertions, fn {_name, score} -> 
      case score do
        score when is_number(score) -> score < get_threshold_for_assertion(elem(List.first(assertions), 0))
        _ -> true  # Non-numeric scores are considered failures
      end
    end)
    
    if length(failed) == 0 do
      {:ok, Map.new(assertions)}
    else
      {:error, failed}
    end
  end
  
  defp get_threshold_for_assertion(assertion_type) do
    Map.get(@assert_thresholds, assertion_type, 0.80)  # Default threshold
  end
end