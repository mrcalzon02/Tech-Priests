# Tech Priests — November 13, 2026 pre-development benchmark checkpoint

**Classification:** Audit-only, immutable source/release comparison. **NOT a new game ZIP, a new release candidate, or a claim of full runtime acceptance.**  
**Snapshot time:** 2026-11-13 17:12 UTC (08:12 Alaska Standard Time).  
**Pinned development source:** `38242c4072d874e2d57cd823aead7ae591110fa5` on `main`.  
**Pinned published benchmark package:** [`factorio-mod-43362162094-1`](https://github.com/mrcalzon02/Tech-Priests/releases/tag/factorio-mod-43362162094-1), `tech-priests_0.1.681.zip`, source `6613612a856b9811b7858c188053e37084744665`.

This deliberately freezes a read-only baseline before the next development cycle. Do not apply later passing or failing results retroactively to the pinned commit or package.

## Published package identity and what actually passed

- `tech-priests_src/info.json` declares mod version **0.1.681**, Factorio **2.1**. The most recent published package is a **prerelease**, not a verified stable release.
- [Publishing workflow run 43362162094](https://github.com/mrcalzon02/Tech-Priests/actions/runs/43362162094) succeeded on the pinned release commit. It completed the Blender V25 integration step, V22C condenser 41-asset atlas/hash/unit checks, packaging, exact packaged-condenser audit, native Factorio 2.1.24 headless new-save startup diagnostic, and publication.
- [Package ZIP](https://github.com/mrcalzon02/Tech-Priests/releases/download/factorio-mod-43362162094-1/tech-priests_0.1.681.zip): **138,679,663 bytes** (about **132.26 MiB**). [Headless diagnostics ZIP](https://github.com/mrcalzon02/Tech-Priests/releases/download/factorio-mod-43362162094-1/headless-diagnostics.zip): **12,043 bytes**.
- The publishing job's native diagnostic reported `HEADLESS_STARTUP_OK` / exit 0 **with only the packaged mod and official game modules**. External optional/cross-mod dependencies were not provisioned. This is not proof of a fully integrated modpack, sustained simulation, graphics, multiplayer, physical method completion, or migration.
- A prior [release tagged `factorio-mod-43264568594-1`](https://github.com/mrcalzon02/Tech-Priests/releases/tag/factorio-mod-43264568594-1) also packages a different `tech-priests_0.1.681.zip` at commit `b630fb1743012249874924d6d2eeca364506b17e` (138,677,673 bytes). **Version 0.1.681 alone is not an immutable build identity**; always specify release tag + commit + asset.

## Code delta and current native test

[Compare published package to frozen development HEAD](https://github.com/mrcalzon02/Tech-Priests/compare/6613612a856b9811b7858c188053e37084744665...38242c4072d874e2d57cd823aead7ae591110fa5): **54 commits ahead**, **16 changed paths**. Main changes include robot expansion/dispatch behavior, source and Python native-acceptance harnesses, condenser four-direction acceptance fixtures, and corrected game-client capture receipts. This is **unpackaged development**, not a newer released `0.1.681` ZIP.

[Latest completed native Dens-Mortis worker 43466366011](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43466366011) used source `198c7e3f046f2cdae1a4b63a4b983f080159fd7c`, a direct predecessor of the pinned development snapshot. Focused `TECH_PRIESTS_1380_SELFTEST` checks **passed**, but real Factorio 2.1.24 **failed**: `NATIVE_ORE_NOT_CHARTED_BY_BOUND tick=30000 radar_energy=5333.3333333333`. The private no-client server did not chart the natural ore target; no successful native ore-cargo save, CRC or independent reload may be credited. The workflow also separately failed uploading artifacts because GitHub artifact storage quota was exhausted. **Do not label this as a gameplay cargo-loss regression; the environment/fixture did not reach the cargo boundary.**

The frozen HEAD `38242c4` added a fail-fast/diagnostic correction for that exact uncharted no-client condition. [Dens-Mortis run 43469822678](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43469822678) was **in progress** at this snapshot, with no success verdict to credit.

## Acceptance matrix

| Scope | Status at snapshot | Evidence / qualification |
| --- | --- | --- |
| Published version, reproducible tag/commit/ZIP | **Available** | 0.1.681 prerelease above; exact asset size and URL, independent file hash not recomputed in this audit |
| Packaged Factorio 2.1.24 minimal new-save start | **PASS for older package** | Release run 43362162094, not current 38242c4 |
| Required cross-mod 2.1 endurance | **Historical PASS only** | [Run 42151378921](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921): 13 external mods, 123,000 engine ticks and independent 1,200-tick reload of initial save; not the 0.1.681 package/current HEAD |
| Method I: station relay/custody | **Historical real physical evidence, not a blanket closure** | [Issue #6](https://github.com/mrcalzon02/Tech-Priests/issues/6) cites five native processes, four CRC-verified saves and real four-hop ore delivery on a 2.0.77 source |
| Method II: physically paid robot frontier, outpost and natural ore | **Partial, acceptance open** | Earlier 2.1 native construction/ore observations; strict saved held-ore, independent process reload and counted upstream delivery not all accepted on this source |
| Method III: rail Magos round trip | **Open** | Outbound train, remote custody, return, ore delivery and interrupted-save scenarios not jointly proven |
| Condenser V22C native socket connection and corrected directional game screenshots | **PASS for scoped native geometry/capture** | [Four-way physical acceptance](../../art/source-to-3d/condenser-v21/CONDENSER_V22C_NATIVE_PHYSICAL_ACCEPTANCE.md); 16 authentic game-client screenshots, four orientations |
| Condenser sustained 12-second in-game animation, fluid output and owner visual sign-off | **OPEN** | Engine pipe adjacency does not prove sustained water transfer or final artistic approval |
| Exact frozen HEAD source/native and final packaged load gate | **Unverified / failing predecessor** | 43466366011 failed; 43469822678 pending, no complete full-acceptance result |

## Release governance defects to reconcile

1. `README.md`, `docs/STANDARDS_AND_PRACTICES.md`, `docs/state-of-mod-master-plan.md` and `docs/DEVELOPMENT_HISTORY.md` still identify protected package `0.1.672` / lane `0.1.674-dev`, despite `info.json` and multiple published `0.1.681` prereleases. These are **stale historical state declarations**, not proof that 0.1.681 passed the old release gates.
2. The publishing workflow runs on `tech-priests_src/info.json` or its own workflow changes, and is manually dispatchable; it is **not a general main-HEAD validation gate**. Its headless diagnostics omit required external modpack profile and gameplay proofs. Do not interpret its green conclusion as whole-mod acceptance.
3. Separate legitimate art/model approvals, engine pipe links, gameplay fluid movement, functional robotics/rail mechanics, release packaging, and player-facing sign-off. Every proof must retain its original source SHA.

## Next benchmark promotion gate

Keep the existing published `0.1.681` prerelease as the **downloadable comparator**, not a falsely rebranded release. On an exact later tested SHA, collect (1) source and native 2.1.24 startup/load results for required modpack and 123,000-tick science/combat scenario, (2) fresh actual save + CRC + independent process reload with held robot-acquired natural ore and two physically counted upstream hops, (3) Method III real train out/return/ore proof, (4) basic new-save/migration persistence and multiplayer/updater-relevant regressions, and (5) final ZIP packaged-load receipt. Performance and visual refinements are diagnostics unless they cause objective build/run failure, per owner release policy. Do not weaken validation to manufacture a pass.

**Action taken here:** audit checkpoint only. **No binary rebuilt; no additional release/tag created; no workflow dispatched; no game-code behavior modified.**
