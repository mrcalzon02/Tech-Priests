# Water Purifier V13 — slow heavy stirrer, active central water, angled green console

**Technical status: verified editable Blender source, independent GLB readback, actual Cycles visual isolation, and 8-frame sprite export.** Owner visual approval and native Factorio 2.1 fluidbox/game integration are **not yet performed**.

## Immutable execution evidence

- Source code exact commit in Tech-Priests main: `a89de584fe85176d56dd6787c2886e2d7b3eb36c`; FMPL version `0.4.2` as declared by its live canonical manifest.
- Executed once after two diagnosed failures using the existing Dens Mortis single-job self-hosted Windows runner `OLD-CORE30-homebrew`: [successful job #42854827403](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42854827403), request/dispatch commit `136ad981db6d89e4e3549deb968fd3819694261f` and mode `fmpl-super-greeble`.
- Exact GitHub Actions ZIP artifact **13781794050**, `dens-mortis-worker-42854827403-1` (30,469,584 bytes). Contains the true editable source `water-purifier-fmpl-super.blend`, independent animated GLB, 512px native idle and active PNG, Cycles effect-isolation renders, 8 actual 256px working frames, 6 RGBA 64/128/256 atlases, QA receipts and logs. Archive before GitHub Actions artifact expiry.
- Verified native `.blend` SHA-256: `971087c8a03e5b91ab6f70afa2a1abe13f5d0cd231b9983969bd509ed10330be`.
- Verified `.glb` SHA-256: `a3f019d2442a6bdd3d241049cf27de7ca8bab4fe66ae96e894f74a7d2f32e9bf`.
- The V13 derivative retains the original 50 MH7 meshes and 136 original process meshes; 368 authored derivative detail/FX meshes and 526 successful GLB mesh readback. A single canonical 45-degree fixed Factorio export camera is retained.

## Actual Blender modeling changes

- Heavy central mixer rate reduced to **25%** of the original angular speed: native rotor at frame 1 `0.0000 rad`, frame 25 `0.3927 rad` and frame 97 `1.5708 rad`; fourfold-symmetric paddles visually close a 90-degree cyclic loop. The original keyframe action remains in the editable Blender source as provenance; the derivative action is explicitly named.
- Actual physically animated annular liquid surface with four distinct Blender shape keys (clockwise paddle swirl, return pressure surge, chopping wakes, outer tank lift). Four truly modeled animated process current ribbons create visible circular circulation beneath the inspection glass. The current rig is included in GLB animations.
- **24 central recirculating bubble meshes**, deliberately brought to the visible upper-water interface after the first V13 isolation trial found only six affected pixels; **24 irregular waterline froth clumps** plus **12 paddle-path foam patches** animate around the vessel. They remain real mesh objects/animation actions, not generated or composited steam/water images.
- The front-right CRT and console were physically moved and tilted toward the viewer to clear the enlarged cyan sample tank. Original CRT, interface casting and four switches are retained intact but render-hidden. Six source-preserving console duplicates, a narrowed backing casting, **12-degree yaw**, and five physically keyed green diagnostic readout bars expose the screen without intersection.
- Existing warm olive-amber RAW and cyan CLEAN front tanks, their visible 24 air bubbles and moving foam, authentic open .49-tile side pipe bores (74 real Blender bore rays, zero intersecting structural meshes), and true nozzle-mounted irregular steam were retained.

## Independent render-visibility and animated export gates

| Genuine 512px Blender Cycles render isolation | V13 affected visible pixels | Minimum |
|---|---:|---:|
| Central swirling water surface and current ribbons | **937** | 30 |
| Central irregular foam and froth patches | **499** | 14 |
| Central recirculating bubbles | **718** | 10 |
| Exposed angled green console readout | **198** | 8 |

`tools/fmpl/production_smoke/verify_central_visual.py` reopens the real native `.blend` and renders the exact fixed-camera scene five ways: all effects, without current surface, without central foam, without central bubbles, and without green readout bars. It compares separate central and console screen-space regions. The first V13 build was correctly rejected on central bubbles (6 pixels), followed by a physically visible bubble fix and re-run. The successful V13 runner verifies all 4 effects individually as actual Cycles render contributions.

Other preserved gates: front RAW and CLEAN bubbles/foam isolation passed (237 RAW bubble, 203 CLEAN bubble, 317 RAW foam, 350 CLEAN foam pixels). Real 256px witness fluid-motion loop passed (max RAW **161**, CLEAN **134** changed pixels). Steam visibility passed (75 idle/81 working pixels). Independent GLB scene roundtrip passed; 155 actual GLB animation clips, including the slow mixer, central swirl rig, five animated CRT readout bars and witness foam/bubbles. No original external pipe connection was altered.

## Boundaries and next production handoff

V13 is a complete editable Blender, export and evidence candidate, not a published Factorio machine. **Actual native Factorio prototype fluidbox connection positions, rendered sprite shifts, game-side fluid behavior, and owner visual approval remain separate undone gates.** Continue the seven-machine metallic hydrogen chain with the 3x4 Electrolyzer after owner acceptance of this candidate. Reuse central agitation and angled console from the versioned FMPL modules, never by copying flat renders.
