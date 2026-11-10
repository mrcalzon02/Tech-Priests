# FMPL — Factorio Modeling Production Library

A **versioned, shared, source-indexed production module** for Tech-Priests, Tanks-for-bob-Fork, HB-TTRPG-tools and future Factorio projects. This is a working *inventory and standards API*, not a new GitHub Actions workflow, third-party asset dump or replacement for existing validated art tooling.

## Contents

- `FMPL.json`: canonical index of complete machine source states, 23 PBR presets / 69 maps, 39 component candidates (21 bunker plus 18 emergency-machine donor candidates), 17 existing programs and four real pipeline recipes.
- `art/source-to-3d/shared-parts/industrial-asset-library/catalog.json`: provenance, original texture blob identities, material families, donor assemblies and source references. Its `import_materials.py` imports packed Blender nodes and textures from committed source files.
- `art/source-to-3d/shared-parts/metallic-hydrogen/registry.json`: **empty verified** component registry (versioned future candidate promotions). Proposed parts stay in the candidate inventory until measured.
- `checkpoints.json`: append-only versioned evidence ledger for future iterative runs, guarded by optimistic SHA-256 readback.
- `fmpl.py`: standard-library-only CLI: `summary`, `list`, `show`, `validate`, `record`, `digest`.

## Query the combined library

```sh
python tools/fmpl/fmpl.py summary
python tools/fmpl/fmpl.py list --kind model
python tools/fmpl/fmpl.py list --kind program
python tools/fmpl/fmpl.py list --kind pipeline
python tools/fmpl/fmpl.py show emergency-boiler-v08
python tools/fmpl/fmpl.py validate --root .
python tools/fmpl/fmpl.py digest
python -m unittest discover -s tools/fmpl -p 'test_*.py'
```

All commands work without Ollama, Blender, GitHub token or network. `validate` checks schema, uniqueness, pins, source-model distinctions and the installed catalog's expected contents. With `--check-files` it checks all local Tech-Priests source files and texture maps. External repositories are **pinned as references**, not mistakenly expected under this checkout.

## Use from another GitHub repository

The **canonical home is Tech-Priests/tools/fmpl**, and consumers keep a fixed FMPL source commit in their `fmpl-consumer.json`. A consumer can acquire only the needed paths with a partial sparse checkout to avoid duplicating large native Blender scenes:

```sh
git clone --filter=blob:none --no-checkout https://github.com/mrcalzon02/Tech-Priests.git fmpl-source
cd fmpl-source
git sparse-checkout init --cone
git sparse-checkout set tools/fmpl art/source-to-3d/shared-parts art/source-to-3d/martian-bunker/src/v10/textures
git checkout <FMPL_PINNED_COMMIT>
python tools/fmpl/fmpl.py validate --root .
```

Then call the material importer with that checkout as repo root in Blender, or read the FMPL JSON registry. **Do not treat a partial sparse checkout as missing complete models**; use the per-entry `source.repository` and `source.ref` fields to retrieve only the assets needed.

Note: some large Git repositories may still download significant metadata; reuse an existing local Tech-Priests checkout when available. FMPL's external consumer adapters do not mutate repositories or run workflows automatically.

## Provenance and production gates

The complete editable model, part, PBR material, tool program, sprite capture, atlas, Lua registration and native Factorio object are **separate asset states**. "Model saved" is not "game ready." In particular, preserve source-specific actual pipe planes and check them against native Factorio pipe grid and sprite offsets. Never fake native cap connections. Keep one Factorio-size screenshot and the original scene/render proof for review.

A candidate component becomes `verified` only with real .blend source, SHA-256, measured attachment transform, named anchors, a tested append/reopen, and a visual inspection. A model is not `approved` without explicit owner review. The same standards apply to incremental local inference: Qwen proposes only bounded geometry; Blender scripts own file modifications.

For a new versioned event, create a JSON record containing `event_id`, `asset_id`, `asset_kind`, `revision`, `state`, `source_sha256`, and `evidence`. Then:

