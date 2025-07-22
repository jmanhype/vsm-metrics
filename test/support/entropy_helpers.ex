defmodule VSMMetrics.Test.EntropyHelpers do
  @moduledoc """
  Helper functions for testing entropy calculations in VSM Metrics.
  """

  @doc """
  Generates a probability distribution with specified characteristics.
  """
  def generate_distribution(type, size) do
    case type do
      :uniform ->
        # All probabilities equal
        p = 1.0 / size
        List.duplicate(p, size)
        
      :gaussian ->
        # Normal distribution discretized
        values = for i <- 1..size do
          x = (i - size/2) / (size/4)
          :math.exp(-x * x / 2)
        end
        total = Enum.sum(values)
        Enum.map(values, &(&1 / total))
        
      :exponential ->
        # Exponential decay
        lambda = 2.0 / size
        values = for i <- 1..size do
          :math.exp(-lambda * i)
        end
        total = Enum.sum(values)
        Enum.map(values, &(&1 / total))
        
      :power_law ->
        # Power law distribution (Zipf-like)
        alpha = 1.5
        values = for i <- 1..size do
          1.0 / :math.pow(i, alpha)
        end
        total = Enum.sum(values)
        Enum.map(values, &(&1 / total))
        
      :sparse ->
        # Most probability mass on few states
        dist = List.duplicate(0.01, size)
        # Put 90% mass on first 10% of states
        concentrated = round(size * 0.1)
        mass_each = 0.9 / concentrated
        
        Enum.with_index(dist)
        |> Enum.map(fn {_, i} ->
          if i < concentrated, do: mass_each, else: 0.01 / (size - concentrated)
        end)
        |> normalize_distribution()
    end
  end

  @doc """
  Normalizes a distribution to sum to 1.0.
  """
  def normalize_distribution(values) do
    total = Enum.sum(values)
    if total == 0 do
      uniform_size = length(values)
      List.duplicate(1.0 / uniform_size, uniform_size)
    else
      Enum.map(values, &(&1 / total))
    end
  end

  @doc """
  Calculates theoretical entropy bounds for a distribution.
  """
  def entropy_bounds(distribution) do
    n = length(distribution)
    
    # Filter out zeros for min entropy calculation
    non_zero = Enum.filter(distribution, &(&1 > 0))
    k = length(non_zero)
    
    %{
      min: 0.0,  # Single certain state
      max: :math.log2(k),  # Uniform over non-zero states
      theoretical_max: :math.log2(n)  # If all states had non-zero probability
    }
  end

  @doc """
  Generates test cases for variety absorption.
  """
  def variety_test_cases do
    [
      # Perfect absorption (no variety passes through)
      %{
        name: "Perfect absorption",
        input_states: 16,
        output_states: 1,
        expected_absorption: :math.log2(16)  # 4 bits
      },
      
      # No absorption (all variety passes through)
      %{
        name: "No absorption",
        input_states: 8,
        output_states: 8,
        expected_absorption: 0.0
      },
      
      # Partial absorption
      %{
        name: "Half absorption",
        input_states: 16,
        output_states: 4,
        expected_absorption: 2.0  # log2(16) - log2(4) = 4 - 2 = 2
      },
      
      # Amplification (should not be possible in theory)
      %{
        name: "Amplification attempt",
        input_states: 4,
        output_states: 16,
        expected_absorption: -2.0  # Negative means amplification
      }
    ]
  end

  @doc """
  Simulates variety flow through a system.
  """
  def simulate_variety_flow(stages) do
    Enum.map_reduce(stages, nil, fn stage, prev_output ->
      input = prev_output || stage.input
      
      # Apply variety engineering
      output = case stage.type do
        :attenuator ->
          # Reduces variety
          min(input, input * stage.factor)
          
        :amplifier ->
          # Cannot truly create variety, only reveal latent variety
          min(input, stage.max_output)
          
        :filter ->
          # Selective variety reduction
          input * (1 - stage.rejection_rate)
          
        :buffer ->
          # Delays but preserves variety
          input
      end
      
      absorbed = max(0, input - output)
      
      result = %{
        stage: stage.name,
        input_variety: input,
        output_variety: output,
        absorbed_variety: absorbed,
        efficiency: if(input > 0, do: output / input, else: 1.0)
      }
      
      {result, output}
    end)
    |> elem(0)
  end

  @doc """
  Tests Ashby's Law of Requisite Variety.
  """
  def test_requisite_variety(system_variety, disturbance_variety, regulator_variety) do
    # The variety of outcomes must be at least:
    # V(outcomes) >= V(disturbances) - V(regulator)
    
    required_variety = max(0, disturbance_variety - regulator_variety)
    
    %{
      sufficient: system_variety >= required_variety,
      required_variety: required_variety,
      actual_variety: system_variety,
      surplus_variety: max(0, system_variety - required_variety),
      deficit_variety: max(0, required_variety - system_variety)
    }
  end

  @doc """
  Generates entropy test vectors with known results.
  """
  def entropy_test_vectors do
    [
      # Uniform distributions
      %{
        distribution: [0.5, 0.5],
        expected_entropy: 1.0,
        description: "Fair coin"
      },
      %{
        distribution: [0.25, 0.25, 0.25, 0.25],
        expected_entropy: 2.0,
        description: "Fair 4-sided die"
      },
      %{
        distribution: List.duplicate(0.125, 8),
        expected_entropy: 3.0,
        description: "Fair 8-sided die"
      },
      
      # Certain events
      %{
        distribution: [1.0],
        expected_entropy: 0.0,
        description: "Certain event"
      },
      %{
        distribution: [0.0, 1.0, 0.0],
        expected_entropy: 0.0,
        description: "Certain middle event"
      },
      
      # Biased distributions
      %{
        distribution: [0.9, 0.1],
        expected_entropy: -0.9 * :math.log2(0.9) - 0.1 * :math.log2(0.1),
        description: "Heavily biased coin"
      },
      %{
        distribution: [0.7, 0.2, 0.1],
        expected_entropy: -0.7 * :math.log2(0.7) - 0.2 * :math.log2(0.2) - 0.1 * :math.log2(0.1),
        description: "Biased 3-state system"
      }
    ]
  end

  @doc """
  Tests entropy calculation precision.
  """
  def test_entropy_precision(calculator_fn) do
    test_vectors = entropy_test_vectors()
    
    results = Enum.map(test_vectors, fn test ->
      calculated = calculator_fn.(test.distribution)
      error = abs(calculated - test.expected_entropy)
      
      %{
        description: test.description,
        expected: test.expected_entropy,
        calculated: calculated,
        error: error,
        passed: error < 0.0001  # Tolerance
      }
    end)
    
    %{
      results: results,
      all_passed: Enum.all?(results, & &1.passed),
      max_error: Enum.max_by(results, & &1.error).error,
      mean_error: Enum.sum(Enum.map(results, & &1.error)) / length(results)
    }
  end
end