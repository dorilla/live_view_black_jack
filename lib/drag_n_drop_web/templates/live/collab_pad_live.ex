defmodule DragNDropWeb.CollabPadLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div>
      <div>
        <%= @game_state.countdown %>
      </div>
      <div>
        <strong>Dealer</strong>

        <%= for card <- @game_state.dealer do %>
          <div class="card">
            <%= card %>
          </div>
        <% end %>
      </div>

      <br>

      <div class="player-seats">
        <%= for {seat, idx} <- Enum.with_index([@game_state.seat_1, @game_state.seat_2, @game_state.seat_3, @game_state.seat_4, @game_state.seat_5]) do %>
          <div class="player-seat <%= if seat.player_id, do: "player-seat--seated" %>">
            <%= if seat.player_id do %>
              <div class="bet-circle">
                <div class="poker-chip <%= if seat.current_bet > 0, do: "poker-chip--slide-in" %>">
                  <%= if seat.current_bet > 0 do %>
                    <div class="poker-chip__value"><%= seat.current_bet %></div>
                  <% end %>
                </div>
              </div>
              <div class="player-detail">
                <%= if seat.player_name && String.length(seat.player_name) > 0 do %>
                  <strong class="player-name <%= if seat.player_id == @current_player_id, do: "player-name--you" %>">
                    <%= seat.player_name %>
                  </strong>
                <% else %>
                  <strong class="player-name <%= if seat.player_id == @current_player_id, do: "player-name--you" %>">
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
                <div class="sit-here"><button phx-click="sit" phx-value=<%= idx + 1 %>>Sit Here</button></div>
              <% end %>

            <% end %>
          </div>
        <% end %>
      </div>

      <div class="player-actions">
        <%= if @is_seated do %>
          <h1>Player Actions</h1>
          <div>
            <form phx-submit="enter-name">
              <input name="name" maxlength="10" placeholder="Enter your name" value="<%= @current_player_name %>"/>
              <input type="hidden" name="seat_id" value="<%= @current_seat_id %>"/>
            </form>
          </div>

          <div>
            <%= if @current_seat && @current_seat.money > 0 && @current_seat.current_bet == 0 do %>
              <hr>
              Make a bet:
              <form phx-submit="enter-bet">
                <input type="number" min=1 max=<%= @current_seat.money %> name="bet" value=<%= @current_seat.current_bet %>>
                <input type="hidden" name="seat_id" value="<%= @current_seat_id %>"/>
              </form>
            <% end %>
          </div>
        <% end %>
      </div>
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
