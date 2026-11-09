# FMPL Greebles — conservative de-atlasing / source-intake sequence

**Goal:** physicalized, reusable, *editable* parts and design language, not a pile of unclassified duplicates. Geometry/shape is the valuable source data; Greebles material slots are generic placeholders, not an approved material library. Reuse the established FMPL and its single self-hosted runner. Do **not** create another GitHub workflow or publish private third-party/source binaries. Run batches on the runner's spacious D: drive.

## Stage 0 — preservation and binary inventory (done)

- Preserve the exact private Drive original (`Greebles.blend`, 133,802,272 bytes; pinned SHA-256 in `source.json`).
- Parse native Blender datablock names: 322 objects, including 320 name-matched mesh datablocks, one camera and one light, nine material datablocks, one collection.
- Stable candidate IDs derive from source hash + exact Blender object name. This is **name-only evidence**, not verified topology or semantics.

## Stage 1 — bounded extraction engine (script and offline tests prepared; Blender pilot pending)

1. Sync the original through the **authorized** Drive connection into a runner-only cache; set `FMPL_GREEBLES_BLEND` in its process environment. No OAuth token in a workflow.
2. Run `probe_source.py` to confirm exact source SHA-256.
3. Use `deatlas.py` in `--dry-run` mode to inspect the first eight candidates, then run one `--limit 8` extraction batch. Its output is geometry-only: placeholder material slots are captured in metadata then stripped from each mesh copy. It writes one compressed geometry-only `.blend` and receipt per mesh-object donor.
4. Check each receipt and part's digest; `--resume` only skips an **exact** matching checkpoint, never overwrites uncertain output. The evaluated geometry is baked as a candidate and its original parenting/modifiers/constraints recorded. It is NOT a verified independent rig or mechanical component; parent-dependent behavior is reviewed later.
5. Keep default limits (8 candidates, 256 MiB total staged output, 64 MiB per part); stop on budget failure and review material duplication before expanding batch size. Outputs go to private D: cache, not Git.
6. Script emits per-part bounds, source transform, original material-slot names, topology counts and unverified state. The nine generic source materials are placeholders: **do not carry their material datablocks into each exported part**. Assign vetted FMPL PBR profiles only after classification. Actual Blender load/readback checks must be run on the runner; local Python compilation is not a substitute.

### Example runner commands (PowerShell)

```powershell
$env:FMPL_GREEBLES_BLEND = 'D:\AI-Relocation\FMPL\sources\Greebles.blend'
python tools/fmpl/greebles/probe_source.py --source $env:FMPL_GREEBLES_BLEND
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b $env:FMPL_GREEBLES_BLEND --python tools/fmpl/greebles/deatlas.py -- --out 'D:\AI-Relocation\FMPL\greebles-extracted' --limit 8 --dry-run
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b $env:FMPL_GREEBLES_BLEND --python tools/fmpl/greebles/deatlas.py -- --out 'D:\AI-Relocation\FMPL\greebles-extracted' --limit 8 --resume
```

### Bounded runner orchestration

For a deliberate full pass, invoke `run_batches.py` with `--batch-size 8 --batches 40`. The runner starts one Blender process per bounded batch, records exact `logs/batch_XXX_attemptN.log` files and resumes only hash-verified checkpoints. Start with the **default one batch** and inspect it before scaling. No workflows are created.

## Stage 1b — extracted-part roundtrip (pending)

- Invoke Blender in a **separate process** using `verify_one.py` to open individual candidate `.blend` files and check expected object/mesh existence, evaluated topology, transform and that placeholders were stripped. This is the native-reopen gate; listing datablocks from a staged file alone is preliminary evidence.
- Preserve orphaned files and receipts on failure for explicit reconciliation. Never silently delete previous successful parts.

## Stage 2 — visual identification and component grouping (not yet executed)

