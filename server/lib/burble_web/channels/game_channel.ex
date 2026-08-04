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

  # A typed game command (tagged "cmd") -> the other seat, verbatim except
  # for the optional "seq" relay-envelope key.
  def handle_in("command", payload, socket) when is_map(payload) do
    with {:ok, tag} <- command_tag(payload, socket.assigns.profile),
         :ok <- authorize(tag, socket) do
      case note_seq(payload, socket) do
        {:fresh, socket} ->
          broadcast_from!(socket, "command", Map.delete(payload, "seq"))
          {:reply, {:ok, %{"relayed" => true}}, socket}

        {:stale, socket} ->
          # A duplicate or out-of-order send is a fact of networks, not a
          # protocol violation: acknowledge it, drop it, relay nothing.
          {:reply, {:ok, %{"relayed" => false, "reason" => "stale_or_duplicate"}}, socket}
      end
    else
      {:error, reason} -> {:reply, {:error, %{"reason" => reason}}, socket}
    end
  end

  def handle_in("command", _payload, socket) do
    {:reply, {:error, %{"reason" => "command payload must be a JSON object"}}, socket}
  end

  # A typed game Event (tagged "event") -> the other seat, verbatim.
  # Events are produced by the peers' deterministic engines, not authored
  # by a seat, so both roles may publish them (lockstep cross-feed).
  def handle_in("event", %{"event" => tag} = payload, socket) when is_binary(tag) do
    broadcast_from!(socket, "event", payload)
    {:reply, {:ok, %{"relayed" => true}}, socket}
  end

  def handle_in("event", _payload, socket) do
    {:reply, {:error, %{"reason" => "event payload must carry the \"event\" tag"}}, socket}
  end

  # Anything else — refuse politely instead of crashing the channel (a stale
  # or foreign client must not read as a peer loss to the other seat).
  def handle_in(event, _payload, socket) do
    {:reply, {:error, %{"reason" => "unknown message: #{inspect(event)}"}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.joined do
      broadcast_from!(socket, "peer_left", %{"role" => socket.assigns.role})
    end

    :ok
  end

  # -- helpers ---------------------------------------------------------------

  defp command_tag(%{"cmd" => tag}, profile) when is_binary(tag) do
    if Map.has_key?(profile.command_roles(), tag) do
      {:ok, tag}
    else
      {:error, "unknown command: #{inspect(tag)}"}
    end
  end

  defp command_tag(_payload, _profile),
    do: {:error, "command payload must carry the \"cmd\" tag"}

  defp authorize(tag, socket) do
    role = socket.assigns.role

    case Burble.Games.sender_for(socket.assigns.profile, tag) do
      :either -> :ok
      ^role -> :ok
      owner -> {:error, "#{tag} is a #{owner} command (you joined as #{role})"}
    end
  end

  # Track the optional "seq" envelope: a fresh (strictly increasing) integer
  # relays; a duplicate or out-of-order one drops gracefully. Commands
  # without "seq" are always fresh — ordering is then the transport's.
  defp note_seq(%{"seq" => seq}, socket) when is_integer(seq) do
    case socket.assigns.last_seq do
      last when is_integer(last) and seq <= last -> {:stale, socket}
      _ -> {:fresh, assign(socket, :last_seq, seq)}
    end
  end

  defp note_seq(_payload, socket), do: {:fresh, socket}
end
