# FMPL Surfaces — procedural construction materials

25 original, named Blender material presets are defined in `catalog.json`; they are additive to FMPL's 23 existing image-backed PBR materials and 28 FX materials. Importers must never replace accepted boiler, condenser or structural concrete source materials in place.

`blendswap_sources.json` is a **metadata-only** CC0 candidate catalog, manually checked against each individual BlendSwap asset page. It is NOT a download cache. CC0 is claimed by the uploader and must be independently reviewed for embedded third-party textures and version compatibility. The old Blender 2.6–3.x source versions are not assumed to load under Blender 5.2.

Source reference: Sam Bowman's [Procedural Nodes part 32 — Cracked Mud with Rocks](https://www.youtube.com/watch?v=iuaZuDiMv6s). Implement original Blender shaders with distinct crack, rock, bump, color and mask controls. Do not copy YouTube frames, Patreon files, or node groups.

Native artifact `FMPL_surfaces_v1.blend` is produced only after running the real builder and a separate Blender reopen verifier. Use a fixed boiler-standard 45°/0° camera; build one real 25-swatch proof and a true 64px readability set. No automatic simulation bake or extra CI workflows. Assets remain technical candidates until user-reviewed.

Blender command (from Tech-Priests repo root):
```
blender -b --factory-startup --python-exit-code 1 --python tools/fmpl/surfaces/build_library.py -- --catalog tools/fmpl/surfaces/catalog.json --out D:/Runner/fmpl-surfaces-output
blender -b --python-exit-code 1 --python tools/fmpl/surfaces/verify_library.py -- --catalog tools/fmpl/surfaces/catalog.json --out D:/Runner/fmpl-surfaces-output
```

Check `source_gate.py` before any user-supplied BlendSwap file import. This step is read-only and checks local file hash/license metadata without promoting content automatically.

**Ownership:** canonical source and runtime standards in Tech-Priests, worker dispatch only through the existing Dens Mortis private runner controller. No new GitHub Actions workflow.
