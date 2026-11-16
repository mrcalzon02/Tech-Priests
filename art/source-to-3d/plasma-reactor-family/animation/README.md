# FMPL plasma reactor operating rigs

Minoris, Majoris and Maximus use the previously approved reactor meshes. Each native Blender file contains one machine, one fixed FMPL orthographic camera, and an operating rig. Select **Scene Properties → Custom Properties → reactor_power**. Set it to **1** to run the rig or **0** to inspect the cold machine. Play frames 1–96 at 48 fps. Frame 97 closes the cycle at the initial pose.

The luminous backing of each machined annulus is divided at the actual port centers. A brighter pulse travels clockwise across 10, 12 or 16 ports while the other ports and the plasma coils remain illuminated. The inner impeller and separate extraction turbine turn around their own shafts. The seals, housings and bolt circles stay fixed.

Minoris exhausts from machined slots in the exchanger crown. On the larger tiers, pressure jets discharge from the vaulted exhaust and merge as the vapor rises. The plume uses the FMPL feathered relief-steam material and nozzle-attached, advecting volumes. Thermal shells around the vertical regulators and exposed horizontal induction sleeves use animated refraction. Both thermal effects switch off with machine power.

## Factorio

Install `mars-reactor-visuals_1.0.0.zip` in the Factorio 2.1 mods directory and enable **Mars Plasma Reactors — Animation Preview**. Craft or place a reactor, add chemical fuel, and connect it to a network that is drawing power. The preview generators have independent active and idle graphics. Its three test output ratings and inexpensive recipes belong to the preview mod.

One camera stays fixed at 45° elevation and zero grid azimuth. The machine rotates about its ground pivot for the four cardinal captures. Each operating sheet contains 16 frames at 8 fps. The renderer supplies the active machine, separate additive glow, cold pose and projected ground shadow. High resolution uses 64 pixels per tile and standard uses 32. Static transparent margins are trimmed independently for each game layer with a compensating sprite shift. Frame-to-frame registration remains constant.

The native rigs refract light through hot air. The sprite bake also displaces nearby visible reactor pixels and the alpha silhouette so the shimmer survives downsampling. Factorio composites these sprites over its terrain. The addon supplies no screen-space shader for refracting separately drawn terrain.

## Rebuild

The scripts run against the approved static file `../Blender/Mars_Reactor_Family.blend` in the repository. The source bundle also includes the approved input scene. The capture used Blender 4.3.2, Python with NumPy, SciPy and Pillow, FFmpeg for movies, and Intel Open Image Denoise 2.5.1 for the sprite pass. Point `OIDN_DENOISE` to its executable for the same denoising. A local edge-preserving fallback is available.

From this directory, the following sequence generates the three animated derivatives, captures, and installable addon. Work and output paths must be writable.

```sh
for entry in '1 Minoris' '2 Majoris' '3 Maximus'; do
  set -- $entry
  blender -b ../Blender/Mars_Reactor_Family.blend --python-exit-code 1 -P rig_reactor.py -- "$1" output/Blender
  blender -b "output/Blender/${2}_FMPL.blend" -Y --python-exit-code 1 -P verify_native.py -- "$1" output/QA
  blender -b "output/Blender/${2}_FMPL.blend" --python-exit-code 1 -P capture.py -- "$1" raw --samples 16
done
python pack_sprites.py raw raw output
python verify_sprites.py output
python trim_atlases.py output
python factorio_preview/build_preview.py output/Factorio/mars-reactor-visuals_1.0.0
python preview.py output
```

The installed Factorio addon includes a native test scenario. See `factorio_preview/README.md` for the power-cycle command. The source files under `vendor/fmpl` carry their upstream paths and identities in `SOURCES.json`.
