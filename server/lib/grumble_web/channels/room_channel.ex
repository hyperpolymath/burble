# SPDX-License-Identifier: PMPL-1.0-or-later
#
# BurbleWeb.RoomChannel — WebSocket channel for voice room signaling.
#
# Handles:
#   - Room join/leave lifecycle
#   - Voice state changes (mute, deafen, priority)
#   - WebRTC signaling (offer/answer/ICE candidate exchange)
#   - Presence tracking (who's in the room)
#   - Text messages within the room
#
# This is the signaling plane — actual audio flows via WebRTC peer
# connections negotiated through this channel.

defmodule BurbleWeb.RoomChannel do
  @moduledoc """
  Phoenix Channel for voice room signaling.

  ## Topics

  Clients join `"room:<room_id>"` to participate in a voice room.

  ## Incoming events

  - `"voice_state"` — update own voice state (mute/deafen/etc.)
  - `"signal"` — WebRTC signaling (offer, answer, ice_candidate)
  - `"text"` — send a text message in the room
  - `"whisper"` — direct audio to a specific user

  ## Outgoing events

  - `"presence_state"` — initial presence snapshot
  - `"presence_diff"` — presence changes (join/leave)
  - `"voice_state_changed"` — another user's voice state changed
  - `"signal"` — WebRTC signaling from another peer
  - `"text"` — text message from another user
  - `"room_state"` — full room state update
  """

  use Phoenix.Channel

  alias Burble.Presence
  alias Burble.Rooms.RoomManager

  @impl true
  def join("room:" <> room_id, params, socket) do
    user_id = socket.assigns[:user_id]
    display_name = Map.get(params, "display_name", socket.assigns[:display_name] || "Guest")

    case RoomManager.join(room_id, user_id, %{display_name: display_name}) do
      {:ok, room_state} ->
        send(self(), :after_join)

        socket =
          socket
          |> assign(:room_id, room_id)
          |> assign(:display_name, display_name)

        {:ok, room_state, socket}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Track presence with voice state metadata
    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        display_name: socket.assigns.display_name,
        voice_state: "connected",
        joined_at: System.system_time(:second)
      })

    # Push current presence state to the joining user
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # ── Voice state ──

  @impl true
  def handle_in("voice_state", %{"state" => state}, socket) when state in ["connected", "muted", "deafened"] do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id
    state_atom = String.to_existing_atom(state)

    Burble.Rooms.Room.set_voice_state(room_id, user_id, state_atom)

    # Update presence metadata
    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :voice_state, state)
    end)

    broadcast!(socket, "voice_state_changed", %{
      user_id: user_id,
      voice_state: state
    })

    {:noreply, socket}
  end

  # ── WebRTC signaling ──

  @impl true
  def handle_in("signal", %{"to" => target_id, "type" => type, "payload" => payload}, socket) do
    # Forward signaling message to the target peer
    broadcast!(socket, "signal", %{
      from: socket.assigns.user_id,
      to: target_id,
      type: type,
      payload: payload
    })

    {:noreply, socket}
  end

  # ── Text messages ──

  @impl true
  def handle_in("text", %{"body" => body}, socket) when byte_size(body) > 0 and byte_size(body) <= 2000 do
    broadcast!(socket, "text", %{
      user_id: socket.assigns.user_id,
      display_name: socket.assigns.display_name,
      body: body,
      sent_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    {:noreply, socket}
  end

  # ── Whisper (directed audio) ──

  @impl true
  def handle_in("whisper", %{"to" => target_id}, socket) do
    broadcast!(socket, "whisper", %{
      from: socket.assigns.user_id,
      to: target_id
    })

    {:noreply, socket}
  end

  # ── Cleanup ──

  @impl true
  def terminate(_reason, socket) do
    room_id = socket.assigns[:room_id]
    user_id = socket.assigns[:user_id]

    if room_id && user_id do
      Burble.Rooms.Room.leave(room_id, user_id)
    end

    :ok
  end
end
