defmodule Wingman.Mattermost.Event do
  @moduledoc """
  Mattermost websocket event
  """
  defstruct seq: 0, event: nil, data: nil, broadcast: nil
end

