# Fortified Martian Bunker — development progress gallery

This gallery records the original 3×3-footprint model under the [construction doctrine](../../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md).

## v0.3 — corrective native Blender import and alignment (pending workflow proof)

The previous **v0.2 Blender renders were visibly wrong**: sideways, monochrome, and apparently disconnected. Their CI job checked mesh counts, not orientation, material identity, or physical alignment. **Do not use the v0.2 Blender PNGs as design or approval references.** Source geometry and direct preview in v0.2 remain valid structural references.

[v0.3 reproducible Blender source archive](../revisions/v03/martian_bunker_v03_source.zip)

The corrective job builds Blender meshes from the original Z-up geometry, explicitly creates colored PBR materials, checks the base/cannon/antenna/turret world coordinates, confirms every 15° traverse of the moving assembly, exports the canonical GLB from Blender, and reimports that GLB in a fresh Blender scene. The final render check requires actual red visible pixels and valid framing. Publication of these new renders depends on all checks passing.

- [Corrected front view](v03_blender_front.png) — generated only on successful CI
- [Corrected rear view](v03_blender_rear.png)
- [256 px game-scale check](v03_blender_256px.png)

## v0.1 — initial structural blockout
![Initial front-angle bunker model](v01_front_isometric.png)

## v0.2 — good blockout geometry, failed Blender handoff
![v0.2 original-color front blockout](v02_front_isometric.png)
![v0.2 original-color rear blockout](v02_rear_isometric.png)
![v0.2 game-scale blockout](v02_factorio_scale.png)

Structural changes: strong octagonal corner chamfers on the intact 3×3 base, narrowed upper roof, lowered fixed rear magazine/controller, and the antenna standoff mounted to the rotating turret casing. These source geometry changes survive unchanged in v0.3.

[Rejected v0.2 Blender front image](v02_blender_front.png) and [rejected rear image](v02_blender_rear.png) remain for failure diagnosis only.

No Wube mesh or third-party Warhammer assets are bundled. Final native Factorio sprite quality and actual in-game suitability remain unapproved.
