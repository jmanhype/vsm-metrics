defmodule VsmMetrics.Entropy.ShannonCalculator do
  @moduledoc """
  Shannon entropy calculator for measuring information content and uncertainty
  in VSM subsystems. Implements various entropy measures including joint,
  conditional, and mutual information.
  """

  @doc """
  Calculate Shannon entropy H(X) = -Σ p(x) * log2(p(x))
  
  ## Parameters
    - distribution: Map of value => probability or list of probabilities
    
  ## Examples
      iex> VsmMetrics.Entropy.ShannonCalculator.shannon_entropy(%{a: 0.5, b: 0.5})
      1.0
      
      iex> VsmMetrics.Entropy.ShannonCalculator.shannon_entropy([0.25, 0.25, 0.25, 0.25])
      2.0
  """
  def shannon_entropy(distribution) when is_map(distribution) do
    distribution
    |> Map.values()
    |> shannon_entropy()
  end

  def shannon_entropy(probabilities) when is_list(probabilities) do
    probabilities
    |> Enum.filter(&(&1 > 0))
    |> Enum.reduce(0, fn p, acc ->
      acc - p * log2(p)
    end)
  end

  @doc """
  Calculate joint entropy H(X,Y) for two random variables
  """
  def joint_entropy(joint_distribution) do
    joint_distribution
    |> Enum.reduce(0, fn {{_x, _y}, p}, acc ->
      if p > 0 do
        acc - p * log2(p)
      else
        acc
      end
    end)
  end

  @doc """
  Calculate conditional entropy H(X|Y) = H(X,Y) - H(Y)
  """
  def conditional_entropy(joint_distribution) do
    h_xy = joint_entropy(joint_distribution)
    
    # Calculate marginal distribution of Y
    y_marginal = joint_distribution
    |> Enum.reduce(%{}, fn {{_x, y}, p}, acc ->
      Map.update(acc, y, p, &(&1 + p))
    end)
    
    h_y = shannon_entropy(y_marginal)
    
    h_xy - h_y
  end

  @doc """
  Calculate mutual information I(X;Y) = H(X) + H(Y) - H(X,Y)
  """
  def mutual_information(joint_distribution) do
    # Calculate marginal distributions
    x_marginal = joint_distribution
    |> Enum.reduce(%{}, fn {{x, _y}, p}, acc ->
      Map.update(acc, x, p, &(&1 + p))
    end)
    
    y_marginal = joint_distribution
    |> Enum.reduce(%{}, fn {{_x, y}, p}, acc ->
      Map.update(acc, y, p, &(&1 + p))
    end)
    
    h_x = shannon_entropy(x_marginal)
    h_y = shannon_entropy(y_marginal)
    h_xy = joint_entropy(joint_distribution)
    
    h_x + h_y - h_xy
  end

  @doc """
  Calculate Kullback-Leibler divergence D_KL(P||Q)
  Measures the difference between two probability distributions
  """
  def kl_divergence(p_dist, q_dist) do
    keys = Map.keys(p_dist) ++ Map.keys(q_dist) |> Enum.uniq()
    
    Enum.reduce(keys, 0, fn key, acc ->
      p = Map.get(p_dist, key, 0)
      q = Map.get(q_dist, key, 0)
      
      if p > 0 and q > 0 do
        acc + p * log2(p / q)
      else
        acc
      end
    end)
  end

  @doc """
  Calculate channel capacity for a given channel matrix
  Maximum mutual information over all input distributions
  """
  def channel_capacity(channel_matrix) do
    # Simplified calculation using uniform input distribution
    # In production, use iterative algorithm (Blahut-Arimoto)
    input_size = length(channel_matrix)
    uniform_input = List.duplicate(1.0 / input_size, input_size)
    
    # Calculate output distribution
    output_dist = calculate_output_distribution(uniform_input, channel_matrix)
    
    # Calculate mutual information
    mutual_info = 0
    
    for {i, p_x} <- Enum.with_index(uniform_input),
        {j, p_y} <- Enum.with_index(output_dist),
        p_xy = Enum.at(Enum.at(channel_matrix, i), j) * p_x,
        p_xy > 0 do
      mutual_info + p_xy * log2(p_xy / (p_x * p_y))
    end
    |> Enum.sum()
  end

  @doc """
  Calculate entropy rate for a time series
  Measures the average information content per symbol
  """
  def entropy_rate(time_series, order \\ 1) do
    # Create n-grams of specified order
    ngrams = create_ngrams(time_series, order + 1)
    
    # Calculate joint and conditional distributions
    _joint_dist = calculate_distribution(ngrams)
    
    if order == 0 do
      # For order 0, just return the entropy of individual symbols
      time_series
      |> calculate_distribution()
      |> shannon_entropy()
    else
      # For higher orders, calculate conditional entropy
      conditional_entropy_from_ngrams(ngrams)
    end
  end

  @doc """
  Calculate variety absorption between subsystems
  Based on Ashby's Law of Requisite Variety
  """
  def variety_absorption(controller_variety, environment_variety) do
    %{
      controller_variety: controller_variety,
      environment_variety: environment_variety,
      variety_ratio: controller_variety / environment_variety,
      absorption_rate: min(1.0, controller_variety / environment_variety),
      unabsorbed_variety: max(0, environment_variety - controller_variety),
      requisite_variety_met?: controller_variety >= environment_variety
    }
  end

  # Private functions

  defp log2(x) when x > 0, do: :math.log(x) / :math.log(2)
  defp log2(_), do: 0

  defp calculate_output_distribution(input_dist, channel_matrix) do
    output_size = length(hd(channel_matrix))
    
    for j <- 0..(output_size - 1) do
      Enum.zip(input_dist, channel_matrix)
      |> Enum.reduce(0, fn {p_x, row}, acc ->
        acc + p_x * Enum.at(row, j)
      end)
    end
  end

  defp create_ngrams(list, n) do
    list
    |> Stream.chunk_every(n, 1, :discard)
    |> Enum.to_list()
  end

  defp calculate_distribution(list) do
    total = length(list)
    
    list
    |> Enum.frequencies()
    |> Map.new(fn {k, v} -> {k, v / total} end)
  end

  defp conditional_entropy_from_ngrams(ngrams) do
    # Calculate P(X_n | X_1, ..., X_{n-1})
    contexts = ngrams |> Enum.map(&Enum.take(&1, length(&1) - 1))
    context_dist = calculate_distribution(contexts)
    
    # Calculate conditional entropy for each context
    ngrams
    |> Enum.group_by(&Enum.take(&1, length(&1) - 1))
    |> Enum.reduce(0, fn {context, context_ngrams}, acc ->
      context_prob = Map.get(context_dist, context, 0)
      
      if context_prob > 0 do
        # Distribution of next symbol given this context
        next_symbols = context_ngrams |> Enum.map(&List.last/1)
        next_dist = calculate_distribution(next_symbols)
        context_entropy = shannon_entropy(next_dist)
        
        acc + context_prob * context_entropy
      else
        acc
      end
    end)
  end
end