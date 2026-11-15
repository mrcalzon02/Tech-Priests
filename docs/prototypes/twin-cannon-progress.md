# Fortified twin cannon - development active

Latest owner-directed flash adjustment: total forward lead is now 0.16 tile
(5.12 pixels at normal zoom), with projectile launch unchanged. Flash depth is
direction-dependent: north/away and side-on facings draw below the gun;
south/toward-facing blasts draw in front. The 36-site fixture checks the real
render object's position, orientation and render layer across all eight test
facings. This supersedes the earlier 0.08-tile setting recorded below.

## Shared base ownership colours restored

The original base delivery recorded neutral/team masks but the prototype
registration omitted them. Recovered the original four named corner buttress
meshes from the Git-held source and rendered depth-occluded coverage with the
original calibrated camera. New neutral paint masks preserve the black
stanchions' shaded texture. Only those stanchions receive force colour;
concrete feet, red armour, equipment, glow and shadows remain unchanged.
The common autocannon foundation registers the masks with apply_runtime_tint,
so the lobber, dish, Chicago piano, twin minigun and twin cannon inherit them.

`docs/prototypes/bunker-team-colour-assets.json` is PASS_NATIVE_GAME_RENDER.
The actual Factorio screenshot and 24-site/four-force report are under
`build/bunker-team-colour/runtime/user-data/script-output/bunker-team-colour/`.
The cannon uses its real new 64-direction native preview in that proof; this
is static appearance evidence, not completed mechanism-animation integration.

Full directional mechanism/aerial capture is running in
`build/twin-cannon/runtime-capture-v2/`, identity-bound and resumable.

## Latest mechanical and animation candidate

Muzzle-effect correction: earlier review clips centred an upright billboard at
the bore, making the flame point down instead of along the barrel. The current
preview is `build/twin-cannon/aligned-muzzle-review-v1/`: screen-space rotation
follows the projected barrel axis, and the native flame's foot (16 pixels below
sprite centre) is anchored at the muzzle. Identical no-flash frames are reused
from aerial-motion-review-v4 with provenance in `frame-reuse.json`.

The engine fixture showed that writing the original explosion entity's
orientation reads back as zero. Runtime now registers the unchanged five
native gunshot animation variations, draws one oriented flash at the active
barrel with an oriented offset, and suppresses the original explosion flash.
The 36-site fixture passes native ammunition consumption, original projectile
damage, cadence, active-barrel selection, flame-foot location and direction at
all eight headings. Stock control effects remain unchanged. This supersedes
earlier claims that teleporting the explosion alone was sufficient.

Owner adjustment: the flash centre now sits 0.08 tile (2.56 pixels at normal
zoom) ahead of the bore. Projectile launch positions are unchanged. Both the
runtime and Blender review use that offset; the 36-site fixture checks the
explicit forward lead as well as barrel selection and direction.

Authoritative runtime correction: oriented_offset is ignored without an
orientation_target. The first pixel comparison caught that the earlier offset
had not moved the actual rendered image. The renderer now places the flash
centre directly 0.08 tile ahead of the native bore point. Tests read the actual
LuaRenderObject target rather than reconstructing an assumed offset. Native
screenshots show a 9.98-pixel outward move at 4x zoom (expected 10.24 pixels).
`build/twin-cannon/muzzle-offset-review/verification.json` binds before/after
hashes and measured movement. Projectile coordinates remain unchanged. Older
Blender clips and claims about flame-foot placement are superseded.

The real animated Factorio pilot now passes all four native ammo types with
four shots each, overlapping left/right recoil, no extra empty-magazine shots,
and a fully returned idle pose. Actual body, aerial and shadow render objects
exist in the engine. The native inventory preview shows the cannon. Evidence:
`build/twin-cannon/animated-runtime-pilot-v1/user-data/script-output/twin-cannon-animated-pilot/`.
Only headings 0 and 8 are packed for this pilot; it is not a full-direction
completion claim. Full capture remains active separately.

