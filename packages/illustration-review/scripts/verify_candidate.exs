[review, fixture] = System.argv()

decode = fn path ->
  {:ok, value} = path |> File.read!() |> Conjunct.Wire.decode()
  value
end

packet = Path.join(review, "packet")
manifest = decode.(Path.join(packet, "manifest.json"))
semantics = decode.(Path.join(packet, "semantics.json"))
presentation = decode.(Path.join(review, "document/presentation-manifest.json"))
site = decode.(Path.join(review, "document/site-manifest.json"))
true = manifest["outcome"] == "completed"

true =
  manifest["scene_digest"] == Conjunct.Wire.blob_id(File.read!(Path.join(fixture, "scene.json")))

true =
  manifest["states_digest"] ==
    Conjunct.Wire.blob_id(File.read!(Path.join(fixture, "states.json")))

true = length(manifest["states"]) == 10

expected = %{
  "outline-width" => "608.8 mm",
  "outline-height" => "355.3 mm",
  "body-depth" => "9.3 mm",
  "active-width" => "596.736 mm",
  "active-height" => "335.664 mm"
}

for state <- semantics["states"] do
  true = state["scene_digest"] == manifest["scene_digest"]
  true = state["physical_status"] == "unknown"
  true = state["procedure_status"] == "unknown"
  true = state["limited"] == false

  true =
    Enum.map(state["subjects"], & &1["id"]) |> Enum.sort() == ["active-area", "panel-outline"]

  true = Enum.sum(Enum.map(state["subjects"], &map_size(&1["features"]))) == 7
  true = Map.new(state["readouts"], &{&1["id"], &1["display"]}) == expected
  true = Enum.all?(state["readouts"], &(&1["source"] == "sourced" and &1["rounding"] == "exact"))

  true =
    Enum.all?(
      state["steps"],
      &(&1["completion"] == "not-recorded" and length(&1["warnings"]) == 1)
    )
end

for file <- manifest["files"] do
  bytes = File.read!(Path.join(packet, file["path"]))
  true = byte_size(bytes) == file["byte_length"]
  true = Conjunct.Wire.blob_id(bytes) == file["digest"]
end

receipt = presentation["pages"]["frame-review"]
true = length(receipt["blocks"]) == 10
true = receipt["constraints"]["reader_mode"] == "file"

true =
  Enum.all?(
    receipt["blocks"],
    &(&1["variant"]["runtime"] == [] and &1["variant"]["state"] == "fallback")
  )

html = File.read!(Path.join(review, "document/index.html"))
false = Regex.match?(~r/<script\b|\bon[a-z]+\s*=|<iframe\b|foreignObject/i, html)
true = String.contains?(html, "src=\"assets/")
true = String.contains?(html, "Preliminary source candidate")
false = String.contains?(html, "A generated view of a synthetic Photo frame")
true = String.contains?(html, "Minimum wood depth UNKNOWN")
for {_id, display} <- expected, do: true = String.contains?(html, display)

for file <- site["files"] do
  bytes = File.read!(Path.join([review, "document", file["path"]]))
  true = Conjunct.Wire.blob_id(bytes) == file["digest"]
end

for app <- [:doc_shell, :conjunct_wire, :conjunct_illustration],
    do: true = Application.spec(app, :mod) == []

observation = %{
  "schema_version" => "frameshift/illustration-observation/1",
  "status" => "passed-source-candidate-static-join",
  "scene_digest" => manifest["scene_digest"],
  "states_digest" => manifest["states_digest"],
  "renderer_digest" => manifest["renderer_digest"],
  "counts" => %{"states" => 10, "occurrences" => 2, "features" => 7, "readouts" => 5},
  "expected_readouts" => expected,
  "packet_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(packet, "manifest.json"))),
  "presentation_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(review, "document/presentation-manifest.json"))),
  "site_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(review, "document/site-manifest.json"))),
  "scope" =>
    "Nominal source envelope; detached active area; complete enclosure and installed depth unknown; no hardware or baseline qualification",
  "review_approval" => "not-granted",
  "browser_inspection" => "not-executed"
}

{:ok, bytes} = Conjunct.Wire.encode_canonical(observation)
IO.puts(bytes)
