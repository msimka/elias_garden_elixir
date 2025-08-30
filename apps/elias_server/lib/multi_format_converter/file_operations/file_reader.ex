defmodule MultiFormatConverter.FileOperations.FileReader do
  @moduledoc """
  Atomic Component 1.1: FileReader
  
  RESPONSIBILITY: Read file bytes from filesystem - ONLY file reading, no processing
  
  Based on Architect guidance:
  - Atomic granularity: One responsibility per component
  - Real testing: Test with actual files from disk
  - Blockchain verification: All tests signed and submitted to Level 2 rollup
  
  Tank Building Stage 1: Brute force file reading with basic error handling
  """
  
  require Logger

  use MultiFormatConverter.AtomicComponent

  # Public API - Atomic Component Interface

  @doc """
  Read file bytes from filesystem
  
  Input: file_path (string) - Path to file to read
  Output: {:ok, content (binary), size (integer)} | {:error, reason}
  
  ATOMIC RESPONSIBILITY: ONLY read file, no processing whatsoever
  """
  def read_file(file_path) when is_binary(file_path) do
    Logger.debug("FileReader: Reading file #{file_path}")
    
    case File.read(file_path) do
      {:ok, content} ->
        size = byte_size(content)
        Logger.debug("FileReader: Successfully read #{size} bytes from #{file_path}")
        {:ok, content, size}
        
      {:error, reason} ->
        Logger.warn("FileReader: Failed to read #{file_path}: #{reason}")
        {:error, reason}
    end
  end

  def read_file(invalid_path) do
    Logger.error("FileReader: Invalid file path type: #{inspect(invalid_path)}")
    {:error, :invalid_path_type}
  end

  @doc """
  Read file with additional metadata (extended functionality for Stage 2)
  
  Returns file content plus filesystem metadata
  """
  def read_file_with_metadata(file_path) when is_binary(file_path) do
    case read_file(file_path) do
      {:ok, content, size} ->
        case File.stat(file_path) do
          {:ok, stat} ->
            metadata = %{
              size: size,
              mtime: stat.mtime,
              atime: stat.atime,
              ctime: stat.ctime,
              mode: stat.mode,
              type: stat.type
            }
            {:ok, content, size, metadata}
            
          {:error, stat_error} ->
            Logger.warn("FileReader: Could not get file stat for #{file_path}: #{stat_error}")
            # Still return content but without metadata
            {:ok, content, size, %{size: size}}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if file is readable before attempting to read
  
  This is a helper function but maintains atomic responsibility
  """
  def can_read_file?(file_path) when is_binary(file_path) do
    case File.stat(file_path) do
      {:ok, %{access: access}} when access in [:read, :read_write] ->
        true
      {:ok, %{type: :regular}} ->
        # Try to determine if readable by attempting to open
        case File.open(file_path, [:read]) do
          {:ok, file} ->
            File.close(file)
            true
          {:error, _} ->
            false
        end
      {:ok, _} ->
        false
      {:error, _} ->
        false
    end
  end

  def can_read_file?(_), do: false

  @doc """
  Read file in chunks for large files (Stage 2 optimization)
  
  Useful for files that might not fit in memory
  """
  def read_file_chunked(file_path, chunk_size \\ 8192) when is_binary(file_path) and is_integer(chunk_size) do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          content = read_chunks(file, chunk_size, [])
          size = byte_size(content)
          Logger.debug("FileReader: Successfully read #{size} bytes in chunks from #{file_path}")
          {:ok, content, size}
        catch
          error ->
            Logger.error("FileReader: Error reading chunks from #{file_path}: #{inspect(error)}")
            {:error, :chunk_read_error}
        after
          File.close(file)
        end
        
      {:error, reason} ->
        Logger.warn("FileReader: Could not open #{file_path} for chunked reading: #{reason}")
        {:error, reason}
    end
  end

  # Private Implementation Functions

  defp read_chunks(file, chunk_size, acc) do
    case IO.binread(file, chunk_size) do
      :eof ->
        # Reverse and concatenate all chunks
        acc |> Enum.reverse() |> IO.iodata_to_binary()
        
      {:error, reason} ->
        throw({:read_error, reason})
        
      chunk when is_binary(chunk) ->
        read_chunks(file, chunk_size, [chunk | acc])
    end
  end

  # AtomicComponent Behavior Implementation

  @impl MultiFormatConverter.AtomicComponent
  def component_id, do: "1.1"

  @impl MultiFormatConverter.AtomicComponent  
  def component_name, do: "FileReader"

  @impl MultiFormatConverter.AtomicComponent
  def component_responsibilities do
    ["read_file_bytes_from_filesystem"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_inputs do
    ["file_path: string"]
  end

  @impl MultiFormatConverter.AtomicComponent
  def component_outputs do
    ["content: binary", "size: integer"]
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
end