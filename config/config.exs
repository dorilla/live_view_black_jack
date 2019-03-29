# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :drag_n_drop,
  ecto_repos: [DragNDrop.Repo]

# Configures the endpoint
config :drag_n_drop, DragNDropWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "htvUM9iA0YHzcQ0v1Z3OKYWg2La2Bhfnu0UueI0P66mpdtIdx60rMML3sR+aZIIh",
  render_errors: [view: DragNDropWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: DragNDrop.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "015A8dTIldakFsDRsLI6uJqAKPrWTeWJ"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# enable LiveView templates
config :phoenix, template_engines: [leex: Phoenix.LiveView.Engine]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
