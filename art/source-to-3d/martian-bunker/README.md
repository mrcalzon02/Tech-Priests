# Red Tech Priests — Fortified Martian Heavy-Weapon Bunker

**Current revision:** v0.3 repair of broken Blender conversion; source geometry and design remain the v0.2 owner-approved blockout. **No game sprites or prototypes changed.**

Read the [canonical construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) and the [development gallery](gallery/README.md).

The earlier v0.2 direct blockout was correct, but the v0.2 native Blender output was **sideways, monochrome and visibly misassembled**. The workflow verified only object counts; that was insufficient. The v0.2 native Blender previews are explicitly rejected, retained for forensic comparison.

**Corrective v0.3 source:** [standalone ZIP](revisions/v03/martian_bunker_v03_source.zip). It contains original coordinate meshes, color/material identities, 131-part source, rotation groups, generator and Blender reconstruction/reimport tests. The [single Blender Actions workflow](../../../.github/workflows/martian-bunker-3d.yml) publishes a canonical native `.blend`, Blender-exported `.glb`, verified front/rear render and 256-pixel preview only after orientation, material and attachment checks pass.

**Fixed geometry rules:** 3×3 strongly chamfered foundation, narrower armored roof, stationary rear magazine and controller below rotating turret, rear-mounted co-rotating antenna, clear barrel. No geometry or third-party model licensing changes.

**Pending acceptance:** visually inspect v0.3 rendered model, check 360° mechanical clashes, refine materials/weathering/lighting, and compare actual in-game Factorio-scale display before replacing any production sprite.
