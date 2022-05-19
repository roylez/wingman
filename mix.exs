defmodule Wingman.MixProject do
  use Mix.Project

  def project do
    [
      app: :wingman,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: Luerl],
      releases: releases(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Wingman.Application, []}
    ]
  end

  defp releases do
    [
      wingman: [
        include_executables_for: [:unix],
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4.0"},
      {:jason, ">= 1.0.0"},
      {:hackney, "~> 1.17"},
      {:websockex, "~> 0.4"},
    ]
  end
end
