# Red Tech Priests — Fortified Martian Heavy-Weapon Bunker

**Current art revision:** v0.2 mechanical-clearance blockout. **Status:** candidate for visual refinement; no gameplay entity or original sprite changed.

Follow the [canonical construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md).

- [Development gallery](gallery/README.md), showing v0.1 versus v0.2.
- [Download v0.2 3D model + source package](revisions/v02/martian_bunker_v02_package.zip) — 3D `.glb`, mesh source, Blender setup, deterministic diagnostic renders and component manifest.
- [Automatic Blender build](../../../.github/workflows/martian-bunker-3d.yml) — single Ubuntu job, installs Blender, regenerates the GLB, saves an editable `.blend` with a co-rotating antenna/turret parent, renders two views and publishes validated files back into `src/v02` and `gallery`.

**Constraints:** fixed 3×3 base; strongly chamfered lower concrete; smaller upper roof; protected rear mechanism with clearance; mast behind turret muzzle and attached to rotating casing. All geometry is independently modeled, rather than copied from the official assembler STL.

**Approval pending:** full 360° traverse inspection in Blender, recoil/elevation animation, meaningful materials/texture weathering, and pixel-scale comparison against genuine Factorio art. The GLB check verifies geometry envelopes; it is not a real combat, rendering, or production gameplay pass.
