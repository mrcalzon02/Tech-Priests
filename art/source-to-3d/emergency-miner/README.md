# Emergency miner — one-asset-at-a-time 3D reconstruction

## Authority and scope
First target: `tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png` (1254×1254 source image). The sprite and mod-owned icon are already committed to Tech Priests. We must reconstruct **this specific machine**, not another rocket engine, generic drill, or an unrelated concept object. This workstream makes **no gameplay/prototype changes** until actual visual acceptance. The current prototype behaves as an assembling-machine with dedicated emergency-mining recipes; do not change that merely to draw a drilling machine.

## Production checkpoints
1. Audit the source sprite and icon, measure alpha bounding box, registration and prominent geometry; retain hash and unmodified reference; identify recognizable landmarks by human source inspection.
2. Write a machine component breakdown: main silhouette / base and feet / vertical assembly / drilling mechanism / power and transmission / ports / material and accent color. Mark any geometry hidden by the original as **hypothesis**, never as a proven source feature.
3. Build a full, editable Blender mechanical blockout from actual mesh primitives. Model physical connections, thickness, bearings, bores, cavities and real component layer order.
4. Inspect render against the **same** image at fixed camera/lighting; correct big shapes and proportions before greebles.
5. Refine metal surfaces and manufactured detail. Use correct bevels, cast vs milled vs painted textures, rust, scratches, grease, recessed lines, metallic response and ambient occlusion. Detail must hold up at native game scale, not merely in a 4K beauty shot.
6. Produce matched source-versus-render contact sheets and candidate Blender `.blend` source plus `.glb` mechanical export, 3D orbit renders, material manifests and reproducible hashes. Save/reopen all files. Original render remains the rollback asset.
7. Only after visual acceptance, make fixed-camera transparent high-resolution game frames; preserve registration, silhouette and prototype art scale; validate in game before replacing source art.

## Review dimensions
- Primary silhouette and dominant colors.
- Attachment and actual functional mining/readable mechanism.
- Industrial detail: distinct materials, meaningful mechanical joints, cast bolts, surface roughness, wear and controlled speculars.
- Factorio viewing distance, canvas extent, grounding/shadows and readable lighting.
- Explicit pass/fail proof that the reconstruction reads as **the existing emergency miner** at the same display size. A successful Blender job is NOT visual fidelity approval.

Current checkpoint: source audit in a single GitHub Actions job. Do not produce lookalike art or force a Blender candidate before visually identifying the authoritative sprite.
