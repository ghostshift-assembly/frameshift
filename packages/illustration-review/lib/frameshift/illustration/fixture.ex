defmodule Frameshift.Illustration.Fixture do
  @moduledoc """
  Authors the exact synthetic frame fixture used by illustration integration.

  The geometry describes a software fixture, not manufacturer CAD or a received
  build. It covers the opening, mat, panel, controller, power connector and
  route, backing, mounting and service fasteners. Original Conjunct artifacts
  and detached surfaces are retained with exact identities; physical and
  procedure reports deliberately remain unknown. This module writes no files.

  ## Reproduction

  `bundle/1` uses an exact producer descriptor digest. `states/1` pins the
  resulting original bundle bytes and supplies explicit camera, selection,
  isolation and transition checkpoints. Changes to this fixture produce new
  bindings rather than overwriting earlier source identities.
  """

  alias Conjunct.Wire

  @triangles [
    [0, 3, 1],
    [0, 2, 3],
    [4, 5, 7],
    [4, 7, 6],
    [0, 1, 5],
    [0, 5, 4],
    [2, 6, 7],
    [2, 7, 3],
    [0, 4, 6],
    [0, 6, 2],
    [1, 3, 7],
    [1, 7, 5]
  ]
  @limitation "Synthetic authored geometry. Manufacturer shape, installed fit, cable bend radius, thermal behavior and mounting strength are unqualified."

  @doc "Returns canonical original bytes for the complete synthetic scene bundle."
  @spec bundle(String.t(), keyword()) :: binary()
  def bundle(profile_digest, options \\ []) do
    revision = Keyword.get(options, :revision, "synthetic-photo-frame/1")
    limitation = Keyword.get(options, :limitation, @limitation)

    source =
      doc("source-revision", %{
        "publisher" => "urn:frameshift:fixture",
        "native_revision" => revision,
        "media_type" => "application/json",
        "blob_ref" => nil,
        "reference" =>
          Keyword.get(options, :reference, "urn:frameshift:fixture:synthetic-photo-frame:1"),
        "retention" => "reference-only"
      })

    rules = doc("rule-set", %{"rules" => [], "evidence_refs" => [ref(source)]})
    assessments = doc("assessment-set", %{"assessments" => [], "geometry" => []})
    components = Keyword.get(options, :components, components())

    parts =
      Enum.map(components, fn {id, _, _, _, _, _, _, _} ->
        doc("part-revision", %{
          "key" => %{
            "publisher" => "urn:frameshift:fixture",
            "manufacturer" => "urn:frameshift:synthetic",
            "mpn" => id,
            "revision" => "1"
          },
          "amount_kind" => "count",
          "lifecycle" => "draft",
          "properties" => [],
          "interfaces" => [],
          "children" => [],
          "consumables" => [],
          "geometry" => [],
          "evidence_refs" => [ref(source)]
        })
      end)

    by_id = Map.new(parts, &{&1["body"]["key"]["mpn"], &1})

    product =
      doc("product-definition", %{
        "publisher" => "urn:frameshift:fixture",
        "manufacturer" => "urn:frameshift:synthetic",
        "family" => Keyword.get(options, :family, "synthetic-photo-frame"),
        "intended_uses" => ["urn:frameshift:fixture:visual-inspection"],
        "part_refs" => Enum.sort(Enum.map(parts, &ref/1)),
        "rule_set_ref" => ref(rules),
        "evidence_refs" => [ref(source)]
      })

    occurrences =
      Enum.map(components, fn {id, _, _, _, position, _, _, _} ->
        %{
          "id" => id,
          "part_ref" => ref(by_id[id]),
          "parent" => nil,
          "placement" => pose(position)
        }
      end)
      |> Enum.sort_by(& &1["id"])

    selection =
      doc("selection", %{
        "product_ref" => ref(product),
        "occurrences" => occurrences,
        "relations" => [],
        "consumables" => []
      })

    composition =
      doc("composition", %{
        "contract_ref" => %{
          "id" => "urn:frameshift:fixture:inspection",
          "digest" => Wire.blob_id(revision)
        },
        "product_ref" => ref(product),
        "selection_ref" => ref(selection),
        "rule_set_ref" => ref(rules),
        "occurrences" =>
          Enum.map(occurrences, fn occurrence ->
            occurrence
            |> Map.delete("id")
            |> Map.delete("parent")
            |> Map.merge(%{"path" => [occurrence["id"]], "parent_path" => nil})
          end),
        "relations" => [],
        "consumables" => [],
        "facts" => []
      })

    report = check(composition, rules, assessments)
    steps = steps(ref(source), Keyword.get(options, :step_specs))

    template =
      doc(
        "procedure-template",
        %{
          "rule_set_ref" => ref(rules),
          "slots" => Enum.sort(Enum.map(components, &elem(&1, 0))),
          "parameter_ids" => [],
          "steps" =>
            steps
            |> Enum.map(fn step ->
              Map.update!(step, "subjects", fn paths -> Enum.map(paths, &hd/1) end)
            end)
            |> Enum.sort_by(& &1["id"]),
          "evidence_refs" => [ref(source)]
        },
        true
      )

    parameters =
      doc(
        "procedure-parameters",
        %{"role" => "urn:frameshift:fixture:assembly", "subjects" => [], "values" => []},
        true
      )

    plan =
      doc(
        "procedure-plan",
        %{
          "composition_ref" => ref(composition),
          "template_ref" => ref(template),
          "parameters_ref" => ref(parameters),
          "role" => "urn:frameshift:fixture:assembly",
          "steps" => steps
        },
        true
      )

    plan_report = check(plan, rules, assessments)

    {assets, nodes} =
      Enum.map_reduce(components, [], fn {id, label, material, size, _position, explode, layer,
                                          feature},
                                         nodes ->
        geometry = geometry(size, feature, ref(source)) |> route_geometry(id)

        geometry =
          geometry
          |> Map.put("source_revision", revision)
          |> Map.put("limitation", limitation)
          |> Map.update!("features", fn features ->
            Enum.map(
              features,
              &Map.put(&1, "source", Keyword.get(options, :feature_source, "synthetic"))
            )
          end)

        extra_axes = Keyword.get(options, :dimension_features, %{}) |> Map.get(id, [])

        extra_features =
          Enum.map(extra_axes, fn {name, axis, vertices} ->
            %{
              "id" => name,
              "role" => "dimension",
              "vertices" => vertices,
              "quantity" => %{
                "quantity_kind" => "length",
                "unit" => "m",
                "value" => mm(Enum.at(size, axis))
              },
              "source" => Keyword.get(options, :feature_source, "synthetic"),
              "evidence_refs" => [ref(source)]
            }
          end)

        geometry = Map.update!(geometry, "features", &(&1 ++ extra_features))

        bytes = encode(geometry)

        node = %{
          "id" => id,
          "path" => [id],
          "part_ref" => ref(by_id[id]),
          "asset_ref" => Wire.blob_id(bytes),
          "label" => label,
          "layer" => layer,
          "material" => material,
          "explode" => Enum.map(explode, &mm/1)
        }

        {%{"ref" => Wire.blob_id(bytes), "bytes" => bytes}, [node | nodes]}
      end)

    assets = Enum.uniq_by(assets, & &1["ref"])

    artifacts =
      [
        source,
        rules,
        assessments,
        product,
        selection,
        composition,
        report,
        template,
        parameters,
        plan,
        plan_report
      ] ++ parts

    encode(%{
      "kind" => "illustration-scene",
      "schema_version" => "conjunct/illustration-bundle/1",
      "profile" => "conjunct/technical-illustration/v1",
      "profile_digest" => profile_digest,
      "title" => Keyword.get(options, :title, "Frameshift / Photo frame"),
      "description" =>
        Keyword.get(
          options,
          :description,
          "Synthetic assembly and service-envelope inspection. Dimensions belong to this authored fixture; physical checks and operation readiness remain unknown."
        ),
      "role" => "assembly-instruction",
      "roots" => %{
        "composition" => ref(composition),
        "report" => ref(report),
        "plan" => ref(plan),
        "plan_report" => ref(plan_report)
      },
      "artifacts" => Enum.map(artifacts, &%{"ref" => ref(&1), "bytes" => encode(&1)}),
      "assets" => assets,
      "nodes" => Enum.reverse(nodes),
      "readouts" =>
        Keyword.get(options, :readouts, [
          %{
            "id" => "active-opening-width",
            "label" => "Opening",
            "node" => "mat-top",
            "feature" => "active-opening-width"
          },
          %{
            "id" => "frame-width",
            "label" => "Frame width",
            "node" => "rail-top",
            "feature" => "width"
          },
          %{
            "id" => "panel-width",
            "label" => "Panel width",
            "node" => "panel",
            "feature" => "width"
          },
          %{
            "id" => "controller-width",
            "label" => "Controller width",
            "node" => "controller",
            "feature" => "width"
          }
        ]),
      "wording" => Keyword.get(options, :wording, wording())
    })
  end

  @doc "Returns canonical exact states for the supplied original scene bytes."
  @spec states(binary()) :: binary()
  def states(bundle) do
    base = %{
      "id" => "assembled",
      "camera" => "orthographic-45-30",
      "viewport" => [1200, 900],
      "theme" => "light",
      "mode" => "assembled",
      "transition" => rational(0, 1),
      "step" => nil,
      "selection" => nil,
      "isolation" => [],
      "visible_layers" => [],
      "reduced_motion" => true,
      "framing" => "context"
    }

    checkpoints =
      Enum.map([{0, 1}, {1, 4}, {1, 2}, {3, 4}, {1, 1}], fn {n, d} ->
        Map.merge(base, %{
          "id" => "explode-#{n}-#{d}",
          "mode" => "exploded",
          "transition" => rational(n, d),
          "reduced_motion" => false
        })
      end)

    steps =
      Enum.map(["place-panel", "connect-power", "close-backing", "mount-frame"], fn step ->
        Map.merge(base, %{
          "id" => step,
          "mode" => "exploded",
          "transition" => rational(1, 1),
          "step" => step
        })
      end)

    extras = [
      Map.merge(base, %{
        "id" => "connector-detail",
        "framing" => "visible",
        "camera" => "back",
        "selection" => "power-connector#anchor",
        "isolation" => ["controller", "power-connector", "power-cable"]
      }),
      Map.merge(base, %{"id" => "front", "camera" => "front"}),
      Map.merge(base, %{"id" => "top", "camera" => "top"}),
      Map.merge(base, %{
        "id" => "dark-exploded",
        "theme" => "dark",
        "mode" => "exploded",
        "transition" => rational(1, 1)
      }),
      Map.merge(base, %{
        "id" => "monochrome",
        "theme" => "monochrome",
        "mode" => "exploded",
        "transition" => rational(1, 1)
      })
    ]

    encode(%{
      "kind" => "illustration-state-set",
      "schema_version" => "conjunct/illustration-states/1",
      "scene_digest" => Wire.blob_id(bundle),
      "states" => [base] ++ checkpoints ++ steps ++ extras
    })
  end

  defp components do
    [
      {"rail-top", "Top timber rail", "timber", [400, 20, 32], [-200, 130, 0], [0, 0, 105],
       "enclosure", "fastener"},
      {"rail-bottom", "Bottom timber rail", "timber", [400, 20, 32], [-200, -150, 0], [0, 0, 105],
       "enclosure", "fastener"},
      {"rail-left", "Left timber rail", "timber", [20, 260, 32], [-200, -130, 0], [0, 0, 105],
       "enclosure", "fastener"},
      {"rail-right", "Right timber rail", "timber", [20, 260, 32], [180, -130, 0], [0, 0, 105],
       "enclosure", "fastener"},
      {"mat-top", "Upper passe-partout", "paper", [360, 25, 2], [-180, 105, 27], [0, 0, 70],
       "mat", "dimension"},
      {"mat-bottom", "Lower passe-partout", "paper", [360, 25, 2], [-180, -130, 27], [0, 0, 70],
       "mat", "dimension"},
      {"mat-left", "Left passe-partout", "paper", [25, 210, 2], [-180, -105, 27], [0, 0, 70],
       "mat", "dimension"},
      {"mat-right", "Right passe-partout", "paper", [25, 210, 2], [155, -105, 27], [0, 0, 70],
       "mat", "dimension"},
      {"panel", "Display panel (synthetic)", "screen", [334, 234, 8], [-167, -117, 16],
       [0, 0, 20], "display", "connector"},
      {"controller", "Display controller", "board", [88, 42, 4], [40, -95, 4], [65, -15, -85],
       "electronics", "connector"},
      {"power-connector", "Power connector exit", "metal", [18, 12, 9], [115, -79, 6],
       [65, -15, -85], "electronics", "connector"},
      {"power-cable", "Power route / bend envelope", "cable", [6, 68, 6], [124, -147, 3],
       [65, -15, -85], "electronics", "connector"},
      {"backing", "Removable backing", "metal", [358, 258, 2], [-179, -129, -4], [0, 0, -170],
       "service", "fastener"},
      {"mount", "Wall mounting interface", "metal", [110, 16, 10], [-55, 75, -14], [0, 0, -230],
       "mounting", "fastener"},
      {"service-left", "Left service fastener", "accent", [7, 7, 10], [-170, -120, -8],
       [-18, -15, -185], "service", "fastener"},
      {"service-right", "Right service fastener", "accent", [7, 7, 10], [163, -120, -8],
       [18, -15, -185], "service", "fastener"}
    ]
  end

  defp geometry([width, height, depth], role, evidence) do
    vertices =
      for index <- 0..7,
          do: [
            mm(if(rem(index, 2) == 1, do: width, else: 0)),
            mm(if(rem(div(index, 2), 2) == 1, do: height, else: 0)),
            mm(if(index >= 4, do: depth, else: 0))
          ]

    %{
      "schema_version" => "conjunct/authored-surfaces/1",
      "units" => "m",
      "frame" => "cj/frame/y-up/1",
      "source_revision" => "synthetic-photo-frame/1",
      "rights" => "MIT",
      "limitation" => @limitation,
      "vertices" => vertices,
      "triangles" => @triangles,
      "features" => [
        %{
          "id" => "anchor",
          "role" => if(role == "dimension", do: "connector", else: role),
          "vertices" => [7],
          "quantity" => nil,
          "source" => "synthetic",
          "evidence_refs" => [evidence]
        },
        %{
          "id" => "width",
          "role" => "dimension",
          "vertices" => [0, 1],
          "quantity" => %{"quantity_kind" => "length", "unit" => "m", "value" => mm(width)},
          "source" => "synthetic",
          "evidence_refs" => [evidence]
        }
      ]
    }
  end

  defp steps(source, specs) do
    for {id, subjects, after_steps} <-
          specs ||
            [
              {"place-panel", ["panel", "mat-top", "mat-bottom", "mat-left", "mat-right"], []},
              {"connect-power", ["controller", "power-connector", "power-cable"],
               ["place-panel"]},
              {"close-backing", ["backing", "service-left", "service-right"], ["connect-power"]},
              {"mount-frame", ["mount"], ["close-backing"]}
            ] do
      %{
        "id" => id,
        "operation" => "urn:frameshift:fixture:#{id}",
        "after" => after_steps,
        "subjects" => Enum.sort(Enum.map(subjects, &[&1])),
        "parameters" => [],
        "tools" => [],
        "skills" => [],
        "conditions" => [],
        "warnings" => [%{"id" => "physical-qualification-required", "evidence_refs" => [source]}],
        "inspections" => [],
        "evidence_refs" => [source],
        "disposition" => "replacement-required",
        "recovery_template_ref" => nil
      }
    end
  end

  defp wording do
    %{
      "place-panel" =>
        "Inspect panel placement and the active opening. This synthetic procedure is not ready for execution.",
      "connect-power" =>
        "Inspect the controller, connector exit and complete power route. Cable bend and electrical checks remain unknown.",
      "close-backing" =>
        "Inspect backing removal and both counted service fasteners. Clearance and fastening limits remain unknown.",
      "mount-frame" =>
        "Inspect the mounting interface and service access. No load-bearing qualification is claimed.",
      "physical-qualification-required" =>
        "Physical checks, electrical limits, cable bend clearance and mounting strength require separate qualification."
    }
  end

  defp route_geometry(geometry, "power-cable") do
    ring = [[0, 0], [6, 0], [6, 62], [28, 62], [28, 68], [0, 68]]
    vertices = for z <- [0, 6], [x, y] <- ring, do: [mm(x), mm(y), mm(z)]
    caps = [[0, 1, 2], [0, 2, 5], [2, 3, 4], [2, 4, 5]]

    triangles =
      Enum.map(caps, fn [a, b, c] -> [a, c, b] end) ++
        Enum.map(caps, fn indices -> Enum.map(indices, &(&1 + 6)) end) ++
        Enum.flat_map(0..5, fn a ->
          b = rem(a + 1, 6)
          [[a, b, b + 6], [a, b + 6, a + 6]]
        end)

    geometry
    |> Map.put("vertices", vertices)
    |> Map.put("triangles", triangles)
    |> put_in(["features", Access.at(0), "vertices"], [9])
  end

  defp route_geometry(geometry, "mat-top") do
    feature = %{
      "id" => "active-opening-width",
      "role" => "dimension",
      "vertices" => [8, 9],
      "quantity" => %{"quantity_kind" => "length", "unit" => "m", "value" => mm(310)},
      "source" => "synthetic",
      "evidence_refs" => hd(geometry["features"])["evidence_refs"]
    }

    geometry
    |> Map.update!("vertices", &(&1 ++ [[mm(25), mm(0), mm(2)], [mm(335), mm(0), mm(2)]]))
    |> Map.update!("features", &(&1 ++ [feature]))
  end

  defp route_geometry(geometry, _), do: geometry

  defp check(subject, rules, assessments),
    do:
      doc("check-report", %{
        "subject_ref" => ref(subject),
        "requirements_ref" => nil,
        "rule_set_ref" => ref(rules),
        "assessment_set_ref" => ref(assessments),
        "status" => "unknown",
        "checks" => [],
        "unresolved_requirements" => []
      })

  defp doc(kind, body, procedures \\ false),
    do: %{
      "wire_version" => "1",
      "kind" => kind,
      "schema_ref" => "urn:conjunct:schema:domain:0.1",
      "required_profiles" =>
        if(procedures, do: ["cj/core/0.2", "cj/procedures/0.1"], else: ["cj/core/0.2"]),
      "body" => body
    }

  defp pose(position),
    do: %{
      "rotation" => Enum.map([1, 0, 0, 0, 1, 0, 0, 0, 1], &rational(&1, 1)),
      "translation" => Enum.map(position, &mm/1)
    }

  defp rational(n, d),
    do: %{
      "n" => Integer.to_string(div(n, Integer.gcd(n, d))),
      "d" => Integer.to_string(div(d, Integer.gcd(n, d)))
    }

  defp mm({:um, value}), do: rational(value, 1_000_000)
  defp mm(value), do: rational(value, 1000)

  defp ref(document) do
    {:ok, reference} = Wire.artifact_id(document)
    reference
  end

  defp encode(document) do
    {:ok, bytes} = Wire.encode_canonical(document)
    bytes
  end
end