The current candidate is now `build/twin-cannon/flexible-aerials-v3/twin-cannon/`.
It retains the pinned supports and deep recoil below. The two radio whips have
continuous tapered meshes with independent X/Y flex shapes, attached protective
tips and fixed socket rings. A damped spring response receives each actual
review discharge and the traverse angular acceleration/centrifugal loading.
The taller aerial oscillates at 2.5 Hz; the shorter one at 3.25 Hz. The heavy
telemetry blade remains rigid. Recoil produces maximum tip offsets of 7.4 cm
and 5.0 cm. Traverse is demonstrated separately after tick 240, with a direction
reversal and settling period. The motion does not use a continuous idle wobble.

`aerial-geometry-check.json` checks all 481 evaluated frames: fixed sockets,
attached tip caps (maximum error below 0.000001 tile), and nonzero flex.
`build/twin-cannon/aerial-motion-review-v4/` contains the review render.
Earlier flexible-aerials-v1/v2 are superseded studies: v1 had a weak turn
response; v2 exposed cross-axis shape-key inheritance and detached tips.
These are source animation and review assets. Dynamic gameplay integration is
still pending alongside the full cannon sprite integration.

The preceding mechanical revision is in `build/twin-cannon/deep-recoil-v3/twin-cannon/`.
It superseded the mesh-feed-v2 candidate below. The mantlet shoulders are
joined into the main casting; sensing and aerial mounts clear the new armour.
Each inspection plate now has two telescopic support stays with pinned clevis
brackets seated on the plate and rear loader roof. The loader service panels
were moved fully onto the flat roof. `stay-detail.png` shows the actual joints.

Independent guns recoil 0.9 tile in three ticks, hold through tick seven and
return slowly to battery by tick 80. The review fires left/right at ticks
0/45/90/135, then settles without extra shots. The fixed foundation is excluded.
`build/twin-cannon/motion-review-v2/` holds the refreshed motion review.
Its flashes use local native cannon artwork for preview only; the runtime
controller positions the original engine effect at the active barrel.
The 36-site native projectile/effect pairing fixture passes across all four
cannon ammunition types and eight headings, with stock controls preserved.
Full graphical in-game integration is still pending. Model approval is pending.

## Current owner-reference rebuild

The owner rejected the earlier model before in-game use and specified three
corrections: more sensing, more aerials, and a correctly routed rear feed.
They then provided a drawn reference for a flexible ammunition belt enclosed
by wire mesh: it rises at an angle from the base, curves level, enters the
rear SIDE of an enclosed turret mechanism, and is pulled forward internally.
The open rear conveyor and exposed shell-turner interpretation are superseded.

The current review candidate is
`build/twin-cannon/mesh-feed-v2/twin-cannon/twin-cannon.blend`, with its actual
GLB and rendered front/rear/quarter/side and isolated-feed detail beside it.
It has paired curved side-entry chutes with mesh on all four faces, continuous
corner rails, articulated ribs, bolted end collars, angled lower feedthroughs,
real receiver openings, internal cartridges and enclosed per-barrel loaders.
Carrier backing is mirrored to the inside of each bend so the cartridges
remain visible through the outer mesh. Each belt indexes for its own cannon.

Sensing now includes a supported multispectral optical director, independent
flank tracking pods, an elevated search array and a rear feed-observer camera.
Three connected aerials comprise two radio whips and a rear telemetry blade.
The new parts are authored by `tools/art/twin_cannon_mesh_feed.py` and
`tools/art/twin_cannon_awareness.py`, called by the existing cannon builder.

Independent actual-GLB inspection passes: 119,716 triangles, 328 meshes with
UVs, 60 degenerate triangles (0.050%, within the unchanged 0.1% limit), and
the calibrated mount at Z=1.70. The source and export were visually reviewed.
This is a MODEL REVIEW CANDIDATE, not accepted art or an in-game asset.
No full direction capture, promotion or game integration was done with it.

