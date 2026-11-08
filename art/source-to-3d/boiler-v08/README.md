# Emergency boiler V08 — production animation

The approved user-edited V07b model is exported and installed into the Tech-Priests
mod source as a four-direction boiler animation. Its original 270 machine meshes,
materials, circular interfaces and rear structural cage remain intact.

- 96 working frames per direction, 24 fps, a four-second loop.
- Flickering indicators, pulsing buttons, three rattling canister assemblies and
  steam from the actual rear-tank top nozzle.
- Fixed 45-degree orthographic camera and authored Cycles lighting; one camera.
- 128px and 256px RGBA cells, with a stable 3.35-tile canvas and ground pivot.
- The 256px sheet uses scale 0.41875; 128px uses 0.8375 for the same world size.
- A 2x2 footprint and native rear-row water/steam pipe connectors.

The generated boiler module is registered from data-final-fixes.lua. It replaces
the complete BoilerPictureSet, rather than layering a second full body. The atlas,
icon and exact-target Lua are installed in tech-priests_src. No recipe costs,
health, heat output or fuel consumption were changed.

[Game-ready package](https://chatgpt.com/library?file_id=libfile_dfa7cc946308819186108d67de62cc95&account_id=personal)
includes the sprite atlases, Lua, native prepared Blender scene, saved MODEL/RENDER
master, export scripts and QA records.

[Four-direction animation](https://chatgpt.com/library?file_id=libfile_13f665ace7208191bcb2b885818e841b&account_id=personal)

[Approved editable native model](https://chatgpt.com/library?file_id=libfile_472d55643ae4819189e12200eb66d4ca&account_id=personal)

Validation: all 388 source captures and 776 final atlas cells verified, source/master
hashes checked, master independently reopened, and final cardinal mappings checked.
The actual exported Lua loaded in Factorio 2.1.24 with the full native mod; pipe pairs
connected and all four boilers produced steam over a 600-tick probe. Graphical-client
appearance remains a diagnostic that has not been reviewed.

## Repeat the established export

Extract the prepared native source from the package at its declared relative path
in this repository, then use Blender 5.0.1 or newer:

```sh
python3 tools/art/produce_factorio_asset.py --job tools/art/jobs/boiler-v08.json --blender /path/to/blender
```

The common exporter supports hash-verified checkpoint resumption. See tools/art/README.md.
The prior low-resolution Eevee previews are obsolete timing drafts; this export uses
Cycles with the authored scene lights, world and packed materials.
