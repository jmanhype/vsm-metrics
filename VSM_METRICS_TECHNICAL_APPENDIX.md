# VSM Metrics Technical Implementation Appendix

## A. Detailed Metric Calculations

### A.1 Variety Engineering Formulas

**Requisite Variety Calculation**:
```elixir
defmodule VSM.Metrics.Variety do
  @doc """
  Calculate requisite variety ratio according to Ashby's Law
  """
  def requisite_variety_ratio(controller_states, environment_states) do
    controller_variety = calculate_variety(controller_states)
    environment_variety = calculate_variety(environment_states)
    
    %{
      controller_variety: controller_variety,
      environment_variety: environment_variety,
      ratio: controller_variety / environment_variety,
      sufficient: controller_variety >= environment_variety,
      deficit: max(0, environment_variety - controller_variety)
    }
  end
  
  defp calculate_variety(states) do
    states
    |> Enum.frequencies()
    |> Map.values()
    |> calculate_entropy()
  end
  
  defp calculate_entropy(frequencies) do
    total = Enum.sum(frequencies)
    
    frequencies
    |> Enum.map(&(&1 / total))
    |> Enum.reduce(0, fn p, acc ->
      if p > 0, do: acc - p * :math.log2(p), else: acc
    end)
  end
end
```

**Multi-Dimensional Variety**:
```elixir
def multidimensional_variety(state_matrix) do
  # Calculate variety for each dimension
  dimensional_varieties = state_matrix
    |> transpose()
    |> Enum.map(&calculate_variety/1)
  
  # Calculate joint variety
  joint_variety = state_matrix
    |> Enum.map(&encode_state/1)
    |> calculate_variety()
  
  %{
    dimensional: dimensional_varieties,
    joint: joint_variety,
    interaction: joint_variety - Enum.sum(dimensional_varieties)
  }
end
```

### A.2 Temporal Decay Functions

**Multi-Scale Decay Model**:
```elixir
defmodule VSM.Metrics.Decay do
  @doc """
  Time-aware importance decay with subsystem-specific constants
  """
  def importance_decay(initial_value, elapsed_time, subsystem) do
    decay_constant = get_decay_constant(subsystem)
    
    case subsystem do
      :s1_operational ->
        # Fast exponential decay for operational signals
        initial_value * :math.exp(-decay_constant * elapsed_time)
        
      :s2_coordination ->
        # Medium decay with plateau
        plateau = 0.3
        decayed = initial_value * :math.exp(-decay_constant * elapsed_time)
        max(decayed, initial_value * plateau)
        
      :s3_control ->
        # Stepped decay for control signals
        steps = div(elapsed_time, decay_constant)
        initial_value * :math.pow(0.5, steps)
        
      :s4_intelligence ->
        # Slow linear decay for strategic signals
        max(0, initial_value - decay_constant * elapsed_time)
        
      :s5_policy ->
        # Very slow decay with long memory
        if elapsed_time < decay_constant do
          initial_value
        else
          initial_value * 0.8
        end
    end
  end
  
  defp get_decay_constant(subsystem) do
    %{
      s1_operational: 0.1,    # 10 second half-life
      s2_coordination: 0.01,  # 100 second half-life  
      s3_control: 600,        # 10 minute steps
      s4_intelligence: 0.001, # Very slow decay
      s5_policy: 86400        # 1 day threshold
    }[subsystem]
  end
end
```

### A.3 Algedonic Signal Correlation

**Pattern Correlation Matrix**:
```elixir
defmodule VSM.Metrics.Algedonic.Correlation do
  @doc """
  Correlate algedonic signals to detect systemic patterns
  """
  def build_correlation_matrix(signals, window_size) do
    # Group signals by time windows
    windowed_signals = signals
      |> Enum.group_by(&time_window(&1.timestamp, window_size))
      |> Enum.sort_by(&elem(&1, 0))
    
    # Calculate correlation between signal types
    signal_types = extract_signal_types(signals)
    
    correlation_matrix = for type1 <- signal_types, into: %{} do
      correlations = for type2 <- signal_types, into: %{} do
        correlation = calculate_signal_correlation(
          windowed_signals, 
          type1, 
          type2
        )
        {type2, correlation}
      end
      {type1, correlations}
    end
    
    %{
      matrix: correlation_matrix,
      significant_correlations: find_significant_correlations(correlation_matrix),
      temporal_patterns: detect_temporal_patterns(windowed_signals)
    }
  end
  
  defp calculate_signal_correlation(windowed_signals, type1, type2) do
    # Extract time series for each signal type
    series1 = extract_series(windowed_signals, type1)
    series2 = extract_series(windowed_signals, type2)
    
    # Calculate Pearson correlation with lag analysis
    max_lag = 5
    correlations = for lag <- -max_lag..max_lag do
      lagged_series2 = apply_lag(series2, lag)
      {lag, pearson_correlation(series1, lagged_series2)}
    end
    
    # Return maximum correlation and its lag
    Enum.max_by(correlations, &abs(elem(&1, 1)))
  end
end
```

