# FMPL Greebles: read-only Blender 5.0 native-geometry bridge

**Context:** In the November 9, 2026 workspace run, Blender was not installed and a Blender 5.0 binary scene was available in native uncompressed form. The code here reads the **pinned exact source** (SHA-256 recorded in `blend5_geometry_reader.py`) and extracts actual stored mesh vertices, face offsets and corner indices from its DNA blocks. It is intentionally **version-specific**, not a substitute for `bpy` or a generic Blender-file parser.

The source is a private Google Drive `Greebles.blend`, not committed into public GitHub. The original Zstd Blender file hash and the decompressed native file hash are both checked before extraction. Each independent candidate has an OBJ retaining original polygon boundaries and a triangulated GLB with readback-validated topology. A separate geometry manifest records original bounds, object-level transforms, source material placeholder policy, and exact hashes.

**Actual workspace evidence:** 320 of 320 source meshes extracted and validated; 2,828,171 vertices, 5,610,509 source polygons, 5,646,243 triangulated faces; 640 two-angle diagnostic previews; 16 20-part contact sheets; 80 provisional visual labels. 0 standalone native `.blend` files confirmed by a Blender reopen in this workspace. No native Factorio runtime integration or port fitting is claimed.

## Local software prerequisites

The binary bridge uses Python 3.10+, NumPy, trimesh and Pillow. Previews additionally use `opencv-python`. Its own Blender 5.0 DNA reader only accepts the exact 17-byte native header, and checks its exact uncompressed source SHA-256. Do not apply it to other Blender versions without dedicated verification. To decompress the original Zstd source in the absence of Blender, `decompress_blender_zstd.py` uses installed `libzstd` on Linux. Use your installed Blender itself on the runner whenever possible.

## Reproduce the extraction in a local workspace

```bash
python decompress_blender_zstd.py /private/Greebles.blend /private/Greebles-uncompressed.blend
python extract_native_geometry.py --source /private/Greebles-uncompressed.blend --out /private/greebles-index --offset 0 --limit 8 --index-all --previews
python extract_native_geometry.py --source /private/Greebles-uncompressed.blend --out /private/greebles-index --offset 8 --limit 32 --resume
python audit_batch.py /private/greebles-index
python render_catalog.py --root /private/greebles-index --offset 0 --limit 32
python build_catalog.py /private/greebles-index
```

Continue extraction and rendering in bounded batches. The default extracted part filenames include stable IDs derived from the exact original compressed source hash plus the exact native Blender object name. The `--resume` flag refuses mismatched checkpoints.

`build_catalog.py` expects `manual_visual_labels.json` inside the extracted index root, which may be seeded from `candidate_labels.json`. This file is a **visual shape vocabulary**, not proof of actual real-world function, fluid interfaces, native Factorio scale, collision, or rights for distribution.

## Native Blender finishing on the existing runner

Prefer the already-committed `tools/fmpl/greebles/deatlas.py` if evaluated modifiers and parent transforms must be applied from the original scene. If the confirmed 320 extracted OBJ candidates are available instead, invoke `native_finalize.py` in Blender 5.2 on a copy of the interchange package and process batches. It preserves source identity and strips placeholder material slots. A second Blender process opens each output using `native_reopen_verify.py`. **These two native Blender scripts were prepared but not run in the internal workspace; no native `.blend` generation is asserted.**

No new GitHub workflow is needed. No private source file or extracted third-party geometry is included in this public repository. The 320-part geometry package remains a separate private download, with per-object receipts and visual proofs.

## Tank donor status

The user-supplied `factorio-tank-chaffe.zip` is an independent candidate, **not a Wube-authored asset**. Its archive includes one Blender 3.03 source (`87` mesh datablocks and `98` object datablocks), `16` PNG textures, and no license document inside the ZIP. `tank_donor_intake.json` records hashes and inspection provenance. Treat rights as unknown until the specific creator/license is established; do not redistribute or promote geometry as approved before that check.
