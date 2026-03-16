# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule GrumbleWeb.API.ServerController do
  use Phoenix.Controller, formats: [:json]

  # MVP: single hardcoded server. Multi-server from database later.
  def index(conn, _params) do
    json(conn, %{servers: [%{id: "default", name: "Grumble Server", room_count: 0}]})
  end

  def create(conn, _params) do
    json(conn, %{id: "default", name: "Grumble Server"})
  end

  def show(conn, %{"id" => _id}) do
    json(conn, %{id: "default", name: "Grumble Server", room_count: 0, member_count: 0})
  end
end
