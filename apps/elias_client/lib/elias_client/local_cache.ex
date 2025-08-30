defmodule EliasClient.LocalCache do
  @moduledoc """
  Local Cache Service for ELIAS Client
  
  Provides local caching for package information, server responses, and client data
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("💾 LocalCache: Starting client-side caching")
    
    # Initialize ETS tables for different cache types
    package_cache = :ets.new(:package_cache, [:set, :public, :named_table])
    server_cache = :ets.new(:server_response_cache, [:set, :public, :named_table])
    config_cache = :ets.new(:config_cache, [:set, :public, :named_table])
    
    # Start cache cleanup timer
    schedule_cache_cleanup()
    
    {:ok, %{
      package_cache: package_cache,
      server_cache: server_cache,
      config_cache: config_cache,
      cache_stats: %{
        hits: 0,
        misses: 0,
        evictions: 0,
        total_entries: 0
      },
      cache_config: load_cache_config()
    }}
  end

  # Public API

  @doc "Cache package information"
  def cache_package_info(ecosystem, package_name, version, package_info) do
    GenServer.call(__MODULE__, {:cache_package, ecosystem, package_name, version, package_info})
  end

  @doc "Get cached package information"
  def get_cached_package_info(ecosystem, package_name, version) do
    GenServer.call(__MODULE__, {:get_package, ecosystem, package_name, version})
  end

  @doc "Cache server response"
  def cache_server_response(server_node, request_key, response) do
    GenServer.call(__MODULE__, {:cache_response, server_node, request_key, response})
  end

  @doc "Get cached server response"
  def get_cached_server_response(server_node, request_key) do
    GenServer.call(__MODULE__, {:get_response, server_node, request_key})
  end

  @doc "Cache configuration data"
  def cache_config(config_key, config_data) do
    GenServer.call(__MODULE__, {:cache_config, config_key, config_data})
  end

  @doc "Get cached configuration"
  def get_cached_config(config_key) do
    GenServer.call(__MODULE__, {:get_config, config_key})
  end

  @doc "Clear all caches"
  def clear_all_caches do
    GenServer.cast(__MODULE__, :clear_all)
  end

  @doc "Get cache statistics"
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Implementation

  def handle_call({:cache_package, ecosystem, package_name, version, package_info}, _from, state) do
    cache_key = {ecosystem, package_name, version}
    cache_entry = %{
      data: package_info,
      cached_at: DateTime.utc_now(),
      ttl_seconds: state.cache_config.package_cache_ttl
    }
    
    :ets.insert(state.package_cache, {cache_key, cache_entry})
    
    updated_stats = %{state.cache_stats | total_entries: state.cache_stats.total_entries + 1}
    new_state = %{state | cache_stats: updated_stats}
    
    {:reply, :ok, new_state}
  end

  def handle_call({:get_package, ecosystem, package_name, version}, _from, state) do
    cache_key = {ecosystem, package_name, version}
    
    case :ets.lookup(state.package_cache, cache_key) do
      [{^cache_key, cache_entry}] ->
        if cache_entry_valid?(cache_entry) do
          updated_stats = %{state.cache_stats | hits: state.cache_stats.hits + 1}
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:hit, cache_entry.data}, new_state}
        else
          # Cache entry expired
          :ets.delete(state.package_cache, cache_key)
          updated_stats = %{state.cache_stats | 
            misses: state.cache_stats.misses + 1,
            evictions: state.cache_stats.evictions + 1
          }
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:miss, :expired}, new_state}
        end
        
      [] ->
        updated_stats = %{state.cache_stats | misses: state.cache_stats.misses + 1}
        new_state = %{state | cache_stats: updated_stats}
        {:reply, {:miss, :not_found}, new_state}
    end
  end

  def handle_call({:cache_response, server_node, request_key, response}, _from, state) do
    cache_key = {server_node, request_key}
    cache_entry = %{
      data: response,
      cached_at: DateTime.utc_now(),
      ttl_seconds: state.cache_config.server_response_ttl
    }
    
    :ets.insert(state.server_cache, {cache_key, cache_entry})
    
    {:reply, :ok, state}
  end

  def handle_call({:get_response, server_node, request_key}, _from, state) do
    cache_key = {server_node, request_key}
    
    case :ets.lookup(state.server_cache, cache_key) do
      [{^cache_key, cache_entry}] ->
        if cache_entry_valid?(cache_entry) do
          updated_stats = %{state.cache_stats | hits: state.cache_stats.hits + 1}
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:hit, cache_entry.data}, new_state}
        else
          :ets.delete(state.server_cache, cache_key)
          updated_stats = %{state.cache_stats | misses: state.cache_stats.misses + 1}
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:miss, :expired}, new_state}
        end
        
      [] ->
        updated_stats = %{state.cache_stats | misses: state.cache_stats.misses + 1}
        new_state = %{state | cache_stats: updated_stats}
        {:reply, {:miss, :not_found}, new_state}
    end
  end

  def handle_call({:cache_config, config_key, config_data}, _from, state) do
    cache_entry = %{
      data: config_data,
      cached_at: DateTime.utc_now(),
      ttl_seconds: state.cache_config.config_cache_ttl
    }
    
    :ets.insert(state.config_cache, {config_key, cache_entry})
    
    {:reply, :ok, state}
  end

  def handle_call({:get_config, config_key}, _from, state) do
    case :ets.lookup(state.config_cache, config_key) do
      [{^config_key, cache_entry}] ->
        if cache_entry_valid?(cache_entry) do
          updated_stats = %{state.cache_stats | hits: state.cache_stats.hits + 1}
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:hit, cache_entry.data}, new_state}
        else
          :ets.delete(state.config_cache, config_key)
          updated_stats = %{state.cache_stats | misses: state.cache_stats.misses + 1}
          new_state = %{state | cache_stats: updated_stats}
          {:reply, {:miss, :expired}, new_state}
        end
        
      [] ->
        updated_stats = %{state.cache_stats | misses: state.cache_stats.misses + 1}
        new_state = %{state | cache_stats: updated_stats}
        {:reply, {:miss, :not_found}, new_state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    enhanced_stats = Map.merge(state.cache_stats, %{
      package_cache_size: :ets.info(state.package_cache, :size),
      server_cache_size: :ets.info(state.server_cache, :size),
      config_cache_size: :ets.info(state.config_cache, :size),
      hit_rate: calculate_hit_rate(state.cache_stats),
      last_updated: DateTime.utc_now()
    })
    
    {:reply, enhanced_stats, state}
  end

  def handle_cast(:clear_all, state) do
    :ets.delete_all_objects(state.package_cache)
    :ets.delete_all_objects(state.server_cache)
    :ets.delete_all_objects(state.config_cache)
    
    Logger.info("LocalCache: Cleared all caches")
    
    new_stats = %{state.cache_stats | 
      evictions: state.cache_stats.evictions + state.cache_stats.total_entries,
      total_entries: 0
    }
    
    {:noreply, %{state | cache_stats: new_stats}}
  end

  def handle_info(:cleanup_expired_entries, state) do
    Logger.debug("LocalCache: Cleaning up expired cache entries")
    
    eviction_count = cleanup_expired_entries(state.package_cache) +
                    cleanup_expired_entries(state.server_cache) +
                    cleanup_expired_entries(state.config_cache)
    
    if eviction_count > 0 do
      Logger.info("LocalCache: Evicted #{eviction_count} expired entries")
    end
    
    updated_stats = %{state.cache_stats | evictions: state.cache_stats.evictions + eviction_count}
    new_state = %{state | cache_stats: updated_stats}
    
    # Schedule next cleanup
    schedule_cache_cleanup()
    
    {:noreply, new_state}
  end

  # Private Functions

  defp cache_entry_valid?(cache_entry) do
    age_seconds = DateTime.diff(DateTime.utc_now(), cache_entry.cached_at, :second)
    age_seconds < cache_entry.ttl_seconds
  end

  defp cleanup_expired_entries(cache_table) do
    now = DateTime.utc_now()
    
    expired_keys = :ets.foldl(fn {key, cache_entry}, acc ->
      age_seconds = DateTime.diff(now, cache_entry.cached_at, :second)
      if age_seconds >= cache_entry.ttl_seconds do
        [key | acc]
      else
        acc
      end
    end, [], cache_table)
    
    Enum.each(expired_keys, fn key ->
      :ets.delete(cache_table, key)
    end)
    
    length(expired_keys)
  end

  defp calculate_hit_rate(stats) do
    total_requests = stats.hits + stats.misses
    if total_requests > 0 do
      (stats.hits / total_requests) * 100
    else
      0.0
    end
  end

  defp schedule_cache_cleanup do
    # Clean up expired entries every 5 minutes
    Process.send_after(self(), :cleanup_expired_entries, 300_000)
  end

  defp load_cache_config do
    %{
      package_cache_ttl: 3600, # 1 hour
      server_response_ttl: 300, # 5 minutes
      config_cache_ttl: 1800,  # 30 minutes
      max_entries_per_cache: 1000,
      cleanup_interval: 300_000 # 5 minutes
    }
  end
end