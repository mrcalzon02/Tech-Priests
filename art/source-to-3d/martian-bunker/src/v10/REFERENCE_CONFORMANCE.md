# v1.0 — source image is the specification

Target: user-selected `Weathered Martian Bunker Turret.png` (displayed in the conversation, and retained in GitHub as `style-references/visual-target-v08.png`). This image is a visual reference, NOT a substitute for a 3D model.

## Required corrections, no invented geometry

- Remove the oversized conical/bulbous blue muzzle knob. Its maximum outer radius must be no more than 0.110 tile units. Retain the 0.047 radius open bore, plain tapered gun tube, subtle thermal finish and original forward muzzle position.
- Delete the large raised rectangular `87_roof_red_inspection_armor` and its **four** invented roof bolts entirely. Preserve the continuous original turret roof; do not replace with another plate.
- Absolutely no other changes to source geometry: every other v0.9 mesh is byte-for-byte identical in vertex/face data. No added rings, boxes, sensors, plates or bolts.
- Keep 3×3 foundation, inward-sloping buttresses, hull-mounted fittings and rotating gun grouping.
- All source and native Blender screenshots must be the **real modified model**, never AI-generated illustration.

## Acceptance

- Before/after mesh geometry comparison and close barrel inspection.
- Mechanical consistency verified in Blender and GLB clean import.
- The reference image has richer texture detail than the procedural asset; this pass fixes the two explicitly rejected geometries without claiming full reference fidelity or final sprite acceptance.
