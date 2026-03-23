defmodule EconSim.MixProject do
  use Mix.Project

  def project do
    [
      app: :econ_sim,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {EconSim.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix core — use v1.7 branch (compatible with Elixir 1.14)
      {:phoenix, github: "phoenixframework/phoenix", branch: "v1.7", override: true},
      {:phoenix_html, github: "phoenixframework/phoenix_html", tag: "v4.1.1", override: true},
      {:phoenix_live_view, github: "phoenixframework/phoenix_live_view", tag: "v0.20.17", override: true},
      {:phoenix_live_reload, github: "phoenixframework/phoenix_live_reload", tag: "v1.5.3", only: :dev, override: true},
      {:phoenix_template, github: "phoenixframework/phoenix_template", tag: "v1.0.4", override: true},
      {:phoenix_pubsub, github: "phoenixframework/phoenix_pubsub", tag: "v2.1.3", override: true},

      # Plug / Cowboy — use versions compatible with Elixir 1.14
      {:plug, github: "elixir-plug/plug", tag: "v1.15.3", override: true},
      {:plug_crypto, github: "elixir-plug/plug_crypto", tag: "v2.1.0", override: true},
      {:plug_cowboy, github: "elixir-plug/plug_cowboy", tag: "v2.7.2", override: true},
      {:cowboy, github: "ninenines/cowboy", tag: "2.12.0", override: true},
      {:cowlib, github: "ninenines/cowlib", tag: "2.13.0", override: true},
      {:ranch, github: "ninenines/ranch", tag: "1.8.0", override: true},
      {:cowboy_telemetry, github: "beam-telemetry/cowboy_telemetry", tag: "v0.4.0", override: true},
      {:websock_adapter, github: "phoenixframework/websock_adapter", tag: "0.5.7", override: true},
      {:websock, github: "phoenixframework/websock", tag: "0.5.3", override: true},

      # Telemetry
      {:telemetry, github: "beam-telemetry/telemetry", tag: "v1.2.1", override: true},
      {:telemetry_metrics, github: "beam-telemetry/telemetry_metrics", tag: "v1.0.0", override: true},
      {:telemetry_poller, github: "beam-telemetry/telemetry_poller", tag: "v1.1.0", override: true},

      # Utilities
      {:jason, github: "michalmuskala/jason", tag: "v1.4.4", override: true},
      {:mime, github: "elixir-plug/mime", tag: "v2.0.6", override: true},
      {:castore, github: "elixir-mint/castore", tag: "v1.0.8", override: true},
      {:file_system, github: "falood/file_system", tag: "v1.0.1", override: true}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