- Render one canonical grid-aligned 45-degree icon view per extracted candidate, with no front/rear or oblique render; only contact sheets of these approved stills are allowed. Keep direct visual proof before claiming acceptance.
- Label real surface forms and separate *visible geometry* from unsupported decorative noise.
- Detect mesh islands, shared material dependencies, parenting and mixed assemblies. **Do not automatically split disconnected islands:** bolts plus a panel may be a single useful module.
- Record mesh name, part-source hash, rendering, topology bounds, material, source transform, semantic tag, likely attachment surface, visibility and licensing status. Preserve raw previews and source references.

## Stage 3 — suitability tuning and library promotion (gated)

- Adapt candidates using uniform scaling, controlled deformation, re-meshing or reconstruction as required. Record the derived revision and fit method.
- Compare appearance at 1×1, 2×2 and 3×3 tile footprints and production 45° Wube camera. Reject detail below meaningful sprite pixel visibility.
- Check structural interfaces against the **actual Factorio prototype**, not guessed placement. Cosmetic collars cannot silently become functional sockets.
- Re-open extracted files with Blender, confirm materials and transforms, produce visible side-by-side evidence and obtain explicit acceptance before `verified_reusable` / `owner_approved` promotion.

## Stage 4 — extend design-language families from *approved* sources (pending)

- Catalog provenance, licenses, image/reference-only status, and derivative/redistribution permissions for each named external website. `tools/fmpl/asset_source_gate.py` blocks `approved-import` without evidence.
- Maintain explicit source status for Snouz mixed-license sprite references, Malcolm Riley render references and tutorial methods, and Wube official public production notes and 3D printable STL designs. The Wube models are printability adaptations, not original Blender production scenes. Third-party imagery is not promoted to donor geometry by simply appearing in a graphics gallery.
- Use third-party references as style rails and optional donors, not constraints on building new objects.

## Stage 5 — growing physicalized family library and production regression

- Mine bunker, boiler, condenser, emergency miner, workbench and subsequently accepted Water Purifier assets for **new** proven components and procedural builders.
- Store derivative geometry, measured anchors, thematic profiles and PBR provenance separately from original immutable sources; avoid binary duplication between repositories.
- Every component that graduates to reusable keeps a local Blender roundtrip, 45° preview, machine-specific fit criteria and a pinned FMPL revision; then export via the established Blender → four-orientation sprite → native Factorio workflow.
- Run one small machine construction pilot using a mixed set of existing verified parts, new approved greebles and brand-new authored geometry. Measure reuse rate, required bespoke edits, render throughput, disk and token savings; do not claim improvements until measured.

## Release and checkpoint policy

Failure to build or import Blender sources blocks *this asset step*. Appearance, balance and aesthetic refinement remain iteration diagnostics rather than automatic blockers for the whole mod. Do not retag or rewrite existing accepted scenes. Review logs and visual proofs; commit code/checkpoint metadata with real Git readback. Checkpoint individual candidate stages and stop cleanly on unavailable Drive or network rather than silently dropping work.

## Pending independently supplied tank geometry

A separate near-vanilla tank model was mentioned but no asset URL or file bytes are present in this conversation. Record it as an **unresolved donor**, not Wube-authored. When its exact file is available: preserve source, inspect license, detect native mesh/rig/texture state, then perform the same measured bounded extraction independently of the Greebles scene. Do not infer or fabricate its URI.

## Internal workspace execution checkpoint — 2026-11-09

All 320 source meshes were parsed and actually exported to per-object OBJ and GLB files using the pinned Blender 5.0 native-file binary bridge in `native_bridge`. Each interchange has a SHA-256 receipt; every GLB received geometry readback; full independent audit reports no errors. Two-angle previews exist for all 320 candidates (16 contact sheets, 80 appearance-only labels). This is a stored-mesh geometry extraction, not Blender-evaluated modifiers, rigging, or native standalone `.blend` exports. Native Blender reopen and Factorio-specific fit acceptance remain pending. No binaries/workflows were added to Git.
