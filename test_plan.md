# VSM Metrics Comprehensive Test Strategy

## 1. Unit Test Strategy

### 1.1 Storage Tiers Testing

#### Memory Storage Tests
```elixir
defmodule VSMMetrics.Storage.MemoryTest do
  use ExUnit.Case, async: true
  
  describe "memory storage operations" do
    test "stores metrics with microsecond precision" do
      # Test that memory storage preserves microsecond timestamps
      metric = %{
        timestamp: System.monotonic_time(:microsecond),
        value: 42.5,
        tags: [:hot, :critical]
      }
      
      assert {:ok, _} = MemoryStorage.put("metric_1", metric)
      assert {:ok, retrieved} = MemoryStorage.get("metric_1")
      assert retrieved.timestamp == metric.timestamp
    end
    
    test "handles concurrent writes without loss" do
      # Spawn 1000 concurrent processes writing different metrics
      tasks = for i <- 1..1000 do
        Task.async(fn ->
          MemoryStorage.put("metric_#{i}", %{value: i})
        end)
      end
      
      results = Task.await_many(tasks)
      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert MemoryStorage.count() == 1000
    end
    
    test "enforces memory limits with LRU eviction" do
      # Configure 100MB limit
      MemoryStorage.configure(max_size: 100_000_000)
      
      # Write until limit exceeded
      # Verify oldest entries are evicted first
    end
  end
end
```

#### ETS Storage Tests
```elixir
defmodule VSMMetrics.Storage.ETSTest do
  use ExUnit.Case
  
  describe "ETS storage tier" do
    test "automatic migration from memory tier" do
      # Test that hot metrics automatically migrate to ETS
      # when they cool down (no access for 1 minute)
    end
    
    test "ordered set operations for time-series queries" do
      # Insert 10,000 metrics with timestamps
      # Query by time range and verify ordering
    end
    
    test "concurrent read/write performance" do
      # Benchmark concurrent operations
      # Assert < 10μs read latency
    end
  end
end
```

#### DETS Storage Tests
```elixir
defmodule VSMMetrics.Storage.DETSTest do
  use ExUnit.Case
  
  describe "DETS persistent storage" do
    test "survives process crashes" do
      # Write metrics to DETS
      # Kill process
      # Restart and verify data integrity
    end
    
    test "automatic archival from ETS" do
      # Test cold data migration after 1 hour
    end
    
    test "file-based backup and restore" do
      # Test backup to external file
      # Test restore from backup
    end
  end
end
```

### 1.2 CRDT Operations Testing

```elixir
defmodule VSMMetrics.CRDT.CounterTest do
  use ExUnit.Case
  
  describe "G-Counter CRDT" do
    test "increment operations are commutative" do
      counter1 = GCounter.new("node1")
      counter2 = GCounter.new("node2")
      
      # Different order of operations
      c1 = counter1 |> GCounter.inc(5) |> GCounter.inc(3)
      c2 = counter2 |> GCounter.inc(3) |> GCounter.inc(5)
      
      # Merge should be identical regardless of order
      merged1 = GCounter.merge(c1, c2)
      merged2 = GCounter.merge(c2, c1)
      
      assert GCounter.value(merged1) == GCounter.value(merged2)
    end
    
    test "handles concurrent increments correctly" do
      # Simulate 3 nodes incrementing concurrently
      nodes = for i <- 1..3, do: GCounter.new("node#{i}")
      
      # Each node increments independently
      updated = Enum.map(nodes, &GCounter.inc(&1, :rand.uniform(10)))
      
      # Merge all states
      final = Enum.reduce(updated, &GCounter.merge/2)
      
      # Verify sum equals total of all increments
    end
  end
end

defmodule VSMMetrics.CRDT.GSetTest do
  use ExUnit.Case
  
  describe "G-Set CRDT for metric tags" do
    test "add-only set convergence" do
      set1 = GSet.new() |> GSet.add("tag1") |> GSet.add("tag2")
      set2 = GSet.new() |> GSet.add("tag2") |> GSet.add("tag3")
      
      merged = GSet.merge(set1, set2)
      
      assert GSet.members(merged) == MapSet.new(["tag1", "tag2", "tag3"])
    end
  end
end

defmodule VSMMetrics.CRDT.LWWRegisterTest do
  use ExUnit.Case
  
  describe "Last-Write-Wins Register" do
    test "newer timestamp always wins" do
      reg1 = LWWRegister.new()
      reg2 = LWWRegister.new()
      
      # Different timestamps
      reg1 = LWWRegister.set(reg1, "value1", 1000)
      reg2 = LWWRegister.set(reg2, "value2", 2000)
      
      merged = LWWRegister.merge(reg1, reg2)
      assert LWWRegister.get(merged) == "value2"
    end
    
    test "tie-breaking with node ID" do
      # Same timestamp, different nodes
      reg1 = LWWRegister.set(LWWRegister.new("node1"), "value1", 1000)
      reg2 = LWWRegister.set(LWWRegister.new("node2"), "value2", 1000)
      
      # Higher node ID wins in tie
      merged = LWWRegister.merge(reg1, reg2)
      assert LWWRegister.get(merged) == "value2"
    end
  end
end
```

