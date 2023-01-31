import Config

config :wingman, :mattermost,
  api_url: URI.merge(System.get_env("MATTERMOST_API_URL"), "/api/v4") |> URI.to_string(),
  token:   System.get_env("MATTERMOST_TOKEN")

config :wingman,
  webhook: System.get_env("WINGMAN_WEBHOOK") |> String.trim(),
  highlights: System.get_env("WINGMAN_HIGHLIGHTS"),
  debug: System.get_env("WINGMAN_DEBUG") == "1"

config :logger, :console,
  level: System.get_env("WINGMAN_DEBUG") == "1" && :debug || :info
