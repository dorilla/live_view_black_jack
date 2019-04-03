defmodule GameManager.Manager do
  use GenServer

  # Phases
  # WAIT_FOR_INITIAL_BET
  # FINISH_BETS -> happens after the first bet
  # DEAL_INITIAL -> no more bets
  # DEAL_PLAYER_1 -> hit/stand action. check if blackjack or bust or 21
  # DEAL_PLAYER_X -> ****
  # PAY_OUT
  # back to WAIT_FOR_INITIAL_BET

  @suit [
    :HEART,
    :DIAMOND,
    :SPADE,
    :CLUB
  ]

  @rank [
    :ACE,
    :TWO,
    :THREE,
    :FOUR,
    :FIVE,
    :SIX,
    :SEVEN,
    :EIGHT,
    :NINE,
    :TEN,
    :JACK,
    :QUEEN,
    :KING
  ]

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
      seat_5: get("seat_5"),
      phase: get("phase"),
      countdown: get("countdown")
    }
  end

  def occupy_seat(seat_id, player_id) do
    set("seat_#{seat_id}", init_player(player_id))

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  def leave_seat(input_player_id) do
    if get("seat_1").player_id == input_player_id, do: set("seat_1", blank_player())
    if get("seat_2").player_id == input_player_id, do: set("seat_2", blank_player())
    if get("seat_3").player_id == input_player_id, do: set("seat_3", blank_player())
    if get("seat_4").player_id == input_player_id, do: set("seat_4", blank_player())
    if get("seat_5").player_id == input_player_id, do: set("seat_5", blank_player())

    # check if there are any seats taken
    # if there are none, then cancel any countdowns and go back to :WAIT_FOR_INITIAL_BET
    unless get("seat_1").player_id || get("seat_2").player_id || get("seat_3").player_id || get("seat_4").player_id || get("seat_5").player_id do
      if get("curr_task") do
        Process.exit(get("curr_task"), :brutal_kill)
        set("curr_task", nil)
      end

      set("phase", :WAIT_FOR_INITIAL_BET)
      set("countdown", 0)
      set("dealer", [])
    end

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  def set_name(seat_id, name) do
    seat = "seat_#{seat_id}"
    seat_data = get(seat)
      |> Map.put(:player_name, name)

    set(seat, seat_data)

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
  end

  def set_bet(seat_id, bet) do
    seat = "seat_#{seat_id}"
    seat_data = get(seat)
      |> Map.put(:current_bet, bet)
      |> Map.put(:money, get(seat).money - bet)

    set(seat, seat_data)

    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
    transition_to_finish_bets_phase()
  end

  defp get(slug) do
    case GenServer.call(__MODULE__, {:get, slug}) do
      [] -> nil
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
      money: nil,
      current_bet: 0
    }
  end

  defp init_player(player_id) do
    %{
      player_id: player_id,
      player_name: nil,
      hand: [],
      money: 1000,
      current_bet: 0
    }
  end

  defp transition_to_finish_bets_phase do
    cond do
      get("phase") == :WAIT_FOR_INITIAL_BET || get("phase") == :FINISH_BETS ->
        if get("curr_task") do
          Process.exit(get("curr_task"), :brutal_kill)
          set("curr_task", nil)
        end

        {:ok, task} = Task.start(fn -> start_countdown_for_bets() end)

        set("curr_task", task)
        set("phase", :FINISH_BETS)
      true -> nil
    end
  end

  defp start_countdown_for_bets do
    for inc <- Enum.to_list(3..1) do
      set("countdown", inc)
      Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
      :timer.sleep(1000)
    end

    set("countdown", 0)
    start_dealing()
  end

  defp start_dealing do
    cond do
      get("phase") == :WAIT_FOR_INITIAL_BET || get("phase") == :FINISH_BETS ->
        set("phase", :DEAL_INITIAL)

        for seat_id <- Enum.to_list(1..5) do
          deal(seat_id)
        end

        deal_dealer

        for seat_id <- Enum.to_list(1..5) do
          deal(seat_id)
        end

        deal_dealer()

        for seat_id <- Enum.to_list(1..5) do
          start_action_to(seat_id)
        end
      true -> nil
    end
  end

  defp deal(seat_id) do
    seat_key = "seat_#{seat_id}"
    %{player_id: player_id, current_bet: current_bet} = get(seat_key)

    if player_id && current_bet > 0 do
      set(seat_key, get(seat_key)
        |> Map.put(:hand, get(seat_key).hand ++ [ {Enum.random(@rank), Enum.random(@suit)} ])
      )
      Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
      :timer.sleep(500)
    end
  end

  defp deal_dealer do
    set("dealer", get("dealer") ++ [ {Enum.random(@rank), Enum.random(@suit)} ])
    Phoenix.PubSub.broadcast DragNDrop.InternalPubSub, "game", {:update_game_state}
    :timer.sleep(500)
  end

  defp start_action_to(seat_id) do

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

  def handle_cast({:transition_to_finish_bets_phase}, state) do
    Task.start(fn -> transition_to_finish_bets_phase() end)
    {:noreply, state}
  end

  def init(args) do
    [{:ets_table_name, ets_table_name}, {:log_limit, log_limit}] = args

    :ets.new(ets_table_name, [:named_table, :set])

    :ets.insert(ets_table_name, {"dealer", []})

    :ets.insert(ets_table_name, {"seat_1", blank_player()})
    :ets.insert(ets_table_name, {"seat_2", blank_player()})
    :ets.insert(ets_table_name, {"seat_3", blank_player()})
    :ets.insert(ets_table_name, {"seat_4", blank_player()})
    :ets.insert(ets_table_name, {"seat_5", blank_player()})

    :ets.insert(ets_table_name, {"phase", :WAIT_FOR_INITIAL_BET})
    :ets.insert(ets_table_name, {"countdown", 0})

    {:ok, %{log_limit: log_limit, ets_table_name: ets_table_name}}
  end
end
