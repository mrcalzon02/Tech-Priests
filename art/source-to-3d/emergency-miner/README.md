# Emergency miner — one-asset-at-a-time 3D reconstruction

## Authority and scope
First target: `tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png` (1254×1254 source image). The sprite and mod-owned icon are already committed to Tech Priests. We must reconstruct **this specific machine**, not another rocket engine, generic drill, or an unrelated concept object. This workstream makes **no gameplay/prototype changes** until actual visual acceptance. The current prototype behaves as an assembling-machine with dedicated emergency-mining recipes; do not change that merely to draw a drilling machine.

## Production checkpoints
1. Audit the source sprite and icon, measure alpha bounding box, registration and prominent geometry; retain hash and unmodified reference; identify recognizable landmarks by human source inspection.
2. Write a machine component breakdown: main silhouette / base and feet / laser emitter array / optical apertures / modulated power and waste processing / ports / material and accent color. Mark any geometry hidden by the original as **hypothesis**, never as a proven source feature.
3. Build a full, editable Blender mechanical blockout from actual mesh primitives. Model physical connections, thickness, shielded optics, collection ducts, cavities and real component layer order.
4. Inspect render against the **same** image at fixed camera/lighting; correct big shapes and proportions before greebles.
5. Refine metal surfaces and manufactured detail. Use correct bevels, cast vs milled vs painted textures, rust, scratches, grease, recessed lines, metallic response and ambient occlusion. Detail must hold up at native game scale, not merely in a 4K beauty shot.
6. Produce matched source-versus-render contact sheets and candidate Blender `.blend` source plus `.glb` mechanical export, 3D orbit renders, material manifests and reproducible hashes. Save/reopen all files. Original render remains the rollback asset.
7. Only after visual acceptance, make fixed-camera transparent high-resolution game frames; preserve registration, silhouette and prototype art scale; validate in game before replacing source art.

## Review dimensions
- Primary silhouette and dominant colors.
- Downward ablation, crude material recovery, pollution and waste heat.
- Industrial detail: distinct materials, meaningful mechanical joints, cast bolts, surface roughness, wear and controlled speculars.
- Factorio viewing distance, canvas extent, grounding/shadows and readable lighting.
- Explicit pass/fail proof that the reconstruction reads as **the existing emergency miner** at the same display size. A successful Blender job is NOT visual fidelity approval.

## V05 — OWNER-AUTHORITATIVE LASER-ABLATION DESIGN

The emergency miner is **not a drill**. It is an armored, face-down, high-power **frequency-modulated laser ablator**. It can be placed on practically any material surface, ablates a thin layer into an impure atomic/proto-matter soup, recovers residue and **crudely reassembles a trickle of adulterated usable material**. It is **slow, intensely wasteful, polluting, impure and not scalable**. Design analogy: *the world's most abusive photocopier placed face-down in the dirt*. It is explicitly an emergency bootstrap device, not conventional resource extraction machinery.

**Known from sprite:** armored octagonal control box; prominent green controller display; four status indicators; upper sockets; three front power/interface connectors; red-green cabling; thick corrugated hoses; maintenance lids, vents, shoes and fasteners. Preserve these exactly as much as the modeling tool allows.

**Owner-defined operating principle, engineered hidden geometry:** underdeck phase controller, pulse capacitor bank, shielded bus, six downward-facing ceramic-isolated emitters, contact seal and ablation chamber, vacuum capture gallery, crude proto-matter reconstitution cassette, degraded scrap outlet, pollution exhaust and high thermal-loss coolant/radiator loop. Optical layout and internals are proposed details, not proven from the sprite; maintain separate collection `INFERRED_UNDERBODY_LASER_ABLATION_AND_RECLAIMER`. No digging teeth, augers, rotary boring or drills.

The model manifest lists six named paths connecting actual 3D objects: high-power supply, frequency modulation and diagnostics, downward photon delivery, proto-matter recovery/reconstitution, waste heat, and contaminant discharge. The Martian red access plate is a functional calibration service point. This implements [the canonical doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) without adding unnecessary ornaments or changing the original control lid.

CI builds an editable `.blend`, a geometry-based `.glb`, original-vs-3D comparisons and a true underside inspection render. Source sprite SHA must be exact. **Model build success does not imply visual acceptance.** No gameplay or prototype change, original graphic replacement, or third-party model redistribution is authorized.
