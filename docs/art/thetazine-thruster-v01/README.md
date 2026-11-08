# Thetazine V01 — editable interface-fit candidate

This is a separately editable **candidate**, with independently inspected static interchange. It does not replace the existing game sprites. The final surface and state gates remain open; no new owner approval is claimed.

## Source and construction

The actual repository Thetazine sprites contain two 256×512 idle and two run rectangles. Their crossbeam, canisters, shoulders, feeds, pressure chamber, winged emblem and bell share the hydrogen sprite construction. Direct comparison of the upper 256×230 region gives alpha IoU **0.9997563731** at threshold 128. RGBA pixels are **not identical**. This supports explicit reuse of the authored construction, not historical native-model identity.

The builder opens the exact verified hydrogen native SHA `396690cccd81487d1bb2a8e05325a3ccbfc0c52e72332449f10bb8fe567fc27e`, scales the shared structural parts by 1.25, preserves standard-size pipe bores/flanges, translates the fittings, removes the two old supply necks and builds two continuous 5×5 routes to the scaled body. Existing 18 cast/tank/brass/steel/bell/dark maps remain shared fabrication materials. They are not renamed or claimed as new Thetazine textures. Packed source images and all exported PBR maps load.

Source +X is east, +Y platform/fore, +Z up; fixed north only. Model flange centers are `(-2.5,1,.36)` fuel, `(2.5,1,.36)` water, outward ±X. Native cells remain `(-2,-1)` and `(2,-1)`, mating planes ±2.5, adjacent pipe centers ±3. The 5×5 half-tile origin, 4.3×4.7 collision and existing cap contract are preserved by leaving the entire game source tree unchanged. No wire point or numerical gameplay interface is invented.

## Actual verification and limits

Actual native and reimported GLB each have **291 meshes / 93,236 triangles / 18 packed or embedded images / seven materials**. Raw GLB geometry, UVs, normals and image decoding pass with zero degenerate geometry/UV triangles. One-to-one oriented triangle matching verifies all three corner positions, UVs and material, not an ordering-dependent vertex-count proxy: maximum position delta **2.3842e-7**, UV delta **2.9803e-8**, per-part surface-area delta **1.4048e-7**. Both actual imported flange planes/normals, two ground feet and 82 named mounting-head support contacts pass.

Four actual reimported GLB renders were viewed: front, oblique, rear and rear clay. Source/reference/render/model hashes bind the review. The first unique-corner matcher falsely rejected float-rounding/deduplication differences; the final verifier uses bijective oriented triangles at the same 1e-5 position/UV tolerance. It does not suppress a geometry mismatch.

The candidate has two idle/two working emission controls, but no full state render, changing flame/plume model or animation acceptance. GLB is a static warm-idle snapshot. The proposed camera registration in `interface-validation.json` is **analytical only**, not native visible pipe-mouth proof. No atlas, runtime import, drawing-box change or game test is made here. Model/render/interchange checks only; no propulsion, behavior or regression tests.

The reviewed surfaces score 3/5 and source-state fidelity 2/5 against the unchanged final threshold of 4/5. Keep this candidate separate until those gates pass.

## Resume locally

Use Blender 5.0.1 and Python with Pillow/NumPy. Do not dispatch Actions. Source files are under `art/source-to-3d/space-platform-engines/thetazine-thruster/v01-candidate/`; checks are under `tools/art/thetazine_thruster_v01/`.

1. Run `prepare_contract.py --repo <Tech-Priests> --out <scratch-contract-dir>`. Inspect the four source-state sheet and source contract. The recorded main SHAs are the reconciliation baseline of this candidate.
2. Invoke Blender with `--factory-startup --background --threads 2 --python-exit-code 12 --python <build_model.py> -- --source <hydrogen-v01.blend> --reference-idle <Thetazine idle PNG> --reference-run <Thetazine run PNG> --contract <source-contract.json> --out <fresh-model-dir>`. Existing output directories are refused.
3. Run each Blender script `verify_export.py`, `verify_interfaces.py`, `render_review.py` with the same flags and `-- <fresh-model-dir>`. Run Python `audit_glb.py <fresh-model-dir>`. Read actual status/results and view all render images.
4. Refine the broad plate seams, engraving and region-specific weathering against the real source, then model/capture the two source flame/light states. Keep source, candidate and rejection history; do not lower the 4/5 final threshold.
5. After reviewed beauty/emission/flame/shadow capture, verify exact atlas cells. Register the projected mouths in an isolated native profile connected/disconnected, preserve `pipe-4`/`pipe-1` and every nonvisual field, integrate only the real late graphics import, and show actual native proof before final promotion.

Retain the already-running A02 capture. Recover condenser/reactor/lumberyard native sources before inventing new designs. The broader goal and issue #13 remain open.
