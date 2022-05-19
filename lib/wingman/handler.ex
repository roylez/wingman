require Logger

defmodule Wingman.Handler do
  use GenServer

  alias Wingman.Mattermost, as: MM

  defstruct [
    highlights: nil,
    webhook: nil,
    me: nil,
  ]
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end
  
  def init(_) do
    webhook = Application.get_env(:wingman, :webhook)
    highlights = ~r(#{Application.get_env(:wingman, :highlights)})iu
    { :ok, %__MODULE__{
      webhook: webhook,
      highlights: highlights,
      me: MM.me(),
    } }
  end

  def handle(msg) do
    GenServer.cast(__MODULE__, msg)
  end
  
  def handle_cast(%MM.EventData{}=msg, %{ me: me }=state) do
    Logger.debug inspect(msg, pretty: true)
    case msg do
      %{ sender_name: "@" <> ^me } ->
        :ok
      %{ channel_type: "D", sender_name: name, post: %{ message: text } } ->
        _send_webhook(state.webhook, "#{name}: #{text}")
      %{ channel_name: chan, sender_name: name, post: %{ message: text } } ->
        if String.match?(text, state.highlights) do
          _send_webhook(state.webhook, "[#{chan}] #{name}: #{text}")
        end
      _ -> :ok
    end
    {:noreply, state}
  end
  def handle_cast(_, state), do: {:noreply, state}

  def _send_webhook(hook, data) do
    header = [{"Content-Type", "text/plain"}]
    Task.start( fn -> :hackney.post(hook, header, data) end)
  end

end
