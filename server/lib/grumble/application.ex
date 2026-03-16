# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Grumble.Application — OTP supervision tree root.
#
# Starts the core services in dependency order:
#   1. Database (Ecto Repo)
#   2. PubSub (Phoenix.PubSub for room events)
#   3. Presence tracker (who's in which room)
#   4. Room registry (named process per active room)
#   5. Telemetry supervisor (metrics + periodic polling)
#   6. Web endpoint (Phoenix, WebSocket signaling)

defmodule Grumble.Application do
  @moduledoc """
  OTP Application for Grumble voice server.

  The supervision tree is structured so that:
  - Database failures don't crash the web endpoint
  - Room processes are isolated (one room crash doesn't affect others)
  - Telemetry is always running for observability
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database
      Grumble.Repo,

      # PubSub for real-time events (room join/leave, voice state changes)
      {Phoenix.PubSub, name: Grumble.PubSub},

      # Presence tracking (who's in which room, voice state)
      Grumble.Presence,

      # Room supervisor — DynamicSupervisor for room processes
      {DynamicSupervisor, name: Grumble.RoomSupervisor, strategy: :one_for_one},

      # Room registry — maps room IDs to PIDs
      {Registry, keys: :unique, name: Grumble.RoomRegistry},

      # Text channels (NNTPS-backed persistent threaded messages)
      Grumble.Text.NNTPSBackend,

      # Media plane — Membrane SFU (WebRTC audio routing)
      Grumble.Media.Engine,

      # Telemetry
      Grumble.Telemetry,

      # Web endpoint (must be last — depends on PubSub and Presence)
      GrumbleWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Grumble.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GrumbleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
