# VSM Entropy Calculations Quick Reference

## Core Shannon Entropy Formulas

### 1. Basic Shannon Entropy
```
H(X) = -Σ p(x) * log₂(p(x))
```
- **Units**: bits
- **Range**: [0, log₂(n)] where n is number of possible states
- **Interpretation**: Average information content per observation

### 2. Joint Entropy
```
H(X,Y) = -Σ p(x,y) * log₂(p(x,y))
```
- **Purpose**: Uncertainty in joint distribution of two variables
- **Property**: H(X,Y) ≤ H(X) + H(Y) (equality if independent)

### 3. Conditional Entropy
```
H(X|Y) = H(X,Y) - H(Y)
```
- **Purpose**: Remaining uncertainty in X after knowing Y
- **Property**: H(X|Y) ≤ H(X) (knowing Y reduces uncertainty)

### 4. Mutual Information
```
I(X;Y) = H(X) + H(Y) - H(X,Y)
I(X;Y) = H(X) - H(X|Y)
I(X;Y) = H(Y) - H(Y|X)
```
- **Purpose**: Information shared between variables
- **Range**: [0, min(H(X), H(Y))]

### 5. Transfer Entropy
```
TE(X→Y) = I(Yₙ₊₁ ; Xₙ | Yₙ)
```
- **Purpose**: Directional information flow from X to Y
- **Asymmetric**: TE(X→Y) ≠ TE(Y→X)

### 6. Kullback-Leibler Divergence
```
D_KL(P||Q) = Σ p(x) * log₂(p(x)/q(x))
```
- **Purpose**: Difference between distributions
- **Property**: D_KL ≥ 0 (equality if P=Q)

## Subsystem-Specific Entropy Calculations

### S1: Policy Subsystem
```
H_policy = -Σ p(decision|context) * log₂(p(decision|context))
H_goal = -Σ p(goal) * impact(goal) * log₂(p(goal) * impact(goal))
H_identity = temporal_entropy(identity_markers, time_window)
```

### S2: Intelligence Subsystem
```
H_environment = Σ H(variable_i) for each environmental variable
C_channel = max I(input;output) over all input distributions
H_signal = average_entropy(signal_types)
I_mutual = H(S2) + H(Environment) - H(S2,Environment)
```

### S3: Control Subsystem
```
H_control = H(actions) - H(outcomes|actions)
V_ratio = V_controller / V_system (Ashby's Law: must be ≥ 1)
L_information = H_input - H_output (information loss in control loop)
H_feedback = H(feedback) * gain_factor * stability_measure
```

### S4: Planning Subsystem
```
H_future(t) = H_base * exp(growth_rate * t)
H_scenarios = -Σ p(scenario) * H(states|scenario)
H_decisions = Σ H(decision_point) - I(decision;outcome)
```

### S5: Implementation Subsystem
```
H_operations = H(processes) + H(performance|process)
H_workload = -Σ (utilization_i/total) * log₂(utilization_i/total)
H_information_flow = H(source) - I(source;destination)
```

## Time-Dependent Entropy Evolution

### Exponential Decay Model
```
H(t) = H₀ * exp(-t/τ)
```
- **τ**: Time constant (subsystem-specific)
- **Half-life**: t₁/₂ = τ * ln(2)

### Learning Rate (Entropy Reduction)
```
dH/dt = -λ * H(t)
```
- **λ**: Learning rate parameter
- **Solution**: H(t) = H₀ * exp(-λt)

### Entropy Growth with Horizon
```
H(horizon) = H₀ * (1 + α * log₂(1 + horizon/τ))
```
- **α**: Growth rate parameter
- **τ**: Characteristic time scale

## Variety Engineering Formulas

### Requisite Variety (Ashby's Law)
```
V_controller ≥ V_disturbance
log₂(V_controller) ≥ log₂(V_disturbance)
```

### Variety Amplification
```
V_output = V_input * Π(amplification_factor_i)
```

### Variety Attenuation
```
V_output = V_input * Π(1 - attenuation_factor_i)
H_loss = -log₂(Π(1 - attenuation_factor_i))
```

