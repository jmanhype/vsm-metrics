defmodule VsmMetrics do
  @moduledoc """
  VsmMetrics is an Elixir-based Viable System Model (VSM) metrics and observability system.
  
  It provides:
  - Multi-tier storage (Memory, ETS, DETS) for efficient metric storage
  - CRDT-based aggregation for distributed systems
  - Shannon entropy calculations for information theory metrics
  - Variety engineering based on Ashby's Law
  - VSM time constants and temporal dynamics
  - Real-time monitoring of all 5 VSM subsystems
  
  ## Quick Start
  
      # Record a metric
      VsmMetrics.record(:s3, :operation, "control_decision", %{impact: :high})
      
      # Get subsystem health
      VsmMetrics.health(:s3)
      
      # Analyze variety balance
      VsmMetrics.variety_analysis()
      
      # Check temporal stability
      VsmMetrics.temporal_analysis()
  """

  alias VsmMetrics.{
    Metrics.SubsystemMetrics,
    Entropy.ShannonCalculator,
    Metrics.VarietyCalculator,
    TimeConstants.TemporalDynamics,
    Aggregation.CRDTAggregator
  }

  @doc """
  Record a metric for a VSM subsystem.
  
  ## Parameters
    - subsystem: One of :s1, :s2, :s3, :s4, :s5
    - metric_type: :operation, :variety, :response_time, :error, :algedonic
    - value: The metric value
    - metadata: Additional context (optional)
  
  ## Examples
      iex> VsmMetrics.record(:s3, :operation, "approve_request")
      :ok
      
      iex> VsmMetrics.record(:s5, :response_time, 150.5, %{unit: :milliseconds})
      :ok
      
      iex> VsmMetrics.record(:s1, :algedonic, "budget_exceeded", %{severity: :critical})
      :ok
  """
  def record(subsystem, metric_type, value, metadata \\ %{}) do
    SubsystemMetrics.record_metric(subsystem, metric_type, value, metadata)
  end

  @doc """
  Get current health status for a subsystem.
  
  ## Examples
      iex> VsmMetrics.health(:s3)
      %{
        subsystem: :s3,
        health_score: 0.85,
        variety_entropy: 4.2,
        error_rate: 0.02,
        avg_response_time: 45.3
      }
  """
  def health(subsystem) do
    SubsystemMetrics.get_metrics(subsystem)
  end

  @doc """
  Get overall VSM system health.
  
  ## Examples
      iex> VsmMetrics.system_health()
      %{
        overall_score: 0.78,
        subsystem_health: %{s1: 0.9, s2: 0.8, s3: 0.75, s4: 0.7, s5: 0.85},
        temporal_stability: true,
        communication_efficiency: 0.65
      }
  """
  def system_health do
    SubsystemMetrics.get_vsm_health()
  end

  @doc """
  Analyze variety balance across the VSM.
  
  ## Examples
      iex> VsmMetrics.variety_analysis()
      %{
        s3_controls_s5: true,
        s2_monitors_environment: false,
        recommendations: ["Increase S2 variety with more sensors"]
      }
  """
  def variety_analysis do
    vsm_state = get_current_vsm_state()
    VarietyCalculator.analyze_vsm_variety(vsm_state)
  end

  @doc """
  Analyze temporal dynamics and stability.
  
  ## Examples
      iex> VsmMetrics.temporal_analysis()
      %{
        is_stable: true,
        settling_time: 3600.0,
        oscillation_period: :infinity
      }
  """
  def temporal_analysis(time_window \\ 3600) do
    vsm_state = get_current_vsm_state()
    TemporalDynamics.temporal_stability_analysis(vsm_state, time_window)
  end

  @doc """
  Calculate Shannon entropy for a distribution.
  
  ## Examples
      iex> VsmMetrics.entropy(%{a: 0.5, b: 0.5})
      1.0
      
      iex> VsmMetrics.entropy([0.25, 0.25, 0.25, 0.25])
      2.0
  """
  def entropy(distribution) do
    ShannonCalculator.shannon_entropy(distribution)
  end

  @doc """
  Calculate channel capacity between subsystems.
  
  ## Examples
      iex> VsmMetrics.channel_capacity(:s2, :s3)
      %{
        capacity: 400,
        current_utilization: 0.75,
        available_capacity: 100
      }
  """
  def channel_capacity(source, target) do
    # Get communication stats
    comm_analysis = SubsystemMetrics.analyze_communication()
    
    # Find the specific channel
    channel_stats = Enum.find(comm_analysis.communication_flows, fn flow ->
      flow.source == source && flow.target == target
    end)
    
    if channel_stats do
      %{
        capacity: estimate_capacity(source, target),
        current_utilization: channel_stats.total_volume,
        message_count: channel_stats.message_count,
        avg_message_size: channel_stats.avg_message_size
      }
    else
      %{capacity: estimate_capacity(source, target), current_utilization: 0}
    end
  end

  @doc """
  Get time constants for a subsystem.
  
  ## Examples
      iex> VsmMetrics.time_constants(:s3)
      %{
        response_time: 60,
        decay_constant: 3600,
        coupling_strength: 0.9
      }
  """
  def time_constants(subsystem) do
    TemporalDynamics.default_time_constants()[subsystem]
  end

  @doc """
  Predict future system state.
  
  ## Examples
      iex> VsmMetrics.predict_state(3600)  # 1 hour ahead
      %{
        predicted_state: %{s1: 0.8, s2: 0.7, ...},
        confidence: 0.67
      }
  """
  def predict_state(time_horizon, external_inputs \\ []) do
    current_state = get_current_vsm_state()
    TemporalDynamics.predict_future_state(current_state, time_horizon, external_inputs)
  end

  @doc """
  Get distributed metric value using CRDT.
  
  ## Examples
      iex> VsmMetrics.get_metric("s3_counter")
      42
  """
  def get_metric(metric_name) do
    CRDTAggregator.get_value(metric_name)
  end

  # Private functions

  defp get_current_vsm_state do
    # Build current state from metrics
    %{
      s1: SubsystemMetrics.get_metrics(:s1),
      s2: SubsystemMetrics.get_metrics(:s2),
      s3: SubsystemMetrics.get_metrics(:s3),
      s4: SubsystemMetrics.get_metrics(:s4),
      s5: SubsystemMetrics.get_metrics(:s5),
      environment: %{variety: 1000}
    }
  end

  defp estimate_capacity(source, target) do
    # Estimate based on VSM structure
    case {source, target} do
      {:s5, :s3} -> 500
      {:s3, :s1} -> 200
      {:s4, :s3} -> 300
      {:s2, :s3} -> 400
      {:s3, :s4} -> 250
      _ -> 100
    end
  end
end