```sh
python tools/fmpl/fmpl.py digest
python tools/fmpl/fmpl.py record --file candidate-event.json --expected-sha256 SHA_FROM_DIGEST
```

The register command uses temp-file atomic rename, rejects duplicate events, validates evidence requirements and does not overwrite older revisions. The published checkpoint ledger must then be committed with the actual sources and read back. A pass from the CLI is not a GitHub commit.

## Family libraries and donor equipment

**Bunker:** weathered cast iron, machined steel, oxide paint, grease, brass, ferrocrete, sensor glass; functional donor candidates in the existing packed Blender scene.

**Emergency miner:** source-matched panel casting, cable glands, junctions, bolts and secured hoses. No hidden ablator internals.

**Boiler:** native V08 270-mesh production scene and validated static G5 interchange; steam jets, pipe joints, cage, valves and canister mounts.

**Condenser:** V21 actual hollow receiver/neck mesh and material transition at x=1, y=-.5, z=.36 for its 2×2 body. The editable V21 package is linked externally, not falsely claimed checked in.

**Assembler:** reference sprite exists, but no distinct approved 3D source found in the verified repository paths. Do **not** substitute the timber workbench source.

**Tanks-for-bob:** distinct pipeline for campfire, workbench, pipe-connection reference and Factorio mod graphic attachment; source paths are pinned in FMPL.json.

## Next step

Use `FMPL.json` to select existing source, PBR and named parts before proposing new hardware, then produce, checkpoint, audit and register the exact artifact. Add actual next-machine and exporter records after each verified run. No giant matrix of tasks; reuse existing single self-hosted worker.

## External Blender design-language donors

Private Google Drive Greebles.blend is indexed as greebles-drive-2026-10 in FMPL.json. See tools/fmpl/greebles/README.md for the pinned source, local runner cache, source probe, Blender index and non-destructive append adapter. Discovery: python tools/fmpl/fmpl.py list --kind library. No binary is copied into public Git, no extra workflow is created, and no donor is automatically approved for mechanical connections.

### Emergency-machine component harvest

The FMPL candidate registry now indexes 12 specific boiler V08 meshes (cage, valve, flange, gauge, manifold and support parts), the V21 fused condenser outlet, and five Emergency Miner Blender generator operators. Their names come from actual committed source/roundtrip evidence; all 18 are **candidates**, not independently extracted and approved physical parts. The emergency assembler remains a sprite-only reference until its correct native source is recovered.

## FMPL v0.2 geometry-first donor pipeline

The Greebles source has 320 individually indexed **unclassified** mesh
candidates; staged scripts support resumable geometry-only Blender
extraction, exact SHA-256 checkpointing, independent native reopen checks
and labeled two-view contact sheets. The original nine materials are
placeholder references, not replacements for approved FMPL PBR presets.
See [greebles/DEATLASE_PLAN.md](greebles/DEATLASE_PLAN.md).

[external_sources.json](external_sources.json) distinguishes actual native
mesh donors, third-party 2D render catalogs, published Wube 3D printable
meshes and official rendering/geometry methods. Every external import must
pass [asset_source_gate.py](asset_source_gate.py) at an individual-file
rights and source-format level. No binaries or additional workflows are
added to Git.

## Process machinery foundation and flow standard (v0.3.0)

See [PROCESS_MACHINERY_STANDARD.md](PROCESS_MACHINERY_STANDARD.md). Actual modeled parts, glass agitator, steam keys, concrete and service-paving PBR, real inlet-to-outlet connections and independent native/GLB validation now have standalone scripts under production_smoke. Approval requires actual runner evidence and visual review; the original machine and Factorio prototypes are immutable.

## Native-geometry fallback bridge (workspace exercised)

The `greebles/native_bridge` directory holds a pinned, read-only Blender 5.0 binary geometry extractor and OBJ/GLB verifier, exercised against the private Drive source in an internal workspace: 320 meshes, 2,828,171 vertices and 5,610,509 original polygons. The companion private geometry package has receipts, GLB readbacks, 640 geometry previews and 16 contact sheets. No private source or extracted binary is publicly committed. Native Blender `.blend` conversion/reopen and native Factorio port integration are still separate gates. The independently supplied `factorio-tank-chaffe.zip` is now indexed but its redistribution rights are unresolved.

