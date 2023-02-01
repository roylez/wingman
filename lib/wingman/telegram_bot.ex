defmodule Wingman.TelegramBot do
  use GenServer

  require Logger
  alias Nadia.Model.{ Chat }
  alias Wingman.Cache

  defstruct chat_id: nil, offset: nil
  
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
  
  def init(_) do
    :timer.send_interval(2000, :update)
    chat_id = Application.get_env(:wingman, :telegram_chat_id)
    {:ok, bot} = Nadia.get_me
    {:ok, chat} = Nadia.get_chat(chat_id)
    Logger.info "Telegram Bot: #{bot.first_name} ( #{bot.username} )"
    Logger.info "Telegram Chat: #{chat.username} ( #{chat.id} )"
    { :ok, %__MODULE__{ chat_id: chat_id } }
  end

  def send(origin, text) do
    GenServer.cast(__MODULE__, {:send, origin, text})
  end

  def handle_info(:update, %{ offset: offset, chat_id: chat_id }=state) do
    { :ok, updates } = Nadia.get_updates(limit: 5, offset: offset)
    for u <- updates do
      with %{ message: %{ chat: %Chat{ id: ^chat_id } }=m } <- u do
        Logger.debug inspect(u, pretty: true)
        Wingman.Handler.handle(m)
      end
    end
    offset = case List.last(updates) do
      %{ update_id: update_id } -> update_id + 1
      _ -> offset
    end
    { :noreply, %{ state | offset: offset } }
  end

  def handle_cast({:send, origin, text}, state) do
    {:ok, %{ message_id: tg_msg_id }} = 
      case Nadia.send_message(state.chat_id, text) do
        {:error, %{ reason: reason }} ->
          Logger.warn "Telegram send error: #{reason}"
          Logger.warn "Original message: #{text}"
          Nadia.send_message(state.chat_id, text)
        {:ok, res} -> {:ok, res}
      end
    Cache.set(tg_msg_id, origin)
    { :noreply, state }
  end

end
