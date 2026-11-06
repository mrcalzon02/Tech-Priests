# Emergency miner — one-asset-at-a-time 3D reconstruction

## Authority and scope
First target: `tech-priests_src/graphics/entity/martian-micro/tech-priests-emergency-miner.png` (1254×1254 source image). The sprite and mod-owned icon are already committed to Tech Priests. We must reconstruct **this specific machine**, not another rocket engine, generic drill, or an unrelated concept object. This workstream makes **no gameplay/prototype changes** until actual visual acceptance. The current prototype behaves as an assembling-machine with dedicated emergency-mining recipes; do not change that merely to draw a drilling machine.

## Production checkpoints
1. Audit the source sprite and icon, measure alpha bounding box, registration and prominent geometry; retain hash and unmodified reference; identify recognizable landmarks by human source inspection.
2. Model only source-visible geometry from the intended Factorio camera: armored silhouette, feet, panels, sockets, ports, display, cables, and hoses; document but do not build hidden systems.
3. Build an editable exterior blockout from primitives. Do not construct unseen insides, underside machinery, emitter arrays, filters, or even physically plausible but invisible details.
4. Inspect render against the **same** image at fixed camera/lighting; correct big shapes and proportions before greebles.
5. Refine metal surfaces and manufactured detail. Use correct bevels, cast vs milled vs painted textures, rust, scratches, grease, recessed lines, metallic response and ambient occlusion. Detail must hold up at native game scale, not merely in a 4K beauty shot.
6. Produce matched source-versus-render contact sheets and candidate Blender `.blend` source plus `.glb` mechanical export, 3D orbit renders, material manifests and reproducible hashes. Save/reopen all files. Original render remains the rollback asset.
7. Only after visual acceptance, make fixed-camera transparent high-resolution game frames; preserve registration, silhouette and prototype art scale; validate in game before replacing source art.

## Review dimensions
- Primary silhouette and dominant colors.
- Visual communication of the high-power ablation box through exposed controls, vents, cables and its protective armored shell.
- Industrial detail: distinct materials, meaningful mechanical joints, cast bolts, surface roughness, wear and controlled speculars.
- Factorio viewing distance, canvas extent, grounding/shadows and readable lighting.
- Explicit pass/fail proof that the reconstruction reads as **the existing emergency miner** at the same display size. A successful Blender job is NOT visual fidelity approval.

## V06 — Render-visibility-first modeling policy (2026-11-05)

**Authoritative operating principle:** This box is a face-down high-power, frequency-modulated laser ablator. It attacks whatever surface lies underneath, generating a contaminated proto-matter soup, then crudely and slowly reconstitutes tiny amounts of adulterated usable scrap. It is inefficient, polluting and absolutely not an industrial-scale extractor: the world's most abusive photocopier placed face down in the dirt.

**Hard constraint: do not model anything not visible in the eventual Factorio render.** The internal laser grid, power converters, matter handling, filtration, offgas recovery and any invented underbody are technical concepts **only**, not meshes. The V05 inferred underbody and inspection angle are removed. No excavating teeth, drilling head, or spinning auger.

**Only geometry retained:** canonically observed chamfered shell, lower shoes/feet, upper cast control plates, vents, fasteners, cable fittings, display, lamps, triple power sockets, color-coded front connectors, top red and green cables, peripheral hydraulic/cooling hoses and grounded wear. The source-visible model still contains real bevels and 3D depth for those exposed elements.

**Evidence:** produce two target viewing angles (source-aligned overhead and proposed game camera) plus a closer view of the same exterior. No underside view. The model manifest must prove zero hidden internal component objects and `GAME_CAMERA_VISIBLE_ONLY`. In-game visual fidelity, not arbitrary mesh count, is the acceptance gate.

The authoritative [construction doctrine](../../../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) governs visible engineering detail and has the same visibility-first rule. No gameplay/recipe/prototype or original sprite replacement is in scope.

## V07 — three-level silhouette and physically terminated wiring

The original image is an inconsistent-perspective oblique reference, NOT a purely top-down flat panel. The project owner specifies a large-office-photocopier-sized armored machine seen from roughly 45° azimuth and 25° elevation, with its front face exposed.

The modeled manufacturing hierarchy is **(1)** the broad continuous foundation plate, **(2)** a vertically raised central armored machine chassis with exposed front, **(3)** the elevated upper console deck containing visible LCD, buttons, knife switches, three substantial pulse capacitors, ports, and secured wiring. Every layer must be visibly readable in a shallow 3D camera render, not fabricated with 2D strips.

The three colored front circles are the **tips of knife switches**, not cable ports. Each should visibly have its hinge, conductive blade, fixed electrical contact, and bolted bed. The three top tubes are **large pulse capacitors** with metal casing and insulated terminal collars, not recesses.

