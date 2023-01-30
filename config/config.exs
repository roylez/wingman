import Config

config :logger, :console,
  format: "$date $time [$level] $levelpad$message\n"

config :tesla, adapter: Tesla.Adapter.Hackney
