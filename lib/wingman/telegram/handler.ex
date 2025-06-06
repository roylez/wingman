require Logger

defmodule Wingman.Telegram.Handler do
  use GenServer

  alias Wingman.Mattermost, as: MM
  alias Wingman.Telegram, as: TG
  alias Wingman.{ Cache, Telegram.Bot }

  @bot_commands [
    on: "Enable Forwarding",
    off: "Disable Forwarding"
  ]

  defstruct [
    highlights:       nil,
    channels:         nil,
    ignored_channels: nil,
    webhook:          nil,
    telegram:         nil,
    last_channel:     nil,
    enabled:          false,
    me:               nil,
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    channels         = Application.get_env(:wingman, :channels)
    ignored_channels = Application.get_env(:wingman, :ignored_channels)
    me = MM.me()
    Logger.info "USER ID: #{me}"
    Logger.info "MATTERMOST CHANNELS: #{inspect channels}"
    Logger.info "MATTERMOST IGNORED CHANNELS: #{inspect ignored_channels}"
    { :ok, %__MODULE__{
      webhook:    Application.get_env(:wingman, :webhook),
      highlights: ~r(#{Application.get_env(:wingman, :highlights)})iu,
      telegram:   Application.get_env(:wingman, :telegram),
      channels:   channels,
      ignored_channels: ignored_channels,
      me: me,
    }, { :continue, :set_commands } }
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
        # myself in dev
        "@#{state.me}"==sender and Application.get_env(:wingman, :env) == :dev ->
          _send_message(state, post, "ME: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # myself in non-dev
        "@#{state.me}"==sender ->
          {:noreply, state}
        # direct message
        type == "D" ->
          _send_message(state, post, "🗣 #{sender}: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # ignored_channels
        chan in state.ignored_channels -> {:noreply, state }
        # highlights
        String.match?(post.message, state.highlights) ->
          _send_message(state, post, "💬 *#{chan}* - #{sender}: #{post.message}")
          {:noreply, %{ state| last_channel: post.channel_id }}
        # permitted channel messages, deliver in silence
        chan in state.channels ->
          _send_message(state, post, "💬 *#{chan}* - #{sender}: #{post.message}", false)
          {:noreply, %{ state| last_channel: post.channel_id }}
        true -> { :noreply, state }
      end
    else
      _ -> { :noreply, state }
    end
  end
  # telegram in
  def handle_cast(%{ text: "/on" }, %{ enabled: false }=state) do
    Bot.send("🙉 Message forwarding from Mattermost is set to **ON**!")
    { :noreply, %{ state| enabled: true } }
  end
  def handle_cast(%{ text: "/off" }, %{ enabled: true }=state) do
    Bot.send("🙈 Message forwarding from Mattermost is set to **OFF**!")
    { :noreply, %{ state| enabled: false } }
  end
  def handle_cast(%{ text: "/" <> _ }, state), do: { :noreply, state }
  def handle_cast(:on, state) do
    Bot.send("🕘 Message forwarding from Mattermost is set to **ON**!")
    { :noreply, %{ state| enabled: true } }
  end
  def handle_cast(:off, state) do
    Bot.send("🕕 Message forwarding from Mattermost is set to **OFF**!")
    { :noreply, %{ state| enabled: false } }
  end
  def handle_cast(%{ text: _text }, %{ enabled: false }=state) do
    {:noreply, state}
  end
  def handle_cast(%{ text: text }=msg, %{ enabled: true }=state) do
    {:ok, origin} = get_in(msg, [:reply_to_message, :message_id]) |> Cache.get()
    channel_id = Map.get(origin || %{}, :channel_id) || state.last_channel
    reply_to = Map.get(origin || %{}, :id)
    case MM.post_create(
      %{ channel_id: channel_id, reply_to: reply_to, message: text }
    ) do
      {:ok, _, _msg} ->
        Logger.info "<- TELEGRAM #{channel_id}: #{text}"
      {:error, _, msg} ->
        Logger.warning "<x TELEGRAM #{channel_id}: #{text}"
        Logger.warning inspect(msg)
    end
    {:noreply, state}
  end
  def handle_cast(stuff, state) do
    Logger.debug inspect(stuff)
    {:noreply, state}
  end

  def handle_continue(:set_commands, state) do
    @bot_commands
    |> Enum.map(fn {k, v} -> %{ command: k, description: v } end)
    |> then(&(TG.request(:set_my_commands, commands: &1)))
    {:noreply, state}
  end

  defp _send_message(%{ webhook: webhook, telegram: telegram }, origin, text, notify \\ true) do
    Logger.info "MATTERMOST -> #{text}"
    if telegram do
      text = String.replace(text, "**", "*")
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
        Logger.warning "x> WEBHOOK : response #{status}"
        Logger.warning inspect(resp)
    end
  end

  defp _send_telegram(origin, data, notify) do
    case notify do
      true  -> Bot.send(origin, data)
      false -> Bot.send(origin, data, disable_notification: true)
    end
  end

end