Wiring must not terminate in the air. Exposed rear/red, rear/green, rear/copper, side power, side control, and two perimeter hydraulic paths have explicit physical end fittings; the Blender build checks both curve endpoints against fitting centers. Rear wires should drop under/behind the raised upper deck rather than sit at an impossible uniform height. Exposed hoses are mounted to chassis shoulders and end in sealed connectors. Hidden internals remain absent.

Render preview requirement: every completed modeling run needs an **inline review image** in the chat. Use actual Blender render and matched sprite comparison plus one oblique/detail view; native 43px swatches remain important. Automation can preserve those images, but an archive link is not visual delivery. The game art remains unchanged pending the owner's review.

## V08 — protect the characteristic exposed perimeter hoses

V07 successfully introduced the three layers and electrical hardware, but its upper control slab was too wide, hiding the corrugated hydraulic hoses seen prominently around the original housing. V08 narrows only the structural upper plate to approximately the controller face's width, preserves raised front fascia, and moves both corrugated hoses into exposed outer chassis channels. The hoses retain checked physical glands and bolted retainers. The design remains original-sprite-led and intentionally leaves hidden laser hardware unmodeled. As always, the owner needs real, inline rendered proof from V08 before visual acceptance.

## V09 — source-matched casting contours, fewer generic boxes

V08's layered construction was recognizable but its broad rectangular front strips and duplicated plates looked like generic stamped boxes. V09 replaces the bulky front armor strips, four corner protrusions, and flat stacked upper cover plates with **custom irregular, beveled cast mesh silhouettes** following the actual reference. The LCD/button module and the knife-switch power module have distinct shaped faces. Core behavior, cabling/hose end fittings, the three capacitor housings and the three-height construction remain intact. Material undertones are darkened slightly to approach the original worn foundry metal. No hidden mechanical details are modeled.

Compare the true Blender V09 renders beside the original and at 43-pixel game scale. Geometry construction passes are diagnostic only; final visual acceptance remains with the project owner.

## V10 — source markup governs actual construction layers

The user-marked source explicitly shows the uncolored perimeter as the FOUNDATION PLATE, blue as the MIDDLE CHASSIS upper lip AND front face, and red as the entire RAISED UPPER MACHINE carrying the power hardware, screens, switches and cabling. The machine is an armored face-down laser ablator, not an excavator.

The lower portion of the red upper machinery is one connected **gently sloped forward-facing control bank**. The LCD, diagnostic buttons and three knife switches share an 11-degree tilted keyboard-like face, rather than sitting on a top-down plane or vertical box front. The three round upper components are the forward ends of **horizontal pulse capacitors** entering rearward into the top machinery; their axis is not vertical. Both substantial perimeter ribbed hoses now finish in lateral glands through the sides of the raised top machinery, not down through the blue chassis. Their endpoints remain physically verified. The foundation is unchanged, the blue chassis remains separate, and no hidden internals are added. Use the marked image as the authority over inconsistent AI perspective.

The V10 model is experimental until visually compared to the markup and original. Include real Blender source-vs-render and 43-pixel views in the conversation for approval.

## V11 — owner sprite-fidelity correction

The blue middle chassis was visibly too tall. Its physical vertical height is compressed from 0.310 to 0.186 Blender units while retaining the unchanged foundation level and translating all upper machinery down by 0.124 units. This uses one continuous, world-space geometry mapping for actual mesh surfaces and bezier cable curves, avoiding disconnection or oval distortion of the horizontally oriented capacitors. Four actual foundation corner bolt assemblies and four bolts on the blue chassis front face are added to match the original mounting language.

The three capacitor **round front ends** are now the dominant shape; exposed sidewalls were shortened and their longitudinal cradle lowered onto the upper machine. The wiring runs just above the physical upper red plate and ends in mounted glands rather than hovering high above the machine. Both large coolant tubes sit along the edge of the red top assembly and enter it laterally. A separate world-space endpoint test is performed before the coherent height reduction, and an explicit physical chassis-height test is required before rendering. No hidden interior machinery, replacement game sprite, or gameplay changes. Show actual source-vs-render plus 43-pixel inspection imagery in chat.

## V12 — minimal front-end depth correction

Per the owner's latest visual feedback, V12 moves the visible **front end** of the armor/chassis back toward the machine by a maximum of **20 pixels in 680-pixel source coordinates**. It is a gentle Y-taper beginning at source y=390 and reaching full setback at y=570, not a new box, another component, or a change of camera. The entire perimeter foundation and its four corner bolts are unchanged. The red upper controls stay in their sprite-registered positions; the lower front-facing machine enclosure and matching fastening details recede together. Only camera-visible surfaces, wire curves, and their existing fittings are transformed. All V11 layer heights, the 11-degree control-panel slope, capacitors, cables, and part semantics remain unchanged. Approval depends on actual V11-vs-V12 source-aligned and game-scale Blender renders, shown directly in chat.
