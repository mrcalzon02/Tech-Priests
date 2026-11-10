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

## V9 outcome and V10 follow-up

V9 native run [#42759037920](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42759037920) produced a real editable scene and passed independent original/GLB geometry checks but correctly failed the new steam-visibility stage. Artifact `13736658901` reports 201 idle/128 working visible steam pixels above the metal lip. Its high-rise subregion was miscalibrated (upper crop at Y91..106 above the actual rendered plume): only 1/0 qualifying pixels. The genuine 512px working PNG shows steam that is finally readable but too axisymmetric, resembling a short white cone; it is not owner-approved.

**V10 model correction** uses irregular overlapping x/y/z offsets across four main and eight secondary wisps, decreases surface intensity and density-linked light, and moves the upper QA region to the actual plume (Y102..117), still excluding the nozzle metal. The pre-V9 near-invisible render fails that corrected region, while the V9 frame had 159 idle/92 working visible pixels within it. The source code continues to preserve original 50+136 meshes, one camera, two fluid ports, and the hollow metal throat without generating textures or using imagegen.

- Pinned V10 Tech-Priests source commit: `6b8ed60bd7cbad68b1a454770fedb036adbc5c51`.
- Dens Mortis dispatch: [run #42759960059](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42759960059), commit `fc4703c425daf059c026b863bd55316792a808fc`.
- V10 acceptance: actual Blender Cycles idle/active 512px steam QA; sideways/asymmetric lobe geometry; independently reopened .blend+GLB; no legacy hard cones, preserved hollow bore; real 64/128/256 RGBA atlas; full-size inline before/after proof and measured alpha visible above nozzle. Final owner visual approval is separate.
- Running constraint: V10 queued behind existing FMPL 36-model gallery batch on the single OLD-CORE30 Windows worker; do not cancel unrelated successful model rendering or create another workflow simply to advance this test.
