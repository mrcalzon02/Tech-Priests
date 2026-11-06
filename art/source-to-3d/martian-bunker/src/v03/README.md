# Fortified Martian Heavy-Weapon Bunker — v0.3 Blender reconstruction repair

**Version:** v0.3 native-Z-up scene fix. No gameplay changes, no sprite replacement, no source-geometry design changes from v0.2.

## Failure reproduced from previous build procedure

The v0.2 workflow imported an intermediate trimesh-generated GLB and proceeded as though the mesh world coordinates were already authoritative Blender coordinates. It did not verify the Z-up coordinates of any named part after the import or verify actual on-screen materials. It only confirmed object count, 42 assigned parent members and that an orthographic render file existed. Blender was never given explicit PBR materials for the 16 functional material classes.

## Repair

- `build_blockout.py` produces a **compressed, explicit original coordinate mesh manifest**: every vertex in original +Z-up frame and every triangle, material identity and traverse membership; 131 named objects.
- `setup_blender.py` creates native Blender meshes **directly from the original Z-up vertices**, avoiding glTF axis conversion during scene construction; creates explicit physically-based materials for Martian red, ferrocrete, glass, iron, brass, parchment etc.
- Rear mast, optics, gun and turret shell use a single Z=1.70 pivot with inverse-parent transforms preserving their original coordinates. Stationary concrete and magazine remain outside this parent.
- Every 15° rotation is numerically verified for three independent moving assemblies and restored before render. The base footprint, turret armour, cannon muzzle, antenna attachment and vertical clearance are all tested in Blender world coordinates.
- **Only Blender exports the final v0.3 GLB**, so its glTF axis conversion is handled by the actual export backend. The old trimesh GLB is retained only as an intermediate forensic source.
- Render identity and image geometry are inspected after actual Cycles front/rear rendering. These output tests protect against silent grayscale imports and sideways geometry.

## Run in same headless Blender environment as emergency miner

```bash
python -m pip install numpy trimesh
python build_blockout.py
blender -b --factory-startup -t 2 --python-exit-code 12 --python setup_blender.py -- --render
```

Original source geometry was created for Tech Priests. This model contains **no imported Wube mesh** or external Warhammer assets. All previous v0.2 results remain in gallery as a failed Blender conversion diagnostic, not accepted art.
