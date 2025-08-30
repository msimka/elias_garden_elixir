defmodule MultiFormatConverter.FileOperations.FileValidator do
  @moduledoc """
  Atomic Component 1.2: FileValidator
  
  RESPONSIBILITY: Validate file exists, readable, size limits - ONLY validation checks
  
  Based on Architect guidance:
  - Atomic granularity: One responsibility per component  
  - Real testing: Test with non-existent files, permission denied, oversized files
  - Blockchain verification: All tests signed and submitted to Level 2 rollup
  
  Tank Building Stage 1: Brute force validation with essential checks
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # Configuration - can be moved to config in Stage 2
  @max_file_size_bytes 100 * 1024 * 1024  # 100MB default limit
  @min_file_size_bytes 0

  # Public API - Atomic Component Interface

  @doc """
  Validate file exists, readable, and meets size requirements
  
  Input: file_path (string) - Path to file to validate
  Output: {:ok, valid (boolean), error_reason (string | nil)} | {:error, reason}
  
  ATOMIC RESPONSIBILITY: ONLY validation checks, no file content processing
  """
  def validate_file(file_path) when is_binary(file_path) do
    Logger.debug("FileValidator: Validating file #{file_path}")
    
    # Perform validation checks in order of priority
    case check_file_exists(file_path) do
      {:error, reason} ->
        {:ok, false, "File does not exist: #{reason}"}
        
      :ok ->
        case check_file_readable(file_path) do
          {:error, reason} ->
            {:ok, false, "File not readable: #{reason}"}
            
          :ok ->
            case check_file_size(file_path) do
              {:error, reason} ->
                {:ok, false, "File size invalid: #{reason}"}
                
              :ok ->
                Logger.debug("FileValidator: File #{file_path} passed all validations")
                {:ok, true, nil}
            end
        end
    end
  end

  def validate_file(invalid_path) do
    Logger.error("FileValidator: Invalid file path type: #{inspect(invalid_path)}")
    {:error, :invalid_path_type}
  end

  @doc """
  Validate file with custom size limits
  
  Allows override of default size limits for specific use cases
  """
  def validate_file_with_limits(file_path, min_size, max_size) 
      when is_binary(file_path) and is_integer(min_size) and is_integer(max_size) do
    Logger.debug("FileValidator: Validating #{file_path} with custom limits (#{min_size}-#{max_size} bytes)")
    
    case check_file_exists(file_path) do
      {:error, reason} ->
        {:ok, false, "File does not exist: #{reason}"}
        
      :ok ->
        case check_file_readable(file_path) do
          {:error, reason} ->
            {:ok, false, "File not readable: #{reason}"}
            
          :ok ->
            case check_file_size_custom(file_path, min_size, max_size) do
              {:error, reason} ->
                {:ok, false, "File size invalid: #{reason}"}
                
              :ok ->
                {:ok, true, nil}
            end
        end
    end
  end

  @doc """
  Quick validation check - returns boolean only
  
  Useful for simple existence checks
  """
  def file_valid?(file_path) when is_binary(file_path) do
    case validate_file(file_path) do
      {:ok, valid, _reason} -> valid
      {:error, _} -> false
    end
  end

  def file_valid?(_), do: false

  @doc """
  Get detailed file validation report
  
  Returns comprehensive validation results for debugging
  """
  def get_validation_report(file_path) when is_binary(file_path) do
    report = %{
      file_path: file_path,
      exists: false,
      readable: false,
      size_valid: false,
      size_bytes: 0,
      error_messages: []
    }
    
    # Check existence
    {exists, report} = case check_file_exists(file_path) do
      :ok -> 
        {true, %{report | exists: true}}
      {:error, reason} -> 
        {false, %{report | error_messages: ["Existence: #{reason}" | report.error_messages]}}
    end
    
    # Check readability if file exists
    {readable, report} = if exists do
      case check_file_readable(file_path) do
        :ok -> 
          {true, %{report | readable: true}}
        {:error, reason} -> 
          {false, %{report | error_messages: ["Readable: #{reason}" | report.error_messages]}}
      end
    else
      {false, report}
    end
    
    # Check size if file is readable
    {size_valid, report} = if readable do
      case File.stat(file_path) do
        {:ok, %{size: size}} ->
          report = %{report | size_bytes: size}
          case check_file_size(file_path) do
            :ok -> 
              {true, %{report | size_valid: true}}
            {:error, reason} -> 
              {false, %{report | error_messages: ["Size: #{reason}" | report.error_messages]}}
          end
        {:error, reason} ->
          {false, %{report | error_messages: ["Stat: #{reason}" | report.error_messages]}}
      end
    else
      {false, report}
    end
    
    overall_valid = exists and readable and size_valid
    %{report | error_messages: Enum.reverse(report.error_messages)}
    |> Map.put(:overall_valid, overall_valid)
  end

  # Private Implementation Functions

  defp check_file_exists(file_path) do
    if File.exists?(file_path) do
      :ok
    else
      {:error, "file_not_found"}
    end
  end

  defp check_file_readable(file_path) do
    case File.stat(file_path) do
      {:ok, %{type: :regular}} ->
        # Try to open file for reading to verify permissions
        case File.open(file_path, [:read]) do
          {:ok, file} ->
            File.close(file)
            :ok
          {:error, :eacces} ->
            {:error, "permission_denied"}
          {:error, reason} ->
            {:error, "open_failed_#{reason}"}
        end
        
      {:ok, %{type: type}} ->
        {:error, "not_regular_file_#{type}"}
        
      {:error, :enoent} ->
        {:error, "file_not_found"}
        
      {:error, reason} ->
        {:error, "stat_failed_#{reason}"}
    end
  end

  defp check_file_size(file_path) do
    check_file_size_custom(file_path, @min_file_size_bytes, @max_file_size_bytes)
  end

  defp check_file_size_custom(file_path, min_size, max_size) do
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        cond do
          size < min_size ->
            {:error, "file_too_small_#{size}_bytes_min_#{min_size}"}
          size > max_size ->
            {:error, "file_too_large_#{size}_bytes_max_#{max_size}"}
          true ->
            :ok
        end
        
      {:error, reason} ->
        {:error, "cannot_get_file_size_#{reason}"}
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "1.2"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "FileValidator"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["validate_file_existence_and_permissions", "validate_file_size_limits"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["file_path: string"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["valid: boolean", "error_reason: string | nil"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_dependencies do
    []  # No dependencies - this is a leaf atomic component
  end

  @impl MultiFormatConverter.AtomicComponent
  def run_component_tests do
    # Use the real verification test framework
    MultiFormatConverter.TestFramework.test_atomic_component(__MODULE__, component_id())
  end

  @impl MultiFormatConverter.AtomicComponent
  def verify_blockchain_signature(signature) do
    MultiFormatConverter.TestFramework.verify_blockchain_test_results(component_id(), signature)
  end

  @impl MultiFormatConverter.AtomicComponent
  def get_component_metadata do
    base_metadata = %{
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
    
    Map.merge(base_metadata, %{
      configuration: %{
        max_file_size_bytes: @max_file_size_bytes,
        min_file_size_bytes: @min_file_size_bytes
      },
      validation_types: ["existence", "readability", "size_limits", "file_type"]
    })
  end
end