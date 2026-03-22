# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# BurbleWeb.API.HealthController — HTTP health endpoint.
#
# Returns server health status for load balancers, container orchestrators,
# and the Gossamer admin panel. Checks OTP supervision tree and VeriSimDB
# connectivity.

defmodule BurbleWeb.API.HealthController do
  @moduledoc """
  Health check endpoint.

  `GET /api/v1/health` returns:
  - `200 OK` with `{"status": "healthy", ...}` when all systems are operational.
  - `503 Service Unavailable` with `{"status": "degraded", ...}` when a
    subsystem is down but the server can still accept requests.
  """

  use Phoenix.Controller, formats: [:json]

  @doc """
  Return the current health status.

  Checks:
  - OTP supervision tree is alive
  - VeriSimDB store is reachable
  - PubSub is functional
  """
  def check(conn, _params) do
    supervisor_ok = Process.whereis(Burble.Supervisor) != nil
    pubsub_ok = Process.whereis(Burble.PubSub) != nil

    verisimdb_status =
      case Burble.Store.health() do
        {:ok, true} -> :healthy
        {:ok, false} -> :degraded
        {:error, _} -> :unreachable
      end

    overall =
      if supervisor_ok and pubsub_ok and verisimdb_status == :healthy do
        :healthy
      else
        :degraded
      end

    status_code = if overall == :healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: overall,
      version: Application.spec(:burble, :vsn) |> to_string(),
      checks: %{
        supervisor: if(supervisor_ok, do: "ok", else: "down"),
        pubsub: if(pubsub_ok, do: "ok", else: "down"),
        verisimdb: verisimdb_status
      },
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    })
  end
end
