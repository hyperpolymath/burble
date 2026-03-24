# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# BurbleWeb.Plugs.GroovePlug — HTTP handler for groove discovery endpoints.
#
# Handles the /.well-known/groove/* paths that Gossamer (and other
# groove-aware systems) probe to discover Burble's capabilities.
#
# Routes:
#   GET  /.well-known/groove         → JSON manifest (static)
#   POST /.well-known/groove/message → Receive message from consumer
#   GET  /.well-known/groove/recv    → Drain pending messages for consumer
#
# This plug is designed to be inserted early in the pipeline (before
# the router) so that groove discovery works regardless of other
# middleware configuration.

defmodule BurbleWeb.Plugs.GroovePlug do
  @moduledoc """
  Plug for groove discovery endpoints.

  Inserted into the Endpoint before the router. Handles the lightweight
  HTTP protocol that Gossamer's groove.zig uses to discover services.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  # GET /.well-known/groove — Return the capability manifest.
  def call(
        %Plug.Conn{method: "GET", path_info: [".well-known", "groove"]} = conn,
        _opts
      ) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Burble.Groove.manifest_json())
    |> halt()
  end

  # POST /.well-known/groove/message — Receive a message from a consumer.
  # Note: Plug.Parsers has already consumed the body by this point in the
  # endpoint pipeline, so we read from conn.body_params (parsed JSON) or
  # fall back to read_body for raw HTTP/1.0 requests from Zig groove probes.
  #
  # Body size is implicitly limited by Plug.Parsers (:length default = 8MB).
  # Groove messages are typically < 1KB, so this is generous.
  def call(
        %Plug.Conn{method: "POST", path_info: [".well-known", "groove", "message"]} = conn,
        _opts
      ) do
    message =
      case conn.body_params do
        %Plug.Conn.Unfetched{} ->
          # Body not yet parsed (e.g. raw HTTP/1.0 from Zig groove client).
          case Plug.Conn.read_body(conn) do
            {:ok, body, _conn} -> Jason.decode(body)
            _ -> {:error, :no_body}
          end

        %{"_json" => json} when is_map(json) ->
          {:ok, json}

        params when is_map(params) and map_size(params) > 0 ->
          {:ok, params}

        _ ->
          {:error, :empty}
      end

    case message do
      {:ok, msg} ->
        Burble.Groove.push_message(msg)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"ok":true}))
        |> halt()

      {:error, _reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, ~s({"ok":false,"error":"invalid JSON"}))
        |> halt()
    end
  end

  # GET /.well-known/groove/recv — Drain pending messages.
  # Handles gracefully if the Groove GenServer hasn't started yet.
  def call(
        %Plug.Conn{method: "GET", path_info: [".well-known", "groove", "recv"]} = conn,
        _opts
      ) do
    messages =
      try do
        Burble.Groove.pop_messages()
      catch
        :exit, _ -> []
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(messages))
    |> halt()
  end

  # Pass through everything else.
  def call(conn, _opts), do: conn
end
