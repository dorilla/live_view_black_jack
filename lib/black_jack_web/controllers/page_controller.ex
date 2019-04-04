defmodule BlackJackWeb.PageController do
  use BlackJackWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
