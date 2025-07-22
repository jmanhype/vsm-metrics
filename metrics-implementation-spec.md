# VSM Metrics Implementation Specification

## Executive Summary

This document provides detailed implementation specifications for the VSM metrics architecture, including concrete algorithms, data structures, and code templates for entropy calculations, variety engineering, and temporal dynamics.

## 1. Core Data Structures

### 1.1 Base Metric Types

```typescript
// Base metric value with metadata
interface MetricValue {
  value: number;
  timestamp: Date;
  confidence: number;          // 0-1 confidence in measurement
  source: string;              // Data source identifier
  quality: 'measured' | 'calculated' | 'estimated';
}

// Time series for metric tracking
interface MetricTimeSeries {
  metric: string;
  values: Array<MetricValue>;
  aggregations: {
    min: number;
    max: number;
    mean: number;
    std: number;
    trend: 'increasing' | 'stable' | 'decreasing';
  };
}

// Metric threshold definition
interface MetricThreshold {
  metric: string;
  critical: { min?: number; max?: number };
  warning: { min?: number; max?: number };
  normal: { min: number; max: number };
  hysteresis: number;          // Prevent threshold flapping
}
```

### 1.2 Subsystem State Representation

```typescript
// Complete state of a subsystem
interface SubsystemState {
  id: 'S1' | 'S2' | 'S3' | 'S4' | 'S5';
  timestamp: Date;
  
  // State variables
  stateVector: Array<number>;   // Current state values
  stateSpace: {
    dimensions: number;
    bounds: Array<[number, number]>; // Min/max for each dimension
  };
  
  // Dynamics
  velocity: Array<number>;       // Rate of state change
  acceleration: Array<number>;   // Rate of velocity change
  
  // Health and performance
  health: number;                // 0-100 overall health
  performance: number;           // 0-100 performance score
  stability: number;             // 0-1 stability index
}

// System-wide state
interface SystemState {
  timestamp: Date;
  subsystems: Map<string, SubsystemState>;
  
  // Inter-subsystem relationships
  coupling: Array<Array<number>>; // Coupling strength matrix
  informationFlow: Array<Array<number>>; // Information flow matrix
  
  // Global metrics
  overallHealth: number;
  systemEntropy: number;
  varietyBalance: number;
}
```

## 2. Entropy Calculation Implementations

### 2.1 Shannon Entropy Calculator

```typescript
class ShannonEntropyCalculator {
  // Calculate entropy from frequency distribution
  static calculateEntropy(frequencies: Map<any, number>): number {
    const total = Array.from(frequencies.values()).reduce((a, b) => a + b, 0);
    if (total === 0) return 0;
    
    let entropy = 0;
    for (const count of frequencies.values()) {
      const p = count / total;
      if (p > 0) {
        entropy -= p * Math.log2(p);
      }
    }
    
    return entropy;
  }
  
  // Calculate entropy from probability distribution
  static calculateEntropyFromProbabilities(probabilities: Array<number>): number {
    let entropy = 0;
    for (const p of probabilities) {
      if (p > 0) {
        entropy -= p * Math.log2(p);
      }
    }
    return entropy;
  }
  
  // Calculate continuous entropy using histogram approximation
  static calculateContinuousEntropy(
    values: Array<number>,
    bins: number = 50
  ): number {
    const histogram = this.createHistogram(values, bins);
    return this.calculateEntropy(histogram);
  }
  
  private static createHistogram(
    values: Array<number>,
    bins: number
  ): Map<number, number> {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const binWidth = (max - min) / bins;
    
    const histogram = new Map<number, number>();
    
    for (const value of values) {
      const binIndex = Math.floor((value - min) / binWidth);
      const binCenter = min + binIndex * binWidth + binWidth / 2;
      histogram.set(binCenter, (histogram.get(binCenter) || 0) + 1);
    }
    
    return histogram;
  }
}
```

### 2.2 Mutual Information Calculator

```typescript
class MutualInformationCalculator {
  // Calculate mutual information between two discrete variables
  static calculateMutualInformation(
    jointDist: Map<[any, any], number>
  ): number {
    // Extract marginal distributions
    const xDist = new Map<any, number>();
    const yDist = new Map<any, number>();
    
    for (const [[x, y], count] of jointDist.entries()) {
      xDist.set(x, (xDist.get(x) || 0) + count);
      yDist.set(y, (yDist.get(y) || 0) + count);
    }
    
    // Calculate entropies
    const hX = ShannonEntropyCalculator.calculateEntropy(xDist);
    const hY = ShannonEntropyCalculator.calculateEntropy(yDist);
    const hXY = ShannonEntropyCalculator.calculateEntropy(jointDist);
    
    // I(X;Y) = H(X) + H(Y) - H(X,Y)
    return hX + hY - hXY;
  }
  
  // Calculate transfer entropy (directional information flow)
  static calculateTransferEntropy(
    source: Array<number>,
    target: Array<number>,
    lag: number = 1,
    historyLength: number = 1
  ): number {
    // Build state distributions
    const jointDist = new Map<string, number>();
    
    for (let i = historyLength + lag; i < source.length; i++) {
      // Target history
      const targetHistory = target.slice(i - historyLength, i).join(',');
      // Source history
      const sourceHistory = source.slice(i - lag - historyLength, i - lag).join(',');
      // Next target value
      const targetNext = target[i];
      
      const state = `${targetHistory}|${sourceHistory}|${targetNext}`;
      jointDist.set(state, (jointDist.get(state) || 0) + 1);
    }
    
    // Calculate transfer entropy using conditional mutual information
    // TE(X→Y) = I(Y_n+1 ; X_n | Y_n)
    return this.calculateConditionalMutualInformation(jointDist);
  }
  
  private static calculateConditionalMutualInformation(
    jointDist: Map<string, number>
  ): number {
    // Implementation of conditional mutual information
    // This is a simplified version - full implementation would be more complex
    return ShannonEntropyCalculator.calculateEntropy(jointDist) / 2;
  }
}
```

### 2.3 Subsystem Entropy Calculators

