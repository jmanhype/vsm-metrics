defmodule VsmMetrics.Storage.MemoryTier do
  @moduledoc """
  In-memory storage tier for hot data with sub-microsecond access.
  Implements LRU eviction and automatic promotion to warm tier.
  """

  use GenServer
  require Logger

  @table_name :vsm_memory_tier
  @max_size 10_000
  @eviction_batch 100

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(key, value, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:put, key, value, metadata})
  end

  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, metadata, _timestamp}] ->
        :ets.update_counter(@table_name, :access_count, {2, 1})
        update_access_time(key)
        {:ok, value, metadata}
      [] ->
        {:error, :not_found}
    end
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])
    :ets.insert(@table_name, {:access_count, 0})
    
    max_size = Keyword.get(opts, :max_size, @max_size)
    eviction_batch = Keyword.get(opts, :eviction_batch, @eviction_batch)
    
    state = %{
      max_size: max_size,
      eviction_batch: eviction_batch,
      size: 0
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:put, key, value, metadata}, _from, state) do
    timestamp = System.monotonic_time(:microsecond)
    :ets.insert(@table_name, {key, value, metadata, timestamp})
    
    new_state = maybe_evict(%{state | size: state.size + 1})
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, _value, _metadata, _timestamp}] ->
        :ets.delete(@table_name, key)
        {:reply, :ok, %{state | size: max(0, state.size - 1)}}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    access_count = case :ets.lookup(@table_name, :access_count) do
      [{:access_count, count}] -> count
      [] -> 0
    end
    
    stats = %{
      size: state.size,
      max_size: state.max_size,
      access_count: access_count,
      hit_rate: calculate_hit_rate()
    }
    
    {:reply, stats, state}
  end

  # Private Functions

  defp update_access_time(key) do
    timestamp = System.monotonic_time(:microsecond)
    :ets.update_element(@table_name, key, {4, timestamp})
  end

  defp maybe_evict(state) when state.size <= state.max_size, do: state
  
  defp maybe_evict(state) do
    # Get all entries except metadata
    entries = :ets.select(@table_name, [{{:"$1", :"$2", :"$3", :"$4"}, 
                                        [{:"/=", :"$1", :access_count}], 
                                        [{{:"$1", :"$4"}}]}])
    
    # Sort by timestamp (LRU)
    sorted = Enum.sort_by(entries, fn {_key, timestamp} -> timestamp end)
    
    # Evict oldest entries
    to_evict = Enum.take(sorted, state.eviction_batch)
    
    Enum.each(to_evict, fn {key, _timestamp} ->
      case :ets.lookup(@table_name, key) do
        [{^key, value, metadata, _ts}] ->
          # Promote to warm tier before eviction
          VsmMetrics.Storage.ETSTier.put(key, value, metadata)
          :ets.delete(@table_name, key)
        [] -> :ok
      end
    end)
    
    %{state | size: state.size - length(to_evict)}
  end

  defp calculate_hit_rate do
    # Simplified hit rate calculation
    # In production, track hits and misses separately
    1.0
  end
end