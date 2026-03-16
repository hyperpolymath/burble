# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble.Repo — Ecto repository for PostgreSQL.
#
# Stores persistent data: user accounts, server configs, room configs,
# role definitions, audit logs, invite tokens.
#
# Dogfooding note: audit log and session telemetry are candidates
# for VeriSimDB integration when that project matures.

defmodule Burble.Repo do
  use Ecto.Repo,
    otp_app: :burble,
    adapter: Ecto.Adapters.Postgres
end
