# Martian alternative turrets — V02: restore the established bunker

V01 used the bunker embedded in the M2 V10 turret-shot file. Forty base objects in that source had lost their placement transforms relative to the intact full M2 bunker. The previous validation incorrectly used that damaged source as its baseline. V01 mounted previews are rejected.

V02 restores the complete base from `martian_bunker_M2_paving_v6.blend` (Library `libfile_747d3fcea6ec81919358e3694b565957`), before split-capture/firing-rig preparation. The bunker geometry and world matrices are checked against this independent intact source, including its hatch reinforcement, side cabling, sensors, braces, stepped foundation and gray paving. The turret entity files and their GLBs remain byte-identical to V01.

## Files

- `energy_dish_entity.blend`: self-contained, independently editable energy-dish turret.
- `grenade_lobber_12_entity.blend`: self-contained twelve-tube lobber; three rows of four.
- `*_v02.blend`: mounted contexts with the restored original bunker; supplied in the complete review package because these scenes exceed the connected GitHub blob-upload limit.
- `*_v01.glb`: unchanged turret-only mapped exports; the filename retains their actual geometry revision.
- `Turret_Blockouts_V02_Review.png`: real mounted, independent and front review renders.
- `Intact_Source_Base_Control.png` and `*_Base_Preservation_Check.png`: base-only renders from the intact source, before/after appending each turret.
- `source_comparison.json`: identifies all forty lost V01 placement transforms and the correct source geometry/matrices.
- `build_validation.json`, `reopen_validation.json`, `entity_validation.json`, `base_render_comparison.json`: executed checks, including reopened native files, GLB reimport and independent base verification.

## Interpretation and materials

The sketch is interpreted as a rectangular concave energy reflector with a central emitter and triangulated supports. The lobber has twelve hollow tubes in three rows of four at a provisional 45-degree elevation. These remain primitive massing models; width, hidden depth and elevation are blockout hypotheses. Detailed heraldry, service hardware, ammunition systems and firing animation remain later work. No astrology glyph is added.

The committed oxide-red, gunmetal, machined-steel and brass image maps are included under `textures/`, packed into each entity and embedded in the GLBs. `texture_provenance.json` preserves original repository commit and map hashes. The intact source bunker retains its own original material graphs.

## Reproduce

Use Blender 5.0.1. To restore mounted scenes from the provided entity files:

```sh
blender -b /path/to/martian_bunker_M2_paving_v6.blend -t 4 --python-exit-code 12 --python restore_intact_base.py
blender -b -t 4 --python-exit-code 12 --python verify_turrets.py -- /path/to/this-directory
python verify_base_renders.py
python make_review.py
```

`build_turrets.py` also reconstructs primitive turret geometry from the same intact source and included textures. It explicitly rejects split/shot sources. The mount interface remains `(0,0,1.70)` and the elevation pivot `(0,0,2.34)`. The smaller native entity files are separately verified; the complete ZIP includes both native entities and mounted contexts. Checksums cover the complete review package, including the larger contexts supplied separately from this repository folder.
