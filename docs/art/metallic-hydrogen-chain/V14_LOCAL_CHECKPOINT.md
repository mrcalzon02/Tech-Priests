# Water Purifier V14 — local construction checkpoint

The metallicized-hydrogen chain and three plasma reactors remain an active production goal. This checkpoint is a real editable purifier revision, **not emergency-machine-equivalent completion, native prototype integration, or owner acceptance**.

## Current artifact

Local staging root: `build/model-completion/metallic-hydrogen-chain/v14-pilot-03-surface-repair/` in the `model-production` checkout. The preserved V13 source came from existing Dens-Mortis artifact `13781794050`, run `42854827403`, recovered into `v13-recovered/fmpl-super-greeble/`. Its `.blend` SHA-256 is `971087c8a03e5b91ab6f70afa2a1abe13f5d0cd231b9983969bd509ed10330be`. The original download in Downloads is older V03 and was not used as a substitute for V13.

The current source is `water-purifier-v14.blend`. Its source-safe constructor is `tools/fmpl/production_smoke/refine_purifier_v14.py`; independent geometry/export inspection is `verify_purifier_v14.py`. Both require actual source bytes. Original MH7 and FMPL mesh coordinates/transforms remain hash-identical. Hidden original geometry remains recoverable.

Implemented in this revision:

- Full source-sized console casting and a physically framed side extension enclosing the original CRT and four buttons. One rigid 12-degree assembly transform preserves control proportions and five animated green bars. Minimum measured local panel border is 0.087 tile, exceeding the 0.025 requirement. The lowest conservative tank-clear placement raises the full assembly by 0.775 tile; two grounded stanchions and seated feet support it. This higher placement still needs owner inspection.
- An I-section upper bridge inside the original bridge envelope, metal landing shoes and paired triangular haunches joining the pedestal feet to the steel vessel shell. Twelve independently checked contact edges have zero surface gap.
- Ten hollow gasketed unions on the five main process routes. Each includes a receiving neck, paired flange plates, gasket and seated bolt groups. Independent receiver-contact checks pass for all ten.
- Source-preserving UV derivatives for inherited meshes lacking coordinates. Main vessel mapping wraps circumferentially with vertical grain; straight process tubes have axial physical-scale UVs. Original data blocks are retained unchanged. New metal uses model-local copies of the packed FMPL PBR materials.
- Explicit fixed-entity capture policy. The default rotatable entity still requires four grid directions; the nonrotating purifier requires one. Thirteen focused camera-policy/chain tests pass.

## Actual checks and limitations

`independent-readback.json` records the actual source/export hashes, material channels, camera, geometry, contacts and animation samples. Reimported GLB: 637 meshes, 128,868 triangles, zero nonfinite vertices, zero degenerate triangles, no missing UV layers, bounds error below 0.000001 tile. Both native and imported external bores pass 74 rays. The complete visible envelope stays within the 3x3 X/Y footprint, allowing floating-point tolerance. Native slow-stirring motion retains the quarter turn from frames 1 to 97.

The GLB **fails visual parity**: the procedural witness-liquid/glass and steam shaders lose their intended appearance in the actual reimported render. Its successful geometry status must never be promoted into full runtime acceptance. `runtime-front.png` and `runtime-clay.png` expose this defect. The source `working.png` preserves visible amber raw water, cyan clean water and bubbles. Bake/adapt the actual material networks and reimport again before accepting the interchange. Do not overwrite the failed export or its renders.

Native Cycles isolation passes: central surface 1,011 changed pixels, foam 495, bubbles 689 and relocated CRT bars 193, under the existing thresholds and canonical camera. Front witness bubble/foam passes: raw 212/317 changed pixels, clean 213/315. Steam working passes with 92 visible/60 high-rise pixels, but idle **fails** with 66 visible pixels against the unchanged 75 threshold (37 high-rise passes). Keep this failure open.

One idle and eight actual working frames were captured at the fixed camera, the master independently reopened, and six 64/128/256 RGBA sheets packed and inspected. The source timeline is 24 FPS over a 96-frame cycle: **4 seconds**, so the native-loop WebP uses 500 ms per captured working frame. The proposed Factorio animation speed is 8/(60*4) = 0.03333333, pending actual engine readback. The profile's 8 FPS capture preview must not be mistaken for the intended machine cycle.

The packaged checkpoint, editable source, failed GLB, real before/after/runtime comparison, loop, six sheets and SHA-256 manifest are under `art/source-to-3d/metallic-hydrogen-chain/water-purifier/v14-local-candidate/`. `VISUAL_REVIEW.json` binds scored findings to source, export, render and boiler/reference hashes. Construction/finish/state integration remain below the 4/5 final threshold; there is no owner approval.

`line-endpoint-census.json` inventories 32 straight process/service segments, not all possible hoses or sight-flow geometry. Ten main process endpoints are fitted; **do not claim zero unsupported or unclassified endpoints**. Remaining service lines, gauge taps, electrical entries, sample lines and original sight routes still require named receiver classification and appropriate fitted connections. The newly raised console also needs its electrical service route reconciled.

## Continuation order

1. Finish witness/steam and fixed-camera eight-frame native evidence; verify the source-to-prototype clock rather than inferring it from the preview FPS.
2. Complete named endpoint/branch classification, electrical routing and remaining coupling families. Preserve existing 0.49 bore / 0.68 collar geometry and the single production camera.
3. Repair the failed GLB procedural surface export; independent material/render inspection must pass separately from geometry.
4. Extract at most a few genuinely reusable verified assemblies from the actual saved source into the cumulative library. The registry is currently empty; do not fabricate reuse.
5. Implement an isolated native prototype/pipe placement jig, measure connected/disconnected cap seating, then integrate only after its gates pass. No purifier prototype, recipe or economy change has been installed by this checkpoint.
6. Continue distinct machines 02–07 in the accepted design order; recover old sources where possible and label reference reconstructions honestly. This checkpoint has not built those six machines.
7. Recover the actual Minoris/Majoris/Maximus V14 package and reference images. Local searches did not find them. Browser recovery stopped at an app-access approval timeout before any page was opened; this is not a proven missing-file result. Keep the original ring-relative frame and historical sources intact.

Other checkouts contain concurrent behavior/steam-engine work. Do not edit those files. The isolated checkout starts from origin/main `e6a5022`; no remote publication or release is claimed here. Candidate and failed-study staging directories are preserved. See `V14_CONTINUATION.json` for current absolute workspace and resumable outputs.
