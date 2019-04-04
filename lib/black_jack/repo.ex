defmodule BlackJack.Repo do
  use Ecto.Repo,
    otp_app: :black_jack,
    adapter: Ecto.Adapters.Postgres
end
