# BlackJack

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

# Info

This repo is the code behind https://polite-angelic-beaver.gigalixirapp.com/.

It is a Phoenix Application utilizing [LiveView](https://github.com/phoenixframework/phoenix_live_view).

The main pieces of code lives in:
* `lib/black_jack_web/live/black_jack_live.ex`
  * Main templating logic
* `lib/game_manager/live/manager.ex`
  * This is the dealer simulater
