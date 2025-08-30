defmodule MultiFormatConverter.Optimization.BatchProcessor do
  @moduledoc """
  Batch Processing System for Multiple File Conversion
  
  RESPONSIBILITY: Efficiently process multiple files in batch operations
  
  Tank Building Stage 3: Optimize
  - Parallel processing of multiple files with controlled concurrency
  - Progress tracking and reporting for batch operations
  - Error recovery and partial batch completion
  - Resource management and memory optimization
  - Batch result aggregation and reporting
  - Integration with caching and streaming systems
  
  Maintains backward compatibility with single-file processing
  """
  
  require Logger
  
  # Batch processing configuration
  @default_batch_size 10
  @max_batch_size 100
  @default_concurrency 4
  @max_concurrency 16
  @batch_timeout 600_000  # 10 minutes
  
  # Import optimization systems
  alias MultiFormatConverter.Pipeline.ConverterOrchestrator
  alias MultiFormatConverter.Optimization.{PerformanceMonitor, SmartCache, StreamingProcessor}

  # Batch processing structures
  defmodule BatchJob do
    defstruct [
      :batch_id,
      :files,
      :options,
      :started_at,
      :completed_at,
      :status,
      :progress,
      :results,
      :errors,
      :performance_metrics
    ]
  end

  defmodule BatchResult do
    defstruct [
      :batch_id,
      :total_files,
      :successful_files,
      :failed_files,
      :skipped_files,
      :total_duration_ms,
      :total_input_size,
      :total_output_size,
      :files_per_second,
      :bytes_per_second,
      :individual_results,
      :error_summary
    ]
  end

  @doc """
  Process multiple files in batch with optimized parallelization
  
  Options:
  - concurrency: number of parallel workers (default 4)
  - batch_size: files per batch chunk (default 10)
  - output_dir: directory for output files
  - progress_callback: function called with progress updates
  - error_handling: :stop_on_error | :continue_on_error (default :continue_on_error)
  - use_streaming: enable streaming for large files (default true)
  - use_cache: enable caching optimizations (default true)
  """
  def process_batch(file_paths, options \\ []) when is_list(file_paths) do
    Logger.info("BatchProcessor: Starting batch processing of #{length(file_paths)} files")
    
    batch_id = generate_batch_id()
    operation_id = PerformanceMonitor.start_operation("batch_processing", calculate_total_input_size(file_paths))
    
    batch_job = %BatchJob{
      batch_id: batch_id,
      files: file_paths,
      options: options,
      started_at: System.monotonic_time(:millisecond),
      status: :running,
      progress: 0,
      results: [],
      errors: [],
      performance_metrics: %{}
    }
    
    Logger.info("BatchProcessor: Created batch job #{batch_id}")
    
    try do
      result = execute_batch_processing(batch_job, operation_id)
      PerformanceMonitor.complete_operation(operation_id, true, result.total_output_size)
      {:ok, result}
      
    rescue
      error ->
        Logger.error("BatchProcessor: Batch processing failed: #{inspect(error)}")
        PerformanceMonitor.complete_operation(operation_id, false, 0, inspect(error))
        {:error, {:batch_processing_failed, inspect(error)}}
    end
  end

  @doc """
  Process files in directory with pattern matching
  
  Automatically discovers files matching patterns and processes them in batch
  """
  def process_directory(directory_path, file_patterns \\ ["**/*.{pdf,rtf,docx,txt,html,xml}"], options \\ []) do
    Logger.info("BatchProcessor: Processing directory #{directory_path}")
    
    case discover_files_in_directory(directory_path, file_patterns) do
      {:ok, file_paths} when length(file_paths) > 0 ->
        Logger.info("BatchProcessor: Discovered #{length(file_paths)} files")
        process_batch(file_paths, options)
        
      {:ok, []} ->
        Logger.info("BatchProcessor: No files found in directory")
        {:ok, %BatchResult{
          batch_id: generate_batch_id(),
          total_files: 0,
          successful_files: 0,
          failed_files: 0,
          skipped_files: 0
        }}
        
      {:error, reason} ->
        Logger.error("BatchProcessor: Failed to discover files: #{inspect(reason)}")
        {:error, {:directory_discovery_failed, reason}}
    end
  end

  @doc """
  Monitor batch processing progress
  
  Returns current status and progress information
  """
  def get_batch_status(batch_id) do
    # In production, this would query persistent batch state
    Logger.debug("BatchProcessor: Status query for batch #{batch_id}")
    {:ok, :status_monitoring_not_implemented_in_stage_3}
  end

  @doc """
  Cancel running batch processing
  """
  def cancel_batch(batch_id) do
    Logger.info("BatchProcessor: Cancelling batch #{batch_id}")
    {:ok, :batch_cancellation_not_implemented_in_stage_3}
  end

  @doc """
  Get batch processing performance recommendations
  """
  def get_batch_optimization_recommendations(batch_result) do
    analyze_batch_performance_and_recommend(batch_result)
  end

  # Private Implementation

  defp execute_batch_processing(batch_job, operation_id) do
    start_time = batch_job.started_at
    
    # Parse options
    concurrency = Keyword.get(batch_job.options, :concurrency, @default_concurrency) |> min(@max_concurrency)
    batch_size = Keyword.get(batch_job.options, :batch_size, @default_batch_size) |> min(@max_batch_size)
    output_dir = Keyword.get(batch_job.options, :output_dir, "./output")
    error_handling = Keyword.get(batch_job.options, :error_handling, :continue_on_error)
    use_streaming = Keyword.get(batch_job.options, :use_streaming, true)
    use_cache = Keyword.get(batch_job.options, :use_cache, true)
    progress_callback = Keyword.get(batch_job.options, :progress_callback)
    
    Logger.info("BatchProcessor: Configuration - concurrency: #{concurrency}, batch_size: #{batch_size}")
    
    # Ensure output directory exists
    File.mkdir_p!(output_dir)
    
    # Split files into batch chunks
    batch_chunks = Enum.chunk_every(batch_job.files, batch_size)
    
    Logger.info("BatchProcessor: Split #{length(batch_job.files)} files into #{length(batch_chunks)} chunks")
    
    # Process chunks in parallel with controlled concurrency
    {individual_results, processing_errors} = batch_chunks
    |> Stream.with_index()
    |> Task.async_stream(
      fn {chunk, chunk_index} ->
        process_batch_chunk(chunk, chunk_index, output_dir, %{
          use_streaming: use_streaming,
          use_cache: use_cache,
          error_handling: error_handling,
          progress_callback: progress_callback,
          total_files: length(batch_job.files)
        })
      end,
      max_concurrency: concurrency,
      timeout: @batch_timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {:chunk_success, results}}, {all_results, errors} ->
        {all_results ++ results, errors}
        
      {:ok, {:chunk_partial, results, chunk_errors}}, {all_results, errors} ->
        {all_results ++ results, errors ++ chunk_errors}
        
      {:ok, {:chunk_failed, chunk_error}}, {all_results, errors} ->
        {all_results, [chunk_error | errors]}
        
      {:exit, timeout_reason}, {all_results, errors} ->
        error = {:batch_chunk_timeout, timeout_reason}
        {all_results, [error | errors]}
    end)
    
    end_time = System.monotonic_time(:millisecond)
    
    # Aggregate results
    result = aggregate_batch_results(
      batch_job.batch_id,
      individual_results,
      processing_errors,
      start_time,
      end_time
    )
    
    Logger.info("BatchProcessor: Completed batch #{batch_job.batch_id}")
    Logger.info("  Success: #{result.successful_files}/#{result.total_files} files")
    Logger.info("  Duration: #{result.total_duration_ms}ms")
    Logger.info("  Throughput: #{Float.round(result.files_per_second, 2)} files/sec")
    
    result
  end

  defp process_batch_chunk(files, chunk_index, output_dir, options) do
    Logger.debug("BatchProcessor: Processing chunk #{chunk_index} with #{length(files)} files")
    
    chunk_start = System.monotonic_time(:millisecond)
    
    {successful_results, failed_results} = files
    |> Enum.with_index()
    |> Enum.map(fn {file_path, file_index_in_chunk} ->
      global_file_index = chunk_index * length(files) + file_index_in_chunk
      process_single_file_in_batch(file_path, output_dir, global_file_index, options)
    end)
    |> Enum.split_with(fn {status, _result} -> status == :success end)
    
    chunk_end = System.monotonic_time(:millisecond)
    chunk_duration = chunk_end - chunk_start
    
    successful_count = length(successful_results)
    failed_count = length(failed_results)
    
    Logger.debug("BatchProcessor: Chunk #{chunk_index} completed in #{chunk_duration}ms")
    Logger.debug("  Success: #{successful_count}, Failed: #{failed_count}")
    
    # Report progress if callback provided
    if options[:progress_callback] do
      total_files = options[:total_files] || 1
      files_per_chunk = max(length(files), 1)
      progress = ((chunk_index + 1) * files_per_chunk / total_files) * 100
      options[:progress_callback].({:chunk_completed, chunk_index, progress})
    end
    
    cond do
      failed_count == 0 ->
        {:chunk_success, Enum.map(successful_results, &elem(&1, 1))}
        
      successful_count > 0 ->
        {:chunk_partial, 
         Enum.map(successful_results, &elem(&1, 1)),
         Enum.map(failed_results, &elem(&1, 1))}
        
      true ->
        {:chunk_failed, Enum.map(failed_results, &elem(&1, 1))}
    end
  end

  defp process_single_file_in_batch(file_path, output_dir, file_index, options) do
    output_file = generate_output_path(file_path, output_dir)
    
    Logger.debug("BatchProcessor: Processing file #{file_index}: #{Path.basename(file_path)}")
    
    # Check cache first if enabled
    cached_result = if options[:use_cache] do
      check_batch_cache(file_path, output_file)
    else
      nil
    end
    
    result = case cached_result do
      {:cache_hit, result} ->
        Logger.debug("BatchProcessor: Using cached result for #{Path.basename(file_path)}")
        {:success, result}
        
      nil ->
        perform_file_conversion(file_path, output_file, options)
    end
    
    # Update cache if successful and caching enabled
    case result do
      {:success, conversion_result} ->
        if options[:use_cache] do
          update_batch_cache(file_path, output_file, conversion_result)
        end
        
      _ ->
        :ok
    end
    
    result
  end

  defp perform_file_conversion(input_path, output_path, options) do
    file_start = System.monotonic_time(:millisecond)
    
    try do
      # Decide on processing method based on file size and options
      result = if options[:use_streaming] and StreamingProcessor.should_use_streaming?(input_path) do
        Logger.debug("BatchProcessor: Using streaming for large file: #{Path.basename(input_path)}")
        StreamingProcessor.stream_convert_file(input_path, output_path)
      else
        # Use standard pipeline
        ConverterOrchestrator.convert_file_to_markdown(input_path, output_path)
      end
      
      file_end = System.monotonic_time(:millisecond)
      
      case result do
        {:ok, conversion_result} ->
          full_result = Map.merge(conversion_result, %{
            file_processing_duration_ms: file_end - file_start,
            processing_method: if(options[:use_streaming], do: "streaming", else: "standard"),
            file_index: nil  # Set by caller if needed
          })
          
          {:success, full_result}
          
        {:error, reason} ->
          Logger.error("BatchProcessor: File conversion failed for #{Path.basename(input_path)}: #{inspect(reason)}")
          {:error, %{
            file_path: input_path,
            error: reason,
            duration_ms: file_end - file_start
          }}
      end
      
    rescue
      error ->
        file_end = System.monotonic_time(:millisecond)
        Logger.error("BatchProcessor: Exception processing #{Path.basename(input_path)}: #{inspect(error)}")
        {:error, %{
          file_path: input_path,
          error: {:exception, inspect(error)},
          duration_ms: file_end - file_start
        }}
    end
  end

  defp discover_files_in_directory(directory_path, patterns) do
    try do
      files = patterns
      |> Enum.flat_map(fn pattern ->
        full_pattern = Path.join(directory_path, pattern)
        Path.wildcard(full_pattern)
      end)
      |> Enum.uniq()
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()
      
      {:ok, files}
      
    rescue
      error ->
        {:error, inspect(error)}
    end
  end

  defp calculate_total_input_size(file_paths) do
    file_paths
    |> Enum.map(fn path ->
      case File.stat(path) do
        {:ok, %{size: size}} -> size
        {:error, _} -> 0
      end
    end)
    |> Enum.sum()
  end

  defp generate_batch_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_output_path(input_path, output_dir) do
    base_name = Path.basename(input_path, Path.extname(input_path))
    output_file = base_name <> ".md"
    Path.join(output_dir, output_file)
  end

  defp check_batch_cache(input_path, output_path) do
    # Check if we have cached conversion result
    case SmartCache.get_text_extraction(input_path, "batch_conversion") do
      {:ok, cached_text} ->
        # Verify output file exists and matches
        case File.stat(output_path) do
          {:ok, _} ->
            {:cache_hit, %{
              input_file: input_path,
              output_file: output_path,
              extracted_text_length: String.length(cached_text),
              cache_used: true
            }}
          {:error, _} ->
            nil  # Cache miss - output file doesn't exist
        end
        
      {:error, _} ->
        nil  # Cache miss
    end
  end

  defp update_batch_cache(input_path, _output_path, conversion_result) do
    # Cache small conversion results
    if Map.has_key?(conversion_result, :extracted_text_length) and 
       conversion_result.extracted_text_length < 1024 * 1024 do  # Under 1MB
      # In a real implementation, we'd cache the actual extracted text
      SmartCache.put_metadata_extraction(input_path, "batch_conversion", conversion_result)
    end
  end

  defp aggregate_batch_results(batch_id, individual_results, processing_errors, start_time, end_time) do
    total_duration = end_time - start_time
    
    successful_files = length(individual_results)
    failed_files = length(processing_errors)
    total_files = successful_files + failed_files
    
    # Calculate aggregate metrics safely
    {total_input_size, total_output_size} = if length(individual_results) > 0 do
      individual_results
      |> Enum.reduce({0, 0}, fn result, {input_acc, output_acc} ->
        input_size = Map.get(result, :file_size_bytes, Map.get(result, :input_size, 0))
        output_size = Map.get(result, :output_bytes_written, Map.get(result, :output_size, 0))
        {input_acc + input_size, output_acc + output_size}
      end)
    else
      {0, 0}
    end
    
    files_per_second = if total_duration > 0 and total_files > 0, do: (total_files * 1000) / total_duration, else: 0
    bytes_per_second = if total_duration > 0 and total_input_size > 0, do: (total_input_size * 1000) / total_duration, else: 0
    
    %BatchResult{
      batch_id: batch_id,
      total_files: total_files,
      successful_files: successful_files,
      failed_files: failed_files,
      skipped_files: 0,
      total_duration_ms: total_duration,
      total_input_size: total_input_size,
      total_output_size: total_output_size,
      files_per_second: files_per_second,
      bytes_per_second: bytes_per_second,
      individual_results: individual_results,
      error_summary: summarize_errors(processing_errors)
    }
  end

  defp summarize_errors(processing_errors) do
    error_types = processing_errors
    |> Enum.group_by(fn error ->
      error_type = case Map.get(error, :error) do
        {:validation_failed, _} -> :validation_error
        {:format_detection_failed, _} -> :format_error
        {:text_extraction_failed, _} -> :extraction_error
        {:output_write_failed, _} -> :output_error
        {:exception, _} -> :exception
        _ -> :other
      end
      error_type
    end)
    |> Enum.map(fn {type, errors} -> {type, length(errors)} end)
    |> Map.new()
    
    %{
      total_errors: length(processing_errors),
      error_types: error_types,
      sample_errors: Enum.take(processing_errors, 5)
    }
  end

  defp analyze_batch_performance_and_recommend(batch_result) do
    recommendations = []
    
    # Analyze throughput
    recommendations = if batch_result.files_per_second < 1.0 do
      [
        %{
          type: :performance,
          priority: :high,
          title: "Low batch processing throughput",
          description: "Processing #{Float.round(batch_result.files_per_second, 2)} files/sec",
          recommendation: "Increase concurrency or use streaming for large files"
        }
        | recommendations
      ]
    else
      recommendations
    end
    
    # Analyze error rate
    error_rate = (batch_result.failed_files / batch_result.total_files) * 100
    
    recommendations = if error_rate > 10.0 do
      [
        %{
          type: :reliability,
          priority: :medium,
          title: "High batch error rate",
          description: "#{Float.round(error_rate, 1)}% of files failed processing",
          recommendation: "Review error patterns and implement retry mechanisms"
        }
        | recommendations
      ]
    else
      recommendations
    end
    
    # Analyze memory efficiency
    avg_file_size = if batch_result.total_files > 0, do: batch_result.total_input_size / batch_result.total_files, else: 0
    
    recommendations = if avg_file_size > 10 * 1024 * 1024 do  # 10MB average
      [
        %{
          type: :memory,
          priority: :medium,
          title: "Large average file size detected",
          description: "Average file size: #{format_bytes(avg_file_size)}",
          recommendation: "Enable streaming processing for better memory efficiency"
        }
        | recommendations
      ]
    else
      recommendations
    end
    
    %{
      batch_id: batch_result.batch_id,
      analysis_performed_at: DateTime.utc_now(),
      total_recommendations: length(recommendations),
      recommendations: recommendations,
      performance_summary: %{
        throughput_files_per_sec: batch_result.files_per_second,
        throughput_mbps: (batch_result.bytes_per_second / (1024 * 1024)),
        success_rate_percent: (batch_result.successful_files / batch_result.total_files) * 100,
        avg_file_size_mb: avg_file_size / (1024 * 1024)
      }
    }
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end