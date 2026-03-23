defmodule EconSimWeb.Router do
  use EconSimWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EconSimWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", EconSimWeb do
    pipe_through :browser

    live "/", SimulationLive
  end
end
