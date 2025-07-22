defmodule VsmMetrics.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Storage tiers - start in order (memory -> ETS -> DETS)
      {VsmMetrics.Storage.MemoryTier, []},
      {VsmMetrics.Storage.ETSTier, []},
      {VsmMetrics.Storage.DETSTier, [data_dir: "./data/dets"]},
      
      # Aggregation and metrics
      {VsmMetrics.Aggregation.CRDTAggregator, [enable_sync: true]},
      {VsmMetrics.Metrics.SubsystemMetrics, []},
      
      # Telemetry and monitoring
      {Telemetry.Metrics.ConsoleReporter, metrics: telemetry_metrics()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: VsmMetrics.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp telemetry_metrics do
    [
      # VM Metrics
      Telemetry.Metrics.last_value("vm.memory.total", unit: :byte),
      Telemetry.Metrics.last_value("vm.total_run_queue_lengths.total"),
      
      # Custom VSM Metrics
      Telemetry.Metrics.counter("vsm.metrics.record"),
      Telemetry.Metrics.summary("vsm.storage.latency"),
      Telemetry.Metrics.distribution("vsm.entropy.value"),
      Telemetry.Metrics.last_value("vsm.variety.ratio")
    ]
  end
end
