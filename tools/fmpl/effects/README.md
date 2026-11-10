# FMPL — executable effects/materials extension

Read [EFFECTS_STANDARD.md](EFFECTS_STANDARD.md) and [presets.json](presets.json). This is a **new** procedural FX library beside (not inside/replacing) the existing industrial PBR map importer.

28 materials: water/oil, lava/cooling, laboratory glass, acids/slurries, volumes for steam/smoke/toxic gas, flames/plasma, heat-treated and damaged metals, mud/snow. Five keyed geometry rig collections: fire, steam, chemical plumes, heat shimmer, water rings.

For Python-only validation:
```
python tools/fmpl/effects/test_presets.py
python -m py_compile tools/fmpl/effects/build_library.py tools/fmpl/effects/verify_library.py
```
Full native production (Blender binary):
```
blender -b --factory-startup --python-exit-code 1 --python tools/fmpl/effects/build_library.py -- --catalog tools/fmpl/effects/presets.json --out /scratch/fmpl-effects-001 --render all
blender -b /scratch/fmpl-effects-001/FMPL_effects_materials_v1.blend --python-exit-code 1 --python tools/fmpl/effects/verify_library.py -- --catalog tools/fmpl/effects/presets.json --out /scratch/fmpl-effects-001
```
Output directories must be new/empty. The builder emits a native .blend and 16 real gallery preview frames; a `proof` run emits 4 preview frames. Preview scene: one orthographic 45-degree fixed camera. Galleries are **not Factorio gameplay sprites**, and no simulation cache is baked.

To import a material asset:
```python
with bpy.data.libraries.load("/path/FMPL_effects_materials_v1.blend", link=False) as (src, dst):
    dst.materials = ["FMPL FX | crude-oil"]
```
To append animated rig geometry, append its named `FMPL FX RIG | ...` collection instead of manually copying render pixels. Transform imported rig roots to the target machine's physically appropriate emitter points, then align the native Factorio camera and game sprite export independently.

The standard is source-only until a native Blender runner produces, saves and independently reopens the actual library. No release or asset acceptance is implied.
