import Config

config :logger, :console,
  format: "$date $time $levelpad$message\n"

config :tesla, adapter: Tesla.Adapter.Hackney
