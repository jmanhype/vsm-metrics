defmodule VsmMetrics.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_metrics,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {VsmMetrics.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Distributed communication
      {:phoenix_pubsub, "~> 2.1"},
      
      # Clustering
      {:libcluster, "~> 3.3"},
      
      # CRDT support
      {:delta_crdt, "~> 0.6"},
      
      # Observability
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end
end
