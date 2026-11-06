# Fortified Martian Heavy-Weapon Bunker — v0.2

Authority: [`docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md`](https://github.com/mrcalzon02/Tech-Priests/blob/main/docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md).

**Status:** Original mesh, mechanical-clearance/blockout stage; no existing Factorio sprite modified. 3×3 tile base footprint retained. Native Blender and finished Factorio-scale material acceptance pending separate render approval.

## Changes after owner review

- Full 3×3 base retained; strong cast octagonal corner chamfers and beveled second slab.
- Rooftop armor tapered to a noticeably narrower upper silhouette (2.35×2.35 final skin, versus 2.74×2.74 in v0.1).
- Rear magazine, ammunition lift and controller lowered below rotating gun platform. Conservative static hardware clearance above main boxes >= 0.10 tile units, with actual v0.2 manifest recording clearance; cable endpoint leading into slip ring is deliberately nearer and separately checked.
- Antenna is **on a braced rear standoff fixed to rotating turret casing**, with hardline into turret controller. It stays behind gun as turret rotates.
- The data-path handoff between rotating platform and stationary control remains through a protected slip-ring interface.
- Rotating and stationary mechanical meshes have explicit membership, and Blender can rotate the whole turret/mast assembly together.
- Structural shapes are original; no Wube geometry or third-party 40K models are included. Wube's official assembler STL and in-game sprites remain separate reference-quality benchmarks, not redistributable derivatives.

## Local reproducibility

```bash
python -m pip install numpy trimesh pillow numba
python build_blockout.py
python render_preview.py
blender -b --factory-startup --python-exit-code 12 --python setup_blender.py -- --render
```

`component_manifest_v02.json` includes named part roles and clearance measurements. `gallery/` in the repository contains the v0.2 before/after progression and diagnostic views. No gameplay or mod prototype behavior is changed by this art task.

**Further tasks:** final traverse/feeding inspection inside Blender, texture passes, corrosion and soot placement, glass/metal PBR materials, fixed isometric in-game 256px composition. Do not present these previews as visually accepted Factorio assets.
