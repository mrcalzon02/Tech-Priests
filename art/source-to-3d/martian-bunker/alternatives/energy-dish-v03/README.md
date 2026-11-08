# Energy dish V03 — continuity, UV and idle rotation candidate

This advances the sketch-derived V02 energy-dish cap; it does not replace the approved A02 lobber. It is a partial model-production checkpoint, not a claim of complete turret/game integration or owner approval.

## Geometry and surfaces

The 48 short side-rim cylinders are replaced by two connected swept rails on the same parabolic centreline. Existing 25 other mesh geometries and world transforms, overall bounds, `(0,0,1.70)` bearing and `(0,0,2.34)` elevation pivot are preserved. Four foot fasteners and two trunnion retainers sit on existing supports. Large steel/painted panels use continuous width/arc-length UVs at two texture repeats per model unit; rails use circumference/length UVs. This fixes enlarged/stretched panel mapping without inventing ornaments or changing the owner-sketch silhouette. Existing packed PBR maps are retained in dish-specific material instances; no baked normal map is claimed.

Independent reopened native and imported GLB: **33 meshes, 10,332 triangles, zero degenerate triangles**, finite coordinates and UVs, packed source images. The two new rails each have one connected component. Export explicitly evaluates modifiers: the default export omitted bevels and failed the triangle-count check; that candidate was replaced. `surface-roundtrip-validation.json` proves unique position/UV/material coverage and per-part area/count correspondence within 1e-5. N-gon cap triangulation can choose different diagonals; topology and render pixels are not called identical. `render-comparison.json` retains the actual CPU render differences.

`local-proof.png` contains actual source, native, independently imported GLB, neutral clay and 256px review renders. Read `visual-review.json` for hash-bound scores and open gates. Existing shape is retained; full surfacing, emitter states and fidelity approval remain open.

## Directional capture and import contract

The idle capture uses the exact camera/world/lights from the restored A02 source, whose camera is copied from the original bunker. Concrete geometry and the lobber are excluded; the dish mount remains fixed. 64 clockwise headings use yaw `180 - direction*5.625` degrees; N=0, E=16, S=32, W=48. New CPU Cycles beauty captures retain 640px / 16 denoised samples / ortho 6.20. `idle64-validation.json`, when present, proves all raw images and both 640px/256px atlas cell readbacks. These are **idle beauty only**; firing, emission, shadow and runtime prototype integration remain open.

Planned sprite destination is `tech-priests_src/graphics/entity/bunker-energy-dish/`; planned module is `tech-priests_src/prototypes/generated_graphics/bunker-energy-dish-v03.lua`, after legacy rescaling. The atlas manifest derives scale/shift from the actual calibrated world-origin projection. Do not install this as a replacement for the autocannon or invent combat statistics. Exact target native prototype/working-state contract must be resolved before runtime registration.

## Reproduce locally

Use Blender 5.0.1; keep scratch/exports outside this immutable checkpoint folder. Run `refine_energy_dish_v03.py` with V02 `energy_dish_entity.blend` loaded and an output directory after `--`. Then run `review_energy_dish_v03.py -- OUTPUT V02_SOURCE` in a clean Blender process and `verify_dish_surface_roundtrip.py -- OUTPUT`. `make_dish_v03_review.py` builds the review board with Pillow. The helper scripts retain this run's relative scratch paths; adapt the scratch root if running elsewhere.

For idle directions, load the restored A02 native source and run `capture_dish_idle64.py -- DISH_NATIVE OUTPUT/idle64`; identity mismatch fails closed. After actual completion, `package_dish_idle64.py` fully verifies PNGs and exact atlas cells. Keep the calibrated camera fixed and preserve original inputs. No Actions or behavior/regression tests are used.
