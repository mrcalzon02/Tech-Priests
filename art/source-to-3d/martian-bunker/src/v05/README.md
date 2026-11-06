# Fortified Martian Bunker — front turret geometry v0.5

This is a two-stage, fully original **editable mechanical** refinement of the approved v0.4 Red Tech Priests heavy-weapon bunker. The model retains its 3×3 footprint, sloped concrete hull, seated 22 wall attachments, eight tapered foot/corner supports, aft magazine, sensors, and rear-mounted rotating antenna. No Wube mesh is embedded; Factorio remains a render-quality reference only.

## Stage 1 — gun mantlet and armor form

- Replace boxy, flat cheek plates with rear-sloping, machined faceted armor solids that intersect the original turret shell.
- Replace the solid rectangular mantlet with four fitted castings around an intentionally **open** gun aperture. Add a bored steel swivel collar and an inner dust ring concentric with the square barrel shroud.
- Turn the flat overhanging forehead into an anchored eyebrow casting and **continuous inclined roof-transition armor (replacing, not stacking on, the original brow)** that closes the cavity between the brow and turret top.
- Re-seat forward primary optic and visor so that the optic sees around the new armor.

## Stage 2 — engineered front detail

- Add two actual trunnion pivot caps, guard lips and paired service fasteners; installed on the angled gun cheeks.
- Add supported recoil housing brackets and demountable cylinder collars, one pair on each side, fitted against the original recoil mechanisms.
- Add barrel heat-shroud connection rings at the tube transition and a small functional elevation-limit indicator with a supported bracket.
- Preserve 360-degree co-traverse parenting, gun axis, turret-ring clearance, mast, and all stationary systems.

## Reproduction

Requires Python, NumPy, Trimesh and optionally Numba/Pillow for diagnostic previews. From this directory:

```bash
BUNKER_TURRET_PASS=1 python build_blockout.py
python verify_turret_front.py
python render_preview.py
BUNKER_TURRET_PASS=2 python build_blockout.py
python verify_turret_front.py
python render_preview.py
```

The Blender CI uses Blender 4.0.2 or newer to run `setup_blender.py -- --render`, then opens the exported GLB in a fresh Blender process with `verify_exported_blender_glb.py`. The final source model is the second pass. Gallery includes two stage images and front-geometry closeups. Tests do not imply final approved Factorio art; these remain clean mechanical geometry with provisional materials and simplified recoil action.
