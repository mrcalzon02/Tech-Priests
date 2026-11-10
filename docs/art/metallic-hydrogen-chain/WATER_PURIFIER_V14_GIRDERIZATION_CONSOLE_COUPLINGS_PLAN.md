# Water Purifier V14 — console enclosure, upper-drive support, couplings, Girderization pilot

**Stage: planned, design-only; not yet built or dispatched.** This is an executable work order for one consolidated V14 production iteration, not a request to create more GitHub workflows. The separate proposed FMPL Girderization design is at `tools/fmpl/girderization/GIRDERIZATION_STANDARD.md`. Do not begin indiscriminate structural changes before applying the source audit and keep-outs below.

## Source of truth and V13 handoff

- Last technically successful Water Purifier: Dens Mortis [run #42854827403](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42854827403), artifact `13781794050` (editable Blender and GLB, native proof PNGs, 8 working sprite frames, 6 atlases and independent QA).
- V13 **modeling-source pin**: Tech-Priests commit `a89de584fe85176d56dd6787c2886e2d7b3eb36c`, canonical FMPL manifest **0.4.2**; Dens Mortis dispatch `136ad981db6d89e4e3549deb968fd3819694261f`.
- Verified V13 contains all 50 original MH7 meshes and 136 V04 process meshes, plus 368 derivative meshes; 526 reimported GLB mesh objects. Two 0.49-tile pipe bores remain unobstructed across 74 physical ray samples. One canonical 45-degree fixed Factorio camera.
- V13 slow stirring rotor: 0.25× previous angular speed, 90-degree visually looping quarter-turn in 97 frames. Prior real Cycles effect-on/off visible-pixel contributions: central swirl **937**, central foam **499**, recirculating bubbles **718**, animated green CRT bars **198**. Front witness tank bubbling/foam, steam and pipes passed their separate original gates.
- **V13 passed technical tests but failed owner inspection of console containment.** Rendering a screen and buttons in the open is NOT acceptable merely because they clear a tank.

## S0 — exact preflight and annotated inventory (no geometry)

Perform the six non-destructive checks before model editing: (1) reconcile exact main HEADs and source SHA; (2) validate FMPL 0.4.2 contract; (3) confirm source 50+136 mesh hashes, animation actions and packed PBR; (4) enumerate protected 3x3 footprint, one fixed camera, two original ports and dynamic/transparent keep-outs; (5) independently reopen V13 and capture actual before source-camera renders and selected closeups; (6) inspect the existing Dens Mortis worker occupancy/output destination, without deleting runs or scheduling any new workflow.

Use the existing source functions in `tools/fmpl/production_smoke/central_agitation_console.py`, `refine_process.py`, `super_greeble.py`, `pipe_bore_clearance.py`, and `tools/fmpl/effects/fluid_steam_fx.py`. Build a machine-readable inventory of **every visible rigid pipe, flexible hose, pressure tap, sample line and electrical conduit endpoint** from the actual Blender scene, including its receiving mount and which end is already mechanically seated. The route sample list in S3 seeds the inventory; it is not an exemption for other actual visible endpoints.

## S1 — repair the front-right GREEN CRT as ONE embedded console assembly

**Root cause:** V13 `relocate_console()` applies a hidden `Matrix.Diagonal((.70,.74,1.,1.))` to `MH7_service interface casting` alone. The CRT and buttons retain full physical size. They therefore overhang the cropped housing at both ends even though the *entire console* clears the cyan glass tank.

The actual V13 exported GLB gives an initial world-X diagnostic: casting `0.791–1.340`, CRT `0.775–1.201`, rightmost buttons to `1.358` (values in tile units, approximate AABBs). This is an observable failure, not a subjective color issue.

Required construction:
1. **Delete the V13 shrink operation from the derivative constructor**, not the immutable MH7 source. Recreate the control casting at full source proportions and restore its full side walls, back, face frame, lid and contact feet. If the actual original source casting dimensions still cannot enclose every original control, construct a minimal matching *framed extension* with actual wall and supporting bracket; do not squeeze the display/buttons.
2. Transform housing, CRT bezel/screen, all four original buttons and five animated diagnostic bars by **one coherent rigid assembly transform** around a stable shared pivot. Retain a modest forward/outboard placement and approximately 10–15° face yaw (V13 was 12°), but solve the final translation **from actual 3D collision and view tests**, not predetermined guess coordinates. Avoid a nonuniform parent scale or independent rotation that unseats individual controls.
3. All original buttons must be seated through actual housing-face bosses/sockets; the CRT must be recessed in a framed window within the housing. Real five-bar green readout stays within CRT glass, not floating outside the screen. Assign a small consistent inset for the CRT and seated collars to the buttons; avoid clipping glass or bar motion.
4. Support the entire angled housing with a wedge foot/standoff or a pair of visibly attached bolted brackets landing into the chassis/console base. The support must be physically connected to the body and metal base, and must not intersect the cyan glass vessel or its witness plumbing.
5. Preserve the source `MH7_service inset CRT`, `MH7_service interface casting`, four `MH7_control push button*` meshes and their names/transforms as recoverable render-hidden objects. Five animated readout bars remain independently animated, with the V13 working cycle preserved.
6. **Approval geometry is in the local tilted panel plane, not a world-X bounding check alone.** Project the actual CRT bezel and button-collar vertices to the console's planar face coordinates; require a **minimum 0.025-tile usable frame margin on every side** (or document equivalent inset recess), screen/buttons fully within the housing silhouette, and physically seated contact along the face. Confirm a positive camera-visible gap to the enlarged cyan sample tank and no overall machine footprint violation. The combined V13 control content spans about 0.583 tile in X; plan for at least ~0.633 tile of actual useful face width plus physical walls after restoring the original enclosure. Check final transformed 2D bounds and true BVH intersections.
7. Render a closeup from the actual Factorio camera, plus one oblique diagnostic inspection view **that is not exported as a production sprite**. Green bars must visibly animate in at least two frames; screen and buttons must remain embedded and aligned through the complete 8-frame capture.

**Hard reject:** A tiny console centered inside the gap with controls spilling off both ends; a cropped/shortened housing; screen or buttons hovering beyond panel walls; a beautiful unrelated replacement unrelated to source.

## S2 — mechanical support chain on the TOP agitator drive

Physical verified source shapes:
- `FMPL_PROCESS | gearbox load-bearing overhead bridge`, location `(0, 0.1, 3.108)`, dimensions approx `(1.83,.22,.13)`.
- Two red `gearbox crossbeam pedestal ±0.84`, center `(±.84,.1,2.92)`, dimensions approx `(.135,.14,.37)`. Their lower ends at about Z2.735; they currently read as unsupported red nubs near/outside the metal glass-retaining bezel.
- `agitator motor gearbox housing` near `(0,.1,3.24)`, support casting `(0,.1,3.29)`, shaft and bearing below; transparent lid at Z~2.735 and metal rim/bezel around radius ~0.718.

Fix the **load path**, not merely the appearance:
- Keep the motor-bearing-transmission axis aligned with the slow stirrer (no accidental rotor animation change).
- Bridge bearing/motor mount must be seated on a real steel plate with bolt groups into the crossbar. The bridge reads as an actual channel or boxed/I-section girder, not a featureless floating slab.
- Each red pedestal lower end must connect via a steel lower shoe and correctly oriented gusset/diagonal standoff to **metal** retaining structure / reinforced vessel-side collar, then chassis/footing. Do **not** land its weight on the transparent observation glass. If the original metal rim cannot directly carry a shoe, make a small explicit reinforcing mount from its support ring or a side upright to the existing structural chassis; preserve sight lines through the lid.
- Use a visually compact and mechanically believable bracket/shoe/bolted flange arrangement, with paired fasteners at physical joints. Show the bearing-to-bridge and pedestal-to-metal-contact nodes; no isolated plates, loose studs or bolts into empty air.
- Report a directed connectivity graph: `motor housing → bearing saddle/mount → bridge → left/right gusset/pedestal → vessel metal seat/chassis upright → foundation`. Independent 3D contact distances should be ≤**0.015 tile** at intended metal-to-metal joints unless measured geometry requires a documented alternative.
- Keep support material out of transparent central water, moving stirrer swept volume, and existing overhead steam/pressure lines; no unseen internal gearbox parts.

## S3 — audit ALL line terminations and install the correct coupling family

A visible pipe simply terminating close to a surface is a defect. Every discovered external and internal **visible line endpoint** must carry an audit record: `line_name, A_xyz, B_xyz, diameter, axis, receiving_object, coupling_type, source_joint, output_joint, source_SHA, clearance, QA_status`. Record intentional route-node welds and branch junctions explicitly so they are not misclassified as disconnected ends. Goal: **zero unclassified endpoints**, not an arbitrary target bolt count.

**Initial prioritized audit targets from the code, not an exhaustive endpoint census:**

| Priority | Route, named source fixture | Mechanically appropriate fitting |
|---|---|---|
| Protect | West raw `(-1.5,0,.36)` / East clean `(+1.5,0,.36)` authentic pipe mouths | Keep unmodified 0.49-ID open-bore throat/0.68 collar/8 bolts; only inspect internal cast reducer and gland; do not add solid caps |
| P0 | `manifold to mounted intake pump` and `pump to first vertical filter` | Seated pump discharge boss, aligned flanged union/compression ring, visible pump casing mount |
| P0 | `first filter to second filter`; `second filter to central treatment inlet` | Gasketed threaded/bolted filter crowns, physically seated pressure tube ends; tank wall boss at inlet |
| P0 | `treatment outlet to clean discharge reducer` | Pump/manifold-compatible reducer union and lower outlet boss |
| P1 | `raw witness feed from pump`, `raw witness return to first filter`, both `raw-canister` sight-flow tubes | Small real pressure fittings/ferrules into larger amber sample canister, matching tube axis and tube wall |
| P1 | `clean witness feed from treatment outlet`, `clean witness return to discharge casting`, both `clean-canister` sight-flow tubes | Compression unions/ferrules into cyan sample canister, protective clamps on small glass lines |
| P1 | Two `filter * pressure impulse tube`, two `pressure gauge * hardline`, `pump metal pressure bleeder` | Needle-tube compression fittings, real gauge/bleeder bosses and valve glands |
| P1 | `return condensate pipe from working relief`, upper relief/steam nozzle assembly | Seated return elbow unions, condensate trap support, pressure/vent coupling (not a free torus) |
| P1 | `process sump gravity return`, drain/trench connection, radiator/heat-exchanger service piping | Seated drain bulkhead/compression union and visible mechanical support at both ends |
| P2 | `control panel motor power armored conduit`, `control junction terminal box`, associated motor/electrical terminations | **Electrical** cable glands and strain-relief sockets, not fake fluid flanges |
| Census | Remaining visible original MH7 and FMPL process tubes/hose routes not named above | Classify each end and provide the one physically appropriate fitting; record blockers instead of inventing a joint |

Rigid small tube: receiving threaded boss and compression gland/nut; hard fluid trunk: two-sided gasketed flange/union with visible barrel; flexible hose: spigot/barb or crimp fitting plus clamp and natural bend; electrical cable: panel-entry gland/grommet with strain relief. Attachment axes must be physically aligned (normally within 5° for a rigid union), endpoints genuinely seated (target gap ≤0.015 tile), and any hollow bore unobstructed. For hoses and lines, avoid stretching to arbitrary surfaces merely because they are closest. A decorative gold ring with no receiving socket is a failing connection.

## S4 — selective Girderization pilot, not a machine-wide texture spray

Use the reusable design in `tools/fmpl/girderization/GIRDERIZATION_STANDARD.md` **only at identified support roles**. Initial selection: the gearbox crossbar, two red support pedestals/lower foot plates, the console's full-length embedded panel surround and wedge mount, and a small number of obvious flat structural brackets/pump or radiator mounting plates that the source audit proves are underspecified. Optional structural inset recesses and section lips may enhance the main chassis but **never** obscure moving fluid, green screen, button caps or meter faces.

Choose an appropriate section (C-channel, box beam, folded flange, I-section) **based on actual load/joint role**. Fit a few meaningful gussets and physically seated bolts at joints. Keep overall machine recognizable, preserve approved FMPL metal/concrete textures and source mesh colors, and allow no unapproved generic donor kitbash. Do not model hidden backsides or mechanical internals invisible in Factorio's 45-degree camera.

## S5 — verification/visual evidence (blocking V14 asset acceptance, not unrelated releases)

- **V13 regressions preserved:** quarter-speed stirrer rotor (frame-1 `0`, frame-25 `π/8`, frame-97 `π/2`), central swirl + bubble + foam real render-isolation, and five bright animated CRT readout bars; front amber/cyan witness water bubbles and foam; soft nozzle-mounted steam.
- **Protected source:** original 50 MH7 and 136 V04 source meshes, their digests, source actions and packed PBR unmodified. GLB and source reopen independently. Derivative objects isolated by names and object roles.
- **Console:** all six source component duplicates plus five actual animated readout bars in one **full** control housing; equal rigid parent transform, embedded 2D panel-face containment with ≥0.025 tile border margin and full 3D support connection; no glass/readout overlap or switches beyond housing; compare actual closeups against the user-provided V13 crop.
- **Load path:** every defined motor bridge/pedestal/console support contact verified, no unanchored endpoints or dead-end nubs. Real metal support carries motor into chassis/metal rim, not glass.
- **Couplings:** 100% of inventoried endpoints classified; zero untreated open visible line ends; proper pipe/hoses/electrical fitting by class; actual endpoint + receiving socket contact. Audit exceptions require explicit naming/owner review.
- **Protected fluid ports:** both `0.49` ID, `0.68` collar authentic mouths unchanged, 74+ core ray probes with **zero** structural intersections. Keep the original 3x3 footprint, no hard solid pipe caps, no extra native fluidbox.
- **Image proof:** actual 512px Cycles full idle and active views, tight **before/after console** and **upper drive load path** crops, **coupling audit closeup mosaics** with labels for confirmed source-joint pairs, one real 256px production-frame check and an eight-frame GIF. The production camera is the one verified original; optional diagnostic orbit is NOT a replacement export camera.
- **Output:** native editable .blend + source SHA, GLB, packed FMPL PBR, one fixed-angle static + 8 actual working frames, 6 RGBA atlases 64/128/256, geometry and visual proof JSON. No output is marked owner-approved or game-integrated before external review.

## One consolidated runner execution after design review

Implement source-pinned editable Blender fixture functions and their independent tests in small committable steps, **then** dispatch ONE bounded `fmpl-super-greeble` request on the existing private Dens Mortis `OLD-CORE30-homebrew` Windows runner. Do not create extra workflow files/jobs/matrices, alter unrelated scheduled rail tasks, overwrite historical artifacts, or start another render while the single worker is occupied.

Recommended order in the worker:
1. Exact repository/manifest/source hash preflight; immutable V13 source readback.
2. Build CRT full-panel assembly and test embedded controls before any fine greebling.
3. Build motor-support load paths and high-priority pipe/cable fitting set.
4. Complete endpoint coverage audit and selective Girderization fixture placement.
5. Independently reopen Blender and GLB, run 3D contact/bore/console margin tests.
6. Run **cheap** genuine Cycles closeup/visibility probes first; correct failed geometry before generating full 8-frame sprite atlases.
7. Run complete V12/V13 regression and single-camera 64/128/256 sprite output; upload native files, proofs, hashes, run ID and exact commit.

### Work acceptance boundary

The user asked to **plan Girderization deeply before applying it here**. This work order therefore authorizes **planning and source inspection only**, not a V14 Blender modification, workflow dispatch or claimed completion. The next modeling execution begins from this document after the user has seen the specific construction rules. Visual approval and Factorio native 2.1 fluidbox/runtime integration remain undone regardless of Blender pass outcome.
