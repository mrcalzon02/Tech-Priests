# FMPL Girderization — proposed reusable structural-construction submodule (design v0.1)

**Status: specification only. No generator, model modification, deployment, or runner job is authorized by this document.** The first proposed pilot is the Water Purifier V14. Girderization is a purposeful structural refinement, **not** decorative greebling and not a blanket “add more bolts” effect.

## Definition and design contract

**Girderization:** convert a plain visible load-bearing strip, plate, bar, or housing support into a mechanically legible steel/cast-iron structural assembly **without changing its intended silhouette, supports, mating interfaces, or source provenance**. A support must communicate what it carries and where its forces go. A conduit must communicate where and how it is attached. A control housing must actually contain the embedded screen and controls.

Input to the future module: source immutable mesh and approved derivative; its mechanically interpreted role; endpoint/socket coordinates and normals; load-path anchors; keep-out volumes; materials from approved FMPL fixtures; the single Factorio 45-degree production camera and expected pixel scale.

Output: source-preserving separately named derived Blender meshes, a machine-readable operation/anchor ledger, a verified attachment graph, actual rendered proof, and GLB/sprite-safe exports. The module must **not** silently repair unknown objects or invent unprovided mechanical roles.

## Classification before creating geometry

Record one of these semantic roles per target:
- `primary-load`: bridge, upright, main chassis, pedestal supporting motor/shaft
- `secondary-stiffener`: gusset, channel, reinforcing lip, crossbrace
- `bearing-or-drive`: motor isolation, bearing saddle, torque-transfer housing
- `service-panel`: cast inset, removable plate, framed access area
- `fluid-joint`: rigid pipe union, flange, gland, nozzle/bulkhead fitting
- `flexible-joint`: hose tail, compression nut, ferrule, clamp, grommet
- `electrical-joint`: cable gland/strain-relief, terminal-box penetration
- `protected-interface`: source-native fluid port/bore, rotating part, transparent viewing window, CRT screen/buttons, glass vessel, dynamic fluid surface
- `decorative-only`: rejected for Girderization unless given a justified attachment/use

A proposed change requires **a cited source object**, a named physical purpose, the actual anchored start/end geometry, and a list of occupied keep-out volumes. Unidentified bolt clusters and arbitrary panel overlays are non-progress.

## Permitted operation families (future reusable builders)

| Operation | Visible result | Required physical justification |
|---|---|---|
| `section_profile` | Box section, C-channel, I/T-beam silhouette, stiffened folded plate | Load-carrying bar retains its envelope and both anchor ends |
| `edge_flange` | Raised lip/return, edge roll, thickness reveal | Real edge/stiffness or removable housing seam |
| `inset_panel` | Recessed panel surrounded by continuous frame, service screws | Panel access or large flat enclosure surface; no display/button overlap |
| `joint_gusset` | Triangular/diagonal rib connecting existing members | Explicit member-to-member contact at both ends |
| `foot_plate` | Bolted landing shoe/clamp around a real chassis or metal vessel seat | Transfers weight to supported structure, not glass/void |
| `bearing_saddle` | Real ring/collar/fastened bracket for shaft or gearbox | Supports motor or bearing without colliding with rotating shaft |
| `flanged_union` | Matching tubular connector, gasket, bolted collar, seated rigid tube | Physically mated two-ended rigid fluid line; flow path remains open |
| `compression_fitting` | Gland/ferrule/retaining nut at small hardline or hose | Axis-aligned line end seated into named housing boss |
| `hose_tail` | Barb/spigot, crimp ring/clamp, flex-bend support | Flexible connection genuinely terminates into machinery |
| `cable_gland` | Metallic/insulating grommet and strain relief | Electrical armored conduit passes through terminal plate |
| `bolt_pattern` | Repeated fasteners around actual flange or plate | Fasteners sit on paired fastening surfaces; no random stud scatter |

Operation ordering: **functional contact → correct cross-section → edge lips/recesses → limited fasteners → restrained PBR/material wear → rendered QA**. Rivets do not manufacture a load path. A brass ring is not an adequate pipe connection by itself.

## Mechanical and visual constraints

