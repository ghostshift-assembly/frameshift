defmodule Frameshift.Illustration.EnclosureTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Frameshift.Illustration.Enclosure

  defp known(id, min, max) do
    %{
      id: id,
      state: :known,
      basis: :bounded,
      min_um: min,
      max_um: max,
      source: "independent-test-dimension"
    }
  end

  test "adjacent pockets use the maximum regional stack and identify its limiting region" do
    input = %{
      width: [known("display.width", 608_500, 609_100), known("lateral.margin", 10_000, 12_000)],
      height: [known("display.height", 355_000, 355_600)],
      regions: [
        %{id: "display", terms: [known("glass", 2_000, 2_000), known("panel", 14_000, 15_000)]},
        %{
          id: "electronics",
          terms: [known("board", 10_000, 13_000), known("connection", 3_000, 4_000)]
        }
      ]
    }

    assert {:ok, result} = Enclosure.derive(input)
    assert result.status == :conditional

    assert result.depth == %{
             min_um: 16_000,
             max_um: 17_000,
             limiting_regions: ["display", "electronics"]
           }

    assert result.width.min_um == 618_500
    assert result.width.max_um == 621_100
  end

  test "unknown dimensions never become a claimed minimum or zero contribution" do
    input = %{
      width: [known("display.width", 608_500, 609_100)],
      height: [known("display.height", 355_000, 355_600)],
      regions: [
        %{
          id: "display",
          terms: [known("body", 8_800, 9_800), %{id: "controller", state: :missing}]
        }
      ]
    }

    assert {:ok, result} = Enclosure.derive(input)
    assert result.status == :unknown
    assert result.depth.min_um == nil
    assert result.depth.max_um == nil
    assert result.depth.known_term_lower_bound_um == 8_800
    assert result.unresolved == ["controller"]
  end

  test "bad intervals, unsourced values and duplicate region identities refuse" do
    valid = %{
      width: [known("width", 1, 2)],
      height: [known("height", 1, 2)],
      regions: [%{id: "same", terms: [known("depth", 1, 2)]}]
    }

    assert {:error, _} = Enclosure.derive(%{valid | width: [known("width", 2, 1)]})

    assert {:error, _} =
             Enclosure.derive(%{valid | height: [Map.delete(known("height", 1, 2), :source)]})

    assert {:error, _} = Enclosure.derive(%{valid | regions: valid.regions ++ valid.regions})
    assert {:error, _} = Enclosure.derive(%{valid | regions: ["invalid"]})
    assert {:error, _} = Enclosure.derive(%{valid | width: valid.width ++ valid.width})

    assert {:error, _} =
             Enclosure.derive(%{valid | width: [Map.delete(known("width", 1, 2), :basis)]})
  end

  test "nominal values produce a scenario rather than a minimum thickness claim" do
    nominal = Map.put(known("rear-region", 14_900, 14_900), :basis, :nominal)

    input = %{
      width: [known("width", 1, 2)],
      height: [known("height", 1, 2)],
      regions: [%{id: "display", terms: [nominal]}]
    }

    assert {:ok, result} = Enclosure.derive(input)
    assert result.status == :nominal_scenario
    assert result.depth.min_um == nil
    assert result.depth.max_um == nil
    assert result.depth.known_term_lower_bound_um == 0
    assert result.depth.scenario_min_um == 14_900
    assert result.depth.scenario_max_um == 14_900
  end
end
