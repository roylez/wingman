defmodule Wingman.Mattermost.EventData do
  @moduledoc """
  Mattermost websocket message format
  """
  @behaviour Access
  defdelegate get(v, key, default), to: Map
  defdelegate fetch(v, key), to: Map
  defdelegate get_and_update(v, key, func), to: Map
  def pop(v, key), do: {v[key], v}

  @derive Jason.Encoder

  defstruct [
    channel_display_name: nil,
    channel_name: nil,
    channel_type: nil,
    mentions: nil,
    post: nil,
    sender_name: nil,
    set_online: nil,
    team_id: nil,
  ]
end
