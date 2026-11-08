# Thruster mounting, full animation reference and working V02 study

This checkpoint delivers the native liquid-thruster clearance/service-underlay correction and restores high-quality review rendering. It also provides a separately editable Thetazine mechanical study with an actual **64-frame working body loop** proven in the native client. **The new body remains a refinement candidate.** The owner explicitly said the models need further development/refinement but look like they are working; that is not final art approval.

## Platform opening and fixed interfaces

The previous masks required foundation beneath the entire nominal body. The new liquid mounts keep **three fore rows** supported and require empty space beginning inside the former full-body footprint. Hydrogen and Thetazine both accept last foundation row **0** and reject the six other probed rows -3..3. The supported origin and fixed pipe row remain on foundation. All four actual baseline/corrected sites are legal; 14 independent empty-site native probes pass.

Hydrogen keeps 4×4 grid/selection and the same west/east cells `(-1.5,-.5)/(1.5,-.5)`, with a fore collision box `(-1.85,-1.85)..(1.85,0)`. Thetazine keeps its 5×5 half-tile grid/selection and `(-2,-1)/(2,-1)` cells, with `(-2.15,-2.35)..(2.15,0)`. Both collision boxes contain `(0,0)`, as Factorio requires. The initial origin-excluding study failed native load and is rejected. A deeper unsupported-origin layout also failed native placement and was not promoted.

Both unchanged input/filter/connection definitions and exact native cap gates `pipe-4`/`pipe-1` are preserved. Actual connected pipes end at the expected centers; disconnected views remove the conditional cap joins. Selection/grid and all fuel/thrust/performance/servicing definitions are retained. Sealed fusion mounts keep their earlier rules pending their own source/model contract.

The new `platform-service-underlay` is a separate static, always-drawn **floor** visual referencing the installed native machinery PNG. It does not copy Wube art into the mod. Its fore anchor is fitted to the donor/target mount heights. Native 2.1's exposed ThrusterGraphicsSet does not list the legacy integration-patch fields, so the exercised working-visualisation layer is explicit. The future source-authored underlay is modeled and rendered separately in the V02 study.

This uses native collision/buildability clearance, not a runtime script that deletes tiles from existing saves. Construction requires a correctly cleared notch. The fixture paints only its disposable platform; no normal profile/save is scanned, carved or migrated.

## Platform edge variation correction

The review launcher used `--low-vram`; the actual log reported **medium** quality even though the profile requested high. Normal-quality rerenders restore the varied side machinery. The launcher now defaults to high and omits that flag; `-LowVram` is explicit diagnostic-only use and cannot establish final appearance acceptance. Video-memory residency can remain low. The actual platform source still declares 32 side overlay and 32 background choices; no platform tile/transition art or definition is changed.

Earlier native images from the reduced mode are historical evidence, not high-quality visual approval. Existing exact source-cell/geometry/interface proofs remain valid within their stated scopes. Future final appearance reviews, including earlier family gates, must use the corrected mode. The accidental one-tile gaps between initial test pads were a separate fixture layout mistake; the final review uses one continuous deck with intentional engine notches.

## Supplied complete vanilla package

`reference-package-audit.json` fully verifies all **17 files** (18 ZIP entries including the directory), PNG decode and CRC from supplied ZIP SHA-256 `0670bc10c11800e89beb4d39dd692dc32a4d3ea4b967b742559b54a8d7967791`. It identifies 64 body frames, 64 independent light frames, static machinery underlay, four conditional pipe overlays, separate flame EffectTexture, two 60-frame smoke/glow sheets used by three plume visualisations and separate remnants. Body/light page count is not emitter count or mechanical motion.

Use actual data-stage resolved shifts: body `(0.046875,1.78125)`, underlay `(0.0625,.734375)`, light `(0,3)`. Do not half-scale descriptor shifts a second time. The numerical source audit and original local package remain distinct from our newly authored meshes; original Wube sheets/private reference contacts are not committed as mod-owned art.

## Authored 64-frame source and actual export

`art/source-to-3d/space-platform-engines/thetazine-thruster/v02-animation-study/` contains a packed editable Blender source, actual animated GLB, exercised builder, source manifest, exact source-capture archive and separate beauty/emission atlas pages. The explicit provenance is the prior verified Thetazine candidate and the measured vanilla body-alpha lip trajectory. A six-harmonic periodic fit removes integer alpha-bound jitter. This is an authored **one-degree-of-freedom interpretation**, not exact recovered vanilla geometry or twelve independently operating mechanisms.