1. **Preserve source.** Original 50 MH7 meshes, 136 V04 process meshes, original animations/material provenance and their hashes remain intact. Replace their visible appearance only with explicitly named derived geometry; keep source originals recoverable.
2. **Protect all keep-outs.** No new material inside either 0.49-tile Water Purifier side port bore (74-ray minimum), the original 0.68-tile collar envelope, glass viewing region, spinning impeller swept volume, fluid surface animation space, vent throat, sample tanks, screen or switch travel. Preserve the 3x3 tile overall envelope.
3. **Land every load path.** The full structural path must terminate on metal chassis/vessel reinforcement or concrete via seated shoes; no top gearbox pedestal shall simply touch glass or end in a red nub. A source gap is not repaired by adding decorative bolts to the free end.
4. **No unseen mechanism fetish.** Only geometry visible at the fixed Factorio export camera or needed to make a *visible* support attachment is in scope. No hidden undersides, internal gearing or unseen rigging.
5. **Preserve approved design language.** Use existing verified FMPL steel/iron/ferrocrete/brass PBR and validated fixture sizes. Unverified private greebles/texture donors remain quarantined.
6. **Manage pixel budget.** A small fastener not distinguishable at 128/256px should not accumulate in dozens; choose a few correctly located larger gussets, flange lips or anchor groups. Render the 64px gameplay projection before approving fine detailing.
7. **No floating couplings.** For every line, locate the actual endpoint, receiving bore/boss, local axis, seal, gland, service access, and physical mount. Cylindrical bore must stay hollow from external mouth into its supported reducer.
8. **Avoid status laundering.** Source count/GLB import and script success prove technical construction, **not** owner visual approval, Factorio prototype connection or gameplay. Render inspection is separately required.
9. **Do not multiply CI.** One existing Dens Mortis worker, one source-pinned request, no new matrix/workflow, no force-push or unrelated release.

## Planned package, interfaces and tests

Proposed directory once design review is complete:

`tools/fmpl/girderization/`
- `GIRDERIZATION_STANDARD.md` (this document, **design only**)
- `role_registry.json`: each original and derivative object role, source SHA, endpoint fixture IDs, clearances, operation IDs, visual priority
- `fixtures.py`: deterministic mesh constructors for section profiles, gussets, footplates, inset panels and unions; no arbitrary name-based auto-assembly
- `attachments.py`: explicit contact/endpoint classification; no blanket closest-surface snapping
- `verify_girderization.py`: source hash checks, contact graph, keep-out ray/BVH, duplicate/missing fittings and loop/test-camera probes
- `test_fixtures.py`: small headless fixture tests independent of any real Water Purifier scene
- `examples/water_purifier_v14.json`: source-pinned pilot selection and declared assumptions

Preferred future operation fields: `operation_id`, `source_object_name`, `source_digest`, `role`, `reason`, `parent_anchor`, `child_anchor`, `normal`, `load_path_group`, `socket_size`, `keep_out_ids`, `material_fixture_id`, `target_visibility_px`, `derived_objects`, `QA_status`. Required fields vary by operation, but any undefined parent or contact is a hard stop.

Verification should establish a mechanically meaningful contact graph: gearbox → bridge/bearing → pedestal/gusset → **metal** vessel collar or chassis upright → foot/plinth; each edge has an explicit measured contact point, not an inferred proximity based on a screenshot. Start with **≤0.015 tile** world-space contact gap for intentional metal-to-metal joints (adjust only with evidence). Pipe axes/mouth centers must match their declared socket fixtures; reject oversized reducers, collisions and open line endpoints.

## Proof and release gates

**Design gate G0:** inventory source meshes/routes, classify roles, define supported nodes/keep-outs and review the intended geometry on the actual source. No Blender modifications or worker dispatch.

**Pilot gate G1:** build and unit-test only minimal authentic support and coupling fixtures. Source hashes unchanged. Check one I/C/box section, one gusset, one foot, one rigid union, one compression gland and one electrical gland in isolation.

**V14 application gate G2:** replace the exact identified console backing defect and selected supports; add individually justified fittings at audited pipe/hose/electrical terminations; never auto-greeblize all components.

**Native proof G3:** independently reopen .blend, reimport GLB, verify full source mesh/animation/hash contract, contact graph and 74+ side-bore rays; render full 512px and 256px source-camera samples with tight console and support closeups. Effect isolation proves visible changes, not just additional mesh count.

**Integration G4:** produce existing eight-frame/one-angle 64/128/256 atlases and all original V12/V13 water, CRT and steam regression checks; actual Factorio 2.1 prototype/fluidbox/runtime connection remains unverified until tested in-game.

**This specification intentionally does not deploy the Girderization module or schedule a V14 build.** See the separate Water Purifier V14 work order for the selected model operations and planned runner handoff.
