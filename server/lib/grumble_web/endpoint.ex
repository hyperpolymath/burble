# SPDX-License-Identifier: PMPL-1.0-or-later
#
# BurbleWeb.Endpoint — Phoenix HTTP/WebSocket endpoint.

defmodule BurbleWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :burble

  @session_options [
    store: :cookie,
    key: "_burble_key",
    signing_salt: "burble_voice",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  socket "/voice", BurbleWeb.UserSocket,
    websocket: [timeout: :infinity],
    longpoll: false

  plug Plug.Static,
    at: "/",
    from: :burble,
    gzip: false,
    only: BurbleWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Corsica, origins: "*", allow_headers: :all
  plug BurbleWeb.Router
end
