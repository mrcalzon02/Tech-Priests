# TP-MH7 cumulative component library — construction/verification contract

This document is **binding** for the same seven-machine order as `AGENT_BUILD_ORDER.md`. Do not spend the entire run creating a general game asset framework. Build real machines first and distill reusable geometry **after** each accepted saved-scene checkpoint. Preserve ownership and source provenance; do not treat unrelated meshes or the AI concept sheet as authoritative interchangeable parts.

## Two layers

**Immutable masters**: 
`art/source-to-3d/shared-parts/metallic-hydrogen/components/<part_id>/<revision>/` contains a parameterized Blender Python builder (or a supported native .blend component collection), packed/material sources as applicable, a real rendered thumbnail, a source hash/manifest, and any test scene. 

**Local assemblies**: each machine's authored `.blend` and generator append the registered part and own a **local instance**, placing it via an explicit named attachment transform. Do not link a mutable master so that changes to the library silently alter previously finished machines. Keep editable source and an exported reimportable GLB for the final whole machine. The instance records `tp_part_id`, `tp_part_revision`, `tp_part_source_sha256`, `tp_local_instance_transform` and material-override/procedural parameters in machine `part_provenance.json`.

## Semantic families — start only with existing valid examples

- **Pipe-fit**: true hollow tubes, calibrated collars, bore/flange seat, chassis transition, supported elbows/Ts, valve mounting bosses, reusable native cap mating jig. The boiler/condenser fitting is a *calibration reference*; every unique machine's actual native port remains independent and can be null.
- **Structural**: tapered cast foot/shoe, anchored red haunch and gussets, open I-section girder, pressure-shell saddle, braced overhead rail, bolted mounting plate. Avoid decorative braces that attach to nothing.
- **Service/control**: modular green monochrome recessed CRT and its case, compact red/amber/green/dark buttons, safeguarded switch, cable strain-relief, instrument box/gauge mount. Use real cogitator/emergency sprites as visual authority. Do not create labels or on-surface text.
- **Process equipment**: filter-cartridge holder, bearing housing, roller saddle, ram guide, supported auger, valve body, retaining ring, canister seat. Only elevate to reusable once construction proves an actual use and real geometry/kinematics where needed.

## Registry format and versioning

Initialize `registry.json` from `PARTS_REGISTRY_TEMPLATE.json` (if absent); the template intentionally contains **zero approved parts**. Each part entry records:

- Stable `part_id` (lowercase, scoped to family) and immutable `revision` such as `v01`, with `derives_from` for adaptations. Different physical dimensions or anchor semantics require **new revision**, not replacing an earlier master.
- Source repo/path, original scene/object/collection, source SHA-256, origin machine, ownership/license, first recorded capture, generator+blend paths and hashes, and dependencies. No missing origin passed off as native geometry.
- Geometry: 1 Blender unit = 1 tile, local XYZ pivot, canonical axes, bounding box and a list of **named anchors** (`position_xyz`, `outward_normal`, `connector_type`, `provenance`, `tolerance_tiles`). Values unknown until measured use null; body axes/rotation must be transformed and remeasured for every consumer. Distinguish `cosmetic`, `mechanical`, `fluid`, `item` and `electrical` anchors.
- Material slots/texture map sources, actual Blender/GLB roundtrip checks, real rendered thumbnail, reuse count and consumers (machine path + transform + frozen part revision + hashes).
- Explicit `candidate`, `verified`, `deprecated` status; only fully checked, compatible parts are `verified`. Do not promote generic geometry from an image-generation render or treat a test scene as evidence of in-game connectivity.

Persist changes through a temp file + atomic rename, record registry SHA-256 at each machine checkpoint, and never delete a registered revision to make a newer one look unique. Keep staging geometry and test captures ignored until they pass. For a stale/changed registry, detect conflicts before merge; do not overwrite another agent's work.

## Required model→library→model loop

1. **Stage 01 Water Purifier:** build, save native file, render and independently reopen. Identify 0–5 truly reusable components (e.g. one fitted collar, one load-bearing shoe, one cogitator housing), normalize their local axes/anchors and promote those which pass independent import/QA. An empty registry is allowed if geometry is not actually ready, but the deficiency remains open.
2. **Before Stage 02 Electrolyzer:** load registry, select only parts whose mate/socket geometry, visual scale and process purpose fit; append an independent revision-locked copy. Build new one-off geometry for unique cells. Document actual reused part ID/revision and show an imported instance in the rendered machine. If no suitable part exists, explain and continue rather than forcing reuse.
3. **At every later stage 03–07:** repeat *look up → append or parameter-adapt → seat/fit → build unique functional geometry → render → independent reopen → harvest/test/promote → checkpoint*. Adapt geometry via parameters, not wholesale distortion or changing old masters. Collect only useful variants rather than duplicating the same 20 cast feet under new names.
4. **At final handoff:** use a fresh Blender session (no cached meshes) to load a registered component, reconstruct one clean test fixture with the recorded transform, render a true image, and verify source/registry SHA-256. Report the registered parts, their consumer machines and revisions, unpromoted candidates, actual reuse locations, and any blocked source/cap/port work.

## Gates for promoting a component

A part can only move from `candidate` to `verified` if a real authored saved Blender scene contains it, source files and any textures exist with hashes, origin and dimensions are recorded, named anchors are finite and documented (unmeasured native cells remain null), one genuine preview shows contact and no impossible intersections, independent Blender reopen/append works, and the tests were run rather than simply claimed. The first verified use counts; no need to invent repeated uses to satisfy a quota. **The absence of a reusable part does not block rendering the next machine.**

## Efficiency and safety

Do not create a background service or GitHub Actions matrix. One local agent and one Blender render process at a time. Limit part extraction to genuinely reusable components after each machine; avoid giant shared source scenes, detached texture directories, or duplicated complete machines. Preserve every prior model and the original v0.2 references. Library work counts as progress only when it produces a usable, re-openable piece of physical geometry and aids the next actual machine.