```typescript
// S1 Policy Entropy
class S1EntropyCalculator {
  static calculatePolicyEntropy(
    decisions: Array<{decision: string; context: string}>
  ): number {
    // Build decision distribution given context
    const contextDecisionMap = new Map<string, Map<string, number>>();
    
    for (const {decision, context} of decisions) {
      if (!contextDecisionMap.has(context)) {
        contextDecisionMap.set(context, new Map());
      }
      const decisionMap = contextDecisionMap.get(context)!;
      decisionMap.set(decision, (decisionMap.get(decision) || 0) + 1);
    }
    
    // Calculate average entropy across contexts
    let totalEntropy = 0;
    let contextCount = 0;
    
    for (const decisionMap of contextDecisionMap.values()) {
      totalEntropy += ShannonEntropyCalculator.calculateEntropy(decisionMap);
      contextCount++;
    }
    
    return contextCount > 0 ? totalEntropy / contextCount : 0;
  }
  
  static calculateGoalUncertainty(
    goals: Array<{id: string; probability: number; impact: number}>
  ): number {
    // Weight probabilities by impact
    const weightedProbs = goals.map(g => g.probability * g.impact);
    const total = weightedProbs.reduce((a, b) => a + b, 0);
    const normalizedProbs = weightedProbs.map(p => p / total);
    
    return ShannonEntropyCalculator.calculateEntropyFromProbabilities(normalizedProbs);
  }
}

// S2 Intelligence Entropy
class S2EntropyCalculator {
  static calculateEnvironmentalEntropy(
    observations: Array<{variable: string; value: any; timestamp: Date}>
  ): Map<string, number> {
    // Group by variable
    const variableObs = new Map<string, Array<any>>();
    
    for (const obs of observations) {
      if (!variableObs.has(obs.variable)) {
        variableObs.set(obs.variable, []);
      }
      variableObs.get(obs.variable)!.push(obs.value);
    }
    
    // Calculate entropy for each variable
    const entropies = new Map<string, number>();
    
    for (const [variable, values] of variableObs.entries()) {
      const valueCounts = new Map<any, number>();
      for (const value of values) {
        valueCounts.set(value, (valueCounts.get(value) || 0) + 1);
      }
      entropies.set(variable, ShannonEntropyCalculator.calculateEntropy(valueCounts));
    }
    
    return entropies;
  }
  
  static calculateChannelCapacity(
    channelMatrix: Array<Array<number>> // Probability of output given input
  ): number {
    // Use Blahut-Arimoto algorithm to find channel capacity
    const inputDim = channelMatrix.length;
    const outputDim = channelMatrix[0].length;
    
    // Initialize uniform input distribution
    let inputDist = new Array(inputDim).fill(1 / inputDim);
    
    // Iterate to find optimal input distribution
    const maxIterations = 100;
    const tolerance = 1e-6;
    
    for (let iter = 0; iter < maxIterations; iter++) {
      // Calculate output distribution
      const outputDist = new Array(outputDim).fill(0);
      for (let i = 0; i < inputDim; i++) {
        for (let j = 0; j < outputDim; j++) {
          outputDist[j] += inputDist[i] * channelMatrix[i][j];
        }
      }
      
      // Update input distribution
      const newInputDist = new Array(inputDim).fill(0);
      for (let i = 0; i < inputDim; i++) {
        let sum = 0;
        for (let j = 0; j < outputDim; j++) {
          if (outputDist[j] > 0) {
            sum += channelMatrix[i][j] * Math.log2(channelMatrix[i][j] / outputDist[j]);
          }
        }
        newInputDist[i] = Math.exp(sum);
      }
      
      // Normalize
      const total = newInputDist.reduce((a, b) => a + b, 0);
      for (let i = 0; i < inputDim; i++) {
        newInputDist[i] /= total;
      }
      
      // Check convergence
      let maxDiff = 0;
      for (let i = 0; i < inputDim; i++) {
        maxDiff = Math.max(maxDiff, Math.abs(newInputDist[i] - inputDist[i]));
      }
      
      inputDist = newInputDist;
      
      if (maxDiff < tolerance) break;
    }
    
    // Calculate capacity with optimal input distribution
    let capacity = 0;
    for (let i = 0; i < inputDim; i++) {
      for (let j = 0; j < outputDim; j++) {
        if (channelMatrix[i][j] > 0 && inputDist[i] > 0) {
          const outputProb = outputDist[j];
          capacity += inputDist[i] * channelMatrix[i][j] * 
                     Math.log2(channelMatrix[i][j] / outputProb);
        }
      }
    }
    
    return capacity;
  }
}

// S3 Control Entropy
class S3EntropyCalculator {
  static calculateControlEntropy(
    controlActions: Array<{action: string; state: string; outcome: string}>
  ): {actionEntropy: number; outcomeEntropy: number; efficiency: number} {
    // Calculate action distribution
    const actionCounts = new Map<string, number>();
    for (const {action} of controlActions) {
      actionCounts.set(action, (actionCounts.get(action) || 0) + 1);
    }
    const actionEntropy = ShannonEntropyCalculator.calculateEntropy(actionCounts);
    
    // Calculate outcome distribution
    const outcomeCounts = new Map<string, number>();
    for (const {outcome} of controlActions) {
      outcomeCounts.set(outcome, (outcomeCounts.get(outcome) || 0) + 1);
    }
    const outcomeEntropy = ShannonEntropyCalculator.calculateEntropy(outcomeCounts);
    
    // Calculate control efficiency (reduction in uncertainty)
    const efficiency = actionEntropy > 0 ? 
      (actionEntropy - outcomeEntropy) / actionEntropy : 0;
    
    return {actionEntropy, outcomeEntropy, efficiency};
  }
  
  static calculateRequisiteVariety(
    systemStates: number,
    controlStates: number
  ): {ratio: number; sufficient: boolean; deficit: number} {
    const ratio = controlStates / systemStates;
    const sufficient = ratio >= 1;
    const deficit = sufficient ? 0 : systemStates - controlStates;
    
    return {ratio, sufficient, deficit};
  }
}

// S4 Planning Entropy
class S4EntropyCalculator {
  static calculateFutureStateEntropy(
    scenarios: Array<{probability: number; states: Array<string>}>
  ): number {
    // Build overall state distribution
    const stateProbabilities = new Map<string, number>();
    
    for (const scenario of scenarios) {
      for (const state of scenario.states) {
        const current = stateProbabilities.get(state) || 0;
        stateProbabilities.set(state, current + scenario.probability / scenario.states.length);
      }
    }
    
    // Convert to array and calculate entropy
    const probs = Array.from(stateProbabilities.values());
    return ShannonEntropyCalculator.calculateEntropyFromProbabilities(probs);
  }
  
  static calculatePlanningHorizonEntropy(
    timeHorizon: number,
    baseEntropy: number,
    growthRate: number
  ): number {
    // Exponential growth of uncertainty
    return baseEntropy * Math.exp(growthRate * timeHorizon);
  }
}

// S5 Implementation Entropy
class S5EntropyCalculator {
  static calculateOperationalEntropy(
    operations: Array<{process: string; duration: number; outcome: 'success' | 'failure'}>
  ): {processEntropy: number; performanceEntropy: number} {
    // Process distribution
    const processCounts = new Map<string, number>();
    for (const {process} of operations) {
      processCounts.set(process, (processCounts.get(process) || 0) + 1);
    }
    const processEntropy = ShannonEntropyCalculator.calculateEntropy(processCounts);
    
    // Performance variability
    const durations = operations.map(o => o.duration);
    const performanceEntropy = ShannonEntropyCalculator.calculateContinuousEntropy(durations);
    
    return {processEntropy, performanceEntropy};
  }
  
  static calculateWorkloadEntropy(
    workload: Map<string, number> // Resource -> utilization
  ): number {
    // Convert utilization to probability distribution
    const total = Array.from(workload.values()).reduce((a, b) => a + b, 0);
    const probs = Array.from(workload.values()).map(w => w / total);
    
    return ShannonEntropyCalculator.calculateEntropyFromProbabilities(probs);
  }
}
```

