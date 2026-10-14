defmodule Frameshift.Illustration.PanelCandidate do
  @moduledoc """
  Builds a source-dimension review for the selected preliminary display candidate.

  ## Geometry and evidence

  `bundle/2` uses integer micrometres from the retained dimensional record.
  The outline is a rectangular nominal envelope, rather than manufacturer CAD.
  The active-area rectangle uses a one-micrometre presentation slab and is detached for inspection: its position is an
  explicit presentation offset because the complete source datum map remains
  unresolved. Regional protrusions are listed in the record rather than placed
  at invented coordinates. Both physical and procedure reports remain unknown.

  ## Enclosure recipe

  `enclosure/1` supplies every required product term to
  `Frameshift.Illustration.Enclosure.derive/1`. Unselected glazing, mat, frame
  face, electronics, connectors, clearances, retention, backing and mounting
  leave the minimum unresolved. The drawing cannot silently select those parts
  or turn one rear-region nominal depth into a complete installed thickness.
  """

  alias Frameshift.Illustration.{Enclosure, Fixture}

  @limitation "Nominal source-dimension envelope sketch, not manufacturer CAD. Active area detached at a presentation offset; complete datum and protrusion locations unresolved. Enclosure and complete installed depth unknown."

  @doc "Returns an exact, source-bound candidate scene with no invented wooden enclosure."
  @spec bundle(String.t(), map()) :: binary()
  def bundle(profile_digest, record) do
    width = nominal(record, "outline.width")
    height = nominal(record, "outline.height")
    depth = nominal(record, "body.depth")
    active_width = nominal(record, "active.width")
    active_height = nominal(record, "active.height")
    source_id = Conjunct.Wire.blob_id(encode(record))

    Fixture.bundle(profile_digest,
      revision: "boe-mv270qhm-n40-p1/1",
      family: "photo",
      title: "Frameshift / BOE MV270QHM-N40 P1",
      reference: record["source"]["url"],
      limitation: @limitation <> " Dimension record: " <> source_id,
      description:
        "Panel outline 608.8 × 355.3 mm; body 9.3 mm nominal. Active area 596.736 × 335.664 mm, detached for inspection. Regional depths and complete wooden thickness remain unresolved. Document model conflict requires qualification.",
      feature_source: "sourced",
      dimension_features: %{
        "panel-outline" => [{"height", 1, [0, 2]}, {"body-depth", 2, [0, 4]}],
        "active-area" => [{"height", 1, [0, 2]}]
      },
      components: [
        {"panel-outline", "Panel nominal body envelope", "metal", units([width, height, depth]),
         units([-div(width, 2), -div(height, 2), 0]), [0, 0, 0], "display", "dimension"},
        {"active-area", "Active area / detached datum", "screen",
         units([active_width, active_height, 1]),
         units([-div(active_width, 2), -div(active_height, 2), depth + 1000]), [0, 0, 70],
         "active-area", "dimension"}
      ],
      step_specs: [{"inspect-dimensions", ["panel-outline", "active-area"], []}],
      readouts: [
        %{
          "id" => "outline-width",
          "label" => "Outline W",
          "node" => "panel-outline",
          "feature" => "width"
        },
        %{
          "id" => "active-width",
          "label" => "Active W",
          "node" => "active-area",
          "feature" => "width"
        },
        %{
          "id" => "outline-height",
          "label" => "Outline H",
          "node" => "panel-outline",
          "feature" => "height"
        },
        %{
          "id" => "body-depth",
          "label" => "Body D nominal",
          "node" => "panel-outline",
          "feature" => "body-depth"
        },
        %{
          "id" => "active-height",
          "label" => "Active H",
          "node" => "active-area",
          "feature" => "height"
        }
      ],
      wording: %{
        "inspect-dimensions" =>
          "Compare source outline and active-area dimensions. The active rectangle is detached, so its position is not a panel datum or a mat design.",
        "physical-qualification-required" =>
          "Minimum wood depth UNKNOWN: complete mated panel, controller, backlight driver, glass, mat, retention, backing, mounting and clearances require exact inputs."
      }
    )
  end

  @doc "Returns the complete required-term recipe, retaining every unselected design input."
  @spec enclosure(map()) :: {:ok, map()} | {:error, atom()}
  def enclosure(record) do
    common =
      Enum.map(
        [
          "protection-glass",
          "front-clearance",
          "passe-partout",
          "retention",
          "backing",
          "wall-mount",
          "service-clearance"
        ],
        &missing/1
      )

    Enclosure.derive(%{
      width: [
        bounded(record, "outline.width"),
        missing("lateral-fit-clearance"),
        missing("mat-border-and-frame-face.width")
      ],
      height: [
        bounded(record, "outline.height"),
        missing("vertical-fit-clearance"),
        missing("mat-border-and-frame-face.height")
      ],
      regions: [
        %{id: "display-installed", terms: common ++ [missing("complete-mated-panel.depth")]},
        %{
          id: "electronics-installed",
          terms:
            common ++
              Enum.map(
                [
                  "controller-and-placement",
                  "backlight-driver",
                  "power-path",
                  "mated-connectors",
                  "cable-bend-clearance"
                ],
                &missing/1
              )
        }
      ]
    })
  end

  @doc "Returns static and motion checkpoints tied to the candidate's original scene bytes."
  @spec states(binary()) :: binary()
  def states(scene) do
    base = %{
      "id" => "nominal-envelope",
      "camera" => "orthographic-45-30",
      "viewport" => [1200, 900],
      "theme" => "monochrome",
      "mode" => "assembled",
      "transition" => rational(0, 1),
      "step" => "inspect-dimensions",
      "selection" => nil,
      "isolation" => [],
      "visible_layers" => [],
      "reduced_motion" => true,
      "framing" => "context"
    }

    states =
      [base] ++
        Enum.map(0..4, fn i ->
          Map.merge(base, %{
            "id" => "separate-#{i}",
            "mode" => "exploded",
            "transition" => rational(i, 4),
            "reduced_motion" => false
          })
        end) ++
        [
          Map.merge(base, %{"id" => "source-front", "camera" => "front"}),
          Map.merge(base, %{"id" => "source-top", "camera" => "top"}),
          Map.merge(base, %{"id" => "material-colour", "theme" => "light"}),
          Map.merge(base, %{"id" => "dark", "theme" => "dark"})
        ]

    encode(%{
      "kind" => "illustration-state-set",
      "schema_version" => "conjunct/illustration-states/1",
      "scene_digest" => Conjunct.Wire.blob_id(scene),
      "states" => states
    })
  end

  defp units(values), do: Enum.map(values, &{:um, &1})
  defp missing(id), do: %{id: id, state: :missing}
  defp dimension(record, id), do: Enum.find(record["dimensions"], &(&1["id"] == id))
  defp nominal(record, id), do: dimension(record, id)["nominal"]

  defp bounded(record, id) do
    value = dimension(record, id)

    %{
      id: id,
      state: :known,
      basis: :bounded,
      min_um: value["min"],
      max_um: value["max"],
      source: record["source"]["digest"] <> "#" <> value["locator"]
    }
  end

  defp rational(n, d) do
    divisor = Integer.gcd(n, d)
    %{"n" => Integer.to_string(div(n, divisor)), "d" => Integer.to_string(div(d, divisor))}
  end

  defp encode(value) do
    {:ok, bytes} = Conjunct.Wire.encode_canonical(value)
    bytes
  end
end
