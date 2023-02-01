require Logger

defmodule Wingman.Handler do
  use GenServer

  alias Wingman.Mattermost, as: MM
  alias Wingman.{ Cache, TelegramBot }

  defstruct [
    highlights: nil,
    webhook: nil,
    telegram: nil,
    last_channel: nil,
    enabled: true,
    me: nil,
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def init(_) do
    webhook = Application.get_env(:wingman, :webhook)
    telegram = Application.get_env(:wingman, :telegram)
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

  def on, do: GenServer.cast(__MODULE__, :on)

  def off, do: GenServer.cast(__MODULE__, :off)
  
  # mattermost in
  def handle_cast(%MM.EventData{}=msg, %{ me: me, enabled: true }=state) do
    Logger.debug inspect(msg, pretty: true)
    case msg do
      %{ 
        sender_name: "@" <> ^me,
        post: %{ message: _text }=post
      } ->  # direct message from myself
        if Application.get_env(:wingman, :env) == :dev do
          _send_message(state, post, "ME: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        else
          {:noreply, state}
        end
      %{
        channel_type: "D",
        sender_name: name,
        post: %{ message: _text }=post
      } ->   # direct message
        _send_message(state, post, "#{name}: #{post.message}")
        {:noreply, %{ state| last_channel: post.channel_id }}
      %{
        channel_name: chan_name,
        sender_name: name,
        post: %{ message: text }=post
      } ->   # channel message
        if String.match?(text, state.highlights) do
          _send_message(state, post, "[#{chan_name}] #{name}: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        else
          {:noreply, state}
        end
      _ -> {:noreply, state}
    end
  end
  # telegram in
  def handle_cast(%{ text: "/on" }, state) do
    TelegramBot.send("🙉 Message forwarding from Mattermost is set to **ON**!")
    { :noreply, %{ state| enabled: true } }
  end
  def handle_cast(%{ text: "/off" }, state) do
    TelegramBot.send("🙈 Message forwarding from Mattermost is set to **OFF**!")
    { :noreply, %{ state| enabled: false } }
  end
  def handle_cast(:on, state) do
    TelegramBot.send("🕘 Message forwarding from Mattermost is set to **ON**!")
    { :noreply, %{ state| enabled: true } }
  end
  def handle_cast(:off, state) do
    TelegramBot.send("🕕 Message forwarding from Mattermost is set to **OFF**!")
    { :noreply, %{ state| enabled: false } }
  end
  def handle_cast(%{ text: _text }, %{ enable: false }=state) do
    {:noreply, state}
  end
  def handle_cast(%{ text: text }=msg, %{ enable: true }=state) do
    {:ok, origin} = get_in(msg, [:reply_to_message, :message_id]) |> Cache.get()
    channel_id = Map.get(origin || %{}, :channel_id) || state.last_channel
    reply_to = Map.get(origin || %{}, :id)
    case MM.post_create(
      %{ channel_id: channel_id, reply_to: reply_to, message: text }
    ) do
      {:ok, _, _msg} ->
        Logger.info "<- TELEGRAM #{channel_id}: #{text}"
      {:error, _, msg} ->
        Logger.warn "<x TELEGRAM #{channel_id}: #{text}"
        Logger.warn inspect(msg)
    end
    {:noreply, state}
  end
  def handle_cast(stuff, state) do
    Logger.debug inspect(stuff)
    {:noreply, state}
  end

  defp _send_message(%{ webhook: webhook, telegram: telegram }, origin, text) do
    Logger.info "MATTERMOST -> #{text}"
    if telegram do
      _send_telegram(origin, text)
    end
    if webhook do
      _send_webhook(webhook, text)
    end
  end

  defp _send_webhook(hook, data) do
    header = [{"Content-Type", "text/plain"}]
    task = Task.async( fn -> :hackney.post(hook, header, data) end)
    case Task.await(task) do
      {:ok, 200, _, _} ->
        Logger.info "-> WEBHOOK : response 200"
      {_, status, _, _}=resp ->
        Logger.warn "x> WEBHOOK : response #{status}"
        Logger.warn inspect(resp)
    end
  end

  defp _send_telegram(origin, data) do
    TelegramBot.send(origin, data)
  end

end
