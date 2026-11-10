# FMPL scene-to-Factorio tile scope and standard pipe interface — V1

FMPL has **two separate sizing contexts**:

1. **Ordinary Blender geometry**: tubes, wires, cables, hoses, rebar, corrugation and connector detailing are sized directly in Blender scene units (e.g. `diameter=0.08`). Those are visual/relative dimensions and have no real-world AWG, mm, pressure, strength or wire-gauge interpretation.
2. **Factorio tile-relative reference fixtures**: the model scene declares how many *Blender scene units correspond to one Factorio tile*, its 2D tile footprint, model origin and +Z axis. Named canonical pipe hardware then derives Blender geometry from stable tile fractions so that 2×2 and 3×3 machines mate with standard adjacent pipe fittings.

Neither context assumes real-world physical scale.

## Data and authority

- `tools/fmpl/scene_scale.py`: pure-Python, deterministic converter and external mouth alignment validator.
- `tools/fmpl/scene_scale_registry.json`: authoritative presets for 2×2 and 3×3 machines and the measured `factorio-fluid-interface-v1` reference.
- `tools/fmpl/FMPL.json` `asset_units`: canonical default `scene_units_per_tile=1`, optional explicit per-scene override.
- `tools/fmpl/pipette/core.py`: route planner with optional `scene_scope` and `tile_interfaces`, without changing ordinary declared `size.outer_diameter`.
- `tools/fmpl/pipette/blender_adapter.py`: dimension-matching standard pipe candidate with full-sized hollow throat, hollow collar and actual hollow reducer into a separately sized service line. Verified original source collar/throat meshes should be copied where available; a procedural candidate is **not** automatically approved as a source fixture or game prototype.
- `tools/fmpl/test_scene_scale.py`: footprint, scaled flange and strict alignment validation. Pipette adds tests for freeform and tile-scoped pipes.

## Scene scope

Example 3×3 scene:

```json
{
  "schema": "fmpl.scene-scope.v1",
  "id": "purifier-3x3",
  "scene_units_per_tile": 1,
  "footprint_tiles": [3,3],
  "origin_bu": [0,0,0],
  "up_axis": "+Z"
}
```

Its local horizontal boundaries are X/Y ±1.5 Blender units. The 2×2 equivalent has X/Y ±1.0. If an artist chooses `scene_units_per_tile=2`, then a 3×3 model spans 6 Blender units across and the tile-relative pipe fitting dimensions multiply by two. This **does not** double any independently declared 0.08-unit decorative wire or small service hose.

The scope is part of the model's authored spatial context. It must not be inferred from a guessed viewport size or a real-life manufacturer's pipe catalog. The optional `origin_bu` lets a model be offset in a scene without changing its tile proportions. Footprint height (Z) remains model-specific, not silently locked to the width.

## Canonical interface `factorio-fluid-interface-v1`

These measured ratios come from the existing FMPL boiler/condenser pipe fixture, not an arbitrary new standard:

| Dimension | Fraction of one Factorio tile | In default 1 unit/tile scene | In 2 units/tile scene |
|---|---:|---:|---:|
| Barrel outside diameter | 0.57 | 0.57 | 1.14 |
| Open bore diameter | 0.49 | 0.49 | 0.98 |
| Collar outside diameter | 0.68 | 0.68 | 1.36 |
| Collar axial thickness | 0.075 | 0.075 | 0.150 |

A machine-space port needs **an explicit cardinal face**, transverse offset from its side's center and Z elevation expressed as a tile fraction. West/east are X-boundaries; north/south are Y-boundaries. Normals face **outward**. A 3×3 purifier west source port at elevation 0.36 is at `(-1.5, 0, 0.36)`; a 2×2 model's corresponding west reference is `(-1.0, 0, 0.36)`.

The 0.36 elevation is a *Water Purifier/example reference*, **not** a universal mandatory pipe elevation. Other machines must declare their actual measured socket location, facing and approved source fixture. Never infer native Factorio connection cells from Blender model-space mouth geometry.

## Pipette integration

`scene_scope` is optional. Without it, Pipette is purely Blender-unit based, and remains fully useful for small visible wire/hose routing. When a route includes `tile_interfaces`, the planner requires the scene scope and validates each marked external fluid/air/gas socket against its declared boundary location and normal.

Pipette retains the interior line's chosen `size.outer_diameter` (for example 0.095), while its external standard pipe throat remains fixed at `0.57 × scene_units_per_tile`. The transition is a **genuine hollow reducer**, not a solid cap or decorative ring.

The Blender adapter currently generates a **candidate** throat, collar and reducing segment. Production FMPL machines should prefer the *actual approved source mesh fixture*, transformed without scale drift. The procedural candidate is tagged as not game-approved and must pass independent Blender/GLB readback, line and port clearance tests, visual approval and the installed Factorio 2.1 runtime before release.

## Verification gates

- Explicit scale finite, positive; footprint 1–64 tiles per horizontal dimension; +Z required.
- 2×2 and 3×3 examples and arbitrary nonzero `origin_bu` map to exact cardinal boundaries.
- Explicit longitudinal/transverse socket alignment and normals; no guessed Y-offset connections.
- Standard bore/collar dimensions retain 0.57/0.49/0.68/0.075 relative tile fractions.
- Candidate interface keeps the face core open and is not blocked by source framing or smaller service tubes.
- Direct scene-unit pipe thickness never changes when a scene reference changes, unless the author deliberately edits that line.
- Existing Water Purifier external 74-ray side-bore test and immutable source mesh preservation still apply.
- Native Factorio fluidbox and actual adjacent-pipe connection remain separate unverified gates until game execution.

**No real-world measurement conversion is part of this standard.**
