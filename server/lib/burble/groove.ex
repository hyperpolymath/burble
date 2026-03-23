# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Burble.Groove — Gossamer Groove endpoint for capability discovery.
#
# Exposes Burble's voice/text capabilities via the groove discovery protocol.
# Any groove-aware system (Gossamer, PanLL, GSA, AmbientOps, etc.) can discover
# Burble by probing GET /.well-known/groove on port 6473.
#
# Works standalone — Burble functions perfectly without any groove consumer.
# When a consumer connects, additional features light up (panel embedding,
# workspace voice, admin alerts, etc.).
#
# The groove connector types are formally verified in Gossamer's Groove.idr:
# - CapabilityType proves what we offer is well-typed
# - IsSubset proves consumers can only connect if we satisfy their needs
# - GrooveHandle is linear: consumers MUST disconnect (no dangling grooves)
#
# Groove Protocol:
#   GET  /.well-known/groove         — Capability manifest (JSON)
#   POST /.well-known/groove/message — Receive message from consumer
#   GET  /.well-known/groove/recv    — Pending messages for consumer
#
# Integration Patterns:
#   Gossamer  → Voice panel in webview shell (spatial audio, PTT, presence)
#   PanLL     → Workspace voice layer (VoiceTag, operator commands, panel events)
#   GSA       → Voice alerts for server health (TTS, escalation, team channels)
#   AmbientOps → Escalation voice (Ward→ER→OR department channels)
#   RPA Elysium → Bot failure voice alerts (EventBus notification backend)
#   IDApTIK   → In-game co-op voice (Jessica↔Q spatial audio)
#   Vext      → Message integrity (hash chain verification on text channels)

defmodule Burble.Groove do
  @moduledoc """
  Manages the groove message queue and manifest for Burble.

  Started as part of the Burble supervision tree. Maintains an in-memory
  queue of messages from groove consumers (Gossamer, PanLL, etc.) and
  provides the static capability manifest.
  """

  use GenServer

  @manifest %{
    groove_version: "1",
    service_id: "burble",
    service_version: "0.1.0",
    capabilities: %{
      voice: %{
        type: "voice",
        description: "WebRTC voice channels with Opus codec, noise suppression, echo cancellation",
        protocol: "webrtc",
        endpoint: "/voice",
        requires_auth: false,
        panel_compatible: true
      },
      text: %{
        type: "text",
        description: "Real-time text messaging in rooms via Phoenix Channels",
        protocol: "websocket",
        endpoint: "/socket/websocket",
        requires_auth: false,
        panel_compatible: true
      },
      presence: %{
        type: "presence",
        description: "User presence and speaking indicators via Phoenix Presence",
        protocol: "websocket",
        endpoint: "/socket/websocket",
        requires_auth: false,
        panel_compatible: true
      },
      spatial_audio: %{
        type: "spatial-audio",
        description: "Positional audio for game integration (x, y, z coordinates)",
        protocol: "webrtc",
        endpoint: "/voice",
        requires_auth: true,
        panel_compatible: false
      },
      recording: %{
        type: "recording",
        description: "Server-side voice recording with consent tracking via Avow",
        protocol: "http",
        endpoint: "/api/v1/recordings",
        requires_auth: true,
        panel_compatible: true
      },
      tts: %{
        type: "tts",
        description: "Text-to-speech synthesis for voice alerts and notifications",
        protocol: "http",
        endpoint: "/api/v1/tts",
        requires_auth: false,
        panel_compatible: false
      },
      stt: %{
        type: "stt",
        description: "Speech-to-text transcription for voice commands and VoiceTag",
        protocol: "http",
        endpoint: "/api/v1/stt",
        requires_auth: false,
        panel_compatible: false
      }
    },
    consumes: ["integrity", "octad-storage", "scanning"],
    endpoints: %{
      voice_ws: "ws://localhost:6473/voice",
      channel_ws: "ws://localhost:6473/socket/websocket",
      api: "http://localhost:6473/api/v1",
      health: "http://localhost:6473/api/v1/health"
    },
    health: "/api/v1/health",
    applicability: ["individual", "team", "massive-open"]
  }

  # Maximum queue depth to prevent memory exhaustion.
  @max_queue_depth 1000

  # --- Client API ---

  @doc "Start the groove GenServer."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Return the groove capability manifest as a map."
  def manifest, do: @manifest

  @doc "Return the manifest as JSON."
  def manifest_json do
    Jason.encode!(@manifest)
  end

  @doc "Enqueue a message from a groove consumer."
  def push_message(message) when is_map(message) do
    GenServer.call(__MODULE__, {:push, message})
  end

  @doc "Drain all pending messages for groove consumers."
  def pop_messages do
    GenServer.call(__MODULE__, :pop)
  end

  @doc "Get current queue depth."
  def queue_depth do
    GenServer.call(__MODULE__, :depth)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{queue: :queue.new(), depth: 0}}
  end

  @impl true
  def handle_call({:push, message}, _from, %{queue: q, depth: d} = state) do
    if d >= @max_queue_depth do
      # Drop oldest message to make room.
      {_dropped, q2} = :queue.out(q)
      {:reply, :ok, %{state | queue: :queue.in(message, q2)}}
    else
      {:reply, :ok, %{state | queue: :queue.in(message, q), depth: d + 1}}
    end
  end

  @impl true
  def handle_call(:pop, _from, %{queue: q}) do
    messages = :queue.to_list(q)
    {:reply, messages, %{queue: :queue.new(), depth: 0}}
  end

  @impl true
  def handle_call(:depth, _from, %{depth: d} = state) do
    {:reply, d, state}
  end
end
