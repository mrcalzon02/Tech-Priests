# Industrial Blender material and parts library (source-indexed v1)

This library consolidates **existing committed assets**, not fake or regenerated parts. All 23 material presets and 69 texture PNGs already live in the Martian Bunker v10 source. The catalog points to the original tracked files, with Git blob identities and sizes, so we don't duplicate ~20 MB of PBR images or overwrite approved texture work. The material importer below loads actual Blender node materials, packs the images into a consuming .blend, and preserves source provenance.

## Source machines

- **Martian bunker v10:** native packed .blend, 194 documented geometry objects, 23 procedural weathered PBR materials, 69 maps; this index contains 21 practical candidate objects (bearings, collars, housings, vents, controls, service attachments). A source mesh is not automatically an interchangeable part.
- **Emergency boiler v08:** native production-source.blend and independently checked static interchange .blend/.glb; inspect support cage, valves, canister mounts and actual fluid interfaces before extracting named components.
- **Condenser v21:** real integration script and mesh-join/validation records. Its calibrated east-mouth plane is (1, -0.5, .36) on a **2x2 condenser**. The native .blend package remains a Library item; the checked-in script depends on its underlying v20 scene. Don't invent an unavailable source.
- **Emergency miner:** source-visible-only Blender generator; candidate operators include `cable_gland`, `routed_cable`, `octagonal_case`, `lofted_cast_chassis`, `frame_ring` and `bolt`. Preserve the no-hidden-internals rule.
- **Emergency assembler:** original sprite exists, but a matching standalone native model has not been independently located in the inspected committed paths. Marked as reference-only, not a verified donor.
- **Timber workbench v05:** committed animated source ZIP is available as a *different* machine; do not confuse it with emergency assembler.

## Use in Blender

From the repository root in Blender Python:

```python
from pathlib import Path
import sys
sys.path.insert(0, str(Path('art/source-to-3d/shared-parts/industrial-asset-library').resolve()))
from import_materials import import_materials
mats = import_materials(Path('.').resolve(), ['machine_steel', 'iron', 'brass', 'martian_red', 'ferrocrete_dark'])
# Object must have suitable UVs; explicitly assign mats['machine_steel'] and inspect rendered result.
```

**Material slots ≠ reusable geometry.** Use the documented `art/source-to-3d/shared-parts/metallic-hydrogen/registry.json` for parts promoted from measured and independently tested component scenes. This candidate inventory alone does not claim native Factorio ports, dimension-compatible fittings, game integration, or acceptance. Preserve per-part provenance, non-destructive source revision, real mesh contact, and a fresh Blender roundtrip before status becomes verified. No new GitHub workflow is needed.

Run the stdlib catalog check with `python art/source-to-3d/shared-parts/industrial-asset-library/validate_library.py --repo-root .`.
