# Fortified Martian Bunker — v0.7 actual cylindrical-barrel reconstruction

This is the **source** of a real 3D asset; it is not an image-generation concept. 

## Geometry changes from v0.6

- Removed `21_gun_tube_outer_shroud` outright (it was a 0.27×0.89×0.27 box).
- Installed `21_cylindrical_gun_jacket`: seven successive machined stations, 48-sided concentric lathe geometry, connected to the previous open-bore pressure tube.
- Installed a fitted round locking flange, annular mid-collar and eight seated mount fasteners.
- Kept the original empty bore; neither inner liner nor muzzle was capped.
- Built seam-aware cylindrical UVs in Blender and checked the jacket's moving-parent identity and 15-degree turret traverse increments.
- Updated original 512×512 tileable albedo/ORM/normal map generation (20 material identities, 60 maps) for worn red enamel, exposed steel, oil/dust, ferrocrete, machining and heat tint, guided by three user-provided reference photos. No photographic reference pixels are baked into the model.
- Preserved the existing bunker footprint, aft antenna, sloped supports, fixed rear controls, and environmental fitting mounts.

## Rebuild

From this folder (Python dependencies: numpy, scipy, trimesh, Pillow, numba for diagnostic raster):

```
python build_blockout.py
python make_textures.py
python verify_barrel_v07.py
python verify_turret_front.py
```

In Blender 4.0.2+ headless with distro `python3-numpy`:

```
BUNKER_TEXTURE_MODE=FLAT blender -b --factory-startup -t 2 --python-exit-code 12 --python setup_blender.py -- --render
BUNKER_TEXTURE_MODE=FLAT blender -b --factory-startup -t 2 --python-exit-code 12 --python verify_exported_blender_glb.py
BUNKER_TEXTURE_MODE=TEXTURED blender -b --factory-startup -t 2 --python-exit-code 12 --python setup_blender.py -- --render
BUNKER_TEXTURE_MODE=TEXTURED blender -b --factory-startup -t 2 --python-exit-code 12 --python verify_exported_blender_glb.py
python verify_render_v07.py
```

The single GitHub Actions workflow automates all steps, publishes a `*.blend`, final textured `*.glb`, 60 maps and a four-view gallery when **every** geometry, rig, material and render check passes. Existing mod game sprites remain untouched.

**Important:** The photographs supplied by the user are treated as **hard style references** (surface wear only), not as source mesh, decal, or bitmap materials. The originals are not part of the automated product archive; any public redistribution requires rights review.
