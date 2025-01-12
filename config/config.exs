import Config

config :logger, :console,
  format: "$date $time [$level] $message\n"

config :tesla, adapter: Tesla.Adapter.Hackney

config :wingman, env: Config.config_env()

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :tzdata, :autoupdate, :disabled
