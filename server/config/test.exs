# SPDX-License-Identifier: PMPL-1.0-or-later

import Config

config :grumble, Grumble.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "grumble_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :grumble, GrumbleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_only_secret_key_base_for_testing_purposes_only_do_not_use_in_production",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :bcrypt_elixir, :log_rounds, 1
