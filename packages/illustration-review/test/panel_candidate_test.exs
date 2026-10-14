defmodule Frameshift.Illustration.PanelCandidateTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Frameshift.Illustration.{Fixture, PanelCandidate}

  @root Path.expand("../../..", __DIR__)
  @descriptor Application.app_dir(:conjunct_illustration, "priv/profile.json")

  test "the existing software fixture keeps its original bytes" do
    profile = @descriptor |> File.read!() |> Conjunct.Wire.blob_id()
    original = File.read!(Path.join(@root, "data/illustrations/synthetic-photo-frame/scene.json"))
    assert Fixture.bundle(profile) == original
  end

  test "BOE dimensions and explicit unknown enclosure survive scene construction" do
    {:ok, record} =
      @root
      |> Path.join("data/illustrations/boe-mv270qhm-n40-p1/dimensions.json")
      |> File.read!()
      |> Conjunct.Wire.decode()

    profile = @descriptor |> File.read!() |> Conjunct.Wire.blob_id()
    scene = PanelCandidate.bundle(profile, record)
    {:ok, parsed} = Conjunct.Wire.decode(scene)
    assert length(parsed["nodes"]) == 2
    refute Enum.any?(parsed["nodes"], &(&1["material"] == "timber"))
    panel = Enum.find(parsed["nodes"], &(&1["id"] == "panel-outline"))
    asset = Enum.find(parsed["assets"], &(&1["ref"] == panel["asset_ref"]))
    {:ok, geometry} = Conjunct.Wire.decode(asset["bytes"])

    assert Enum.at(geometry["vertices"], 7) == [
             %{"n" => "761", "d" => "1250"},
             %{"n" => "3553", "d" => "10000"},
             %{"n" => "93", "d" => "10000"}
           ]

    assert {:ok, enclosure} = PanelCandidate.enclosure(record)
    assert enclosure.status == :unknown
    assert enclosure.depth.min_um == nil

    for term <- [
          "complete-mated-panel.depth",
          "controller-and-placement",
          "backlight-driver",
          "protection-glass",
          "passe-partout",
          "retention",
          "mated-connectors",
          "wall-mount"
        ],
        do: assert(term in enclosure.unresolved)

    {:ok, states} = scene |> PanelCandidate.states() |> Conjunct.Wire.decode()
    assert states["scene_digest"] == Conjunct.Wire.blob_id(scene)
    assert hd(states["states"])["theme"] == "monochrome"
  end
end
