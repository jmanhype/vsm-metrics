defmodule VsmMetrics.Metrics.VarietyCalculator do
  @moduledoc """
  Variety engineering calculations based on Ashby's Law of Requisite Variety.
  Measures and manages variety in VSM subsystems for viability.
  """

  alias VsmMetrics.Entropy.ShannonCalculator

  @doc """
  Calculate variety (number of distinguishable states) from a distribution
  """
  def calculate_variety(distribution) when is_map(distribution) do
    # Variety is the number of possible states
    Map.keys(distribution) |> length()
  end

  def calculate_variety(states) when is_list(states) do
    states |> Enum.uniq() |> length()
  end

  @doc """
  Calculate requisite variety ratio
  Controller variety must match or exceed environment variety
  """
  def requisite_variety_ratio(controller_states, environment_states) do
    controller_variety = calculate_variety(controller_states)
    environment_variety = calculate_variety(environment_states)
    
    %{
      controller_variety: controller_variety,
      environment_variety: environment_variety,
      ratio: controller_variety / environment_variety,
      meets_requisite_variety?: controller_variety >= environment_variety,
      variety_deficit: max(0, environment_variety - controller_variety)
    }
  end

  @doc """
  Calculate variety amplification factor
  How much a component increases variety handling capacity
  """
  def amplification_factor(input_variety, output_variety) do
    output_variety / input_variety
  end

  @doc """
  Calculate variety attenuation factor
  How much a component reduces variety
  """
  def attenuation_factor(input_variety, output_variety) do
    input_variety / output_variety
  end

  @doc """
  Design variety amplifiers for a subsystem
  """
  def design_amplifiers(current_variety, required_variety) do
    amplification_needed = required_variety / current_variety
    
    %{
      current_variety: current_variety,
      required_variety: required_variety,
      amplification_needed: amplification_needed,
      suggested_amplifiers: suggest_amplifiers(amplification_needed)
    }
  end

  @doc """
  Design variety attenuators for a subsystem
  """
  def design_attenuators(current_variety, target_variety) do
    attenuation_needed = current_variety / target_variety
    
    %{
      current_variety: current_variety,
      target_variety: target_variety,
      attenuation_needed: attenuation_needed,
      suggested_attenuators: suggest_attenuators(attenuation_needed)
    }
  end

  @doc """
  Calculate effective variety after applying filters
  """
  def effective_variety(raw_variety, filters) do
    Enum.reduce(filters, raw_variety, fn filter, variety ->
      apply_filter(variety, filter)
    end)
  end

  @doc """
  Calculate variety flow between VSM subsystems
  """
  def variety_flow(source_subsystem, target_subsystem, channel_capacity) do
    source_variety = calculate_subsystem_variety(source_subsystem)
    target_capacity = calculate_subsystem_capacity(target_subsystem)
    
    %{
      source_variety: source_variety,
      target_capacity: target_capacity,
      channel_capacity: channel_capacity,
      effective_flow: min(source_variety, min(target_capacity, channel_capacity)),
      bottleneck: identify_bottleneck(source_variety, target_capacity, channel_capacity),
      utilization: min(source_variety, channel_capacity) / channel_capacity
    }
  end

  @doc """
  Calculate variety absorption between subsystems
  Based on information theory and channel capacity
  """
  def variety_absorption(controller, environment, channel) do
    # Calculate entropies
    controller_entropy = ShannonCalculator.shannon_entropy(controller.state_distribution)
    environment_entropy = ShannonCalculator.shannon_entropy(environment.state_distribution)
    
    # Calculate mutual information (variety absorbed)
    joint_dist = calculate_joint_distribution(controller, environment)
    mutual_info = ShannonCalculator.mutual_information(joint_dist)
    
    # Channel capacity limits absorption
    channel_capacity = channel.capacity
    actual_absorption = min(mutual_info, channel_capacity)
    
    %{
      controller_entropy: controller_entropy,
      environment_entropy: environment_entropy,
      mutual_information: mutual_info,
      channel_capacity: channel_capacity,
      actual_absorption: actual_absorption,
      absorption_efficiency: actual_absorption / environment_entropy,
      unabsorbed_variety: environment_entropy - actual_absorption
    }
  end

  @doc """
  Analyze variety engineering for entire VSM
  """
  def analyze_vsm_variety(vsm_state) do
    subsystems = [:s1, :s2, :s3, :s4, :s5]
    
    # Calculate variety for each subsystem
    subsystem_varieties = subsystems
    |> Enum.map(fn subsystem ->
      variety = calculate_subsystem_variety(vsm_state[subsystem])
      {subsystem, variety}
    end)
    |> Map.new()
    
    # Analyze variety flows between subsystems
    variety_flows = analyze_variety_flows(vsm_state, subsystem_varieties)
    
    # Identify bottlenecks and imbalances
    bottlenecks = identify_vsm_bottlenecks(variety_flows)
    
    %{
      subsystem_varieties: subsystem_varieties,
      variety_flows: variety_flows,
      bottlenecks: bottlenecks,
      recommendations: generate_recommendations(bottlenecks)
    }
  end

  # Private functions

  defp suggest_amplifiers(factor) when factor <= 1.5 do
    ["Parallel processing", "Delegation", "Pattern recognition"]
  end

  defp suggest_amplifiers(factor) when factor <= 3.0 do
    ["Hierarchical organization", "Specialization", "Automation", "Machine learning"]
  end

  defp suggest_amplifiers(_factor) do
    ["Multiple control levels", "Distributed systems", "AI augmentation", 
     "Predictive models", "Self-organizing teams"]
  end

  defp suggest_attenuators(factor) when factor <= 2.0 do
    ["Categorization", "Filtering", "Summarization"]
  end

  defp suggest_attenuators(factor) when factor <= 5.0 do
    ["Aggregation", "Statistical sampling", "Exception reporting", "Dashboards"]
  end

  defp suggest_attenuators(_factor) do
    ["Heavy filtering", "Abstraction layers", "Policy-based routing", 
     "Automated triage", "ML-based classification"]
  end

  defp apply_filter(variety, {:categorization, categories}), do: min(variety, categories)
  defp apply_filter(variety, {:sampling, rate}), do: variety * rate
  defp apply_filter(variety, {:threshold, level}), do: variety * (1 - level)
  defp apply_filter(variety, _), do: variety

  defp calculate_subsystem_variety(%{states: states}), do: length(states)
  defp calculate_subsystem_variety(%{state_distribution: dist}), do: map_size(dist)
  defp calculate_subsystem_variety(_), do: 0

  defp calculate_subsystem_capacity(%{max_states: max}), do: max
  defp calculate_subsystem_capacity(%{capacity: cap}), do: cap
  defp calculate_subsystem_capacity(_), do: :infinity

  defp identify_bottleneck(source, target, channel) do
    cond do
      channel < source and channel < target -> :channel
      target < source and target < channel -> :target_capacity
      source < channel and source < target -> :source_limited
      true -> :balanced
    end
  end

  defp calculate_joint_distribution(controller, environment) do
    # Simplified - in practice, observe actual correlations
    for {c_state, c_prob} <- controller.state_distribution,
        {e_state, e_prob} <- environment.state_distribution,
        into: %{} do
      {{c_state, e_state}, c_prob * e_prob * correlation_factor()}
    end
  end

  defp correlation_factor, do: 0.7 + :rand.uniform() * 0.3

  defp analyze_variety_flows(vsm_state, varieties) do
    # Define VSM communication channels
    channels = [
      {:s5, :s3, :operations_control},
      {:s3, :s1, :resource_bargain},
      {:s4, :s3, :plans_instructions},
      {:s2, :s3, :intelligence_alerts},
      {:s3, :s4, :feedback},
      {:environment, :s5, :disturbances},
      {:s1, :environment, :identity_broadcast}
    ]
    
    channels
    |> Enum.map(fn {source, target, channel_type} ->
      source_variety = varieties[source] || calculate_environment_variety(vsm_state)
      target_variety = varieties[target] || 0
      capacity = estimate_channel_capacity(channel_type)
      
      flow = min(source_variety, capacity)
      
      %{
        source: source,
        target: target,
        channel: channel_type,
        flow: flow,
        utilization: flow / capacity,
        constrained?: flow < source_variety
      }
    end)
  end

  defp calculate_environment_variety(%{environment: env}), do: env[:variety] || 1000
  defp calculate_environment_variety(_), do: 1000

  defp estimate_channel_capacity(channel_type) do
    case channel_type do
      :operations_control -> 500
      :resource_bargain -> 200
      :plans_instructions -> 300
      :intelligence_alerts -> 400
      :feedback -> 250
      :disturbances -> 1000
      :identity_broadcast -> 100
      _ -> 100
    end
  end

  defp identify_vsm_bottlenecks(flows) do
    flows
    |> Enum.filter(& &1.constrained?)
    |> Enum.map(fn flow ->
      %{
        channel: flow.channel,
        severity: 1 - flow.utilization,
        impact: categorize_impact(flow.channel)
      }
    end)
    |> Enum.sort_by(& &1.severity, :desc)
  end

  defp categorize_impact(channel) do
    case channel do
      :operations_control -> :critical
      :intelligence_alerts -> :high
      :resource_bargain -> :high
      :plans_instructions -> :medium
      :feedback -> :medium
      _ -> :low
    end
  end

  defp generate_recommendations(bottlenecks) do
    bottlenecks
    |> Enum.take(3)
    |> Enum.map(fn bottleneck ->
      %{
        channel: bottleneck.channel,
        recommendation: recommend_for_channel(bottleneck.channel),
        priority: bottleneck.impact
      }
    end)
  end

  defp recommend_for_channel(channel) do
    case channel do
      :operations_control -> 
        "Increase operational autonomy and delegation frameworks"
      :intelligence_alerts -> 
        "Implement intelligent filtering and priority-based routing"
      :resource_bargain -> 
        "Establish clearer resource allocation policies"
      :plans_instructions -> 
        "Simplify planning frameworks and use standardized templates"
      :feedback -> 
        "Implement automated feedback aggregation"
      _ -> 
        "Analyze channel usage patterns for optimization"
    end
  end
end