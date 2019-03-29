defmodule GameManager.Manager do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [
      {:ets_table_name, :game_manager_table},
      {:log_limit, 1_000_000}
    ], opts)
  end

  def get_game_state do
    %{
      dealer: get("dealer"),
      seat_1: get("seat_1"),
      seat_2: get("seat_2"),
      seat_3: get("seat_3"),
      seat_4: get("seat_4"),
      seat_5: get("seat_5")
    }
  end

  def occupy_seat(seat_id, player_id) do
    set("seat_#{seat_id}", init_player(player_id))

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  def leave_seat(input_player_id) do
    if get("seat_1").player_id == input_player_id, do: set("seat_1", blank_player)
    if get("seat_2").player_id == input_player_id, do: set("seat_2", blank_player)
    if get("seat_3").player_id == input_player_id, do: set("seat_3", blank_player)
    if get("seat_4").player_id == input_player_id, do: set("seat_4", blank_player)
    if get("seat_5").player_id == input_player_id, do: set("seat_5", blank_player)

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  def set_name(seat_id, name) do
    seat = "seat_#{seat_id}"
    seat_data = get(seat)
      |> Map.put(:player_name, name)

    set(seat, seat_data)

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  defp get(slug) do
    case GenServer.call(__MODULE__, {:get, slug}) do
      [] -> {:not_found}
      [{_slug, result}] -> result
    end
  end

  defp set(slug, value) do
    GenServer.call(__MODULE__, {:set, slug, value})
  end

  defp blank_player do
    %{
      player_id: nil,
      player_name: nil,
      hand: [],
      money: nil
    }
  end

  defp init_player(player_id) do
    %{
      player_id: player_id,
      player_name: nil,
      hand: [],
      money: 1000
    }
  end

  # GenServer callbacks

  def handle_call({:get, slug}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    result = :ets.lookup(ets_table_name, slug)
    {:reply, result, state}
  end

  def handle_call({:set, slug, value}, _from, state) do
    %{ets_table_name: ets_table_name} = state
    :ets.insert(ets_table_name, {slug, value})
    {:reply, value, state}
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    # :ets.new(ets_table_name, [:named_table, :set, :private])
    :ets.new(ets_table_name, [:named_table, :set])

    :ets.insert(ets_table_name, {"dealer", [
      "Six",
      "Seven"
    ]})

    :ets.insert(ets_table_name, {"seat_1", blank_player()})
    :ets.insert(ets_table_name, {"seat_2", blank_player()})
    :ets.insert(ets_table_name, {"seat_3", blank_player()})
    :ets.insert(ets_table_name, {"seat_4", blank_player()})
    :ets.insert(ets_table_name, {"seat_5", blank_player()})

    {:ok, %{log_limit: log_limit, ets_table_name: ets_table_name}}
  end
end