`model-review.png` shows neutral-background views and calibrated small-scale
insets. The owner-photo comparison lives ONLY in
`build/twin-cannon/private-reference-review/feed-reference-comparison.png`;
keep that private board and the attachment out of galleries and packages.
The source sketch is the attachment ending `image-1794718699137.jpg` supplied
after the owner requested a hold to obtain a reference. Goal status was
paused during that hold; this turn performs the requested reference-based
model revision and leaves final model acceptance pending.

Before the art rejection, isolated placeholder-graphics physics work passed
36 sites: all four native cannon-shell types at eight custom-turret facings,
plus stock cannon controls. The original native projectiles are relocated
to alternating muzzle points without respawning them; one-shell accounting,
steady 45-tick launch gaps, narrow-target hits and source-scoped stock-flash
suppression pass. This is physics evidence only, not visual approval.
The owner chose the heavy-armour and line-penetration role. Existing native
damage and penetration remain intact; further gameplay balance is provisional.

## Historical initial model notes - superseded by the rebuild above

Owner requirements: a large twin cannon with separately housed guns and
independent mantlets, sharing one traversing turret body. A substantial rear
loading mechanism must show large linked cannon shells rising from below
and disappearing through the mounting plate. The owner explicitly selected
**steady leftâ€“right fire**, rather than a quick pair followed by a pause.

The current editable model is
`build/twin-cannon/candidate-v3/twin-cannon/twin-cannon.blend`.
Its actual GLB passed independent reimport checks: 28,404 triangles,
151 UV-equipped meshes, zero degenerate triangles and the existing
socket at Z=1.70. Source and imported front, rear, quarter and clay renders
are available alongside it. Quarter and rear renders were shown inline.
Owner visual direction feedback is pending through the optional question.

`tools/art/build_twin_cannon.py` authors the model using the reviewed family
studio and geometric constructors. It creates a single armoured casting,
two independent round mantlets, recoiling gun tubes and recuperators,
individual breech covers, two loading rams, a shared shell transfer housing,
eight correctly spaced large rounds on a curved rear track, and connected
optics/controls. The fixed bunker is excluded from the animated cap.

Initial source animation uses a provisional 90-tick cycle with shots at
0 and 45, independent recoil return and alternating loading-ram motion.
The belt is currently static; its functional indexing still needs authoring.
The body/texture style is a review candidate, not accepted final art.

Candidate-v1's shell spacing was revised. Candidate-v2 exposed 96
degenerate triangles in four thin bevelled inspection plates; candidate-v3
repairs them without weakening the geometry threshold. Earlier candidates
remain superseded studies. The generic export inspector now accepts an
optional list of asset names, retaining its old two-weapon defaults.

Remaining work: refine the model from owner feedback; settle the distinct
gameplay role and provisional ammunition/range/cadence numbers; animate
shell-feed indexing; register the actual cannon prototype and recipes;
prove alternating projectile launch positions and native ammo accounting;
capture body/FX/shadows with correct shot sampling; create native preview
cores and icons; verify gameplay, previews, save/reload and regression;
package a new isolated prototype revision. Preserve the completed 0.3.0
bullet-turret package and the protected full-mod release.

Implementation cautions: cannon projectiles travel, so impact events cannot
time recoil or muzzle flashes. Trigger the shot controller at launch.
Source shots at tick 45 are off the earlier 30-fps capture grid; use an
explicit FX sampling strategy or capture at 60 fps. The existing bullet
capture utility hardcodes 48/36-tick loops and recognizes only its two
flash-name prefixes, so it cannot be reused unmodified for this cannon.
Native projectile creation offsets choose randomly; do not claim they
provide strict alternating left/right launches. Research-supported launch
handling must be verified rather than inferred from cosmetic FX.

The artillery and missile equivalents remain queued for their own design
discussions after the cannon; do not silently assign them the cannon role.

## Final main integration — 2026-11-15

All 64 directions are packed, with separate motion, occluded aerials, static
cap shadows and native preview cores. Main-mod headless, graphical and mid-fire
reload checks pass. The five earlier weapons are integrated and regressions
pass. See twin-cannon-main-evidence and bunker-runtime-map.md. The remaining
instructions and pending states above are historical development checkpoints.
Source version remains 0.1.681; this integration does not issue a full release.
