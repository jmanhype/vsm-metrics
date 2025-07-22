# VSM Metrics Implementation Guide

## Quick Start Guide

This guide provides practical steps to implement VSM metrics and observability based on the research findings.

### 1. Project Setup

```bash
# Create new Elixir project
mix new vsm_metrics --sup
cd vsm_metrics

# Add dependencies to mix.exs
defp deps do
  [
    {:telemetry, "~> 1.2"},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:prometheus_ex, "~> 3.0"},
    {:prometheus_ecto, "~> 1.4"},
    {:gen_stage, "~> 1.2"},
    {:flow, "~> 1.2"},
    {:ex2ms, "~> 1.0"},
    {:jason, "~> 1.4"},
    {:nimble_parsec, "~> 1.3"},
    {:stream_data, "~> 0.5", only: :test}
  ]
end
```

### 2. Core Metrics Module Structure

```
lib/vsm_metrics/
├── application.ex          # Main application supervisor
├── telemetry.ex           # Telemetry configuration
├── metrics/
│   ├── collector.ex       # Metric collection
│   ├── variety.ex         # Variety calculations
│   ├── entropy.ex         # Shannon entropy
│   └── temporal.ex        # Time-based metrics
├── storage/
│   ├── hot_tier.ex        # ETS-based storage
│   ├── warm_tier.ex       # Time-series storage
│   └── cold_tier.ex       # Archival storage
├── subsystems/
│   ├── s1_operational.ex  # System 1 metrics
│   ├── s2_coordination.ex # System 2 metrics
│   ├── s3_control.ex      # System 3 metrics
│   ├── s4_intelligence.ex # System 4 metrics
│   └── s5_policy.ex       # System 5 metrics
├── channels/
│   ├── algedonic.ex       # Pain/pleasure signals
│   └── temporal_variety.ex # Temporal patterns
└── crdt/
    ├── g_counter.ex       # Grow-only counter
    └── pn_counter.ex      # PN-Counter
```

### 3. Basic Implementation

#### 3.1 Telemetry Setup

```elixir
# lib/vsm_metrics/telemetry.ex
defmodule VSMMetrics.Telemetry do
  def setup do
    events = [
      # System 1 - Operational
      [:vsm, :s1, :operation, :start],
      [:vsm, :s1, :operation, :stop],
      [:vsm, :s1, :operation, :exception],
      
      # System 2 - Coordination
      [:vsm, :s2, :coordination, :start],
      [:vsm, :s2, :coordination, :stop],
      
      # System 3 - Control
      [:vsm, :s3, :control, :decision],
      [:vsm, :s3, :audit, :check],
      
      # System 4 - Intelligence
      [:vsm, :s4, :scan, :complete],
      [:vsm, :s4, :pattern, :detected],
      
      # System 5 - Policy
      [:vsm, :s5, :policy, :update],
      [:vsm, :s5, :identity, :check],
      
      # Algedonic signals
      [:vsm, :algedonic, :pain],
      [:vsm, :algedonic, :pleasure],
      
      # Variety measurements
      [:vsm, :variety, :calculated],
      [:vsm, :variety, :imbalance]
    ]
    
    # Attach handlers
    :telemetry.attach_many(
      "vsm-metrics-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end
  
  def handle_event(event, measurements, metadata, _config) do
    # Process and store metrics
    VSMMetrics.Collector.process_event(event, measurements, metadata)
  end
end
```

#### 3.2 Variety Calculator

