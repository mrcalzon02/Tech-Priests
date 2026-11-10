# Pipette — Blender-unit typed tubing, wiring and coupling planner

### Executable geometry construction (19 recipes, current slice)

**[Build instructions and explicit native verification gates](LIBRARY_BUILD.md)** describe the new independent `library_geometry.py` mesh kernel, `build_library.py` batch OBJ exporter, `library_blender.py` editable Blender/Cycles/GLB builder, and `library_verify.py` independent native readback. These have **19 physically distinct implemented geometry recipes** drawn from the [140-entry construction index](architecture_catalog.v1.json). Examples include metal helical interlocked conduit, annular polymer conduit, open spiral sleeve, split loom, naturally sagging eight-wire bundles, and a Boolean hollow lead-pipe Y using frozen comparison coordinates.

The new source implementation and `test_library_geometry.py` mesh regressions are not automatic production approval: use the existing Dens Mortis opt-in `architecture_gallery` proof when scheduling a bounded, source-pinned Blender run. The standing v0.1 four-fixture script and existing models are preserved; no new workflow or add-on installation is necessary.

## Architecture expansion index (catalog stage)

The **[GitHub-readable architecture index](ARCHITECTURE_INDEX.md)** contains **140 construction profiles across nine groups**, **77 joint/termination architectures**, **20 visual stiffness profiles**, and a [fixed XYZ port comparison fixture](comparison_fixture.v1.json) shared by Y/tee/elbow examples. These are **indexed future build targets**, *not* 140 implemented meshes. The [catalog JSON](architecture_catalog.v1.json), [joint library](joint_catalog.v1.json), [stiffness models](stiffness_profiles.v1.json) and [regression contracts](test_architecture_catalog.py) form the new source-of-truth baseline; existing v0.1 executable line types are not silently expanded.

**Current state: V0.1 source-level prototype.** The [authoritative design and development stages](PIPETTE_STANDARD.md) define the planned typed Blender construction subsystem. This is not yet a visually approved 3D asset library or a fluid/electrical/force simulation.

## The size rule

All sizes are **relative Blender scene units**: `size.outer_diameter: 0.08` makes the visible tube 0.08 Blender units wide. `visual_gauge: thin` is an appearance preset, **not** AWG or millimeters. No real-world conversion is performed or required. Outer diameter, tube-wall fraction, segment spacing, sag, wire diameter, winding pitch, corrugation and rebar ribbing are specified directly in Blender units or dimensionless fractions.

## Module layout

- `PIPETTE_STANDARD.md` — classification, parameterization, physical coupling rules and staged development gates.
- `core.py` — **pure Python**, no Blender required. Rejects invalid family/payload/fittings/sizes/sockets, constructs bounded centerline/segment plans, flags unverified socket-facing and preserves source protections.
- `blender_adapter.py` — isolated **prototype Blender mesh builder**. Consumes a validated plan and creates named editable visible tube, hose, cable and rebar geometry with terminal fitting meshes, without modifying source files. Actual native .blend/GLB reopening is a further gate.
- `test_core.py` and `test_registry.py` — pure Python regression cases for relative sizing, typed fittings, keep-outs, conductor counts and consistency with the authoritative type registry.
- `type_registry.json` — machine-readable description of the eight line families, allowed payloads, typical fittings, visual presets, affordances and user prompts.
- `verify_native.py` — independent Blender/GLB reopening and real Cycles preview, not just source-file existence.
- `examples/` — reference requests for eight signal wires and a segmented fluid tube.

## Execute the pure planning stage

```sh
python -m unittest discover -s tools/fmpl/pipette -p 'test_*.py' -v
python tools/fmpl/pipette/core.py \
    --request tools/fmpl/pipette/examples/eight_wire_loom.json \
    --output pipette-eight-wire-plan.json
```

The output is a deterministic machine-readable plan, **not** an actual Blender mesh or game-native object.

## Blender mesh prototype

Using an existing approved FMPL model with the exact referenced materials already loaded:

```sh
blender -b --python-exit-code 1 --python tools/fmpl/pipette/blender_adapter.py -- \
  --request tools/fmpl/pipette/examples/segmented_fluid_tube.json \
  --source-blend path/to/verified-source.blend \
  --out-blend path/to/NEW-pipette-scene.blend \
  --out-glb path/to/NEW-pipette-geometry.glb \
  --report path/to/NEW-pipette-receipt.json
```

The command refuses to overwrite existing files, and fails closed if the requested FMPL material is not available in the pinned source. `--preview-only` is explicitly a **non-production material preview** mode; it may generate an unapproved gray stand-in so pure geometry can be inspected. Such a preview is not approval to integrate or render final Factorio sprites.

The adapter currently builds:
- hollow visible pipes and conduits with open annular end faces;
- repeatable segmented conduit sections and actual separately modeled sleeves;
- relative corrugation/rib surface geometry for hoses and rebar;
- single-wire, bundle jackets, optional exposed multi-core wires, and tension-cable strands (hanging shape from plan);
- fitting barrels/stops/glands or mechanical eyes with source socket IDs preserved as metadata.

It does **not** automatically prove perfect mechanical corner elbows, real pressure containment, insulation ratings, actual electric behavior or native game/fluidbox integration. Free-form mesh socket discovery, BVH routing, approved connector fixture sourcing, true braided mechanics and durable cross-repository automation remain **future stages**.

## Example authoring

The typed planner can distinguish “one thin wire,” “eight wires inside a segmented conduit,” “an empty plastic sheath,” and “a large steel pipe carrying fluid.” The **visible** scene-unit diameter is always explicit when fine control matters. The count, payload, section kind, material, joint pitch, support points, endpoint socket normals, connector kinds and behavior hook IDs are separate parameters.

For a new unknown source mesh, `infer_family_candidates()` returns tentative role hints with `requires_review=true`. It must not silently classify or attach to an arbitrary nearby surface.

## Safety and next gate

This repository stage deliberately **does not create a new GitHub workflow, modify Water Purifier V14, or assume a Factorio native port**. Before calling Pipette V0.1 physically verified, run the existing Dens Mortis `OLD-CORE30-homebrew` Windows Blender environment against pinned sources, independently reopen .blend/GLB, inspect a representative connector/bore up close, test the two canonical Water Purifier pipe clearances, and review actual fixed-camera rendered proof.

Blender “one unit” is an authoring size: not real-world inches or millimeters. World gauge/pressure/force/ampacity claims are out of scope until an explicit independently verified simulator is commissioned.

## Optional Factorio tile-scoped fittings

Ordinary `outer_diameter` and visual wire gauges are **direct Blender-unit sizes**. Only an explicitly requested external `tile_interfaces` fitting uses the model's `scene_scope` (units-per-Factorio-tile, 2×2/3×3 footprint and origin), via the shared [FMPL scale standard](../SCENE_SCALE_STANDARD.md).

See [2×2 sample](examples/two_by_two_reference_pipe.json) and [3×3 doubled-scale sample](examples/three_by_three_double_scale_pipe.json). Both use canonical `factorio-fluid-interface-v1` pipe fractions (0.57 outer barrel, 0.49 open bore, 0.68 collar, 0.075 axial thickness in tiles), while their connecting service pipe keeps its own numeric Blender-unit diameter.

The builder creates a real hollow dimension-matched candidate throat/collar/reducer; it is **not** a certified clone of the authoritative FMPL source fixture, nor a proved Factorio fluidbox connection. Independent GLB/Blender geometry checks and real Cycles proof are required.
