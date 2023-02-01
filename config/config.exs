import Config

config :logger, :console,
  format: "$date $time [$level] $levelpad$message\n"

config :tesla, adapter: Tesla.Adapter.Hackney

config :wingman, env: Config.config_env()

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
