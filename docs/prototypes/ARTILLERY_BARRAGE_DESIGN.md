# Bunker artillery: revolving-breech barrage

Current stage: completed prototype, Tech Priests 0.1.684.
The capture and full-main review used 0.1.683; final publication incorporates
the concurrent hydrogen balance delivery without changing artillery assets. All 64 directional
body, per-round and moving-shadow captures are packed and promoted. Full-main
acceptance passes 20 combat/recipe/save-resume sites and 64 runtime headings,
including the graphical inventory preview and native diagonal launch origins.
Evidence: `artillery-production-acceptance/review.json` and its bound captures.

The owner selected a three-shell rolling barrage followed by a long reload,
accepted the revolving breech, and required an elevated artillery firing pose.
The current candidate fires at 35 degrees. The complete barrel, breech and
recoil bed lower to level for reloading, then elevate before the next barrage.
The bunker foundation remains a separate fixed asset.

## Proposed native firing cycle

Use the existing artillery-shell category, projectiles, damage, automatic and
manual target selection, ranges, research and one actual shell per launch.
The selected burst role changes cadence, rather than inflating shell damage.

| Base tick | Action |
| --- | --- |
| 0, 90, 180 | Three native launches, 1.5 seconds apart |
| After each shot | 0.494-tile recoil, return to battery by tick 62 |
| 250–300 | Lower from 35 degrees to level |
| 315–360 | Open the rear reload gate |
| 360–440 | Return the empty drum to its initial chamber |
| 450–495 | Three large rounds slide into the open mechanism in succession |
| 500–545 | Close the gate after loading |
| 550–600 | Elevate to 35 degrees |
| 600 | Begin the next barrage |

Three shells per 600 ticks matches vanilla artillery's one shell per 200 ticks.
The last shot to next barrage is seven seconds. Native shooting research scales
the complete cycle: +100% speed gives 45/45/210-tick gaps. Inventory, target loss,
manual targeting beyond automatic range, exact native shell damage, recipe
consumption and mid-reload save/resume pass the native test fixture. The same
20 cases also pass inside the full mod while preserving its 180 existing routes.
The graphical run verifies 64 heading selections and 71,209 visual checks.
Existing cannon-family (32 sites, five legacy weapons) and rocket (23 sites)
regressions pass. A separate-process save/resume test passes mid-reload.

## Current model evidence

`art/bunker-artillery/candidate-v19` contains the editable packed Blend and the
independently reimported static GLB. The Blend retains the full source animation;
the GLB is a static runtime interchange, not an animated-gameplay claim.

The trunnion is centered over the mounting plate. Two full-contact yoke feet
bolt onto a thick distribution plate; radial gussets and a central pedestal
transfer those loads into the traverse flange and its 16-bolt circle.
The redundant cage saddle bars are removed. The rear gate has two bored clevis
hinges mounted to the rear support ring, with gate-side lugs and captive pins.
Narrow curved bands clamp the cage wires to both support rings. The lubrication
line connects the motor and reduction housing on the same recoiling carriage.

The full 601-frame source check covers chamber/guard intersections, sliding
links against supports, gate sweep, bore alignment, recoil, level reloading,
the full recoiling assembly against the mount, centered trunnion placement,
full foot contact and clearance above the 1.70-tile bunker socket. It does not prove continuous
collision clearance or native gameplay. Earlier failed and superseded candidates
remain locally preserved; their reports are retained alongside this candidate.

The hardware audit requires actual evaluated material intersections between
the named cage bands, wires, clamps, hinge lugs, clevis mounts and their supports.
Hinge bores provide real pin clearance. Gate motion is checked against its
fixed clevis plates across the same 601 frames.

The installed Factorio 2.1 runtime API exposes `on_trigger_fired_artillery`
with the original projectile and source. That native event observes launches
through the canonical event owner without replacing native damage or targeting.
Artillery orientation uses `relative_turret_orientation`.

Native integration must use the real shared bunker foundation, corner-stanchion
force masks, modeled turret top, native preview and barrel-aligned native firing
effects. No visible vanilla-body stand-ins or blank-art acceptance fixtures.

The native launch lookup contains exactly 64 already-projected heading entries,
without a duplicated 1.0 endpoint or a second orientation projection. Native
cardinal and diagonal launches pass the same 0.08-tile socket tolerance.

Owner scope change, 2026-11-15: artillery is the final weapon. No further
weapon development follows this delivery.


## Reload visibility correction

An alpha intersection of all body poses was an incorrect native cap layer:
it could retain opaque pixels from different moving parts at the same screen
position. It painted over the lower cage in both world and camera views.
The native cap sublayers now contribute no static geometry. The actual complete
source body is rendered independently above the fixed bunker; the lower gate
and chambers remain visible throughout lowering and reloading.

The artillery inventory window uses a live camera and Factorio inventory widgets
bound directly to the player and artillery inventories, plus the native auto
-targeting flag. It replaces the incomplete static entity preview. Transfers
respect reach, and the reload display is driven by actual native launches.

Candidate v19 adds shell insertion directly to the inspected v17 master.
Its authored meshes, modifiers, UVs, used texture pixels, lighting and rigid
pose transforms were compared before reusing any completed captures. Changed
insertion poses are freshly rendered. Body and shell layers remain separate so
visible rounds follow real inventory, including partial loads and resupply.
