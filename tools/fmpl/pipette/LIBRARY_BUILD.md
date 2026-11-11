# Pipette geometry library — first executable construction slice

**Status (2026-11-10): actual editable source geometry, native acceptance in progress.** This work stays inside FMPL. A standalone Blender add-on can be extracted later without changing these stable data contracts.

## Scope implemented now

The catalog specifies **140 architectures**. The new `library_geometry.py` contains **30 currently coded geometric recipes**, not 140 approved Blender models. They cover: smooth rigid metal/polymer tubes; two distinct metal conduits (EMT and square-lock/FMC); annular polymer conduit; split corrugated loom; *open* spiral plastic wrap and metal spring guard; manually segmented articulated sleeves; annular and helical metal hose; soft rubber hose; historical soft-cast lead pipe; single and eight-wire harnesses; tied eight-wire loom; true 1×7 wound metal cable; and ridged rebar.

For every implemented shape, the construction logic returns actual indexed vertices/faces. `build_library.py` exports stand-alone editable **OBJ** geometry and JSON receipts. `library_blender.py` converts the same recipes into separately editable Blender objects, GLB, and a real Cycles proof PNG. `library_verify.py` independently reopens Blender and GLB in another Blender process and verifies pixels, mesh counts, and the fixed comparison ports.

Crucially, **pipe Y is not several capped tubes intersecting**. When selected on a smooth hollow fluid line, the Blender renderer unions physical outer cylinders and subtracts overlapping continuous inner bores via exact Boolean geometry. Corrugated/other shaped fluid manifolds are deliberately rejected until their CSG shaping is supported. `wire_eight_loose_bundle` Y instead uses eight continuous conductor meshes with four exiting each branch; the loose-wire variant has no unmounted mid-span rings or junction boxes. It is not an assertion of certified electrical service.

## Fixed comparative measurements

Read `comparison_fixture.v1.json`: canonical public socket coordinates are identical for every matching topology. A branch sample uses Y ports A/B/C at **(-1.2,0,0.65), (0.848528137,0.848528137,0.65), (0.848528137,-0.848528137,0.65)**. All compare at nominal **0.12 Blender-unit outer diameter** at their endpoint mouths, and the reference Cycles camera and illumination are fixed. Corrugation fades to the nominal interface size at the actual public port, rather than creating incompatible pipe mouths.

A two-point loose wire uses one naturally drooping span. In an eight-wire harness, all eight conductors have small and distinct authored *internal* pin offsets and different deterministic sag factors; the **public socket center remains unchanged**. Sag is visual geometry, not a force, ampacity, or fluid-pressure simulation.

## Pure Python: export all constructed recipes

From repository root, choose a NEW folder path:

```bash
python -m unittest discover -s tools/fmpl/pipette -p 'test_*.py' -v
python tools/fmpl/pipette/build_library.py --output /tmp/pipette-first-library
```

The builder rejects existing directories to avoid overwriting original assets. It generates all **30 currently implemented recipes** as distinct OBJ scenes plus explicit Y comparison demos and `manifest.json`. This program is *not* dependent on Blender.

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

## Typed fitting construction (25 initial joint types)

The new `library_fittings.py` implements **25 actual editable connector part recipes** from the larger 77-entry joint registry, including flanges with six individually placed fasteners, hex compression fittings, raised helical threads, hose barbs/clamps, electrical glands, ring lugs with conductive tangs, eight-contact terminal blocks, rebar sleeves, and mechanical clevis/turnbuckle parts. They use the same exact public socket XYZ/normals as the construction examples and reject incompatible type/payload matches. The Blender adapter now chooses these typed fitting meshes when available; unimplemented types remain clearly unapproved placeholders rather than silent substitutions.

Pure Python fitting-only OBJ example:

```bash
python tools/fmpl/pipette/library_fittings.py \\
  --architecture conduit_fmc_interlocked \\
  --joint flex_conduit_connector --topology wye --port A \\
  --out-obj /tmp/fmc-captured-fitting.obj
```

The 14 checks in `test_library_fittings.py` inspect real fitting meshes, visibility of eight terminals and preserved fixed port coordinates. These added fittings have NOT yet passed a separate native Blender visual approval.

## Test and proof gates

