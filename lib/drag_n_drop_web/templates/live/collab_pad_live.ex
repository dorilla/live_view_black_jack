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
          <div class="player-seat">
            <%= if seat.player_id do %>
              <div>
                <strong>
                  Player <%= idx + 1 %>
                </strong>
              </div>
              <%= if seat.player_id == @current_player_id do %>
                <div>You</div>
              <% end %>
              <div class="player-id">
                <%= seat.player_id %>
              </div>
              <div>Money: <%= seat.money %></div>
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

  def handle_info({:update_game_state}, socket) do
    {:noreply, assign(socket, get_game_state(socket))}
  end

  defp player_sit(seat_id, socket) do
    unless socket.assigns.is_seated, do: GameManager.Manager.occupy_seat(seat_id, socket.id)

    assign(socket, get_game_state(socket) |> Map.put(:is_seated, true))
  end

  defp get_game_state(socket) do
    socket.assigns
      |> Map.put(:game_state, GameManager.Manager.get_game_state)
  end
end
