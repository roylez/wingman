import Config
import Common.Util

config :wingman, :mattermost,
  api_url: URI.merge(trim_get("WINGMAN_MATTERMOST_URL"), "/api/v4") |> URI.to_string(),
  token:   trim_get("WINGMAN_MATTERMOST_TOKEN")

config :wingman,
  webhook: trim_get("WINGMAN_WEBHOOK"),
  highlights: trim_get("WINGMAN_HIGHLIGHTS"),
  debug: trim_get("WINGMAN_DEBUG") == "1",
  telegram: {
    trim_get("WINGMAN_TELEGRAM_TOKEN"),
    trim_get("WINGMAN_TELEGRAM_CHAT_ID", :integer)
  }

config :logger, :console,
  level: trim_get("WINGMAN_DEBUG") == "1" && :debug || :info

if trim_get("WINGMAN_ENABLE_AT") do
  config :wingman, Wingman.Cron,
    timezone: trim_get("TZ") || "UTC",
    jobs: [
      {trim_get("WINGMAN_ENABLE_AT"), {Wingman.Handler, :on, []}},
      {trim_get("WINGMAN_DISABLE_AT"), {Wingman.Handler, :off, []}}
    ]

end
