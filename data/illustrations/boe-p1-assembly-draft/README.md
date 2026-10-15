# BOE P1 layered assembly draft

This is a calculated enclosure draft, separate from the two-plane panel source
inspection. It contains 14 subjects: four timber walls, four rebate-lip strips,
protection glass, four passe-partout strips and the BOE P1 nominal body envelope.
The timber walls end at the lip underside; the two timber regions share a
boundary without overlapping volume. No electronics, rear cover, mounts or
fasteners are fabricated while those selections are missing.

[inputs.json](inputs.json) contains explicit provisional design choices in integer
micrometres. It selects 2 mm glass, 1.4 mm mat, 30 mm mat border, 1 mm aperture
overlap, 8 mm timber wall, 2 mm front lip, 4 mm rebate overlap, 0.5 mm fit per side,
0.5 mm front gap and 1 mm rear gap. These are editable choices, not purchased
specifications. The 14.9 mm planning panel depth is a nominal regional scenario,
not the complete mated envelope. The existing panel record and profile are unchanged.

The mat opening is 594.736 × 333.664 mm. Its footprint is 654.736 × 393.664 mm.
The cavity uses the larger of that footprint and the source panel upper bounds,
plus both fit margins. Outside wood is therefore 671.736 × 410.664 mm. The
shown depth follows the planning stack: 2 + 2 + 0.5 + 1.4 + 14.9 + 1 = 21.8 mm.
The wall body is 19.8 mm and the separate lip is 2 mm. The complete installed
minimum remains **unknown**; missing electronics, full panel/mating envelope,
retention, backing, wall mounting and service clearances remain explicit terms.
The supplied front choices are retained as design terms in the enclosure assessment.

The centred aperture is a design placement while the active-area datum is
unresolved. The panel is a nominal envelope, not detailed manufacturer CAD.
The renderer's current opaque profile shows the glass as a solid inspection
surface with its real draft thickness and neutral paper-style tone. It does not
simulate transmission or refraction. `assembled-section` explicitly hides glass;
`full-stack` includes it. Layer inspections expose the rebate, glass, mat opening
and panel separately. Monochrome is the default, with material colour as an
explicit illustration palette rather than a sourced finish.

`Frameshift.Illustration.AssemblyDraft` owns the product recipe. Regenerate
[current scene/state carriers](current/scene.json) with
`packages/illustration-review/scripts/assembly_draft.exs`: supply the installed
producer descriptor, retained panel dimension record, input file and a new
destination. The producer owns all rendering and motion; DocShell checks the
same original bindings and exported SVG assets. The
[acceptance values](acceptance.json) are independent numerical expectations for
this input set. Run the existing verifier with explicit review, fixture and
acceptance-file arguments. Changing the input set requires new carriers and
reviewed expectations.

The [static observation](evidence/observation-macos-arm64.json) records 13 states,
14 subjects, 57 features and six exact readouts, plus real file hashes and
script-free document admission. Nine consumer tests cover derived dimensions,
input refusal, source/design distinction and original-byte replay. Native
inspection is recorded separately. These software checks establish no complete
CAD, hardware fit, minimum depth, optical behavior, mounting strength or execution
readiness. Full passing packets remain temporary; inputs and manifests are retained.

The [native control observation](evidence/native-controls-observation.json)
records the version-2 producer and corrected AppKit inspector for these same
carriers. All 57 features retain separate node IDs, including repeated timber
and mat labels. Selecting top timber depth resolves to `wood-wall-top#depth`;
reduced motion, pause and the `3/8` checkpoint preserve all six exact readouts.
Details shows original bindings and each subject's limitations. The Desktop
delivery is `Frameshift Assembly Review.app`. These selected automated native
observations grant no complete viewer, manual accessibility or hardware claim.

The [2026-10-15 producer refresh](evidence/producer-refresh-2026-10-15.json)
replays these unchanged original scene/state carriers with the later producer.
All 44 packet files are byte-identical to the retained earlier manifest; all
13 states preserve 14 subjects, 57 features, six exact readouts and unknown
physical/procedure status. The
[new run manifest](evidence/producer-refresh-run-manifest-2026-10-15.json) binds
the executable and original inputs; its
[storage result](evidence/producer-refresh-storage-result-2026-10-15.json)
records success and closed processes. Full-stack, timber-rebate and mat-opening
PNGs were inspected from files; no GUI app was opened. The full-stack image is
on Desktop as `Frameshift Layered Assembly 2026-10-15.png`. This checks current
producer generation; it does not repeat document-adapter or installed native
qualification.