```elixir
# lib/vsm_metrics/metrics/variety.ex
defmodule VSMMetrics.Metrics.Variety do
  use GenServer
  
  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def calculate(subsystem, states) do
    GenServer.call(__MODULE__, {:calculate, subsystem, states})
  end
  
  def check_requisite_variety(controller, environment) do
    GenServer.call(__MODULE__, {:check_requisite, controller, environment})
  end
  
  # Server callbacks
  def init(_opts) do
    {:ok, %{
      calculations: %{},
      history: [],
      thresholds: default_thresholds()
    }}
  end
  
  def handle_call({:calculate, subsystem, states}, _from, state) do
    variety = calculate_shannon_entropy(states)
    
    # Store calculation
    timestamp = System.monotonic_time(:millisecond)
    calculation = %{
      subsystem: subsystem,
      variety: variety,
      timestamp: timestamp,
      state_count: length(Enum.uniq(states))
    }
    
    new_state = state
      |> update_calculations(subsystem, calculation)
      |> update_history(calculation)
      |> check_thresholds(subsystem, variety)
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm, :variety, :calculated],
      %{variety: variety},
      %{subsystem: subsystem}
    )
    
    {:reply, {:ok, variety}, new_state}
  end
  
  def handle_call({:check_requisite, controller, environment}, _from, state) do
    controller_variety = calculate_shannon_entropy(controller)
    environment_variety = calculate_shannon_entropy(environment)
    
    ratio = controller_variety / environment_variety
    sufficient = ratio >= 1.0
    
    result = %{
      controller_variety: controller_variety,
      environment_variety: environment_variety,
      ratio: ratio,
      sufficient: sufficient,
      recommendation: get_recommendation(ratio)
    }
    
    # Emit event if imbalanced
    unless sufficient do
      :telemetry.execute(
        [:vsm, :variety, :imbalance],
        %{ratio: ratio, deficit: environment_variety - controller_variety},
        %{type: :insufficient}
      )
    end
    
    {:reply, {:ok, result}, state}
  end
  
  # Private functions
  defp calculate_shannon_entropy(states) do
    frequencies = Enum.frequencies(states)
    total = length(states)
    
    frequencies
    |> Map.values()
    |> Enum.map(fn count ->
      p = count / total
      -p * :math.log2(p)
    end)
    |> Enum.sum()
  end
  
  defp get_recommendation(ratio) when ratio < 0.8 do
    "Critical: Significant variety amplification needed"
  end
  defp get_recommendation(ratio) when ratio < 1.0 do
    "Warning: Minor variety amplification recommended"
  end
  defp get_recommendation(ratio) when ratio > 1.5 do
    "Consider variety attenuation for efficiency"
  end
  defp get_recommendation(_ratio) do
    "Variety balance is adequate"
  end
  
  defp default_thresholds do
    %{
      s1_operational: {2.0, 4.0},    # min, max variety
      s2_coordination: {1.5, 3.5},
      s3_control: {1.0, 3.0},
      s4_intelligence: {2.5, 5.0},
      s5_policy: {0.5, 2.0}
    }
  end
end
```

#### 3.3 Algedonic Channel

