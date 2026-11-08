# Boiler V08 — animated operation from the user's V07b model

This revision starts from the supplied `tech_priests_emergency_boiler_v07b.blend`, including the larger rear tank, metal top nozzle, and the user's frame/layout edits. All 270 input mesh vertex arrays are preserved. Rest-pose world transforms match the supplied model within floating-point precision. The original input is included unchanged in the complete package.

## Animation

- Four-second loop, 24 fps, frames 1–96. Frame 97 is the matching closure keyframe, outside the playback range.
- Eleven individual emissive/button targets: all existing glowing glasses, optics and LCD flicker; each console button face pulses independently. Existing colours and LCD graphics are retained.
- Three smaller canister assemblies rattle with their caps, lenses and hardware. Mounting feet stay fixed. Peak translation is 0.006–0.007 tile, with small rotational vibration. The large rear tank/nozzle remains fixed.
- Sixteen animated volumetric steam puffs form two staggered jet bursts from the actual added top nozzle, with expanding and fading residual wisps. The steam exits upward at world `(0.062684, 0.652263, 1.223761)`. Source object: `V02 crown recessed inner plate.001`.
- Steam and all other channels loop deterministically. There is no fluid simulation or cache dependency.

Open `tech_priests_emergency_boiler_v08_animated.blend` in Blender 5.0.1 and play frames 1–96. The native file retains Cycles for production-quality rendering. The effects are actual animated Blender geometry, volume shaders and material keyframes.

The final animation scene contains exactly one camera, `BOILER_FACTORIO_EXPORT_45`. Legacy inspection cameras have been removed. The original V07b input remains unchanged inside the archive for provenance; use the V08 file for the cleaned animation scene.

The preview uses a fixed north-facing 45-degree orthographic camera with extra headroom for steam. The four-second review loop samples alternate source frames at 12 fps. It is not a production atlas or four-orientation export. Runtime integration remains pending.

## Reproduce

Run from the complete package root with Blender 5.0.1:

```
blender --background --threads 6 --python animate_boiler_v08.py
blender --background --threads 4 --python validate_boiler_v08.py
blender --background --threads 8 --python preview_boiler_v08.py
python3 package_boiler_v08.py
```

The supplied model was saved in Edit Mode; the build script first returns to Object Mode before creating the independent effect meshes. No source mesh is used as a particle mesh or altered by an effect constructor.

## Tubing and appearance correction

The original 384-pixel GIF/MP4 used low-sample Eevee, which changed the appearance of metal shading and thin tubes. Those files are now explicitly labelled draft Eevee timing previews. They are not an appearance reference. The replacement Cycles image uses the native scene lights/world, native materials and visible steam. A complete corrected Cycles animation preview has not been rendered in this inspection pass.

A source-versus-animation audit found all machinery meshes present, no tube visibility masks, opaque tube materials, matching light transforms/energies and matching colour management. Cycles checks were rendered at frames 1 and 25. Main workspaces now open in Rendered mode with Scene Lights and Scene World enabled. Future preview capture uses Cycles at 720 pixels and 16 samples; packaging rejects draft Eevee frames as an appearance reference.

## Saved current files

- [Corrected native viewport and animation](https://chatgpt.com/library?file_id=libfile_472d55643ae4819189e12200eb66d4ca&account_id=personal)
- [Corrected package with tubing appearance audit](https://chatgpt.com/library?file_id=libfile_161c07109b94819180761fee95d96017&account_id=personal)
- [Actual Cycles appearance with steam](https://chatgpt.com/library?file_id=libfile_47ea67a1d0848191994713f08ac1878b&account_id=personal)

The earlier GIF/MP4 are explicitly labelled draft Eevee timing previews. No complete corrected Cycles motion loop is claimed by this inspection pass.
