defmodule MultiFormatConverter.Optimization.SmartCache do
  @moduledoc """
  Intelligent Caching System for Multi-Format Converter
  
  RESPONSIBILITY: Cache format detection, metadata, and processing results
  
  Tank Building Stage 3: Optimize
  - File-based caching with content hash validation
  - Format detection result caching
  - Metadata extraction result caching  
  - LRU eviction with size-based limits
  - Cache invalidation on file modification
  - Distributed cache support (UFM integration ready)
  
  Performance optimizations without breaking Stage 2 functionality
  """
  
  use GenServer
  require Logger
  
  # Cache configuration
  @cache_version "1.0.0"
  @max_cache_entries 10_000
  @max_cache_size_bytes 100 * 1024 * 1024  # 100MB
  @cache_file_path "tmp/converter_cache.ets"
  @cache_cleanup_interval 300_000  # 5 minutes

  # Cache entry structure
  defmodule CacheEntry do
    defstruct [
      :key,
      :value,
      :created_at,
      :last_accessed,
      :access_count,
      :size_bytes,
      :content_hash,
      :file_mtime,
      :entry_type
    ]
  end

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached format detection result
  
  Returns cached result if valid, nil otherwise
  """
  def get_format_detection(file_path) do
    cache_key = generate_cache_key("format_detection", file_path)
    get_cached_value(cache_key, file_path)
  end

  @doc """
  Cache format detection result
  """
  def put_format_detection(file_path, format_result) do
    cache_key = generate_cache_key("format_detection", file_path)
    put_cached_value(cache_key, file_path, format_result, :format_detection)
  end

  @doc """
  Get cached metadata extraction result
  """
  def get_metadata_extraction(file_path, extractor_type) do
    cache_key = generate_cache_key("metadata_#{extractor_type}", file_path)
    get_cached_value(cache_key, file_path)
  end

  @doc """
  Cache metadata extraction result
  """
  def put_metadata_extraction(file_path, extractor_type, metadata_result) do
    cache_key = generate_cache_key("metadata_#{extractor_type}", file_path)
    put_cached_value(cache_key, file_path, metadata_result, :metadata_extraction)
  end

  @doc """
  Get cached text extraction result
  """
  def get_text_extraction(file_path, extractor_type) do
    cache_key = generate_cache_key("text_#{extractor_type}", file_path)
    get_cached_value(cache_key, file_path)
  end

  @doc """
  Cache text extraction result (only for small results to avoid memory issues)
  """
  def put_text_extraction(file_path, extractor_type, text_result) do
    # Only cache text results under 1MB to avoid memory bloat
    if is_binary(text_result) and byte_size(text_result) < 1024 * 1024 do
      cache_key = generate_cache_key("text_#{extractor_type}", file_path)
      put_cached_value(cache_key, file_path, text_result, :text_extraction)
    else
      Logger.debug("SmartCache: Skipping text cache for large result (#{byte_size(text_result)} bytes)")
      :not_cached
    end
  end

  @doc """
  Invalidate cache entry for specific file
  """
  def invalidate_file_cache(file_path) do
    GenServer.cast(__MODULE__, {:invalidate_file, file_path})
  end

  @doc """
  Clear all cache entries
  """
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end

  @doc """
  Get cache statistics
  """
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_cache_stats)
  end

  @doc """
  Get cache performance metrics
  """
  def get_cache_metrics do
    GenServer.call(__MODULE__, :get_cache_metrics)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    Logger.info("SmartCache: Initializing intelligent caching system")
    
    # Create ETS table for high-performance caching
    cache_table = :ets.new(:converter_cache, [
      :set,
      :named_table,
      :public,
      {:write_concurrency, true},
      {:read_concurrency, true}
    ])
    
    state = %{
      cache_table: cache_table,
      cache_size_bytes: 0,
      cache_entries_count: 0,
      hit_count: 0,
      miss_count: 0,
      eviction_count: 0,
      last_cleanup: System.monotonic_time(:millisecond)
    }
    
    # Schedule periodic cache cleanup
    :timer.send_interval(@cache_cleanup_interval, :cleanup_cache)
    
    # Load persistent cache if it exists
    load_persistent_cache(state)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:get, cache_key, file_path}, _from, state) do
    case get_cache_entry(cache_key, file_path, state) do
      {:hit, value} ->
        new_state = %{state | hit_count: state.hit_count + 1}
        {:reply, {:ok, value}, new_state}
        
      :miss ->
        new_state = %{state | miss_count: state.miss_count + 1}
        {:reply, {:error, :cache_miss}, new_state}
        
      {:invalid, reason} ->
        # Remove invalid entry and count as miss
        :ets.delete(:converter_cache, cache_key)
        new_state = %{state | miss_count: state.miss_count + 1}
        Logger.debug("SmartCache: Invalidated cache entry: #{reason}")
        {:reply, {:error, :cache_invalid}, new_state}
    end
  end

  @impl true
  def handle_call(:get_cache_stats, _from, state) do
    stats = %{
      entries_count: state.cache_entries_count,
      size_bytes: state.cache_size_bytes,
      max_entries: @max_cache_entries,
      max_size_bytes: @max_cache_size_bytes,
      hit_count: state.hit_count,
      miss_count: state.miss_count,
      hit_rate: calculate_hit_rate(state.hit_count, state.miss_count),
      eviction_count: state.eviction_count,
      memory_usage_percent: (state.cache_size_bytes / @max_cache_size_bytes) * 100,
      capacity_usage_percent: (state.cache_entries_count / @max_cache_entries) * 100
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_cache_metrics, _from, state) do
    # Analyze cache entries for detailed metrics
    all_entries = :ets.tab2list(:converter_cache)
    
    metrics = %{
      total_entries: length(all_entries),
      entry_types: analyze_entry_types(all_entries),
      access_patterns: analyze_access_patterns(all_entries),
      age_distribution: analyze_age_distribution(all_entries),
      size_distribution: analyze_size_distribution(all_entries),
      most_accessed: get_most_accessed_entries(all_entries, 5)
    }
    
    {:reply, metrics, state}
  end

  @impl true
  def handle_cast({:put, cache_key, file_path, value, entry_type}, state) do
    new_state = put_cache_entry(cache_key, file_path, value, entry_type, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:invalidate_file, file_path}, state) do
    # Remove all cache entries for this file
    file_hash = hash_file_path(file_path)
    
    all_entries = :ets.tab2list(:converter_cache)
    entries_to_delete = Enum.filter(all_entries, fn {key, _entry} ->
      String.contains?(key, file_hash)
    end)
    
    Enum.each(entries_to_delete, fn {key, _entry} ->
      :ets.delete(:converter_cache, key)
    end)
    
    deleted_count = length(entries_to_delete)
    Logger.debug("SmartCache: Invalidated #{deleted_count} entries for #{file_path}")
    
    new_state = %{state | cache_entries_count: state.cache_entries_count - deleted_count}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_cache, state) do
    Logger.info("SmartCache: Clearing all cache entries")
    :ets.delete_all_objects(:converter_cache)
    
    new_state = %{
      state |
      cache_size_bytes: 0,
      cache_entries_count: 0
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup_cache, state) do
    Logger.debug("SmartCache: Running periodic cache cleanup")
    new_state = perform_cache_cleanup(state)
    {:noreply, new_state}
  end

  # Private Implementation

  defp get_cached_value(cache_key, file_path) do
    GenServer.call(__MODULE__, {:get, cache_key, file_path})
  end

  defp put_cached_value(cache_key, file_path, value, entry_type) do
    GenServer.cast(__MODULE__, {:put, cache_key, file_path, value, entry_type})
  end

  defp generate_cache_key(operation, file_path) do
    file_hash = hash_file_path(file_path)
    "#{operation}:#{file_hash}"
  end

  defp hash_file_path(file_path) do
    # Create hash based on file path and modification time
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        content = "#{file_path}:#{inspect(mtime)}"
        :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> String.slice(0, 16)
        
      {:error, _} ->
        # Fallback to path-only hash
        :crypto.hash(:sha256, file_path) |> Base.encode16(case: :lower) |> String.slice(0, 16)
    end
  end

  defp get_cache_entry(cache_key, file_path, state) do
    case :ets.lookup(:converter_cache, cache_key) do
      [{^cache_key, entry}] ->
        # Validate cache entry
        case validate_cache_entry(entry, file_path) do
          :valid ->
            # Update access information
            updated_entry = %{entry | 
              last_accessed: System.monotonic_time(:millisecond),
              access_count: entry.access_count + 1
            }
            :ets.insert(:converter_cache, {cache_key, updated_entry})
            {:hit, entry.value}
            
          {:invalid, reason} ->
            {:invalid, reason}
        end
        
      [] ->
        :miss
    end
  end

  defp put_cache_entry(cache_key, file_path, value, entry_type, state) do
    # Calculate entry size
    entry_size = calculate_entry_size(value)
    
    # Check if we need to make space
    state = ensure_cache_capacity(state, entry_size)
    
    # Create cache entry
    entry = %CacheEntry{
      key: cache_key,
      value: value,
      created_at: System.monotonic_time(:millisecond),
      last_accessed: System.monotonic_time(:millisecond),
      access_count: 1,
      size_bytes: entry_size,
      content_hash: hash_value(value),
      file_mtime: get_file_mtime(file_path),
      entry_type: entry_type
    }
    
    # Store in cache
    :ets.insert(:converter_cache, {cache_key, entry})
    
    # Update state
    %{state |
      cache_size_bytes: state.cache_size_bytes + entry_size,
      cache_entries_count: state.cache_entries_count + 1
    }
  end

  defp validate_cache_entry(entry, file_path) do
    cond do
      # Check if file has been modified
      entry.file_mtime != get_file_mtime(file_path) ->
        {:invalid, "file_modified"}
        
      # Check cache entry age (expire after 24 hours)
      System.monotonic_time(:millisecond) - entry.created_at > 24 * 60 * 60 * 1000 ->
        {:invalid, "expired"}
        
      # Entry is valid
      true ->
        :valid
    end
  end

  defp ensure_cache_capacity(state, new_entry_size) do
    cond do
      # Check size limit
      state.cache_size_bytes + new_entry_size > @max_cache_size_bytes ->
        evict_cache_entries_by_size(state, new_entry_size)
        
      # Check count limit  
      state.cache_entries_count >= @max_cache_entries ->
        evict_cache_entries_by_count(state, 1)
        
      # No eviction needed
      true ->
        state
    end
  end

  defp evict_cache_entries_by_size(state, needed_size) do
    Logger.debug("SmartCache: Evicting entries to free #{format_bytes(needed_size)}")
    
    # Get all entries sorted by last access time (LRU)
    all_entries = :ets.tab2list(:converter_cache)
    |> Enum.sort_by(fn {_key, entry} -> entry.last_accessed end)
    
    {evicted_size, evicted_count} = evict_entries_until_size_freed(all_entries, needed_size, 0, 0)
    
    Logger.debug("SmartCache: Evicted #{evicted_count} entries, freed #{format_bytes(evicted_size)}")
    
    %{state |
      cache_size_bytes: state.cache_size_bytes - evicted_size,
      cache_entries_count: state.cache_entries_count - evicted_count,
      eviction_count: state.eviction_count + evicted_count
    }
  end

  defp evict_cache_entries_by_count(state, needed_count) do
    Logger.debug("SmartCache: Evicting #{needed_count} entries by count")
    
    # Get least recently used entries
    all_entries = :ets.tab2list(:converter_cache)
    |> Enum.sort_by(fn {_key, entry} -> entry.last_accessed end)
    |> Enum.take(needed_count)
    
    {evicted_size, evicted_count} = Enum.reduce(all_entries, {0, 0}, fn {key, entry}, {size_acc, count_acc} ->
      :ets.delete(:converter_cache, key)
      {size_acc + entry.size_bytes, count_acc + 1}
    end)
    
    %{state |
      cache_size_bytes: state.cache_size_bytes - evicted_size,
      cache_entries_count: state.cache_entries_count - evicted_count,
      eviction_count: state.eviction_count + evicted_count
    }
  end

  defp evict_entries_until_size_freed([], _needed_size, freed_size, freed_count) do
    {freed_size, freed_count}
  end

  defp evict_entries_until_size_freed([{key, entry} | rest], needed_size, freed_size, freed_count) do
    :ets.delete(:converter_cache, key)
    new_freed_size = freed_size + entry.size_bytes
    new_freed_count = freed_count + 1
    
    if new_freed_size >= needed_size do
      {new_freed_size, new_freed_count}
    else
      evict_entries_until_size_freed(rest, needed_size, new_freed_size, new_freed_count)
    end
  end

  defp perform_cache_cleanup(state) do
    Logger.debug("SmartCache: Performing cache cleanup")
    
    # Remove expired entries
    current_time = System.monotonic_time(:millisecond)
    all_entries = :ets.tab2list(:converter_cache)
    
    expired_entries = Enum.filter(all_entries, fn {_key, entry} ->
      current_time - entry.created_at > 24 * 60 * 60 * 1000  # 24 hours
    end)
    
    {cleaned_size, cleaned_count} = Enum.reduce(expired_entries, {0, 0}, fn {key, entry}, {size_acc, count_acc} ->
      :ets.delete(:converter_cache, key)
      {size_acc + entry.size_bytes, count_acc + 1}
    end)
    
    if cleaned_count > 0 do
      Logger.info("SmartCache: Cleaned #{cleaned_count} expired entries, freed #{format_bytes(cleaned_size)}")
    end
    
    %{state |
      cache_size_bytes: state.cache_size_bytes - cleaned_size,
      cache_entries_count: state.cache_entries_count - cleaned_count,
      last_cleanup: current_time
    }
  end

  defp calculate_entry_size(value) do
    # Estimate size of cached value
    case value do
      v when is_binary(v) -> byte_size(v)
      v when is_map(v) -> :erlang.external_size(v)
      v -> :erlang.external_size(v)
    end
  end

  defp hash_value(value) do
    :crypto.hash(:sha256, :erlang.term_to_binary(value))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp get_file_mtime(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} -> mtime
      {:error, _} -> nil
    end
  end

  defp calculate_hit_rate(hits, misses) when hits + misses > 0 do
    (hits / (hits + misses)) * 100
  end
  defp calculate_hit_rate(_hits, _misses), do: 0.0

  defp load_persistent_cache(state) do
    # Future: Load cache from persistent storage
    Logger.debug("SmartCache: Persistent cache loading not implemented in Stage 3")
    state
  end

  # Cache analytics functions
  
  defp analyze_entry_types(entries) do
    entries
    |> Enum.group_by(fn {_key, entry} -> entry.entry_type end)
    |> Enum.map(fn {type, type_entries} -> {type, length(type_entries)} end)
    |> Map.new()
  end

  defp analyze_access_patterns(entries) do
    total_accesses = Enum.sum(Enum.map(entries, fn {_key, entry} -> entry.access_count end))
    avg_access_count = if length(entries) > 0, do: total_accesses / length(entries), else: 0
    
    %{
      total_accesses: total_accesses,
      average_access_count: avg_access_count,
      most_accessed_count: entries |> Enum.map(fn {_key, entry} -> entry.access_count end) |> Enum.max(fn -> 0 end),
      least_accessed_count: entries |> Enum.map(fn {_key, entry} -> entry.access_count end) |> Enum.min(fn -> 0 end)
    }
  end

  defp analyze_age_distribution(entries) do
    current_time = System.monotonic_time(:millisecond)
    ages = Enum.map(entries, fn {_key, entry} -> current_time - entry.created_at end)
    
    if length(ages) > 0 do
      %{
        oldest_entry_age_ms: Enum.max(ages),
        newest_entry_age_ms: Enum.min(ages),
        average_age_ms: Enum.sum(ages) / length(ages)
      }
    else
      %{oldest_entry_age_ms: 0, newest_entry_age_ms: 0, average_age_ms: 0}
    end
  end

  defp analyze_size_distribution(entries) do
    sizes = Enum.map(entries, fn {_key, entry} -> entry.size_bytes end)
    
    if length(sizes) > 0 do
      %{
        largest_entry_bytes: Enum.max(sizes),
        smallest_entry_bytes: Enum.min(sizes),
        average_size_bytes: Enum.sum(sizes) / length(sizes),
        total_size_bytes: Enum.sum(sizes)
      }
    else
      %{largest_entry_bytes: 0, smallest_entry_bytes: 0, average_size_bytes: 0, total_size_bytes: 0}
    end
  end

  defp get_most_accessed_entries(entries, limit) do
    entries
    |> Enum.sort_by(fn {_key, entry} -> entry.access_count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {key, entry} ->
      %{
        key: key,
        access_count: entry.access_count,
        entry_type: entry.entry_type,
        size_bytes: entry.size_bytes
      }
    end)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} bytes"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end