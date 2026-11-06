# Martian Heavy Weapon Bunker v0.9 — subtractive turret refinement

This is **not** new concept art. All changes modify the source 3D meshes used to build the actual Blender `.blend` and exported `.glb`.

## Why this revision exists
v0.8 was incorrectly treated as improved because it added 82 little mesh accessories, including multiple stacked annular rings, duplicate lens bezels, extra bands over existing bands, free-standing heat bars, pseudo-serial bars, and false chipped edges. The result was busier, not more mechanically convincing.

## Actual changes
- Removes 55 physical mesh components (254 → 199), reducing turrets' 165 moving pieces to 110.
- Retains the 48-sided **round** cylindrical gun jacket and *open* pressure barrel.
- Keeps one genuine external mantlet spall shield seated on the original bearing rather than three superimposed extra circles; retains six structurally placed fasteners.
- Replaces stacked optical socket/bezel assemblies with one structural instrument well, one recessed functional lens, four mounting screws, and an integrated status window on each side.
- Deletes the five additional gun service bands; the actual jacket locking flange, single forward clamp, and already-functional material interfaces remain.
- Removes unsupported crown ribs and barrel heat rails. Heat bluing and scuffing remain material properties, not fake cylinders.
- Removes the second oversized periscope hood; original hood carries the existing optic aperture.
- Removes extra ring cog medallion, raised letter-bars and raised paint chips. Surface wear belongs to generated material maps, not sculpted floating strips.
- Preserves 3×3 foundation, sloped corner buttresses, 22 external wall attachments, fixed rear services, true antenna parent rotation and remote gun clear bore.

## Verification
Run with Python dependencies `numpy`, `trimesh`, `scipy`, `Pillow`, `numba`:

```
python build_blockout.py
python make_textures.py
python verify_visual_target_v09.py
python verify_barrel_v09.py
python verify_turret_front.py
python render_preview.py
```

In GitHub Actions, the existing single headless Blender 4.0 runner builds both flat and image-textured scenes, independently imports both exported GLBs, renders the gun from three angles, and compares flat versus PBR. The source-level checks **assert that the removed clutter does not return**.

The source reference images, earlier v0.8 and the user-selected rendered target are for visual guidance only. No pixels or meshes from those images are copied into the shipped asset. This is a coherent step towards the target, **not** final target-level image fidelity or native Factorio sprite acceptance.
