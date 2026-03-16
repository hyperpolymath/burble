# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Grumble server configuration.

import Config

config :grumble,
  ecto_repos: [Grumble.Repo],
  generators: [timestamp_type: :utc_datetime]

config :grumble, GrumbleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: GrumbleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Grumble.PubSub,
  live_view: [signing_salt: "grumble_lv"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
