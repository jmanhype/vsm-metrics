# Test VSM Metrics functionality

IO.puts "Testing VSM Metrics System...\n"

# Test 1: Shannon Entropy
IO.puts "1. Testing Shannon Entropy Calculator:"
dist = %{a: 0.25, b: 0.25, c: 0.25, d: 0.25}
entropy = VsmMetrics.entropy(dist)
IO.puts "   Uniform distribution entropy: #{entropy} (expected: 2.0)"

# Test 2: Record some metrics
IO.puts "\n2. Recording metrics for subsystems:"
VsmMetrics.record(:s3, :operation, "control_decision")
VsmMetrics.record(:s5, :variety, "state_a")
VsmMetrics.record(:s5, :variety, "state_b")
VsmMetrics.record(:s5, :variety, "state_c")
VsmMetrics.record(:s3, :response_time, 45.5)
VsmMetrics.record(:s2, :operation, "environment_scan")
VsmMetrics.record(:s1, :algedonic, "budget_alert", %{severity: :critical})
IO.puts "   ✓ Metrics recorded"

# Test 3: Get subsystem health
IO.puts "\n3. Getting subsystem health:"
s3_health = VsmMetrics.health(:s3)
IO.inspect s3_health, label: "   S3 Health"

# Test 4: Get overall system health
IO.puts "\n4. Getting overall VSM health:"
vsm_health = VsmMetrics.system_health()
IO.puts "   Overall score: #{vsm_health.overall_score}"
IO.puts "   Temporal stability: #{vsm_health.temporal_stability}"
IO.puts "   Communication efficiency: #{vsm_health.communication_efficiency}"

# Test 5: Variety analysis
IO.puts "\n5. Analyzing variety balance:"
variety = VsmMetrics.variety_analysis()
IO.inspect variety.subsystem_varieties, label: "   Subsystem varieties"

# Test 6: Time constants
IO.puts "\n6. Getting time constants for S3:"
s3_constants = VsmMetrics.time_constants(:s3)
IO.inspect s3_constants, label: "   S3 Time Constants"

# Test 7: CRDT aggregation
IO.puts "\n7. Testing CRDT aggregation:"
VsmMetrics.Aggregation.CRDTAggregator.increment_counter("test_counter", 5)
VsmMetrics.Aggregation.CRDTAggregator.increment_counter("test_counter", 3)
counter_value = VsmMetrics.get_metric("test_counter")
IO.puts "   Counter value: #{counter_value} (expected: 8)"

# Test 8: Multi-tier storage
IO.puts "\n8. Testing multi-tier storage:"
VsmMetrics.Storage.MemoryTier.put("hot_data", %{value: 100})
{:ok, value, _meta} = VsmMetrics.Storage.MemoryTier.get("hot_data")
IO.inspect value, label: "   Retrieved from memory tier"

# Test 9: Temporal dynamics
IO.puts "\n9. Testing temporal dynamics:"
response = VsmMetrics.TimeConstants.TemporalDynamics.temporal_response(:s3, 1.0, 60)
IO.inspect response, label: "   Temporal response"

# Test 10: Communication analysis
IO.puts "\n10. Analyzing communication patterns:"
# Record some inter-subsystem communication
VsmMetrics.record(:s2, :operation, "alert_sent", %{target_subsystem: :s3})
VsmMetrics.record(:s3, :operation, "instruction_sent", %{target_subsystem: :s5})
VsmMetrics.record(:s5, :operation, "feedback_sent", %{target_subsystem: :s3})

comm_analysis = VsmMetrics.Metrics.SubsystemMetrics.analyze_communication()
IO.puts "   Flow entropy: #{comm_analysis.flow_entropy}"
IO.puts "   Number of active channels: #{length(comm_analysis.communication_flows)}"

IO.puts "\n✅ All tests completed successfully!"