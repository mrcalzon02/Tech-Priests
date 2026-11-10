# FMPL Pipette — verified scene-tile reference pilot (2×2 and 3×3)

**Status:** source-level unit tests and isolated Blender 5.2 prototype builds **passed**. Preview-only fittings, not yet owner-approved native FMPL donor geometry or Factorio 2.1 runtime-connected prototypes.

## Reproducible provenance

- Canonical source: `mrcalzon02/Tech-Priests` exact commit `5c58eee36786270b1c2fa6d5e8205072b719b6e9` (module manifest `0.4.2`).
- Dens Mortis self-hosted runner: **OLD-CORE30-homebrew** using the preexisting single `runner-controller.yml` worker; [completed-success Actions run #42918149893](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42918149893), request commit `dd4df71448372dfc901fbc41651f112f22646ad7`.
- Full Actions artifact `13810168163`, `dens-mortis-worker-42918149893-1` (~1.16 MB ZIP); includes four editable `.blend`, four genuine `.glb`, four independently rendered Cycles PNG, per-fixture route/mesh/QA JSON and runner stdout/stderr.
- Worker `repair-and-test` completed successfully; an ancillary status job returned an unsuccessful conclusion. Use the actual production receipts and artifact, not just status-side reporting.
- **46 Pipette unit tests and 16 FMPL scene-scale unit tests passed.** Blender/GLB independent reopen passed on all four examples. Actual lit Cycles pixels measured independently; no black/empty proof passes.

## Resolved scale model

**Unscoped:** regular wire/tube diameter `0.08` means 0.08 Blender scene units. No AWG/mm conversion and no dependency on machine footprint.

**Scoped:** `scene_units_per_tile`, `footprint_tiles`, `origin_bu`, `up_axis=+Z` permit an explicit machine-to-Factorio tile reference. A 2×2 machine defaults to XY ±1 Blender unit; 3×3 defaults to ±1.5, and an alternate scene may author 2 Blender units per tile. A specific `tile_interfaces.start/end` gives cardinal face, transverse offset and elevation; missing/misaligned normals fail closed.

| Standard fitting in Blender units | 2×2 @ 1 unit/tile | 3×3 @ 2 units/tile |
|---|---:|---:|
| Full barrel outside diameter | 0.57 | 1.14 |
| Genuine hollow bore inside diameter | 0.49 | 0.98 |
| Full collar outside diameter | 0.68 | 1.36 |
| Collar axial thickness | 0.075 | 0.150 |
| External west mouth X | -1.0 | -3.0 |
| Declared elevation Z for example (0.36 tiles) | 0.36 | 0.72 |

Both reference candidates passed measured Blender solid geometry diameter checks and **5 independent centerline/offset ray-clearance probes per open mouth**; their internal service pipes retain separately declared diameters (`0.095` and `0.120` respectively). They transition to standard external throats with real hollow reducers, rather than extending a small tube through the external bore face.

## Native build and pixel evidence

| Pilot model | Blender meshes | GLB readback | Actual Cycles lit pixels | Physical standard interface |
|---|---:|---:|---:|---|
| Eight-wire hanging loom | 11 | 11 | 5,176 | N/A |
| Segmented fluid tube | 12 | 12 | 10,289 | N/A |
| 2×2 standard fitting | 6 | 6 | 26,339 | 1 fitted throat / 5 rays clear |
| 3×3 double-scale fitting | 6 | 6 | 23,129 | 1 fitted throat / 5 rays clear |

The generated fitting is intentionally tagged `dimension-matching candidate`, **not** the approved source mesh. Its geometric proportions match the same FMPL `factorio-fluid-interface-v1` reference used for existing boiler/condenser and Water Purifier pipe alignments. Production should import a measured approved donor fixture when available, or obtain visual and game-native approval before adopting the parametric candidate.

## Relevant code contracts and future work

- `tools/fmpl/scene_scale.py` and `scene_scale_registry.json`: scene/footprint scope, proportional fittings and explicit model-port checks.
- `tools/fmpl/SCENE_SCALE_STANDARD.md`: rationale and tile-versus-scene separation.
- `tools/fmpl/pipette/core.py`: optional scope and type compatibility without altering an ordinary line's Blender-unit `size.outer_diameter`.
- `tools/fmpl/pipette/blender_adapter.py`: source-safe real hollow throat, full collar, sized reducer and distinct service line.
- `tools/fmpl/pipette/verify_native.py`: independent reopen, 5-ray central bore clearance, actual Cycles image brightness and GLB reimport.
- `tools/fmpl/test_scene_scale.py` and `tools/fmpl/pipette/test_core.py`: relative tile sizes, footprint boundaries, normals, ambiguity and no-real-world conversion policy.

This pilot does **not** claim true service pressure ratings, wiring ampacity, mechanical tension physics, actual installed Factorio fluidbox connections, owner visual approval or Water Purifier V14 integration. No production model changed, no additional workflow was created, and no model/inference download was performed. Existing Factorio game-side tests remain a separate release gate.