### 1.3 Metric Calculations Accuracy

```elixir
defmodule VSMMetrics.CalculationsTest do
  use ExUnit.Case
  use PropCheck
  
  describe "statistical calculations" do
    test "percentile calculation accuracy" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      
      assert Metrics.percentile(data, 50) == 5.5
      assert Metrics.percentile(data, 90) == 9.0
      assert Metrics.percentile(data, 99) == 9.9
    end
    
    test "handles edge cases correctly" do
      assert Metrics.percentile([], 50) == nil
      assert Metrics.percentile([42], 50) == 42
    end
    
    test "moving average calculation" do
      window = [1, 2, 3, 4, 5]
      assert Metrics.moving_average(window, 3) == [2.0, 3.0, 4.0]
    end
  end
  
  describe "rate calculations" do
    test "calculates rate per second correctly" do
      # 100 events in 10 seconds = 10/sec
      counter = 100
      duration = 10_000_000 # microseconds
      
      assert Metrics.rate_per_second(counter, duration) == 10.0
    end
    
    test "handles sub-second durations" do
      # 5 events in 500ms = 10/sec
      assert Metrics.rate_per_second(5, 500_000) == 10.0
    end
  end
end
```

### 1.4 Entropy Computation Testing

```elixir
defmodule VSMMetrics.EntropyTest do
  use ExUnit.Case
  use PropCheck
  
  describe "Shannon entropy calculation" do
    test "entropy of uniform distribution" do
      # Uniform distribution has maximum entropy
      uniform = List.duplicate(1/8, 8)
      assert_in_delta Entropy.shannon(uniform), 3.0, 0.001
    end
    
    test "entropy of certain event" do
      # Single certain event has zero entropy
      certain = [1.0]
      assert Entropy.shannon(certain) == 0.0
    end
    
    test "entropy bounds" do
      # Entropy is between 0 and log(n)
      distribution = [0.1, 0.2, 0.3, 0.4]
      entropy = Entropy.shannon(distribution)
      
      assert entropy >= 0
      assert entropy <= :math.log2(4)
    end
  end
  
  describe "variety entropy measurement" do
    test "calculates variety absorption correctly" do
      input_states = 16  # 4 bits of variety
      output_states = 4  # 2 bits of variety
      
      absorbed = Entropy.variety_absorbed(input_states, output_states)
      assert absorbed == 2.0  # 2 bits absorbed
    end
    
    test "handles edge cases" do
      # No variety absorbed when output = input
      assert Entropy.variety_absorbed(8, 8) == 0.0
      
      # Maximum absorption when output = 1
      assert Entropy.variety_absorbed(8, 1) == 3.0
    end
  end
end
```

### 1.5 Time Constant Functions

```elixir
defmodule VSMMetrics.TimeConstantTest do
  use ExUnit.Case
  
  describe "time-constant operations" do
    test "query operations complete in O(1)" do
      # Insert 1M metrics
      for i <- 1..1_000_000 do
        Metrics.insert("metric_#{i}", i)
      end
      
      # Measure query time - should be constant
      times = for _ <- 1..100 do
        {time, _} = :timer.tc(fn ->
          Metrics.get("metric_500000")
        end)
        time
      end
      
      # Verify standard deviation is low (constant time)
      assert Statistics.stdev(times) < 100  # microseconds
    end
    
    test "aggregation uses pre-computed values" do
      # Pre-computed aggregates should return instantly
      {time, result} = :timer.tc(fn ->
        Metrics.get_aggregate(:sum, :last_hour)
      end)
      
      assert time < 1000  # Less than 1ms
      assert is_number(result)
    end
  end
end
```

