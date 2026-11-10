# FMPL GitHub-wide asset gallery — verified baseline (9 November 2026, Alaska)

This is a **source/evidence checkpoint**, not a claim that every GitHub image and
model is already rendered. Read [README.md](README.md) and use the exact original
source inventory (inside the GitHub Actions gallery ZIP) for future batches.

## Verified Dens Mortis executions

| Step | GitHub Actions run | Observed result |
|---|---|---|
| Full public-repository file census, native 76-material capture, initial 36-model capture | [42753249716](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42753249716) | All source/Blender render stages passed. Original run ultimately failed in HTML index argument parsing, **after** preserving genuine proofs. |
| Gallery index, source-preserving artifact repack and independent Blender verification | [42758624374](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42758624374) | **SUCCESS**. Reused original 112 renders; saved offline HTML browser, full inventory, native master, source hash receipts and portable ZIP. |

The portable gallery archive is `FMPL_Gallery_76_Materials_36_Models.zip`,
**50,923,769 bytes**, SHA-256
`268255d2f26be9fceff1d5b707e47df1a4d4ea8e0f050dd575c9e91153c8387c`.
It is available as an artifact from run 42758624374.

The independent `gallery_verify.json` confirms: Blender **5.2.3 LTS**;
76 native material assets reopened; 76 material PNG proof hashes verified;
36 genuine 3D source-model PNG proofs verified, 0 blocked; 76 swatch meshes;
one calibrated 45-degree camera. No gameplay assets were overwritten.

## Entire account source census (read-only, full Git commit pins)

- **25 public repositories** included: 23 scanned with source files, 2 empty.
  The private Dens Mortis execution controller was deliberately excluded.
- **95,993 indexed asset paths**, **61,823 distinct Git blobs**;
  **34,170 exact duplicate source paths** preserved with their identities.
- **4,374 source model paths** (1,488 native and 2,880 interchange);
  six Blender backup paths are cataloged separately, not promoted.
- **91,603 image paths** including texture/mapping, screenshots, game sprites,
  proof renders and historical atlases. Not every image is a reusable physical
  texture; original classification and source bytes are retained.
- 39 reusable-part candidates and 320 private Drive Greebles candidates
  **remain unapproved**. Listing is not approval to import or redistribute.

## Actual completed rendering coverage

| Family | Total in authoritative FMPL catalog | Genuine initial render count |
|---|---:|---:|
| Existing industrial PBR presets | 23 | 23 |
| Procedural effect materials | 28 | 28 |
| Procedural construction surfaces | 25 | 25 |
| **Materials subtotal** | **76** | **76** |
| Distinct source models | 4,374 paths, many historical/duplicate | **36** |

The first model cohort contains Tanks-for-Bob survival greyboxes and real
native/interchange sources from additional repositories. A successful render of
a blockout does not make it a production-ready model. Original model sources
and material catalogs remain unmodified; visual approval and game integration
are separate gates.

## Continuations on the same single Windows runner

- **Raw material maps:** mode `fmpl-gallery-textures`, explicit
  `batch_index`, 64 distinct source blobs maximum per request. The script
  `run_fmpl_gallery_textures.ps1` verifies Git blob bytes before applying a
  raw map to an honest neutral Blender surface. Normal/ORM maps are not
  falsely labeled finished diffuse PBR.
- **More 3D sources:** mode `fmpl-gallery-models`, explicit
  `batch_index`, `batch_size` capped at 48 and pinned original inventory.
  The read-only selector excludes initial 36 rendered blob IDs and
  deduplicates within batches. The result includes a verified image catalog,
  blocked reasons and a portable ZIP, without altering source models.
- Do **not** run concurrent Blender workers, force-push, create new GitHub
  workflows, infer successful coverage from untested placeholders or
  silently rerender source versions with identical Git blob SHA.
- Each later batch needs its **own actual run result and artifact receipt**.
  Do not call the remaining models/textures complete until their run results
  are archived and verified.

## Status

**Initial gallery verified and distributed. Further raw textures and models
remain in explicit, bounded continuation batches.** This document does not
authorize an unbounded overnight loop or a new workflow matrix.
