import Config

config :logger, :console,
  metadata: [:channel],
  level: config_env() == :prod && :info || :debug,
  handle_sasl_reports: config_env() == :dev

config :tesla, adapter: Tesla.Adapter.Hackney
