# VSM Metrics - Umbrella Integration Guide

## Current Status

VSM Metrics is currently a standalone Elixir application that can be integrated into the VSM umbrella project.

## Integration Steps

### Option 1: Add as Git Submodule to Main Umbrella

```bash
cd /home/batmanosama/viable-systems
git submodule add https://github.com/jmanhype/vsm-metrics.git vsm-metrics
```

### Option 2: Move to Umbrella Apps Directory

```bash
# Move vsm-metrics to the umbrella apps directory
cd /home/batmanosama/viable-systems
mv vsm-metrics apps/vsm_metrics

# Update the app name in mix.exs to match umbrella conventions
# Change app: :vsm_metrics to app: :vsm_metrics in mix.exs
```

### Option 3: Add as Dependency

Add to your umbrella's root `mix.exs`:

```elixir
defp deps do
  [
    # Other deps...
    {:vsm_metrics, path: "./vsm-metrics"}
  ]
end
```

Or if using from GitHub:

```elixir
{:vsm_metrics, github: "jmanhype/vsm-metrics"}
```

## Configuration for Umbrella

Once integrated, vsm-metrics will:

1. **Share dependencies** with other VSM components
2. **Use common telemetry** infrastructure
3. **Integrate with VSM Event Bus** for inter-component communication
4. **Provide metrics** to all VSM subsystems

## Inter-component Communication

VSM Metrics can communicate with other VSM components:

```elixir
# From any VSM component
VsmMetrics.record(:s3, :operation, "control_decision")

# Subscribe to metrics via Event Bus
VsmEventBus.subscribe("vsm.metrics.*")
```

## Shared Resources

VSM Metrics uses:
- `phoenix_pubsub` - Compatible with VSM Event Bus
- `telemetry` - Same as other VSM components
- `libcluster` - For distributed deployments

## Running with Umbrella

```bash
# From umbrella root
mix deps.get
mix compile

# Start all apps
iex -S mix

# Or start specific app
iex -S mix run --no-start
Application.ensure_all_started(:vsm_metrics)
```