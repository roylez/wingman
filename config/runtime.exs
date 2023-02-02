import Config
import Common.Util

config :wingman, :mattermost,
  api_url: URI.merge(env_get("WINGMAN_MATTERMOST_URL"), "/api/v4") |> URI.to_string(),
  token:   env_get("WINGMAN_MATTERMOST_TOKEN")

config :wingman,
  webhook: env_get("WINGMAN_WEBHOOK"),
  highlights: env_get("WINGMAN_HIGHLIGHTS"),
  debug: env_get("WINGMAN_DEBUG") == "1",
  channels: env_get("WINGMAN_CHANNELS"),
  telegram: {
    env_get("WINGMAN_TELEGRAM_TOKEN"),
    env_get("WINGMAN_TELEGRAM_CHAT_ID", :integer)
  }

config :logger, :console,
  level: env_get("WINGMAN_DEBUG") == "1" && :debug || :info

if env_get("WINGMAN_ENABLE_AT") do
  config :wingman, Wingman.Cron,
    timezone: env_get("TZ") || "UTC",
    jobs: [
      {env_get("WINGMAN_ENABLE_AT"), {Wingman.Handler, :on, []}},
      {env_get("WINGMAN_DISABLE_AT"), {Wingman.Handler, :off, []}}
    ]

end
