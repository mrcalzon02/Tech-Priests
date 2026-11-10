# FMPL raw-source texture previews — batch 00

**Verified:** Dens Mortis [run #42758930802](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42758930802) — GitHub Actions SUCCESS and native Blender proof verified.

- 64 distinct Git-blob-verified source textures rendered by Blender Cycles into a separate native preview library, with a browsing `index.html`.
- 0 blocked images; all 64 PNG proof SHA-256 values checked by the independent `verify_texture_batch.py` reader.
- The source-classified raw texture queue has 28,144 unique candidates; 28,080 remain after batch 00.
- Every preview is explicitly labeled **raw-map-on-sphere-not-PBR**: these include normal, emissive, UI-state and other texture images. Rendering an image on a sphere does not certify it as physically appropriate surface albedo.
- Original public repository source files, commit pins and blob IDs remain read-only. No Blender scenes from those source repositories were modified.
- Only the existing private Dens Mortis single worker was used; no new Actions workflow, recurring schedule or Game/Factorio art attachment.

**Original job artifact:** `dens-mortis-worker-42758930802-1` (artifact ID `13736538797`), retained according to GitHub Actions artifact policy. Keep a verified local or downloaded copy; Actions artifacts are not permanent asset storage.

**Next continuation:** `fmpl-gallery-textures`, `batch_index=1`, `inventory_run_id=42753249716`. Do not launch it on a runner already executing another Blender model job. A future raw-texture category improvement should avoid confusing UI labels such as `normal` (button state) with normal-map physics, without rewriting this immutable batch's evidence.
