# FMPL — Factorio Modeling Production Library

A **versioned, shared, source-indexed production module** for Tech-Priests, Tanks-for-bob-Fork, HB-TTRPG-tools and future Factorio projects. This is a working *inventory and standards API*, not a new GitHub Actions workflow, third-party asset dump or replacement for existing validated art tooling.

## Contents

- `FMPL.json`: canonical index of complete machine source states, 23 PBR presets / 69 maps, 21 bunker part candidates, 17 existing programs and four real pipeline recipes.
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
