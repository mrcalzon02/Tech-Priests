# FMPL Pipette — typed Blender linework and connector system

**Status:** V0.1 planning contract and bounded prototype. This is a reusable FMPL modeling tool, **not** a live flow, cable-physics, game-fluidbox or Factorio prototype simulator. Pipette never changes source assets automatically.

## Fundamental unit rule

**All geometry is sized directly in Blender scene units.** A value such as `diameter: 0.08` means a Blender tube whose outer diameter is 0.08 scene units. The user may specify `thin`, `regular`, `heavy`, or a numeric size; these are *appearance-oriented presets relative to the machine*, not AWG or millimeter engineering conversions. Wire “gauge” is only a visual label/preset. The system must not infer any real-world diameter, material rating or load capacity. Blender/FΜPL's scene convention happens to place one tile in one Blender unit for Factorio assets; that does not make a tube physically scaled to real hardware.

No `mm`, `AWG`, gauge conversion, psi, bar, force, ampacity or tensile-strength formula is applied by default. Such fields can be optional future simulation metadata, but **never drive geometry without an explicitly authored scene-relative mapping**.

## Orthogonal classification

Pipette's type is more than “pipe or wire”. Describe each member across independent fields:

| Axis | Examples | Geometry consequence |
|---|---|---|
| `family` | rigid_pipe, segmented_conduit, flex_hose, single_wire, wire_bundle, tension_cable, rebar | Shell shape, bend handling, fittings, subdivision |
| `payload` | fluid, air, steam, gas, coolant, power, signal, mechanical_tension, reinforcement, empty | Compatible socket behavior and later game hooks |
| `surface` | FMPL verified material ID; metal, galvanized, polymer, rubber, glass, copper, braid | Visible material and surface profile, **not** physical size |
| `section` | hollow, solid, multi-core, jacketed, corrugated, ribbed | Outer mesh, wall/liner and visible inner geometry |
| `deformation` | straight, orthogonal, hanging, slack, draped, segmented, tensioned | Centerline and joint spacing |
| `end fittings` | flange, compression, hose_tail, cable_gland, lug, clevis, rebar_coupler, capped, none | Real receiving hardware and join behavior |
| `intermediates` | joints, supports, junctions, sight glass, pressure tap, wear sleeve, expansion section | Added only when justified by a route role |
| `behavior hooks` | fluid port id, circuit id, power net id, animated flexible joint, force anchor | Metadata only until supported by verified simulation/game code |

A flexible rubber coolant hose and a flexible rubber-covered wire can look similar but require different end fittings and socket compatibility.

## Authoring schema

Each route record needs `id`, `family`, `payload`, `size`, `path`, `start_socket`, `end_socket`, `material_id`. The requested **`size.outer_diameter` is Blender units**, not a “real” measurement. `wall_fraction` is the wall thickness as a fraction of radius; `visual_gauge` selects relative thin/regular/heavy presets only if numeric outer diameter is absent.

```json
{
  "id": "pump-to-filter-01",
  "family": "segmented_conduit",
  "payload": "fluid",
  "size": {"outer_diameter": 0.09, "wall_fraction": 0.22},
  "material_id": "TP Library | iron",
  "path": {"kind": "waypoints", "points": [[0.0, 0.0, 0.8], [0.3, 0.0, 0.8], [0.3, -0.4, 0.8]]},
  "joint_pitch": 0.18,
  "start_socket": {"id": "pump.out", "xyz": [0, 0, 0.8], "normal": [-1, 0, 0], "role": "source", "payloads": ["fluid"], "parent_mesh": "pump outlet"},
  "end_socket": {"id": "filter.in", "xyz": [0.3, -0.4, 0.8], "normal": [0, -1, 0], "role": "sink", "payloads": ["fluid"], "parent_mesh": "filter inlet"},
  "fittings": {"start": "auto", "end": "auto"},
  "supports": {"pitch": 0.35, "anchor_ids": ["support-1"]},
  "behavior": {"binding": null},
  "keep_outs": []
}
```

A wire bundle instead specifies `conductor_count: 1|2|8|...`, `strand_diameter` as a Blender-unit value or visual gauge, and `sheath_diameter`. Model conductor cores only if they are visible at the ends or in an intentionally exposed inspection section. Do not build unseen internals for completion theater.

## Algorithmic stages

