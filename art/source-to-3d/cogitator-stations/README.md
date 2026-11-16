# Cogitator stations

Five approved cogitator stations with editable source models and four-direction Factorio sprites. Each native Blender scene has four mechanical collections for the chassis and fluid circuits, instruments, gantry, and pinned foot chains. Materials and display textures are packed. Each matching GLB contains the station meshes and embedded textures.

| Station | Identifying equipment |
| --- | --- |
| Junior | Jade pilot lens, winged cog seal, open gantry and porcelain bus taps |
| Intermediate | Compact gantry, gilded shoulder shields and a winged central seal |
| Senior | Armored shoulder shields, central green CRT and keyboard |
| Planetary Magos | Central CRT and keyboard plus separate left and right operator displays |
| Void | Steel crosshead, lateral feedthroughs, inspection pods and two green sight glasses |

## Rebuild in the Tech-Priests checkout

The native scenes and GLB readback were verified with Blender 4.3.2. The supplied inspection renders used Blender 5.0.1 with Cycles denoising. Run from this directory in the checkout or the extracted standalone model package. The builder locates the repository's FMPL tools, Pipette catalog and surface definitions. The original FMPL source revision used for this study was 707363a27a870839b962fa58a75a4002afe78900.

    blender -b -t 2 --python-exit-code 1 -P stations_src/build.py -- junior --stage final --out models --views
    blender -b -t 2 --python-exit-code 1 -P stations_src/verify.py -- --assets models --reports checks --editions junior

Build keys are junior, intermediate, senior, planetary and void. The planetary files use the slug planetary-magos. The empty view list in the first command writes the Blender and GLB files. To render inspection images from the saved scene:

    blender -b -t 2 --python-exit-code 1 -P stations_src/build.py -- junior --stage render --out models --views front threequarter chain --samples 32

The saved scenes retain the FMPL 45-degree orthographic camera. The review renders use temporary inspection cameras to show the reference-facing details, chain pins and controls.

## Native station sprites

Junior, Intermediate, Senior, Planetary Magos and Void each use their own directional container picture. The operator face points south. In-game placement and rotation choose the north, east, south or west row of the station's atlas. Each rotation includes a separate ground shadow projected from the evaluated meshes along the key light's axis.

The captures use the fixed FMPL orthographic camera at 45 degrees and the four lights, AgX view transform, textures and materials of the approved scene. Only the model rotates around its ground origin. High resolution uses 320-pixel frames at scale 0.5. The standard station sprite startup setting selects 160-pixel frames at scale 1. Both resolutions place the feet on the same 2 × 2 footprint.

From the repository root, reproduce the production captures with Blender 5.0.1 and a Python environment containing Pillow and NumPy:

    python art/source-to-3d/cogitator-stations/stations_src/capture_factorio.py --repo . --work /tmp/station-capture --blender blender

The command uses the repository's FMPL sprite worker and writes color and shadow atlases to tech-priests_src/graphics/entity/cogitator-station/fmpl. Use --rank with a single model slug for a partial rebuild. The review sheet composites the packed runtime layers using their in-game shifts.

[Cardinal rotations](review/factorio-cardinal-rotations.jpg) · [Capture settings and asset hashes](review/factorio-capture.json)