## 2. Property-Based Testing

### 2.1 CRDT Convergence Properties

```elixir
defmodule VSMMetrics.Properties.CRDTTest do
  use ExUnit.Case
  use PropCheck
  
  property "CRDTs always converge to same state" do
    forall {ops1, ops2} <- {list(crdt_operation()), list(crdt_operation())} do
      # Apply operations in different orders
      state1 = apply_operations(new_crdt(), ops1 ++ ops2)
      state2 = apply_operations(new_crdt(), ops2 ++ ops1)
      
      # States should be identical
      state1 == state2
    end
  end
  
  property "merge is commutative" do
    forall {crdt1, crdt2} <- {crdt(), crdt()} do
      merge(crdt1, crdt2) == merge(crdt2, crdt1)
    end
  end
  
  property "merge is associative" do
    forall {a, b, c} <- {crdt(), crdt(), crdt()} do
      merge(merge(a, b), c) == merge(a, merge(b, c))
    end
  end
  
  property "merge is idempotent" do
    forall crdt <- crdt() do
      merge(crdt, crdt) == crdt
    end
  end
  
  # Generators
  def crdt_operation do
    oneof([
      {:increment, pos_integer()},
      {:add_tag, binary()},
      {:set_value, number(), pos_integer()}  # value, timestamp
    ])
  end
end
```

### 2.2 Entropy Bounds Properties

```elixir
defmodule VSMMetrics.Properties.EntropyTest do
  use PropCheck
  
  property "entropy is always non-negative" do
    forall distribution <- probability_distribution() do
      Entropy.shannon(distribution) >= 0
    end
  end
  
  property "entropy bounded by log(n)" do
    forall distribution <- probability_distribution() do
      n = length(distribution)
      Entropy.shannon(distribution) <= :math.log2(n)
    end
  end
  
  property "maximum entropy for uniform distribution" do
    forall n <- integer(2, 100) do
      uniform = List.duplicate(1/n, n)
      abs(Entropy.shannon(uniform) - :math.log2(n)) < 0.0001
    end
  end
  
  def probability_distribution do
    let values <- non_empty(list(pos_integer())) do
      sum = Enum.sum(values)
      Enum.map(values, &(&1 / sum))
    end
  end
end
```

### 2.3 Variety Engineering Invariants

```elixir
defmodule VSMMetrics.Properties.VarietyTest do
  use PropCheck
  
  property "requisite variety law holds" do
    forall {disturbance, regulator} <- {variety(), variety()} do
      # System variety >= disturbance variety - regulator variety
      system_variety = calculate_system_variety(disturbance, regulator)
      system_variety >= max(0, disturbance - regulator)
    end
  end
  
  property "variety amplification bounded" do
    forall {input, amplification} <- {variety(), float(1.0, 10.0)} do
      output = amplify_variety(input, amplification)
      # Cannot create variety from nothing
      output <= input * amplification
    end
  end
  
  property "variety attenuation monotonic" do
    forall {input, attenuation} <- {variety(), float(0.0, 1.0)} do
      output = attenuate_variety(input, attenuation)
      output <= input
    end
  end
  
  def variety do
    # Variety in bits
    let bits <- integer(0, 16) do
      :math.pow(2, bits)
    end
  end
end
```

## 3. Integration Tests

### 3.1 Multi-Tier Storage Coordination

```elixir
defmodule VSMMetrics.Integration.StorageTest do
  use ExUnit.Case
  
  describe "storage tier coordination" do
    test "automatic tier migration based on access patterns" do
      # Insert 10K metrics
      metrics = for i <- 1..10_000 do
        %{id: "metric_#{i}", value: i, timestamp: now() - i}
      end
      
      Enum.each(metrics, &Metrics.insert/1)
      
      # Access first 100 frequently (hot)
      for _ <- 1..100 do
        for i <- 1..100 do
          Metrics.get("metric_#{i}")
        end
      end
      
      # Wait for migration
      :timer.sleep(2000)
      
      # Verify hot metrics in memory
      assert Storage.tier_for("metric_1") == :memory
      assert Storage.tier_for("metric_50") == :memory
      
      # Verify warm metrics in ETS
      assert Storage.tier_for("metric_500") == :ets
      
      # Verify cold metrics in DETS
      assert Storage.tier_for("metric_9000") == :dets
    end
    
    test "transparent access across tiers" do
      # Insert metrics in different tiers
      Metrics.insert_to_tier(:memory, "hot_metric", %{value: 1})
      Metrics.insert_to_tier(:ets, "warm_metric", %{value: 2})
      Metrics.insert_to_tier(:dets, "cold_metric", %{value: 3})
      
      # Access should be transparent
      assert {:ok, %{value: 1}} = Metrics.get("hot_metric")
      assert {:ok, %{value: 2}} = Metrics.get("warm_metric")
      assert {:ok, %{value: 3}} = Metrics.get("cold_metric")
    end
  end
end
```

