# Fortified Martian Bunker — development progress gallery

## v0.6 — hollow barrel refinement and original PBR texture system

This revision uses an **owner-provided image as stylistic direction only**. The reference image is **not stored, reproduced, used as texture pixels, or imported as geometry**.

**Barrel:** The previous solid disk muzzle becomes a genuinely hollow, lathed pressure tube, with a stepped replaceable blue-tempered crown, open inner liner, three machined service collars, supported shroud heat rails and four seated crown ribs. Every new barrel part moves with the turret. The v0.5 bunker hull, 22 hull attachments, 8 sloped corner foot/buttress parts and antenna remain unchanged.

**Textures:** 20 original material classes, each with deterministic 384×384 tileable albedo, occlusion/roughness/metalness and tangent-space normal maps (60 image files total). Painted red, granular ferrocrete, heat-darkened metal, machined gray steel, brass, glass and other service surfaces have physically distinct finish. The finished Blender scene **packs image assets**, and the exported GLB must pass a clean Blender import with UVs and textures intact.

![Previous barrel / new open barrel / textured refinement](v06_three_stage_barrel_comparison.png)

![Original generated PBR material swatches](v06_material_swatch.png)

[Barrel three-quarter closeup](v06_barrel_three_quarter.png) · [Muzzle head-on](v06_barrel_head_on.png) · [Barrel side](v06_barrel_side.png) · [Full front](v06_textured_front.png) · [Full rear](v06_textured_rear.png) · [Factorio-scale 256px](v06_factorio_256px.png)

[**Native textured Blender master**](../src/v06/martian_heavy_weapon_bunker_v06_textured.blend) · [**Final PBR GLB**](../src/v06/martian_heavy_weapon_bunker_v06_textured_export.glb) · [Full source and map generator](../revisions/v06/martian_bunker_barrel_texture_v06_source.zip) · [Validation report](../src/v06/validation_report_v06.json)

**Status:** CI must pass and final renders need visual inspection. Not yet approved as production Factorio sprites. Neither sprites nor gameplay data are modified.


## v0.5 — two progressive refinements of the *front of the rotating turret*

These are **real Blender-rendered, editable two-stage geometry builds**, not concept illustrations.

**First pass:** The flat front cheek blocks become genuinely sloped faceted armor with positive thickness and an anchored rear edge. A four-piece mantlet surrounds a hollow steel gun socket and dust seal; the visor and optic were re-seated to the new front geometry.

**Second pass:** Two cheek trunnion covers and guards, removable fasteners, supported recoil-cylinder collars and brackets, the heat-shroud connection, and the elevation-limit index. No decorative boxes were added without a defined mechanical purpose. Both passes preserve the 3×3 foundation, hull-mounted equipment, aft magazine, turret bearing and antenna.

![Three stages — v0.4 baseline, armored turret shape, and attached front hardware](v05_assembly_progress_3stage.png)

![Close turret comparison, first and second passes](v05_turret_close_comparison.png)

[First pass: front armor](v05_pass1_turret_close.png) · [Second pass: final turret closeup](v05_pass2_turret_close_front.png) · [Final head-on view](v05_pass2_turret_head_on.png) · [Full front](v05_pass2_full_front.png) · [Full rear](v05_pass2_full_rear.png) · [256px](v05_final_256px.png)

[**Editable pass-one Blender model**](../src/v05/martian_heavy_weapon_bunker_pass1_v05.blend) · [**Editable pass-two Blender model**](../src/v05/martian_heavy_weapon_bunker_v05.blend) · [final Blender-exported GLB](../src/v05/martian_heavy_weapon_bunker_v05_blender_export.glb) · [rebuildable source ZIP](../revisions/v05/martian_bunker_turret_front_v05_source.zip) · [test report](../src/v05/validation_report_v05.json)

Automatic Blender testing includes an independent clean-scene GLB reimport, turret parenting and 15-degree traverse checks, mesh watertightness for new facial armor, open barrel socket, mounting contact, and an actual rendered pixel difference between stages. **Provisional art only:** full recoil animation, detailed PBR wear and game sprite approval remain pending.


Follow the [canonical construction doctrine](../../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md). **Source geometry is original.** No Wube production models or third-party 40K meshes are redistributed.

## v0.4 — corner buttress slope and all outer hull attachments

![v0.4 front source-geometry inspection](v04_front_blockout.png)
![v0.4 rear source-geometry inspection](v04_rear_blockout.png)
![v0.4 game-scale source preview](v04_256px_blockout.png)

These three images are direct mesh geometry diagnostics. The source passes **22 sloped face attachment assembly** checks and **8 beveled corner/foot part** checks, and keeps the original **3×3 foundation** plus 42 rotating turret meshes. Reference: [complete rebuildable v0.4 source package](../revisions/v04/martian_bunker_v04_source.zip).

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
