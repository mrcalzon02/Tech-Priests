Tech Priests GUI Asset Slices

Contents:
- frame_kit/: separated frame pieces from the modular 40K screen frame sheet.
- controls/normal/: 16 normal/on-off widget panels, centered on a uniform canvas.
- controls/disabled/: 16 broken/disabled widget panels, centered on a uniform canvas.
- medallion_spin/: 8 aligned frames for the spinning green skull/cog coin.
- icons/: standalone green skull/cog emblem.
- source_sheets_cleaned/: cleaned source sheets with the baked checkerboard keyed to alpha.
- manifest.json: source paths, slice bboxes, and output dimensions.

Caveat:
The generated source sheets had a baked checkerboard instead of real alpha. I converted the light neutral checkerboard to transparency deterministically. This is good for prototyping and slicing into the Factorio mod, but a final release art pass should inspect alpha edges and standardize exact tile dimensions where necessary.
