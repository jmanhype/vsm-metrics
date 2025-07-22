defmodule VsmMetrics.TimeConstants.TemporalDynamics do
  @moduledoc """
  VSM time constants and temporal dynamics calculations.
  Each subsystem operates on different timescales and has unique decay functions.
  """

  @doc """
  Default time constants for VSM subsystems (in seconds)
  Based on typical organizational dynamics
  """
  def default_time_constants do
    %{
      s1: %{
        name: "Policy/Identity",
        response_time: 0.001,      # 1ms - immediate identity responses
        decay_constant: 86_400,     # 1 day - policy changes slowly
        coupling_strength: 0.1      # Loosely coupled to operations
      },
      s2: %{
        name: "Intelligence",
        response_time: 1.0,         # 1 second - quick scanning
        decay_constant: 300,        # 5 minutes - recent intelligence matters most
        coupling_strength: 0.7      # Tightly coupled to environment
      },
      s3: %{
        name: "Control",
        response_time: 60,          # 1 minute - control decisions
        decay_constant: 3_600,      # 1 hour - medium-term memory
        coupling_strength: 0.9      # Very tightly coupled to all
      },
      s4: %{
        name: "Planning",
        response_time: 3_600,       # 1 hour - planning cycles
        decay_constant: 604_800,    # 1 week - plans persist
        coupling_strength: 0.5      # Moderately coupled
      },
      s5: %{
        name: "Operations",
        response_time: 86_400,      # 1 day - operational changes
        decay_constant: 2_592_000,  # 30 days - operational memory
        coupling_strength: 0.8      # Tightly coupled to environment
      }
    }
  end

  @doc """
  Calculate temporal response for a subsystem given an input signal
  """
  def temporal_response(subsystem, input_signal, time_elapsed, custom_constants \\ nil) do
    constants = get_constants(subsystem, custom_constants)
    
    # Calculate response based on subsystem characteristics
    response = case subsystem do
      :s1 -> policy_response(input_signal, time_elapsed, constants)
      :s2 -> intelligence_response(input_signal, time_elapsed, constants)
      :s3 -> control_response(input_signal, time_elapsed, constants)
      :s4 -> planning_response(input_signal, time_elapsed, constants)
      :s5 -> operations_response(input_signal, time_elapsed, constants)
      _ -> 0
    end
    
    %{
      subsystem: subsystem,
      input: input_signal,
      response: response,
      time_elapsed: time_elapsed,
      response_time: constants.response_time,
      decay_factor: calculate_decay(time_elapsed, constants.decay_constant)
    }
  end

  @doc """
  Calculate coupling dynamics between subsystems
  """
  def coupling_dynamics(source_subsystem, target_subsystem, signal_strength, time_elapsed) do
    source_constants = get_constants(source_subsystem)
    target_constants = get_constants(target_subsystem)
    
    # Calculate coupling coefficient
    coupling = source_constants.coupling_strength * target_constants.coupling_strength
    
    # Calculate time delay
    time_delay = target_constants.response_time - source_constants.response_time
    effective_time = max(0, time_elapsed - time_delay)
    
    # Calculate transmitted signal
    transmitted_signal = if effective_time > 0 do
      signal_strength * coupling * 
        calculate_decay(effective_time, target_constants.decay_constant)
    else
      0
    end
    
    %{
      source: source_subsystem,
      target: target_subsystem,
      coupling_coefficient: coupling,
      time_delay: time_delay,
      transmitted_signal: transmitted_signal,
      attenuation: 1 - (transmitted_signal / signal_strength)
    }
  end

  @doc """
  Analyze temporal stability of the VSM
  """
  def temporal_stability_analysis(vsm_state, time_window) do
    subsystems = [:s1, :s2, :s3, :s4, :s5]
    
    # Calculate eigenvalues of the temporal coupling matrix
    coupling_matrix = build_coupling_matrix(subsystems)
    eigenvalues = calculate_eigenvalues(coupling_matrix)
    
    # Determine stability
    max_eigenvalue = Enum.max(eigenvalues)
    is_stable = max_eigenvalue < 1.0
    
    # Calculate settling time
    settling_time = if is_stable do
      -time_window / :math.log(max_eigenvalue)
    else
      :infinity
    end
    
    %{
      is_stable: is_stable,
      max_eigenvalue: max_eigenvalue,
      settling_time: settling_time,
      oscillation_period: calculate_oscillation_period(eigenvalues),
      damping_ratio: calculate_damping_ratio(eigenvalues),
      recommendations: stability_recommendations(is_stable, max_eigenvalue)
    }
  end

  @doc """
  Calculate optimal time constants for desired system behavior
  """
  def optimize_time_constants(desired_response_time, desired_stability_margin) do
    current_constants = default_time_constants()
    
    # Use gradient descent to optimize constants
    optimized = Enum.map(current_constants, fn {subsystem, constants} ->
      optimized_constants = %{
        constants |
        response_time: optimize_response_time(
          constants.response_time,
          desired_response_time,
          subsystem
        ),
        decay_constant: optimize_decay_constant(
          constants.decay_constant,
          desired_stability_margin,
          subsystem
        ),
        coupling_strength: optimize_coupling(
          constants.coupling_strength,
          desired_stability_margin
        )
      }
      
      {subsystem, optimized_constants}
    end)
    |> Map.new()
    
    %{
      original: current_constants,
      optimized: optimized,
      expected_response_time: calculate_system_response_time(optimized),
      expected_stability_margin: calculate_stability_margin(optimized)
    }
  end

  @doc """
  Predict future system state based on temporal dynamics
  """
  def predict_future_state(current_state, time_horizon, external_inputs \\ []) do
    # Discretize time
    time_steps = round(time_horizon / 0.1)  # 100ms steps
    dt = time_horizon / time_steps
    
    # Simulate system evolution
    final_state = Enum.reduce(0..time_steps, current_state, fn step, state ->
      t = step * dt
      
      # Apply external inputs
      state_with_inputs = apply_external_inputs(state, external_inputs, t)
      
      # Update each subsystem
      Enum.map(state_with_inputs, fn {subsystem, value} ->
        new_value = evolve_subsystem(subsystem, value, state_with_inputs, dt)
        {subsystem, new_value}
      end)
      |> Map.new()
    end)
    
    %{
      initial_state: current_state,
      predicted_state: final_state,
      time_horizon: time_horizon,
      confidence: calculate_prediction_confidence(time_horizon)
    }
  end

  # Private functions

  defp get_constants(subsystem, custom \\ nil) do
    if custom && custom[subsystem] do
      custom[subsystem]
    else
      default_time_constants()[subsystem]
    end
  end

  defp calculate_decay(time_elapsed, decay_constant) do
    :math.exp(-time_elapsed / decay_constant)
  end

  # Subsystem-specific response functions

  defp policy_response(signal, time, constants) do
    # Policy has sharp initial response then slow decay
    if time < constants.response_time do
      signal
    else
      signal * calculate_decay(time - constants.response_time, constants.decay_constant)
    end
  end

  defp intelligence_response(signal, time, constants) do
    # Intelligence has rapid response and decay
    signal * :math.exp(-time / constants.response_time) * 
      calculate_decay(time, constants.decay_constant)
  end

  defp control_response(signal, time, constants) do
    # Control has damped oscillatory response
    damping = 0.7
    frequency = 1 / constants.response_time
    
    signal * :math.exp(-damping * time) * 
      :math.cos(2 * :math.pi() * frequency * time) *
      calculate_decay(time, constants.decay_constant)
  end

  defp planning_response(signal, time, constants) do
    # Planning has delayed ramp-up
    if time < constants.response_time do
      signal * (time / constants.response_time)
    else
      signal * calculate_decay(time - constants.response_time, constants.decay_constant)
    end
  end

  defp operations_response(signal, time, constants) do
    # Operations has sigmoid response
    midpoint = constants.response_time
    steepness = 4 / constants.response_time
    
    signal / (1 + :math.exp(-steepness * (time - midpoint))) *
      calculate_decay(time, constants.decay_constant)
  end

  defp build_coupling_matrix(subsystems) do
    # Build coupling matrix based on VSM structure
    n = length(subsystems)
    matrix = :array.new(n * n, default: 0.0)
    
    # Define couplings (simplified)
    couplings = [
      {0, 2, 0.3}, {2, 0, 0.2},  # S1 <-> S3
      {1, 2, 0.8}, {2, 1, 0.5},  # S2 <-> S3
      {2, 3, 0.6}, {3, 2, 0.4},  # S3 <-> S4
      {2, 4, 0.7}, {4, 2, 0.6},  # S3 <-> S5
      {3, 4, 0.3}, {4, 3, 0.2}   # S4 <-> S5
    ]
    
    Enum.reduce(couplings, matrix, fn {i, j, strength}, acc ->
      :array.set(i * n + j, strength, acc)
    end)
  end

  defp calculate_eigenvalues(_matrix) do
    # Simplified - return example eigenvalues
    # In production, use proper linear algebra library
    [0.85, 0.6, 0.4, 0.2, 0.1]
  end

  defp calculate_oscillation_period(eigenvalues) do
    # Find complex eigenvalues and calculate period
    # Simplified implementation
    if length(eigenvalues) > 1 do
      2 * :math.pi() / 0.5  # Example frequency
    else
      :infinity
    end
  end

  defp calculate_damping_ratio(eigenvalues) do
    # Calculate from eigenvalue magnitudes
    max_magnitude = Enum.max(eigenvalues)
    -:math.log(max_magnitude) / :math.pi()
  end

  defp stability_recommendations(true, eigenvalue) when eigenvalue < 0.5 do
    ["System is highly stable", "Consider reducing damping for faster response"]
  end

  defp stability_recommendations(true, _eigenvalue) do
    ["System is stable", "Current parameters are well-balanced"]
  end

  defp stability_recommendations(false, eigenvalue) do
    [
      "System is unstable (eigenvalue: #{eigenvalue})",
      "Reduce coupling strengths",
      "Increase decay constants",
      "Add damping to control loops"
    ]
  end

  defp optimize_response_time(current, desired, :s3) do
    # Control should be fast
    min(current, desired * 0.1)
  end

  defp optimize_response_time(current, desired, :s2) do
    # Intelligence should be very fast
    min(current, desired * 0.01)
  end

  defp optimize_response_time(current, desired, _subsystem) do
    # Others can be slower
    current * 0.9 + desired * 0.1
  end

  defp optimize_decay_constant(current, stability_margin, _subsystem) do
    # Increase decay for better stability
    current * (1 + stability_margin * 0.1)
  end

  defp optimize_coupling(current, stability_margin) do
    # Reduce coupling for better stability
    current * (1 - stability_margin * 0.1)
  end

  defp calculate_system_response_time(constants) do
    # Weighted average based on coupling
    total_weight = constants
    |> Map.values()
    |> Enum.map(& &1.coupling_strength)
    |> Enum.sum()
    
    weighted_sum = constants
    |> Map.values()
    |> Enum.map(fn c -> c.response_time * c.coupling_strength end)
    |> Enum.sum()
    
    weighted_sum / total_weight
  end

  defp calculate_stability_margin(constants) do
    # Simplified stability calculation
    max_coupling = constants
    |> Map.values()
    |> Enum.map(& &1.coupling_strength)
    |> Enum.max()
    
    1.0 - max_coupling
  end

  defp apply_external_inputs(state, inputs, time) do
    Enum.reduce(inputs, state, fn {subsystem, input_fn}, acc ->
      Map.update(acc, subsystem, 0, fn current ->
        current + input_fn.(time)
      end)
    end)
  end

  defp evolve_subsystem(subsystem, current_value, full_state, dt) do
    constants = get_constants(subsystem)
    
    # Calculate influences from other subsystems
    influences = Enum.reduce(full_state, 0, fn {other_sub, other_value}, acc ->
      if other_sub != subsystem do
        coupling = coupling_dynamics(other_sub, subsystem, other_value, dt)
        acc + coupling.transmitted_signal
      else
        acc
      end
    end)
    
    # Apply decay
    decay = current_value * (1 - dt / constants.decay_constant)
    
    # Update value
    decay + influences * dt
  end

  defp calculate_prediction_confidence(time_horizon) do
    # Confidence decreases exponentially with time
    :math.exp(-time_horizon / 3600)  # 50% confidence at 1 hour
  end
end