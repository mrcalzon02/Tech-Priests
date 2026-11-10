# Pipette geometry library — first executable construction slice

**Status (2026-11-10): actual editable source geometry, native acceptance in progress.** This work stays inside FMPL. A standalone Blender add-on can be extracted later without changing these stable data contracts.

## Scope implemented now

The catalog specifies **140 architectures**. The new `library_geometry.py` contains **19 currently coded geometric recipes**, not 140 approved Blender models. They cover: smooth rigid metal/polymer tubes; two distinct metal conduits (EMT and square-lock/FMC); annular polymer conduit; split corrugated loom; *open* spiral plastic wrap and metal spring guard; manually segmented articulated sleeves; annular and helical metal hose; soft rubber hose; historical soft-cast lead pipe; single and eight-wire harnesses; tied eight-wire loom; true 1×7 wound metal cable; and ridged rebar.

For every implemented shape, the construction logic returns actual indexed vertices/faces. `build_library.py` exports stand-alone editable **OBJ** geometry and JSON receipts. `library_blender.py` converts the same recipes into separately editable Blender objects, GLB, and a real Cycles proof PNG. `library_verify.py` independently reopens Blender and GLB in another Blender process and verifies pixels, mesh counts, and the fixed comparison ports.

Crucially, **pipe Y is not several capped tubes intersecting**. When selected on a smooth hollow fluid line, the Blender renderer unions physical outer cylinders and subtracts overlapping continuous inner bores via exact Boolean geometry. Corrugated/other shaped fluid manifolds are deliberately rejected until their CSG shaping is supported. `wire_eight_loose_bundle` Y uses individual wires and a visible junction-housing *candidate*, not a fictitious fluid pipe fitting or an assertion of electrical service.

## Fixed comparative measurements

Read `comparison_fixture.v1.json`: canonical public socket coordinates are identical for every matching topology. A branch sample uses Y ports A/B/C at **(-1.2,0,0.65), (0.848528137,0.848528137,0.65), (0.848528137,-0.848528137,0.65)**. All compare at nominal **0.12 Blender-unit outer diameter** at their endpoint mouths, and the reference Cycles camera and illumination are fixed. Corrugation fades to the nominal interface size at the actual public port, rather than creating incompatible pipe mouths.

A two-point loose wire uses one naturally drooping span. In an eight-wire harness, all eight conductors have small and distinct authored *internal* pin offsets and different deterministic sag factors; the **public socket center remains unchanged**. Sag is visual geometry, not a force, ampacity, or fluid-pressure simulation.

## Pure Python: export all constructed recipes

From repository root, choose a NEW folder path:

```bash
python -m unittest discover -s tools/fmpl/pipette -p 'test_*.py' -v
python tools/fmpl/pipette/build_library.py --output /tmp/pipette-first-library
```

The builder rejects existing directories to avoid overwriting original assets. It generates all **19 currently implemented recipes** as distinct OBJ scenes plus explicit Y comparison demos and `manifest.json`. This program is *not* dependent on Blender.

Generate a single sample without Blender:

```bash
python tools/fmpl/pipette/library_geometry.py \
  --architecture conduit_fmc_interlocked --topology straight \
  --out-obj /tmp/metal-spiral.obj --out-json /tmp/metal-spiral.json
```

## Native Blender geometry and proof

Use Blender 5.2+; all output filenames must NOT exist:

```bash
blender -b --factory-startup --threads 4 --python-exit-code 1 \
  --python tools/fmpl/pipette/library_blender.py -- \
  --architecture conduit_fmc_interlocked --topology straight --preview-only \
  --out-blend /tmp/fmc.blend --out-glb /tmp/fmc.glb \
  --out-png /tmp/fmc-cycles.png --report /tmp/fmc-build.json

blender -b --factory-startup --threads 4 --python-exit-code 1 \
  --python tools/fmpl/pipette/library_verify.py -- \
  --blend /tmp/fmc.blend --glb /tmp/fmc.glb \
  --preview /tmp/fmc-cycles.png --build-receipt /tmp/fmc-build.json \
  --out-report /tmp/fmc-verify.json
```

For a true-hollow historical pipe Y, change `--architecture pipe_lead_historical --topology wye`, retaining the exact same fixture. A wire Y uses `wire_eight_loose_bundle --topology wye`. For other indexed profiles not in `RECIPES`, **fail closed**: indexed is not the same as implemented.

To use a production FMPL material instead of an unapproved preview, pass `--source-blend path/to/approved.blend --material-name "exact approved FMPL material ID"` and **omit** `--preview-only`. The builder will fail rather than silently replace missing approved materials.

## Test and proof gates

`test_library_geometry.py` verifies actual topology, helical-versus-annular geometry, open spiral gaps, split-wall construction, natural single- and eight-wire sag, seven-strand winding, exact fixture socket positions, identical diameter at terminal mouths, and refusal to overwrite exports. These tests are pure-Python mesh tests, not substitutes for native Blender readback. The optional `architecture_gallery=true` request in the existing `Dens-Mortis` `fmpl-pipette` mode runs eight hardcoded Blender/Cycles cases and independent verification, without adding any workflow or accepting arbitrary executable parameters.

**Still not complete:** automatic adapter generation for the remaining 121 catalog recipes, 77 individually measured/approved hardware fittings, BVH wire collision solver, true structural/pressure/electric behavior, and native Factorio fluidbox integration. Existing production models are not edited in this stage.
