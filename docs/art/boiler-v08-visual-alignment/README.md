# Boiler V08 — four-direction visual registration correction

The physical water/steam connections already worked. The previous native attachment-coordinate check did **not** establish visual sprite alignment, and the owner rejected that visual result. The old common sprite scale/shift is superseded by these four independent draw registrations.

The unchanged 256px source cells project the two existing flange centres differently by orientation. East/west compress the separation through the 45-degree camera, so they need approximately sqrt(2) times the previous scale. North and south retain their scale but need different vertical placement. East/west also need opposite horizontal shifts. The mouth landmarks were read from the exact approved V07b native source (hash in the receipt), checked against the actual source-atlas pixels, and fitted to the existing native pipe graphics. No boiler pipe, collision, selection, recipe or energy field was changed.

| Direction | Scale at 256px | Shift X | Shift Y |
|---|---:|---:|---:|
| North | 0.418750 | 0 | -0.555428 |
| East | 0.592202 | -0.207107 | -0.489999 |
| South | 0.418750 | 0 | -0.262535 |
| West | 0.592202 | 0.207107 | -0.489999 |

`before/` and `corrected/` are actual graphical Factorio 2.1.24 captures at zoom 4. `four-orientations.png` shows the corrected contacts; `before-after.png` keeps the same pipe locations for comparison. Boards only crop/resize and label the screenshots. The physical-port readbacks are byte-equivalent as JSON data before/after; this is a preservation check, not a substitute for visual review. All four corrected closeups were inspected.

The production job stores `directional_registration` for all four directions. The exporter consumes it when generating both normal directional graphics and BoilerPictureSet structures, and includes it in its receipt. The installed Lua was generated through the actual exporter helper and is byte-identical to the candidate loaded by the graphical client. The atlas bytes, 96-frame timeline and orientation-cell mapping are unchanged. The fitting applies equally to every frame because the interface manifolds do not belong to the animated rattle rigs.

Cold-idle/working-state separation and circuit-wire anchors remain separate open gates. Do not reopen fluid functionality or behavior/regression work to evaluate this visual correction. The older wide-view boiler image under native-attachment-review is a rejected visual baseline, not accepted visual-placement proof.