### 3.2 Distributed Aggregation

```elixir
defmodule VSMMetrics.Integration.DistributedTest do
  use ExUnit.Case
  
  describe "distributed aggregation" do
    setup do
      # Start 3 nodes
      nodes = for i <- 1..3 do
        {:ok, node} = LocalCluster.start_node("node#{i}")
        node
      end
      
      on_exit(fn ->
        Enum.each(nodes, &LocalCluster.stop_node/1)
      end)
      
      {:ok, nodes: nodes}
    end
    
    test "aggregates metrics across nodes", %{nodes: nodes} do
      # Each node generates metrics
      tasks = Enum.map(nodes, fn node ->
        Task.async(fn ->
          :rpc.call(node, Metrics, :generate_load, [1000])
        end)
      end)
      
      Task.await_many(tasks)
      
      # Query aggregate from any node
      total = :rpc.call(hd(nodes), Metrics, :distributed_sum, [])
      
      # Should sum all 3000 metrics
      assert total == 3000
    end
    
    test "handles node failures during aggregation", %{nodes: [n1, n2, n3]} do
      # Generate metrics on all nodes
      :rpc.call(n1, Metrics, :generate_load, [1000])
      :rpc.call(n2, Metrics, :generate_load, [1000])
      :rpc.call(n3, Metrics, :generate_load, [1000])
      
      # Kill one node
      LocalCluster.stop_node(n3)
      
      # Aggregation should still work with partial data
      total = :rpc.call(n1, Metrics, :distributed_sum, [])
      assert total == 2000
    end
    
    test "CRDT-based aggregation convergence", %{nodes: nodes} do
      # Each node maintains CRDT counter
      Enum.each(nodes, fn node ->
        :rpc.call(node, Metrics, :init_crdt_counter, [])
      end)
      
      # Concurrent increments
      tasks = Enum.map(nodes, fn node ->
        Task.async(fn ->
          for _ <- 1..100 do
            :rpc.call(node, Metrics, :increment_counter, [1])
          end
        end)
      end)
      
      Task.await_many(tasks)
      
      # Sync CRDTs
      :rpc.call(hd(nodes), Metrics, :sync_all_nodes, [])
      
      # All nodes should converge to same value
      values = Enum.map(nodes, fn node ->
        :rpc.call(node, Metrics, :get_counter_value, [])
      end)
      
      assert Enum.all?(values, &(&1 == 300))
    end
  end
end
```

### 3.3 Cross-Subsystem Communication

```elixir
defmodule VSMMetrics.Integration.SubsystemTest do
  use ExUnit.Case
  
  describe "VSM subsystem integration" do
    setup do
      # Start VSM subsystems
      {:ok, _} = System1.start_link()
      {:ok, _} = System2.start_link()
      {:ok, _} = System3.start_link()
      {:ok, _} = MetricsCollector.start_link()
      
      :ok
    end
    
    test "metrics flow from S1 -> S2 -> S3" do
      # Generate load in System 1
      System1.process_transactions(100)
      
      # Wait for propagation
      :timer.sleep(1000)
      
      # Verify metrics collected at each level
      s1_metrics = MetricsCollector.get_metrics(:system1)
      assert s1_metrics.transactions_processed == 100
      
      s2_metrics = MetricsCollector.get_metrics(:system2)
      assert s2_metrics.coordination_events > 0
      
      s3_metrics = MetricsCollector.get_metrics(:system3)
      assert s3_metrics.adaptations_made > 0
    end
    
    test "variety absorption tracking" do
      # Inject variety into System 1
      System1.inject_variety(entropy: 4.0)  # 16 states
      
      # Process through VSM
      :timer.sleep(2000)
      
      # Measure variety at each level
      v1 = MetricsCollector.get_variety(:system1)
      v2 = MetricsCollector.get_variety(:system2)
      v3 = MetricsCollector.get_variety(:system3)
      
      # Variety should decrease up the hierarchy
      assert v1 > v2
      assert v2 > v3
      
      # Total absorption should match
      absorbed = (v1 - v3)
      recorded = MetricsCollector.get_total_variety_absorbed()
      assert_in_delta absorbed, recorded, 0.1
    end
  end
end
```

