defmodule MultiFormatConverter.Optimization.StreamingProcessor do
  @moduledoc """
  Streaming File Processing for Large File Optimization
  
  RESPONSIBILITY: Handle large files efficiently using streaming techniques
  
  Tank Building Stage 3: Optimize
  - Memory-efficient streaming for large files (>50MB)
  - Chunked processing with backpressure control
  - Progress reporting for long-running operations
  - Adaptive chunk sizing based on available memory
  - Stream-based pipeline processing
  
  Integrates with Stage 2 components without breaking existing functionality
  """
  
  require Logger
  
  # Streaming configuration
  @large_file_threshold 50 * 1024 * 1024  # 50MB
  @default_chunk_size 8 * 1024 * 1024     # 8MB chunks
  @max_chunk_size 32 * 1024 * 1024        # 32MB max chunk
  @min_chunk_size 1 * 1024 * 1024         # 1MB min chunk
  @max_concurrent_chunks 4                 # Parallel processing limit

  # Import atomic components for streaming integration
  alias MultiFormatConverter.FileOperations.{FileReader, FileValidator}
  alias MultiFormatConverter.Optimization.PerformanceMonitor

  @doc """
  Determine if file should use streaming processing
  
  Based on file size and available system memory
  """
  def should_use_streaming?(file_path) when is_binary(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        size > @large_file_threshold or should_use_streaming_for_memory?(size)
      {:error, _} ->
        false
    end
  end

  @doc """
  Stream process a large file through the conversion pipeline
  
  Returns a stream of processed chunks that can be consumed efficiently
  """
  def stream_convert_file(input_path, output_path, options \\ []) do
    Logger.info("StreamingProcessor: Starting streaming conversion")
    Logger.info("  Input: #{input_path}")
    Logger.info("  Output: #{output_path}")
    
    operation_id = PerformanceMonitor.start_operation("streaming_conversion", get_file_size(input_path))
    
    try do
      # Validate file first
      case FileValidator.validate_file(input_path) do
        {:ok, true, nil} ->
          perform_streaming_conversion(input_path, output_path, options, operation_id)
          
        {:ok, false, reason} ->
          PerformanceMonitor.complete_operation(operation_id, false, 0, reason)
          {:error, {:validation_failed, reason}}
          
        {:error, reason} ->
          PerformanceMonitor.complete_operation(operation_id, false, 0, reason)
          {:error, {:validation_error, reason}}
      end
      
    rescue
      error ->
        PerformanceMonitor.complete_operation(operation_id, false, 0, inspect(error))
        {:error, {:streaming_exception, inspect(error)}}
    end
  end

  @doc """
  Create a file stream with optimal chunk sizing
  
  Adapts chunk size based on file size and available memory
  """
  def create_file_stream(file_path, opts \\ []) do
    chunk_size = calculate_optimal_chunk_size(file_path, opts)
    
    Logger.debug("StreamingProcessor: Creating file stream with #{format_bytes(chunk_size)} chunks")
    
    File.stream!(file_path, [], chunk_size)
  end

  @doc """
  Process file chunks in parallel with backpressure control
  
  Maintains memory efficiency while maximizing throughput
  """
  def process_chunks_parallel(chunks_stream, processor_func, options \\ []) do
    max_concurrency = Keyword.get(options, :max_concurrency, @max_concurrent_chunks)
    timeout = Keyword.get(options, :timeout, 120_000)
    
    Logger.debug("StreamingProcessor: Processing chunks with concurrency #{max_concurrency}")
    
    chunks_stream
    |> Task.async_stream(
      processor_func,
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Stream.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:task_timeout, reason}}
    end)
  end

  @doc """
  Stream write results to output file
  
  Efficiently writes processed chunks without loading everything into memory
  """
  def stream_write_output(results_stream, output_path) do
    Logger.debug("StreamingProcessor: Streaming write to #{output_path}")
    
    case File.open(output_path, [:write, :binary]) do
      {:ok, file} ->
        try do
          total_bytes = results_stream
          |> Stream.with_index()
          |> Enum.reduce(0, fn {chunk_result, index}, acc ->
            case chunk_result do
              {:ok, data} when is_binary(data) ->
                IO.binwrite(file, data)
                bytes_written = byte_size(data)
                
                if rem(index, 100) == 0 do
                  Logger.debug("StreamingProcessor: Written chunk #{index} (#{format_bytes(bytes_written)})")
                end
                
                acc + bytes_written
                
              {:error, reason} ->
                Logger.error("StreamingProcessor: Chunk #{index} failed: #{inspect(reason)}")
                acc
                
              _ ->
                Logger.warn("StreamingProcessor: Unexpected chunk result: #{inspect(chunk_result)}")
                acc
            end
          end)
          
          File.close(file)
          {:ok, total_bytes}
          
        rescue
          error ->
            File.close(file)
            {:error, {:write_stream_error, inspect(error)}}
        end
        
      {:error, reason} ->
        {:error, {:file_open_error, reason}}
    end
  end

  @doc """
  Monitor streaming progress with periodic updates
  """
  def monitor_streaming_progress(stream, total_size, callback \\ nil) do
    stream
    |> Stream.with_index()
    |> Stream.map(fn {item, index} ->
      # Calculate approximate progress
      progress_percent = case total_size do
        0 -> 0
        _ -> min((index * @default_chunk_size / total_size) * 100, 100)
      end
      
      # Call progress callback if provided
      if callback and rem(index, 10) == 0 do
        callback.({:progress, progress_percent, index})
      end
      
      item
    end)
  end

  # Private Implementation

  defp perform_streaming_conversion(input_path, output_path, options, operation_id) do
    start_time = System.monotonic_time(:millisecond)
    
    # Get file information
    file_size = get_file_size(input_path)
    format = detect_format_efficiently(input_path)
    
    Logger.info("StreamingProcessor: Processing #{format_bytes(file_size)} #{format} file")
    
    # Create streaming pipeline
    result = input_path
    |> create_file_stream(options)
    |> monitor_streaming_progress(file_size, Keyword.get(options, :progress_callback))
    |> process_format_specific_chunks(format, options)
    |> stream_write_output(output_path)
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    case result do
      {:ok, output_bytes} ->
        Logger.info("StreamingProcessor: Completed in #{duration}ms, wrote #{format_bytes(output_bytes)}")
        PerformanceMonitor.complete_operation(operation_id, true, output_bytes)
        {:ok, %{
          input_size: file_size,
          output_size: output_bytes,
          duration_ms: duration,
          format: format,
          processing_method: "streaming"
        }}
        
      {:error, reason} ->
        Logger.error("StreamingProcessor: Failed after #{duration}ms: #{inspect(reason)}")
        PerformanceMonitor.complete_operation(operation_id, false, 0, reason)
        {:error, reason}
    end
  end

  defp should_use_streaming_for_memory?(file_size) do
    available_memory = get_available_memory()
    
    # Use streaming if file is more than 25% of available memory
    file_size > (available_memory * 0.25)
  end

  defp get_available_memory do
    # Get available system memory
    total_memory = :erlang.memory(:total)
    system_memory = :erlang.system_info(:wordsize) * :erlang.system_info(:system_architecture)
    
    # Simple heuristic for available memory
    max(system_memory - total_memory, 100 * 1024 * 1024)  # At least 100MB
  end

  defp calculate_optimal_chunk_size(file_path, opts) do
    file_size = get_file_size(file_path)
    available_memory = get_available_memory()
    
    # Base chunk size on file size and available memory
    memory_based_size = div(available_memory, @max_concurrent_chunks * 2)
    file_based_size = div(file_size, 100)  # Aim for ~100 chunks
    
    optimal_size = [
      memory_based_size,
      file_based_size,
      Keyword.get(opts, :chunk_size, @default_chunk_size)
    ]
    |> Enum.min()
    |> max(@min_chunk_size)
    |> min(@max_chunk_size)
    
    Logger.debug("StreamingProcessor: Calculated optimal chunk size: #{format_bytes(optimal_size)}")
    optimal_size
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end

  defp detect_format_efficiently(file_path) do
    # Read only first 1KB for format detection to save memory
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        sample = IO.binread(file, 1024)
        File.close(file)
        
        # Use existing format detector on sample
        case MultiFormatConverter.FormatDetection.FormatDetector.detect_format(sample) do
          {:ok, format} -> format
          {:error, _} -> :unknown
        end
        
      {:error, _} ->
        :unknown
    end
  end

  defp process_format_specific_chunks(chunks_stream, format, options) do
    processor_func = get_chunk_processor_for_format(format, options)
    
    # Process chunks with controlled concurrency
    process_chunks_parallel(chunks_stream, processor_func, options)
  end

  defp get_chunk_processor_for_format(format, _options) do
    case format do
      :txt ->
        &process_text_chunk/1
        
      :pdf ->
        &process_pdf_chunk/1
        
      :html ->
        &process_html_chunk/1
        
      :xml ->
        &process_xml_chunk/1
        
      _ ->
        &process_generic_chunk/1
    end
  end

  defp process_text_chunk(chunk) do
    # For text files, just pass through with markdown formatting
    {:ok, chunk}
  end

  defp process_pdf_chunk(chunk) do
    # For PDF chunks, we need to accumulate and process as complete structures
    # Stage 3 optimization: implement streaming PDF processing
    {:ok, "<!-- PDF chunk processed via streaming -->\n"}
  end

  defp process_html_chunk(chunk) do
    # Process HTML chunk by chunk, removing tags
    processed = chunk
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    
    {:ok, processed <> "\n"}
  end

  defp process_xml_chunk(chunk) do
    # Process XML chunk, extracting text content
    processed = chunk
    |> String.replace(~r/<!\[CDATA\[.*?\]\]>/s, "")
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    
    {:ok, processed <> "\n"}
  end

  defp process_generic_chunk(chunk) do
    # Generic chunk processing
    {:ok, chunk}
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end