defmodule Wingman.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Wingman.Mattermost.Websocket,
      Wingman.Mattermost,
      Wingman.Handler,
      Wingman.TelegramBot,
      Wingman.Cache,
      Wingman.Cron,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wingman]
    Supervisor.start_link(children, opts)
  end
end