## 4. Performance Benchmarks

### 4.1 Storage Tier Latencies

```elixir
defmodule VSMMetrics.Benchmark.StorageTest do
  use Benchfella
  
  @metric %{value: 42, timestamp: System.monotonic_time()}
  
  setup_all do
    {:ok, _} = Application.ensure_all_started(:vsm_metrics)
    
    # Pre-populate storage
    for i <- 1..10_000 do
      MemoryStorage.put("mem_#{i}", @metric)
      ETSStorage.put("ets_#{i}", @metric) 
      DETSStorage.put("dets_#{i}", @metric)
    end
  end
  
  bench "memory storage write" do
    MemoryStorage.put("bench_mem", @metric)
  end
  
  bench "memory storage read" do
    MemoryStorage.get("mem_5000")
  end
  
  bench "ETS storage write" do
    ETSStorage.put("bench_ets", @metric)
  end
  
  bench "ETS storage read" do
    ETSStorage.get("ets_5000")
  end
  
  bench "DETS storage write" do
    DETSStorage.put("bench_dets", @metric)
  end
  
  bench "DETS storage read" do
    DETSStorage.get("dets_5000")
  end
  
  # Expected results:
  # Memory: < 1μs read, < 2μs write
  # ETS: < 5μs read, < 10μs write  
  # DETS: < 100μs read, < 200μs write
end
```

### 4.2 CRDT Merge Operations

```elixir
defmodule VSMMetrics.Benchmark.CRDTTest do
  use Benchfella
  
  setup_all do
    # Create CRDTs with various sizes
    @small_crdt = create_counter(10)
    @medium_crdt = create_counter(1_000)
    @large_crdt = create_counter(100_000)
  end
  
  bench "merge small CRDTs (10 ops)" do
    GCounter.merge(@small_crdt, @small_crdt)
  end
  
  bench "merge medium CRDTs (1K ops)" do
    GCounter.merge(@medium_crdt, @medium_crdt)
  end
  
  bench "merge large CRDTs (100K ops)" do
    GCounter.merge(@large_crdt, @large_crdt)
  end
  
  bench "G-Set union operation" do
    set1 = create_gset(1000)
    set2 = create_gset(1000)
    GSet.merge(set1, set2)
  end
  
  # Expected: O(n) merge time where n = number of nodes
end
```

### 4.3 Entropy Calculation Throughput

```elixir
defmodule VSMMetrics.Benchmark.EntropyTest do
  use Benchfella
  
  @small_dist List.duplicate(0.125, 8)
  @medium_dist List.duplicate(0.01, 100)
  @large_dist List.duplicate(0.001, 1000)
  
  bench "Shannon entropy - 8 states" do
    Entropy.shannon(@small_dist)
  end
  
  bench "Shannon entropy - 100 states" do
    Entropy.shannon(@medium_dist)
  end
  
  bench "Shannon entropy - 1000 states" do
    Entropy.shannon(@large_dist)
  end
  
  bench "Variety calculation - simple" do
    Entropy.variety_absorbed(16, 4)
  end
  
  bench "Variety calculation - complex" do
    input_dist = @medium_dist
    output_dist = Enum.take(@medium_dist, 50)
    Entropy.variety_absorbed_complex(input_dist, output_dist)
  end
end
```

## 5. Test Plan Document

### 5.1 Test Coverage Goals

- **Unit Tests**: 95% code coverage minimum
- **Property Tests**: All CRDT operations and entropy calculations
- **Integration Tests**: All subsystem boundaries
- **Performance Tests**: Meet latency SLAs

### 5.2 Test Execution Strategy

1. **Continuous Integration**
   - Run unit tests on every commit
   - Run property tests nightly
   - Run integration tests on PR merge
   - Run benchmarks weekly

