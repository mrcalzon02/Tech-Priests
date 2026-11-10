# FMPL GitHub Pages publishing

The gallery is a static site. Configure the public `mrcalzon02/Tech-Priests` repository under **Settings → Pages → Build and deployment → Deploy from a branch → main → /docs**. No custom workflow is required.

The repository README links the [GitHub-native Markdown contact sheets](README.md) even before Pages is enabled. Static site entry: `docs/index.html` redirects into `docs/fmpl-gallery/index.html`.

Future publication: merge independently verified render artifacts, rerun `tools/fmpl/gallery/publish_site.py` into a clean temporary output directory, inspect the diff and copy `assets/*.webp`, `manifest.json`, `index.html` and `README.md` into `docs/fmpl-gallery/` using the already-authorized runner checkout. Commit to `main` with ordinary fast-forward semantics and read back; do not create additional Actions workflows.

Maintain source commit pins and SHA-256 receipts. Never label raw map sphere previews as approved PBR. Do not publish unlicensed private donor binaries.
