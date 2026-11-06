# Emergency Miner — source-locked 3D feature register

**Status:** V16 is frozen for audit. This is a **planning and reconstruction specification**, not authorization to change the game sprite or produce extra ornamentation. Authoritative references: `source_reference.jpg` (680×680 source capture in the asset artifact), the owner's three-color layer annotation (`lasyering.png`, conversation reference), and the original sprite hash checked by `build_model.py`. The owner has expressly corrected the three-layer assembly, cable orientation, and manual-switch interpretation. **If a detail cannot be traced to one of these, do not model it.**

**Failure diagnosis:** V06–V16 often translated a 2D edge into a new 3D plate, introduced plausible but unsourced glands/bolts, and connected wires to arbitrary adjacent parts to satisfy endpoint tests. Geometry count, closed meshes, GLB export and green Actions are not visual-fidelity measures. The working object must be an authentic *3D machine whose camera projection explains the visible 2D sprite*, not a collection of independent 2D outlines extruded in Z.

## 1. Evidence levels and non-invention rule

- **OBSERVED:** the sprite visibly contains it. Model its count, location, proportion, silhouette, color and occlusion before proposing elaboration.
- **OWNER-CONFIRMED:** structural/functional reading explicitly supplied in conversation. Use this when the AI-painted sprite has inconsistent perspective.
- **OCCLUDED / UNKNOWN:** the image hides the continuation or mount. The visible geometry must terminate **under/into the actual housing** at the occlusion boundary, not in an invented ornament, open socket, random power capacitor, or decorative connector. Never invent hidden internal geometry merely for explanatory completeness.
- **INFERRED:** only minimal supporting volume required to make visible pieces mechanically contiguous in 3D. Identify inference in the model and don't count it as sprite fidelity.
- **FORBIDDEN:** unsourced switches, buttons, ring connectors, electrical endpoints, random fasteners, extra faceplates, thick fake fascia bars, floating wires, orphaned details and unseen laser-ablation equipment.

Each model-visible object must have a row with: **object name; evidence level; source bbox or anchor in 680px sprite coordinates; count; expected support surface; actual 3D connection; render views showing it**. A model object with no evidence or mechanical support goes into the *remove/justify* queue—not directly into the final render.

## 2. Source-coordinate register (approximate, not pixel-perfect reconstruction measurements)

Coordinates refer to the 680×680 uncolored original; the owner's 421×398 annotated image establishes **which physical tier each region belongs to**.

