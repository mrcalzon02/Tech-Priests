# Advanced Space Cargo Inventory V01

Owner-rescoped construction: keep the original Basic three-window cargo module,
add a huge closed double cargo door into a real subframe shaft and a large
articulated overhanging crane. The pedestal sits close to the cargo windows;
the raised boom and suspended hook reach back over the door. The dense detail pass
adds213mounted parts: panel lips/seam armor, gussets, corner shoes, bolted web
edges, a true louver vent, two hollow pump stacks, and four supply/return tubes
with actually bored receivers.400 source/GLB axial bore probes pass. The rejected
four-bay and rectangular studies remain under `studies/` and are not delivery.

The source is a genuine square:4.92x4.92 units. Owner's explicit SQUARE correction
requires Advanced native placement5x5, selection±2.5/collision±2.2 on both axes.
Capacity50, health420,18s recipe, void-cogitator research, platform-only rules
and wire reach9 are preserved. Square placement permits normal R quarter-turns.

`advanced-space-cargo-v01.blend` is packed editable source; the `.glb` is the actual
independently reimported runtime artifact. `basic-reuse-audit.json` proves all242
Basic meshes/UV/material bindings remain unchanged, with only a uniform0.8 module
fit and translation. Materials and lighting inherit the accepted Basic finish.

`occlusion.json` declares three green windows and the closed cargo-door shaft.
Opaque walls/floors and render-only grade holdouts enforce aperture clipping.
Holdouts are omitted from physical GLB and reconstructed by its renderer.
All four source/export leak and stress passes are inspected. Native sprites use
an explicitly recorded sprite-only worldYsqrt2 projection after facing rotation
to match Factorio's square tiles; physical source and GLB remain undeformed.

Four bodies/shadows and matching64px icon are integrated. Actual platform proof:
5x5 buildability, ground/empty-space rejection,50general slots,mixed items,
all16 ordinary inserter sides, capacity block/recovery, red/green contents/reach,
loaded R quarter-turns, original recipe/research,mining and reload. Test helpers
are isolated and do not ship. Crane/door are static service equipment; no new
powered loader, controller or unsupported working animation is invented.

Original editable Advanced source was unavailable; the supplied sheet and original
PNG are references, and the accepted Basic source is reused. Owner visual acceptance is complete (2026-11-17). Static model, sprite integration and native tests are complete.

See `native-evidence/review.json`, `visual-review.json`, `square-footprint.json`,
`service-route.json` and `rear-service-route.json` for exact scope and evidence.

## Crane construction refinement

Shaped chamfered boom heels and tapered necks, annular journal cheeks, a stepped octagonal foundation with four cast triangular gussets, round hollow strut barrels with captive rods and retaining glands, and a tapered forged hook with safety latch/swivel.Additional mounted joint hardware and8 reworked meshes. Square bounds, Basic module, crane placement and native behavior preserved. See `crane-refinement.json` and independent front/rear GLB closeups. All source/export/contact/occlusion gates pass; all four body/shadow facings and inventory icon refreshed. Operated native save reload verified. Owner visual acceptance is complete.

## Accepted final delivery — 2026-11-17

Owner closed visual review and requested integration/publication. No animation or further rotation development is required. Final correction places both boom arms in one vertical plane and derives the transverse journal axes from that plane. Actual machined hub/fork and pin/bore clearances are verified in reopened source and GLB by `crane-axis-audit.json`. Superseded world-Y-journal study remains local under `studies/`; it is not the delivery.

Packed Blender source, GLB, current static sprites, inventory icon and native proof are the final delivery. The private owner reference sheet remains local and is excluded from public publication.