```elixir
# lib/vsm_metrics/channels/algedonic.ex
defmodule VSMMetrics.Channels.Algedonic do
  use GenServer
  require Logger
  
  @critical_threshold 0.9
  @high_threshold 0.7
  @medium_threshold 0.5
  
  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def signal(type, source, data, severity \\ :medium) do
    GenServer.cast(__MODULE__, {:signal, type, source, data, severity})
  end
  
  # Server callbacks
  def init(_opts) do
    {:ok, %{
      signals: [],
      patterns: %{},
      alert_handlers: []
    }}
  end
  
  def handle_cast({:signal, type, source, data, severity}, state) do
    signal = %{
      id: generate_id(),
      type: type,
      source: source,
      data: data,
      severity: severity,
      timestamp: DateTime.utc_now()
    }
    
    # Emit telemetry
    :telemetry.execute(
      [:vsm, :algedonic, type],
      %{severity: severity_to_number(severity)},
      %{source: source, signal_id: signal.id}
    )
    
    new_state = state
      |> store_signal(signal)
      |> detect_patterns(signal)
      |> maybe_alert(signal)
    
    {:noreply, new_state}
  end
  
  # Private functions
  defp severity_to_number(:critical), do: 1.0
  defp severity_to_number(:high), do: 0.8
  defp severity_to_number(:medium), do: 0.5
  defp severity_to_number(:low), do: 0.2
  
  defp store_signal(state, signal) do
    # Keep last 1000 signals
    signals = [signal | state.signals] |> Enum.take(1000)
    %{state | signals: signals}
  end
  
  defp detect_patterns(state, signal) do
    # Simple pattern detection - repeated signals from same source
    recent_similar = state.signals
      |> Enum.filter(fn s ->
        s.source == signal.source and 
        s.type == signal.type and
        DateTime.diff(signal.timestamp, s.timestamp, :second) < 300
      end)
      |> length()
    
    if recent_similar > 5 do
      Logger.warn("Pattern detected: Repeated #{signal.type} signals from #{signal.source}")
      
      # Create aggregated signal
      aggregated = %{signal | 
        severity: :high,
        data: Map.put(signal.data, :pattern_count, recent_similar)
      }
      
      maybe_alert(state, aggregated)
    else
      state
    end
  end
  
  defp maybe_alert(state, signal) do
    case signal.severity do
      :critical ->
        Logger.error("CRITICAL #{signal.type} signal from #{signal.source}")
        send_to_s5(signal)
        
      :high ->
        Logger.warn("HIGH #{signal.type} signal from #{signal.source}")
        send_to_s4(signal)
        
      _ ->
        # Normal routing through hierarchy
        :ok
    end
    
    state
  end
  
  defp send_to_s5(signal) do
    # Direct emergency bypass to System 5
    Process.send(:vsm_s5_policy, {:algedonic_emergency, signal}, [:noconnect])
  end
  
  defp send_to_s4(signal) do
    # Route to System 4 for analysis
    Process.send(:vsm_s4_intelligence, {:algedonic_alert, signal}, [:noconnect])
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
end
```

### 4. Storage Implementation

#### 4.1 Hot Tier (ETS)

```elixir
# lib/vsm_metrics/storage/hot_tier.ex
defmodule VSMMetrics.Storage.HotTier do
  use GenServer
  
  @table_name :vsm_metrics_hot
  @ttl_seconds 3600  # 1 hour
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def insert(metric) do
    timestamp = System.monotonic_time(:microsecond)
    key = {timestamp, metric.subsystem, metric.name}
    value = {metric.value, metric.metadata, System.system_time(:second)}
    
    :ets.insert(@table_name, {key, value})
    :ok
  end
  
  def query(subsystem, name, time_range) do
    # Build match spec for efficient querying
    match_spec = [
      {
        {{:"$1", :"$2", :"$3"}, {:"$4", :"$5", :"$6"}},
        [
          {:andalso,
            {:==, :"$2", subsystem},
            {:andalso,
              {:==, :"$3", name},
              {:andalso,
                {:>=, :"$1", time_range.start},
                {:"=<", :"$1", time_range.end}
              }
            }
          }
        ],
        [{{:"$1", :"$4", :"$5"}}]
      }
    ]
    
    :ets.select(@table_name, match_spec)
  end
  
  def init(_opts) do
    # Create ETS table
    :ets.new(@table_name, [
      :ordered_set,
      :named_table,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
    
    # Schedule cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end
  
  def handle_info(:cleanup, state) do
    cutoff = System.system_time(:second) - @ttl_seconds
    
    # Delete old entries
    :ets.select_delete(@table_name, [
      {
        {{:"$1", :"$2", :"$3"}, {:"$4", :"$5", :"$6"}},
        [{:<, :"$6", cutoff}],
        [true]
      }
    ])
    
    schedule_cleanup()
    {:noreply, state}
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
```

### 5. Subsystem Metrics

#### 5.1 System 1 - Operational Metrics

