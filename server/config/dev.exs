# SPDX-License-Identifier: PMPL-1.0-or-later

import Config

config :grumble, Grumble.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "grumble_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :grumble, GrumbleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_only_secret_key_base_that_must_be_replaced_in_production_with_real_secret",
  watchers: []

config :grumble, dev_routes: true

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
