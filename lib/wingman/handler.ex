require Logger

defmodule Wingman.Handler do
  use GenServer

  alias Wingman.Mattermost, as: MM
  alias Nadia.Model, as: TG

  defstruct [
    highlights: nil,
    webhook: nil,
    telegram: nil,
    last_channel: nil,
    me: nil,
  ]
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def init(_) do
    webhook = Application.get_env(:wingman, :webhook)
    telegram = Application.get_env(:wingman, :telegram_chat_id) && Application.get_env(:nadia, :token)
    highlights = ~r(#{Application.get_env(:wingman, :highlights)})iu
    me = MM.me()
    Logger.info "USER ID: #{me}"
    { :ok, %__MODULE__{
      webhook: webhook,
      highlights: highlights,
      telegram: telegram,
      me: me,
    } }
  end

  def handle(msg) do
    GenServer.cast(__MODULE__, msg)
  end
  
  # mattermost in
  def handle_cast(%MM.EventData{}=msg, %{ me: me }=state) do
    Logger.debug inspect(msg, pretty: true)
    case msg do
      %{ sender_name: "@" <> ^me, post: %{ message: text, chann_id: chan } } ->
        if Application.get_env(:wingman, :env) == :dev do
          _send_message(state, "ME: #{text}")
          {:noreply, %{ state| last_channel: chan }}
        else
          {:noreply, state}
        end
      %{ channel_type: "D", sender_name: name, post: %{ message: text, channel_id: chan } } ->
        _send_message(state, "#{name}: #{text}")
        {:noreply, %{ state| last_channel: chan }}
      %{ channel_name: chan_name, sender_name: name, post: %{ message: text, channel_id: chan } } ->
        if String.match?(text, state.highlights) do
          _send_message(state, "[#{chan_name}] #{name}: #{text}")
          {:noreply, %{ state| last_channel: chan }}
        else
          {:noreply, state}
        end
      _ -> {:noreply, state}
    end
  end
  # telegram in
  def handle_cast(%TG.Message{ text: text }, state) do
    Logger.info "TELEGRAM -> #{state.last_channel}: #{text}"
    MM.post_create(%{ channel: state.last_channel, message: text })
    {:noreply, state}
  end
  def handle_cast(_, state), do: {:noreply, state}

  defp _send_message(%{ webhook: webhook, telegram: telegram }, data) do
    Logger.info "MATTERMOST: #{data}"
    if telegram do
      _send_telegram(data)
    end
    if webhook do
      _send_webhook(webhook, data)
    end
  end

  defp _send_webhook(hook, data) do
    header = [{"Content-Type", "text/plain"}]
    task = Task.async( fn -> :hackney.post(hook, header, data) end)
    case Task.await(task) do
      {:ok, 200, _, _} ->
        Logger.info "WEBHOOK sent: response 200"
      {_, status, _, _}=resp ->
        Logger.warn "WEBHOOK failed: response #{status}"
        Logger.warn inspect(resp)
    end
  end

  defp _send_telegram(data) do
    Wingman.TelegramBot.send(data)
  end

end
