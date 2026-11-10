# Water Purifier MH7 — native Blender fluid FX V5 receipt

**Status:** technically verified Blender/GLB and real 256px sprite motion; *awaiting owner visual approval and actual Factorio 2.1 fluidbox/native placement*. This is a real saved model revision, not image-generated reference art.

- Authoritative source revision: `406132008a814911590fbcc9ff799f2a2c1016b9` on `mrcalzon02/Tech-Priests` (FMPL v0.4.1, exact full commit pin).
- Production controller: private `mrcalzon02/Dens-Mortis`, self-hosted Windows `OLD-CORE30-homebrew`, single `fmpl-super-greeble` job.
- [Successful native Blender/GLB/render run #42747904758](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42747904758) on controller commit `9e24010ccad713efb5b6e807389ef799c0f98a57`.
- Retained GitHub Actions artifact **13731882196**, `dens-mortis-worker-42747904758-1`, retained 14 days by the private runner. **Archive into permanent asset storage before expiry.** Its ZIP contains the editable `water-purifier-fmpl-super.blend`, `water-purifier-fmpl-super.glb`, 512px native proof renders, eight working frames, six RGBA 64/128/256 atlases and independent QA receipts.
- Immutable V04 Water Purifier source SHA-256: `5d03419b7861278ed21f89cb08686d79d5ebb80d886d42ed265d866ea7f08c30`.
- Final **editable .blend** SHA-256: `62dac55e96d2f63d5f33124b7f9d69508a24e878bcad6ddd67cd3f965e466e7d`.
- Final **GLB** SHA-256: `6a630a13a14f1c109f677e88cba5fb44eebdc5d38e1481c5c0ddcce0e589e332`.
- Pinned, previously independently verified FMPL effects v1.0.1 native Blender library SHA-256: `0aec2d100331ba2aa390ed17269dd5f245e3bd5269bc8caa233cf4c83f5f7da3`. The FMPL import adapter requires explicit historical version **1.0.1** and verifies material identity and source hash even as newer FX versions are developed elsewhere.

## Verified construction

- Preserved **50 original MH7 meshes**, **136 prior process meshes**, one canonical 45° camera and both original full-bore fluid couplings, without rewriting source.
- **243 additional live process/detail meshes**, including two enlarged front glass witness canisters, four glass-cored input/output sample branches and actual pipe paths to pre-existing feed/discharge equipment; no extra gameplay fluidbox added.
- Two Blender **animated sloshing fluid surfaces**, two surface foam crests, **24 internally modeled moving bubbles**, **eight moving glass-line fluid tracer meshes**, and four nozzle-anchored animated steam lobes.
- GLB independently reimported **418 meshes**. Native Blender fresh reopen and SHA-256 checks passed.
- Idle plus **eight real keyed Cycles render frames** at 8 fps, six alpha RGBA atlases at 64/128/256. Reusable fluid keyframes authored as **16 samples plus a closing frame 97**; automatic simulations/cache avoided.
- New independent `tools/fmpl/effects/verify_sprite_motion.py` excluded the steam region and measured sprite differences in **both forward canister regions** at actual 256px: raw-water **132** peak visibly changed pixels, clarified-water **138** peak, over a required minimum of six. This replaces the earlier insufficient “keyframes exist therefore motion is visible” assertion.
- Native visual source and proof SHA manifests are in `fmpl-super-greeble/super-greeble-build.json`, `super-greeble-verification.json`, `sprites/fluid-motion-visible-qa.json`, `sprites/capture.json` and `sprites/super-greeble-qa.json` inside artifact.

## Scope and next handoff

This is **not** a published or installed Factorio game prototype. The two model-space X±1.5 tile pipe-mouths remain *provisional* until measured against the actual native fluidbox cells and checked in-game. Do not approve fluidbox, player-selected sprite placement, or appearance solely from Blender verification. Before reusing the sample vessel or wave/bubble/nozzle FX on an Electrolyzer, add actual measured component anchors and a clean append/readback to the metallic-hydrogen shared-parts registry; do **not** silently promote this whole Water Purifier as one generic verified component.

Use `tools/fmpl/effects/fluid_steam_fx.py` and `tools/fmpl/effects/verify_sprite_motion.py` from the exact source commit for reproducible next-pass construction. The next ordered industrial machine is the 3×4 Electrolyzer, with separately supported hydrogen and oxygen outputs.
