# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule BurbleWeb.API.InviteController do
  use Phoenix.Controller, formats: [:json]

  alias Burble.Auth

  def create(conn, %{"server_id" => server_id} = params) do
    opts = [
      max_uses: Map.get(params, "max_uses", 10),
      expires_in: Map.get(params, "expires_in", 86_400)
    ]

    case Auth.generate_invite_token(server_id, opts) do
      {:ok, invite} -> json(conn, invite)
      {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
    end
  end

  def accept(conn, %{"token" => _token}) do
    # MVP: accept any token
    json(conn, %{status: "accepted", server_id: "default"})
  end
end
