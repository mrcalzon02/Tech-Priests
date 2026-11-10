# Water Purifier V12 — restored visible air bubbles and moving foam

**Result:** native Blender and GLB verified; genuine Cycles on/off renders prove both bubble and foam visibility. Owner visual approval and Factorio 2.1 native fluidbox integration remain separate gates.

## Provenance

- V12 source: `mrcalzon02/Tech-Priests` main at exact commit `027d93bfb8b92dd74617de1c2bba28a4395eae39`.
- Existing Dens Mortis Windows self-hosted runner: [successful run #42777518280](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42777518280) dispatched by commit `9f2dbf216df0e1d1d9256e0a2a9a34de780d3894`.
- Native production artifact: GitHub Actions artifact `13745175825` (`dens-mortis-worker-42777518280-1`; ZIP 28,790,690 bytes), includes editable `.blend`, GLB, actual 512px idle/working Cycles renders, three on/off witness proof renders, 8 native working frames, 6 RGBA 64/128/256 sprite atlases and logs/receipts.
- Editable Blender SHA-256: `8342cab9ad7e7d803fd9349cf27cf180343c419e4208bc11520a0950c43f1309`.
- Independent GLB SHA-256: `940688ea2d333bb6ea398a34f31a81e78aac8e42de635bac4afa83f071001487`.
- Immutable historical V04 source `.blend` SHA-256: `5d03419b7861278ed21f89cb08686d79d5ebb80d886d42ed265d866ea7f08c30`.

## Root cause and physically constructed solution

V11 enlarged the two front vessels but left the 24 existing bubble spheres too deep behind the opaque tinted cylindrical liquid bodies, and the two `animated waterline foam crest` pieces were very thin strips inside the liquid/glass near the top rim. Source Blender had genuine bubbles and keyed foam, but user could no longer see them in the renders; previous tests mistakenly treated object existence/keyframes as visual acceptance.

V12 preserves the 0.426-tile OD × 0.712-tile tall RAW olive-amber and CLEAN cyan-blue tanks, original pipe routing, authentic 0.49-tile-ID side connections, the hollow steam nozzle and all previous model engineering fixes. It modifies only source-safe derived materials/effects in `tools/fmpl/effects/fluid_steam_fx.py`:

- RAW liquid transmission from 0.22 to **0.66**, CLEAN liquid transmission from 0.45 to **0.82**, retaining distinct warm and cool approved-source derivative color ramps.
- 12 animated physically modeled rising air bubbles per tank, moved near the inside glass-facing fluid surface and given meaningful vertical ascent through the liquid; 24 bubbles total, 16 keyframed samples plus frame-97 closed loop.
- Existing two animated waterline crests remain; **24 additional real, animated Blender mesh froth beads** (12 per tank) form a visibly active waterline band, colored cream/ochre for RAW and pale cyan-white for CLEAN. Foam uses restrained source-derived material luminance, not generated textures.
- 292 newly authored derivative meshes, 456 independent GLB mesh readback, 50 original MH7 and 136 prior process meshes retained unmodified.

## New visual acceptance gate — do not regress

`tools/fmpl/effects/verify_witness_visibility.py` reopens the actual V12 native `.blend` at the one canonical camera and saves three fresh **real Blender Cycles** frames: all effects visible, bubbles disabled, and foam disabled. A per-tank image subtraction verifies that the physical bubbles and froth actually affect visible pixels, not merely render or animate invisibly.

| 512px real Blender image-difference gate | RAW water | CLEAN water |
|---|---:|---:|
| Bubble contribution, changed visible pixels | **230** | **223** |
| Foam contribution, changed visible pixels | **312** | **338** |

The required gate is at least 12 changed RGB pixels **separately for bubbles and foam in each tank**. The 256px real working-frame fluid-motion QA also passed: RAW 178 pixels, CLEAN 141. Steam visibility remains verified (75 idle / 82 working above-nozzle visible pixels).

## Preserved structural and visual gates

- Side connections tested by **74 real Blender bore rays**, **zero structural intersections**; original 0.49-ID pipe-throats/flanges and fixed 45-degree camera unchanged.
- Original two cone plumes and solid steam outlet cap retained but hidden in the source; new open nozzle and irregular volumetric steam retained.
- One stationary production direction; eight working frames plus idle, 64/128/256 RGBA atlases; no additional GitHub workflow, random geometry or image generation.
- No actual Factorio game-side native fluidbox, connected-pipe runtime, sprite shift, or player visual approval is claimed.

## Follow-up

Preserve the source and verified output in durable FMPL storage before Actions artifact expiry. When adapting this fixture to other machines, always add independent effect-on/effect-off **render pixel visibility** tests—source mesh counts, animation keys and a moving-fluid timeline alone are not visual proof.
