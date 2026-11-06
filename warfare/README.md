# Warfare module — isolated preparation workspace

**PLANNING + ISOLATED EXPERIMENTS ONLY.** One disposable, CI-only native Skitarii unit prototype and two test scenarios now exist **exclusively on this branch**. They have passed real native movement, attack and magazine-consumption tests. **No production Warfare gameplay, sprites, recipes, 3D models, user teleoperation, release, or main-branch changes.**

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
6. [EXPERIMENT_III_NATIVE_SKITARII_FEASIBILITY.md](EXPERIMENT_III_NATIVE_SKITARII_FEASIBILITY.md) — **two successful native gameplay experiments** in the standalone test-only [Skitarii probe mod](experiments/skitarii-ci-mod/): real unit movement + attack, and real magazine consumption + bullet damage through the existing turret proxy.

## Summary of deliberate scope

- **Start with what works:** vanilla gun, laser and flamethrower turrets, artillery; native tank/car/spider systems; installed 40K Baneblade, Predator, Leman Russ, Dreadnought; AAI Programmable Vehicles.
- **Future custom assets:** Skitarii infantry, dedicated networked defense cannon, armored bunker and possibly anti-air installations. These **do not exist as shippable game assets**; a separate diagnostic Skitarii **test clone** exists only inside a disposable headless CI scenario. **Authorized Skitarii *visual* placeholder:** the already-installed Mechanicus Reborn **engineer retexture**; its use is contingent on actual prototype/animation compatibility, and its art is not copied, bundled, or claimed original. A proper **original 3D Skitarii model, rig and animations** with Factorio-ready directional renders must replace it later.
- **Future human control:** observe/view, give tactical order, and *direct teleoperate* are three different interfaces. Teleoperation of a Skitarius or bunker requires an actual exclusive operator lease and validated native movement/aim/fire.
- **AAI one-weapon issue:** source multi-gun vehicles generate **gun-specific single-weapon AI variants**. Don't infer simultaneous firing or compatibility from modpack load alone; preserve AAI navigation and test alternatives separately.
- **Future combined arms:** progress from automated defenses to remote soldiers/fortresses, then offensive vehicles, then optional anti-air, fire-support and composite weapons only with native combat evidence.
- **Current factory work:** continues independently. This branch does not modify shipping `tech-priests_src`, its mod `info.json`, main's CI, or active resource/production/defense execution. A **single branch-only investigation workflow** and test-only mod have been added under `warfare/`.

## Branch discipline

Do not merge this branch into `main`, retag, publish a release, or add production Warfare gameplay/runtime integration without an explicit subsequent directive. Separate disposable branch-only tests are authorized by the user's experimentation request. When authorized later, develop and test Warfare **on this branch**, add the minimum separate feature-gated runtime entrypoints, validate with one isolated native test profile, and only then seek merge/release approval.

**No placeholders for unknown remote method signatures.** Exact AAI `remote.interfaces` names and gun-specific prototype identities have **now been observed**, but arguments/side effects, turret target release, actual circuit connection and direct-input viability **remain unproven** before any control protocol is built.

**Read-only follow-up evidence:** [Factorio 2.1 run #42164879426](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164879426) PASS. It read AAI/Mechanicus source locations and sprite PNG headers without invoking Warfare orders or copying any mod graphics. Existing `tech-priests_src/prototypes/entity.lua` already references Mechanicus Reborn sprites for visible commandable priests; this is an observed precedent, **not a deployed Skitarii**.

**Native gameplay experiment evidence:** [run #42165600370](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42165600370) **PASS**: test unit traveled 4.887 tiles and dealt 3 HP of native attack damage. [Run #42166015258](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42166015258) **PASS**: separate native proxy consumed one firearm-magazine round (10→9) and dealt 5 HP of genuine bullet damage with the test soldier unable to reach the target. The first proxy test also exposed a real Factorio 2.1 incompatibility: `LuaEntity.active` is read-only; corrected **only in the test** and flagged for separate production review.

**Evidence quality:** the passing 13-mod/123,000-tick Factorio smoke establishes that the current pack can load and simulate. It does **not** establish Warfare readiness or deployed Skitarii/cannon operation.
