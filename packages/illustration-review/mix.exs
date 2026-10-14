defmodule FrameshiftIllustrationReview.MixProject do
  @moduledoc """
  Builds the isolated consumer for installed illustration and document producers.

  The application is passive. Runtime dependencies use versioned declarations;
  three explicit source variables support development and unpacked archive
  qualification. Hosts select the executable and output directory at call time.
  This package does not boot the artwork core or companion platform.
  """

  use Mix.Project

  def project do
    [
      app: :frameshift_illustration_review,
      version: "0.1.0",
      elixir: "~> 1.20",
      deps: [
        dependency(:doc_shell, "~> 0.5.0", "DOC_SHELL_SOURCE"),
        dependency(:conjunct_wire, "~> 0.1.0", "CONJUNCT_WIRE_SOURCE"),
        dependency(:conjunct_illustration, "~> 0.1.0", "CONJUNCT_ILLUSTRATION_SOURCE")
      ],
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application, do: [extra_applications: [:crypto]]

  defp dependency(app, version, variable) do
    case System.get_env(variable) do
      nil -> {app, version}
      source -> {app, [path: source, override: true]}
    end
  end
end
