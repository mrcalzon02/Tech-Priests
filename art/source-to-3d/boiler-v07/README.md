# Boiler V07 — circular interfaces and rear structural cage

V07 corrects the V06 rectangular manifold design to circular, coaxial interface housings. Each water/steam housing is a 0.70-tile diameter drum aligned to its full-size external pipe axis, with a hollow chamber and smaller constant-size machine fitting. Circular face covers, eight cover bolts and a circumferential support strap retain the round interface form. The V05 tapered elbows and V06 rectangular chambers are rejected.

The two round housings have separate fluid spaces. Full-size mouth dimensions and positions remain unchanged: 0.57-tile barrel, 0.49-tile bore, 0.68-tile flange at Blender (-1,0.5,0.36) and (1,0.5,0.36). Original vessel seats and all 202 boiler core meshes retain their prior geometry. The steam machine-side fitting is routed from the round housing to the existing vessel seat without changing its bore size.

A rear structural cage runs across the assembly: two anchored uprights, upper and lower crossmembers, crossed diagonal braces and corner fasteners. Each housing's circumferential strap is connected to the cage by upper and lower diagonal supports. Frame feet anchor into the base. This is visible support geometry, with no hidden mechanical internals added.

The 45-degree orthographic side view exposes the circular interface face, while the rear view shows the cage and its supports. Separate reference pipes are available in the native Blender file and excluded from the GLB.

The validation record covers closed single-component manifold shells, unchanged core geometry, native-size mouth rings, native reopening and GLB mesh/bounds readback. Runtime integration and animation remain pending. This revision is ready for visual review.

The complete archive includes V05 source and its geometry helper script. From the extracted root:

```
blender --background --threads 6 --python build_boiler_v07.py
blender --background --threads 4 --python readback_boiler_v07.py
```

Validated with Blender 4.3.2.

## Saved assets

- [Editable boiler V07](https://chatgpt.com/library?file_id=libfile_a76488dcaadc8191a3a38ae50b31f8ab&account_id=personal)
- [Complete circular interface package](https://chatgpt.com/library?file_id=libfile_c97d4eb9cbc481918f23ea4c25413790&account_id=personal)
- [Asset-only GLB](https://chatgpt.com/library?file_id=libfile_28690160587081918b57fc963558ecca&account_id=personal)

Native binaries are linked above; the repository stores reproducible scripts, hashes and validation records. Run from the complete archive layout.
