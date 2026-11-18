# Fusion drive design authority

Owner corrections from this continuation, 2026-11-17, apply to **both** the long
1×9 and short/wide 4×4 fusion drive:

> These drives are made by essentially cramming electrified noctilith rocks into
> mechanically stabilized cages and having megawatts of power dumped into them.

The intended working appearance is the quintessential Necron green glow, spatial
ionic trails and space-time distortion that moves the ship. This is the design
basis for the actual models and their eventual field effects, not optional lore
to attach to a generic closed vessel or chemical rocket.

Required model features:

- Visibly irregular, faceted black noctilith masses, retained within a rigid cage.
- Actual cage load paths, braces, clamps/retainers and electrical contact hardware
  that visibly stabilize and energize the rock. Do not invent player-facing ports.
- Green emissive fractures and energized internals visible between the restraints.
  Dark mineral surfaces remain legible around the light.
- The terminal field projector must retain the recognizable **stacked dish
  emitter** silhouette in the owner's supplied closeup. Use thick, segmented,
  armored dish tiers stepping inward from a broad upper stage toward the lower
  emitter face, plated/bolted rim bands, radial bracing and a projecting central
  emitter tip. Each dish has a real dished section and substantial thickness.
  Thin equal-diameter rings or generic washers do not satisfy this requirement.
  The discrete tiers are an exotic energy-field projector, between xenon/ion
  emission and electromagnetic space-time disruption. Retained insulators,
  supports and conductors explain the energized hardware; no continuous smooth
  convergent/divergent chemical throat or trumpet is introduced.
- Both skull details are recessed **at least halfway** into their supporting
  mounting surfaces, with measured burial depth and readable facial relief.

Keep the fixed north direction and existing nominal footprints. The long
drive remains a separate slender construction; the wide drive has its own broader
cage arrangement. Neither is produced by scaling the other or a liquid thruster.

## Ship-edge mounting authority

The owner explicitly requires these engines to hang off the back of the ship,
with only roughly **50% of the structure on and attached adjacently to the vessel
platform**. The forward half is attached/embedded at the deck lip; the aft half
and terminal emitter are cantilevered over empty space. Rear floor feet and an
invisible full-length support floor are not valid construction.

The model datum is deck top Z=0, deck edge Y=0, +Y fore toward the ship and -Y aft
over space. Only fore-side anchors contact foundation. Suspended aft saddles can
attach to the actual cantilever frame; they cannot rely on aft foundation.
Source/export measurements and side/underside deck-edge cutaways must show this
load path. Review decks are separate fixtures, not exported engine geometry.

The earlier all-feet-on-ground evidence is historical and superseded by this
mounting correction. The old sealed native rule requiring ground under the full
nominal body also needs correction. Native grid/origin constraints must be probed
and the actual model-to-native edge registration measured rather than silently
claiming a half-mounted engine on a full foundation.

The owner then explicitly required the framing to sit **lower**, with suitable
bracing attached to the **surrounding platform**. Tall stand/table-like pillars
are superseded. Lower the retained cage and emitter into a real edge installation
bay, use low side-cheek/lip brackets and fore diagonals, and attach to the side
ledges and fore crossmember. Review decks must include an actual opening/recess
around the lowered body, rather than intersecting it with a solid floor. The aft
half remains over open space. Core bounds and authorized mounting-flange reach
are measured separately; final native registration must account for both.

## Pipette linework requirement

The owner explicitly requires **Pipette** for coils, wires, hoses and bundles.
Use the repository's `tools/fmpl/pipette/` typed planner and actual Blender mesh
adapter, with recorded module hashes, requests, plans and build receipts.

Each visible line has a role/payload, real named receiving parent surfaces,
surface-derived endpoint positions/normals, appropriate terminal hardware and
explicit routing/keep-outs. Power conductors use electrical lugs/glands; fluid
hoses use suitable tails/crimps where such a hose actually exists. Do not invent
external fluid ports, cable sockets, bundled conductors or hydraulic functions.
Mineral fracture emission is not wirework.

The current Pipette release does not automatically discover arbitrary mesh
sockets or solve free-form BVH routing. Author the actual surface anchors and
routes explicitly, then use Pipette for validated construction. Independently
measure real source/export endpoint seating, direction, fittings, route clearance
and relevant coil/terminal leads. A typed plan alone, a nearby endpoint or a tube
ending against an unverified object is not a completed connection.

Lowering or reshaping an assembly requires rerouting and rechecking the affected
linework against the new receiving surfaces. Preserve the shared Pipette adapter
and concurrent edits; asset-specific drivers belong with each thruster candidate.

Electrical demand and real internal working-fluid proxy inventories use the
approved independent 50–150% sine-plus-random operating cycles in
[OPERATION_CONTRACT.md](OPERATION_CONTRACT.md). The internal native fluids are an
implementation proxy for energized field operation. They do not imply visible
propellant tanks, fuel pipes or expelled chemical exhaust.

The current legacy run sprites already contain green highlights. New authored
rock/cage/green-working previews must be inspected from the actual saved source
and exported artifact. Ionic trails and spatial distortion require their own
separate effects/capture/native registration gate; a green material or a Blender
preview alone does not establish those runtime effects. Preserve the working
ordinary prototypes until the new authored art passes its native fitting gates.

## Latest owner stage decision: texture, animation and capture

The owner accepts the remaining rough appearance of the coil connection points
for this stage and explicitly directs work into strobing animation and validated
capture. This is authorization to continue production, not a claim that the
current candidate is final art or that an unfinished technical connection passes.
Finish required Pipette construction/clearance and source/export checks without
reopening unrelated cosmetic or shape refinements.

