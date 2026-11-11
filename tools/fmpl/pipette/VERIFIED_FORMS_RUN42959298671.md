# Pipette five-carrier native geometry proof — run #42959298671

**Proof status:** geometry-source tests and independent Blender/Cycles/GLB reopening **passed**. These are usable **editable prototype objects**, not production-approved FMPL materials or certified physical/game connections.

- Source pin (the actual geometry tested): `1d474c94ad22e861418f975522293a6ffa1ff35c`
- Runner: [Dens Mortis — source-pinned native proof #42959298671](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/42959298671)
- Exact runner artifact: `dens-mortis-worker-42959298671-1`
- Existing Windows Blender 5.2 runner; no new workflow or source asset overwrite
- **138 Pipette Python tests passed** and **16 separate scene-scale tests passed**
- **5/5** native editable `.blend` files reopened, **5/5** `.glb` imports verified, **5/5** actual Cycles previews had visible alpha-backed pixels, and **5/5** saved Blender collection asset marks survived reopening
- All five carried unmodified fixed comparison ports from `comparison_fixture.v1.json`.

| Physical architecture | Real editable Blender meshes | Reimported GLB meshes | Lit Cycles pixels | Independent outcome |
| --- | ---: | ---: | ---: | --- |
| `tube_retractile_coil` | 1 | 1 | 3,739 | PASS |
| `hose_layflat` | 1 | 1 | 9,079 | PASS |
| `hose_twin_bonded` | 3 | 3 | 9,977 | PASS |
| `housing_ladder_tray` | 13 | 13 | 8,056 | PASS |
| `housing_slotted_duct` | 33 | 33 | 12,571 | PASS |

## Meaningful geometry

This is not five duplicated circular pipes. The pneumatic line has a hollow 14-turn axial spiral; the discharge hose has a flattened true open bore; the bonded pair has two separate open lumens and an external web; the ladder has physical rails and crossbars separated by open air; and the duct has a U-shaped floor and real alternating comb-wall fingers.

The initial source test run #42958784246 rejected the tray/duct because a flat-ribbon helper erroneously forbade structurally tall/narrow rail sections. It was **fixed with genuine six-faced rectangular prism geometry**, covered by a dedicated topology test, and the source-pinned rerun completed successfully.

## Exact artifact provenance

The native validator recorded cryptographic SHA-256 hashes for each `.blend`, `.glb` and preview PNG in the associated `architecture-independent-reopen.json` receipts. Selected Blender hashes:

- Pneumatic coil: `ea976a728e2160c706bd9f40642f96de76760b56078755ccb03f785d64366489`
- Layflat hose: `4dc37a26056b14d9e03c075e7a059e275544db402f0fd757a64a9c25206ed85e`
- Twin hose: `da0573104560bf990b994fdbbdd02dc7b5cf6588f168404ba0053b64ff2057c8`
- Ladder tray: `2cfe5e96da81025f9f55342beb2833ad784fa8e07ea5fe49adb2089884b33011`
- Slotted duct: `27e11c5cc16070f8b3e3967da3f18fa5efcf497ba7f856df84a98bdcf7f1051b`

The proof set is only source-geometry, GLB, Cycles preview, and Blender Asset Browser registration. **End fitting adapters remain explicitly deferred** for each of these five: connecting a circular coupling to a flattened hose, a single common fitting to two separate bores, or a circular pipe snap to a rectangular U channel would be false geometry. Material provenance/approval and Factorio-native simulation or fluidbox integration have not been claimed.
