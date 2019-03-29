use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :drag_n_drop, DragNDropWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :drag_n_drop, DragNDrop.Repo,
  username: "postgres",
  password: "postgres",
  database: "drag_n_drop_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
