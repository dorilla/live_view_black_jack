defmodule DragNDrop.Repo do
  use Ecto.Repo,
    otp_app: :drag_n_drop,
    adapter: Ecto.Adapters.Postgres
end
