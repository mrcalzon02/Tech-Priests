# Red Tech Priests bunker — v0.6 barrel and original PBR materials

Continue only the owner-approved v0.5 bunker and turret. The newly supplied visual is a **stylistic reference**, not a source texture, mesh, or work to be redistributed. The v0.5 coordinates, rotating assembly, hull and anchor details remain unchanged outside the weapon's forward barrel and original material system.

## Barrel geometry
- Actual open-bore steel pressure barrel, tapered from 0.109 to 0.102 tile-units outer radius, with 0.058+ inner bore.
- A stepped thermal muzzle crown forward to Y=-2.025 with fully open core; separate inset sacrificial liner (minimum 0.047 bore radius).
- Three clamped inspection/thermal sleeves with measurable overlap, and four short forged crown stiffeners.
- Two longitudinal, fully attached outer shroud heat bars, not decorative dangling rods.
- Maintains breech, recoil cylinders, original mantlet opening, targeting and rear mast.
- All new pieces are co-rotating. Explicit 15-degree turntable tests in Blender.

## Texture system
- `make_textures.py` generates **60 independently authored 384×384 tileable PNGs** (20 material classes × albedo, occlusion/roughness/metalness, tangent-space normal).
- Physically distinct concrete, painted Martian red, heat-tempered crown, blued/dark pressure steel, polished clamps, brass, optical glass, seals. Scratch/pit density is deliberately modest for native Factorio scale; no third-party/reference-image pixels are incorporated.
- `setup_blender.py` creates box-projected UVs on every mesh and builds linked Principled BSDF materials from packed images. Exported GLB should preserve albedo, UVs and normal/metallic texture references; the reimport checker rejects a lost-texture export.
- `BUNKER_TEXTURE_MODE=FLAT` produces a base-color-only geometry view; `TEXTURED` is the default and generates the finished comparison.

## Gates and limitations

Run `python build_blockout.py && python make_textures.py && python verify_barrel_v06.py` locally. A dedicated **single GitHub Action** installs Blender, saves both editable `.blend` versions, renders multiple closeups, exports and reimports GLB, checks all image and geometry gates, and commits results to the development gallery. Geometry source is Z-up, +X east, -Y forward. Footprint stays 3×3.

Still **unapproved as a final Factorio sprite**: need in-game light response, projected game scale, high-effort material/art review and real recoil movement checking. No prototypes or existing sprites are altered.
