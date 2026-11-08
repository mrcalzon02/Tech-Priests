# Rough timber workbench V4 — inspection model

One-tile workbench: four rough timber legs, simple rails and braces, three supporting top planks, one continuous thin sheet of dull iron wrapped down around the edges, and one heavy hammer.

This is a model for visual review, not an approved production sprite or a gameplay integration. Working face is approximately 0.98 × 0.82 tiles. One orthographic camera is reused at 45° elevation for all four views.

`rough_timber_workbench_v4_source.zip` contains the native Blender model and reproducible build script. `workbench_v4_views.webp` is a contact sheet of actual Blender Cycles inspection renders.

The narrowly scoped `Rough timber workbench inspection` workflow reuses the pinned Blender installer from the existing turret capture pipeline, produces four PNGs and the native model, and uploads one artifact. Its completion record is GITHUB_RENDER.json. No workflow chaining or matrix fan-out.

Rebuild locally:

    blender -b --python build_workbench_v4.py
