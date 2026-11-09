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
