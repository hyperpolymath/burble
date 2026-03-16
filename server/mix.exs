# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble Server — Elixir/Phoenix control plane.
#
# OTP supervision tree managing auth, rooms, presence, permissions,
# moderation, signaling, telemetry, and audit logging.

defmodule Burble.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :burble,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Burble",
      description: "Voice-first communications server. Self-hostable. WebRTC-compatible.",
      source_url: "https://github.com/hyperpolymath/burble",
      docs: [main: "Burble", extras: ["../README.adoc"]]
    ]
  end

  def application do
    [
      mod: {Burble.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Web framework
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},

      # WebSocket transport for voice signaling
      {:phoenix_pubsub, "~> 2.1"},

      # JSON encoding
      {:jason, "~> 1.4"},

      # HTTP server
      {:bandit, "~> 1.6"},

      # Authentication
      {:bcrypt_elixir, "~> 3.2"},
      {:guardian, "~> 2.3"},
      {:jose, "~> 1.11"},

      # Database (user accounts, room config, audit logs)
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},

      # Telemetry and observability
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Rate limiting
      {:hammer, "~> 6.2"},

      # Media plane — ex_webrtc for MVP, Membrane full stack later
      {:ex_webrtc, "~> 0.9"},

      # CORS for web client
      {:corsica, "~> 2.1"},

      # Protobuf (wire protocol)
      {:protobuf, "~> 0.13"},

      # Dev/test
      {:phoenix_ecto, "~> 4.6"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
