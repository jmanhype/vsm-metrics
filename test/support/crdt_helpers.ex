defmodule VSMMetrics.Test.CRDTHelpers do
  @moduledoc """
  Helper functions for CRDT testing in VSM Metrics.
  """

  @doc """
  Creates a G-Counter with specified number of operations from different nodes.
  """
  def create_gcounter(num_ops) do
    nodes = ["node1", "node2", "node3"]
    
    Enum.reduce(1..num_ops, VSMMetrics.CRDT.GCounter.new(), fn i, counter ->
      node = Enum.at(nodes, rem(i, 3))
      VSMMetrics.CRDT.GCounter.increment(counter, node, 1)
    end)
  end

  @doc """
  Creates a G-Set with specified number of elements.
  """
  def create_gset(num_elements) do
    Enum.reduce(1..num_elements, VSMMetrics.CRDT.GSet.new(), fn i, set ->
      VSMMetrics.CRDT.GSet.add(set, "element_#{i}")
    end)
  end

  @doc """
  Creates an LWW-Register with history of updates.
  """
  def create_lww_register(updates) do
    Enum.reduce(updates, VSMMetrics.CRDT.LWWRegister.new(), fn {value, timestamp, node}, reg ->
      VSMMetrics.CRDT.LWWRegister.set(reg, value, timestamp, node)
    end)
  end

  @doc """
  Simulates concurrent CRDT operations from multiple nodes.
  """
  def simulate_concurrent_ops(crdt_type, num_nodes, ops_per_node) do
    tasks = for node_id <- 1..num_nodes do
      Task.async(fn ->
        crdt = create_crdt(crdt_type, "node_#{node_id}")
        
        Enum.reduce(1..ops_per_node, crdt, fn _, acc ->
          perform_random_op(crdt_type, acc, "node_#{node_id}")
        end)
      end)
    end
    
    crdts = Task.await_many(tasks)
    
    # Merge all CRDTs
    Enum.reduce(crdts, fn crdt, acc ->
      merge_crdt(crdt_type, acc, crdt)
    end)
  end

  defp create_crdt(:gcounter, node_id), do: VSMMetrics.CRDT.GCounter.new(node_id)
  defp create_crdt(:gset, _node_id), do: VSMMetrics.CRDT.GSet.new()
  defp create_crdt(:lww_register, node_id), do: VSMMetrics.CRDT.LWWRegister.new(node_id)

  defp perform_random_op(:gcounter, crdt, node_id) do
    VSMMetrics.CRDT.GCounter.increment(crdt, node_id, :rand.uniform(10))
  end

  defp perform_random_op(:gset, crdt, _node_id) do
    VSMMetrics.CRDT.GSet.add(crdt, "item_#{:rand.uniform(1000)}")
  end

  defp perform_random_op(:lww_register, crdt, node_id) do
    timestamp = System.monotonic_time(:microsecond)
    value = "value_#{:rand.uniform(100)}"
    VSMMetrics.CRDT.LWWRegister.set(crdt, value, timestamp, node_id)
  end

  defp merge_crdt(:gcounter, crdt1, crdt2), do: VSMMetrics.CRDT.GCounter.merge(crdt1, crdt2)
  defp merge_crdt(:gset, crdt1, crdt2), do: VSMMetrics.CRDT.GSet.merge(crdt1, crdt2)
  defp merge_crdt(:lww_register, crdt1, crdt2), do: VSMMetrics.CRDT.LWWRegister.merge(crdt1, crdt2)

  @doc """
  Verifies CRDT convergence by comparing multiple merge orders.
  """
  def verify_convergence(crdts) do
    # Try different merge orders
    result1 = merge_in_order(crdts)
    result2 = merge_in_reverse(crdts)
    result3 = merge_pairwise(crdts)
    
    # All should converge to same state
    result1 == result2 and result2 == result3
  end

  defp merge_in_order([first | rest]) do
    Enum.reduce(rest, first, &merge_crdt(:gcounter, &2, &1))
  end

  defp merge_in_reverse(crdts) do
    [first | rest] = Enum.reverse(crdts)
    Enum.reduce(rest, first, &merge_crdt(:gcounter, &2, &1))
  end

  defp merge_pairwise([single]), do: single
  defp merge_pairwise(crdts) do
    pairs = Enum.chunk_every(crdts, 2)
    merged = Enum.map(pairs, fn
      [a, b] -> merge_crdt(:gcounter, a, b)
      [a] -> a
    end)
    merge_pairwise(merged)
  end
end