## 3. Variety Engineering Implementations

### 3.1 Variety Calculators

```typescript
class VarietyCalculator {
  // Calculate variety using state space enumeration
  static calculateStateSpaceVariety(
    dimensions: Array<{name: string; values: number | Array<any>}>
  ): number {
    let variety = 1;
    
    for (const dim of dimensions) {
      if (typeof dim.values === 'number') {
        variety *= dim.values;
      } else {
        variety *= dim.values.length;
      }
    }
    
    return variety;
  }
  
  // Calculate variety using behavioral observation
  static calculateBehavioralVariety(
    observations: Array<{behavior: string; context: string}>
  ): number {
    const uniqueBehaviors = new Set<string>();
    
    for (const obs of observations) {
      uniqueBehaviors.add(`${obs.context}:${obs.behavior}`);
    }
    
    return uniqueBehaviors.size;
  }
  
  // Calculate effective variety (considering constraints)
  static calculateEffectiveVariety(
    theoreticalVariety: number,
    constraints: Array<{type: string; reduction: number}>
  ): number {
    let effectiveVariety = theoreticalVariety;
    
    for (const constraint of constraints) {
      effectiveVariety *= (1 - constraint.reduction);
    }
    
    return Math.floor(effectiveVariety);
  }
}
```

### 3.2 Variety Amplifiers

```typescript
interface VarietyAmplifier {
  name: string;
  type: 'structural' | 'functional' | 'temporal' | 'spatial';
  amplify(inputVariety: number): number;
  cost(): number;
}

class HierarchicalAmplifier implements VarietyAmplifier {
  name = 'Hierarchical Structure';
  type = 'structural' as const;
  
  constructor(private levels: number, private branchingFactor: number) {}
  
  amplify(inputVariety: number): number {
    // Each level multiplies variety by branching factor
    return inputVariety * Math.pow(this.branchingFactor, this.levels);
  }
  
  cost(): number {
    // Cost grows with levels and branching
    return this.levels * this.branchingFactor * 10;
  }
}

class ParallelProcessingAmplifier implements VarietyAmplifier {
  name = 'Parallel Processing';
  type = 'functional' as const;
  
  constructor(private parallelUnits: number) {}
  
  amplify(inputVariety: number): number {
    // Parallel units multiply variety
    return inputVariety * this.parallelUnits;
  }
  
  cost(): number {
    // Linear cost with units
    return this.parallelUnits * 20;
  }
}

class TemporalMultiplexingAmplifier implements VarietyAmplifier {
  name = 'Temporal Multiplexing';
  type = 'temporal' as const;
  
  constructor(private timeSlots: number) {}
  
  amplify(inputVariety: number): number {
    // Different behaviors in different time slots
    return inputVariety * this.timeSlots;
  }
  
  cost(): number {
    // Coordination cost grows with slots
    return this.timeSlots * 5;
  }
}

class SpatialDistributionAmplifier implements VarietyAmplifier {
  name = 'Spatial Distribution';
  type = 'spatial' as const;
  
  constructor(private locations: number) {}
  
  amplify(inputVariety: number): number {
    // Different behaviors at different locations
    return inputVariety * this.locations;
  }
  
  cost(): number {
    // Infrastructure cost
    return this.locations * 15;
  }
}
```

### 3.3 Variety Attenuators

```typescript
interface VarietyAttenuator {
  name: string;
  type: 'filter' | 'aggregator' | 'simplifier' | 'standardizer';
  attenuate(inputVariety: number): number;
  informationLoss(): number;
}

class ThresholdFilter implements VarietyAttenuator {
  name = 'Threshold Filter';
  type = 'filter' as const;
  
  constructor(private threshold: number, private selectivity: number) {}
  
  attenuate(inputVariety: number): number {
    // Only pass states above threshold
    return inputVariety * (1 - this.selectivity);
  }
  
  informationLoss(): number {
    // Information lost is proportional to selectivity
    return -Math.log2(1 - this.selectivity);
  }
}

class CategoryAggregator implements VarietyAttenuator {
  name = 'Category Aggregator';
  type = 'aggregator' as const;
  
  constructor(private categories: number, private originalCategories: number) {}
  
  attenuate(inputVariety: number): number {
    // Reduce variety by grouping into categories
    return inputVariety * (this.categories / this.originalCategories);
  }
  
  informationLoss(): number {
    // Loss from merging categories
    return Math.log2(this.originalCategories / this.categories);
  }
}

class PatternSimplifier implements VarietyAttenuator {
  name = 'Pattern Simplifier';
  type = 'simplifier' as const;
  
  constructor(private compressionRatio: number) {}
  
  attenuate(inputVariety: number): number {
    // Reduce variety through pattern recognition
    return inputVariety / this.compressionRatio;
  }
  
  informationLoss(): number {
    // Lossy compression information loss
    return Math.log2(this.compressionRatio) * 0.3; // 30% is lost
  }
}

class ProcessStandardizer implements VarietyAttenuator {
  name = 'Process Standardizer';
  type = 'standardizer' as const;
  
  constructor(private standardizationLevel: number) {}
  
  attenuate(inputVariety: number): number {
    // Reduce variety through standardization
    return inputVariety * (1 - this.standardizationLevel);
  }
  
  informationLoss(): number {
    // Loss from removing unique aspects
    return -Math.log2(1 - this.standardizationLevel) * 0.5;
  }
}
```

