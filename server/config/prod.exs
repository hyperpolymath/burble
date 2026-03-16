# SPDX-License-Identifier: PMPL-1.0-or-later

import Config

config :burble, BurbleWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "example.com", port: 443, scheme: "https"],
  force_ssl: [hsts: true]

config :burble, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :logger, level: :info
