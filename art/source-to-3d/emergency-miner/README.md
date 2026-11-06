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

## V04 — reconstruction decision (2026-11-05)
The actual sprite has been inspected in GitHub Actions. It is an **overhead view of an armored control-and-services deck**, not an illustration of an exposed drill. Its visual landmarks include the octagonal armor, lower shoe, paired perimeter corrugated hydraulic hoses, crossing red/green cables, upper vent slots and three power sockets, green computer display, four indicators and the front cable bank. None proves the location or form of the underground extractor.

The previous V03 candidate rendered an **unsupported front-projecting horizontal auger**, giving the game candidate a different silhouette from the source. V04 removes this and makes a defensible **vertical underground boring hypothesis**: below-deck motor/reducer, real bearing and spindle, thick helical flight and pointed cutting bit. The view matching the original contains ONLY source-visible parts. The isometric and low physical inspection views may show the inferred underside. All inferred parts live in the separate Blender collection `INFERRED_UNDERBODY_MINING_MECHANISM`.

### Doctrine-to-component contract
The six explicit `functional_paths` in the model manifest trace existing source features through **physical modeled** equipment to their load: drive/shaft, power, tachometer data, lubricant return, ore discharge and bearing inspection/oiling. Each endpoint is an actual named 3D object. This applies [the canonical construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) without decorating the source plate with unrelated skulls or red paint. A small Martian-red cover is confined to the **inferred underbody service assembly**.

A resemblance pass is still necessary: compare the 680 px source with the true top orthographic Blender render, then inspect 43 px actual-size swatches. Object count, GLB export and CI green lights are **construction evidence**, not proof of screenshot-level matching.

**Scope lock:** no sprite replacement, no prototype/entity changes, no changes to the current Factorio mining mechanism and no third-party Factorio model redistribution. The V04 inspection deliverable is a new editable `.blend`, `.glb`, exact original-reference hash, three true-mesh renders, contact sheet and model manifest. Approval remains pending.
