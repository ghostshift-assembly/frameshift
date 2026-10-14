defmodule Frameshift.Illustration.AssemblyDraft do
  @moduledoc """
  Calculates a layered enclosure draft from the panel record and explicit design inputs.

  ## Inputs and results

  `derive/2` accepts integer micrometres from a caller-owned draft. Glass and mat
  thickness, mat border/overlap, timber wall/lip/rebate, fit and clearance are
  design choices, never supplier measurements. The panel cavity uses the larger
  of the source outline upper bounds and the drafted mat footprint. The timber
  outside size follows from that cavity and the wall; its displayed depth follows
  the stated planning stack, rather than a fixed wooden frame dimension.

  The planning panel depth is an explicit input because source regional depths
  do not establish the complete mated envelope. `Frameshift.Illustration.Enclosure`
  retains supplied design terms and unresolved installed envelopes separately.
  The draft therefore cannot become a minimum-depth or compatibility result.

  ## Geometry and use

  `bundle/3` returns original Conjunct carriers for the wood walls/front lip,
  glass, four mat strips and nominal panel body. The centred opening is a draft
  placement, not an established panel datum. Unselected electronics, retention,
  backing and mounting have no fabricated substitute geometry. `states/1`
  supplies complete-layer, isolated-layer, section and motion inspections; the
  assembled section deliberately omits the opaque glass inspection surface.
  Hosts own files, UI and invocation; this module starts no process or I/O.
  """

  alias Frameshift.Illustration.{Enclosure, Fixture}

  @fields ~w(glass_thickness_um mat_thickness_um mat_border_um aperture_overlap_um wood_wall_um wood_lip_um rebate_overlap_um fit_per_side_um front_clearance_um rear_clearance_um planning_panel_depth_um)

  @doc "Derives draft dimensions and keeps complete installed thickness unresolved."
  @spec derive(map(), map()) :: {:ok, map()} | {:error, atom()}
  def derive(record, %{
        "schema_version" => "frameshift/assembly-draft-inputs/1",
        "units" => "um",
        "values" => inputs
      })
      when is_map(inputs) do
    valid =
      Enum.sort(Map.keys(inputs)) == Enum.sort(@fields) and
        Enum.all?(@fields, fn key ->
          is_integer(inputs[key]) and inputs[key] >= 0 and inputs[key] <= 100_000
        end)

    with true <- valid_record?(record),
         true <- valid,
         true <-
           Enum.all?(
             ~w(glass_thickness_um mat_thickness_um mat_border_um wood_wall_um wood_lip_um rebate_overlap_um planning_panel_depth_um),
             &(inputs[&1] > 0)
           ),
         true <- inputs["rebate_overlap_um"] < inputs["mat_border_um"],
         true <- inputs["aperture_overlap_um"] * 2 < nominal(record, "active.height"),
         true <- inputs["planning_panel_depth_um"] >= maximum(record, "body.depth") do
      opening_w = nominal(record, "active.width") - 2 * inputs["aperture_overlap_um"]
      opening_h = nominal(record, "active.height") - 2 * inputs["aperture_overlap_um"]
      mat_w = opening_w + 2 * inputs["mat_border_um"]
      mat_h = opening_h + 2 * inputs["mat_border_um"]
      cavity_w = max(maximum(record, "outline.width"), mat_w) + 2 * inputs["fit_per_side_um"]
      cavity_h = max(maximum(record, "outline.height"), mat_h) + 2 * inputs["fit_per_side_um"]

      front_stack =
        inputs["wood_lip_um"] + inputs["glass_thickness_um"] + inputs["front_clearance_um"] +
          inputs["mat_thickness_um"]

      depth = front_stack + inputs["planning_panel_depth_um"] + inputs["rear_clearance_um"]

      {:ok, enclosure} =
        enclosure(
          inputs,
          record,
          cavity_w + 2 * inputs["wood_wall_um"],
          cavity_h + 2 * inputs["wood_wall_um"]
        )

      {:ok,
       %{
         inputs: inputs,
         opening_w: opening_w,
         opening_h: opening_h,
         cavity_w: cavity_w,
         cavity_h: cavity_h,
         mat_w: mat_w,
         mat_h: mat_h,
         outer_w: cavity_w + 2 * inputs["wood_wall_um"],
         outer_h: cavity_h + 2 * inputs["wood_wall_um"],
         shown_depth: depth,
         front_stack: front_stack,
         enclosure: enclosure,
         unresolved: enclosure.unresolved,
         scope:
           "Editable design draft; shown rail depth is a planning scenario. Complete installed minimum UNKNOWN; aperture datum and electronics unqualified."
       }}
    else
      _ -> {:error, :invalid_assembly_draft}
    end
  end

  def derive(_, _), do: {:error, :invalid_assembly_draft}

  @doc "Builds the layered draft using calculated timber and explicit source/design status."
  @spec bundle(String.t(), map(), map()) :: {:ok, binary()} | {:error, atom()}
  def bundle(profile, record, inputs) do
    with {:ok, d} <- derive(record, inputs) do
      i = d.inputs
      wall = i["wood_wall_um"]
      lip = i["wood_lip_um"]
      rebate = i["rebate_overlap_um"]
      lip_w = wall + rebate
      cavity_x = -div(d.cavity_w, 2)
      cavity_y = -div(d.cavity_h, 2)
      x = -div(d.outer_w, 2)
      y = -div(d.outer_h, 2)
      glass_top = -lip
      mat_top = glass_top - i["glass_thickness_um"] - i["front_clearance_um"]
      panel_top = -d.front_stack
      panel_w = nominal(record, "outline.width")
      panel_h = nominal(record, "outline.height")
      panel_depth = nominal(record, "body.depth")

      parts =
        ring(
          "wood-wall",
          "Timber wall / calculated draft",
          "timber",
          d.outer_w,
          d.outer_h,
          wall,
          d.shown_depth - lip,
          x,
          y,
          -d.shown_depth,
          [0, 0, 180],
          "wood"
        ) ++
          ring(
            "wood-lip",
            "Timber rebate lip / design",
            "timber",
            d.outer_w,
            d.outer_h,
            lip_w,
            lip,
            x,
            y,
            -lip,
            [0, 0, 180],
            "wood"
          ) ++
          [
            {"glass", "Protection glass / design thickness", "paper",
             units([
               d.cavity_w - 2 * i["fit_per_side_um"],
               d.cavity_h - 2 * i["fit_per_side_um"],
               i["glass_thickness_um"]
             ]),
             units([
               cavity_x + i["fit_per_side_um"],
               cavity_y + i["fit_per_side_um"],
               glass_top - i["glass_thickness_um"]
             ]), [-160, 0, 65], "glass", "dimension"}
          ] ++
          ring(
            "mat",
            "Passe-partout / draft opening",
            "paper",
            d.mat_w,
            d.mat_h,
            i["mat_border_um"],
            i["mat_thickness_um"],
            -div(d.mat_w, 2),
            -div(d.mat_h, 2),
            mat_top - i["mat_thickness_um"],
            [0, 0, -70],
            "mat"
          ) ++
          [
            {"panel", "BOE P1 / nominal body envelope", "screen",
             units([panel_w, panel_h, panel_depth]),
             units([-div(panel_w, 2), -div(panel_h, 2), panel_top - panel_depth]), [160, 0, -260],
             "display", "dimension"}
          ]

      all = Enum.map(parts, &elem(&1, 0))

      readouts = [
        %{
          "id" => "outside-width",
          "label" => "Draft outside W",
          "node" => "wood-wall-top",
          "feature" => "width"
        },
        %{
          "id" => "shown-depth",
          "label" => "Draft wall D (lip separate)",
          "node" => "wood-wall-top",
          "feature" => "depth"
        },
        %{
          "id" => "glass-thickness",
          "label" => "Draft glass",
          "node" => "glass",
          "feature" => "depth"
        },
        %{
          "id" => "mat-thickness",
          "label" => "Draft mat",
          "node" => "mat-top",
          "feature" => "depth"
        },
        %{
          "id" => "mat-opening",
          "label" => "Draft opening W",
          "node" => "mat-top",
          "feature" => "opening-width"
        },
        %{
          "id" => "panel-width",
          "label" => "Panel W nominal",
          "node" => "panel",
          "feature" => "width"
        }
      ]

      dimension_features =
        Map.new(parts, fn {id, _, _, _, _, _, _, _} ->
          {id, [{"height", 1, [0, 2]}, {"depth", 2, [0, 4]}]}
        end)

      input_ref = inputs |> encode() |> Conjunct.Wire.blob_id()
      panel_ref = record |> encode() |> Conjunct.Wire.blob_id()

      scene =
        Fixture.bundle(profile,
          revision: "boe-p1-assembly-draft/1/" <> input_ref,
          family: "photo-draft",
          title: "Frameshift / BOE P1 assembly draft",
          reference: record["source"]["url"],
          fixture_details: false,
          limitation:
            d.scope <> " Design inputs: " <> input_ref <> "; panel record: " <> panel_ref,
          description:
            "Calculated wood walls and rebate, protection glass, passe-partout and source-sized BOE panel. Planning rail depth #{d.shown_depth / 1000} mm; complete installed minimum UNKNOWN. Electronics, retention, backing and mount are unselected; no substitute shapes. Centred aperture is a draft placement. Glass is an opaque inspection surface; the assembled section hides it.",
          feature_source: "synthetic",
          feature_sources: %{"panel" => "sourced"},
          part_manufacturers:
            Map.new(
              all,
              &{&1, if(&1 == "panel", do: "urn:manufacturer:boe", else: "urn:frameshift:design")}
            ),
          dimension_features: dimension_features,
          span_features: %{
            "mat-top" => [
              {"opening-width", units([i["mat_border_um"], 0, i["mat_thickness_um"]]),
               units([i["mat_border_um"] + d.opening_w, 0, i["mat_thickness_um"]]),
               {:um, d.opening_w}}
            ]
          },
          components: parts,
          readouts: readouts,
          step_specs: [{"inspect-stack", all, []}],
          wording: %{
            "inspect-stack" =>
              "Inspect each source-sized and drafted layer; no assembly execution or work completion is qualified.",
            "physical-qualification-required" =>
              d.scope <> " Missing: " <> Enum.join(d.unresolved, ", ")
          }
        )

      {:ok, scene}
    end
  end

  @doc "Returns full-layer, section, isolation and transition checkpoints for the draft."
  @spec states(binary()) :: binary()
  def states(scene) do
    base = %{
      "id" => "full-stack",
      "camera" => "orthographic-45-30",
      "viewport" => [1200, 900],
      "theme" => "monochrome",
      "mode" => "exploded",
      "transition" => rational(1, 1),
      "step" => nil,
      "selection" => nil,
      "isolation" => [],
      "visible_layers" => [],
      "reduced_motion" => true,
      "framing" => "context"
    }

    {:ok, parsed} = Conjunct.Wire.decode(scene)
    without_glass = parsed["nodes"] |> Enum.reject(&(&1["id"] == "glass")) |> Enum.map(& &1["id"])

    states =
      [
        base,
        Map.merge(base, %{
          "id" => "assembled-section",
          "mode" => "assembled",
          "transition" => rational(0, 1),
          "isolation" => without_glass
        }),
        Map.merge(base, %{
          "id" => "wood-rebate",
          "visible_layers" => ["wood"],
          "framing" => "visible"
        }),
        Map.merge(base, %{
          "id" => "glass-inspection",
          "visible_layers" => ["glass"],
          "framing" => "visible"
        }),
        Map.merge(base, %{
          "id" => "mat-opening",
          "visible_layers" => ["mat"],
          "framing" => "visible",
          "camera" => "front"
        }),
        Map.merge(base, %{
          "id" => "panel-body",
          "visible_layers" => ["display"],
          "framing" => "visible"
        }),
        Map.merge(base, %{"id" => "material-colour", "theme" => "light"}),
        Map.merge(base, %{"id" => "side-stack", "camera" => "top"})
      ] ++
        Enum.map(0..4, fn n ->
          Map.merge(base, %{
            "id" => "stack-#{n}",
            "transition" => rational(n, 4),
            "reduced_motion" => false
          })
        end)

    encode(%{
      "kind" => "illustration-state-set",
      "schema_version" => "conjunct/illustration-states/1",
      "scene_digest" => Conjunct.Wire.blob_id(scene),
      "states" => states
    })
  end

  defp ring(id, label, material, w, h, b, depth, x, y, z, explode, layer) do
    [
      {id <> "-top", label, material, units([w, b, depth]), units([x, y + h - b, z]), explode,
       layer, "dimension"},
      {id <> "-bottom", label, material, units([w, b, depth]), units([x, y, z]), explode, layer,
       "dimension"},
      {id <> "-left", label, material, units([b, h - 2 * b, depth]), units([x, y + b, z]),
       explode, layer, "dimension"},
      {id <> "-right", label, material, units([b, h - 2 * b, depth]),
       units([x + w - b, y + b, z]), explode, layer, "dimension"}
    ]
  end

  defp valid_record?(record) when is_map(record) do
    values = Map.get(record, "dimensions", [])

    is_list(values) and is_map(record["candidate"]) and
      is_map(record["source"]) and is_binary(record["source"]["digest"]) and
      is_binary(record["source"]["url"]) and
      record["candidate"]["model"] == "MV270QHM-N40" and
      record["candidate"]["document_revision"] == "P1" and
      Enum.all?(~w(outline.width outline.height body.depth active.width active.height), fn id ->
        case Enum.filter(values, &(is_map(&1) and &1["id"] == id)) do
          [%{"nominal" => n} = value] when is_integer(n) and n > 0 and n < 1_000_000 ->
            if id in ~w(active.width active.height),
              do: true,
              else:
                is_integer(value["min"]) and is_integer(value["max"]) and
                  value["min"] > 0 and value["min"] <= n and value["max"] >= n and
                  value["max"] < 1_000_000

          _ ->
            false
        end
      end)
  end

  defp valid_record?(_), do: false

  defp enclosure(inputs, record, width, height) do
    source = inputs |> encode() |> Conjunct.Wire.blob_id()

    design = fn id, value ->
      %{
        id: id,
        state: :known,
        basis: :design,
        min_um: value,
        max_um: value,
        source: source <> "#" <> id
      }
    end

    common =
      Enum.map(
        ~w(wood_lip_um glass_thickness_um front_clearance_um mat_thickness_um rear_clearance_um),
        &design.(&1, inputs[&1])
      ) ++
        Enum.map(~w(retention backing wall-mount service-clearance), &%{id: &1, state: :missing})

    Enclosure.derive(%{
      width: [design.("calculated-outside-width", width)],
      height: [design.("calculated-outside-height", height)],
      regions: [
        %{
          id: "display-installed",
          terms:
            common ++
              [
                %{
                  id: "complete-mated-panel.depth",
                  state: :missing,
                  source: record["source"]["digest"]
                }
              ]
        },
        %{
          id: "electronics-installed",
          terms:
            common ++
              Enum.map(
                ~w(controller-and-placement backlight-driver power-path mated-connectors cable-bend-clearance),
                &%{id: &1, state: :missing}
              )
        }
      ]
    })
  end

  defp dimension(record, id), do: Enum.find(record["dimensions"], &(&1["id"] == id))
  defp nominal(record, id), do: dimension(record, id)["nominal"]
  defp maximum(record, id), do: dimension(record, id)["max"]
  defp units(values), do: Enum.map(values, &{:um, &1})

  defp rational(n, d) do
    gcd = Integer.gcd(n, d)
    %{"n" => Integer.to_string(div(n, gcd)), "d" => Integer.to_string(div(d, gcd))}
  end

  defp encode(value) do
    {:ok, bytes} = Conjunct.Wire.encode_canonical(value)
    bytes
  end
end
