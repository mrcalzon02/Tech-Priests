# Thetazine V04: integrated machinery, thermal light and shadow

Source 35 is wired into the normal `thetazine-thruster` prototype. Its late graphics import replaces the legacy two-frame sheets with 64 working body frames, a separate 64-frame heat map, an animated projected shadow, cold body/shadow states and the source-authored floor underlay. The actual ordinary entity was viewed in an exact tracked-source copy; the review mod did not replace its graphics.

**Correction to earlier checkpoints:** V03 was a published source study, not the normal runtime animation. The before-import data dump resolves the old 256Ã—512, two-frame idle/run sheets. The current after-import dump resolves V04. No personal game profile installation or release is claimed.

## Construction and appearance

Twelve articulated exterior plates each carry four-pass serpentine regenerative tubing, twelve seated saddles and flexible inlet/return roots. Six fuel and six water circuits remain separate; cold bulk injection runs in parallel with heated regenerative pre-injection. Platform frame, tanks and external interfaces remain rigid while the suspended core, rams, leaves, pump plungers and Archimedes screws move inside the frame.

The uniform pink inner lining is replaced by dark, mottled warm refractory heat, with cooler lanes aligned approximately behind the regenerative runs. Exterior plate centers remain dark with gentle edge/lip fringing. The full-throated volumetric combustion remains in the separate light map, with the installed native jet and smoke providing downstream motion and mixture-dependent colour. The zero-adjustment native jet overlaps the fading baked plume below the bell mouth.

The current agent review is **4/5**, meeting the iteration's 4/5 integration threshold. Owner final appearance approval is not asserted. Source-specific wreck/remnant and icon refinements, other thruster variants and the wider model ledger remain open.

## Evidence

- Actual GLB reimport: 3,022 physical meshes and 533,304 triangles; oriented surface, UV/material/socket correspondence and working animation pass. Render-only combustion is intentionally excluded from the GLB.
- Source 35 changes materials only. Every evaluated vertex and object transform matches source 33 across all 66 poses, preserving its direct 84-route clearance sweep: 204,858 evaluated pairs, zero violations or ambiguous classifications. Original source-33 receipts keep their original hashes.
- There are 66 combined source captures, 132 separate body/light captures and 128 exact body/light atlas cells. Cold heat RGB is zero. The original RGBA layer captures remain in a verified archive.
- The shadow comes from actual evaluated triangles clipped at the deck plane and projected along the established parallel-light direction. All 66 poses were captured. The 64 working cells preserve source alpha exactly; RGB dithering of at most one byte is canonicalized to black. Cropping to 398Ã—394 is compensated in the sprite shift, with exact common-point registration checks. The working shadow has 51 distinct images and an exact rendered wrap.
- All 64 body, light and shadow clocks were decoded, equal and sequential modulo 64. The shadow counter shares the animation root; its timing proof is combined with the separate source shadow-cell/registration proof, rather than claimed as direct identification of shadow pixels.
- Separate source-bound state captures show working, stopped/idle, disconnected caps and restart. Eight additional images show those states on the actual ordinary `thetazine-thruster`, without a graphics clone or debug counters.
- Actual before/after data-stage snapshots differ only in `graphics_set` and `drawing_box`. All 33 nonvisual root fields, including their nested physical/fluid/performance definitions, are exact. Both native conditional cap tables (`pipe-1`, `pipe-4`) are preserved. The normal graph matches the reviewed graph after removing counters and substituting its texture namespace.

These are model/render/integration checks. No behavior, consumption, thrust-performance or regression suite was run. The early zero-fluid fixture error and stale dump read were rejected and repaired; neither is represented as a successful state capture.

## Source, runtime and reproduction

Editable packed Blender source, physical GLB and export plan are under `art/source-to-3d/space-platform-engines/thetazine-thruster/v04-regenerative-study/`. Its `source-package` contains generated atlases, cold states, underlay, all original body/light captures and all original projected-shadow captures. The authored refractory texture and provenance are in `textures/`.

Runtime images are under `tech-priests_src/graphics/entity/thetazine-thruster-v04/`. The generated module is `tech-priests_src/prototypes/generated_graphics/thetazine-thruster-v04.lua`, imported at the end of `tech-priests_src/data-final-fixes.lua` after legacy rescaling. There are no runtime frame-counter images or review scene hooks in that module.

The source is fixed north, matching the prototype's `not-rotatable` flag. Body/light cells are 512Ã—1280 at scale 0.46875 and the exact manifest shift. The cropped shadow uses its own compensated shift. Cold body and shadow use `frame_count=1`, `repeat_count=64`, matching the effective working count. External socket projections remain `(-2.5, -1.0625)` and `(2.5, -1.0625)` native tiles.

Use local Blender 5.0.1 and the helpers under `tools/art/thetazine_v04/`. Resume only source/script-hash-matching capture receipts. The full working capture and the dedicated state capture have separate preparation receipts; do not relabel one with the other's current profile. Data dumps must postdate the exact tracked-source preparation. The normal-state fixture uses the ordinary entity and only logs its data-stage prototype.

The broader completion goal stays active. Consult the global ledger before starting another asset or restarting an expensive capture.