`test_library_geometry.py` verifies actual topology, helical-versus-annular geometry, open spiral gaps, split-wall construction, natural single- and eight-wire sag, seven-strand winding, exact fixture socket positions, identical diameter at terminal mouths, and refusal to overwrite exports. These tests are pure-Python mesh tests, not substitutes for native Blender readback. The optional `architecture_gallery=true` request in the existing `Dens-Mortis` `fmpl-pipette` mode runs eight hardcoded Blender/Cycles cases and independent verification, without adding any workflow or accepting arbitrary executable parameters.

**Still not complete:** automatic adapter generation for the remaining 110 catalog recipes, 77 indexed hardware interfaces still requiring real mating approval, BVH wire collision solver, true structural/pressure/electric behavior, and native Factorio fluidbox integration. Existing production models are not edited in this stage.

## Second executable expansion (2026-11-10)

The geometry kernel now includes six distinct section meshes beyond the original 19: `wire_twisted_pair`, `wire_flat_ribbon`, `wire_coax`, `housing_pet_braided_sleeve`, `hose_wire_suction`, and `pipe_jacketed_double_wall`. Each preserves the fixed public connection port positions. Physical conductor, sleeve, spring and coax layers are deliberately modeled where visible at review or termination; they are not interchangeable aliases for standard tubes. Updated tests exercise actual vertices, profile differences and fixed Y layouts. The native Blender gallery uses the existing Dens Mortis worker and a bounded 14-case set; source-level implementation is not visual approval without passing independent reopen checks.

The Boolean fluid Y now has a mandatory surface-island/non-manifold audit. If exact Booleans cannot produce one contiguous watertight hollow body, native construction attempts a bounded weld/voxel repair and fails closed if topology remains invalid. No floating parts may be accepted solely because their Cycles image appears connected.

## Typed connector expansion

`library_fittings.py` now constructs 25 physical fitting types, including flat-ribbon eight-position IDC contacts, coaxial shield/dielectric/center-pin geometry, actual protective braid-sleeve overlap, and six-bolt metal bellows flanges. A twisted-pair terminal block has **two**, not eight, separately placed conductor contacts; eight-wire looms retain eight. Generated Blender objects carry the exact source port ID and type. `library_verify.py` independently checks these Blender fitting objects against the frozen comparison coordinates. This proves authored geometry, not pressure/ampacity rating or host-socket contact approval.

## Immediate Blender Asset Browser use (without a separate add-on)

New `library_blender.py` exports mark their generated editable collection as a **Blender Asset Browser collection asset by default**. The asset description explicitly says **PROTOTYPE / PREVIEW ONLY** unless source-approved materials are supplied. This is native Blender 5.2 ID-level `collection.asset_mark()` behavior, not a new plug-in or global preference mutation. Add the directory containing the resulting `.blend` files under **Edit → Preferences → File Paths → Asset Libraries** (or your existing FMPL Asset Library); the marked Pipette collections can then be selected and appended/linked through Blender's Asset Browser. You can opt out when generating a file with `--no-asset-mark`.

This asset marking still needs a new native proof on the runner. The existing 14-model run proves geometry and Cycles previews but was generated **before** this Asset Browser feature. `library_verify.py` now checks that the marked collection and its prototype warning survive actual `.blend` reopening. 

## New shaped carriers: coils, layflat, twin-channel, open tray and slotted duct

The pure-Python `library_forms.py` module adds five physically distinct construction kernels to the previous 25 recipes, all explicitly handled through the safe Pipette API. `tube_retractile_coil` has one continuous true hollow line following 14 spring turns; `hose_layflat` has a flattened, elliptical *open* bore; `hose_twin_bonded` has two individually modeled open lumens and a visible exterior bonding web; `housing_ladder_tray` has two rails and countable transverse rungs with actual air gaps; `housing_slotted_duct` has a continuous U-shaped base and two slotted comb walls, not a painted pattern. All preserve exactly the same reference endpoint XYZ/normal positions.

These require **profile-specific terminations**. A generic circular hose barb cannot be presumed to mate with a flattened layflat hose, a single round collar cannot connect two different fluid channels, and a circular conduit snap cannot directly connect a rectangular open wiring duct. `library_blender.py` deliberately leaves these five terminal interfaces unimplemented, rather than inventing misleading hardware. Fittings can be added after their true adapter geometries are authored and measured. Native Blender/GLB/Cycles render proof remains a separate release gate.
