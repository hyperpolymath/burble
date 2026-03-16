# SPDX-License-Identifier: PMPL-1.0-or-later
#
# BurbleWeb.Router — HTTP routing for the Burble API.

defmodule BurbleWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BurbleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # API routes
  scope "/api/v1", BurbleWeb.API do
    pipe_through :api

    # Auth
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/guest", AuthController, :guest
    post "/auth/magic-link", AuthController, :magic_link
    delete "/auth/logout", AuthController, :logout

    # Servers
    get "/servers", ServerController, :index
    post "/servers", ServerController, :create
    get "/servers/:id", ServerController, :show

    # Rooms
    get "/servers/:server_id/rooms", RoomController, :index
    post "/servers/:server_id/rooms", RoomController, :create
    get "/rooms/:id", RoomController, :show
    get "/rooms/:id/participants", RoomController, :participants

    # Invites
    post "/servers/:server_id/invites", InviteController, :create
    post "/invites/:token/accept", InviteController, :accept
  end

  # LiveDashboard for operators (dev + prod with auth)
  if Application.compile_env(:burble, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: Burble.Telemetry
    end
  end

  # Serve the MVP web client at root
  scope "/", BurbleWeb do
    pipe_through :browser
    get "/", PageController, :index
  end

  @doc false
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt index.html)
end

defmodule BurbleWeb do
  @moduledoc false

  def static_paths, do: BurbleWeb.Router.static_paths()
end
