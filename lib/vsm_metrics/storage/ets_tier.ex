defmodule VsmMetrics.Storage.ETSTier do
  @moduledoc """
  ETS-based warm storage tier for recent data with microsecond access.
  Implements time-based eviction and automatic archival to cold tier.
  """

  use GenServer
  require Logger

  @table_name :vsm_ets_tier
  @max_age_seconds 3600  # 1 hour
  @cleanup_interval 60_000  # 1 minute

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(key, value, metadata \\ %{}) do
    timestamp = System.system_time(:second)
    :ets.insert(@table_name, {key, value, metadata, timestamp})
    :ok
  end

  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, metadata, timestamp}] ->
        if expired?(timestamp) do
          :ets.delete(@table_name, key)
          {:error, :expired}
        else
          {:ok, value, metadata}
        end
      [] ->
        {:error, :not_found}
    end
  end

  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])
    
    max_age = Keyword.get(opts, :max_age_seconds, @max_age_seconds)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)
    
    # Schedule periodic cleanup
    :timer.send_interval(cleanup_interval, :cleanup)
    
    state = %{
      max_age: max_age,
      cleanup_interval: cleanup_interval
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table_name, :size)
    memory = :ets.info(@table_name, :memory)
    
    stats = %{
      size: size,
      memory_bytes: memory * :erlang.system_info(:wordsize),
      max_age_seconds: state.max_age
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired(state.max_age)
    {:noreply, state}
  end

  # Private Functions

  defp expired?(timestamp) do
    current_time = System.system_time(:second)
    current_time - timestamp > @max_age_seconds
  end

  defp cleanup_expired(max_age) do
    current_time = System.system_time(:second)
    cutoff_time = current_time - max_age
    
    # Find expired entries
    expired = :ets.select(@table_name, [
      {{:"$1", :"$2", :"$3", :"$4"},
       [{:"<", :"$4", cutoff_time}],
       [{{:"$1", :"$2", :"$3"}}]}
    ])
    
    # Archive to cold tier before deletion
    Enum.each(expired, fn {key, value, metadata} ->
      VsmMetrics.Storage.DETSTier.put(key, value, metadata)
      :ets.delete(@table_name, key)
    end)
    
    Logger.debug("Cleaned up #{length(expired)} expired entries from ETS tier")
  end
end