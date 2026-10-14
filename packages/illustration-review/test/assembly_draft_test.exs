defmodule Frameshift.Illustration.AssemblyDraftTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Frameshift.Illustration.AssemblyDraft
  @root Path.expand("../../..", __DIR__)
  @descriptor Application.app_dir(:conjunct_illustration, "priv/profile.json")

  defp inputs do
    {:ok, record} =
      @root
      |> Path.join("data/illustrations/boe-mv270qhm-n40-p1/dimensions.json")
      |> File.read!()
      |> Conjunct.Wire.decode()

    {:ok, inputs} =
      @root
      |> Path.join("data/illustrations/boe-p1-assembly-draft/inputs.json")
      |> File.read!()
      |> Conjunct.Wire.decode()

    {record, inputs}
  end

  test "draft wood follows the stack, outline bound and design footprint" do
    {record, inputs} = inputs()
    assert {:ok, d} = AssemblyDraft.derive(record, inputs)
    assert d.shown_depth == 21_800
    assert d.outer_w == 671_736
    assert d.outer_h == 410_664
    assert d.opening_w == 594_736
    assert d.enclosure.status == :unknown
    assert d.enclosure.depth.min_um == nil
    assert "controller-and-placement" in d.unresolved
    assert "complete-mated-panel.depth" in d.unresolved
    thicker = put_in(inputs, ["values", "glass_thickness_um"], 3_000)
    assert {:ok, changed} = AssemblyDraft.derive(record, thicker)
    assert changed.shown_depth == d.shown_depth + 1_000
    assert changed.outer_w == d.outer_w
    narrow = put_in(inputs, ["values", "mat_border_um"], 5_000)
    assert {:ok, changed} = AssemblyDraft.derive(record, narrow)
    assert changed.cavity_w == 610_800, "Panel upper bound and two fit margins dominate"
  end

  test "missing, noninteger and impossible draft inputs refuse without guessed defaults" do
    {record, inputs} = inputs()
    assert {:error, :invalid_assembly_draft} = AssemblyDraft.derive(%{}, inputs)

    for changed <- [
          update_in(inputs, ["values"], &Map.delete(&1, "glass_thickness_um")),
          put_in(inputs, ["values", "wood_lip_um"], 0),
          put_in(inputs, ["values", "planning_panel_depth_um"], 9_300),
          put_in(inputs, ["values", "mat_thickness_um"], 1.4),
          put_in(inputs, ["values", "rebate_overlap_um"], 30_000)
        ] do
      assert {:error, :invalid_assembly_draft} = AssemblyDraft.derive(record, changed)
    end
  end

  test "all drafted layers retain exact bindings, separate source basis and closed unknowns" do
    {record, inputs} = inputs()
    profile = @descriptor |> File.read!() |> Conjunct.Wire.blob_id()
    assert {:ok, scene} = AssemblyDraft.bundle(profile, record, inputs)
    {:ok, parsed} = Conjunct.Wire.decode(scene)
    assert length(parsed["nodes"]) == 14
    ids = Enum.map(parsed["nodes"], & &1["id"])
    assert "glass" in ids
    assert "mat-top" in ids
    assert "wood-wall-top" in ids
    assert "wood-lip-top" in ids
    refute "controller" in ids

    features = fn id ->
      node = Enum.find(parsed["nodes"], &(&1["id"] == id))
      asset = Enum.find(parsed["assets"], &(&1["ref"] == node["asset_ref"]))
      {:ok, geometry} = Conjunct.Wire.decode(asset["bytes"])
      geometry["features"]
    end

    assert Enum.all?(features.("panel"), &(&1["source"] == "sourced"))
    assert Enum.all?(features.("glass"), &(&1["source"] == "synthetic"))
    wall_depth = Enum.find(features.("wood-wall-top"), &(&1["id"] == "depth"))
    assert wall_depth["quantity"]["value"] == %{"n" => "99", "d" => "5000"}
    {:ok, states} = scene |> AssemblyDraft.states() |> Conjunct.Wire.decode()
    assert states["scene_digest"] == Conjunct.Wire.blob_id(scene)
    assert hd(states["states"])["theme"] == "monochrome"
    assert hd(states["states"])["step"] == nil
    section = Enum.find(states["states"], &(&1["id"] == "assembled-section"))
    refute "glass" in section["isolation"]

    assert File.read!(
             Path.join(@root, "data/illustrations/boe-p1-assembly-draft/current/scene.json")
           ) == scene

    assert File.read!(
             Path.join(@root, "data/illustrations/boe-p1-assembly-draft/current/states.json")
           ) == AssemblyDraft.states(scene)
  end
end
