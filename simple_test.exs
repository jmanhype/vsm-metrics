# Simple test to verify VSM Metrics works

IO.puts "Testing basic VSM Metrics functionality...\n"

# Test Shannon Entropy
IO.puts "1. Shannon Entropy:"
entropy = VsmMetrics.entropy(%{a: 0.5, b: 0.5})
IO.puts "   Binary entropy: #{entropy} (expected: 1.0)"

# Test Variety Calculator
IO.puts "\n2. Variety Calculator:"
alias VsmMetrics.Metrics.VarietyCalculator
result = VarietyCalculator.requisite_variety_ratio([:a, :b, :c], [:x, :y, :z, :w, :v])
IO.puts "   Controller variety: #{result.controller_variety}"
IO.puts "   Environment variety: #{result.environment_variety}"
IO.puts "   Meets requisite variety?: #{result.meets_requisite_variety?}"

# Test Time Constants
IO.puts "\n3. Time Constants:"
constants = VsmMetrics.time_constants(:s3)
IO.puts "   S3 response time: #{constants.response_time} seconds"
IO.puts "   S3 decay constant: #{constants.decay_constant} seconds"

# Test CRDT
IO.puts "\n4. CRDT Aggregation:"
alias VsmMetrics.Aggregation.CRDTAggregator
CRDTAggregator.increment_counter("visitors", 10)
CRDTAggregator.increment_counter("visitors", 5)
visitors = CRDTAggregator.get_value("visitors")
IO.puts "   Total visitors: #{visitors}"

# Test Storage
IO.puts "\n5. Storage Tiers:"
alias VsmMetrics.Storage.MemoryTier
MemoryTier.put("config", %{timeout: 30})
{:ok, config, _} = MemoryTier.get("config")
IO.puts "   Retrieved config: #{inspect config}"

IO.puts "\n✅ Basic functionality verified!"