```elixir
# lib/vsm_metrics/subsystems/s1_operational.ex
defmodule VSMMetrics.Subsystems.S1Operational do
  use GenServer
  
  def start_link(unit_id) do
    GenServer.start_link(__MODULE__, unit_id, name: via_tuple(unit_id))
  end
  
  def record_operation(unit_id, operation, duration, result) do
    GenServer.cast(via_tuple(unit_id), {:record, operation, duration, result})
  end
  
  def get_metrics(unit_id) do
    GenServer.call(via_tuple(unit_id), :get_metrics)
  end
  
  # Callbacks
  def init(unit_id) do
    {:ok, %{
      unit_id: unit_id,
      operations: %{},
      performance: %{
        success_rate: 1.0,
        avg_duration: 0,
        throughput: 0
      }
    }}
  end
  
  def handle_cast({:record, operation, duration, result}, state) do
    # Start telemetry span
    start_time = System.monotonic_time()
    metadata = %{unit_id: state.unit_id, operation: operation}
    
    # Emit start event
    :telemetry.execute(
      [:vsm, :s1, :operation, :start],
      %{system_time: System.system_time()},
      metadata
    )
    
    # Update metrics
    new_state = state
      |> update_operation_stats(operation, duration, result)
      |> calculate_performance()
    
    # Emit stop event
    :telemetry.execute(
      [:vsm, :s1, :operation, :stop],
      %{duration: duration, success: result == :ok},
      metadata
    )
    
    # Check for anomalies
    if duration > expected_duration(operation) * 2 do
      VSMMetrics.Channels.Algedonic.signal(
        :pain,
        {:s1, state.unit_id},
        %{operation: operation, duration: duration},
        :medium
      )
    end
    
    {:noreply, new_state}
  end
  
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      unit_id: state.unit_id,
      performance: state.performance,
      operations: summarize_operations(state.operations),
      health: calculate_health(state)
    }
    
    {:reply, metrics, state}
  end
  
  # Private functions
  defp via_tuple(unit_id) do
    {:via, Registry, {VSMMetrics.Registry, {:s1_unit, unit_id}}}
  end
  
  defp update_operation_stats(state, operation, duration, result) do
    stats = Map.get(state.operations, operation, %{
      count: 0,
      success: 0,
      total_duration: 0,
      errors: []
    })
    
    updated_stats = %{stats |
      count: stats.count + 1,
      success: stats.success + (if result == :ok, do: 1, else: 0),
      total_duration: stats.total_duration + duration,
      errors: if result != :ok, do: [result | stats.errors] |> Enum.take(10), else: stats.errors
    }
    
    put_in(state.operations[operation], updated_stats)
  end
  
  defp calculate_performance(state) do
    total_ops = state.operations
      |> Map.values()
      |> Enum.map(& &1.count)
      |> Enum.sum()
    
    if total_ops > 0 do
      success_count = state.operations
        |> Map.values()
        |> Enum.map(& &1.success)
        |> Enum.sum()
      
      total_duration = state.operations
        |> Map.values()
        |> Enum.map(& &1.total_duration)
        |> Enum.sum()
      
      performance = %{
        success_rate: success_count / total_ops,
        avg_duration: total_duration / total_ops,
        throughput: total_ops / (total_duration / 1000) # ops per second
      }
      
      %{state | performance: performance}
    else
      state
    end
  end
  
  defp calculate_health(state) do
    # Simple health score based on success rate and performance
    base_score = state.performance.success_rate * 100
    
    # Penalize high latency
    latency_penalty = min(20, state.performance.avg_duration / 10)
    
    # Bonus for high throughput
    throughput_bonus = min(10, state.performance.throughput)
    
    max(0, min(100, base_score - latency_penalty + throughput_bonus))
  end
  
  defp expected_duration(operation) do
    # Define expected durations for operations
    case operation do
      :process -> 50
      :transform -> 100
      :validate -> 20
      _ -> 75
    end
  end
  
  defp summarize_operations(operations) do
    operations
    |> Enum.map(fn {name, stats} ->
      {name, %{
        count: stats.count,
        success_rate: stats.success / max(stats.count, 1),
        avg_duration: stats.total_duration / max(stats.count, 1),
        recent_errors: Enum.take(stats.errors, 3)
      }}
    end)
    |> Map.new()
  end
end
```

