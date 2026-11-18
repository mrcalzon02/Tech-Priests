# Basic Space Cargo Inventory V01

Mostly flush steel platform insert over three closed, below-grade cargo wells.
The bays now vary: slatted wooden crate plus sealed case, three rolled-hoop red
barrels with bungs, and a supported tray of spanners, hammer and screwdrivers.
Accepted FMPL steel/gunmetal/brass/red surfaces and baked directional cedar
replace the initial generic-noise study. Rounded plate/tool edges, formed drum
shoulders and smooth barrel normals replace the overly sharp pilot. The exact
Boiler V08 workshop world, lights and Standard transform are preserved.
Green glazing has a soft low-energy highlight; its effective IOR1.08 is an
art-directed thin-window approximation, rather than a laboratory glass value.

Green glazing, receiving ledges, opaque partition walls and a sealed floor are
editable physical geometry. Corner locks and circuit contacts sit above grade.
The centered relief reuses the supplied skull and bionic assembly.

The original editable cargo source was unavailable; original sprite/icon/shadow
references are retained. This is an independently authored replacement.

`basic-space-cargo-v01.blend` contains packed PBR maps and render-only grade
holdouts. `basic-space-cargo-v01.glb` is the actual physical export. Reconstruct
the cutaway environment from `occlusion.json` when rendering GLB: it does not
provide automatic engine clipping. Factorio uses the baked bounded sprite.

Source and export inspection pass: UVs/maps, finite nondegenerate meshes,
grade-bearing rim, recorded contacts, four-view aperture isolation, neutral clay,
open/empty wells and a deliberately protruding underground stress test. All four
views report zero outside-aperture pixels with one-pixel antialias allowance;
the stress object falls from 1531 visible pixels to zero with clipping.

Four directional bodies, aperture-respecting above-grade shadows and 64px icon are
integrated into the actual prototype. This passive container has no invented
working machinery, cargo-quantity animation or player masking controls.

Real Factorio platform tests pass: 6x3 placement, ground and empty-space rejection,
20 general slots, all four ordinary inserter sides, mixed items, full blocking
and recovery, red/green contents and wire reach, research unlock, mining contents
and reload. Gameplay fields and the other family prototypes remain unchanged.

Wall trusses have continuous chords, fitted gussets and diagonal load braces along
long walls, ends and partitions. All four native placement directions have aligned
circuit points and ordinary inserter access. The original mixed-parity 6x3 grid
uses 180-degree R turns when already placed; quarter-turn placement uses the
normal 3x6 tile alignment. No custom relocation or precision-inserter rule added.

Technical gates pass. Owner accepted this refined source as the Advanced basis;
final native screenshot approval is not separately inferred. Advanced has a
read contract and recovered references, but no model yet. Build its distinct
larger compartment and supported fittings using this clipping standard next.

Final accepted source: `owner-approval.json`; current scored review: `visual-review.json`.
Actual native four-way gallery: `native-evidence/native-four-directions.png`.
Reproduce the accepted packed source/export with `tools/art/space_cargo/build_basic.py`;
legacy pilot generator and all failed material/geometry studies are retained separately.