## Water Purifier v03 technical validation

[OLD-CORE30 run #42715980695](https://github.com/mrcalzon02/HB-TTRPG-tools/actions/runs/42715980695) passed. 50 source meshes were preserved, 114 process meshes built, 155 reimported in GLB, 30 packed PBR textures, and four N/E/S/W static frames produced in 64/128/256 RGBA atlases. The glass agitator and steam are keyed, but animated sprite atlases, visual acceptance, and native Factorio pipe connections are NOT yet proven. See `tools/fmpl/checkpoints.json` event `fmpl-water-purifier-42715980695-1` for exact hashes. The runner artifact has 14-day retention; the native binary is not yet permanently committed.

## FMPL v0.3.1 camera and pipe-coupling correction

Fixed (nonrotating) machinery now exports one actual boiler-derived 45-degree/zero-azimuth orthographic camera. The Water Purifier has two model-grid-centred exposed mouths at X±1.5/Y0, not arbitrary offsets, using copied canonical hollow collar/throat meshes with bolted seats and cast reducing manifolds. Four directional views are reserved for rotatable prototypes only. Native Lua pipe-cell positions still require the actual entity prototype and real Factorio validation. See [PROCESS_MACHINERY_STANDARD.md](PROCESS_MACHINERY_STANDARD.md).

## Required view and camera discipline (FMPL v0.4.0)

The single authority is [CAMERA_CAPTURE_STANDARD.md](CAMERA_CAPTURE_STANDARD.md). Entities render from one fixed 45-degree orthographic camera with four object rotations; items render exactly one icon frame. Temporary inspection cameras are discarded in-memory before saving and cannot appear as alternate outputs. The production render worker saves a one-camera derivative and records the removed legacy camera names without changing the input scene on disk. The Greebles visual index now also uses one canonical icon-view render per part.

## Water Purifier v04 - camera/connector technical receipt

The corrected single-view export passed [run #42722511833](https://github.com/mrcalzon02/HB-TTRPG-tools/actions/runs/42722511833), reusing the [verified Blender/GLB #42721689714](https://github.com/mrcalzon02/HB-TTRPG-tools/actions/runs/42721689714) despite the first run's atlas packing failure. A single 45°/0° orthographic camera and 64/128/256 RGBA sprites were recorded. Two model-space centered 3×3 edge joints use full hollow 0.49 bore / 0.68 collar with eight fasteners each; the independent annular mating residual was 6.14e-8 tiles. Original 50 meshes are preserved, with 136 process meshes and 175 reimported GLB meshes. The exact hashes are in `checkpoints.json`. **Native fluidbox connection and item/entity suitability are not yet tested or user-approved**; the model is not installed in a game release. The artifact has time-limited retention, so preserve a permanent approved source before expiry.

## Super Greeble V01 construction pipeline

The v0.4.1 Super Greeble builder adds purposeful pump drives, serviceable filters, working pressure hardware, visible before/after fluids, conduit, thermal fittings and keyed effects on top of the verified V04 Water Purifier. It leaves the fixed camera and two boiler-standard fluid collars untouched. This is a new candidate until the native runner evidence passes. The private donor remains provenance-only until individual meshes are visually accepted. See [SUPER_GREEBLE_STANDARD.md](SUPER_GREEBLE_STANDARD.md).

## Super Greeble V01 actual Dens Mortis production checkpoint

[Private Dens Mortis Actions run #42739292638](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42739292638) passed after repair of twelve generic Blender bubble names. It preserved 50 original MH7 and 136 previously verified process meshes, added **177 physically justified detail meshes**, independently reimported 352 GLB meshes, retained the one boiler-calibrated camera and exact 0.49-tile open-bore/0.68-tile collar reference geometry, and verified 27 packed PBR maps. Pump rotor, two gauge needles, and twelve treatment bubbles were keyed and checked. One idle and eight working frames produced six 64/128/256px RGBA atlases with valid alpha. Exact content SHA-256 values are in `tools/fmpl/checkpoints.json` under `fmpl-super-greeble-v041-dens-42739292638-1`. The source and production archive are retained in a **private 14-day Actions artifact**, not yet permanently promoted. The private Google Drive Greebles donor was unavailable locally and **was not** grafted into this exported model. Visual owner acceptance, native Factorio fluid-port linkage, engine integration, and permanent model archival remain open.

## Procedural effects/materials library extension

The [FMPL Effects Library v1.0](effects/README.md) adds **28 procedural material candidates** and five looped geometry-emitter rigs for water, oil, lava, chemical fluids/vapors, glass, steam/smoke, flame/plasma, heated and fractured steel, cracked mud and snow. Its separate [effects registry](effects/presets.json), [Blender builder](effects/build_library.py), [native reopen verifier](effects/verify_library.py) and [production standard](effects/EFFECTS_STANDARD.md) are additive to the existing **23 verified source-indexed PBR presets** (69 texture maps). This extension has its own version: the base FMPL module version and existing consumers are not silently repinned.

A committed builder is **not** a finished native asset: the real `.blend`, images, animation and SHA-256 receipt must be generated and independently verified on Dens Mortis's authorized self-hosted Blender runner. Approved game sprite installation and expensive physical-fluid simulation remain separate gates; no new GitHub workflow is added.

## FMPL Procedural Surfaces — 25 original candidates + CC0 intake

[Procedural surface library](surfaces/README.md) adds **25 programmatically constructed Blender material assets** (wood, driftwood, brick, concrete, stone, clay, cracked mud with embedded rocks, metal, leather and rubber) alongside the existing 23 real image-backed PBR presets. The [source registry](surfaces/catalog.json), [Blender builder](surfaces/build_library.py), [independent native verification](surfaces/verify_library.py) and [BlendSwap source catalog](surfaces/blendswap_sources.json) are separate from FX/gas material presets. No existing material files or models are overwritten.

The source includes a techniques-only adaptation of [Sam Bowman's procedural cracked mud with rocks](https://www.youtube.com/watch?v=iuaZuDiMv6s). Its documented stages map to explicit Voronoi edge darkening, masked rock distribution and bounded bump relief. Neither its copyrighted video nor external Patreon files are reproduced.

BlendSwap CC0 pages are **candidates**, not downloaded assets; license declarations are uploader-provided and old Blender version/source dependences need manual inspection. The [quarantine gate](surfaces/source_gate.py) only checks local file magic, hash, CC0 listing and size. No unseen third-party materials are promoted or uploaded automatically. Native output is intended to be produced by the existing private Dens Mortis Windows runner; visual acceptance, actual source permanence and Factorio game placement remain separately gated.

## GitHub-wide rendered asset gallery

The [source-verified account gallery](gallery/README.md) inventories all 25
public mrcalzon02 repositories and records every discovered 3D model,
texture/map, historical sprite and proof with an immutable Git commit/blob SHA.
Its [initial verified production checkpoint](gallery/VERIFIED_BASELINE_2026-11-09.md)
documents 95,993 indexed asset paths, all **76 canonical materials** rendered,
and the first **36 genuine 3D models**. Follow-up
[raw texture batch 00](gallery/VERIFIED_TEXTURE_BATCH_00_2026-11-09.md)
added 64 independently verified Blender map previews; later
[model batch 00](gallery/VERIFIED_MODEL_BATCH_00_2026-11-09.md)
added 27 model renders, with nine size-limited assets explicitly marked blocked.

The galleries run via the existing single private Dens Mortis Windows worker.
Additional source files are indexed but **not implied rendered or approved**.
Download the offline index and native Blender proof receipts from each actual
Dens Mortis workflow artifact; do not create additional Actions workflows or
treat its 14-day artifact retention as permanent distribution.
