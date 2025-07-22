# Variety Engineering Quick Reference

## Ashby's Law of Requisite Variety

**Core Principle**: "Only variety can destroy variety"

```
V(Controller) ≥ V(System)
```

Where:
- V(Controller) = Number of distinct control states
- V(System) = Number of distinct system states requiring control

## Variety Calculation Methods

### 1. State Space Method
```
V = Π(n_i) for i in dimensions
```
Example: 3 variables with 5, 4, and 6 states = 5×4×6 = 120 variety

### 2. Behavioral Method
Count unique observed behaviors over time period

### 3. Combinatorial Method
```
V = C(n,k) = n!/(k!(n-k)!)
```
For selecting k options from n possibilities

### 4. Information-Theoretic Method
```
V = 2^H where H is entropy in bits
```

## Variety Amplifiers

### 1. Hierarchical Amplification
```
V_out = V_in × branching_factor^levels
```
- **Example**: 3 levels, branching factor 5: V_out = V_in × 125
- **Cost**: Linear with levels and branching
- **Use case**: Management structures, decision trees

### 2. Parallel Processing
```
V_out = V_in × parallel_units
```
- **Example**: 10 parallel processors: V_out = V_in × 10
- **Cost**: Linear with units
- **Use case**: Distributed systems, teams

### 3. Temporal Multiplexing
```
V_out = V_in × time_slots
```
- **Example**: 8 time slots: V_out = V_in × 8
- **Cost**: Coordination overhead
- **Use case**: Shift work, time-sharing systems

### 4. Functional Specialization
```
V_out = V_in × specialist_types
```
- **Example**: 5 specialist roles: V_out = V_in × 5
- **Cost**: Training and coordination
- **Use case**: Expert teams, specialized departments

### 5. Adaptive Amplification
```
V_out = V_in × (1 + learning_rate × time)
```
- **Dynamic**: Variety grows with experience
- **Cost**: Learning investment
- **Use case**: AI systems, learning organizations

## Variety Attenuators

### 1. Filtering
```
V_out = V_in × (1 - filter_rate)
Information_loss = -log₂(1 - filter_rate)
```
- **Example**: 80% filter rate: V_out = 0.2 × V_in
- **Use case**: Exception management, alarm systems

### 2. Categorization
```
V_out = V_in × (categories_out / categories_in)
Information_loss = log₂(categories_in / categories_out)
```
- **Example**: 100 items → 10 categories: V_out = 0.1 × V_in
- **Use case**: Classification systems, taxonomies

### 3. Aggregation
```
V_out = V_in / aggregation_factor
Information_loss = log₂(aggregation_factor)
```
- **Example**: Daily → Monthly aggregation: V_out = V_in / 30
- **Use case**: Reporting, summaries

### 4. Standardization
```
V_out = V_in × (1 - standardization_level)
```
- **Example**: 90% standardized: V_out = 0.1 × V_in
- **Use case**: Process standardization, templates

### 5. Sampling
```
V_out = V_in × sampling_rate
Information_loss = -log₂(sampling_rate)
```
- **Example**: 10% sample: V_out = 0.1 × V_in
- **Use case**: Quality control, surveys

## Variety Balance Strategies

### 1. Match Environmental Variety
```
Strategy: V_controller = V_environment
Implementation: Measure environment, design matching control
```

### 2. Overwhelming Variety
```
Strategy: V_controller >> V_environment
Implementation: Build excess capacity for resilience
Cost: High resource requirements
```

### 3. Selective Variety
```
Strategy: V_controller covers critical V_environment subset
Implementation: Focus on high-impact areas
Risk: Uncovered edge cases
```

### 4. Dynamic Variety
```
Strategy: V_controller adapts to V_environment changes
Implementation: Sensing + rapid reconfiguration
Complexity: High coordination needs
```

## Practical Variety Engineering

### For Each VSM Subsystem

#### S1 (Policy) Variety Management
**Challenge**: High variety in goals and constraints
**Amplifiers**:
- Multiple scenario planning (×scenarios)
- Flexible policy frameworks (×flexibility)
- Stakeholder representation (×stakeholders)

**Attenuators**:
- Core value filtering (÷ by value alignment)
- Strategic focus (÷ by priority)
- Policy templates (÷ by standardization)

#### S2 (Intelligence) Variety Management
**Challenge**: Infinite environmental variety
**Amplifiers**:
- Multiple sensors (×sensor_types)
- Diverse information sources (×sources)
- Pattern recognition (×patterns)

