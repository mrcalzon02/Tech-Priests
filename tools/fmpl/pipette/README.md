# Pipette — Blender-unit typed tubing, wiring and coupling planner

**Current state: V0.1 source-level prototype.** The [authoritative design and development stages](PIPETTE_STANDARD.md) define the planned typed Blender construction subsystem. This is not yet a visually approved 3D asset library or a fluid/electrical/force simulation.

## The size rule

All sizes are **relative Blender scene units**: `size.outer_diameter: 0.08` makes the visible tube 0.08 Blender units wide. `visual_gauge: thin` is an appearance preset, **not** AWG or millimeters. No real-world conversion is performed or required. Outer diameter, tube-wall fraction, segment spacing, sag, wire diameter, winding pitch, corrugation and rebar ribbing are specified directly in Blender units or dimensionless fractions.

## Module layout

- `PIPETTE_STANDARD.md` — classification, parameterization, physical coupling rules and staged development gates.
- `core.py` — **pure Python**, no Blender required. Rejects invalid family/payload/fittings/sizes/sockets, constructs bounded centerline/segment plans, flags unverified socket-facing and preserves source protections.
- `blender_adapter.py` — isolated **prototype Blender mesh builder**. Consumes a validated plan and creates named editable visible tube, hose, cable and rebar geometry with terminal fitting meshes, without modifying source files. Actual native .blend/GLB reopening is a further gate.
- `test_core.py` — 31+ pure Python regression cases for sizing, family compatibility, route keep-outs, fittings, wire counts and hanging/slack guides.
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
