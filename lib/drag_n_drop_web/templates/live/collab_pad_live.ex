defmodule DragNDropWeb.CollabPadLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div>
      <br>

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
              <div>
                <%= if seat.current_bet > 0 do %>
                  <div><strong>Current Bet: <%= seat.current_bet %></strong></div>
                <% end %>
                <%= if seat.player_name do %>
                  <strong>
                    Name: <%= seat.player_name %>
                  </strong>
                <% else %>
                  <strong>
                    Player <%= idx + 1 %>
                  </strong>

                  <%= if seat.player_id == @current_player_id do %>
                    <form phx-submit="enter-name">
                      <input name="name" placeholder="Enter your name" value="<%= seat.player_name %>"/>
                      <input type="hidden" name="seat_id" value="<%= idx + 1 %>"/>
                    </form>
                  <% end %>
                <% end %>
              </div>

              <%= if seat.player_id == @current_player_id do %>
                <div>You</div>
              <% end %>
              <div class="player-id">
                <%= seat.player_id %>
              </div>
              <div>Money: <%= seat.money %></div>
              <div>
                <%= if seat.money > 0 && seat.current_bet == 0 do %>
                  <hr>
                  Make a bet:
                  <form phx-submit="enter-bet">
                    <input type="number" min=1 max=<%= seat.money %> name="bet" value=<%= seat.current_bet %>>
                    <input type="hidden" name="seat_id" value="<%= idx + 1 %>"/>
                  </form>
                <% end %>
              </div>
              <%= seat.hand %>
            <% else %>
              <%= if @is_seated do %>
                <button disabled>Sit Here</button>
              <% else %>
                <button phx-click="sit" phx-value=<%= idx + 1 %>>Sit Here</button>
              <% end %>
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
      is_seated: false,
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

    assign(socket, get_game_state(socket) |> Map.put(:is_seated, true))
  end

  defp enter_name(seat_id, name, socket) do
    GameManager.Manager.set_name(seat_id, name)

    assign(socket, get_game_state(socket) |> Map.put(:is_seated, true))
  end

  defp enter_bet(seat_id, bet, socket) do
    {bet_int, _} = Integer.parse(bet)

    GameManager.Manager.set_bet(seat_id, bet_int)

    assign(socket, get_game_state(socket))
  end

  defp get_game_state(socket) do
    socket.assigns
      |> Map.put(:game_state, GameManager.Manager.get_game_state)
  end
end
