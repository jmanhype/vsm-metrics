defmodule VsmMetrics.Storage.DETSTier do
  @moduledoc """
  DETS-based cold storage tier for historical data with millisecond access.
  Implements compression and time-based partitioning.
  """

  use GenServer
  require Logger

  @partition_interval :timer.hours(24)  # Daily partitions
  @compression_level 6  # zlib compression level

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(key, value, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:put, key, value, metadata})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def query(start_time, end_time, filters \\ %{}) do
    GenServer.call(__MODULE__, {:query, start_time, end_time, filters}, 30_000)
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    data_dir = Keyword.get(opts, :data_dir, "./data/dets")
    File.mkdir_p!(data_dir)
    
    state = %{
      data_dir: data_dir,
      current_partition: nil,
      partitions: %{},
      partition_interval: Keyword.get(opts, :partition_interval, @partition_interval),
      compression_level: Keyword.get(opts, :compression_level, @compression_level)
    }
    
    # Open current partition
    state = ensure_current_partition(state)
    
    # Schedule partition rotation
    :timer.send_interval(state.partition_interval, :rotate_partition)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:put, key, value, metadata}, _from, state) do
    timestamp = System.system_time(:second)
    compressed_value = :zlib.compress(:erlang.term_to_binary(value))
    
    partition = state.current_partition
    :dets.insert(partition, {key, compressed_value, metadata, timestamp})
    
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    result = search_all_partitions(state, key)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    Enum.each(state.partitions, fn {_date, partition} ->
      :dets.delete(partition, key)
    end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:query, start_time, end_time, filters}, _from, state) do
    results = query_partitions(state, start_time, end_time, filters)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      partitions: map_size(state.partitions),
      total_size: calculate_total_size(state),
      compression_ratio: estimate_compression_ratio(state)
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:rotate_partition, state) do
    {:noreply, ensure_current_partition(state)}
  end

  # Private Functions

  defp ensure_current_partition(state) do
    today = Date.utc_today()
    partition_name = partition_name(today, state.data_dir)
    
    if state.current_partition != partition_name do
      # Open new partition
      {:ok, table} = :dets.open_file(partition_name, [type: :set])
      
      # Update state
      %{state | 
        current_partition: table,
        partitions: Map.put(state.partitions, today, table)
      }
    else
      state
    end
  end

  defp partition_name(date, data_dir) do
    Path.join(data_dir, "vsm_metrics_#{Date.to_iso8601(date)}.dets")
    |> String.to_atom()
  end

  defp search_all_partitions(state, key) do
    # Search from newest to oldest partition
    state.partitions
    |> Enum.sort_by(fn {date, _} -> date end, :desc)
    |> Enum.find_value({:error, :not_found}, fn {_date, partition} ->
      case :dets.lookup(partition, key) do
        [{^key, compressed_value, metadata, timestamp}] ->
          value = :zlib.uncompress(compressed_value) |> :erlang.binary_to_term()
          {:ok, value, metadata, timestamp}
        [] ->
          false
      end
    end)
  end

  defp query_partitions(state, start_time, end_time, filters) do
    # Determine which partitions to query
    relevant_partitions = get_relevant_partitions(state, start_time, end_time)
    
    # Query each partition in parallel
    tasks = Enum.map(relevant_partitions, fn partition ->
      Task.async(fn ->
        query_partition(partition, start_time, end_time, filters)
      end)
    end)
    
    # Collect results
    tasks
    |> Task.await_many(30_000)
    |> Enum.flat_map(& &1)
    |> Enum.sort_by(fn {_k, _v, _m, ts} -> ts end, :desc)
  end

  defp get_relevant_partitions(state, start_time, end_time) do
    start_date = DateTime.from_unix!(start_time) |> DateTime.to_date()
    end_date = DateTime.from_unix!(end_time) |> DateTime.to_date()
    
    state.partitions
    |> Enum.filter(fn {date, _partition} ->
      Date.compare(date, start_date) != :lt and
      Date.compare(date, end_date) != :gt
    end)
    |> Enum.map(fn {_date, partition} -> partition end)
  end

  defp query_partition(partition, start_time, end_time, filters) do
    # Build match spec for efficient querying
    match_spec = build_match_spec(start_time, end_time, filters)
    
    :dets.select(partition, match_spec)
    |> Enum.map(fn {key, compressed_value, metadata, timestamp} ->
      value = :zlib.uncompress(compressed_value) |> :erlang.binary_to_term()
      {key, value, metadata, timestamp}
    end)
  end

  defp build_match_spec(start_time, end_time, _filters) do
    [
      {{:"$1", :"$2", :"$3", :"$4"},
       [{:">=", :"$4", start_time}, {:"=<", :"$4", end_time}],
       [{{:"$1", :"$2", :"$3", :"$4"}}]}
    ]
  end

  defp calculate_total_size(state) do
    state.partitions
    |> Enum.map(fn {_date, partition} ->
      {:ok, info} = :dets.info(partition)
      Keyword.get(info, :file_size, 0)
    end)
    |> Enum.sum()
  end

  defp estimate_compression_ratio(_state) do
    # In production, track original vs compressed sizes
    0.3  # Assume 70% compression
  end
end