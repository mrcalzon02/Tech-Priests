# Red Tech Priests — Fortified Martian Heavy-Weapon Bunker

**Current art revision: v0.3 — Blender-conversion repair verified.** 3×3 bunker geometry remains the owner-directed v0.2 blockout. No mod entity, recipe, animation, or production sprite changed.

[Construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) · [**See corrected development gallery**](gallery/README.md) · [**Passing Blender workflow**](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42153818744)

**Fixed:** the v0.2 Blender output had incorrect orientation, apparently detached parts and monochrome materials. The new v0.3 Blender scene is reconstructed directly from its original Z-up source geometry with explicit material/shader assignments. Correct sRGB-to-linear shader colors restore the deep Martian red and gray ferrocrete. The turret/mast/gun are attached to one traverse pivot while the concrete, magazine and controllers remain stationary. The script tests physical coordinates and every 15° of turret rotation. The exported GLB is reopened in a clean Blender session and tested again.

- [Native **editable** Blender scene](src/v03/martian_heavy_weapon_bunker_v03.blend)
- [Verified Blender-exported GLB](src/v03/martian_heavy_weapon_bunker_v03_blender_export.glb)
- [Full source ZIP](revisions/v03/martian_bunker_v03_source.zip)
- [Front and rear rendered gallery](gallery/README.md)
- [v0.3 geometry and image validation](src/v03/render_validation_v03.json)

**Art acceptance still pending:** 360° geometric collision probing for every subsystem (beyond fixed-equipment clearance and correct transform parenting), magazine/recoil animation, weathered PBR textures, lighting composition and actual native Factorio-size visual comparison. The rejected v0.2 Blender PNGs are retained solely as regression evidence.
