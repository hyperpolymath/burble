# SPDX-License-Identifier: PMPL-1.0-or-later
#
# GrumbleWeb.UserSocket — WebSocket entry point for voice signaling.
#
# Clients connect here and then join room channels for voice comms.
# Authentication happens at connect time via token verification.

defmodule GrumbleWeb.UserSocket do
  use Phoenix.Socket

  channel "room:*", GrumbleWeb.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_token(token) do
      {:ok, user_data} ->
        socket =
          socket
          |> assign(:user_id, user_data.id)
          |> assign(:display_name, user_data.display_name)
          |> assign(:is_guest, Map.get(user_data, :is_guest, false))

        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  # Guest connection (no token required if server policy allows)
  def connect(%{"guest" => "true", "display_name" => name}, socket, _connect_info) do
    {:ok, guest} = Grumble.Auth.create_guest_session(name)

    socket =
      socket
      |> assign(:user_id, guest.id)
      |> assign(:display_name, guest.display_name)
      |> assign(:is_guest, true)

    {:ok, socket}
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  defp verify_token(token) do
    # TODO: Guardian token verification
    # For now, accept any non-empty token during development
    case Phoenix.Token.verify(GrumbleWeb.Endpoint, "user_auth", token, max_age: 86_400) do
      {:ok, user_id} -> {:ok, %{id: user_id, display_name: "User"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