| Source zone | Observed geometry and approximate sprite footprint | Binding constraints |
|---|---|---|
| OUTER FOUNDATION, x≈18–662, y≈20–644 | Thick irregular chamfered perimeter frame, corner foundations/feet, bolted metallic corners and low horizontal front detailing | **ONE** foundation casting with appropriate stepped corner geometry. Do not add a broad blank rectangle outside it. Use only bolts supported by visible screw-head locations. |
| CENTRAL CHASSIS, x≈56–629, front y≈423–552 | Exposed upper lip and relatively compact armored front beneath upper machinery; dark cast/forged transitions; shallow face, a horizontal front line and sparse end/front fasteners | **ONE** connected chassis solid with correctly placed upper shoulder and real face. Do not extrude the horizontal lines into separate projecting full-width slabs. |
| UPPER MACHINE, x≈106–591, y≈92–446 | Main machinery/control assembly, including left rail, upper vent covers, socket bay and the gently forward-sloping operator console | **ONE coherent raised housing** with mounted accessories. No arbitrary added elevations or separate plates where the image shows a continuous casting. |
| LEFT VERTICAL RAIL, x≈109–166, y≈103–399 | Long dark/metal rail and **two large brass/gold fastener heads** near (138,130) and (139,325) | Only the two visually supported primary bosses; don't pepper surrounding steel with decorative bolts. |
| VENT & MAINTENANCE COVERS, x≈170–420, y≈98–300 | Three dark horizontal ventilation openings at y≈153/175/195, two broad rectangular upper/mid covers divided by visible seam; small heads on corners | Exactly three vents; make actual apertures/cavities. Case seam is a join, not a third high-standing slab. Fasteners only at observed positions. |
| THREE TOP CIRCULAR COMPONENT ENDS, x≈439–569, y≈123–226 | Three dark round recessed mouths at ~x459/503/548, y≈168; restrained worn-steel collars, short dark cylindrical walls | **Exactly three**, equal-size, uniformly spaced. Owner says they are large capacitors **resting horizontally on the upper surface** and showing their round ends toward the viewer. Do not model vertical towers, glaring oversized gold annuli, free-hanging rings, or visible invented wiring into the mouths. Physical body axis/mount must be validated from a distinct 3D camera. |
| LCD / LAMP BAY, x≈171–392, y≈303–444 | One rectangular green LCD around x≈183–305,y≈312–408 and a **2×2 cluster of four** small red/yellow/green/dark indicators ~x329/362,y≈340/383 | Exactly one display and four indicators. No extra buttons near the display; recess/bezels match the sprite shape and sidewall/shadow depth. |
| MANUAL SWITCH BAY, x≈393–583, y≈303–445 | **Four vertical switch channels**, with red, dark/black, amber/yellow and green circular handle ends across the face | Owner-confirmed knife-switch handles. Preserve four *readable channels*, not 3 invented levers plus a disconnected floating toggle or extra knobs. No added switch mounting boxes unless visible or necessary as flush support. |
| UPPER REAR STRAPPED CABLES, x≈164–565, y≈40–125 | Red, green and warm-colored conductors run along/through approximately the upper straps and then curve toward the RIGHT side | Build a **small number of surface-seated curves** precisely following those routes. Straps are mostly rectangular clamps in the source, not a row of prominent circular gold glands. At hidden endpoints, run cable under an existing cover; do **not** terminate red and green on nearby capacitor mouths without source evidence. |
| OUTER BLACK CORRUGATED HOSES, x≈50–115 (left) and x≈567–646 (right), y≈57–433 | Two large, dark ribbed hoses bend smoothly around the top corners and descend along the outside edges of the red upper assembly; lower right shows a red conductor emerging | Preserve two distinct U/side-route conduit silhouettes, proper corrugation and attachment. Large bends are part of the hoses, not isolated ring ornaments. Lateral entries into the **red upper tier**, never arbitrary connections to blue chassis or unrelated upper components. |
| FRONT CASTING/ANCHORS, x≈35–646, y≈424–643 | Two sculpted lower corner structures, broad shallow front plate with material breaks, visible bolts in specific groups | Recover the original-shaped corner/bolt pattern (not oversized plain pads or a new frontal shelf). Source shows sparse front-face bolts near (179,513) and (497,513); other recognizable heads are at shoulder/corner mounts. Each extra V16 bolt must be checked against the original. |

**Source uncertainty:** a 2D/AI-painted source cannot uniquely determine exact internal depth, hidden endpoints or every bevel. User-confirmed topology controls those choices. Do not substitute arbitrary guessed internals.

## 3. V16 mismatch and action register — inspect before making changes

