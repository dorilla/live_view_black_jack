defmodule GameManager.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(GameManager.Manager, [[name: GameManager.Manager]])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