### Channel Capacity (Shannon-Hartley)
```
C = B * log₂(1 + S/N)
```
- **B**: Bandwidth
- **S/N**: Signal-to-noise ratio

## Information Flow Between Subsystems

### Coupling Matrix Element
```
I_ij = I(S_i ; S_j) = H(S_i) + H(S_j) - H(S_i, S_j)
```

### Effective Information Transfer
```
I_effective = I_theoretical * (1 - noise_factor) * coupling_strength
```

### Total System Information
```
I_total = Σ H(S_i) - redundancy + synergy
redundancy = Σ I(S_i ; S_j) for i < j
synergy = I(S₁, S₂, ..., S₅) - Σ H(S_i)
```

## Practical Calculation Guidelines

### 1. Discrete Variables
- Use frequency counts to estimate probabilities
- Apply Laplace smoothing for zero counts: p = (count + 1)/(total + categories)

### 2. Continuous Variables
- Use histogram binning: bins = ⌊1 + log₂(n)⌋ (Sturges' rule)
- Or kernel density estimation for smooth distributions

### 3. Time Series
- Use sliding windows for dynamic entropy
- Consider multiple time scales for multi-resolution analysis

### 4. High-Dimensional Data
- Use dimensionality reduction before entropy calculation
- Consider differential entropy for continuous distributions

### 5. Numerical Stability
- Add small epsilon (1e-10) to probabilities to avoid log(0)
- Use log-sum-exp trick for numerical stability

## Implementation Pseudocode

```python
def calculate_entropy(data):
    # Count frequencies
    counts = Counter(data)
    total = sum(counts.values())
    
    # Calculate entropy
    entropy = 0
    for count in counts.values():
        p = count / total
        if p > 0:
            entropy -= p * log2(p)
    
    return entropy

def calculate_mutual_information(x, y):
    # Calculate marginal entropies
    h_x = calculate_entropy(x)
    h_y = calculate_entropy(y)
    
    # Calculate joint entropy
    joint_data = list(zip(x, y))
    h_xy = calculate_entropy(joint_data)
    
    # Mutual information
    return h_x + h_y - h_xy

def calculate_transfer_entropy(source, target, lag=1):
    # Create lagged sequences
    source_lagged = source[:-lag]
    target_future = target[lag:]
    target_past = target[:-lag]
    
    # Calculate conditional mutual information
    # TE(X→Y) = I(Y_future ; X_past | Y_past)
    return conditional_mutual_information(
        target_future, source_lagged, target_past
    )
```

## Key Insights

1. **Entropy measures uncertainty** - Higher entropy means less predictability
2. **Information reduces entropy** - I(X;Y) quantifies uncertainty reduction
3. **Variety must match** - Controller variety must equal or exceed system variety
4. **Entropy grows with time** - Without active control, systems become more disordered
5. **Coupling creates dependencies** - Information flow between subsystems reduces total entropy
6. **Feedback controls entropy** - Negative feedback reduces entropy, positive feedback increases it

## Reference Values

### Typical Entropy Ranges by Subsystem
- **S1 (Policy)**: 2-4 bits (relatively stable)
- **S2 (Intelligence)**: 4-8 bits (high environmental variety)
- **S3 (Control)**: 3-5 bits (moderate complexity)
- **S4 (Planning)**: 5-10 bits (future uncertainty)
- **S5 (Implementation)**: 3-6 bits (operational variety)

### Time Constants (Typical)
- **S1**: Days to weeks (τ ≈ 7-30 days)
- **S2**: Hours to days (τ ≈ 1-3 days)
- **S3**: Hours to days (τ ≈ 0.5-2 days)
- **S4**: Weeks to months (τ ≈ 14-60 days)
- **S5**: Hours (τ ≈ 0.1-1 day)

### Alert Thresholds
- **Normal**: H ∈ [μ - σ, μ + σ]
- **Warning**: H ∈ [μ - 2σ, μ - σ] ∪ [μ + σ, μ + 2σ]
- **Critical**: H < μ - 2σ or H > μ + 2σ