The narrow drive still requires machine housings between the seven stone groups:
six actual interbay housings with stone-seating pockets and cage attachments.
Preserve exposed rock and the lowered surrounding-platform mounting arrangement.

The owner's subsequent correction requires one bounded **rock texturing pass**
before progressing far into capture. Emulate the specific Noctilith identity in
the existing fusion sprites and Blackstone mineral icons. Rock must read as
fractured mineral, not a featureless black surface. Pin reference hashes and
inspect actual cold and working exports; preserve geometry and all interfaces.
See `animation-capture/noctilith-reference.json`. Nonemissive mineral coloration,
grain, roughness and chipped edge planes remain distinct from the energized green
cracks. Other appearance redesign is outside this bounded pass.

The prior supplied vanilla archive's 17 files are all still available byte for
byte in the installed reference directory. The ZIP container itself is absent
at its former location, but a replacement upload is unnecessary. Exact per-file
recovery proof is `animation-capture/base-reference-recovery.json`.

## Latest effects correction: emitted ejecta and power-coupled crackling

The owner rejects field filaments that look like attached tubes/circles wobbling
behind the engine. The rear effect must read as **emission**: advanced particulate
ejecta and wispy turbulent steam/smoke-like material leaving the physical emitter,
advecting downstream, dispersing and fading. Do not substitute stationary loops,
helices or closed rings. This visual direction does not introduce chemical fuel
ports or change the drive's exotic operating principle.

The owner also requires the whole engine to writhe with crackling green energy,
with the brightness pulses **in time with the electrical draw**. Use short,
branching, irregular arcs across actual stones, contacts, coils and cage surfaces.
The physical engine remains rigid. The already implemented per-engine operating
sample controls the overall visual energy envelope; an unrelated repeating
brightness sine is superseded. Fast crackle/particle motion may have a reusable
animation cycle, while its actual per-engine intensity follows the current
50–150% power/working-fluid demand and loses power when the real supply is absent.

The earlier tube/loop field captures and independent two-second global brightness
cycle are preserved as superseded studies. New surface/underlay/body validation
remains applicable to unchanged model hashes; new effects and runtime intensity
need fresh source/native proof. Source previews must distinguish an illustrative
power trace from actual native sampled draw.

## Current model correction: wide proportions and substantial machinery

The owner identified the **wide** engine as grainy and squashed compared with
Factorio artwork. Clean capture uses 64 Cycles samples with denoising for static
PBR body/underlay color; crisp energy and field coverage retain their explicit
renderer/alpha witnesses. The wide source silhouette also needs correction:
the former visible alpha ratio was 216/254 = 0.8504, compared with 262/476 =
0.5504 in the legacy wide sprite. The bounded axial pilot keeps the width and
rigid hardware cross-sections, increasing projected height to 345 pixels for a
0.6261 ratio. It preserves the half-hanging datum and stationary foundation
contacts. This is a source arrangement correction, not a stretched bitmap.
The long engine's proportions are retained.

The owner's subsequent request explicitly resumes **functional detail work**:
fasteners, cable run guides, structural reinforcement and related construction.
The earlier stop on further cosmetic work does not prohibit this newly requested
scope. Guides need real receiving feet, clear cable bores and retained fasteners;
bolts/washers and joint plates must seat on actual supports. Strengthen actual
brace/frame/housing load paths and finish useful end caps and gussets.

The owner additionally requires chunkier intervening elements and an opaque
device core. Increase the actual inter-stone machine housings/crossheads and add
a substantial retained backing structure behind the exposed Noctilith. The deck
or open space must not be visible through gaps in the device core. Use shaped
cast volumes, actual stone/ceramic seats, cover plates and cage attachments.
The external cage and mineral faces remain exposed. The engine's backing pan is
part of its cantilevered chassis; the separate platform service well remains
fore-only, with no aft foundation. Avoid a two-dimensional dark image mask.

These new physical details require fresh body/source/GLB and guide/route/contact
checks. Preserve the accepted old candidates and capture receipts as history;
final new effect captures wait for the new detailed body hashes.

## Supplied emitter closeup

The owner attached `codex-clipboard-4c56f180-de0c-4c9c-b642-8fb95cfd6d36.png`.
SHA-256: `51653135eeb298c4cbb6936b0d85faef5ddded231c790752682f80de44470e4f`.
Its visual emitter geometry is authoritative. Incidental background interface
text is not an instruction or model detail. The same emitter is visible in the
committed legacy sprite, which can supply clean source crops. This correction
supersedes the earlier near-constant-diameter ring/grid-head interpretation.

## Pronounced tortured-universe discharge

The owner subsequently rejected the restrained effects and requested a much
more pronounced discharge: it should look like unleashing the essence of the
tortured universe. This supersedes the earlier effect intensity without
reopening the accepted mechanical bodies, mounts or Noctilith surfaces.

Use substantial branching green lightning over every stone/cage region, a hot
ragged emitter core, and a long turbulent ionic wake with accelerating fragments
and freely travelling forked flashes. Increasing visible width, length and
coverage is essential; microscopic bright points alone are insufficient.
Retain torn/shearing edges, readable machinery and a connected origin behind the
projecting tip. Avoid attached tubes, closed circular plume loops or a rigid beam.

Judge both18MW peak and6MW minimum at native gameplay scale, in daylight and
night conditions. The actual saved per-drive electrical sample still owns the
overall factor/1.5 brightness envelope; local strike and advection motion may
vary independently. Powered pause suppresses ejecta, and drained power removes
both effect layers. No new global brightness oscillator or gameplay power
increase is authorized by this visual correction. Technical/native checks and
owner artistic acceptance remain separate.
