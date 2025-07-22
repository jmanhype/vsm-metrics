# VSM Metrics

A distributed Elixir application for computing entropy and time-based diversity metrics across different system channels in the Viable System Model (VSM) framework.

## Overview

VSM Metrics implements the mathematical foundations of Stafford Beer's Viable System Model, focusing on:

- **Shannon Entropy Calculations**: Measure information content and variety across system channels
- **Time-Based Diversity Metrics**: Track how system variety changes over different time horizons
- **Distributed Architecture**: Built for high scalability using Elixir/OTP
- **CRDT-Based Aggregation**: Conflict-free distributed data aggregation
- **Multi-Tier Storage**: Hierarchical data storage optimized for different time constants

## Key Features

### 1. Entropy Computation
- Real-time Shannon entropy calculation for system channels
- Channel-specific variety measurement
- Cross-channel correlation analysis
- Temporal entropy evolution tracking

### 2. Time Constants Support
- Variable System 1 (operational): milliseconds to seconds
- Variable System 2 (coordination): seconds to minutes  
- Variable System 3 (management): minutes to hours
- Variable System 4 (strategic): hours to days
- Variable System 5 (policy): days to weeks

### 3. Distributed Architecture
- Built on Elixir/OTP for fault tolerance
- Phoenix PubSub for inter-node communication
- Libcluster for automatic node discovery
- CRDT-based state synchronization

### 4. Storage Architecture
- Hot tier: In-memory for real-time access
- Warm tier: Local disk for recent data
- Cold tier: Object storage for historical data
- Automatic tier migration based on access patterns

## Architecture

```
vsm_metrics/
├── lib/
│   └── vsm_metrics/
│       ├── storage/          # Multi-tier storage system
│       ├── aggregation/      # CRDT-based aggregation
│       ├── metrics/          # Core metric calculations
│       ├── entropy/          # Shannon entropy implementation
│       └── time_constants/   # VSM time-based functions
├── config/                   # Environment configurations
├── test/                     # Test suites
└── mix.exs                   # Project dependencies
```

## Installation

Add `vsm_metrics` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vsm_metrics, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure the application in your `config/config.exs`:

```elixir
config :vsm_metrics,
  cluster_strategy: :gossip,
  storage_tiers: [
    hot: [ttl: :timer.minutes(5)],
    warm: [ttl: :timer.hours(1)],
    cold: [ttl: :infinity]
  ],
  time_constants: [
    s1: :timer.seconds(1),
    s2: :timer.minutes(1),
    s3: :timer.hours(1),
    s4: :timer.hours(24),
    s5: :timer.hours(168)
  ]
```

## Usage

### Starting the Application

```elixir
# Start a distributed node
iex --name vsm@localhost -S mix

# The application will automatically:
# - Initialize storage tiers
# - Start metric collectors
# - Begin entropy calculations
```

### Computing Entropy

```elixir
# Calculate entropy for a channel
VsmMetrics.Entropy.calculate("channel_1", data)

# Get time-based diversity metrics
VsmMetrics.Metrics.diversity("channel_1", :s3)

# Aggregate metrics across nodes
VsmMetrics.Aggregation.aggregate_entropy(["channel_1", "channel_2"])
```

### Distributed Deployment

The application supports multiple deployment patterns:

1. **Single Node**: Development and testing
2. **Cluster**: Multiple nodes with automatic discovery
3. **Federation**: Cross-datacenter deployment with eventual consistency

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Start interactive console
iex -S mix

# Run with distributed node
iex --name vsm@localhost -S mix
```

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/vsm_metrics/entropy_test.exs
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on Stafford Beer's Viable System Model
- Inspired by the mathematical foundations of cybernetics
- Built with the Elixir/OTP platform for reliability and scalability