### 3.4 Variety Balancer

```typescript
class VarietyBalancer {
  private amplifiers: Array<VarietyAmplifier> = [];
  private attenuators: Array<VarietyAttenuator> = [];
  
  constructor(
    private systemVariety: number,
    private environmentVariety: number
  ) {}
  
  // Find optimal combination of amplifiers and attenuators
  optimizeVarietyBalance(
    maxCost: number,
    maxInfoLoss: number
  ): {
    amplifiers: Array<VarietyAmplifier>;
    attenuators: Array<VarietyAttenuator>;
    finalRatio: number;
    totalCost: number;
    totalInfoLoss: number;
  } {
    // Genetic algorithm to find optimal combination
    const populationSize = 100;
    const generations = 50;
    
    // Initialize population
    let population = this.initializePopulation(populationSize);
    
    for (let gen = 0; gen < generations; gen++) {
      // Evaluate fitness
      const evaluated = population.map(individual => ({
        individual,
        fitness: this.evaluateFitness(individual, maxCost, maxInfoLoss)
      }));
      
      // Select best individuals
      evaluated.sort((a, b) => b.fitness - a.fitness);
      const selected = evaluated.slice(0, populationSize / 2);
      
      // Create new generation
      population = [];
      for (let i = 0; i < populationSize; i++) {
        if (i < selected.length) {
          population.push(selected[i].individual);
        } else {
          // Crossover and mutation
          const parent1 = selected[Math.floor(Math.random() * selected.length)].individual;
          const parent2 = selected[Math.floor(Math.random() * selected.length)].individual;
          population.push(this.crossover(parent1, parent2));
        }
      }
    }
    
    // Return best solution
    const best = population[0];
    return this.evaluateSolution(best);
  }
  
  private initializePopulation(size: number): Array<any> {
    // Implementation details...
    return [];
  }
  
  private evaluateFitness(individual: any, maxCost: number, maxInfoLoss: number): number {
    const solution = this.evaluateSolution(individual);
    
    // Fitness considers variety ratio, cost, and information loss
    let fitness = 0;
    
    // Variety ratio (want close to 1 or above)
    if (solution.finalRatio >= 1) {
      fitness += 100;
    } else {
      fitness += solution.finalRatio * 100;
    }
    
    // Cost penalty
    if (solution.totalCost > maxCost) {
      fitness -= (solution.totalCost - maxCost) * 10;
    }
    
    // Information loss penalty
    if (solution.totalInfoLoss > maxInfoLoss) {
      fitness -= (solution.totalInfoLoss - maxInfoLoss) * 20;
    }
    
    return fitness;
  }
  
  private evaluateSolution(individual: any): any {
    // Calculate final variety ratio and costs
    // Implementation details...
    return {
      amplifiers: [],
      attenuators: [],
      finalRatio: 1,
      totalCost: 0,
      totalInfoLoss: 0
    };
  }
  
  private crossover(parent1: any, parent2: any): any {
    // Genetic crossover implementation
    return parent1; // Placeholder
  }
}
```

## 4. Time Constant Implementations

### 4.1 Decay Functions

```typescript
class DecayFunctions {
  // Exponential decay
  static exponentialDecay(
    initialValue: number,
    time: number,
    timeConstant: number
  ): number {
    return initialValue * Math.exp(-time / timeConstant);
  }
  
  // Multi-exponential decay (sum of exponentials)
  static multiExponentialDecay(
    initialValue: number,
    time: number,
    components: Array<{weight: number; tau: number}>
  ): number {
    let value = 0;
    
    for (const component of components) {
      value += initialValue * component.weight * Math.exp(-time / component.tau);
    }
    
    return value;
  }
  
  // Power law decay
  static powerLawDecay(
    initialValue: number,
    time: number,
    exponent: number
  ): number {
    return initialValue / Math.pow(1 + time, exponent);
  }
  
  // Logarithmic decay
  static logarithmicDecay(
    initialValue: number,
    time: number,
    rate: number
  ): number {
    return initialValue - rate * Math.log(1 + time);
  }
  
  // Oscillatory decay
  static oscillatoryDecay(
    initialValue: number,
    time: number,
    tau: number,
    frequency: number,
    phase: number = 0
  ): number {
    return initialValue * Math.exp(-time / tau) * Math.cos(2 * Math.PI * frequency * time + phase);
  }
}
```

### 4.2 Time Constant Estimators

```typescript
class TimeConstantEstimator {
  // Estimate time constant from step response data
  static estimateFromStepResponse(
    times: Array<number>,
    values: Array<number>
  ): number {
    // Find 63.2% of final value (1 - 1/e)
    const initialValue = values[0];
    const finalValue = values[values.length - 1];
    const targetValue = initialValue + 0.632 * (finalValue - initialValue);
    
    // Find time when target value is reached
    for (let i = 0; i < values.length - 1; i++) {
      if (values[i] <= targetValue && values[i + 1] >= targetValue) {
        // Linear interpolation
        const t1 = times[i];
        const t2 = times[i + 1];
        const v1 = values[i];
        const v2 = values[i + 1];
        
        return t1 + (targetValue - v1) * (t2 - t1) / (v2 - v1);
      }
    }
    
    // Fallback: use exponential fit
    return this.exponentialFit(times, values);
  }
  
  // Fit exponential decay using least squares
  static exponentialFit(
    times: Array<number>,
    values: Array<number>
  ): number {
    // Transform to linear: ln(y) = ln(a) - t/tau
    const logValues = values.map(v => Math.log(v));
    
    // Linear regression
    const n = times.length;
    const sumT = times.reduce((a, b) => a + b, 0);
    const sumLogV = logValues.reduce((a, b) => a + b, 0);
    const sumT2 = times.reduce((a, b) => a + b * b, 0);
    const sumTLogV = times.reduce((a, b, i) => a + b * logValues[i], 0);
    
    const slope = (n * sumTLogV - sumT * sumLogV) / (n * sumT2 - sumT * sumT);
    const tau = -1 / slope;
    
    return tau;
  }
  
  // Estimate time constant from autocorrelation
  static estimateFromAutocorrelation(
    values: Array<number>,
    samplingInterval: number
  ): number {
    const autocorr = this.autocorrelation(values);
    
    // Find lag where autocorrelation drops to 1/e
    const targetCorr = 1 / Math.E;
    
    for (let lag = 0; lag < autocorr.length - 1; lag++) {
      if (autocorr[lag] >= targetCorr && autocorr[lag + 1] < targetCorr) {
        // Linear interpolation
        const t = lag + (targetCorr - autocorr[lag]) / 
                  (autocorr[lag + 1] - autocorr[lag]);
        return t * samplingInterval;
      }
    }
    
    // Fallback
    return samplingInterval * autocorr.length / 3;
  }
  
  private static autocorrelation(values: Array<number>): Array<number> {
    const n = values.length;
    const mean = values.reduce((a, b) => a + b, 0) / n;
    const variance = values.reduce((a, b) => a + (b - mean) ** 2, 0) / n;
    
    const autocorr: Array<number> = [];
    
    for (let lag = 0; lag < n; lag++) {
      let sum = 0;
      for (let i = 0; i < n - lag; i++) {
        sum += (values[i] - mean) * (values[i + lag] - mean);
      }
      autocorr.push(sum / ((n - lag) * variance));
    }
    
    return autocorr;
  }
}
```

