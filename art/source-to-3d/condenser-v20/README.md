# Condenser V20 — raised housing and side outlet

The existing Blender condenser now has its upper assembly raised by 0.38 tile. The canisters, console, covers, conductors and hoses retain their shapes and move upward together. The main housing, side cheeks and retaining straps extend to support that assembly. Ground footprint and base hardware are preserved.

The housing roof is at Z=0.772575 tiles, 0.072575 tile above the outlet flange. A real circular bore is cut through the main housing and right side cheek, coaxial with the pipe at Blender (1, -0.5, 0.36). The outlet and two reference pipe sections retain their V19 world geometry, diameter, height and tile alignment. This revision makes the pipe emerge from the side of the taller housing.

Open `tech_priests_water_condenser_v20.blend` to inspect the editable model. `REFERENCE_ADJACENT_PIPES` and `REFERENCE_TILE_GRID` are detachable fit references and are excluded from the asset-only GLB. PNGs are actual Blender renders.

Validation checks unchanged pipe geometry, roof clearance, closed bored sidewall meshes, axial ray clearance through the socket, native reopen, and GLB mesh/bounds readback. Factorio runtime integration and production sprite replacement have not been performed.

The complete archive includes the preserved V19 source and scripts. From its root:

```
blender --background --threads 6 --python build_condenser_v20.py
blender --background --threads 4 --python readback_condenser_v20.py
```

Validated with Blender 4.3.2. Packed textures are retained.

## Saved assets

- [Editable Blender scene](https://chatgpt.com/library?file_id=libfile_334339b507e88191beab3d64326ec58c&account_id=personal)
- [Complete V20 archive with V19 source](https://chatgpt.com/library?file_id=libfile_cc15e5dd2c8c8191be794ff1d776ae25&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_fbe6d37df4cc81918cbc57d3b61d3701&account_id=personal)

Native binaries are linked above; this repository directory contains reproducible scripts, hashes and validation records.
