defmodule DragNDropWeb.PageController do
  use DragNDropWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
