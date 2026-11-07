# Fortified Martian Bunker v1.0 — EXACT reference-bound cleanup

**Actual source mesh change, not image generation.** User rejected the giant bulbous blue muzzle crown and giant raised roof plate on the v0.9 Blender model. They are not in the user-selected image.

Changes only to existing geometry:

1. Slender 48-sided **true open-bore** muzzle with maximum outside radius **0.110** instead of **0.159**. No change to length, pressure barrel, jacket, bearing or inner bore.
2. Delete **one** unsupported roof slab (`87_roof_red_inspection_armor`) and its **four** fabricated top bolts. The underlying turret roof is unchanged.
3. Exactly **193 meshes remain geometrically identical**, with no added elements, no relocated optics, no new rings or plates. Source count **199 → 194**, turret rotating count **110 → 105**.

Use the original selected image from `../style-references/visual-target-v08.png` as the visual specification. See `REFERENCE_CONFORMANCE.md`. Programmatic `verify_reference_fidelity_v10.py` compares every mesh against v0.9 and fails if ANY other geometry is modified, while Blender export and clean reimport check actual attachment and material identity.

Regenerate: `python build_blockout.py && python make_textures.py && python verify_reference_fidelity_v10.py && python verify_barrel_v10.py && python verify_visual_target_v10.py` then the Blender `setup_blender.py` and `verify_exported_blender_glb.py` pipeline. The primary render comparison is the model from v0.9 versus the newly corrected v1.0 from identical camera positions. No extra decorative geometry permitted.

**Status:** mechanical/source correction only; full reference fidelity remains unapproved until the user inspects the actual Blender render. No gameplay sprites changed.
