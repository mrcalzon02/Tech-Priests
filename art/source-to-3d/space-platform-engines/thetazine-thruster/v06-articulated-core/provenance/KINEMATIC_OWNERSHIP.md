# Thetazine V06 mechanical ownership

This derivative implements the owner's axial core stroke, smooth periodic noise and small periodic torque. It preserves the canonical V05 model and V04/source35 files. It does not change native prototypes, recipes, ports or normal installed art.

## Current source and export

- Packed source: `../core10-complete-pose-range/thetazine-v06-complete-motion.blend`, SHA-256 `35c4f470ad92015b70d056086b7f6e53573f4ccabbecab6af346ab382734871e` (byte-exact mechanical source from stage08).
- Physical GLB: `../core10-complete-pose-range/thetazine-v06-complete-motion.glb`, SHA-256 `77892d382fe0b1f39f28d84082d6c68dbb3b00c26f1476a3963cac97b9fce074`.
- Cold frame 0, working frames 1–64 and wrap frame 65 at 30 fps. The saved source timeline 1–65 is retained; the exporter explicitly evaluates 0–65 without resaving source. GLB has 3,202 physical meshes, 21 physical EMPTY nodes and 150 animation channels.
- `../independent10-export66/validation.json` proves all 66 source and actual-export poses, exact working-loop closure, unchanged original source fields except declared changes, protected original interfaces, new geometry/UV/PBR and actual actuator fit. Maximum world vertex error is `2.00186445908912e-6 BU`, below `1e-5 BU`. Its status separates the targeted nonmate clearance classification below.

## Actual route ownership

`route-ownership.json` classifies all 84 physical routes from source construction and actual parent chains:

| Ownership | Count | V06 action |
|---|---:|---|
| Fixed services |12|Keep original geometry and motion|
| Already inside core hierarchy |40|Follow new core automatically|
| World-baked leaf links, both ends on core/leaf |24|Root retargeted every old pose into old-core-local coordinates, then parented to new core|
| Fixed-to-core hoses |8|Root retained sweep topology/UV/PBR/unions; rebaked actual endpoints and ring frames, invoking typed Pipette plans per pose|

The eight boundary hoses are six `V04 cold bulk radial feed {fuel,water} {0,1,2}` and two `V04 regenerative turbo supply {fuel,water}`. Existing four corrugated external/deck bellows connect protected fixed-frame interfaces and remain unchanged. Four injector riser/collar meshes follow their real moving chamber-band contacts; four pumpbed riser/collar meshes are restored to fixed ownership at their actual diagonal-shoulder receivers. The render-only combustion volume and plume join already descend from the sliding-bell carrier/core. `current-exhaust-ownership.json` also verifies the current packed source volume uses object `Generated` texture coordinates for both radial field and flow mapping, so its density field follows the moving volume rather than remaining world-baked.

## Two giant side actuators

The original Hydrogen builder lines114–120 authored solid shafts, external helical threads, four collars per side and two clevises per side, all later parented to the fixed recoil frame. They were not pre-existing telescopic pistons. Actual clevis-pin mesh centroids establish the new fixed-fore/core-following-aft solve.

- Short hollow fore barrels pivot rigidly about actual fixed pins.
- Rigid stepped inner rods slide with the measured aft pin separation; the old external coils and collars retain their original geometry.
- Two old aft structural webs are rebaked between the solved aft clevis and the actual core receiver.
- New thin rod portions clear the bore; thicker aft portions seat the retained collars. The 132 side/pose records for each source/export prove pins, rigid members, overlap, running gap, 72 radial rays per collar and finite original clevis contact.
- Original clevis hosts remain finite closed box/cradle representations. No drilled-bore or universal CAD clearance claim is made.

The independent probe discovered that the solver's hardcoded replacement shaft datum was `0.050 BU` below the retained collar axes. Subsequent canonical-mesh measurement proved the original shaft and collars were already aligned: this was an authoring error in the derivative, not a legacy source defect. Four replacement shaft surfaces were restored to the actual canonical axis, then matched to the retained 48 facet phase. Actual source vertex frames agree within `7.53e-8 BU` perpendicular center offset and `7.74e-7 rad` angular phase. Units are authored BU; no real-world scale is inferred.

## Separate clearance evidence

- 110 new fixed bracket details versus other moving geometry: all 66 source poses pass; four changed shaft surfaces are excluded from that receipt.
- 2,298 core descendants versus 758 protected original surfaces (750 world-static plus 8 unchanged cyclic internals): all 66 source poses pass, with conservative minimum separation `.030633330 BU`.
- Four restored-fixed pumpbed parts versus the core: all 66 supplemental source poses pass, with minimum bound `.698431474 BU`.
- The final 32 member nearby-pair sweep covers 18 rigid side-actuator members plus 8 hoses, 4 injector supports and 2 aft webs. It completed all 66 poses with zero new unrelated-host or out-of-shaft-corridor defects. `../independent08j-local32-source-clearance/clearance.json` retains the full finite screen and earlier passing prefixes.
- Three local legacy flags remain explicitly described rather than called clear: left clevis/feed6 terminal touch at frame 12 (6 triangle crossings), mirrored right clevis/feed0 terminal approach at frame 46 (no intersections; source gap `.000140596 BU`), and the same original union029 bolt retained inside its original riser at frame 48. Independent SOURCE and actual-GLB proofs bind both authored terminal spans 20–30 and the old receiver faces. The terminals remain respectively `.024016 BU` and `.022345009 BU` outside the strict union-component envelopes; those envelopes were not enlarged. The owner accepted these narrowly documented existing-layout limits while requesting animation, without a general CAD cleanup or reroute.

The bound final receipt is `../independent08j-local32-source-clearance/final-resolved-receipt.json`, SHA-256 `f5b5e28d748ce70632fa03bb712acafda109ac8a46a7297b1b23d3e170aeefc0`. Its status is `PASS_BOUNDED_MOTION_EXPORT_AND_NO_NEW_UNRELATED_INTERFERENCE_WITH_RECORDED_LEGACY_ROUGHNESS`. It binds 6,760,512 broad-phase pair/pose checks, 55,161 exact nearby checks, all 66 source/export poses and the three independent SOURCE/actual-GLB region reviews. The 27 additional bolt/subpart pose contacts inside the two already-fouled union regions and maximum measured legacy patch displacement `.157406207 BU` remain disclosed. All five final input pins were rechecked; the source and GLB hashes above remain unchanged.

Rejected export study 09 (missing cold frame 0), mesh-only 08 exports and earlier fit studies remain preserved. Stage 10 corrects export assembly only; it does not modify the validated mechanical source.
