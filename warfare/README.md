# Warfare module — isolated preparation workspace

**PLANNING + READ-ONLY INVESTIGATION ONLY — no gameplay code, sprites, prototypes, recipes, models or combat commands have been added. A branch-only headless capability probe and one investigative CI workflow are present.**

- **Active preparation branch:** [`feature/warfare-module-planning`](https://github.com/mrcalzon02/Tech-Priests/tree/feature/warfare-module-planning)
- **Forked from `main`:** `55ce75a2aca2e65902af2c86e88da3818f6fa2d1`
- **Tracking issue:** [#12 — Warfare preparation and future teleoperation](https://github.com/mrcalzon02/Tech-Priests/issues/12)
- **Separate ongoing factory issue:** [#11 — native process integration](https://github.com/mrcalzon02/Tech-Priests/issues/11)
- **Current engineering doctrine:** native engine authority, single dispatcher, no invented inventory/power/control, no duplicate event route.
- **Ship state:** Warfare **not enabled, not implemented, not merged, not released**.

## Documents in reading order

1. [CONTROL_INTERFACE_AUDIT.md](CONTROL_INTERFACE_AUDIT.md) — exact AAI 0.9.2 gun-specific AI variants recorded from the successful combined-modpack engine logs, Factorio unit/car/turret API boundaries, observed limitations, existing Tech-Priests hidden ammo-turret precedent, critical unknowns.
2. [WARFARE_MODULE_ARCHITECTURE.md](WARFARE_MODULE_ARCHITECTURE.md) — future module boundaries, command ownership, teleoperation of Skitarii/bunkers, physical network doctrine, staged defense-to-offense progression, failure and multiplayer handling.
3. [WARFARE_TEST_AND_ASSET_MATRIX.md](WARFARE_TEST_AND_ASSET_MATRIX.md) — existing versus unbuilt asset registry, interface/role matrix, future native functional test IDs and implementation/merge gates.
4. [READONLY_NATIVE_INTERFACE_FINDINGS.md](READONLY_NATIVE_INTERFACE_FINDINGS.md) — **actual** AAI 0.9.2 remote interface names, original 40K gun slots, AAI navigator/solid/ghost variants and turret ranges from two passing engine investigations.
5. [INVESTIGATION_II_AAI_AND_SKITARII_SPRITES.md](INVESTIGATION_II_AAI_AND_SKITARII_SPRITES.md) — confirms existing Tech-Priests already renders Mechanicus Reborn 8-way, 22-frame engineer sprites; captures true 14 PNG sizes and preliminary AAI command-data identifiers from read-only source inspection.

## Summary of deliberate scope

- **Start with what works:** vanilla gun, laser and flamethrower turrets, artillery; native tank/car/spider systems; installed 40K Baneblade, Predator, Leman Russ, Dreadnought; AAI Programmable Vehicles.
- **Future custom assets:** Skitarii infantry, dedicated networked defense cannon, armored bunker and possibly anti-air installations. These **do not yet exist in the game**. **Authorized Skitarii *visual* placeholder:** the already-installed Mechanicus Reborn **engineer retexture**; its use is contingent on actual prototype/animation compatibility, and its art is not copied, bundled, or claimed original. A proper **original 3D Skitarii model, rig and animations** with Factorio-ready directional renders must replace it later.
- **Future human control:** observe/view, give tactical order, and *direct teleoperate* are three different interfaces. Teleoperation of a Skitarius or bunker requires an actual exclusive operator lease and validated native movement/aim/fire.
- **AAI one-weapon issue:** source multi-gun vehicles generate **gun-specific single-weapon AI variants**. Don't infer simultaneous firing or compatibility from modpack load alone; preserve AAI navigation and test alternatives separately.
- **Future combined arms:** progress from automated defenses to remote soldiers/fortresses, then offensive vehicles, then optional anti-air, fire-support and composite weapons only with native combat evidence.
- **Current factory work:** continues independently. This branch does not modify `tech-priests_src`, `info.json`, `.github/workflows`, or working resource/production/defense execution.

## Branch discipline

Do not merge this branch into `main`, retag, publish a release, or begin gameplay implementation without an explicit subsequent directive. When authorized later, develop and test Warfare **on this branch**, add the minimum separate feature-gated runtime entrypoints, validate with one isolated native test profile, and only then seek merge/release approval.

**No placeholders for unknown remote method signatures.** Exact AAI `remote.interfaces` names and gun-specific prototype identities have **now been observed**, but arguments/side effects, turret target release, actual circuit connection and direct-input viability **remain unproven** before any control protocol is built.

**Read-only follow-up evidence:** [Factorio 2.1 run #42164879426](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164879426) PASS. It read AAI/Mechanicus source locations and sprite PNG headers without invoking Warfare orders or copying any mod graphics. Existing `tech-priests_src/prototypes/entity.lua` already references Mechanicus Reborn sprites for visible commandable priests; this is an observed precedent, **not a deployed Skitarii**.

**Evidence quality:** the passing 13-mod/123,000-tick Factorio smoke establishes that the current pack can load and simulate. It does **not** establish Warfare readiness or deployed Skitarii/cannon operation.
