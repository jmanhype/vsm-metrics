defmodule VsmMetrics.Metrics.SubsystemMetrics do
  @moduledoc """
  Core metric collectors for each VSM subsystem (S1-S5).
  Provides real-time metric collection, aggregation, and analysis.
  """

  use GenServer
  require Logger

  alias VsmMetrics.{
    Storage.MemoryTier,
    Aggregation.CRDTAggregator,
    Entropy.ShannonCalculator,
    TimeConstants.TemporalDynamics,
    Metrics.VarietyCalculator
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a metric for a specific subsystem
  """
  def record_metric(subsystem, metric_type, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, subsystem, metric_type, value, metadata})
  end

  @doc """
  Get current metrics for a subsystem
  """
  def get_metrics(subsystem) do
    GenServer.call(__MODULE__, {:get_metrics, subsystem})
  end

  @doc """
  Get aggregated metrics across all subsystems
  """
  def get_vsm_health do
    GenServer.call(__MODULE__, :get_vsm_health)
  end

  @doc """
  Analyze inter-subsystem communication
  """
  def analyze_communication do
    GenServer.call(__MODULE__, :analyze_communication)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Initialize metric storage for each subsystem
    subsystems = [:s1, :s2, :s3, :s4, :s5]
    
    state = %{
      subsystems: subsystems,
      metrics: initialize_metrics(subsystems),
      communication_matrix: initialize_communication_matrix(subsystems),
      window_size: Keyword.get(opts, :window_size, 300), # 5 minutes
      aggregation_interval: Keyword.get(opts, :aggregation_interval, 60_000)
    }
    
    # Schedule periodic aggregation
    :timer.send_interval(state.aggregation_interval, :aggregate_metrics)
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:record_metric, subsystem, metric_type, value, metadata}, state) do
    timestamp = System.system_time(:millisecond)
    
    # Store in appropriate tier based on metric type
    metric_key = build_metric_key(subsystem, metric_type, timestamp)
    
    # Store raw metric
    MemoryTier.put(metric_key, value, Map.put(metadata, :timestamp, timestamp))
    
    # Update CRDT aggregations
    case metric_type do
      :counter -> CRDTAggregator.increment_counter("#{subsystem}_#{metric_type}", value)
      :gauge -> CRDTAggregator.update_register("#{subsystem}_#{metric_type}", value)
      :set -> CRDTAggregator.add_to_set("#{subsystem}_#{metric_type}", value)
      _ -> :ok
    end
    
    # Update subsystem-specific metrics
    new_metrics = update_subsystem_metrics(state.metrics, subsystem, metric_type, value, metadata)
    
    # Track communication if applicable
    new_state = if metadata[:target_subsystem] do
      track_communication(state, subsystem, metadata.target_subsystem, value)
    else
      state
    end
    
    {:noreply, %{new_state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:get_metrics, subsystem}, _from, state) do
    metrics = calculate_subsystem_metrics(subsystem, state)
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:get_vsm_health, _from, state) do
    health = calculate_vsm_health(state)
    {:reply, health, state}
  end

  @impl true
  def handle_call(:analyze_communication, _from, state) do
    analysis = analyze_communication_patterns(state)
    {:reply, analysis, state}
  end

  @impl true
  def handle_info(:aggregate_metrics, state) do
    # Aggregate metrics for each subsystem
    aggregated = Enum.map(state.subsystems, fn subsystem ->
      metrics = aggregate_subsystem_metrics(subsystem, state)
      {subsystem, metrics}
    end)
    |> Map.new()
    
    # Store aggregated metrics
    Enum.each(aggregated, fn {subsystem, metrics} ->
      store_aggregated_metrics(subsystem, metrics)
    end)
    
    {:noreply, state}
  end

  # Private Functions

  defp initialize_metrics(subsystems) do
    Enum.map(subsystems, fn subsystem ->
      {subsystem, %{
        operations: [],
        variety: %{},
        entropy: [],
        response_times: [],
        errors: 0,
        algedonic_signals: []
      }}
    end)
    |> Map.new()
  end

  defp initialize_communication_matrix(subsystems) do
    # Initialize NxN matrix for communication tracking
    for s1 <- subsystems, s2 <- subsystems, into: %{} do
      {{s1, s2}, %{count: 0, total_volume: 0, latencies: []}}
    end
  end

  defp build_metric_key(subsystem, metric_type, timestamp) do
    "#{subsystem}:#{metric_type}:#{timestamp}"
  end

  defp update_subsystem_metrics(metrics, subsystem, metric_type, value, metadata) do
    Map.update(metrics, subsystem, %{}, fn subsystem_metrics ->
      case metric_type do
        :operation ->
          Map.update(subsystem_metrics, :operations, [value], &([value | &1] |> Enum.take(1000)))
          
        :variety ->
          Map.update(subsystem_metrics, :variety, %{value => 1}, fn variety ->
            Map.update(variety, value, 1, &(&1 + 1))
          end)
          
        :response_time ->
          Map.update(subsystem_metrics, :response_times, [value], &([value | &1] |> Enum.take(100)))
          
        :error ->
          Map.update(subsystem_metrics, :errors, 1, &(&1 + 1))
          
        :algedonic when metadata[:severity] in [:critical, :high] ->
          signal = %{value: value, severity: metadata.severity, timestamp: metadata.timestamp}
          Map.update(subsystem_metrics, :algedonic_signals, [signal], &([signal | &1] |> Enum.take(50)))
          
        _ ->
          subsystem_metrics
      end
    end)
  end

  defp track_communication(state, source, target, volume) do
    key = {source, target}
    
    new_matrix = Map.update(state.communication_matrix, key, 
      %{count: 1, total_volume: volume, latencies: []}, 
      fn current ->
        %{current | 
          count: current.count + 1,
          total_volume: current.total_volume + volume
        }
      end)
    
    %{state | communication_matrix: new_matrix}
  end

  defp calculate_subsystem_metrics(subsystem, state) do
    metrics = state.metrics[subsystem] || %{}
    
    # Calculate variety metrics
    variety_entropy = if map_size(metrics[:variety] || %{}) > 0 do
      distribution = normalize_distribution(metrics.variety)
      ShannonCalculator.shannon_entropy(distribution)
    else
      0
    end
    
    # Calculate temporal metrics
    avg_response_time = if length(metrics[:response_times] || []) > 0 do
      Enum.sum(metrics.response_times) / length(metrics.response_times)
    else
      0
    end
    
    # Get time constants
    time_constants = TemporalDynamics.default_time_constants()[subsystem]
    
    %{
      subsystem: subsystem,
      variety_count: map_size(metrics[:variety] || %{}),
      variety_entropy: variety_entropy,
      operation_count: length(metrics[:operations] || []),
      error_rate: calculate_error_rate(metrics),
      avg_response_time: avg_response_time,
      time_constants: time_constants,
      algedonic_count: length(metrics[:algedonic_signals] || []),
      health_score: calculate_health_score(metrics, subsystem)
    }
  end

  defp calculate_vsm_health(state) do
    # Get metrics for all subsystems
    subsystem_health = Enum.map(state.subsystems, fn subsystem ->
      metrics = calculate_subsystem_metrics(subsystem, state)
      {subsystem, metrics.health_score}
    end)
    |> Map.new()
    
    # Calculate variety balance
    variety_analysis = analyze_variety_balance(state)
    
    # Calculate temporal coupling
    temporal_analysis = TemporalDynamics.temporal_stability_analysis(state.metrics, 3600)
    
    # Calculate communication efficiency
    comm_efficiency = calculate_communication_efficiency(state.communication_matrix)
    
    # Overall health score
    overall_score = calculate_overall_health(subsystem_health, variety_analysis, temporal_analysis)
    
    %{
      overall_score: overall_score,
      subsystem_health: subsystem_health,
      variety_balance: variety_analysis,
      temporal_stability: temporal_analysis.is_stable,
      communication_efficiency: comm_efficiency,
      alerts: generate_health_alerts(overall_score, subsystem_health),
      timestamp: System.system_time(:millisecond)
    }
  end

  defp analyze_communication_patterns(state) do
    # Calculate communication volumes
    volumes = state.communication_matrix
    |> Enum.map(fn {{source, target}, data} ->
      %{
        source: source,
        target: target,
        message_count: data.count,
        total_volume: data.total_volume,
        avg_message_size: if(data.count > 0, do: data.total_volume / data.count, else: 0)
      }
    end)
    |> Enum.sort_by(& &1.message_count, :desc)
    
    # Identify communication bottlenecks
    bottlenecks = identify_communication_bottlenecks(volumes)
    
    # Calculate information flow entropy
    flow_distribution = volumes
    |> Enum.map(& &1.message_count)
    |> normalize_list()
    
    flow_entropy = ShannonCalculator.shannon_entropy(flow_distribution)
    
    %{
      communication_flows: Enum.take(volumes, 10),
      bottlenecks: bottlenecks,
      flow_entropy: flow_entropy,
      recommendations: generate_communication_recommendations(bottlenecks, flow_entropy)
    }
  end

  defp aggregate_subsystem_metrics(subsystem, state) do
    metrics = state.metrics[subsystem] || %{}
    
    %{
      operation_rate: length(metrics[:operations] || []) / state.window_size,
      variety_measure: map_size(metrics[:variety] || %{}),
      error_count: metrics[:errors] || 0,
      algedonic_intensity: calculate_algedonic_intensity(metrics[:algedonic_signals] || [])
    }
  end

  defp store_aggregated_metrics(subsystem, metrics) do
    timestamp = System.system_time(:millisecond)
    key = "#{subsystem}:aggregated:#{timestamp}"
    
    # Store in warm tier for medium-term analysis
    VsmMetrics.Storage.ETSTier.put(key, metrics, %{
      subsystem: subsystem,
      type: :aggregated,
      timestamp: timestamp
    })
  end

  # Helper functions

  defp normalize_distribution(frequency_map) do
    total = frequency_map |> Map.values() |> Enum.sum()
    
    if total > 0 do
      Map.new(frequency_map, fn {k, v} -> {k, v / total} end)
    else
      %{}
    end
  end

  defp normalize_list(list) do
    total = Enum.sum(list)
    if total > 0 do
      Enum.map(list, &(&1 / total))
    else
      list
    end
  end

  defp calculate_error_rate(metrics) do
    operations = length(metrics[:operations] || [])
    errors = metrics[:errors] || 0
    
    if operations > 0 do
      errors / operations
    else
      0
    end
  end

  defp calculate_health_score(metrics, subsystem) do
    # Weighted scoring based on subsystem characteristics
    error_weight = case subsystem do
      :s1 -> 0.1  # Policy errors less critical
      :s3 -> 0.4  # Control errors very critical
      _ -> 0.2
    end
    
    variety_weight = case subsystem do
      :s2 -> 0.4  # Intelligence needs high variety
      :s5 -> 0.3  # Operations need good variety
      _ -> 0.2
    end
    
    response_weight = 1 - error_weight - variety_weight
    
    # Calculate component scores
    error_score = 1 - min(1, calculate_error_rate(metrics))
    variety_score = min(1, map_size(metrics[:variety] || %{}) / 100)
    response_score = if length(metrics[:response_times] || []) > 0 do
      avg_time = Enum.sum(metrics.response_times) / length(metrics.response_times)
      1 / (1 + avg_time / 1000)  # Normalize to seconds
    else
      0.5
    end
    
    # Weighted average
    error_score * error_weight + variety_score * variety_weight + response_score * response_weight
  end

  defp analyze_variety_balance(state) do
    varieties = Enum.map(state.subsystems, fn subsystem ->
      variety_count = map_size(state.metrics[subsystem][:variety] || %{})
      {subsystem, variety_count}
    end)
    |> Map.new()
    
    # Check key variety relationships
    s3_s5_ratio = if varieties[:s5] > 0, do: varieties[:s3] / varieties[:s5], else: 0
    s2_environment_ratio = varieties[:s2] / 1000  # Assume environment variety of 1000
    
    %{
      subsystem_varieties: varieties,
      s3_controls_s5: s3_s5_ratio >= 1.0,
      s2_monitors_environment: s2_environment_ratio >= 0.1,
      variety_imbalances: identify_variety_imbalances(varieties)
    }
  end

  defp identify_variety_imbalances(varieties) do
    # Check VSM variety requirements
    imbalances = []
    
    # S3 must have variety >= S5
    imbalances = if varieties[:s3] < varieties[:s5] do
      [{:s3_s5_imbalance, varieties[:s3] / max(1, varieties[:s5])} | imbalances]
    else
      imbalances
    end
    
    # S2 must have adequate variety for environment
    imbalances = if varieties[:s2] < 100 do
      [{:s2_insufficient, varieties[:s2]} | imbalances]
    else
      imbalances
    end
    
    imbalances
  end

  defp calculate_communication_efficiency(matrix) do
    total_messages = matrix
    |> Map.values()
    |> Enum.map(& &1.count)
    |> Enum.sum()
    
    if total_messages > 0 do
      # Calculate average path length
      active_channels = Enum.count(matrix, fn {_k, v} -> v.count > 0 end)
      total_channels = map_size(matrix)
      
      active_channels / total_channels
    else
      0
    end
  end

  defp identify_communication_bottlenecks(volumes) do
    # Find channels with high volume
    total_volume = volumes |> Enum.map(& &1.message_count) |> Enum.sum()
    
    volumes
    |> Enum.filter(fn flow ->
      flow.message_count > total_volume * 0.2  # More than 20% of total
    end)
    |> Enum.map(fn flow ->
      %{
        channel: {flow.source, flow.target},
        load: flow.message_count / total_volume,
        severity: :high
      }
    end)
  end

  defp calculate_algedonic_intensity(signals) do
    if length(signals) > 0 do
      critical_count = Enum.count(signals, & &1.severity == :critical)
      high_count = Enum.count(signals, & &1.severity == :high)
      
      (critical_count * 10 + high_count * 5) / length(signals)
    else
      0
    end
  end

  defp calculate_overall_health(subsystem_health, variety_analysis, temporal_analysis) do
    # Average subsystem health
    avg_subsystem = subsystem_health
    |> Map.values()
    |> Enum.sum()
    |> Kernel./(map_size(subsystem_health))
    
    # Variety penalty
    variety_penalty = length(variety_analysis.variety_imbalances) * 0.1
    
    # Temporal penalty
    temporal_penalty = if temporal_analysis.is_stable, do: 0, else: 0.3
    
    # Calculate final score
    max(0, avg_subsystem - variety_penalty - temporal_penalty)
  end

  defp generate_health_alerts(overall_score, subsystem_health) do
    alerts = []
    
    # Overall health alert
    alerts = if overall_score < 0.5 do
      [{:critical, "VSM health critical: #{Float.round(overall_score, 2)}"} | alerts]
    else
      alerts
    end
    
    # Subsystem alerts
    subsystem_alerts = subsystem_health
    |> Enum.filter(fn {_subsystem, score} -> score < 0.6 end)
    |> Enum.map(fn {subsystem, score} ->
      {:warning, "#{subsystem} health low: #{Float.round(score, 2)}"}
    end)
    
    alerts ++ subsystem_alerts
  end

  defp generate_communication_recommendations(bottlenecks, flow_entropy) do
    recommendations = []
    
    # Bottleneck recommendations
    recommendations = recommendations ++ Enum.map(bottlenecks, fn bottleneck ->
      "Optimize communication channel #{inspect(bottleneck.channel)} - handling #{Float.round(bottleneck.load * 100, 1)}% of traffic"
    end)
    
    # Entropy recommendations
    recommendations = if flow_entropy < 2.0 do
      ["Increase communication distribution - current entropy: #{Float.round(flow_entropy, 2)}" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end