1. **Discover** authorized socket empties/custom properties, existing curves, or annotated source routes; scan unknown mesh ends only as candidates. Name similarity alone **never** certifies a connection.
2. **Classify** family, payload, visible section/surface, flex or tension, and permitted fitting types.
3. **Validate** explicit scene-unit size, count, positive wall thickness and appropriate internal/external diameters. Reject unsupported payload/family combinations and unmated sockets.
4. **Route** straight/direct, explicitly authored waypoints, orthogonal grid, or hanging catenary-like guide. Apply bounded segmentation. Flag keep-out intersections instead of silently crossing geometry. Future auto-route solvers must be deterministic, bounded, observable and refuse ambiguous best paths.
5. **Select fittings** based on payload/socket. A rigid fluid line receives a real union/flange/compression fitting; flexible hose a seated hose-tail/crimp; electrical line a proper cable gland or lug; mechanical tension cable a seated eye/clevis; rebar a lap/coupler. “Brass ring” alone is not a connector.
6. **Build** actual hollow shell or solid member meshes, with a consistent local frame, open bores where needed, gradual radius profiles where specified, real joint sleeves at segment boundaries, and no hidden interior embellishment.
7. **Verify** typed endpoints, direction, true bore clearance, radius and keep-out, connector contact, fixture source provenance and no floating endpoints. Full Blender/GLB reopening and real Cycles camera proof are separate stage gates.
8. **Export** source-preserving Blender collection and role/behavior metadata. Factorio fluidboxes, circuit connections, electricity, wire physics and actual game behavior remain unverified until integrated and tested.

### Family policies

- **Rigid pipe:** hollow wall, constant diameter or explicit reducer, permissible explicit elbows, two seated fluid unions. No sphere used as a fake hollow elbow.
- **Segmented conduit:** repeatable physical sleeve sections and visible **hollow** intersegment joints, `joint_pitch` and capped segment count; payload can be fluid/air/gas or wires if connectors agree.
- **Flexible hose:** routed curved/draped envelope, declared visual corrugation pitch if desired, bend hints, physical hose tails/clamps at both ends. No “flexible” label on a straight rigid cylinder.
- **Single wire / wire bundle:** solid insulated strands or sheath. Conductor count, loose vs bundled, bundling/twist pitch, visible fanout and dangling slack; not a hydraulic flange.
- **Protective conduit carrying wires:** hollow visible sheath and optional internally visible 1/2/8 conductors only where accessible; matching two cable glands. Conduit geometry and wire contents are independent.
- **Tension cable:** solid cable or visible braided sheath, hanging sag/near-taut mode, paired load anchors/eye/clevis/turnbuckle, not fluid fittings. “Tension” metadata is not force simulation.
- **Rebar:** solid ribbed bar with relative rib-pitch and explicit bend/lap/coupler to concrete or reinforcement seat. No hollow bore.
- **Viewports/inspection sections:** real glass/witness or open inspection fixture with a known function; don't add viewport windows at arbitrary intervals merely for complexity.

## Relative visual presets

Visual presets are **appearance choices** and intentionally have no correspondence to manufactured sizes.

| Size label | Suggested Blender outer diameter | Use |
|---|---:|---|
| hairline | 0.012 | Small exposed wire/high-resolution proof |
| thin | 0.025 | Signal line, service tube |
| regular | 0.060 | Small pipe, sheathed cable |
| heavy | 0.120 | Visible trunk/industrial hose |
| massive | 0.250 | Major process main |

These are editable defaults, not requirements, tolerances or mechanical standards. The numeric value `size.outer_diameter` always overrides the named preset. Different scene profiles can later provide their own visually appropriate preset values.

## Safety and quality gates

- Original objects and canonical Factorio connections remain source-preserved; route constructs in a named removable collection.
- **Never place a support, bolt, liner, coupling or conductor inside a protected 0.49 Blender-unit pipe bore** on the Water Purifier; reuse the existing 74-ray or better structural clearance check.
- No generic “match nearest” snap without a compatible socket and explicit authorization. Keep-out volumes are blocker flags, not something to ignore when computing a pretty route.
- Preserve one canonical 45-degree production camera and current 64/128/256 sprite standards. Only construct details that are visible in that camera or required to support visible geometry.
- Reuse approved FMPL PBR assets by exact material IDs, without silently substituting unrelated colors or unlicensed assets.
- A successful type/planner unit test is **not** a Blender artifact, installed prototype, physics simulation, fluid transfer or visually approved connection.

## Roadmap

**P0 (v0.1):** Blender-unit schema/presets, classification, explicit sockets, compatibility and fitting selection, bounded waypoint/direct/hanging paths, segment records, deterministic plan receipts and Python unit tests.

**P1:** Native Blender generator of real hollow/solid mesh sections, segmented sleeves and terminal hardware; test actual .blend/GLB saved/reopened with source hashes. Keep a separate fixture preview .blend rather than modifying a production model.

**P2:** Connector library and placement search from real FMPL sockets, collision/clearance/BVH and measured auto-routing; unit-test ambiguous matches and blocked routes.

**P3:** Multiple conductor bundles, exposed fanout, corrugation/rib profiles, strain relief, catenary/cable sag and bend-radius constraints; visual behavior hooks for motorized segments, slack and service movement.

**P4:** FMPL/Girderization collaboration: endpoint audit of the Water Purifier V14 and subsequent machinery with 100% classified real visible line terminations and actual rendered proof. This is NOT automatic approval of unknown source geometry.

**P5:** Optional actual game adapters, Blender drivers and user-defined live mechanical/flow/circuit simulation behaviors, developed and tested independently, with no promises about functionality before native integration.

No new workflow or runner registration is needed for the standalone pure-Python planner. Future Blender proof uses the existing Dens Mortis worker and a source-pinned, bounded request.