### 4.3 Temporal Coupling Analyzer

```typescript
class TemporalCouplingAnalyzer {
  // Calculate phase coupling between two signals
  static calculatePhaseCoupling(
    signal1: Array<number>,
    signal2: Array<number>,
    samplingRate: number
  ): {phaseShift: number; coherence: number; frequency: number} {
    // Compute cross-correlation
    const xcorr = this.crossCorrelation(signal1, signal2);
    
    // Find peak correlation and lag
    let maxCorr = -Infinity;
    let maxLag = 0;
    
    for (let i = 0; i < xcorr.length; i++) {
      if (xcorr[i] > maxCorr) {
        maxCorr = xcorr[i];
        maxLag = i - signal1.length + 1;
      }
    }
    
    // Convert lag to phase shift
    const dominantFreq = this.findDominantFrequency(signal1, samplingRate);
    const phaseShift = 2 * Math.PI * dominantFreq * maxLag / samplingRate;
    
    // Calculate coherence (normalized correlation)
    const coherence = maxCorr / Math.sqrt(
      this.signalPower(signal1) * this.signalPower(signal2)
    );
    
    return {
      phaseShift: phaseShift % (2 * Math.PI),
      coherence,
      frequency: dominantFreq
    };
  }
  
  // Calculate transfer entropy between subsystems
  static calculateTransferEntropy(
    source: Array<number>,
    target: Array<number>,
    lag: number,
    bins: number = 10
  ): number {
    // Discretize continuous signals
    const sourceBinned = this.discretize(source, bins);
    const targetBinned = this.discretize(target, bins);
    
    // Calculate transfer entropy
    return MutualInformationCalculator.calculateTransferEntropy(
      sourceBinned,
      targetBinned,
      lag
    );
  }
  
  // Detect synchronization clusters
  static detectSynchronizationClusters(
    signals: Array<Array<number>>,
    threshold: number = 0.8
  ): Array<{members: Array<number>; strength: number}> {
    const n = signals.length;
    const synchronization = Array(n).fill(null).map(() => Array(n).fill(0));
    
    // Calculate pairwise synchronization
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        const sync = this.calculateSynchronization(signals[i], signals[j]);
        synchronization[i][j] = sync;
        synchronization[j][i] = sync;
      }
    }
    
    // Cluster using hierarchical clustering
    const clusters: Array<{members: Array<number>; strength: number}> = [];
    const visited = new Set<number>();
    
    for (let i = 0; i < n; i++) {
      if (visited.has(i)) continue;
      
      const cluster = {members: [i], strength: 1.0};
      visited.add(i);
      
      // Find synchronized subsystems
      for (let j = 0; j < n; j++) {
        if (i !== j && !visited.has(j) && synchronization[i][j] > threshold) {
          cluster.members.push(j);
          visited.add(j);
        }
      }
      
      // Calculate average synchronization strength
      if (cluster.members.length > 1) {
        let totalSync = 0;
        let count = 0;
        
        for (let m1 of cluster.members) {
          for (let m2 of cluster.members) {
            if (m1 < m2) {
              totalSync += synchronization[m1][m2];
              count++;
            }
          }
        }
        
        cluster.strength = totalSync / count;
        clusters.push(cluster);
      }
    }
    
    return clusters;
  }
  
  private static crossCorrelation(
    signal1: Array<number>,
    signal2: Array<number>
  ): Array<number> {
    const result: Array<number> = [];
    const n1 = signal1.length;
    const n2 = signal2.length;
    
    for (let lag = -n2 + 1; lag < n1; lag++) {
      let sum = 0;
      
      for (let i = 0; i < n1; i++) {
        const j = i - lag;
        if (j >= 0 && j < n2) {
          sum += signal1[i] * signal2[j];
        }
      }
      
      result.push(sum);
    }
    
    return result;
  }
  
  private static signalPower(signal: Array<number>): number {
    return signal.reduce((a, b) => a + b * b, 0) / signal.length;
  }
  
  private static findDominantFrequency(
    signal: Array<number>,
    samplingRate: number
  ): number {
    // Simple FFT-based frequency detection
    // In real implementation, use proper FFT library
    const n = signal.length;
    const frequencies: Array<number> = [];
    const magnitudes: Array<number> = [];
    
    for (let k = 0; k < n / 2; k++) {
      let real = 0;
      let imag = 0;
      
      for (let t = 0; t < n; t++) {
        const angle = -2 * Math.PI * k * t / n;
        real += signal[t] * Math.cos(angle);
        imag += signal[t] * Math.sin(angle);
      }
      
      frequencies.push(k * samplingRate / n);
      magnitudes.push(Math.sqrt(real * real + imag * imag));
    }
    
    // Find peak magnitude
    let maxMag = 0;
    let maxFreq = 0;
    
    for (let i = 1; i < magnitudes.length; i++) { // Skip DC
      if (magnitudes[i] > maxMag) {
        maxMag = magnitudes[i];
        maxFreq = frequencies[i];
      }
    }
    
    return maxFreq;
  }
  
  private static discretize(signal: Array<number>, bins: number): Array<number> {
    const min = Math.min(...signal);
    const max = Math.max(...signal);
    const binWidth = (max - min) / bins;
    
    return signal.map(value => 
      Math.floor((value - min) / binWidth)
    );
  }
  
  private static calculateSynchronization(
    signal1: Array<number>,
    signal2: Array<number>
  ): number {
    // Kuramoto order parameter
    const n = Math.min(signal1.length, signal2.length);
    let sumCos = 0;
    let sumSin = 0;
    
    for (let i = 0; i < n; i++) {
      const phaseDiff = signal1[i] - signal2[i];
      sumCos += Math.cos(phaseDiff);
      sumSin += Math.sin(phaseDiff);
    }
    
    return Math.sqrt(sumCos * sumCos + sumSin * sumSin) / n;
  }
}
```

