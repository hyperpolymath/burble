# SPDX-License-Identifier: MPL-2.0
#
# BurbleWeb.GameChannel — one game session's typed relay lane.
#
# The two seats of `game:<session_id>` exchange their game's typed wire
# enums verbatim: a `"command"` or `"event"` message's payload IS the
# game's JSON, byte-preserving — burble reads only the routing tag and
# never interprets the body. Which seat may send which command tag comes
# from the session's registered game profile (Burble.Games), so this
# module contains no game-specific code at all.
#
# Ported from IDApTIK's session_channel.ex (the parity source; see
# docs/superpowers/specs/2026-08-04-game-session-fabric-design.md).
# Until the lobby slice lands, the joining client names its game in the
# join params; the lobby then becomes the authority and this param a
# cross-check.
defmodule BurbleWeb.GameChannel do
  use Phoenix.Channel

  alias Burble.Games

  @impl true
  def join("game:" <> _session_id, %{"role" => role, "game" => game_id}, socket)
      when is_binary(role) and is_binary(game_id) do
    case Games.fetch(game_id) do
      {:ok, profile} ->
        if role in profile.roles() do
          socket =
            socket
            |> assign(:role, role)
            |> assign(:game, game_id)
            |> assign(:profile, profile)
            |> assign(:last_seq, nil)

          send(self(), :after_join)
          {:ok, %{role: role, game: game_id}, socket}
        else
          {:error,
           %{reason: "unknown role #{inspect(role)} — #{game_id} seats: " <>
               Enum.join(profile.roles(), ", ")}}
        end

      :error ->
        {:error, %{reason: "unknown game: #{inspect(game_id)}"}}
    end
  end

  def join("game:" <> _session_id, params, _socket) do
    missing =
      ["role", "game"]
      |> Enum.reject(&Map.has_key?(params, &1))
      |> Enum.join(" and ")

    {:error, %{reason: "join requires #{missing}"}}
  end

  @impl true
  def handle_info(:after_join, socket) do
    broadcast_from!(socket, "peer_joined", %{"role" => socket.assigns.role})
    {:noreply, socket}
  end

  # Lightweight liveness check.
  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{"pong" => true}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.joined do
      broadcast_from!(socket, "peer_left", %{"role" => socket.assigns.role})
    end

    :ok
  end
end
