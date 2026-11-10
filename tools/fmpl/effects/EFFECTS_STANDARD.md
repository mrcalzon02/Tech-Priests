# FMPL Effects and Materials Standard v1.0.3

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

## v1.0.1 visual-readability revision

The first full Dens Mortis run (42743646586, Blender 5.2.3 LTS) genuinely built and reopened all 28 assets and five rigs and produced 16 frame screenshots. Its actual gas-volume previews were too faint to read at the preview camera. The subsequent revision deliberately increases preset small-volume density values and improves Blender-native gallery-label facing/lighting, without enabling any physical simulation bake. This is a visual legibility correction, not a claim that the presets are already physically calibrated for every scene scale. Existing 1.0.0 native output and SHA receipts remain preserved in the original runner artifact.

## v1.0.2 bounded-lobe correction

The second Blender 5.2.3 production run #42745250083 passed all native reopening tests, but direct proof inspection revealed that the animated plume logic reset tiny gas-sphere scales to 1.0, creating huge visual occlusion. V1.0.2 captures and restores original axis scales during every animation phase, and verifies gas lobes remain <=0.40 units in X/Y. This is a real animation-geometry repair, separate from the v1.0.1 gas-density improvement. Verification still requires actual new runner renders and user visual acceptance.

## v1.0.3 — geometry and chemical-opacity correction

Blender V1.0.2 failed the native spatial-scale gate at [Dens Mortis run 42746275215](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42746275215). Scene parenting had reinterpreted the initial world-space transforms, creating unit-sized gas spheres. V1.0.3 parents new emitter meshes with explicit local offsets and restores the authored scale, fixes local-space ring vertices and validates the gas envelope at initial, middle and final frames. A test failure is a real defect, not evidence to weaken QA.

Chemical acid, blue coolant and slurry are intentionally less transmissive for clearer color at 64px. Gas effect density remains separate. This does not affect ordinary transparent water and glass; no physical-fluid solver is invoked. User approval and game sprite integration remain independent.

## Steam plume silhouettes — no visible cone edges (Water Purifier V6)

The historic two `service steam plume` meshes are literal UV cones whose
surface boundary was plainly readable in the actual 512px Water Purifier
camera. **A cone-shaped steam shader is not a pass, even if animated.**

The accepted construction direction for compact pipe relief steam is a **small
nozzle-anchored, twelve-lobe physical mesh assembly** with four principal
animated steam wisps and eight intersecting thinner veil shells. Use native
Blender noise to perturb both the generated-coordinate radial-volume-density
falloff and the almost-transparent surface feather, so the *interior* is
soft scattering vapor instead of a hollow translucent shell. The layer surface
opacity must remain below 0.05 at the core; 3D volume density falls smoothly
to zero *before* each mesh silhouette. No billboard planes,
cone caps, sudden opacity thresholds, hard white borders, or fake texture cards.
The layered mesh shader may enable Blender dithered material evaluation; its
actual Cycles renderer output is the authority. This is cheap geometry, not a
simulation cache.

Keep the exact original cone source meshes and keyframes in the editable native
Blender derivative but set `hide_render=True` for those two objects, *and*
exclude them from production GLB/sprites. Do not rewrite or delete the
verified process source. Four primary and eight secondary feather lobes must
key their transform in the same 16-sample/97 closed loop, originate at the real
Water Purifier exhaust nozzle, remain within the 3x3 footprint, and have
independently verified saved material nodes, edge feather, animation seam,
source mesh digests, and rendered cone suppression.

Review images must be **real Blender renders of the complete machine** at idle
and active frames, plus a close-up crop for subtle steam edges. If edges still
show as faceted cones, the pass fails visual review even if other numeric checks
pass. Prefer small sharply feathered exhaust over enlarging bright white cones.

### Visible nozzle-to-vapor mating (Water Purifier follow-up)

A steam plume needs a **visible mechanical origin**. The Water Purifier's original
`FMPL_PROCESS | vent nozzle anchored through pressure pipe` is a solid cylinder
at Blender `(0.94, 0.60, 2.80)`: it cannot serve as a convincing open emitter
on its own. Preserve the historical object's vertices/keyframes but hide its
render and fit a real hollow steel throat centered at `(0.94, 0.60)`,
from `Z2.760` through `Z2.913` with a measured `0.15576`-tile bore.
Physically seat the base on the unchanged pressure-relief pipe and add a
restrained machined retaining lip at the mouth. Begin the overlapping, true
3D feathered vapor lobes **inside/just above that open bore**, not as a
floating cloud or a disk of opaque white mesh. Render both the lip and vapor
at the one canonical Factorio camera; verify source preservation, cap
suppression, actual mesh topology, vent-to-plume proximity, and independent
GLB readback. The exact fluidbox mapping remains a separate native gate.