## B. Storage Tier Specifications

### B.1 Hot Tier (Real-time)

**ETS Configuration**:
```elixir
defmodule VSM.Storage.HotTier do
  def init_tables do
    # Main metrics table - optimized for write
    :ets.new(:vsm_metrics_hot, [
      :ordered_set,           # Time-ordered
      :public,                # Concurrent access
      :named_table,
      {:write_concurrency, true},
      {:read_concurrency, true},
      {:decentralized_counters, true}  # Better concurrent writes
    ])
    
    # Index tables for fast lookup
    :ets.new(:vsm_metrics_by_system, [:bag, :public, :named_table])
    :ets.new(:vsm_metrics_by_type, [:bag, :public, :named_table])
    
    # Circular buffer for sliding windows
    :ets.new(:vsm_metrics_buffer, [
      :set,
      :public,
      :named_table,
      {:write_concurrency, true}
    ])
  end
  
  def insert_metric(metric) do
    timestamp = System.monotonic_time(:microsecond)
    key = {timestamp, metric.system, metric.type}
    
    # Insert into main table
    :ets.insert(:vsm_metrics_hot, {key, metric})
    
    # Update indices
    :ets.insert(:vsm_metrics_by_system, {metric.system, key})
    :ets.insert(:vsm_metrics_by_type, {metric.type, key})
    
    # Update circular buffer
    update_circular_buffer(metric)
    
    # Trigger rollup if needed
    maybe_trigger_rollup(timestamp)
  end
end
```

### B.2 Warm Tier (Time-series)

**Time-series Schema**:
```elixir
defmodule VSM.Storage.WarmTier do
  @doc """
  Optimized time-series storage with downsampling
  """
  defstruct [
    :metric_name,
    :tags,
    :timestamp,
    :value,
    :aggregations
  ]
  
  def create_schema do
    %{
      # 1-minute aggregations
      "vsm_metrics_1m" => %{
        retention: "7d",
        aggregations: [:avg, :min, :max, :sum, :count, :p95, :p99],
        downsampling: nil
      },
      
      # 5-minute aggregations  
      "vsm_metrics_5m" => %{
        retention: "30d",
        aggregations: [:avg, :min, :max, :p95],
        downsampling: "vsm_metrics_1m"
      },
      
      # 1-hour aggregations
      "vsm_metrics_1h" => %{
        retention: "1y",
        aggregations: [:avg, :min, :max],
        downsampling: "vsm_metrics_5m"
      },
      
      # Daily aggregations
      "vsm_metrics_1d" => %{
        retention: "5y",
        aggregations: [:avg, :min, :max],
        downsampling: "vsm_metrics_1h"
      }
    }
  end
  
  def rollup_metrics(source_table, target_table, time_window) do
    # Efficient streaming aggregation
    source_table
    |> stream_time_range(time_window)
    |> Stream.chunk_by(&time_bucket(&1.timestamp, time_window))
    |> Stream.map(&aggregate_chunk/1)
    |> Stream.each(&insert_aggregated(target_table, &1))
    |> Stream.run()
  end
end
```

### B.3 Cold Tier (Archival)

**Columnar Storage Format**:
```elixir
defmodule VSM.Storage.ColdTier do
  @doc """
  Parquet-like columnar storage for historical data
  """
  def archive_metrics(date_range) do
    metrics = fetch_metrics_for_range(date_range)
    
    # Convert to columnar format
    columns = %{
      timestamps: extract_column(metrics, :timestamp),
      systems: extract_column(metrics, :system) |> dictionary_encode(),
      types: extract_column(metrics, :type) |> dictionary_encode(),
      values: extract_column(metrics, :value) |> compress_values()
    }
    
    # Apply compression
    compressed = columns
      |> Enum.map(fn {name, data} ->
        {name, compress_column(data)}
      end)
      |> Map.new()
    
    # Write to storage with metadata
    write_archive(compressed, build_metadata(metrics))
  end
  
  defp compress_column(data) do
    # Use appropriate compression based on data type
    case detect_column_type(data) do
      :numeric -> delta_encode(data) |> zstd_compress()
      :categorical -> dictionary_encode(data) |> zstd_compress()
      :timestamp -> delta_encode(data) |> zstd_compress()
      _ -> zstd_compress(data)
    end
  end
end
```

## C. CRDT Implementation Patterns

### C.1 State-based CRDTs for VSM

