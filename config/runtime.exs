import Config
import Wingman.Util

config :wingman, :mattermost,
  api_url: URI.merge(trim_get("MATTERMOST_API_URL"), "/api/v4") |> URI.to_string(),
  token:   trim_get("MATTERMOST_TOKEN")

config :wingman,
  webhook: trim_get("WINGMAN_WEBHOOK"),
  highlights: trim_get("WINGMAN_HIGHLIGHTS"),
  debug: trim_get("WINGMAN_DEBUG") == "1",
  telegram_chat_id: trim_get("WINGMAN_TELEGRAM_CHAT_ID", :integer)

config :logger, :console,
  level: trim_get("WINGMAN_DEBUG") == "1" && :debug || :info

config :nadia,
  token: trim_get("WINGMAN_TELEGRAM_TOKEN")
