defmodule GameManager.Manager do
  use GenServer

  # Phases
  # WAIT_FOR_INITIAL_BET
  # FINISH_BETS -> happens after the first bet
  # DEAL_INITIAL -> no more bets
  # ACTION_SEAT_1 -> hit/stand action. check if blackjack or bust or 21
  # ACTION_SEAT_X -> ****
  # ACTION_DEALER -> ****
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

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
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

      if get("endgame_task") do
        Process.exit(get("endgame_task"), :brutal_kill)
        set("endgame_task", nil)
      end

      set("phase", :WAIT_FOR_INITIAL_BET)
      set("countdown", 0)
      set("dealer", [])
    end

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
  end

  def set_name(seat_id, name) do
    seat = "seat_#{seat_id}"
    seat_data = get(seat)
      |> Map.put(:player_name, name)

    set(seat, seat_data)

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
  end

  def set_bet(seat_id, bet) do
    seat = "seat_#{seat_id}"
    seat_data = get(seat)
      |> Map.put(:current_bet, bet)
      |> Map.put(:money, get(seat).current_bet + get(seat).money - bet)

    set(seat, seat_data)

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
    transition_to_finish_bets_phase()
  end

  def hit(seat_id) do
    GenServer.cast(__MODULE__, {:hit, seat_id})
  end

  def stand(seat_id) do
    GenServer.cast(__MODULE__, {:stand, seat_id})
  end

  def get_value_of_hand(hand) do
    Enum.reduce(hand, %{option_1: 0, option_2: 0}, fn card, acc ->
      %{option_1: acc1, option_2: acc2} = acc
      %{option_1: get_value_of_card(card) + acc1, option_2: get_value_of_card(card, true) + acc2}
    end)
  end

  def get_value_of_card({rank, _suit}, ace_2 \\ false) do
    case rank do
      :ACE -> if ace_2, do: 11, else: 1
      :TWO -> 2
      :THREE -> 3
      :FOUR -> 4
      :FIVE -> 5
      :SIX -> 6
      :SEVEN -> 7
      :EIGHT -> 8
      :NINE -> 9
      :TEN -> 10
      :JACK -> 10
      :QUEEN -> 10
      :KING -> 10
    end
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
        if !get("curr_task") do
          {:ok, task} = Task.start(fn ->
            start_countdown(8)
            start_dealing()
          end)

          set("curr_task", task)
        else
          set("phase", :FINISH_BETS)
        end
      true -> nil
    end
  end

  defp start_dealing do
    bets = Enum.reduce(Enum.to_list(1..5), 0, fn seat_id, acc ->
      acc + get("seat_#{seat_id}").current_bet
    end)

    cond do
      bets == 0 ->
        # no bets, go back to original
        set("phase", :WAIT_FOR_INITIAL_BET)
        set("countdown", 0)
        set("dealer", [])
        set("curr_task", nil)

        Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}

      get("phase") == :WAIT_FOR_INITIAL_BET || get("phase") == :FINISH_BETS ->
        set("phase", :DEAL_INITIAL)

        for seat_id <- Enum.to_list(1..5) do
          deal(seat_id)
        end

        deal_dealer()

        for seat_id <- Enum.to_list(1..5) do
          deal(seat_id)
        end

        deal_dealer()

        start_action_to(1)
      true -> nil
    end
  end

  defp start_action_to(seat_id) do
    seat_key = "seat_#{seat_id}"
    %{player_id: player_id, current_bet: current_bet} = get(seat_key)

    set("phase", String.to_atom("ACTION_SEAT_#{seat_id}"))
    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}

    if player_id && current_bet > 0 do
      {:ok, task} = Task.start(fn ->
        start_countdown(5)
        stand(seat_id)
      end)

      set("curr_task", task)
    else
      start_next_action()
    end

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
  end

  defp start_dealer_action do
    set("phase", :ACTION_DEALER)
    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
    :timer.sleep(1000)

    dealer_hit_or_stand()
  end

  defp start_pay_out do
    set("phase", :PAY_OUT)

    for seat_id <- Enum.to_list(1..5) do
      pay_seat(seat_id)
    end

    if get("curr_task") do
      Process.exit(get("curr_task"), :brutal_kill)
      set("curr_task", nil)
    end

    {:ok, task} = Task.start(fn ->
      start_countdown(8)
      restart_game()
    end)

    set("endgame_task", task)
  end

  defp pay_seat(seat_id) do
    seat_key = "seat_#{seat_id}"
    %{player_id: player_id, current_bet: current_bet, hand: hand, money: money} = get(seat_key)

    if player_id && current_bet > 0 do
      dealer_value = hand_best_value(get("dealer"))
      seat_value = hand_best_value(hand)

      cond do
        did_bust(seat_id) ->
          set(seat_key, get(seat_key)
            |> Map.put(:current_bet, 0)
          )
        dealer_value <= 21 && dealer_value > seat_value ->
          set(seat_key, get(seat_key)
            |> Map.put(:current_bet, 0)
          )
        dealer_value <= 21 && dealer_value == seat_value ->
          nil
        true ->
          set(seat_key, get(seat_key)
            |> Map.put(:money, money + current_bet)
          )
      end
    end

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
  end

  defp restart_game do
    set("phase", :WAIT_FOR_INITIAL_BET)
    set("countdown", 0)
    set("dealer", [])

    # clear all hands
    for seat_id <- Enum.to_list(1..5) do
      seat_key = "seat_#{seat_id}"

      set(seat_key, get(seat_key)
        |> Map.put(:hand, [])
      )

      # player has no more money, they gotta go!
      if get(seat_key).money == 0 && get(seat_key).current_bet == 0 do
        set(seat_key, blank_player)
      end
    end

    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}

    bets = Enum.reduce(Enum.to_list(1..5), 0, fn seat_id, acc ->
      if get("seat_#{seat_id}").current_bet > 0 do
        set_bet(seat_id, get("seat_#{seat_id}").current_bet)
      end

      acc + get("seat_#{seat_id}").current_bet
    end)

    # if there are any bets, start the game with collecting any other bets
    if bets > 0, do: transition_to_finish_bets_phase()
  end

  defp start_next_action do
    case get("phase") do
      :ACTION_SEAT_1 -> start_action_to(2)
      :ACTION_SEAT_2 -> start_action_to(3)
      :ACTION_SEAT_3 -> start_action_to(4)
      :ACTION_SEAT_4 -> start_action_to(5)
      :ACTION_SEAT_5 -> start_dealer_action()
    end
  end

  # countdowns

  defp start_countdown(start_time) do
    for inc <- Enum.to_list(start_time..1) do
      set("countdown", inc)
      Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
      :timer.sleep(1000)
    end

    set("countdown", 0)
    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
  end

  # Hand Utilities

  defp deal(seat_id) do
    seat_key = "seat_#{seat_id}"
    %{player_id: player_id, current_bet: current_bet} = get(seat_key)

    if player_id && current_bet > 0 do
      set(seat_key, get(seat_key)
        |> Map.put(:hand, get(seat_key).hand ++ [ {Enum.random(@rank), Enum.random(@suit)} ])
      )

      Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
      :timer.sleep(500)
    end
  end

  defp deal_dealer(timeout \\ 500) do
    set("dealer", get("dealer") ++ [ {Enum.random(@rank), Enum.random(@suit)} ])
    Phoenix.PubSub.broadcast BlackJack.InternalPubSub, "game", {:update_game_state}
    :timer.sleep(timeout)
  end

  defp did_bust(seat_id) do
    %{option_1: option_1, option_2: _option_2} = get("seat_#{seat_id}").hand
     |> get_value_of_hand()

    if option_1 > 21, do: true, else: false
  end

  defp hand_best_value(hand) do
    %{option_1: option_1, option_2: option_2} = get_value_of_hand(hand)

    cond do
      option_1 == option_2 ->
        option_1
      option_1 <= 21 && option_2 <= 21 ->
        max(option_1, option_2)
      option_1 <= 21 ->
        option_1
      option_2 <= 21 ->
        option_2
      true ->
        min(option_1, option_2)
    end
  end

  defp should_dealer_keep_hitting() do
    hand_best_value(get("dealer")) < 17
  end

  defp dealer_hit_or_stand do
    case should_dealer_keep_hitting() do
      true ->
        deal_dealer(1000)
        dealer_hit_or_stand()
      false -> start_pay_out()
    end
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

  def handle_cast({:hit, seat_id}, state) do
    Task.start(fn ->
      if get("curr_task") do
        Process.exit(get("curr_task"), :brutal_kill)
        set("curr_task", nil)
      end

      deal(seat_id)

      if did_bust(seat_id) do
        start_next_action
      else
        start_action_to(seat_id)
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:stand, seat_id}, state) do
    Task.start(fn ->
      if get("curr_task") do
        Process.exit(get("curr_task"), :brutal_kill)
        set("curr_task", nil)
        set("countdown", 0)
      end

      start_next_action
    end)

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