2. **Test Environments**
   - Local: In-memory storage only
   - Staging: Full storage tiers
   - Production-like: Distributed cluster

3. **Test Data Management**
   - Synthetic metrics generation
   - Production data sampling (anonymized)
   - Chaos testing scenarios

### 5.3 Key Metrics to Monitor

1. **Correctness Metrics**
   - CRDT convergence rate
   - Entropy calculation accuracy
   - Variety measurement precision

2. **Performance Metrics**
   - Storage tier latencies
   - Aggregation throughput
   - Memory usage per metric

3. **Reliability Metrics**
   - Recovery time after crash
   - Data consistency score
   - Replication lag

### 5.4 Test Infrastructure

```yaml
# docker-compose.test.yml
version: '3.8'
services:
  metrics_node1:
    build: .
    environment:
      - NODE_NAME=metrics1@vsm
      - STORAGE_BACKEND=multi_tier
    volumes:
      - ./data/node1:/data
      
  metrics_node2:
    build: .
    environment:
      - NODE_NAME=metrics2@vsm
      - STORAGE_BACKEND=multi_tier
    volumes:
      - ./data/node2:/data
      
  metrics_node3:
    build: .
    environment:
      - NODE_NAME=metrics3@vsm
      - STORAGE_BACKEND=multi_tier
    volumes:
      - ./data/node3:/data
      
  test_runner:
    build: .
    command: mix test --trace
    depends_on:
      - metrics_node1
      - metrics_node2
      - metrics_node3
```

### 5.5 Example Test Scenarios

#### Scenario 1: High-Volume Metrics Ingestion
```elixir
test "handles 1M metrics/second ingestion" do
  # Generate 1M metrics
  metrics = generate_metrics(1_000_000)
  
  # Measure ingestion time
  {time, :ok} = :timer.tc(fn ->
    Metrics.bulk_insert(metrics)
  end)
  
  # Should complete in < 1 second
  assert time < 1_000_000
  
  # Verify all metrics stored
  assert Metrics.count() == 1_000_000
end
```

#### Scenario 2: Distributed Query During Network Partition
```elixir
test "degrades gracefully during network partition" do
  # Setup 5-node cluster
  nodes = setup_cluster(5)
  
  # Insert metrics across all nodes
  distribute_metrics(nodes, 10_000)
  
  # Partition network (3 + 2 nodes)
  partition = create_partition(nodes, {3, 2})
  
  # Query should return partial results
  result = Metrics.distributed_query(:sum)
  
  # Should have ~60% of data (3/5 nodes)
  assert result.count > 5_000
  assert result.count < 7_000
  assert result.partial == true
  
  # Heal partition
  heal_partition(partition)
  
  # Eventually consistent
  :timer.sleep(5000)
  result = Metrics.distributed_query(:sum)
  assert result.count == 10_000
end
```

## 6. Test Automation & CI/CD

```yaml
# .github/workflows/metrics-tests.yml
name: VSM Metrics Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        otp: [24, 25, 26]
        elixir: [1.14, 1.15]
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-elixir@v1
        with:
          otp-version: ${{ matrix.otp }}
          elixir-version: ${{ matrix.elixir }}
      - run: mix deps.get
      - run: mix test --cover
      - uses: codecov/codecov-action@v3

  property-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-elixir@v1
      - run: mix deps.get
      - run: mix test --only property --max-runs 10000

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-elixir@v1
      - run: docker-compose -f docker-compose.test.yml up -d
      - run: mix test --only integration
      - run: docker-compose -f docker-compose.test.yml down

  benchmarks:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-elixir@v1
      - run: mix deps.get
      - run: mix bench
      - uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: bench/snapshots/
```

## Summary

This comprehensive test strategy covers:

1. **Unit Tests** for all storage tiers, CRDT operations, calculations, entropy, and time-constant functions
2. **Property-Based Tests** ensuring mathematical properties hold for CRDTs, entropy bounds, and variety laws
3. **Integration Tests** validating multi-tier coordination, distributed aggregation, and cross-subsystem communication
4. **Performance Benchmarks** measuring storage latencies, CRDT merge times, and entropy calculation throughput
5. **Test Infrastructure** with Docker Compose for distributed testing
6. **CI/CD Integration** with automated test execution and coverage reporting

The strategy emphasizes correctness, performance, and reliability of the VSM metrics system while providing concrete examples for implementation.