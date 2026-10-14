defmodule Frameshift.Illustration.Review do
  @moduledoc """
  Joins installed producer output to the product's static review document.

  A caller selects the native executable, committed fixture directory and new
  destination explicitly. The host invokes Conjunct, then passes original
  manifest and semantic bytes, local variants and the passive producer adapter
  into DocShell. Product wording and layout remain here; no generic scene or
  artifact semantics are reimplemented.

  ## Failure and publication

  Native refusal stops the document join. DocShell checks every advertised
  variant and source binding before its staged export. Existing destinations
  refuse; baseline approval and hardware qualification are separate actions.
  Merely loading this module starts no renderer or application supervisor.
  """

  alias Conjunct.Illustration.DocumentProfile
  alias Conjunct.Wire
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactBlock, Asset, Page, Renderer, Site, StaticExporter}

  @doc "Generates and exports one exact local frame packet from explicit installed producers."
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(options) do
    destination = Keyword.fetch!(options, :destination)
    fixture = Keyword.fetch!(options, :fixture)
    executable = Keyword.fetch!(options, :renderer)
    base_path = Keyword.get(options, :base_path, "/")
    packet = Path.join(destination, "packet")

    with false <- File.exists?(destination),
         {output, 0} <-
           System.cmd(
             executable,
             [
               "generate",
               "--bundle",
               Path.join(fixture, "scene.json"),
               "--states",
               Path.join(fixture, "states.json"),
               "--output",
               packet
             ],
             stderr_to_stdout: true
           ),
         {:ok, _} <- Wire.decode(String.trim(output)),
         {:ok, inputs} <- inputs(packet),
         {:ok, site, artifact_options} <- site(inputs, base_path),
         {:ok, manifest} <-
           StaticExporter.export(
             site: site,
             renderer: Frameshift.Illustration.Renderer,
             destination: Path.join(destination, "document"),
             artifact_options: artifact_options
           ) do
      {:ok, manifest}
    else
      true ->
        {:error, :destination_exists}

      {output, status} when is_binary(output) and is_integer(status) ->
        {:error, {:producer_refused, status, String.trim(output)}}

      {:error, _} = error ->
        error
    end
  end

  @doc "Builds a document from caller-supplied original packet bytes and local variants."
  @spec site(map(), String.t()) :: {:ok, Site.t(), keyword()} | {:error, term()}
  def site(inputs, base_path) do
    with {:ok, manifest} <- Wire.decode(inputs.manifest),
         {:ok, semantics} <- Wire.decode(inputs.semantics) do
      nodes = Enum.map(semantics["states"], &block(&1, manifest, inputs.manifest))
      {:ok, content_digest} = Canonical.digest(nodes)
      first = hd(semantics["states"])
      synthetic? = Enum.all?(first["readouts"], &(&1["source"] == "synthetic"))

      page = %Page{
        id: "frame-review",
        collection_id: "frame-fixtures",
        document_id: "frame-illustration",
        kind: "guide",
        route: base_path,
        title: first["title"] <> " / Review",
        locale: "en",
        template: :document,
        content: nodes,
        content_digest: content_digest,
        source_revision: manifest["scene_digest"],
        package_version: "0.1.0",
        requirements: [
          %Renderer.CapabilityRequirement{
            feature_id: "doc-shell/html/v1",
            acceptable_states: [:fallback],
            essential?: true
          }
        ]
      }

      site = %Site{
        schema_version: "doc-shell-site/v1",
        generation_id: Wire.blob_id(inputs.manifest),
        cohort_digest: manifest["scene_digest"],
        profile: "frameshift/illustration-review/v1",
        title: page.title,
        base_path: base_path,
        default_locale: "en",
        locales: ["en"],
        pages: %{page.id => page},
        routes: %{page.route => page.id},
        navigation: [],
        search: [],
        redirects: %{},
        metadata: %{"source_tier" => if(synthetic?, do: "synthetic", else: "sourced-candidate")}
      }

      {:ok, site, artifact_options(inputs, manifest)}
    end
  end

  @doc "Reads an explicit local packet for the host-owned document handoff."
  @spec inputs(String.t()) :: {:ok, map()} | {:error, term()}
  def inputs(packet) do
    with {:ok, manifest_bytes} <- File.read(Path.join(packet, "manifest.json")),
         {:ok, semantics_bytes} <- File.read(Path.join(packet, "semantics.json")),
         {:ok, manifest} <- Wire.decode(manifest_bytes) do
      assets =
        for file <- manifest["files"],
            file["media_type"] == "image/svg+xml",
            do: %Asset{
              path: file["path"],
              media_type: file["media_type"],
              bytes: File.read!(Path.join(packet, file["path"]))
            }

      {:ok, %{manifest: manifest_bytes, semantics: semantics_bytes, assets: assets}}
    end
  end

  defp block(state, manifest, manifest_bytes) do
    id = state["state"]["id"]
    file = Enum.find(manifest["files"], &(&1["path"] == "states/#{id}.svg"))

    subjects = Enum.map(state["subjects"], &{"conjunct/occurrence", &1["id"]})

    features =
      state["readouts"]
      |> Enum.map(&{"conjunct/feature", &1["node"] <> "#" <> &1["feature"]})
      |> Enum.uniq()

    bindings =
      (subjects ++ features)
      |> Enum.with_index()
      |> Enum.map(fn {{kind, subject}, index} ->
        %{
          "anchor" => "#{id}-s#{index}",
          "subject_ref" => manifest["scene_digest"] <> "#" <> subject,
          "subject_kind" => kind,
          "subject_id" => subject
        }
      end)

    fallback =
      Enum.map(
        bindings,
        &%{"tag" => "span", "attrs" => %{"id" => &1["anchor"]}, "content" => [], "meta" => %{}}
      ) ++
        [
          %{
            "tag" => "p",
            "attrs" => %{},
            "content" => [
              state["description"],
              " Physical checks are unknown. Procedure completion is not recorded. Required physical qualification, cable bend clearance and mounting checks remain open."
            ],
            "meta" => %{}
          }
        ] ++
        Enum.map(
          state["readouts"],
          &%{
            "tag" => "p",
            "attrs" => %{},
            "content" => ["#{&1["label"]}: #{&1["display"]} (#{&1["source"]}, exact)."],
            "meta" => %{}
          }
        )

    block = %{
      "schema_version" => "doc-shell-artifact-block/v1",
      "profile" => manifest["profile"]["profile"],
      "profile_digest" => manifest["profile"]["profile_digest"],
      "artifact_ref" => manifest["scene_digest"],
      "manifest_digest" => Wire.blob_id(manifest_bytes),
      "caption" => caption(id),
      "description" => description(id),
      "locale" => "en",
      "bindings" => bindings,
      "variants" => [
        %{
          "id" => "#{id}-svg",
          "profile" => manifest["profile"]["profile"],
          "profile_digest" => manifest["profile"]["profile_digest"],
          "state" => "fallback",
          "media_type" => "image/svg+xml",
          "blob_digest" => file["digest"],
          "byte_length" => file["byte_length"],
          "asset" => file["path"],
          "runtime" => []
        }
      ],
      "acceptable_states" => ["fallback"],
      "essential" => true,
      "fallback_digest" => ""
    }

    node = %{
      "tag" => "artifact",
      "attrs" => %{"id" => id},
      "content" => fallback,
      "meta" => %{"artifact" => block}
    }

    node = Map.update!(node, "content", &(&1 ++ fallback_details(state)))
    {:ok, digest} = ArtifactBlock.fallback_digest(node)
    put_in(node, ["meta", "artifact", "fallback_digest"], digest)
  end

  defp fallback_details(state) do
    steps =
      Enum.map(state["steps"], fn step ->
        %{
          "tag" => "p",
          "attrs" => %{},
          "content" => [step["wording"] | Enum.map(step["warnings"], & &1["wording"])],
          "meta" => %{}
        }
      end)

    parts = %{
      "tag" => "ul",
      "attrs" => %{},
      "content" =>
        Enum.map(
          state["subjects"],
          &%{
            "tag" => "li",
            "attrs" => %{},
            "content" => ["#{&1["label"]} (#{&1["id"]}). #{&1["limitation"]}"],
            "meta" => %{}
          }
        ),
      "meta" => %{}
    }

    steps ++ [parts]
  end

  defp artifact_options(inputs, manifest) do
    descriptor = DocumentProfile.describe()

    capabilities = %{
      "schema_version" => "doc-shell-renderer-capabilities/v2",
      "renderer_id" => "frameshift/illustration-review",
      "renderer_version" => "0.1.0",
      "output_modes" => ["static"],
      "features" => [
        %{
          "id" => "static-svg",
          "profile" => descriptor["profile"],
          "profile_digest" => manifest["profile"]["profile_digest"],
          "schema_digest" => descriptor["input_schema_digest"],
          "output_mode" => "static",
          "state" => "fallback",
          "media_types" => ["image/svg+xml"],
          "runtime" => []
        }
      ]
    }

    [
      profiles: [DocumentProfile],
      assets: inputs.assets,
      manifests: %{Wire.blob_id(inputs.manifest) => inputs.manifest},
      projections: %{Wire.blob_id(inputs.manifest) => inputs.semantics},
      capabilities: capabilities,
      constraints: %{
        "output_mode" => "static",
        "reader_mode" => "file",
        "preferences" => ["static-svg"],
        "available_runtime" => [],
        "forbidden_runtime" => ["browser_js", "live_transport", "native_host"]
      }
    ]
  end

  defp caption("assembled"), do: "The assembled frame"
  defp caption("explode-1-1"), do: "The complete exploded stack"
  defp caption("connector-detail"), do: "Controller, power exit and route"
  defp caption(id), do: id |> String.replace("-", " ") |> String.capitalize()

  defp description("assembled"),
    do:
      "The timber enclosure, passe-partout and active opening share the exact panel binding. Rear electronics remain part of the same composition."

  defp description("explode-1-1"),
    do:
      "Presentation offsets separate the optical stack, electronics, service backing and wall interface. They do not change physical placements."

  defp description("connector-detail"),
    do:
      "A source-bound inspection of the controller, connector exit and power route. Electrical and bend-radius qualification remain unknown."

  defp description(_),
    do:
      "An exact state from the same synthetic frame, with text, dimensions, warnings and source limitations preserved."
end
