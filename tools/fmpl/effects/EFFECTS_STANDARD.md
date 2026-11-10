# FMPL Effects and Materials Standard v1.0

This **additive** library extends the existing 23 image-backed PBR presets; it never renames, overwrites or silently promotes the existing bunker/boiler/condenser materials. It provides **28 named original procedural effect materials** and **five reusable animated demonstration rig collections**. Materials, rig geometry, preview frames, the saved native Blender library, a verified reopened library, a user-approved visual design, and a Factorio in-game sprite are distinct acceptance states.

## Source and scope

Derived from the user's 13-page `To create effects in blender.pdf` (SHA-256 `b256e188919ace7804ff958cbf2eee052cc47519529a70e61da7d2270c93d27d`). The guide describes Wave/Ocean/Displace/Geometry Nodes, procedural texture and roughness systems, steam and smoke, liquid viscosity, blackbody heated metal, lava crust, cracked mud, and high-risk simulation caches. It is **design guidance**, not an engine/API verification report. Reference the current Blender 5.2 manual for actual Principled BSDF socket names; scripted material creation checks each required socket.

## Material and effect families

| Family | Reusable presets | Rendering behavior |
|---|---|---|
| Water and oil | clear/murky water, crude/lubricating/refined oil | transmissive PBR approximations, wave animation separately |
| Thermal liquids | molten lava and cooling crust | Voronoi channel/mask, bounded emission; NOT a fluid solve |
| Chemicals | green acid, blue coolant, slurry and fumes | liquid surface versus gas/volume kept distinct |
| Glass | clear, frosted, amber and green laboratory | transmission + IOR, roughness controls; no opaque fake glass |
| Steam/smoke | clean steam, exhaust steam, soot smoke, chemical gas | lightweight volume proxies; full gas sim opt-in |
| Fire/plasma | fire core, outer flame, blue plasma | keyed material/geometry proxies, no unbounded drivers |
| Metals | red/orange hot, tempered blue, cracked and oxidized steel | metal shading with optional blackbody heat and fracture masks |
| Ground | cracked mud, compacted snow | surface damage and roughness; fracture/snow physics separate |

## Mandatory construction conventions

1. Always connect explicit **Object/UV -> Mapping -> procedural noise**. A named master Scale controller sets texture frequency. Do not use drifting unanchored world-space texture coordinates or unbounded linear frequency drivers.
2. Model PBR metallic/dielectric and transmissions intentionally. Metallic = 0 for clean dielectrics, 1 for exposed metal; mixed coverings and rust may appropriately use masks/intermediate effective values. Water IOR ~1.333 and ordinary glass ~1.46–1.5 are baseline approximations. A single planar transparent shader is not a fluid volume.
3. Keep contrast, tint and roughness physically plausible. Use gently broken roughness, limited bump distance and softened ramp thresholds; bake normal/displacement only when justified at native game-pixel scale. False-color emissive effects can exceed physically reflected color values.
4. Animated FX rigs use **16 authored cyclic samples at 8 fps**, with an exact key at frame 97 equal to frame 1. No time-growing infinite drivers, runaway scales, unrelated camera motion or arbitrary randomization; seed procedural identity per object.
5. Preview galleries use one 45°/0° orthographic camera, not icon cameras. **Do not confuse gallery images with game-correct sprite placement.** Entity sprites use a stationary canonical camera; rotate the *model* only when its native prototype genuinely supports rotation.
6. Real effect emitters must be physically attached to an actual nozzle/chamber/hot face. Emitters, light intensity, opacity and motion are measurable separate channels. Never pass duplicated screenshots or decorative transparent overlays as production animation.
7. No automatic Mantaflow/Ocean/FLIP/VDB bakes in material-gallery jobs. Advanced simulations require a separately approved budget, disk-space preflight, full-thickness manifold colliders, applied scales, explicit bake boundaries and D:-drive scratch cache. Source pages state 4-8 substeps or exact vorticity values, but those are **starting heuristics**, not universal requirements across every Blender solver/version.
8. A valid build requires source checksum; 28 uniquely named material assets; five reusable collections; one native .blend; >0 real sampled animation frames; exact camera/preset controls; and fresh independent Blender reopen. Every source revision produces a new output directory; never overwrite accepted originals.
9. All assets remain candidate library elements until the user sees **actual Blender** visual proof. Rendering does not imply approval, native Factorio attachment, fluidbox alignment or functioning materials in-game.

## Production API

- `presets.json`: deterministic independent parameter registry
- `build_library.py`: Blender 4.3+/5.2 procedural node construction and native save; source + gallery and actual effect-keyed rig collections
- `verify_library.py`: separate Blender process reopens and checks material IDs, live camera, keys, native scene and proof-image hashes
- `test_presets.py`: standard-library-only schema and source contract sanity
- `library_report.json`: Blender/build identity, source hash and frame digests
- `FMPL_effects_materials_v1.blend`: actual editable library output, generated only on a runner, not fabricated from source code
- `proof_*.png`: real Blender-only thumbnails (not approved game sprites)

## Worker execution

Only the existing **Dens Mortis private Windows runner controller** is permitted to perform the full build; do not create another GitHub workflow or enable a recurring schedule. Run the new `fmpl-effects` mode through its authorized request file, pin the complete Tech-Priests commit, check free D: scratch space and archive genuine native outputs, logs, hashes and images. Heavy per-machine rendering never starts merely because a library file changes.

The library is for future Fish Pond water, steam condensers, boilers, compressors, plasma machinery and other project models. Import by exact ID from the native library via `bpy.data.libraries.load(..., link=False)`; do not duplicate raw shader definitions in each machine builder.