The new mechanism has twelve rigid overlapping **closed** petal meshes, tangential throat hinges, attached retaining rails/thermal liners and twelve articulated actuator rods. The rest structure and both source sockets remain fixed. A static U-shaped under-deck assembly is in a separate source collection. Existing shared cast/tank/brass/steel/bell PBR maps retain their provenance; no renamed-map uniqueness claim.

Actual GLB: **439 meshes / 80,784 triangles / 18 embedded images / seven materials / one 48-channel animation**. Raw finite/degenerate/UV/normal/image checks pass. Oriented triangle, UV and material correspondence passes at the correct first frame. All 64 native-source/imported moving-part bounds plus wrap and fixed socket samples agree within **4.7684e-7** model units. Twelve petals have zero nonmanifold edges. Source pose 65 exactly wraps pose 1. Actual GLB front/oblique/rear/clay views were inspected.

Exporter defaults initially split the scene into 24 clips, and an inspector initially sampled the wrong imported FPS/frame. Those checks failed and were repaired: scene export explicitly disables splitting, and inspection uses 30 fps/source/import frames 1..65. Thresholds were not weakened.

All **128** source beauty/emission PNGs fully decode, have clear alpha borders and exact matching channel alpha. All **64 body alpha masks differ**, while the fixed fore-mount alpha is identical. Every one of 128 atlas cells matches its exact source RGBA. The deterministic capture ZIP has all 128 PNGs plus its receipt, CRC/hash checked. Source rendering is local Blender, 16 CPU samples/two threads. No Actions.

## Actual native working cycle and limits

The high-quality native fixture loads the actual new body/emission atlas and separately rendered underlay into a review-only real thruster prototype with fixed caps. An unfuelled cold-clock trial held frame zero; it is explicitly rejected as working-loop proof. A disposable platform route and propellant were then supplied solely to exercise active graphics, with no consumption/thrust/behavior assertions.

A temporary six-bit counter shares the body's exact animation layers/timing. The 64 screenshots decode **26..63,0..25**, exactly sequential modulo 64, so every body rectangle was actually displayed. Both ordinary pipe joins remain exact. `native-working-validation.json` hashes all 64 originals; eight key-pose originals, the key-pose board and actual native loop are committed. Full originals remain local and can be reproduced. Counter and caption are review-only. The GIF is actual native capture; the separately named source GIF is Blender output.

This proves the native **body clock**, not independent native glow-phase decoding, final shadow/exhaust alignment or complete conditional state acceptance. New body and source-authored underlay remain review-only; ordinary mod source receives the mounting/service-underlay and review-launcher corrections. The existing normal save/profile is not modified or released.

## Resume and production gates

Read `visual-review.json`, `CHECKPOINT.json` and the asset's `source-export-plan.json`. Required final score remains 4/5; current refinement/full-parity scores are 3/5. Refine silhouette/construction transitions, plate detail, material placement and wear first. Then complete animated projected shadows, idle/effective frame counts, native glow/body phase, source-derived flame/plume anchors, conditional states and the real late graphics import. Never call the seven-frame light-only hydrogen lane or the old two-frame Thetazine body full mechanical parity. Apply the full component graph to each thruster family independently; preserve sealed fusion port policy.

Repeat local source audit with `audit_package.py --zip <supplied ZIP> --out <scratch>`. Build a fresh candidate using Blender 5.0.1 `--factory-startup --background --threads 2 --python-exit-code 12 --python <build_model.py> -- --source <verified Thetazine V01 native> --reference-audit <reference-package-audit.json> --out <fresh-dir>`. Run `audit_animation_glb.py`, Blender `verify_animation.py` and `verify_study_geometry.py`, then `render_study_export.py`; read status/results and view actual output. Run `capture_animation.py` resumably from matching source/script receipts and `package_capture.py` for exact-cell/archive proof.

The portable animation-native recipe is byte-compared to the exercised actual data-stage Lua, working control and six graphics inputs. After preparing the mounting profile, run `prepare_animation_native.py --study <study-dir> --review-root <profile> --registration docs/art/thetazine-thruster-v01/interface-validation.json --working`; launch normally and inspect with `check_working_animation.py --study <study-dir> --review-root <profile>`. Use a fresh profile/base data file when adding the pilot, because duplicate pilot injection is refused. `prepare_review.py --repo <repo> --review-root <scratch> --baseline <baseline-prototypes.json>` reproduces the mounting fixture. Launch with `tools/art/native_visual_review/launch.ps1 -ReviewRoot <scratch>` and use `check_native.py` for the targeted native placement/art checks. Do not use `-LowVram` for acceptance. Resume verified phases; do not launch duplicate existing captures.

Issue #13 and the broader model goal remain open. Condenser/reactor/lumberyard native-source recovery and every other family gate remain separate work. Existing A02 workers are preserved.
