# Emergency Assembler V07

This is the exact packed, animated Blender scene supplied by the owner from
**Branch · PIPE-Plan model corrections**. Its original SHA-256 is
`00d047b9aa80e13bd148b1dcbd2e5440b4a5e0414d744b446f273b0fc741845d`.
The original scene, geometry, materials, images, animation keys and timing are
preserved. The unrelated timber-workbench override is replaced only for the
emergency assembler.

The 12-second cycle opens the real split hatches, raises the rounded knobbly
capsule on its three-link hinged arm, discharges branching electricity into
both ends, heats the capsule and tower tips, emits vapor during discharge,
cools, retracts and closes. The 288-frame scene runs at 24 fps. Native sprites
sample every second source frame: 144 frames at 12 fps, four directions, with
a separate closed idle image and matching icon. This keeps the full duration
independent of recipe speed. Fuel starvation uses the engine's native idle
behavior; the visual cycle does not redefine recipe completion or output.

The source's 26 actual texture images are packed. The surface plan documents
the existing authored finishes; no replacement textures or machinery were
introduced. `motion-audit.json` independently checks evaluated geometry,
capsule/hatch/well surface clearance, arc endpoint attachment, steam overlap,
packed images and closure at frame 288. It does not claim an exhaustive
collision test of every pair of parts.

The capture scene exists only in memory. A fixed 45-degree FMPL camera and
whole-model facing parent generate genuine north/east/south/west frames.
Steam planes face the capture camera. A Cycles shadow catcher supplies actual
per-frame ground shadows in the RGBA image. Shadow sampling noise at alpha
<=8/255 is removed during packing, and the outer 12px shadow-only margin fades
to transparency to prevent image-border seams. The scene is centered on its actual
foundation for sprite registration. The one-tile grid and selection bounds,
burner, crafting speed, recipe categories and item costs are retained. Native
burner assemblers require a non-square collision box for directional placement:
only its depth changes from 0.70 to 0.72 tile. All four facings can be chosen
before placement; the engine does not permit in-place rotation for this type.

`atlas-manifest.json` binds source, camera, cycle, registration and installed
PNG hashes. `four-direction-cycle-review.png` and the four-direction GIF are
alpha-composited previews. The PNG sheets themselves retain transparency.
`native-evidence/` records the exact production builder and generated graphics
tested in an isolated Factorio 2.1 profile with real recipes and fuel. This
focused native test does not stage the entire priest behavior runtime.

Rebuild from the repository root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --factory-startup --background --disable-autoexec --python tools/art/emergency_assembler/audit_motion.py
& 'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe' --factory-startup --background --disable-autoexec --python tools/art/emergency_assembler/capture.py -- --size 256 --samples 24
python tools/art/emergency_assembler/pack.py
python tools/art/emergency_assembler/run_native.py --reload --graphics
```

No Actions workflow, unrelated model, or held workbench source is modified.
