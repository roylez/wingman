require Logger

defmodule Wingman.Mattermost.Websocket do
  use WebSockex

  def start_link(_) do
    endpoint = Application.get_env(:wingman, :mattermost)[:api_url]
    header = [ {"authorization", "Bearer #{Application.get_env(:wingman, :mattermost)[:token]}" } ]
    WebSockex.start_link(
      endpoint <> "/websocket",
      __MODULE__,
      0,
      name: __MODULE__,
      extra_headers: header
    )
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg, keys: :atoms) do
      {:ok, %{ event: _ }=event } ->
        event
        |> parse_event()
        |> handle_event(state)
      { :ok, %{ seq_reply: _ } } -> { :ok, state }
      { :ok, msg } ->
        Logger.warn "MESSAGE: #{inspect msg}"
        { :ok, state }
      {:error, _     } -> throw("Unable to decode message: #{msg}")
    end
  end

  def handle_disconnect(status, state) do
    Logger.warn "Disconnected, status: #{inspect status}"
    { :reconnect, state }
  end

  def handle_event(%{ event: "hello", seq: seq }, _state) do
    reply = Jason.encode!(%{ seq: seq+1 , action: "get_statuses"})
    { :reply, {:text, reply}, seq+1 }
  end

  def handle_event(%{ event: "posted", seq: seq }=event, _state) do
    Wingman.Handler.handle(event.data)
    { :ok, seq }
  end

  def handle_event(%{ event: e, seq: seq }, _state)
  when e in ~w(
    typing
    user_updated
    user_added
    user_removed
    post_edited
    post_deleted
    emoji_added
    status_change
    license_changed
    reaction_added
    reaction_removed
    channel_viewed
    preferences_changed
    sidebar_category_updated
  )
  do
    { :ok, seq }
  end

  def handle_event(event, _state) do
    Logger.warn("Event received: #{inspect event}")
    { :ok, event.seq }
  end

  def handle_cast(frame, state) do
    { :reply, frame, state }
  end

  def terminate(reason, _state) do
    Logger.critical("Socket Terminating: #{inspect reason}")
    exit(:normal)
  end

  defp parse_event(event) do
    e =event
       |> update_in(~w(data mentions)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data post)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data)a, &(struct(Wingman.Mattermost.EventData, &1)))
    struct(Wingman.Mattermost.Event, e)
  end

end
