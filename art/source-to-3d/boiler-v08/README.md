# Emergency boiler V08 — production animation

The approved user-edited V07b model is exported and installed into the Tech-Priests
mod source as a four-direction boiler animation. Its original 270 machine meshes,
materials, circular interfaces and rear structural cage remain intact.

- 96 working frames per direction, 24 fps, a four-second loop.
- Flickering indicators, pulsing buttons, three rattling canister assemblies and
  steam from the actual rear-tank top nozzle.
- Fixed 45-degree orthographic camera and authored Cycles lighting; one camera.
- 128px and 256px RGBA cells, with a stable 3.35-tile canvas and ground pivot.
- Native draw registration is per direction: at 256px N/S use scale 0.41875, E/W 0.592201857, with separate shifts. The source capture canvas/geometry are unchanged. See the production job and [visual correction](../../../docs/art/boiler-v08-visual-alignment/README.md).
- A 2x2 footprint and native rear-row water/steam pipe connectors.

The generated module is registered after legacy graphics rescaling. The runtime uses a static cold structure plus a native conditional activity clip. All 96 working poses, rattle rigs and nozzle steam are retained; the original idle/working source atlases remain untouched. The small cold-alpha compatibility adjustment, source-pixel bounds, filtering repair and actual native four-direction cold/working/stopped review are documented in [state-layer evidence](../../../docs/art/boiler-v08-state-layers/README.md). The inherited duplicate burner smoke is removed as a visual-only adjustment. Circuit-wire placement is now native-reviewed at the measured fixed cage-top mount; see [wire evidence](../../../docs/art/boiler-v08-wire-attachments/README.md). The optional sprite-dependency startup gate is now resolved in the wider mod; see the import proof below.

[Game-ready package](https://chatgpt.com/library?file_id=libfile_dfa7cc946308819186108d67de62cc95&account_id=personal)
includes the sprite atlases, Lua, native prepared Blender scene, saved MODEL/RENDER
master, export scripts and QA records.

[Four-direction animation](https://chatgpt.com/library?file_id=libfile_13f665ace7208191bcb2b885818e841b&account_id=personal)

[Approved editable native model](https://chatgpt.com/library?file_id=libfile_472d55643ae4819189e12200eb66d4ca&account_id=personal)

Validation: all 388 source captures and 776 final atlas cells verified, source/master
hashes checked, master independently reopened, and final cardinal mappings checked.
The actual exported Lua loaded in Factorio 2.1.24 with the full native mod; pipe pairs
connected and all four boilers produced steam over a 600-tick probe. Those are historical records; current native graphical state acceptance is linked above, and no behavior/regression suite was rerun.

## Repeat the established export

The reconstructed prepared source is now checked in at `production-source.blend`.
Its [recovery evidence](../../../docs/art/boiler-v08-source-recovery/README.md) includes independent native reopen checks and eight actual local pilot renders.
It is a newly reconstructed binary, not the historical Library download.
Use Blender 5.0.1 or newer:

```sh
python3 tools/art/produce_factorio_asset.py --job tools/art/jobs/boiler-v08.json --blender /path/to/blender
```

The common exporter supports hash-verified checkpoint resumption. See tools/art/README.md.
The prior low-resolution Eevee previews are obsolete timing drafts; this export uses
Cycles with the authored scene lights, world and packed materials.

The earlier common native shift/scale was visually rejected even though the pipe systems connected. The subsequent four-way sprite-only registration is recorded in the linked native visual review. Do not infer visual alignment from the historical fluid connectivity probe above.

To reconstruct again from the exact approved V07b file, use `tools/art/rebuild_boiler_source.py` as documented in the recovery evidence. Existing production sprite replacement still requires full capture and visual-state acceptance.

The source/render/pipe/wire slices are reviewed in the isolated dependency-enabled native profile. This does not prove loading with the optional Mechanicus mod disabled.

The separate optional Mechanicus sprite-namespace gate is now resolved and native-loaded both absent/enabled; see [import proof](../../../docs/art/priest-sprite-import/README.md). Boiler G5 static cold-pose interchange now passes; see [independent GLB evidence](../../../docs/art/boiler-v08-glb/README.md). No animated GLB is claimed. Earlier dependency-enabled views retain their original evidence scope.