| Current V16 component/behavior | Source-grounded issue | Next action |
|---|---|---|
| `Rear red HV input gland`, `Rear green logic input gland`, `Capacitor red terminal gland`, `Capacitor green terminal gland`, `Rear copper service gland`, and additional gold terminal rings | Several visible gold circular fittings in V16 have no corresponding source feature; wires end in exposed circular fittings near unrelated components | **Remove the unsourced visible rings.** Route conductors under the existing rectangular cable clamps and housing edges, using minimally visible pass-throughs only where the source shows them. Record occluded ends rather than inventing devices. |
| Three `Capacitor * upright metal shell` columns | Source/camera makes end circles visible, but the owner explicitly describes the bodies as **lying horizontally on the machinery surface**; the current upright posts are the wrong physical interpretation | Rebuild as three supported short horizontal cans with their **round front/end faces** oriented toward the source camera; check a side view to prove their actual axis and contact. Camera perspective may need calibrating rather than making them vertical. |
| Repeated `Knife switch * bolted insulated bed` and separately boxed `Central raised selector housing` | Visually turns one coherent four-channel bay into multiple manufactured pedestals; the black channel may appear disconnected | Redesign one four-position switch bank on the sloped face; count and position exactly four source channels. Any bed must be flush/necessary, not an extra protruding plate. |
| `Upper controller shared sloped mount`, two full faceplates and `Controller leading machined armor lip` | V16 still resembles a broad smoothly extruded step instead of the original thin, sharply defined upper/control assembly | Reassess which surfaces are actually **one sloped operator plane** and which are separate visible castings. Remove overlapping false elevations; model physical plane + real seam or recess rather than outline-stacked layers. |
| Foundation corner gussets, uncolored plain pads, front-face bolt row | Oversized blank front corner pads and several small bright bolts do not appear in the original in those forms/locations | Rebuild corner shapes from observed outlines, shrink/recess where necessary; eliminate extra bright front screws and relocate only source-supported anchors. |
| Large smooth charcoal middle chassis face | Wrong finish, poorly differentiated front details and inaccurate relation to top red assembly | Solve actual front wall geometry and distinctive armoring **before** any rust/scratch overlays or extra inserts. |
| Green screen noise and randomized material scars | Individually plausible, but random micro-detail is not a substitute for matching large landmarks | Freeze until large geometry, orientation, parts count and material regions match. Use the source as texture reference rather than filling blank regions with random objects. |
| 3D render camera | The source image is not a reliable orthographic diagram; previous turns used conflicting camera assumptions | Hold model fixed while testing source-camera candidates (including owner's approximate 45°/25° initial impression and steep near-symmetric view). Select by landmark agreement, not prettiness. Maintain an independent 3D view to prove depth and connections. |

## 4. Reconstruction order and objective exit conditions

1. **Freeze V16 and build a landmark/contact sheet**: unchanged source; owner's colored tier segmentation; V16 from same projected frame; six close crops covering upper cable/hoses, top three mouths, vent panels, LCD/lights, four switch channels and foundation/front.
2. **Remove or hide unsupported visual additions** in a temporary review candidate (not the live Factorio sprite). Maintain a deletion ledger keyed to Blender object names. Do not add compensatory details.
3. **Fit the three connected structural solids and one inclined control face**, with actual support, proper front silhouette and corners. Check multiple camera elevations and sidewall geometry. Keep blank areas blank if source shows blank metal.
4. **Rebuild exact recognized component counts**: three vents; three mounted capacitor mouths; one LCD; four indicators; four switch channels; two large outer corrugated hoses; visible front anchor patterns. Compare both top/reference and real oblique views.
5. **Trace wires one at a time.** A route can only be declared attached if it meets an *observed* fitting/cover/retaining strap or legitimately disappears underneath a physically modeled casing. Never treat an arbitrary nearest-neighbor object as an endpoint.
6. **Reconcile fasteners and cover seams**, using image locations and types. Remove duplicates; no uniform bolt spread. Only then do restrained normal maps and source-matched oxide/metal wear.
7. **Render proof in chat for every pass**: (a) original sprite alongside candidate using a matched projection, (b) real 3D inspection view, and (c) native ~43 px crop. Link to GitHub is supplemental, never a substitute.
8. **Do not promote on a green build**. Structural, landmark, count, attachment and game-scale checks are separate from compiler/mesh/GLB tests. The owner must accept the appearance before replacing the game's sprite.

### Hard evidence gates

- Each newly visible object needs a source-coordinate anchor and identifiable function. No source evidence or explicitly owner-confirmed requirement → **no new visible geometry**.
- Absolute counts: three vent slots, three round capacitor ends, one LCD, four adjacent status indicators, four switch lanes, two big perimeter hoses; no extra invented knobs.
- All external cables are **seated** on real support surfaces along their visible run, with source-justified endings; no hovering and no decorative clamps.
- The base, compact chassis and upper machine have continuous real depth; no false full-width strips to explain a 2D painted line.
- Report the **deleted**, **repositioned**, and **unchanged** object-name sets for each future model revision. A pass without a before/after visual comparison is incomplete.
- No gameplay/prototype changes, source replacement, new laser internals, or unrelated asset development as part of this fidelity pass.

**Review reminder:** This document intentionally makes **no V17 model edits**. It establishes the source-grounded constraints required before the next geometry revision.

## 5. V17 model correction candidate — implementation trace

This revision is limited to the existing source evidence. It must not be considered automatically visually approved.

| Evidence group | V17 actual Blender choice | Model evidence |
|---|---|---|
| 4 switch lanes at x≈430, 466, 505, 550, y≈345–417 | Three colored end rings and ONE dark lever, each in a shallow channel, no added individual bed plates | `Knife switch {0..3} source recessed channel` |
| 3 cylindrical mouths at x≈459, 503, 547, y≈168–190 | Short horizontal cylinders; front dark recessed ends, restrained rims, no upright towers | `Capacitor {0..2} horizontal supported shell` |
| Rear conductors under bands | Red, green, warm-colored curves with source-located occlusion endpoints, four non-circular rectangular straps | `Original rear rectangular retaining clamp {0..3}` |
| Right-side red conductor | Continuous external red segment, ends hidden at original sleeve and upper casing | `Right visible red high voltage feed` |
| 2 major black side hoses | Two real curved tubes, each with ONE visible metal sleeve and no invented side rings | `L/R actual perimeter ribbed hydraulic conduit` |
| Large bolts on outer/base mounting positions | 6 source-anchored heads (≈75,69; 605,69; 126,455; 550,454; 116,569; 560,568) | `Foundation source anchor bolt {0..5}` |
| Sparse smaller bolts on main chassis front | 2 small heads near (180,512) and (497,512), no even row | `Middle front source screw {0..1}` |

The model must retain editability and true physical depth. Although endpoints require no invented visible fittings, Blender EMPTY objects are acceptable as nonrendering assembly/occlusion constraints and must not be mistaken for unseen physical machinery. Re-check the eventual render: a claim that the presence of six cables proves they are visually seated is NOT sufficient. Correct actual occlusions when necessary.

## V18–V20 evidence after actual side-by-side renders (2026-11-06)

**Never confuse a technically passing Blender build with a matched sprite.** The verified source/V18/V20 rendered comparison (V20 Actions run 42314537463, corresponding model `tech_priests_emergency_miner_v20.blend`) shows that the original lower machine still looks substantially different.

- **V18:** correctly deletes 2 invented blank corner pads, 1 false full-width control lip and pseudo-random physical scar geometry. The exposed base is nevertheless still a generic empty rectangle, NOT the original foundation.
- **V19:** attempts to replace these pads with 2 original source-motivated corner supports but makes them into undersized, bright, isolated octagonal pads. **Visual candidate REJECTED**.
- **V20:** physically extends those two original source-supported structures to meet the chassis shoulder and darkens them. This remedies the disconnected pads, but the result is now **two huge smooth tapering buttresses**, equally unfaithful to the original's intricately stepped and recessed armored feet. **V20 is not approved**.
- Source left foot: roughly x≈50–160, y≈426–640, with main visible bolt near (112,456), a shaped lower projection, another large fastener near (109,556), and a physically recessed rectangular front face. Right foot mirrors this nonidentical surface language near x≈521–644. V20 loses the separate recessed front and buries or misplaces the lower bolt.
- Source center front: a dark, shallow armored middle-chassis face with exactly two small visible heads, and distinct joined, beveled foundation structure below. V20 still renders uniform wide bands and a featureless black inset rather than these observed features. Do not remedy by attaching another full-width slab.
- Source top upper-right triple ends: three deep, black circular mouths facing the view, not three long silver drums. The existing V20 cylinders remain the wrong read; correct their genuine 3D orientation and end geometry before adding any decoration.
- Source front controls are **one flush, sloped keyboard-like panel**, with closely grouped LCD and switch hardware, not a generic tall box. The current model still projects too much of the supporting upper block.
- **Hard next-pass rule:** No additional parts beyond the documented original source geometry. Fix the actual connected existing mesh's recesses, bevel cross sections, face placements and material zoning; verify from the source-matched camera AND distinct actual side view; show both real Blender renders in the chat.

These are observations, not permission to add arbitrary hardware or change any in-game sprite. The original source remains the only appearance authority; all candidate meshes remain subject to owner's approval.