## 5. Real-time Metrics Processing

### 5.1 Streaming Metrics Processor

```typescript
class StreamingMetricsProcessor {
  private buffers: Map<string, Array<MetricValue>> = new Map();
  private windowSize: number = 1000; // Default window size
  
  // Process incoming metric value
  processMetric(metric: string, value: number, timestamp: Date): void {
    if (!this.buffers.has(metric)) {
      this.buffers.set(metric, []);
    }
    
    const buffer = this.buffers.get(metric)!;
    buffer.push({value, timestamp, confidence: 1, source: 'stream', quality: 'measured'});
    
    // Maintain window size
    if (buffer.length > this.windowSize) {
      buffer.shift();
    }
    
    // Trigger calculations
    this.updateCalculations(metric);
  }
  
  // Update derived metrics
  private updateCalculations(metric: string): void {
    const buffer = this.buffers.get(metric)!;
    if (buffer.length < 2) return;
    
    // Calculate streaming statistics
    const values = buffer.map(b => b.value);
    const stats = this.calculateStreamingStats(values);
    
    // Calculate entropy
    const entropy = ShannonEntropyCalculator.calculateContinuousEntropy(values);
    
    // Detect anomalies
    const anomalies = this.detectAnomalies(values);
    
    // Emit updates
    this.emit('update', {
      metric,
      stats,
      entropy,
      anomalies
    });
  }
  
  private calculateStreamingStats(values: Array<number>): any {
    const n = values.length;
    const mean = values.reduce((a, b) => a + b, 0) / n;
    const variance = values.reduce((a, b) => a + (b - mean) ** 2, 0) / n;
    const std = Math.sqrt(variance);
    
    // Calculate trend using linear regression
    const indices = Array.from({length: n}, (_, i) => i);
    const sumX = indices.reduce((a, b) => a + b, 0);
    const sumY = values.reduce((a, b) => a + b, 0);
    const sumXY = indices.reduce((a, b, i) => a + b * values[i], 0);
    const sumX2 = indices.reduce((a, b) => a + b * b, 0);
    
    const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    const trend = slope > 0.01 ? 'increasing' : slope < -0.01 ? 'decreasing' : 'stable';
    
    return {
      mean,
      std,
      min: Math.min(...values),
      max: Math.max(...values),
      trend
    };
  }
  
  private detectAnomalies(values: Array<number>): Array<number> {
    const anomalies: Array<number> = [];
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const std = Math.sqrt(values.reduce((a, b) => a + (b - mean) ** 2, 0) / values.length);
    
    // Z-score based anomaly detection
    values.forEach((value, index) => {
      const zScore = Math.abs((value - mean) / std);
      if (zScore > 3) {
        anomalies.push(index);
      }
    });
    
    return anomalies;
  }
  
  private emit(event: string, data: any): void {
    // Event emission implementation
    console.log(`Event: ${event}`, data);
  }
}
```

### 5.2 Metric Aggregator

```typescript
class MetricAggregator {
  // Aggregate metrics across time windows
  static aggregateTimeWindows(
    metrics: Array<MetricValue>,
    windowSize: number,
    aggregationFn: (values: Array<number>) => number
  ): Array<{timestamp: Date; value: number}> {
    const aggregated: Array<{timestamp: Date; value: number}> = [];
    
    // Group by time windows
    const windows = new Map<number, Array<number>>();
    
    for (const metric of metrics) {
      const windowIndex = Math.floor(metric.timestamp.getTime() / windowSize);
      if (!windows.has(windowIndex)) {
        windows.set(windowIndex, []);
      }
      windows.get(windowIndex)!.push(metric.value);
    }
    
    // Aggregate each window
    for (const [windowIndex, values] of windows.entries()) {
      aggregated.push({
        timestamp: new Date(windowIndex * windowSize + windowSize / 2),
        value: aggregationFn(values)
      });
    }
    
    return aggregated.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
  }
  
  // Aggregate metrics across subsystems
  static aggregateSubsystems(
    subsystemMetrics: Map<string, number>,
    weights: Map<string, number>
  ): number {
    let weightedSum = 0;
    let totalWeight = 0;
    
    for (const [subsystem, value] of subsystemMetrics.entries()) {
      const weight = weights.get(subsystem) || 1;
      weightedSum += value * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }
  
  // Multi-resolution aggregation
  static multiResolutionAggregate(
    metrics: Array<MetricValue>,
    resolutions: Array<number>
  ): Map<number, Array<{timestamp: Date; value: number}>> {
    const result = new Map<number, Array<{timestamp: Date; value: number}>>();
    
    for (const resolution of resolutions) {
      result.set(
        resolution,
        this.aggregateTimeWindows(metrics, resolution, values => 
          values.reduce((a, b) => a + b, 0) / values.length
        )
      );
    }
    
    return result;
  }
}
```

## 6. Metric Storage and Retrieval

### 6.1 Time Series Database Interface

