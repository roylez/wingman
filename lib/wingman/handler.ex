require Logger

defmodule Wingman.Handler do
  use GenServer

  alias Wingman.Mattermost, as: MM
  alias Wingman.{ Cache, TelegramBot }

  defstruct [
    highlights: nil,
    channels: nil,
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
    channels = Application.get_env(:wingman, :channels)
    me = MM.me()
    Logger.info "USER ID: #{me}"
    Logger.info "MATTERMOST CHANNELS: #{inspect channels}"
    { :ok, %__MODULE__{
      webhook:    Application.get_env(:wingman, :webhook),
      highlights: ~r(#{Application.get_env(:wingman, :highlights)})iu,
      telegram:   Application.get_env(:wingman, :telegram),
      channels:   channels,
      me: me,
    } }
  end

  def handle(msg) do
    GenServer.cast(__MODULE__, msg)
  end

  def on, do: GenServer.cast(__MODULE__, :on)

  def off, do: GenServer.cast(__MODULE__, :off)
  
  # mattermost in
  def handle_cast(%MM.EventData{}=msg, %{ enabled: true }=state) do
    Logger.debug inspect(msg, pretty: true)
    with %{ sender_name: sender, post: %{ message: _ }=post, channel_type: type, channel_name: chan } <- msg
    do
      cond do
        # myself
        "@#{state.me}"==sender and Application.get_env(:wingman, :env) == :dev -> 
          _send_message(state, post, "ME: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # direct message
        type == "D" ->
          _send_message(state, post, " @#{sender}: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # highlights
        String.match?(post.message, state.highlights) ->
          _send_message(state, post, " ⚠️⚠*#{chan}* - #{sender}: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # permitted channel messages, deliver in silence
        chan in state.channels ->
          _send_message(state, post, " *#{chan}* - #{sender}: #{post.message}", false)
          {:noreply, %{ state| last_channel: post.channel_id }}
        true -> { :noreply, state }
      end
    else
      _ -> { :noreply, state }
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

  defp _send_message(%{ webhook: webhook, telegram: telegram }, origin, text, notify \\ true) do
    Logger.info "MATTERMOST -> #{text}"
    if telegram do
      _send_telegram(origin, text, notify)
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

  defp _send_telegram(origin, data, notify) do
    case notify do
      true -> TelegramBot.send(origin, data)
      false -> TelegramBot.send(origin, data, disable_notification: true)
    end
  end

end
