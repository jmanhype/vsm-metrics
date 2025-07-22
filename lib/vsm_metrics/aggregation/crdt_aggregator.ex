defmodule VsmMetrics.Aggregation.CRDTAggregator do
  @moduledoc """
  CRDT-based aggregation for distributed VSM metrics.
  Implements G-Counter, G-Set, and LWW-Register for different metric types.
  """

  use GenServer
  require Logger

  alias VsmMetrics.Aggregation.{GCounter, GSet, LWWRegister}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Increment a counter metric (uses G-Counter CRDT)
  """
  def increment_counter(metric_name, value \\ 1, node_id \\ node()) do
    GenServer.call(__MODULE__, {:increment_counter, metric_name, value, node_id})
  end

  @doc """
  Add an element to a set metric (uses G-Set CRDT)
  """
  def add_to_set(metric_name, element, node_id \\ node()) do
    GenServer.call(__MODULE__, {:add_to_set, metric_name, element, node_id})
  end

  @doc """
  Update a register metric (uses LWW-Register CRDT)
  """
  def update_register(metric_name, value, node_id \\ node()) do
    GenServer.call(__MODULE__, {:update_register, metric_name, value, node_id})
  end

  @doc """
  Get the current value of a metric
  """
  def get_value(metric_name) do
    GenServer.call(__MODULE__, {:get_value, metric_name})
  end

  @doc """
  Merge state from another node
  """
  def merge_state(remote_state) do
    GenServer.call(__MODULE__, {:merge_state, remote_state})
  end

  @doc """
  Get the full CRDT state for synchronization
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, node())
    
    state = %{
      node_id: node_id,
      counters: %{},
      sets: %{},
      registers: %{},
      last_sync: System.monotonic_time(:millisecond)
    }
    
    # Setup periodic sync if clustering is enabled
    if Keyword.get(opts, :enable_sync, true) do
      :timer.send_interval(5_000, :sync_with_peers)
    end
    
    {:ok, state}
  end

  @impl true
  def handle_call({:increment_counter, metric_name, value, node_id}, _from, state) do
    counter = Map.get(state.counters, metric_name, GCounter.new())
    updated_counter = GCounter.increment(counter, node_id, value)
    
    new_state = %{state | counters: Map.put(state.counters, metric_name, updated_counter)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:add_to_set, metric_name, element, node_id}, _from, state) do
    set = Map.get(state.sets, metric_name, GSet.new())
    updated_set = GSet.add(set, element, node_id)
    
    new_state = %{state | sets: Map.put(state.sets, metric_name, updated_set)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update_register, metric_name, value, node_id}, _from, state) do
    register = Map.get(state.registers, metric_name, LWWRegister.new())
    updated_register = LWWRegister.update(register, value, node_id)
    
    new_state = %{state | registers: Map.put(state.registers, metric_name, updated_register)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_value, metric_name}, _from, state) do
    value = cond do
      Map.has_key?(state.counters, metric_name) ->
        GCounter.value(state.counters[metric_name])
        
      Map.has_key?(state.sets, metric_name) ->
        GSet.value(state.sets[metric_name])
        
      Map.has_key?(state.registers, metric_name) ->
        LWWRegister.value(state.registers[metric_name])
        
      true ->
        {:error, :not_found}
    end
    
    {:reply, value, state}
  end

  @impl true
  def handle_call({:merge_state, remote_state}, _from, state) do
    merged_state = merge_all_crdts(state, remote_state)
    {:reply, :ok, merged_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    crdt_state = %{
      counters: state.counters,
      sets: state.sets,
      registers: state.registers
    }
    {:reply, crdt_state, state}
  end

  @impl true
  def handle_info(:sync_with_peers, state) do
    # Sync with other nodes in the cluster
    peers = Node.list()
    
    if length(peers) > 0 do
      local_state = %{
        counters: state.counters,
        sets: state.sets,
        registers: state.registers
      }
      
      # Send our state to all peers and collect their states
      peer_states = peers
      |> Enum.map(&sync_with_peer(&1, local_state))
      |> Enum.filter(&(&1 != :error))
      
      # Merge all peer states
      merged_state = Enum.reduce(peer_states, state, &merge_all_crdts/2)
      
      {:noreply, %{merged_state | last_sync: System.monotonic_time(:millisecond)}}
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp sync_with_peer(peer_node, local_state) do
    try do
      :rpc.call(peer_node, __MODULE__, :merge_and_return_state, [local_state], 5_000)
    catch
      _, _ -> :error
    end
  end

  def merge_and_return_state(remote_state) do
    :ok = merge_state(remote_state)
    get_state()
  end

  defp merge_all_crdts(state1, state2) do
    %{
      state1 |
      counters: merge_crdt_maps(state1.counters, state2.counters, &GCounter.merge/2),
      sets: merge_crdt_maps(state1.sets, state2.sets, &GSet.merge/2),
      registers: merge_crdt_maps(state1.registers, state2.registers, &LWWRegister.merge/2)
    }
  end

  defp merge_crdt_maps(map1, map2, merge_fn) do
    Map.merge(map1, map2, fn _key, v1, v2 ->
      merge_fn.(v1, v2)
    end)
  end
end

# G-Counter CRDT Implementation
defmodule VsmMetrics.Aggregation.GCounter do
  @moduledoc """
  Grow-only counter CRDT. Can only increment, never decrement.
  """

  def new, do: %{}

  def increment(counter, node_id, value \\ 1) do
    Map.update(counter, node_id, value, &(&1 + value))
  end

  def value(counter) do
    Map.values(counter) |> Enum.sum()
  end

  def merge(counter1, counter2) do
    Map.merge(counter1, counter2, fn _node, v1, v2 -> max(v1, v2) end)
  end
end

# G-Set CRDT Implementation
defmodule VsmMetrics.Aggregation.GSet do
  @moduledoc """
  Grow-only set CRDT. Can only add elements, never remove.
  """

  def new, do: MapSet.new()

  def add(set, element, _node_id) do
    MapSet.put(set, element)
  end

  def value(set), do: MapSet.to_list(set)

  def merge(set1, set2) do
    MapSet.union(set1, set2)
  end
end

# LWW-Register CRDT Implementation
defmodule VsmMetrics.Aggregation.LWWRegister do
  @moduledoc """
  Last-Write-Wins Register CRDT. Latest timestamp wins on conflict.
  """

  def new, do: {nil, 0, nil}

  def update(register, value, node_id) do
    timestamp = System.monotonic_time(:microsecond)
    {value, timestamp, node_id}
  end

  def value({value, _timestamp, _node}), do: value

  def merge({v1, t1, n1} = reg1, {v2, t2, n2} = reg2) do
    cond do
      t1 > t2 -> reg1
      t2 > t1 -> reg2
      # Same timestamp, use node ID as tiebreaker
      n1 > n2 -> reg1
      true -> reg2
    end
  end
end