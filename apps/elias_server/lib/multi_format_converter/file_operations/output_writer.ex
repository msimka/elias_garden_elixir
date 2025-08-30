defmodule MultiFormatConverter.FileOperations.OutputWriter do
  @moduledoc """
  Atomic Component 1.3: OutputWriter
  
  RESPONSIBILITY: Write markdown content to file - ONLY write output file
  
  Based on Architect guidance:
  - Atomic granularity: One responsibility per component
  - Real testing: Write to actual filesystem, verify content matches exactly
  - Blockchain verification: All tests signed and submitted to Level 2 rollup
  
  Tank Building Stage 1: Brute force file writing with basic error handling
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # Public API - Atomic Component Interface

  @doc """
  Write markdown content to output file
  
  Input: content (string) - Markdown content to write
         output_path (string) - Path for output file
  Output: {:ok, bytes_written (integer)} | {:error, reason}
  
  ATOMIC RESPONSIBILITY: ONLY write output file, no content processing
  """
  def write_output(content, output_path) 
      when is_binary(content) and is_binary(output_path) do
    Logger.debug("OutputWriter: Writing #{byte_size(content)} bytes to #{output_path}")
    
    # Ensure parent directory exists
    case ensure_parent_directory(output_path) do
      :ok ->
        case File.write(output_path, content) do
          :ok ->
            bytes_written = byte_size(content)
            Logger.debug("OutputWriter: Successfully wrote #{bytes_written} bytes to #{output_path}")
            {:ok, bytes_written}
            
          {:error, reason} ->
            Logger.error("OutputWriter: Failed to write to #{output_path}: #{reason}")
            {:error, reason}
        end
        
      {:error, reason} ->
        Logger.error("OutputWriter: Could not create parent directory for #{output_path}: #{reason}")
        {:error, {:parent_directory_error, reason}}
    end
  end

  def write_output(invalid_content, output_path) when not is_binary(invalid_content) do
    Logger.error("OutputWriter: Invalid content type: #{inspect(invalid_content)}")
    {:error, :invalid_content_type}
  end

  def write_output(content, invalid_path) when not is_binary(invalid_path) do
    Logger.error("OutputWriter: Invalid output path type: #{inspect(invalid_path)}")
    {:error, :invalid_path_type}
  end

  @doc """
  Write content with backup of existing file
  
  Creates backup before overwriting existing files
  """
  def write_output_with_backup(content, output_path) 
      when is_binary(content) and is_binary(output_path) do
    Logger.debug("OutputWriter: Writing with backup to #{output_path}")
    
    # Create backup if file exists
    backup_result = if File.exists?(output_path) do
      create_backup(output_path)
    else
      :ok
    end
    
    case backup_result do
      :ok ->
        write_output(content, output_path)
        
      {:error, reason} ->
        Logger.error("OutputWriter: Backup creation failed: #{reason}")
        {:error, {:backup_failed, reason}}
    end
  end

  @doc """
  Write content atomically using temporary file
  
  Writes to temporary file first, then moves to final location
  Prevents partial writes if process is interrupted
  """
  def write_output_atomic(content, output_path) 
      when is_binary(content) and is_binary(output_path) do
    Logger.debug("OutputWriter: Atomic write to #{output_path}")
    
    temp_path = "#{output_path}.tmp.#{:erlang.unique_integer([:positive])}"
    
    case ensure_parent_directory(output_path) do
      :ok ->
        case File.write(temp_path, content) do
          :ok ->
            case File.rename(temp_path, output_path) do
              :ok ->
                bytes_written = byte_size(content)
                Logger.debug("OutputWriter: Atomic write successful (#{bytes_written} bytes)")
                {:ok, bytes_written}
                
              {:error, reason} ->
                # Clean up temp file on failure
                File.rm(temp_path)
                Logger.error("OutputWriter: Failed to move temp file to final location: #{reason}")
                {:error, {:atomic_move_failed, reason}}
            end
            
          {:error, reason} ->
            Logger.error("OutputWriter: Failed to write temp file #{temp_path}: #{reason}")
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, {:parent_directory_error, reason}}
    end
  end

  @doc """
  Verify written file matches expected content
  
  Reads back the written file and compares with original content
  """
  def verify_written_content(output_path, expected_content) 
      when is_binary(output_path) and is_binary(expected_content) do
    case File.read(output_path) do
      {:ok, actual_content} ->
        content_matches = (actual_content == expected_content)
        size_matches = (byte_size(actual_content) == byte_size(expected_content))
        
        %{
          content_matches: content_matches,
          size_matches: size_matches,
          expected_size: byte_size(expected_content),
          actual_size: byte_size(actual_content),
          verification_success: content_matches and size_matches
        }
        
      {:error, reason} ->
        Logger.error("OutputWriter: Could not read written file for verification: #{reason}")
        %{
          content_matches: false,
          size_matches: false,
          verification_success: false,
          error: reason
        }
    end
  end

  @doc """
  Get output file statistics after writing
  
  Returns file information for verification purposes
  """
  def get_output_file_stats(output_path) when is_binary(output_path) do
    case File.stat(output_path) do
      {:ok, stat} ->
        {:ok, %{
          size: stat.size,
          mtime: stat.mtime,
          atime: stat.atime,
          mode: stat.mode,
          type: stat.type,
          exists: true
        }}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Implementation Functions

  defp ensure_parent_directory(file_path) do
    parent_dir = Path.dirname(file_path)
    
    case File.exists?(parent_dir) do
      true ->
        :ok
      false ->
        Logger.debug("OutputWriter: Creating parent directory #{parent_dir}")
        case File.mkdir_p(parent_dir) do
          :ok -> 
            :ok
          {:error, reason} -> 
            {:error, reason}
        end
    end
  end

  defp create_backup(file_path) do
    backup_path = "#{file_path}.backup.#{DateTime.utc_now() |> DateTime.to_unix()}"
    
    case File.copy(file_path, backup_path) do
      {:ok, _bytes} ->
        Logger.debug("OutputWriter: Created backup at #{backup_path}")
        :ok
        
      {:error, reason} ->
        Logger.error("OutputWriter: Backup creation failed: #{reason}")
        {:error, reason}
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "1.3"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "OutputWriter"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["write_markdown_content_to_file", "create_parent_directories_if_needed"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["content: string", "output_path: string"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["success: boolean", "bytes_written: integer"]
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
      features: ["atomic_writes", "backup_creation", "directory_creation", "content_verification"],
      file_operations: ["write", "copy", "mkdir", "rename", "stat"],
      safety_mechanisms: ["parent_directory_creation", "atomic_writes", "backup_before_overwrite"]
    })
  end
end