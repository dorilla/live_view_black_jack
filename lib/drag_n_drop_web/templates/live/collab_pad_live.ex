defmodule DragNDropWeb.CollabPadLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div>
      <div class="dealer">
        <div class="dealer-header">DEALER</div>

        <div class="dealer-quote">
          <%= phase_to_string(@game_state.phase) %>
          <%= if @game_state.countdown > 0, do: @game_state.countdown %>
        </div>

        <div class="cards cards--dealer">
          <%= if length(@game_state.dealer) do %>
            <%= for {{rank, suit}, idx} <- Enum.with_index(@game_state.dealer) do %>
              <%= if idx == 0 && @game_state.phase != :DEAL_DEALER do %>
                <div class="card card--idx-<%= idx + 1 %> card--hidden"></div>
              <% else %>
                <div class="card card--idx-<%= idx + 1 %> card--rank-<%= String.downcase(Atom.to_string(rank)) %> card--suit-<%= String.downcase(Atom.to_string(suit)) %>">
                  <div><%= rank_to_string(rank) %><br><%= suit_to_string(suit) %></div>
                  <div class="card-desc"><%= rank_to_string(rank) %><br><%= suit_to_string(suit) %></div>
                </div>
              <% end %>
            <% end %>
          <% end %>
        </div>
      </div>

      <br>

      <div class="player-seats">
        <%= for {seat, idx} <- Enum.with_index([@game_state.seat_1, @game_state.seat_2, @game_state.seat_3, @game_state.seat_4, @game_state.seat_5]) do %>
          <div class="player-seat <%= if seat.player_id, do: "player-seat--seated" %>">

            <div class="cards">
              <%= if length(seat.hand) do %>
                <%= for {{rank, suit}, idx} <- Enum.with_index(seat.hand) do %>
                  <div class="card card--idx-<%= idx + 1 %> card--rank-<%= String.downcase(Atom.to_string(rank)) %> card--suit-<%= String.downcase(Atom.to_string(suit)) %>">
                    <div><%= rank_to_string(rank) %><br><%= suit_to_string(suit) %></div>
                    <div class="card-desc"><%= rank_to_string(rank) %><br><%= suit_to_string(suit) %></div>
                  </div>
                <% end %>
              <% end %>
            </div>

            <%# this should be moved to its own template %>
            <div class="hand-value <%= if get_value_of_hand(seat.hand).option_1 > 0, do: "hand-value--visible" %>">
              <span>Card value:</span>
              <%= get_value_of_hand(seat.hand).option_1 %>
              <%= if get_value_of_hand(seat.hand).option_1 != get_value_of_hand(seat.hand).option_2 &&
                  get_value_of_hand(seat.hand).option_2 <= 21 do %>
                or <%= get_value_of_hand(seat.hand).option_2 %>
              <% end %>
            </div>

            <%= if seat.player_id do %>
              <div class="bet-circle">
                <div class="poker-chip <%= if seat.current_bet > 0, do: "poker-chip--slide-in" %>">
                  <%= if seat.current_bet > 0 do %>
                    <div class="poker-chip__value"><%= seat.current_bet %></div>
                  <% end %>
                </div>
              </div>
              <div class="player-detail">
                <%= if seat.player_id == @current_player_id do %>
                  <strong class="you-indicator">YOU</strong>
                <% end %>
                <%= if seat.player_name && String.length(seat.player_name) > 0 do %>
                  <strong class="player-name">
                    <%= seat.player_name %>
                  </strong>
                <% else %>
                  <strong class="player-name">
                    Player <%= idx + 1 %>
                  </strong>
                <% end %>

                <div class="player-id">
                  <%#= seat.player_id %>
                </div>

                <div class="player-money">$<%= seat.money %></div>
              </div>
            <% else %>

              <div class="bet-circle"></div>
              <%= unless @is_seated do %>
                <div class="sit-here"><button phx-click="sit" phx-value=<%= idx + 1 %>>SIT HERE</button></div>
              <% end %>

            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @is_seated do %>
        <div class="player-actions">
          <div>
            <p>Enter Your Name:</p>
            <form phx-submit="enter-name">
              <input name="name" maxlength="10" value="<%= @current_player_name %>"/>
              <input type="hidden" name="seat_id" value="<%= @current_seat_id %>"/>
            </form>
          </div>

          <div>
            <%= if @current_seat && @current_seat.money > 0 &&
                @current_seat.current_bet == 0 &&
                (@game_state.phase == :WAIT_FOR_INITIAL_BET || @game_state.phase == :FINISH_BETS) do %>
              <br>
              <p>Make a bet:</p>
              <form phx-submit="enter-bet">
                <input type="number" min=1 max=<%= @current_seat.money %> name="bet" value=<%= @current_seat.current_bet %>>
                <input type="hidden" name="seat_id" value="<%= @current_seat_id %>"/>
              </form>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe DragNDrop.InternalPubSub, "game"

    assigned_data = %{
      current_player_id: socket.id,
      current_player_name: nil,
      is_seated: false,
      current_seat_id: nil,
      current_seat: nil,
      game_state: GameManager.Manager.get_game_state
    }

    {:ok, assign(socket, assigned_data)}
  end

  def terminate(_reason, socket) do
    GameManager.Manager.leave_seat(socket.id)
  end

  def handle_event("sit", seat_id, socket) do
    {:noreply, player_sit(seat_id, socket)}
  end

  def handle_event("enter-name",  %{"name" => name, "seat_id" => seat_id}, socket) do
    {:noreply, enter_name(seat_id, name, socket)}
  end

  def handle_event("enter-bet",  %{"bet" => bet, "seat_id" => seat_id}, socket) do
    {:noreply, enter_bet(seat_id, bet, socket)}
  end

  # Consume message from pubsub
  def handle_info({:update_game_state}, socket) do
    {:noreply, assign(socket, get_game_state(socket))}
  end

  defp rank_to_string(rank) do
    case rank do
      :ACE -> "A"
      :TWO -> "2"
      :THREE -> "3"
      :FOUR -> "4"
      :FIVE -> "5"
      :SIX -> "6"
      :SEVEN -> "7"
      :EIGHT -> "8"
      :NINE -> "9"
      :TEN -> "10"
      :JACK -> "J"
      :QUEEN -> "Q"
      :KING -> "K"
    end
  end

  defp suit_to_string(suit) do
    case suit do
      :HEART -> "❤"
      :DIAMOND -> "◆"
      :SPADE -> "♠"
      :CLUB -> "♣"
    end
  end

  defp get_value_of_hand(hand) do
    Enum.reduce(hand, %{option_1: 0, option_2: 0}, fn card, acc ->
      %{option_1: acc1, option_2: acc2} = acc
      %{option_1: get_value_of_card(card) + acc1, option_2: get_value_of_card(card, true) + acc2}
    end)
  end

  defp get_value_of_card({rank, _suit}, ace_2 \\ false) do
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

  defp phase_to_string(phase) do
    case phase do
      :WAIT_FOR_INITIAL_BET -> "Place your bets"
      :FINISH_BETS -> "Final bets"
      :DEAL_INITIAL -> "Dealing cards"
    end
  end

  defp player_sit(seat_id, socket) do
    unless socket.assigns.is_seated, do: GameManager.Manager.occupy_seat(seat_id, socket.id)

    data = get_game_state(socket)
      |> Map.put(:is_seated, true)
      |> Map.put(:current_seat_id, seat_id)

    assign(socket, data
      |> Map.put(:current_seat, Map.get(data.game_state, String.to_atom("seat_#{seat_id}")))
    )
  end

  defp enter_name(seat_id, name, socket) do
    GameManager.Manager.set_name(seat_id, name)

    assign(socket, get_game_state(socket)
      |> Map.put(:current_player_name, name)
    )
  end

  defp enter_bet(seat_id, bet, socket) do
    {bet_int, _} = Integer.parse(bet)

    GameManager.Manager.set_bet(seat_id, bet_int)

    assign(socket, get_game_state(socket))
  end

  defp get_game_state(socket) do
    game_state = GameManager.Manager.get_game_state

    if socket.assigns.is_seated do
      socket.assigns
        |> Map.put(:game_state, game_state)
        |> Map.put(:current_seat, Map.get(game_state, String.to_atom("seat_#{socket.assigns.current_seat_id}")))
    else
      socket.assigns
        |> Map.put(:game_state, game_state)
    end
  end
end
