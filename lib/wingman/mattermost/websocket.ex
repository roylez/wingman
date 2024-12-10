require Logger

defmodule Wingman.Mattermost.Websocket do
  use WebSockex

  @ping_timeout 30_000

  defstruct [ seq: 0, connected: false, pong_received: false ]

  def start_link(_) do
    endpoint = Application.get_env(:wingman, :mattermost)[:api_url]
    header = [ {"authorization", "Bearer #{Application.get_env(:wingman, :mattermost)[:token]}" } ]
    WebSockex.start_link(
      endpoint <> "/websocket",
      __MODULE__,
      %__MODULE__{},
      name: __MODULE__,
      extra_headers: header,
      async: true,
      handle_initial_conn_failure: true
    )
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg, keys: :atoms) do
      {:ok, %{ event: _ }=event } ->
        event
        |> _parse_event()
        |> handle_event(state)
      { :ok, %{ seq_reply: _ } } -> { :ok, state }
      { :ok, msg } ->
        Logger.warning "MESSAGE: #{inspect msg}"
        { :ok, state }
      {:error, _     } -> throw("Unable to decode message: #{msg}")
    end
  end

  def handle_pong(_, %{ connected: false }=state), do: {:ok, state}
  def handle_pong(_, %{ connected: true }=state),  do: {:ok, %{ state| pong_received: true }}

  def handle_connect(_conn, _state) do
    Process.send_after(self(), :ping_timeout, @ping_timeout)
    { :ok, %__MODULE__{ pong_received: true, connected: true } }
  end

  # this happens too often to be useful
  def handle_disconnect(%{ reason: {:remote, :closed} }, _state), do: {:reconnect, %__MODULE__{}}
  def handle_disconnect(%{ reason: reason }, _state) do
    Logger.warning "Mattermost websocket disconnected, reason: #{inspect reason}"
    { :reconnect, %__MODULE__{} }
  end

  def handle_info(:ping_timeout, state) do
    case state do
      %{ pong_received: true } ->
        Process.send_after(self(), :ping_timeout, @ping_timeout)
        {:reply, {:ping, ""}, %{ state| pong_received: false }}
      %{ pong_received: false } ->
        {:close, state}
    end
  end

  def handle_event(%{ event: "hello", seq: seq }, state) do
    reply = Jason.encode!(%{ seq: seq+1 , action: "get_statuses"})
    { :reply, {:text, reply}, %{ state | seq: seq+1 } }
  end

  def handle_event(%{ event: "posted", seq: seq }=event, state) do
    Wingman.Telegram.Handler.handle(event.data)
    { :ok, %{ state |seq: seq } }
  end

  def handle_event(%{ event: e, seq: seq }, state)
  when e in ~w(
    channel_updated
    channel_viewed
    direct_added
    draft_created
    emoji_added
    leave_team
    license_changed
    multiple_channels_viewed
    new_user
    post_deleted
    post_edited
    preferences_changed
    reaction_added
    reaction_removed
    sidebar_category_updated
    status_change
    typing
    user_added
    user_removed
    user_updated
  )
  do
    { :ok, %{ state | seq: seq } }
  end

  def handle_event(%{ event: _e, seq: seq }, state) do
    { :ok, %{ state | seq: seq } }
  end

  def handle_cast(frame, state) do
    { :reply, frame, state }
  end

  def terminate(reason, _state) do
    Logger.critical("Socket Terminating: #{inspect reason}")
    exit(:normal)
  end

  defp _parse_event(event) do
    e =event
       |> update_in(~w(data mentions)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data post)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data)a, &(struct(Wingman.Mattermost.EventData, &1)))
    struct(Wingman.Mattermost.Event, e)
  end

end
