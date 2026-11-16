# Cogitator stations

Five editable Tech-Priests industrial station studies. Each native Blender scene has four mechanical collections for the chassis and fluid circuits, instruments, gantry, and pinned foot chains. Materials and display textures are packed. Each matching GLB contains the station meshes and embedded textures.

| Station | Identifying equipment |
| --- | --- |
| Junior | Jade pilot lens, winged cog seal, open gantry and porcelain bus taps |
| Intermediate / fallback | Compact gantry, gilded shoulder shields and a winged central seal |
| Senior | Armored shoulder shields, central green CRT and keyboard |
| Planetary Magos | Central CRT and keyboard plus separate left and right operator displays |
| Void | Steel crosshead, lateral feedthroughs, inspection pods and two green sight glasses |

## Rebuild in the Tech-Priests checkout

The native scenes and GLB readback were verified with Blender 4.3.2. The supplied inspection renders used Blender 5.0.1 with Cycles denoising. Run from this directory in the checkout or the extracted standalone model package. The builder locates the repository's FMPL tools, Pipette catalog and surface definitions. The original FMPL source revision used for this study was 707363a27a870839b962fa58a75a4002afe78900.

    blender -b -t 2 --python-exit-code 1 -P stations_src/build.py -- junior --stage final --out models --views
    blender -b -t 2 --python-exit-code 1 -P stations_src/verify.py -- --assets models --reports checks --editions junior

Build keys are junior, intermediate, senior, planetary and void. The planetary files use the slug planetary-magos. The empty view list in the first command writes the Blender and GLB files. To render inspection images from the saved scene:

    blender -b -t 2 --python-exit-code 1 -P stations_src/build.py -- junior --stage render --out models --views front threequarter chain --samples 32

The saved scenes retain the FMPL 45-degree orthographic camera. The review renders use temporary inspection cameras to show the reference-facing details, chain pins and controls. The station studies are at the art review stage. Game sprites, animation and mod integration are separate production steps.
