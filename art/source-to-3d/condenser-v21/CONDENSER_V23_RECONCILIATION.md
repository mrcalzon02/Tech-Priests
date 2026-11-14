# Emergency condenser V23 inlet review — November 13, 2026

## Recovered state

Inspected current main at e5e77118b5434aac08346cf1acd1788bd5aba15f and reopened the recovered editable V22C scene in native Blender 5.2.3 LTS.

Recovered scene SHA-256: `5e28d62eb5b4250d78a7b4888d4bf031d5437b9e0a0ed52d4ff7e26d4792d247`.
Library source: `libfile_44cb28f8b00081918f4acb202495502a`, version 5.

| Requirement | Actual recovered state |
| --- | --- |
| Chassis, materials, controls, output flange | Present in editable source |
| Eight sequential cap strokes | Present; 96 frames at 8 FPS, 12-second cycle |
| Lines replaced with inward mist | Present; 40 procedural alpha particles, five per head |
| Openings beneath lifting caps | Missing; eight solid thin seat blocks over a solid rack plate |
| Front-row Factorio output correction | Recorded in current production source and corrected native capture; retained |
| Sustained in-game animation and water production | Still pending; static screenshots do not establish either |

The earlier V22 source-lock policy deliberately prohibited machine geometry edits. It preserved the existing model but also preserved the missing inlet holes. The owner's present instruction explicitly requires that geometry repair.

## V23 repair performed

`repair_condenser_v23_inlets.py` produces a separate review derivative from the exact recovered scene. It cuts eight circular apertures through the seat blocks and rack, adds eight cylindrical interior liners and recessed floors, and moves each existing mist destination beneath the corresponding inlet rim. The liners follow the rack vibration, independently of cap lift. Existing materials are reused for the rims.

Only nine original meshes change: the rack plus eight seats. Sixteen objects are added: eight liners and eight recessed floors. Original hardware world transforms and cap timing are preserved. Foundation, output flange and game prototypes are untouched.

Native verification includes eight unobstructed centre rays through the modified seat and rack geometry. Independent reopening compares original geometry and all original hardware world matrices across frames 1–97; the receipt records its measured result. Review renders use real Cycles, with before/after and mist-hidden diagnostics. The supplied 12-frame GIF shows the first 1.5-second intake slot, not the complete eight-head cycle.

## Remaining work, in order

1. Review inlet depth/rim readability and mist convergence at normal game scale, with all eight heads and all four headings.
2. Tune mist shape, density and timing if it obscures the opening or reads as floating clouds. Replacing lines with particles is implemented; artistic acceptance of the effect remains open.
3. Render a complete revised 12-second cycle in four directions. This checkpoint renders only the first head's slot and a north-facing full view and close-up.
4. Add an explicit V23 export contract for the authorized geometry delta. The existing V22 exporter must continue rejecting the changed source mesh hashes; do not bypass that guard or label this source as unchanged V21.
5. Export revised HR/standard atlases, integrate them, then verify pipe registration, sustained animation, and fuel-fed water delivery in the real Factorio client.

This is an inlet repair and recovery checkpoint, not a completed production integration or release. Existing V22C production graphics remain in place.