### 6. Testing

```elixir
# test/vsm_metrics/variety_test.exs
defmodule VSMMetrics.VarietyTest do
  use ExUnit.Case
  
  alias VSMMetrics.Metrics.Variety
  
  describe "shannon entropy calculation" do
    test "calculates entropy for uniform distribution" do
      states = [:a, :b, :c, :d] |> List.duplicate(25) |> List.flatten()
      
      {:ok, variety} = Variety.calculate(:test, states)
      
      # Uniform distribution of 4 states = log2(4) = 2.0
      assert_in_delta variety, 2.0, 0.001
    end
    
    test "calculates entropy for skewed distribution" do
      states = List.duplicate(:a, 90) ++ List.duplicate(:b, 10)
      
      {:ok, variety} = Variety.calculate(:test, states)
      
      # Highly skewed distribution has low entropy
      assert variety < 0.5
    end
    
    test "detects variety imbalance" do
      controller = [:a, :b]  # Low variety
      environment = [:a, :b, :c, :d, :e, :f, :g, :h]  # High variety
      
      {:ok, result} = Variety.check_requisite_variety(controller, environment)
      
      refute result.sufficient
      assert result.ratio < 1.0
      assert result.recommendation =~ "amplification"
    end
  end
end
```

### 7. Configuration

```elixir
# config/config.exs
import Config

config :vsm_metrics,
  # Telemetry polling
  telemetry_poller: [
    measurements: [
      {VSMMetrics.Metrics, :measure_vm_stats, []},
      {:process_info, :message_queue_len, [self()]}
    ],
    period: :timer.seconds(5)
  ],
  
  # Storage configuration
  storage: [
    hot_tier: [
      ttl: :timer.hours(1),
      max_size: 1_000_000
    ],
    warm_tier: [
      retention: [
        {"1m", "7d"},
        {"5m", "30d"},
        {"1h", "1y"}
      ]
    ],
    cold_tier: [
      compression: :zstd,
      format: :parquet
    ]
  ],
  
  # Subsystem thresholds
  thresholds: [
    s1_variety: {2.0, 4.0},
    s2_variety: {1.5, 3.5},
    s3_variety: {1.0, 3.0},
    s4_variety: {2.5, 5.0},
    s5_variety: {0.5, 2.0}
  ],
  
  # Algedonic channel
  algedonic: [
    pain_threshold: 0.7,
    pleasure_threshold: 0.8,
    pattern_window: :timer.minutes(5),
    bypass_severity: [:critical, :high]
  ]
```

### 8. Deployment Checklist

- [ ] Set up Prometheus/Grafana for visualization
- [ ] Configure alerting rules for algedonic signals
- [ ] Set up time-series database (InfluxDB/TimescaleDB)
- [ ] Configure CRDT synchronization for distributed deployment
- [ ] Set up archival storage (S3/GCS)
- [ ] Configure log aggregation
- [ ] Set up distributed tracing
- [ ] Configure auto-scaling based on variety metrics
- [ ] Set up backup and disaster recovery
- [ ] Configure security monitoring

### 9. Monitoring Dashboard

Create Grafana dashboards with:

1. **System Overview**
   - Variety ratios for all subsystems
   - Algedonic signal rates
   - System health scores

2. **Operational Metrics (S1)**
   - Unit performance
   - Throughput and latency
   - Error rates

3. **Coordination Metrics (S2)**
   - Inter-system communication
   - Coordination lag
   - Channel utilization

4. **Control Metrics (S3)**
   - Resource allocation efficiency
   - Audit compliance
   - Optimization scores

5. **Intelligence Metrics (S4)**
   - Pattern detection rate
   - Forecast accuracy
   - Environmental signals

6. **Policy Metrics (S5)**
   - Strategic goal progress
   - Decision quality
   - Identity alignment

This implementation guide provides a practical foundation for building a complete VSM metrics system with proper observability.