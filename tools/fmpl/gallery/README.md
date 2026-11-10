# FMPL GitHub-wide rendered asset library

**[Open the live GitHub-native visual contact sheets](../../../docs/fmpl-gallery/README.md)** (76 canonical materials, 180 source models, 192 raw texture-map previews). Searchable GitHub Pages source: [gallery/index.html](../../../docs/fmpl-gallery/index.html). Full-resolution original Blender proofs remain in independently verified runner artifacts.

This gallery inventories **all public mrcalzon02 repositories** as source records, not just the FMPL register. Its first native production pass uses a bounded number of Blender scenes and renders; the JSONL inventory includes every found 3D file and image, even those **not yet rendered**. Private Dens Mortis runner files, unverified private Drive donor binaries and unaudited external CC0 source packages do not get published here.

## Output families

- `materials/`: editable 3D material swatches, canonical 45-degree Cycles gallery, source IDs and explicit library version (existing 23 texture-map PBR, 28 FX, 25 procedural surfaces).
- `models/`: real Blender renders for each processed `.blend`, `.obj`, `.glb`, `.fbx`, `.gltf` donor or finished model, with historical and blockout status preserved.
- `parts/`: source-indexed shared parts and Greebles candidates; only license- and source-verified geometry can be included as rendered geometry. Candidates without available 3D files remain visibly pending.
- `inventory/`: one JSONL file per source repository plus `summary.json`; exact source path, full commit, Git blob SHA, size, role, clone/release duplicate classification, first-pass render availability.
- `index.html`: offline gallery with linked real PNGs and source URLs, no fake thumbnails for missing assets.

## Production and review gates

All source repositories are read-only. Store source commit and raw blob SHA; detect exact binary duplicates across version folders and distribution directories. Never confuse 10,000 sequential animation frames with 10,000 unique material presets.

The initial batch targets canonical FMPL **76 material definitions** and the legacy **Tanks-for-Bob 21 survival OBJ blockouts**, with progressively scheduled, bounded extensions to the other thousands of files. Lack of a Blender-compatible source, oversized binary, license uncertainty, truncated tree or render failure is recorded as pending/blocked, not claimed as completed.

No new GitHub workflow. The private Dens Mortis controller runs one job on OLD-CORE30; every run saves an immutable native report, proofs and a new artifact. The indexed library is not a Factorio installation or a replacement for user visual approval.

See `repositories.json` for repository scope and `inventory.py` for deterministic inventory. Rerun an explicit batch to extend coverage without deleting previous versioned proof artifacts.

## Raw texture-map continuation

The one-time first gallery build renders the 76 canonical FMPL material definitions. Other GitHub images are **indexed**, not automatically repurposed as physical surfaces. Run `render_texture_batch.py` against the preserved inventory to obtain actual Blender sphere previews for unique `material-map` and `texture-image` source files. It verifies the complete Git blob SHA before opening each original source; unsupported or oversized images are recorded as blocked.

```sh
blender -b --factory-startup --python-exit-code 1 --python tools/fmpl/gallery/render_texture_batch.py -- \
  --inventory /path/gallery/inventory --out /path/new-batch-0000 --batch-index 0 --batch-size 64
```

Batches never overwrite one another. `batch-index` advances by 1 for the next slice. The material-map preview is labeled **raw-map-on-sphere**, not an approved PBR preset, because normal/ORM/height data are not interchangeable with albedo. Full sprite/frame/icon histories remain indexed but do not consume a separate physical-material render per animation frame.

No scheduled jobs, no workflow matrices, and no automatic GitHub publication of external image binaries. For historical/duplicate models, future batches should reuse previously verified source hashes rather than rerendering identical geometry needlessly.

## Cumulative verified gallery

[merge_verified_batches.py](merge_verified_batches.py) takes the previously verified
canonical gallery ZIP plus subsequent **genuine** Dens Mortis model/texture job artifacts.
It validates the original 76 material PNGs and .blend, every new image SHA-256, each
batch's independent verification receipt, and exact pinned Git blob identities. It
deduplicates models and raw-map previews by source blob identity, removes size-blockers
only when the matching source is actually rendered, and emits one self-contained,
searchable offline `index.html`, a machine-readable `manifest.json`, preserved
inventory reports and all genuine proof PNGs.

Example after downloading the authorized runner artifacts:

```sh
python tools/fmpl/gallery/merge_verified_batches.py \
  --baseline FMPL_Combined_Library_76_Materials_63_Models_64_Textures.zip \
  --batch FMPL-gallery-nine-recovered-42760825381.zip \
  --batch FMPL-gallery-model-batch01-run42887345055.zip \
  --output FMPL_Cumulative_76_Materials_100_Models_64_Textures.zip
```

The command refuses to overwrite an existing destination or include unverifiable
images. It uses Python's standard library, never downloads from the web, and does not
run Blender or alter source repositories. New batches are explicit arguments; the
library is not claimed complete merely because its source census is complete.
