# Water Purifier MH7 — V11 enlarged color-separated front tanks and clear side bores

**State:** Blender-native construction and visual rendering verified; **Factorio 2.1 fluidbox/game integration and owner approval remain unverified**.

## Reproducible source and artifact

- Canonical FMPL source in mrcalzon02/Tech-Priests main at full pin `9ab8ad9c5edb2e9b51b802ff6a3654a77cd25653` (FMPL v0.4.1).
- Dens Mortis private self-hosted OLD-CORE30 worker: successful [run #42774155631](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42774155631), dispatch commit `514e6d7aeaca1e621e4f9774ae82d2ba66c85236`.
- Downloadable run artifact ID `13743666109`: `dens-mortis-worker-42774155631-1`, 27,895,121-byte ZIP. It contains the **editable native Blender .blend**, independent GLB, 512px actual Cycles idle/working images, 8 true animation frames, 64/128/256 RGBA static and working atlases (6 sheets), logs and receipts. The Actions artifact has limited retention; preserve it in permanent asset storage before expiry.
- Verified Blender .blend SHA-256: `0e600e9f704e76a60f291f1bc97798597487b40cff04c47af700d4a7d71b62ed`.
- Verified exported GLB SHA-256: `391a3bf6d07b100c4ca207b28ff5905f2989dd6c44fd44ae69f50224cd53ed4d`.
- Protected original process input .blend SHA-256: `5d03419b7861278ed21f89cb08686d79d5ebb80d886d42ed265d866ea7f08c30`.

## Physical changes

- **Two larger front glass witness vessels**: outside diameter **0.426 tile** (previous .352; **+21.0%**), body height **0.712 tile** (previous .611; **+16.5%**), spaced across x=-.17 and x=+.53, 3x3 tile footprint retained.
- Distinct real source-preserving material derivatives. Raw/input water has procedural olive-amber ramp endpoint RGB `[0.5520,0.31625,0.05405]`; clean/output water uses vibrant cyan-blue `[0.04025,0.6670,1.0]`. Canonical 28 FMPL effects materials not changed. Separate colorway materials are applied to the actual water mesh, animated surface, bubbles and flow tracers.
- Protected original 50 MH7 meshes and 136 V04 process meshes unchanged. Eight offending original structural meshes are retained and render-hidden. Replacement geometry splits four chassis rail segments around the side pipe openings, redirects eight manifold shoe/foot supports outside the bores, and boolean-carves the two derived concrete foundation layers. Existing authentic open-bore/boiler-style flange components and eight bolts per side remain untouched.
- The two machine-side model-space interface joints are still centered on x=-1.5 and x=+1.5, Blender y=0, z=.36 with 0.49-tile nominal ID. No extra native fluidbox port was created.
- New derivative adds **268** Blender detail/FX meshes; independent GLB import recovers **432** meshes. Exactly one original 45° fixed camera, eight 8-fps working frames, six true RGBA atlases.

## Independent acceptance results

- The native Blender independent verifier cast **74 side-bore rays total** (37 per side): **0 structural collisions**. A separate offline intersection test against the actual GLB triangles independently confirmed **0/37 blocked rays in each side bore**.
- For comparison, the previous verified V10 GLB produced **34/37 blocked test rays on BOTH sides**, intersecting chassis rails, foundation, cast footings and braced manifold shoes. These were real solid geometry, not shader artifacts.
- Native rendering shows clearly larger two sample tanks and a strong warm-versus-cool visual separation. The front 256px animation retained real motion: **85 RAW** and **69 CLEAN** maximum visibly changing pixels in the two sample regions, above the six-pixel gate.
- Previous verified nozzle and asymmetric volume steam remain intact, with **75 idle / 82 working** real Cycles visible steam pixels and 47 in the working high-rise crop. Both original cone plumes and the original solid nozzle cap remain hidden in the derivative; the hollow visible vent remains preserved.
- Existing 27 real PBR maps are still packed in editable Blender, native proof images have transparent alpha, source hashes and camera unchanged. `FMPL_SUPER_GREEBLE_RESULTS.json`, `super-greeble-build.json`, `super-greeble-verification.json`, `steam-visibility-native-qa.json` and `sprites/fluid-motion-visible-qa.json` are the authoritative readback receipts inside the Actions artifact.

## Integration boundary

**Blender port-bore geometric clearance is NOT native Factorio fluidbox connection-cell verification.** Runtime prototype declarations, sprite shifts and actual connected pipe behavior still need a Factorio 2.1 installation test. The model remains a technically completed, visually reviewable V11 candidate rather than a published game prototype. The production direction remains a single fixed 45° camera, not four arbitrary rotations. No new runner workflow or model download was used.

## Source functions for later machines

- `tools/fmpl/effects/fluid_steam_fx.py` supplies larger animated glass witness canisters and source-safe FMPL water colors.
- `tools/fmpl/production_smoke/pipe_bore_clearance.py` produces actual split-and-carved machine geometry and inspects the rendered open bores by Blender ray tests.
- `tools/fmpl/production_smoke/verify_super_greeble.py` independently reopens Blender and GLB, checks sample dimensions and shader identities, and re-tests actual port geometry.
