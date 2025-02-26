defmodule Wingman.Telegram.Bot do
  use GenServer

  require Logger
  alias Wingman.Cache
  alias Wingman.Telegram, as: TG

  defstruct chat_id: nil, offset: nil

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(_) do
    :timer.send_interval(2000, :update)
    {_, chat_id} = Application.get_env(:wingman, :telegram)
    with {:ok, bot} <- TG.request(:get_me),
      {:ok, chat} <- TG.request(:get_chat, chat_id: chat_id)
    do
      Logger.info "Telegram Bot: #{bot.first_name} ( #{bot.username} )"
      Logger.info "Telegram Chat: #{chat.username} ( #{chat.id} )"
      { :ok, %__MODULE__{ chat_id: chat_id } }
    else
      {:error, reason} ->
        Logger.warning "Failed to start Telegram Bot: #{inspect reason}"
        {:stop, reason}
    end
  end

  def send(origin, text, opts \\ []) do
    GenServer.cast(__MODULE__, {:send, origin, text, opts})
  end
  def send(text) do
    GenServer.cast(__MODULE__, {:send, text})
  end

  def handle_info(:update, %{ offset: offset, chat_id: chat_id }=state) do
    with { :ok, updates } <- TG.request(:get_updates, limit: 5, offset: offset) do
      for u <- updates do
        with %{ message: %{ chat: %{ id: ^chat_id } }=m } <- u do
          Logger.debug inspect(u, pretty: true)
          Wingman.Telegram.Handler.handle(m)
        end
      end
      offset = case List.last(updates) do
        %{ update_id: update_id } -> update_id + 1
        _ -> offset
      end
      { :noreply, %{ state | offset: offset } }
    else
      _ -> {:noreply, state}
    end
  end

  def handle_cast({:send, text}, state) do
    TG.request(:send_message, chat_id: state.chat_id, text: text, parse_mode: "Markdown")
    {:noreply, state}
  end
  def handle_cast({:send, origin, text, opts}, state) do
    {:ok, %{ message_id: tg_msg_id }} =
      case TG.request(:send_message, [chat_id: state.chat_id, text: text, parse_mode: "Markdown"] ++ opts) do
        {:error, %{ reason: reason }} ->
          Logger.warning "Telegram send error: #{reason}"
          Logger.warning "Original message: #{text}"
        {:ok, res} -> {:ok, res}
      end
    Cache.put(tg_msg_id, origin)
    { :noreply, state }
  end

end
