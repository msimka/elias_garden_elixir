defmodule EliasUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :elias_utils,
      version: "1.0.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "ELIAS CLI Utilities - Workflow enhancement tools",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "elias_utils",
      maintainers: ["ELIAS Development Team"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/elias/elias_garden_elixir"}
    ]
  end
end