**G-Counter for Metrics**:
```elixir
defmodule VSM.CRDT.GCounter do
  @doc """
  Grow-only counter for distributed metric aggregation
  """
  defstruct node_id: nil, counts: %{}
  
  def new(node_id) do
    %__MODULE__{node_id: node_id, counts: %{}}
  end
  
  def increment(%__MODULE__{node_id: node_id, counts: counts} = counter) do
    updated_counts = Map.update(counts, node_id, 1, &(&1 + 1))
    %{counter | counts: updated_counts}
  end
  
  def merge(%__MODULE__{counts: counts1}, %__MODULE__{counts: counts2}) do
    merged_counts = Map.merge(counts1, counts2, fn _k, v1, v2 ->
      max(v1, v2)
    end)
    %__MODULE__{counts: merged_counts}
  end
  
  def value(%__MODULE__{counts: counts}) do
    Map.values(counts) |> Enum.sum()
  end
end
```

**LWW-Register for Configuration**:
```elixir
defmodule VSM.CRDT.LWWRegister do
  @doc """
  Last-Write-Wins Register for configuration management
  """
  defstruct [:value, :timestamp, :node_id]
  
  def new(value, node_id) do
    %__MODULE__{
      value: value,
      timestamp: System.monotonic_time(:nanosecond),
      node_id: node_id
    }
  end
  
  def merge(%__MODULE__{} = reg1, %__MODULE__{} = reg2) do
    cond do
      reg1.timestamp > reg2.timestamp -> reg1
      reg1.timestamp < reg2.timestamp -> reg2
      true -> if reg1.node_id > reg2.node_id, do: reg1, else: reg2
    end
  end
end
```

### C.2 Delta-CRDT Optimization

**Delta State Propagation**:
```elixir
defmodule VSM.CRDT.DeltaState do
  @doc """
  Efficient delta-state synchronization
  """
  def track_deltas(crdt, operation) do
    initial_state = crdt
    updated_state = apply_operation(crdt, operation)
    delta = compute_delta(initial_state, updated_state)
    
    %{
      state: updated_state,
      delta: delta,
      version: increment_version(crdt.version)
    }
  end
  
  def merge_delta(crdt, delta) do
    # Only merge if delta is newer
    if delta.version > crdt.version do
      merge_state(crdt, delta.changes)
    else
      crdt
    end
  end
  
  def anti_entropy_sync(local_crdt, remote_crdt) do
    # Exchange version vectors
    missing_deltas = compute_missing_deltas(
      local_crdt.version_vector,
      remote_crdt.version_vector
    )
    
    # Exchange only missing deltas
    exchange_deltas(missing_deltas)
  end
end
```

## D. Advanced Pattern Detection

### D.1 Anomaly Detection Algorithms

**Isolation Forest for Multivariate Anomalies**:
```elixir
defmodule VSM.Metrics.AnomalyDetection do
  @doc """
  Detect anomalies in multi-dimensional metric space
  """
  def isolation_forest(metrics, contamination \\ 0.1) do
    n_trees = 100
    sample_size = min(256, length(metrics))
    
    # Build isolation trees
    trees = for _ <- 1..n_trees do
      sample = Enum.take_random(metrics, sample_size)
      build_isolation_tree(sample, 0)
    end
    
    # Calculate anomaly scores
    scores = metrics
      |> Enum.map(fn metric ->
        path_length = average_path_length(metric, trees)
        anomaly_score(path_length, sample_size)
      end)
    
    # Determine threshold
    threshold = quantile(scores, 1 - contamination)
    
    # Classify anomalies
    metrics
    |> Enum.zip(scores)
    |> Enum.map(fn {metric, score} ->
      %{metric | anomaly_score: score, is_anomaly: score > threshold}
    end)
  end
  
  defp build_isolation_tree(data, current_depth) do
    max_depth = :math.log2(length(data)) |> ceil()
    
    cond do
      length(data) <= 1 or current_depth >= max_depth ->
        %{type: :leaf, size: length(data)}
        
      true ->
        # Select random attribute and split value
        attribute = Enum.random(get_attributes(data))
        {min_val, max_val} = get_range(data, attribute)
        split_value = :rand.uniform() * (max_val - min_val) + min_val
        
        # Partition data
        {left, right} = partition(data, attribute, split_value)
        
        %{
          type: :internal,
          attribute: attribute,
          split_value: split_value,
          left: build_isolation_tree(left, current_depth + 1),
          right: build_isolation_tree(right, current_depth + 1)
        }
    end
  end
end
```

### D.2 Temporal Pattern Mining

