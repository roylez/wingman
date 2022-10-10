import Config

config :logger, :console,
  level: config_env() == :prod && :info || :debug,
  format: "$date $time [$level] $levelpad$message\n"

config :tesla, adapter: Tesla.Adapter.Hackney
