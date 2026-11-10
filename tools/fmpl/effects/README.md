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

## Verified native import API

The [non-destructive import adapter](import_effects.py) takes the **verified saved .blend**, not a JSON-only material guess. Pin SHA-256 when reusing a cached library:

```python
import import_effects
mats = import_effects.import_materials(
    "/safe/local/path/FMPL_effects_materials_v1.blend",
    ["water-clear", "crude-oil", "heated-steel-red"],
    expected_sha256="SHA256_FROM_VERIFICATION",
)
target_object.data.materials.clear()
target_object.data.materials.append(mats["water-clear"])
collection, root = import_effects.append_rig(
    "/safe/local/path/FMPL_effects_materials_v1.blend",
    "steam-plume", anchor=(0.0, 0.0, 0.36),
    expected_sha256="SHA256_FROM_VERIFICATION",
)
```

The API fails on missing/mismatched assets or name collisions. An import does not prove correct in-game scale, pipe hookups, sprite anchoring, translucent sorting or user visual approval. `test_import_adapter.py` validates the source contract without a Blender installation.

### Production revisions

1.0.0: first native Blender 5.2.3 build and independent reopen, 16/16 captures; gas swatches too faint at native proof scale. 1.0.1: gas optical-depth and sample-label readability adjustments; **new native verification required** before visual readiness. Both remain source-derived candidates until actual render review.

## Optional Blender Asset Browser registration

The generated native .blend **marks the 28 materials and five rig collections as Blender assets**, but it does not silently modify interactive or service-account Blender preferences. The [registration utility](register_library.py) accepts a SHA-256 pinned, previously verified .blend and is dry-run by default:

```sh
blender -b --python tools/fmpl/effects/register_library.py -- \
  --blend /path/to/FMPL_effects_materials_v1.blend \
  --expected-sha256 SHA256_FROM_NATIVE_VERIFY
```

Add `--install` only when authorizing registration of that directory in the **current Blender account's Asset Browser**. This does not copy the asset to a shared network drive, make a private runner artifact permanent, approve its appearance, or modify any Factorio prototype.
