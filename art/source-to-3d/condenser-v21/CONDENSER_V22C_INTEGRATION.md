# Atmospheric Water Condenser V22C — Factorio 2.1 integration

## Approval and scope

The owner accepted the real Blender Cycles V22C animation after seeing the corrected rack, soft mist and four-direction proof. The source is SHA-locked V21 (`1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b`) plus the V22C keyed original object animation. No new source machine meshes, changed resource recipes, fuel balance or hidden geometry are authorized.

## Source and export policy

- Exact original source restored from `source-parts/`; the animated derivative is reconstructed via `animate_condenser_v22.py --build-only` and includes the locked 187-mesh geometry/parent receipt.
- Render native Cycles at 512 square, 48 samples, 45-degree FMPL camera, four yaw headings: 0, 90, 180, 270. The camera remains fixed; the source machine rotates temporarily only during capture.
- Authoritative 96-frame/8fps loop is sampled every third frame (32 frames over 12 seconds). Higher frame-rate export can be added later without modifying the 12-second source loop.
- Each game direction has 4 ordered eight-frame active atlas slices (4 columns × 2 rows each) and one static idle slice reused 4 times. `512px` HR and a true downscaled `256px` SD set share the same world registration. Only HR is bound to Factorio 2.1; automatic sprite quality downscaling uses the authored source. Separate SD PNGs remain as reproducible assets.
- World registration: 3.2 tile-span × 512 native pixels, HR scale 0.2, SD scale 0.4. These produce 102.4 default-zoom pixels for the full 3.2-tile view, with the actual body occupying the expected 2x2 footprint. Do not crop per heading or per frame, which would break registration.
- Native Blender 0°/90°/180°/270° maps to Factorio north/west/south/east respectively. Source outlet flange is at Blender `(1,-0.5,0.36)`; Blender Y is opposite to Factorio world Y, so the corrected 2x2 east FRONT-row fluidbox socket is `position={0.5,0.5}`. Keep the original physical source flange, joint and camera world registration fixed. Four real independent engine/pipe checks and a new genuine 16-screenshot graphical client capture are recorded in `CONDENSER_V22C_NATIVE_PHYSICAL_ACCEPTANCE.md`.
- Do not rewrite/erase the original `martian-micro` placeholder sprites, collision boxes, recipes, `fuel_categories`, or energy values. The graphics patch is only enabled after all asset hashes and source constraints pass.

## Required verification before declaring shipped

1. Exact original V21 SHA and world/parent matrix receipts validated, native Blender source reopens and 4 × 32 real Cycles frames render with matching hashes.
2. Packer validates frame order and produces 4-way HR/SD PNGs, icon, and SHA manifest; only the 512 HR files are loaded by Factorio 2.1 at scale 0.2.
3. Lua patch `prototypes/generated_graphics/atmospheric-water-condenser-v22c.lua` is required from `data-final-fixes.lua` only with all images present. Verify prototype boot and 2x2 fluidbox alignment in Factorio runtime; stop release on missing input/assets or engine load failure.
4. Archive the Blender derivative, four-direction proof, atlas manifest and engine test logs. Rollback by removing only this new require to return to old `martian-micro` art.

This stage replaces visuals, not recipe or energy behavior. The 12-second animation is constant paced, while crafting itself remains governed by the existing condenser recipe and burner.
