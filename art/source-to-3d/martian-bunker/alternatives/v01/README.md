# Martian bunker alternative turret blockouts — V01

Two independent editable primitive assemblies, fitted to the established M2 bunker bearing at world Z=1.70. The bunker base is copied intact from the packed M2 V10 source; original cannon and firing effects are removed from these alternative scenes. Source remains unchanged. This is a massing review checkpoint, not production sprites or gameplay integration.

## Models

`energy_dish_entity.blend` and `grenade_lobber_12_entity.blend` are the compact, self-contained turret-only native entities committed here. The larger `*_v01.blend` scenes retain the bunker for fit review and are supplied in the complete review ZIP; they are omitted from this repository folder because the connected upload route rejects their size. `entity_validation.json` verifies the smaller native files separately.

- `energy_dish_v01.blend`: curved rectangular reflector, central forward feed/emitter, triangulated focal supports, rim nodes, backing spine and trunnion cradle.
- `grenade_lobber_12_v01.blend`: exactly twelve hollow tubes, three rows of four, reinforced muzzles, closed breeches, row supports and elevation cradle.
- Corresponding GLBs contain only the turret assembly, including traverse/elevation hierarchy and mapped textures. The native scenes also include the established bunker as a separately named collection for fit review.
- `*_mounted.png`, `*_turret.png`, `*_front.png` and `*_rear.png`: actual Blender renders. `Turret_Blockouts_V01_Review.png` gathers the mounted and isolated front/oblique comparisons.

## Reference interpretation

The owner sketch is preserved under `reference/`. Its dish is interpreted as a rectangular concave trough: curved vertical side profiles, straight cross-width edges, a central emitter and support struts. The drawing shows three lobber tube rows; four tubes per row supply the requested total of twelve. Width, proportions, 45-degree lobber elevation and hidden depth are inferred blockout choices awaiting visual review.

Construction stays at visible primitive massing. Detailed heraldry, sensors, service routing, ammunition handling and firing animation are not modeled at this checkpoint. No Mars/astrology glyph is carried over from the old turret. Only geometry visible in intended renders is built.

## Materials and provenance

The new turrets use the existing committed `art/material-libraries/martian-bunker-reference/v01/textures/` oxide-red, dark-gunmetal, machined-steel and tarnished-brass base-color/roughness/metallic maps. The twelve reused maps are also included under `textures/`, with original commit and SHA-256 provenance in `texture_provenance.json`. All image dependencies are packed into each native model. New meshes receive actual UVs and the same material channels are included in GLB. Base material graphs and geometry remain inherited from M2 V10.

Base source: `martian_bunker_M2_symbology_v10.blend`, Library version 3, source asset checkpoint previously published at Tech-Priests commit `40a3355`. Source geometry/material signatures and mount dimensions are recorded in `build_validation.json`; final reopened-native and GLB checks are recorded in `reopen_validation.json`. Per-file hashes are recorded in `checksums.json`.

## Reproduce

Blender 5.0.1 is required by the packed source format. From this directory:

```sh
blender -b /path/to/martian_bunker_M2_symbology_v10.blend -t 4 --python-exit-code 12 --python build_turrets.py -- /path/to/output /path/to/this-checkpoint/textures
blender -b -t 4 --python-exit-code 12 --python verify_turrets.py -- /path/to/output
blender -b -t 4 --python-exit-code 12 --python save_entities.py -- /path/to/output
python make_review.py
```

Traverse pivot: `(0,0,1.70)`. Elevation pivot: `(0,0,2.34)`. Both are editable empties, with independent weapon meshes below the elevation pivot. No motion clips are claimed; animation remains a later pass.
