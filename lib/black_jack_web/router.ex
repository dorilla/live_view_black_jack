defmodule BlackJackWeb.Router do
  use BlackJackWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BlackJackWeb do
    pipe_through :browser

    get "/", PageController, :index
    live "/black_jack", BlackJackLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", BlackJackWeb do
  #   pipe_through :api
  # end
end
