# Factorio asset production

Established Blender exporter and production runner recovered from
mrcalzon02/Tanks-for-bob-Fork/tools/art, used here for the approved V08 boiler.
Authored geometry, packed materials and lights remain authoritative.

One command from the repository root:

```sh
python3 tools/art/produce_factorio_asset.py --job tools/art/jobs/boiler-v08.json --blender /path/to/blender-5.0.1
```

The profile captures idle plus 96 working frames at 24 fps, four directions, using
one fixed 45-degree orthographic camera. The job converts Blender's positive-Z
rotation order into Factorio N/E/S/W, sizes atlases within 8192 pixels and emits
a BoilerPictureSet rather than a crafting-machine graphics_set.

Prepare the approved native V08 file at the path declared by the profile:

```sh
blender -b approved-v08.blend --python tools/art/prepare_boiler_source.py -- --out art/source-to-3d/boiler-v08/production-source.blend
```

This adds cold frame zero, skips zero-density steam, and enables denoising/render
caching without changing mesh geometry, working-loop timing, lighting or materials.

Four rendering processes share eight CPU threads. Each saves source/configuration
identity and completed-frame hashes. Resume a failed capture using:

```sh
python3 tools/art/export_sprites.py --config tools/art/profiles/boiler-v08.json --out PATH_TO_EXISTING_CAPTURE --blender /path/to/blender-5.0.1 --resume
```

Package a resumed capture with the production runner's `--from-capture` and a fresh
`--out` directory. `verify_boiler_production.py` compares every final RGBA channel
against its hash-verified source capture, including the direction mapping.

The generic prototype attachment helper supports crafting machines/furnaces only.
The boiler job emits its exact-target module as `prototype-ready.lua`, to run after
tech-priests-emergency-boiler is declared. Engine-test the boiler-specific graphics
and ports before live installation. An isolated test does not change the live mod.
