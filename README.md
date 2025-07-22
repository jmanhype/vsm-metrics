# VSM Metrics & Entropy Architecture

This directory contains the comprehensive metrics and entropy calculation architecture for the Viable System Model (VSM) implementation.

## Overview

The VSM Metrics Architecture provides a complete framework for measuring, analyzing, and optimizing VSM performance through:

- **Shannon Entropy Calculations** - Information-theoretic metrics for uncertainty and information flow
- **Variety Engineering** - Ashby's Law compliance and variety management
- **Temporal Dynamics** - Time constants and decay functions
- **Real-time Processing** - Streaming metrics and anomaly detection

## Documentation Structure

### 1. [VSM Metrics Architecture](vsm-metrics-architecture.md)
Comprehensive design document covering:
- Subsystem-specific metrics (S1-S5)
- Entropy calculations for each subsystem
- Variety engineering metrics
- Time constant functions
- Integrated dashboard specifications

### 2. [Metrics Implementation Specification](metrics-implementation-spec.md)
Detailed implementation guide including:
- Core data structures
- Entropy calculation algorithms
- Variety calculators and balancers
- Time constant estimators
- Real-time processing systems
- Alert management
- Complete code examples

### 3. [Entropy Calculations Reference](entropy-calculations-reference.md)
Quick reference for:
- Shannon entropy formulas
- Subsystem-specific calculations
- Time-dependent entropy evolution
- Practical calculation guidelines
- Implementation pseudocode

### 4. [Variety Engineering Reference](variety-engineering-reference.md)
Practical guide for:
- Ashby's Law applications
- Variety amplifiers and attenuators
- Balance strategies
- Subsystem-specific variety management
- Implementation checklists

## Key Features

### Information-Theoretic Foundation
- Shannon entropy for uncertainty measurement
- Mutual information for subsystem coupling
- Transfer entropy for directional information flow
- Channel capacity calculations

### Variety Engineering
- Requisite variety calculations
- Amplification strategies (hierarchical, parallel, temporal, spatial)
- Attenuation methods (filtering, categorization, aggregation)
- Dynamic variety balancing

### Temporal Dynamics
- Exponential decay models
- Multi-exponential and alternative decay functions
- Phase coupling analysis
- Response time characteristics

### Real-time Capabilities
- Streaming metrics processing
- Dynamic threshold calculation
- Anomaly detection
- Alert management with hysteresis

## Implementation Architecture

```
VSM Metrics System
├── Entropy Calculators
│   ├── S1: Policy Entropy
│   ├── S2: Intelligence Entropy
│   ├── S3: Control Entropy
│   ├── S4: Planning Entropy
│   └── S5: Implementation Entropy
├── Variety Engineering
│   ├── Variety Calculators
│   ├── Amplifiers (4 types)
│   ├── Attenuators (4 types)
│   └── Variety Balancer
├── Temporal Analysis
│   ├── Decay Functions
│   ├── Time Constant Estimators
│   └── Coupling Analyzers
└── Real-time Processing
    ├── Streaming Processor
    ├── Alert Manager
    ├── Threshold Calculator
    └── Time Series Database
```

## Quick Start

### Basic Entropy Calculation
```typescript
const entropy = ShannonEntropyCalculator.calculateEntropy(frequencyMap);
```

### Variety Balance Check
```typescript
const varietyRatio = V_controller / V_system;
const compliant = varietyRatio >= 1; // Ashby's Law
```

### Real-time Monitoring
```typescript
const processor = new StreamingMetricsProcessor();
processor.processMetric('S1.health', value, timestamp);
```

## Metrics by Subsystem

### S1 (Policy)
- Identity coherence
- Goal achievement
- Strategic alignment
- Decision quality
- Policy entropy

### S2 (Intelligence)
- Environmental awareness
- Threat detection
- Opportunity recognition
- Channel capacity
- Signal entropy

### S3 (Control)
- Regulatory effectiveness
- Operational stability
- Resource efficiency
- Control entropy
- Variety metrics

### S4 (Planning)
- Forecast accuracy
- Plan quality
- Scenario coverage
- Future state entropy
- Decision tree entropy

### S5 (Implementation)
- Operational performance
- Execution effectiveness
- Process metrics
- Operational entropy
- Workload distribution

## Key Formulas

### Shannon Entropy
```
H(X) = -Σ p(x) * log₂(p(x))
```

### Mutual Information
```
I(X;Y) = H(X) + H(Y) - H(X,Y)
```

### Requisite Variety
```
V(Controller) ≥ V(System)
```

### Exponential Decay
```
V(t) = V₀ * e^(-t/τ)
```

## Performance Characteristics

- **Entropy Calculation**: O(n) for n states
- **Variety Calculation**: O(d) for d dimensions
- **Real-time Processing**: Sub-millisecond latency
- **Storage**: Time-series optimized
- **Alerting**: Threshold with hysteresis

## Integration Points

The metrics system integrates with:
- VSM subsystem implementations
- Real-time monitoring dashboards
- Alert and notification systems
- Predictive analytics engines
- Optimization algorithms

## Future Enhancements

- Machine learning-based anomaly detection
- Predictive entropy forecasting
- Automated variety optimization
- Advanced visualization capabilities
- External system integrations

## References

- Ashby, W.R. (1956). An Introduction to Cybernetics
- Shannon, C.E. (1948). A Mathematical Theory of Communication
- Beer, S. (1981). Brain of the Firm
- Cover, T.M. & Thomas, J.A. (2006). Elements of Information Theory

---

For questions or contributions, please refer to the main VSM documentation.