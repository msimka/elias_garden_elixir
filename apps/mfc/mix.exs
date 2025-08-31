defmodule MFC.MixProject do
  use Mix.Project

  def project do
    [
      app: :mfc,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      name: "MFC - Multi-Format Converter",
      description: "Global CLI for ELIAS Multi-Format Document Converter"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def escript do
    [
      main_module: MFC.CLI,
      name: "mfc"
    ]
  end

  defp deps do
    [
      {:elias_server, in_umbrella: true},
      {:jason, "~> 1.4"}
    ]
  end
end