**Sequential Pattern Discovery**:
```elixir
defmodule VSM.Metrics.SequentialPatterns do
  @doc """
  Mine frequent sequential patterns in metric events
  """
  def prefixspan(sequences, min_support) do
    # Build initial frequent items
    frequent_items = sequences
      |> Enum.flat_map(&Enum.uniq/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_, count} -> count >= min_support end)
      |> Enum.map(&elem(&1, 0))
    
    # Recursively mine patterns
    patterns = frequent_items
      |> Enum.flat_map(fn item ->
        prefix = [item]
        projected_db = project_sequences(sequences, prefix)
        
        if length(projected_db) >= min_support do
          mine_patterns(prefix, projected_db, min_support)
        else
          []
        end
      end)
    
    # Add pattern metadata
    patterns
    |> Enum.map(fn pattern ->
      %{
        sequence: pattern,
        support: calculate_support(pattern, sequences),
        confidence: calculate_confidence(pattern, sequences),
        lift: calculate_lift(pattern, sequences)
      }
    end)
    |> Enum.sort_by(& &1.support, :desc)
  end
end
```

## E. Real-time Processing Pipelines

### E.1 Stream Processing Architecture

```elixir
defmodule VSM.Metrics.StreamProcessor do
  use GenStage
  
  @doc """
  Multi-stage pipeline for metric processing
  """
  def start_link(opts) do
    # Define pipeline stages
    {:ok, producer} = MetricProducer.start_link(opts)
    {:ok, enricher} = MetricEnricher.start_link(opts)
    {:ok, aggregator} = MetricAggregator.start_link(opts)
    {:ok, detector} = AnomalyDetector.start_link(opts)
    {:ok, consumer} = MetricConsumer.start_link(opts)
    
    # Connect stages
    GenStage.sync_subscribe(enricher, to: producer)
    GenStage.sync_subscribe(aggregator, to: enricher)
    GenStage.sync_subscribe(detector, to: aggregator)
    GenStage.sync_subscribe(consumer, to: detector)
    
    {:ok, %{pipeline: [producer, enricher, aggregator, detector, consumer]}}
  end
end
```

### E.2 Window Operations

```elixir
defmodule VSM.Metrics.Windows do
  @doc """
  Sliding window aggregations with watermarks
  """
  def tumbling_window(stream, window_size) do
    stream
    |> Stream.chunk_by(&div(&1.timestamp, window_size))
    |> Stream.map(&aggregate_window/1)
  end
  
  def sliding_window(stream, window_size, slide_size) do
    stream
    |> Stream.transform([], fn event, buffer ->
      new_buffer = [event | buffer]
        |> Enum.filter(&in_window?(&1, event.timestamp, window_size))
      
      if should_emit?(event.timestamp, slide_size) do
        {[aggregate_window(new_buffer)], new_buffer}
      else
        {[], new_buffer}
      end
    end)
  end
  
  def session_window(stream, gap_duration) do
    stream
    |> Stream.transform([], fn event, session ->
      if session == [] or event.timestamp - last_timestamp(session) > gap_duration do
        # New session
        if session != [], do: {[aggregate_window(session)], [event]}, else: {[], [event]}
      else
        # Continue session
        {[], session ++ [event]}
      end
    end)
  end
end
```

## F. Integration Examples

### F.1 Complete Metric Pipeline

```elixir
defmodule VSM.Metrics.Pipeline do
  def start do
    # Initialize storage tiers
    VSM.Storage.HotTier.init_tables()
    {:ok, _} = VSM.Storage.WarmTier.start_link()
    {:ok, _} = VSM.Storage.ColdTier.start_link()
    
    # Start metric collectors
    {:ok, _} = VSM.Metrics.Collector.start_link()
    
    # Start stream processors
    {:ok, _} = VSM.Metrics.StreamProcessor.start_link([
      enrichment: true,
      aggregation: true,
      anomaly_detection: true
    ])
    
    # Start variety calculators
    {:ok, _} = VSM.Metrics.VarietyCalculator.start_link()
    
    # Start algedonic channel
    {:ok, _} = VSM.Metrics.AlgedonicChannel.start_link()
    
    # Configure telemetry handlers
    :telemetry.attach_many(
      "vsm-metrics",
      [
        [:vsm, :metrics, :received],
        [:vsm, :metrics, :processed],
        [:vsm, :metrics, :stored],
        [:vsm, :metrics, :anomaly]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end
  
  defp handle_telemetry_event(event, measurements, metadata, _config) do
    # Route to appropriate handler
    case event do
      [:vsm, :metrics, :received] -> 
        VSM.Storage.HotTier.insert_metric(metadata.metric)
        
      [:vsm, :metrics, :anomaly] ->
        VSM.Metrics.AlgedonicChannel.send_pain_signal(
          metadata.source,
          metadata.anomaly,
          :high
        )
        
      _ -> :ok
    end
  end
end
```

This technical appendix provides implementation-ready code patterns for the VSM metrics system, with a focus on performance, scalability, and mathematical correctness.