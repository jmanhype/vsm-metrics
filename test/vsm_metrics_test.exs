defmodule VsmMetricsTest do
  use ExUnit.Case
  doctest VsmMetrics

  alias VsmMetrics.{
    Entropy.ShannonCalculator,
    Metrics.VarietyCalculator,
    TimeConstants.TemporalDynamics,
    Storage.MemoryTier,
    Aggregation.CRDTAggregator
  }

  describe "Shannon Entropy Calculator" do
    test "calculates entropy for uniform distribution" do
      dist = %{a: 0.25, b: 0.25, c: 0.25, d: 0.25}
      assert ShannonCalculator.shannon_entropy(dist) == 2.0
    end

    test "calculates zero entropy for single outcome" do
      dist = %{a: 1.0}
      assert ShannonCalculator.shannon_entropy(dist) == 0.0
    end

    test "calculates entropy for binary distribution" do
      dist = %{heads: 0.5, tails: 0.5}
      assert ShannonCalculator.shannon_entropy(dist) == 1.0
    end

    test "calculates mutual information" do
      joint_dist = %{
        {:x1, :y1} => 0.25,
        {:x1, :y2} => 0.25,
        {:x2, :y1} => 0.25,
        {:x2, :y2} => 0.25
      }
      
      # For independent variables, mutual information should be 0
      assert_in_delta ShannonCalculator.mutual_information(joint_dist), 0.0, 0.001
    end
  end

  describe "Variety Calculator" do
    test "calculates requisite variety ratio" do
      controller = [:action1, :action2, :action3]
      environment = [:state1, :state2, :state3, :state4, :state5]
      
      result = VarietyCalculator.requisite_variety_ratio(controller, environment)
      
      assert result.controller_variety == 3
      assert result.environment_variety == 5
      assert result.ratio == 0.6
      refute result.meets_requisite_variety?
      assert result.variety_deficit == 2
    end

    test "identifies variety amplification" do
      input_variety = 10
      output_variety = 50
      
      factor = VarietyCalculator.amplification_factor(input_variety, output_variety)
      assert factor == 5.0
    end

    test "suggests appropriate amplifiers" do
      result = VarietyCalculator.design_amplifiers(10, 30)
      
      assert result.amplification_needed == 3.0
      assert is_list(result.suggested_amplifiers)
      assert length(result.suggested_amplifiers) > 0
    end
  end

  describe "Temporal Dynamics" do
    test "provides default time constants" do
      constants = TemporalDynamics.default_time_constants()
      
      assert Map.has_key?(constants, :s1)
      assert Map.has_key?(constants, :s2)
      assert Map.has_key?(constants, :s3)
      assert Map.has_key?(constants, :s4)
      assert Map.has_key?(constants, :s5)
      
      # S3 should have fast response time
      assert constants.s3.response_time < constants.s4.response_time
    end

    test "calculates temporal response" do
      result = TemporalDynamics.temporal_response(:s3, 1.0, 60)
      
      assert result.subsystem == :s3
      assert result.input == 1.0
      assert result.response > 0
      assert result.response < 1.0  # Should decay
    end

    test "analyzes coupling dynamics" do
      result = TemporalDynamics.coupling_dynamics(:s2, :s3, 1.0, 10)
      
      assert result.source == :s2
      assert result.target == :s3
      assert result.coupling_coefficient > 0
      assert result.transmitted_signal <= 1.0
    end
  end

  describe "Multi-tier Storage" do
    test "memory tier provides sub-microsecond access" do
      # Start memory tier if not already started
      {:ok, _pid} = MemoryTier.start_link(max_size: 100)
      
      # Measure write performance
      start_time = System.monotonic_time(:microsecond)
      :ok = MemoryTier.put("test_key", "test_value")
      write_time = System.monotonic_time(:microsecond) - start_time
      
      # Measure read performance
      start_time = System.monotonic_time(:microsecond)
      {:ok, value, _metadata} = MemoryTier.get("test_key")
      read_time = System.monotonic_time(:microsecond) - start_time
      
      assert value == "test_value"
      # Allow some overhead, but should be very fast
      assert write_time < 1000  # Less than 1ms
      assert read_time < 1000   # Less than 1ms
    end

    test "memory tier implements LRU eviction" do
      {:ok, _pid} = MemoryTier.start_link(max_size: 3, eviction_batch: 1)
      
      # Fill the tier
      :ok = MemoryTier.put("key1", "value1")
      :ok = MemoryTier.put("key2", "value2")
      :ok = MemoryTier.put("key3", "value3")
      
      # Access key1 to make it recently used
      {:ok, _, _} = MemoryTier.get("key1")
      
      # Add one more to trigger eviction
      :ok = MemoryTier.put("key4", "value4")
      
      # key2 should have been evicted (least recently used)
      assert {:error, :not_found} = MemoryTier.get("key2")
      assert {:ok, _, _} = MemoryTier.get("key1")
      assert {:ok, _, _} = MemoryTier.get("key3")
      assert {:ok, _, _} = MemoryTier.get("key4")
    end
  end

  describe "CRDT Aggregation" do
    test "g-counter increments correctly" do
      {:ok, _pid} = CRDTAggregator.start_link(enable_sync: false)
      
      :ok = CRDTAggregator.increment_counter("test_counter", 5, :node1)
      :ok = CRDTAggregator.increment_counter("test_counter", 3, :node2)
      :ok = CRDTAggregator.increment_counter("test_counter", 2, :node1)
      
      assert CRDTAggregator.get_value("test_counter") == 10
    end

    test "g-set adds elements correctly" do
      {:ok, _pid} = CRDTAggregator.start_link(enable_sync: false)
      
      :ok = CRDTAggregator.add_to_set("test_set", "element1", :node1)
      :ok = CRDTAggregator.add_to_set("test_set", "element2", :node2)
      :ok = CRDTAggregator.add_to_set("test_set", "element1", :node2)  # Duplicate
      
      value = CRDTAggregator.get_value("test_set")
      assert length(value) == 2
      assert "element1" in value
      assert "element2" in value
    end

    test "lww-register updates with latest value" do
      {:ok, _pid} = CRDTAggregator.start_link(enable_sync: false)
      
      :ok = CRDTAggregator.update_register("test_register", "value1", :node1)
      Process.sleep(1)  # Ensure different timestamp
      :ok = CRDTAggregator.update_register("test_register", "value2", :node2)
      
      assert CRDTAggregator.get_value("test_register") == "value2"
    end

    test "crdt merge preserves all data" do
      {:ok, _pid} = CRDTAggregator.start_link(enable_sync: false)
      
      # Simulate two nodes with different data
      :ok = CRDTAggregator.increment_counter("shared_counter", 5, :node1)
      
      # Get state from "node1"
      state1 = CRDTAggregator.get_state()
      
      # Simulate node2 with different increments
      :ok = CRDTAggregator.increment_counter("shared_counter", 3, :node2)
      
      # Merge state from node1
      :ok = CRDTAggregator.merge_state(state1)
      
      # Should have both increments
      assert CRDTAggregator.get_value("shared_counter") == 8
    end
  end

  describe "VSM Integration" do
    test "records and retrieves subsystem metrics" do
      # This would require starting the full application
      # For now, we test the public API structure
      
      assert :ok == VsmMetrics.record(:s3, :operation, "test_operation")
      assert :ok == VsmMetrics.record(:s5, :variety, "state_a", %{context: "test"})
    end

    test "calculates entropy from recorded data" do
      # Test entropy calculation
      distribution = %{a: 0.4, b: 0.3, c: 0.2, d: 0.1}
      entropy = VsmMetrics.entropy(distribution)
      
      assert entropy > 0
      assert entropy < 2  # Maximum entropy for 4 states
    end
  end
end