# Bunker artillery: revolving-breech barrage

Current stage: model and source animation candidate. Native artillery gameplay,
recipe/research registration and final directional sprites remain unimplemented.

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
| After each shot | 0.76-tile recoil, return to battery by tick 62 |
| 250–300 | Lower from 35 degrees to level |
| 315–360 | Open the rear reload gate |
| 360–440 | Return the empty drum to its initial chamber |
| 500–545 | Close the gate after loading |
| 550–600 | Elevate to 35 degrees |
| 600 | Begin the next barrage |

Three shells per 600 ticks matches vanilla artillery's one shell per 200 ticks.
The last shot to next barrage is seven seconds. These are a source demonstration
and proposed base timings; native shooting research and partial ammunition must
be verified in engine. Rendered rounds must ultimately follow real inventory
and actual launches, rather than a free-running animation.

## Current model evidence

`art/bunker-artillery/candidate-v12` contains the editable packed Blend and the
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
with the original projectile and source. That native event is the proposed
launch observer; integration must compose it through the canonical event owner.
Artillery orientation uses `relative_turret_orientation`.

Native integration must use the real shared bunker foundation, corner-stanchion
force masks, modeled turret top, native preview and barrel-aligned native firing
effects. No visible vanilla-body stand-ins or blank-art acceptance fixtures.

Artillery is followed by radium, grav, plasma and flamer in the active goal.
