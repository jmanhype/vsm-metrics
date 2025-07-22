defmodule VSMMetrics.Test.StorageHelpers do
  @moduledoc """
  Helper functions for testing multi-tier storage in VSM Metrics.
  """

  @doc """
  Sets up a test storage environment with all three tiers.
  """
  def setup_storage_tiers do
    # Start storage processes
    {:ok, memory_pid} = VSMMetrics.Storage.Memory.start_link(name: :test_memory)
    {:ok, ets_pid} = VSMMetrics.Storage.ETS.start_link(name: :test_ets)
    {:ok, dets_pid} = VSMMetrics.Storage.DETS.start_link(
      name: :test_dets,
      file: 'test_metrics.dets'
    )
    
    # Start tier coordinator
    {:ok, coordinator} = VSMMetrics.Storage.Coordinator.start_link(
      memory: memory_pid,
      ets: ets_pid,
      dets: dets_pid,
      migration_interval: 100  # Fast migration for tests
    )
    
    %{
      memory: memory_pid,
      ets: ets_pid,
      dets: dets_pid,
      coordinator: coordinator
    }
  end

  @doc """
  Generates test metrics with specified access patterns.
  """
  def generate_test_metrics(count, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, :uniform)
    base_time = Keyword.get(opts, :base_time, System.monotonic_time(:microsecond))
    
    for i <- 1..count do
      %{
        id: "metric_#{i}",
        value: generate_value(i, pattern),
        timestamp: base_time - (i * 1000),  # 1ms apart
        tags: generate_tags(i),
        access_count: 0,
        last_accessed: nil
      }
    end
  end

  defp generate_value(i, :uniform), do: :rand.uniform() * 100
  defp generate_value(i, :sequential), do: i * 1.0
  defp generate_value(i, :gaussian) do
    # Box-Muller transform for Gaussian distribution
    u1 = :rand.uniform()
    u2 = :rand.uniform()
    z0 = :math.sqrt(-2 * :math.log(u1)) * :math.cos(2 * :math.pi() * u2)
    50 + z0 * 15  # mean=50, std=15
  end

  defp generate_tags(i) do
    base_tags = ["metric", "test"]
    
    cond do
      rem(i, 10) == 0 -> base_tags ++ ["important"]
      rem(i, 5) == 0 -> base_tags ++ ["frequent"]
      true -> base_tags
    end
  end

  @doc """
  Simulates access patterns to trigger tier migrations.
  """
  def simulate_access_pattern(coordinator, pattern) do
    case pattern do
      :hot_cold ->
        # 10% of metrics get 90% of accesses (hot)
        for _ <- 1..1000 do
          if :rand.uniform() < 0.9 do
            # Access hot metrics (1-100)
            id = "metric_#{:rand.uniform(100)}"
            VSMMetrics.Storage.Coordinator.get(coordinator, id)
          else
            # Access cold metrics (101-1000)
            id = "metric_#{100 + :rand.uniform(900)}"
            VSMMetrics.Storage.Coordinator.get(coordinator, id)
          end
        end
        
      :time_decay ->
        # Recent metrics accessed more frequently
        for _ <- 1..1000 do
          # Exponential decay probability
          x = :rand.uniform()
          i = round(-:math.log(x) * 100) + 1
          i = min(i, 1000)
          
          id = "metric_#{i}"
          VSMMetrics.Storage.Coordinator.get(coordinator, id)
        end
        
      :uniform ->
        # All metrics accessed equally
        for _ <- 1..1000 do
          id = "metric_#{:rand.uniform(1000)}"
          VSMMetrics.Storage.Coordinator.get(coordinator, id)
        end
    end
  end

  @doc """
  Verifies metrics are in expected storage tiers.
  """
  def verify_tier_distribution(coordinator, expectations) do
    Enum.all?(expectations, fn {metric_id, expected_tier} ->
      actual_tier = VSMMetrics.Storage.Coordinator.get_tier(coordinator, metric_id)
      actual_tier == expected_tier
    end)
  end

  @doc """
  Measures storage operation latencies.
  """
  def benchmark_storage_ops(storage_mod, num_ops) do
    # Warmup
    for i <- 1..100 do
      storage_mod.put("warmup_#{i}", %{value: i})
    end
    
    # Write benchmarks
    write_times = for i <- 1..num_ops do
      metric = %{value: i, timestamp: System.monotonic_time()}
      
      {time, _} = :timer.tc(fn ->
        storage_mod.put("bench_#{i}", metric)
      end)
      
      time
    end
    
    # Read benchmarks
    read_times = for i <- 1..num_ops do
      key = "bench_#{:rand.uniform(num_ops)}"
      
      {time, _} = :timer.tc(fn ->
        storage_mod.get(key)
      end)
      
      time
    end
    
    %{
      write: calculate_stats(write_times),
      read: calculate_stats(read_times)
    }
  end

  defp calculate_stats(times) do
    sorted = Enum.sort(times)
    count = length(sorted)
    
    %{
      min: List.first(sorted),
      max: List.last(sorted),
      mean: Enum.sum(sorted) / count,
      median: Enum.at(sorted, div(count, 2)),
      p95: Enum.at(sorted, round(count * 0.95)),
      p99: Enum.at(sorted, round(count * 0.99))
    }
  end

  @doc """
  Tests storage tier migration logic.
  """
  def test_migration_logic(coordinator) do
    # Insert metric in memory
    metric = %{
      id: "test_migration",
      value: 42,
      timestamp: System.monotonic_time(),
      access_count: 10,
      last_accessed: System.monotonic_time()
    }
    
    VSMMetrics.Storage.Coordinator.put(coordinator, metric.id, metric, :memory)
    
    # Verify in memory
    assert VSMMetrics.Storage.Coordinator.get_tier(coordinator, metric.id) == :memory
    
    # Don't access for a while to cool down
    :timer.sleep(200)
    
    # Trigger migration check
    VSMMetrics.Storage.Coordinator.check_migrations(coordinator)
    
    # Should have moved to ETS
    assert VSMMetrics.Storage.Coordinator.get_tier(coordinator, metric.id) == :ets
    
    # Don't access for longer
    :timer.sleep(500)
    
    # Trigger migration again
    VSMMetrics.Storage.Coordinator.check_migrations(coordinator)
    
    # Should have moved to DETS
    assert VSMMetrics.Storage.Coordinator.get_tier(coordinator, metric.id) == :dets
    
    # Access it again (heat up)
    VSMMetrics.Storage.Coordinator.get(coordinator, metric.id)
    VSMMetrics.Storage.Coordinator.get(coordinator, metric.id)
    
    # Should promote back to memory
    :timer.sleep(100)
    VSMMetrics.Storage.Coordinator.check_migrations(coordinator)
    
    assert VSMMetrics.Storage.Coordinator.get_tier(coordinator, metric.id) == :memory
  end
end