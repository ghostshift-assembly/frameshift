[review] = System.argv()

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
inputs = Path.expand("../../../data/illustrations/synthetic-photo-frame", __DIR__)

true =
  manifest["scene_digest"] == Conjunct.Wire.blob_id(File.read!(Path.join(inputs, "scene.json")))

true =
  manifest["states_digest"] == Conjunct.Wire.blob_id(File.read!(Path.join(inputs, "states.json")))

true = length(manifest["states"]) == 15
true = length(semantics["states"]) == 15
expected_steps = ~w(place-panel connect-power close-backing mount-frame)

for state <- semantics["states"] do
  true = state["scene_digest"] == manifest["scene_digest"]
  true = state["physical_status"] == "unknown"
  true = state["procedure_status"] == "unknown"
  true = length(state["subjects"]) == 16
  true = Enum.sum(Enum.map(state["subjects"], &map_size(&1["features"]))) == 33
  true = length(state["readouts"]) == 4

  true =
    Enum.find(state["readouts"], &(&1["id"] == "active-opening-width"))["display"] == "310 mm"

  true = Enum.map(state["steps"], & &1["id"]) == expected_steps

  true =
    Enum.all?(
      state["steps"],
      &(&1["completion"] == "not-recorded" and length(&1["warnings"]) == 1)
    )

  true = state["limited"] == false
end

for file <- manifest["files"] do
  bytes = File.read!(Path.join(packet, file["path"]))
  true = byte_size(bytes) == file["byte_length"]
  true = Conjunct.Wire.blob_id(bytes) == file["digest"]
end

receipt = presentation["pages"]["frame-review"]
true = length(receipt["blocks"]) == 15
true = receipt["constraints"]["reader_mode"] == "file"

true =
  Enum.all?(
    receipt["blocks"],
    &(&1["variant"]["runtime"] == [] and &1["variant"]["state"] == "fallback")
  )

html = File.read!(Path.join(review, "document/index.html"))
false = Regex.match?(~r/<script\b|\bon[a-z]+\s*=|<iframe\b|foreignObject/i, html)
true = String.contains?(html, "src=\"assets/")
true = String.contains?(html, "310 mm")
true = String.contains?(html, "mounting strength require separate qualification")

for app <- [:doc_shell, :conjunct_wire, :conjunct_illustration] do
  true = Application.spec(app, :mod) == []
end

for file <- site["files"] do
  bytes = File.read!(Path.join([review, "document", file["path"]]))
  true = Conjunct.Wire.blob_id(bytes) == file["digest"]
end

observation = %{
  "schema_version" => "frameshift/illustration-observation/1",
  "status" => "passed-selected-static-join",
  "scope" =>
    "Synthetic software fixture; no physical, native-window, browser, assistive or complete-platform qualification",
  "scene_digest" => manifest["scene_digest"],
  "states_digest" => manifest["states_digest"],
  "renderer_digest" => manifest["renderer_digest"],
  "profile" => manifest["profile"],
  "platform" => manifest["platform"],
  "metrics" => manifest["metrics"],
  "states" =>
    Enum.map(
      manifest["states"],
      &Map.take(&1, ~w(id state_digest svg png crop crop_region limited))
    ),
  "packet_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(packet, "manifest.json"))),
  "presentation_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(review, "document/presentation-manifest.json"))),
  "site_manifest_digest" =>
    Conjunct.Wire.blob_id(File.read!(Path.join(review, "document/site-manifest.json"))),
  "elixir" => System.version(),
  "otp" => :erlang.system_info(:otp_release) |> to_string(),
  "counts" => %{"states" => 15, "occurrences" => 16, "features" => 33, "readouts" => 4},
  "review_approval" => "not-granted",
  "browser_inspection" => "not-executed-by-this-check"
}

{:ok, bytes} = Conjunct.Wire.encode_canonical(observation)
IO.puts(bytes)
