defmodule Wingman.Telegram.Sup do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_) do

    children = [
      Wingman.Telegram.Bot,
      Wingman.Telegram.Handler,
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end
