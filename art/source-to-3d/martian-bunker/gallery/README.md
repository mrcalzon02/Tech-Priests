# Fortified Martian Bunker — development progress gallery

Follow the [canonical construction doctrine](../../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md). **Source geometry is original.** No Wube production models or third-party 40K meshes are redistributed.

## v0.4 — corner buttress slope and all outer hull attachments

![v0.4 front source-geometry inspection](v04_front_blockout.png)
![v0.4 rear source-geometry inspection](v04_rear_blockout.png)
![v0.4 game-scale source preview](v04_256px_blockout.png)

These three images are direct mesh geometry diagnostics. The source passes **20 sloped face attachment assembly** checks and **8 beveled corner/foot part** checks, and keeps the original **3×3 foundation** plus 42 rotating turret meshes. Reference: [complete rebuildable v0.4 source package](../revisions/v04/martian_bunker_v04_source.zip).

### Native Blender views, published by the dedicated verification workflow

- [Front view](v04_blender_front.png)
- [Rear view](v04_blender_rear.png)
- [Opposite front corner](v04_blender_front_west.png)
- [Opposite rear corner](v04_blender_rear_east.png)
- [256 px native Blender preview](v04_blender_256px.png)
- [v0.3 versus v0.4 front comparison](v04_before_after_front.png)

**Acceptance:** CI must prove actual mesh vertex contact along the top and bottom of tilted mounting plates, inward-leaning buttress geometry, turret parenting and fixed rear clearance. It then opens the Blender-exported GLB in an independent scene and checks visible Martian-red materials. Source geometry diagnostic success is not final game-art approval.

## v0.3 — corrected Z-up, colors and turret attachment

![v0.3 corrected native Blender front](v03_blender_front.png)
![v0.3 corrected native Blender rear](v03_blender_rear.png)

[v0.3 native model](../src/v03/martian_heavy_weapon_bunker_v03.blend) fixed the catastrophic sideways/monochrome Blender import, but **still had hull fixtures floating relative to the subsequently beveled shell**.

## v0.2 — valid intermediate mechanical shape, broken Blender handoff
![v0.2 engineering front](v02_front_isometric.png)
![v0.2 engineering rear](v02_rear_isometric.png)

[Rejected Blender front](v02_blender_front.png) and [rejected Blender rear](v02_blender_rear.png) are retained for regression analysis only.

## v0.1 — initial blockout
![Initial model](v01_front_isometric.png)

**Art status:** open. Finish proper surface wear and material details, 360° collision/sweep inspection, and in-game Factorio-scale validation before any sprite replacement.