```typescript
interface TimeSeriesDB {
  // Write metric value
  write(metric: string, value: number, timestamp: Date, tags?: Map<string, string>): Promise<void>;
  
  // Read metric values
  read(
    metric: string,
    startTime: Date,
    endTime: Date,
    aggregation?: 'raw' | 'avg' | 'min' | 'max' | 'sum',
    interval?: number
  ): Promise<Array<MetricValue>>;
  
  // Query multiple metrics
  query(
    metrics: Array<string>,
    startTime: Date,
    endTime: Date,
    groupBy?: Array<string>
  ): Promise<Map<string, Array<MetricValue>>>;
  
  // Delete old data
  retention(metric: string, olderThan: Date): Promise<void>;
}

// Example implementation using in-memory storage
class InMemoryTimeSeriesDB implements TimeSeriesDB {
  private data: Map<string, Array<MetricValue>> = new Map();
  
  async write(
    metric: string,
    value: number,
    timestamp: Date,
    tags?: Map<string, string>
  ): Promise<void> {
    if (!this.data.has(metric)) {
      this.data.set(metric, []);
    }
    
    this.data.get(metric)!.push({
      value,
      timestamp,
      confidence: 1,
      source: tags?.get('source') || 'unknown',
      quality: 'measured'
    });
  }
  
  async read(
    metric: string,
    startTime: Date,
    endTime: Date,
    aggregation: 'raw' | 'avg' | 'min' | 'max' | 'sum' = 'raw',
    interval?: number
  ): Promise<Array<MetricValue>> {
    const values = this.data.get(metric) || [];
    const filtered = values.filter(v => 
      v.timestamp >= startTime && v.timestamp <= endTime
    );
    
    if (aggregation === 'raw' || !interval) {
      return filtered;
    }
    
    // Aggregate based on interval
    const aggregationFn = {
      avg: (vals: Array<number>) => vals.reduce((a, b) => a + b, 0) / vals.length,
      min: (vals: Array<number>) => Math.min(...vals),
      max: (vals: Array<number>) => Math.max(...vals),
      sum: (vals: Array<number>) => vals.reduce((a, b) => a + b, 0)
    }[aggregation];
    
    return MetricAggregator.aggregateTimeWindows(filtered, interval, aggregationFn);
  }
  
  async query(
    metrics: Array<string>,
    startTime: Date,
    endTime: Date,
    groupBy?: Array<string>
  ): Promise<Map<string, Array<MetricValue>>> {
    const result = new Map<string, Array<MetricValue>>();
    
    for (const metric of metrics) {
      const values = await this.read(metric, startTime, endTime);
      result.set(metric, values);
    }
    
    return result;
  }
  
  async retention(metric: string, olderThan: Date): Promise<void> {
    const values = this.data.get(metric) || [];
    this.data.set(
      metric,
      values.filter(v => v.timestamp >= olderThan)
    );
  }
}
```

## 7. Alert and Threshold Management

### 7.1 Dynamic Threshold Calculator

```typescript
class DynamicThresholdCalculator {
  // Calculate adaptive thresholds based on historical data
  static calculateDynamicThresholds(
    historicalData: Array<number>,
    sensitivity: number = 2 // Standard deviations
  ): MetricThreshold {
    const mean = historicalData.reduce((a, b) => a + b, 0) / historicalData.length;
    const std = Math.sqrt(
      historicalData.reduce((a, b) => a + (b - mean) ** 2, 0) / historicalData.length
    );
    
    // Calculate percentiles for more robust thresholds
    const sorted = [...historicalData].sort((a, b) => a - b);
    const p5 = sorted[Math.floor(sorted.length * 0.05)];
    const p95 = sorted[Math.floor(sorted.length * 0.95)];
    
    return {
      metric: 'dynamic',
      critical: {
        min: Math.min(mean - sensitivity * 1.5 * std, p5),
        max: Math.max(mean + sensitivity * 1.5 * std, p95)
      },
      warning: {
        min: mean - sensitivity * std,
        max: mean + sensitivity * std
      },
      normal: {
        min: mean - std,
        max: mean + std
      },
      hysteresis: std * 0.1 // 10% of standard deviation
    };
  }
  
  // Calculate seasonal thresholds
  static calculateSeasonalThresholds(
    data: Array<{timestamp: Date; value: number}>,
    seasonalityPeriod: number // in days
  ): Map<number, MetricThreshold> {
    const thresholdsByHour = new Map<number, MetricThreshold>();
    
    // Group data by hour of seasonal period
    const groupedData = new Map<number, Array<number>>();
    
    for (const item of data) {
      const hourInPeriod = (item.timestamp.getTime() / (1000 * 60 * 60)) % (seasonalityPeriod * 24);
      const hourBucket = Math.floor(hourInPeriod);
      
      if (!groupedData.has(hourBucket)) {
        groupedData.set(hourBucket, []);
      }
      groupedData.get(hourBucket)!.push(item.value);
    }
    
    // Calculate thresholds for each hour bucket
    for (const [hour, values] of groupedData.entries()) {
      thresholdsByHour.set(hour, this.calculateDynamicThresholds(values));
    }
    
    return thresholdsByHour;
  }
}
```

### 7.2 Alert Manager

```typescript
interface Alert {
  id: string;
  metric: string;
  subsystem: string;
  severity: 'info' | 'warning' | 'critical';
  value: number;
  threshold: number;
  timestamp: Date;
  message: string;
  acknowledged: boolean;
}

class AlertManager {
  private activeAlerts: Map<string, Alert> = new Map();
  private alertHistory: Array<Alert> = [];
  
  // Check metric against thresholds
  checkThresholds(
    metric: string,
    value: number,
    threshold: MetricThreshold,
    subsystem: string
  ): Alert | null {
    const alertKey = `${subsystem}:${metric}`;
    const existingAlert = this.activeAlerts.get(alertKey);
    
    // Check if value violates thresholds
    let severity: 'info' | 'warning' | 'critical' | null = null;
    let thresholdValue = 0;
    
    if (threshold.critical.max && value > threshold.critical.max) {
      severity = 'critical';
      thresholdValue = threshold.critical.max;
    } else if (threshold.critical.min && value < threshold.critical.min) {
      severity = 'critical';
      thresholdValue = threshold.critical.min;
    } else if (threshold.warning.max && value > threshold.warning.max) {
      severity = 'warning';
      thresholdValue = threshold.warning.max;
    } else if (threshold.warning.min && value < threshold.warning.min) {
      severity = 'warning';
      thresholdValue = threshold.warning.min;
    }
    
    // Handle hysteresis
    if (existingAlert && severity) {
      const improving = this.isImproving(value, thresholdValue, existingAlert.value);
      if (improving && Math.abs(value - thresholdValue) < threshold.hysteresis) {
        return null; // Don't update alert within hysteresis band
      }
    }
    
    // Create or update alert
    if (severity) {
      const alert: Alert = {
        id: `${alertKey}:${Date.now()}`,
        metric,
        subsystem,
        severity,
        value,
        threshold: thresholdValue,
        timestamp: new Date(),
        message: `${metric} is ${severity}: ${value} (threshold: ${thresholdValue})`,
        acknowledged: false
      };
      
      this.activeAlerts.set(alertKey, alert);
      this.alertHistory.push(alert);
      
      return alert;
    } else if (existingAlert) {
      // Clear existing alert
      this.activeAlerts.delete(alertKey);
    }
    
    return null;
  }
  
  private isImproving(current: number, threshold: number, previous: number): boolean {
    // Check if value is moving away from threshold
    const prevDistance = Math.abs(previous - threshold);
    const currDistance = Math.abs(current - threshold);
    return currDistance < prevDistance;
  }
  
  // Get active alerts by severity
  getActiveAlerts(severity?: 'info' | 'warning' | 'critical'): Array<Alert> {
    const alerts = Array.from(this.activeAlerts.values());
    
    if (severity) {
      return alerts.filter(a => a.severity === severity);
    }
    
    return alerts;
  }
  
  // Acknowledge alert
  acknowledgeAlert(alertId: string): void {
    for (const alert of this.activeAlerts.values()) {
      if (alert.id === alertId) {
        alert.acknowledged = true;
        break;
      }
    }
  }
  
  // Get alert statistics
  getAlertStatistics(timeWindow: number): {
    total: number;
    bySeverity: Map<string, number>;
    bySubsystem: Map<string, number>;
    mttr: number; // Mean time to resolution
  } {
    const cutoff = new Date(Date.now() - timeWindow);
    const relevantAlerts = this.alertHistory.filter(a => a.timestamp > cutoff);
    
    const bySeverity = new Map<string, number>();
    const bySubsystem = new Map<string, number>();
    
    for (const alert of relevantAlerts) {
      bySeverity.set(alert.severity, (bySeverity.get(alert.severity) || 0) + 1);
      bySubsystem.set(alert.subsystem, (bySubsystem.get(alert.subsystem) || 0) + 1);
    }
    
    // Calculate MTTR (simplified)
    const resolvedAlerts = relevantAlerts.filter(a => !this.activeAlerts.has(`${a.subsystem}:${a.metric}`));
    const mttr = resolvedAlerts.length > 0 ? timeWindow / resolvedAlerts.length : 0;
    
    return {
      total: relevantAlerts.length,
      bySeverity,
      bySubsystem,
      mttr
    };
  }
}
```

