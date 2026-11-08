# Published timber workbench game sprites

The approved V5 hammer / sparks / heat / laydown / cooling cycle replaces the graphics of `tech-priests-emergency-assembler`.

- One-tile footprint; existing crafting recipes, speed and fuel behavior retained.
- Four cardinal sprite sheets, each 1536 × 1024 pixels with 96 frames of 128 × 128.
- 12 fps / eight-second cycle (`animation_speed = 0.2` at 60 ticks/sec).
- Transparent background and integrated soft shadow; fixed scale 0.5 and ground-origin shift.
- Cold resting idle in all four directions, with repeated frames matching the working animation length.
- Matching 64px item, recipe and entity icon.
- Camera and object geometry retained from the approved model. One camera; no studio ground in the sprite.

Re-export the native animated Blender file from `../workbench-v5-animation/Workbench_V5_Animated_Source.zip`:

    blender -b -t 6 --python export_workbench.py -- --source /absolute/path/rough_timber_workbench_v5_animated.blend --out /absolute/path/export

Assemble the verified frames into the game asset directory:

    python3 assemble_sheets.py --export /absolute/path/export --asset-dir /absolute/path/tech-priests_src/graphics/entity/timber-workbench

The exporter preserves the impact extremes when reducing to 12 fps. `--refresh-impacts` refreshes just impact and final-cold frames in an existing export.

`validation.json` records the native Factorio 2.1.24 startup/crafting checks and atlas verification. The headless run validates native prototype loading and actual crafting; it does not render the Factorio GUI.