**Attenuators**:
- Relevance filtering (÷ by relevance)
- Signal aggregation (÷ by similarity)
- Threshold detection (÷ by significance)

#### S3 (Control) Variety Management
**Challenge**: Operational complexity
**Amplifiers**:
- Control modes (×modes)
- Intervention levels (×levels)
- Feedback loops (×loops)

**Attenuators**:
- Control rules (÷ by rules)
- Automation (÷ by repeatability)
- Exception handling (÷ by frequency)

#### S4 (Planning) Variety Management
**Challenge**: Exponential future possibilities
**Amplifiers**:
- Planning horizons (×horizons)
- Scenario branches (×branches)
- Option generation (×options)

**Attenuators**:
- Probability filtering (÷ by likelihood)
- Impact focusing (÷ by significance)
- Planning templates (÷ by similarity)

#### S5 (Implementation) Variety Management
**Challenge**: Detailed execution variety
**Amplifiers**:
- Process variations (×variations)
- Resource options (×resources)
- Execution paths (×paths)

**Attenuators**:
- Standard procedures (÷ by standardization)
- Batch processing (÷ by grouping)
- Automation (÷ by repeatability)

## Variety Metrics

### 1. Variety Ratio
```
VR = V_controller / V_system
Interpretation:
- VR < 1: Under-controlled (system instability)
- VR = 1: Perfectly matched (ideal)
- VR > 1: Over-controlled (resource waste)
```

### 2. Variety Efficiency
```
VE = Effective_variety / Total_variety
```
Measures how much variety is actually useful

### 3. Variety Utilization
```
VU = Used_variety / Available_variety
```
Measures how much control variety is actively employed

### 4. Variety Cost
```
VC = Resource_cost / Variety_gained
```
Cost per unit of variety

## Common Variety Engineering Patterns

### 1. Hierarchical Variety Distribution
```
Level 1: Low variety (strategic)
Level 2: Medium variety (tactical)  
Level 3: High variety (operational)
```

### 2. Variety Funnel
```
Input: High variety → Processing: Reduced variety → Output: Managed variety
```

### 3. Variety Buffer
```
Store excess variety for future use (options, reserves)
```

### 4. Variety Transformation
```
Convert one type of variety to another (more manageable form)
```

## Variety Engineering Checklist

- [ ] **Measure** system variety (all relevant dimensions)
- [ ] **Measure** current control variety
- [ ] **Calculate** variety gap (deficit or surplus)
- [ ] **Identify** critical variety requirements
- [ ] **Design** amplification strategy (if deficit)
- [ ] **Design** attenuation strategy (for environment)
- [ ] **Calculate** information loss from attenuation
- [ ] **Implement** variety management mechanisms
- [ ] **Monitor** variety balance continuously
- [ ] **Adapt** variety engineering as system evolves

## Quick Formulas

### Required Control Variety
```
V_control_required = V_environment × (1 - acceptable_error_rate)
```

### Variety Deficit
```
Deficit = max(0, V_environment - V_control)
```

### Information Loss from Attenuation
```
Info_loss = H_before - H_after = log₂(V_before/V_after)
```

### Combined Amplification
```
V_final = V_initial × Π(amplifier_i) × Π(1 - attenuator_j)
```

### Variety Balance Index
```
VBI = min(V_control/V_environment, V_environment/V_control)
Range: [0,1] where 1 is perfect balance
```

## Implementation Priority Matrix

| Variety Gap | System Impact | Priority | Action |
|-------------|---------------|----------|---------|
| High deficit | Critical | 1 | Immediate amplification |
| High deficit | Moderate | 2 | Planned amplification |
| Low deficit | Critical | 2 | Targeted amplification |
| Low deficit | Moderate | 3 | Monitor and plan |
| Balanced | Any | 4 | Maintain and optimize |
| Surplus | High cost | 3 | Reduce waste |
| Surplus | Low cost | 4 | Maintain buffer |

## Key Principles

1. **Variety cannot be destroyed, only displaced** - Reduced variety in one place appears elsewhere
2. **Amplification has costs** - Each amplifier requires resources
3. **Attenuation loses information** - Cannot be perfectly reversed
4. **Dynamic balance is key** - Static solutions fail in changing environments
5. **Hierarchical distribution works** - Different variety levels at different scales
6. **Local variety management** - Handle variety close to its source
7. **Variety buffers provide resilience** - Excess variety handles unexpected situations