## 8. Integration Example

### 8.1 Complete VSM Metrics System

```typescript
class VSMMetricsSystem {
  private entropyCalculators = {
    S1: new S1EntropyCalculator(),
    S2: new S2EntropyCalculator(),
    S3: new S3EntropyCalculator(),
    S4: new S4EntropyCalculator(),
    S5: new S5EntropyCalculator()
  };
  
  private varietyBalancer: VarietyBalancer;
  private temporalAnalyzer: TemporalCouplingAnalyzer;
  private metricsProcessor: StreamingMetricsProcessor;
  private alertManager: AlertManager;
  private database: TimeSeriesDB;
  
  constructor() {
    this.varietyBalancer = new VarietyBalancer(1000, 1500); // Example varieties
    this.temporalAnalyzer = new TemporalCouplingAnalyzer();
    this.metricsProcessor = new StreamingMetricsProcessor();
    this.alertManager = new AlertManager();
    this.database = new InMemoryTimeSeriesDB();
  }
  
  // Process incoming metric
  async processMetric(
    subsystem: string,
    metric: string,
    value: number,
    timestamp: Date = new Date()
  ): Promise<void> {
    // Store in database
    await this.database.write(`${subsystem}.${metric}`, value, timestamp);
    
    // Process in streaming processor
    this.metricsProcessor.processMetric(`${subsystem}.${metric}`, value, timestamp);
    
    // Check thresholds
    const historicalData = await this.database.read(
      `${subsystem}.${metric}`,
      new Date(timestamp.getTime() - 24 * 60 * 60 * 1000), // Last 24 hours
      timestamp
    );
    
    const threshold = DynamicThresholdCalculator.calculateDynamicThresholds(
      historicalData.map(h => h.value)
    );
    
    const alert = this.alertManager.checkThresholds(metric, value, threshold, subsystem);
    if (alert) {
      console.log('Alert generated:', alert);
    }
  }
  
  // Calculate system-wide entropy
  async calculateSystemEntropy(): Promise<number> {
    const subsystemEntropies: Array<number> = [];
    
    // Get recent data for each subsystem
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - 60 * 60 * 1000); // Last hour
    
    for (const subsystem of ['S1', 'S2', 'S3', 'S4', 'S5']) {
      const metrics = await this.database.query(
        [`${subsystem}.state`],
        startTime,
        endTime
      );
      
      const values = metrics.get(`${subsystem}.state`) || [];
      if (values.length > 0) {
        const entropy = ShannonEntropyCalculator.calculateContinuousEntropy(
          values.map(v => v.value)
        );
        subsystemEntropies.push(entropy);
      }
    }
    
    // Total system entropy (simplified - could use joint entropy)
    return subsystemEntropies.reduce((a, b) => a + b, 0);
  }
  
  // Get comprehensive dashboard data
  async getDashboardData(): Promise<any> {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    // Get metrics for all subsystems
    const metricsData = new Map<string, any>();
    
    for (const subsystem of ['S1', 'S2', 'S3', 'S4', 'S5']) {
      const metrics = await this.database.query(
        [
          `${subsystem}.health`,
          `${subsystem}.performance`,
          `${subsystem}.entropy`
        ],
        dayAgo,
        now
      );
      
      metricsData.set(subsystem, {
        health: this.getLatestValue(metrics.get(`${subsystem}.health`)),
        performance: this.getLatestValue(metrics.get(`${subsystem}.performance`)),
        entropy: this.getLatestValue(metrics.get(`${subsystem}.entropy`))
      });
    }
    
    // Get active alerts
    const alerts = this.alertManager.getActiveAlerts();
    
    // Get alert statistics
    const alertStats = this.alertManager.getAlertStatistics(24 * 60 * 60 * 1000);
    
    // Calculate system entropy
    const systemEntropy = await this.calculateSystemEntropy();
    
    return {
      timestamp: now,
      subsystems: metricsData,
      systemEntropy,
      alerts,
      alertStatistics: alertStats,
      varietyBalance: this.varietyBalancer.optimizeVarietyBalance(1000, 5)
    };
  }
  
  private getLatestValue(values?: Array<MetricValue>): number {
    if (!values || values.length === 0) return 0;
    return values[values.length - 1].value;
  }
}
```

## Conclusion

This implementation specification provides a complete framework for implementing the VSM metrics architecture. The modular design allows for:

1. **Flexible deployment** - Components can be used independently or together
2. **Scalable processing** - Streaming architecture handles high-volume metrics
3. **Adaptive thresholds** - Dynamic threshold calculation based on historical patterns
4. **Real-time insights** - Immediate calculation of entropy and variety metrics
5. **Comprehensive monitoring** - Full observability of VSM dynamics

The implementation can be extended with additional features such as:
- Machine learning-based anomaly detection
- Predictive analytics for future states
- Automated optimization recommendations
- Integration with external monitoring systems
- Advanced visualization capabilities

This forms a solid foundation for building a production-ready VSM metrics system.