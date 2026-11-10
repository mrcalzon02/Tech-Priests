# Water Purifier — real nozzle steam readability checkpoint (V9)

**State:** V9 Blender production dispatched, not yet technically or visually approved.
Source pinned to Tech-Priests commit 26802ffca147fc873514793432691fb0a60cd359.
Controller: Dens Mortis single-job self-hosted Windows runner; no new workflow.

## Execution
- V9: https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42759037920 on dispatch commit d61e3f7cd425b7b8ab037c6c2d006b5423547a82 (fmpl-super-greeble mode).
- V8 verified: https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42754989343, artifact 13735008281.
- V8 source preservation: 50 original meshes, 136 previous process meshes, immutable camera and two canonical fluid mouths; 254 new meshes; 426 reimported GLB meshes; 8 working frames and 6 sprite atlases.
- Hollow vent has a verified 0.15576-tile bore at Blender x=.94, y=.60, upper lip Z2.913. Two original literal cone meshes and original solid cap are retained but hidden.

## Visual blocker and correction
V8 real 512px Cycles render has a physical open metal vent, but only a dark tiny wisp. Above-nozzle ROI x320..358, y90..119 produced zero visibly opaque pixels in both idle and working states. Shader and geometry QA alone does not constitute visual approval.
V9 refines tools/fmpl/effects/fluid_steam_fx.py with actual 24x16-segment intersecting vapor meshes, a higher irregular four-core/eight-veil rise, noise-broken true Principled Volume, and soft volume density that reaches zero before mesh rims. Gentle density-linked emission (0.165 multiplier) supplies contrast against dark industrial machinery without hard edges, planar cards, image generation, or simulation caches.

## Hard gates
- tools/fmpl/production_smoke/verify_super_greeble.py checks actual native geometry, invisible legacy cones, feather nodes, density-linked volume lighting and source preservation.
- tools/fmpl/effects/verify_steam_visibility.py decodes REAL Blender 512px idle and working PNGs, excludes nozzle metal, and requires 75+ visible steam pixels in the above-nozzle crop in each state and 12+ in the high-rise crop. This fails V8 by design.
- Existing runner executes steam pixel QA BEFORE expensive sprite atlas capture. The Water Purifier fluid-motion pixel QA remains mandatory.
- If run fails: diagnose first actual stack trace, repair minimally, re-pin the source by full SHA, dispatch once through the existing authorized request file, and avoid unnecessary concurrent jobs.
- If run passes: visually inspect full native render and alpha-aware dark/light backgrounds; create true-source before/after crop and real-frame GIF if worthwhile. Reject hollow bright rims, visible cones and invisible vapor even if technical tests pass.
- Retain source .blend, GLB, 64/128/256 RGBA atlases and SHA/QA receipts with final GitHub run and artifact. Do not claim native Factorio fluidbox integration or owner approval before game and owner checks.
