# Six-cannon lobber animation plan

Planning revision A. Static source: V14, commit e5aead307471d7c8867b8ae2ecc212aa5225af39, alternatives/v14/six_lobber_bolted_mount_v14.blend. This revision records the animation design and timing; it does not author keyframes or change the model.

## Firing order and timing

Interpret top right to bottom left as row-by-row order viewed directly from the front: top right, top left, middle right, middle left, bottom right, bottom left. Front is the -Y camera position; screen right is model +X. This is the working interpretation to review in the first sequence preview.

Use a 60-tick-per-second master clock. Consecutive firing events are 80 ticks apart: 1.333333 seconds. Six shots form a 480-tick, eight-second repeating sequence. Each individual cannon fires once per sequence. These are animation event timings; gameplay/prototype changes are a separate integration step.

| Station | Relative tick | Blender frame | Time |
| --- | ---: | ---: | ---: |
| Top right | 0 | 1 | 0.000 s |
| Top left | 80 | 81 | 1.333 s |
| Middle right | 160 | 161 | 2.667 s |
| Middle left | 240 | 241 | 4.000 s |
| Bottom right | 320 | 321 | 5.333 s |
| Bottom left | 400 | 401 | 6.667 s |
| Next top right | 480 | 481 | 8.000 s |

## Independent local cycle

Proposed first-preview timings below are artistic starting values, not approvals of finished motion. All local offsets are relative to the firing event of that station only.

| Local ticks | Visible action |
| --- | --- |
| 0 | Barrel fires; blast flash begins; loaded state clears; recoil begins. |
| 0–5 | Brief tapered flash with a matching short light pulse. Reuse the approved cannon's visual FX language; locate and verify its committed FX source before implementation. |
| 3–90 | Muzzle smoke develops after the flash, then thins and fades. |
| 0–3 | Main cast tube and rounded muzzle move together to the recoil pose. |
| 3–6 | Short recoil hold. |
| 6–24 | Damp the barrel assembly back into its rest pose. |
| 1 | That station's rubber conveyor starts moving immediately. |
| 1–8 | Its pillar hatch opens and the next grenade begins emerging. |
| 8–72 | One intact green pineapple grenade travels along the existing sloping belt, with a restrained roll that keeps the clasp and ring visibly attached. |
| 73–90 | Grenade rolls off the belt into the open hopper and disappears only once behind the opaque feed housing. |
| 91–100 | Conveyor eases to a stop; hatch closes; station returns to its ready pose. |

A proposed 100-tick reload overlaps the next firing event by 20 ticks. This makes the loaders independent and gives the staggered sequence visible activity between shots. Tune grenade speed and hatch timing after reviewing one complete station; the 80-tick firing cadence remains the base value.

## Rig preparation

- Split evaluated left/right copies of the mirrored cannon, muzzle, air hose, socket, hopper, hatch and conveyor assemblies into six separately addressable station rigs. Preserve rest geometry, UVs, materials and world positions against V14. Keep the original V14 file intact.
- Use stable station IDs: TOP_R, TOP_L, MID_R, MID_L, BOT_R, BOT_L. The current LEFT source objects are at model -X; their mirrored counterparts are +X.
- Main cast cannon and rounded muzzle share one recoil control per station. Fixed fin mounts, central pillar, hatches, hopper assemblies and bolted mounting plate do not recoil with the barrel.
- Keep the existing corrugated air hose connected visually: its pillar end stays fixed, while its cannon-end socket follows the recoiling cannon. Deform the visible bellows smoothly between those endpoints. Check all reviewed camera directions for stretching or detachment.
- Flash, its light and the smoke emission point follow the recoiling muzzle. Existing smoke should drift and fade rather than slide rigidly with the returning tube.
- One grenade prop per visible transport event. Replace the permanently posed duplicate hatch/tray grenades with controlled prop states; avoid multiple copies appearing or vanishing in the open. Preserve the classic segmented green body, attached spoon clasp and ring.
- Animate the rubber shoes as a complete closed loop, including the visible end turn and lower return, preserving their one shared material. Use cyclic travel by distance around each existing loop. Do not animate the metal side rails or fake motion by sliding only the texture.
- Update the reload path markers to the V14 hatch and belt geometry. Existing RELOAD_PATH empties were created before the V08 track changes and are planning placeholders, not authoritative animation paths. Fit motion to the actual current belt centerline and hopper lip; check grenade/clasp/ring clearance visually.
- The mounting plate bolts and inset girders remain under TURRET_TRAVERSE; they do not inherit individual barrel recoil.

## Loop boundary

Evaluate station phases independently with (master_tick - station_offset) modulo 480. The last cannon's reload and smoke continue across the master-loop boundary: do not reset every loader or every particle at tick zero. At the start of a steady repeating loop, the previous bottom-left reload is already in progress. Use a full-cycle preroll or equivalent wrapped keys/caches, then review two consecutive loops. A separate cold-start intro can be planned later if gameplay requires it.

## Implementation stages

1. Prepare six independent controls and validate rest-pose preservation. Review the unchanged model before keyframing.
2. Animate TOP_R only: flash, recoil, smoke, immediate belt start, hatch, one grenade's full visible journey and return to ready. Render a close review from the game camera, including a side view for hose and hopper clearance.
3. Reuse the reviewed local cycle across all six stations with the 80-tick offsets. Render an eight-second sequence twice consecutively for loop-boundary review. First review can be sampled at 15 fps while retaining the 60-tick master schedule.
4. After motion review, use the established Factorio rendering workflow for the required directions, transparent sprites and emissive/FX passes. Confirm that workflow's export sampling and gameplay animation mapping before choosing atlas frame counts. Keep the bunker out of turret-only exports.

## Acceptance checks

- Exactly six firing events per eight seconds, in the stated row-by-row order, with no unintended simultaneous pair shots from Mirror modifiers.
- Only the firing station recoils and starts its reload; active stations retain their own state when the next shot occurs.
- Flash stays at the moving muzzle; barrel returns to its original rest transform; fixed mounts and the bolted plate remain stable.
- Corrugated hoses stay attached during recoil; hatches and belts remain independent of recoil.
- Every visible reload follows the existing hatch–belt–hopper route; no grenade travels through an exposed solid face or disappears in midair.
- Rubber shoe motion is continuous around the entire loop with one material. No rest-geometry drift or nonuniform shoe scale.
- Smoke, grenade props, belt position and hatch state remain continuous across the master-loop boundary.
- Save an editable native animation scene, timing manifest and reproducible render source before publishing preview clips. Verify the committed artifacts and actual displayed preview, not just a successful export command.
