# Warfare investigation III — Skitarii engineer-sprite native-unit feasibility

**Status:** **PASS for the two narrowly scoped test scenarios below.** Separate Warfare branch, test-only Factorio 2.1.24, 13 external authenticated mods; **not** a shippable Skitarii, no teleoperation, no AAI movement, no in-game gallery render.
**Branch:** `feature/warfare-module-planning`.
**Successful runs:** [native unit movement/attack #42165600370](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42165600370); [native unit + physical ammo proxy #42166015258](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42166015258). Both GitHub Actions `conclusion=success`, with actual Factorio test logs, not source-only mocks.
**Regression diagnosis:** [run #42165836096](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42165836096) failed on a real 2.1 API incompatibility, repaired on the experimental branch only (see below).

## 1. Reused existing unit and graphics rather than inventing a new soldier art path

The experimental mod [`experiments/skitarii-ci-mod`](experiments/skitarii-ci-mod/) depends on `tech-priests` and `mechanicus-reborn` as runtime-installed mods. Its `data.lua` clones only the actual `data.raw.unit["junior-tech-priest"]` **prototype**, renames the clone `warfare-skitarii-experiment`, preserves the already-loaded run/weapon animation references to `__mechanicus-reborn__/images/`, and adjusts movement, health and attack parameters **only in the experiment**. This is source-written test logic, **not a new animated 3D model or third-party art redistribution**.

The experimental standalone mod is copied only into the **disposable GitHub Actions runner mod directory**. No changes to the shipping `tech-priests_src/data.lua`, `tech-priests_src/control.lua`, recipes, technology, inventory/planning services, main CI, 2.0 compatibility metadata, releases or Factorio Mod Portal.

There is intentionally **no Skitarii crafting item/recipe**, equipment grid, technology unlock or automatic unit spawning: the scenarios instantiate the test clone to ask two specific feasibility questions.

## 2. WAR-SKIT-001 — native infantry unit, movement and direct attack (PASS)

Source: [`scenarios/skitarii-move-attack/control.lua`](experiments/skitarii-ci-mod/scenarios/skitarii-move-attack/control.lua).

Observed readbacks from successful run **#42165600370**:

| Check | Actual native log | Conclusion |
| --- | --- | --- |
| Prototype loaded and entity created | `spawned=warfare-skitarii-experiment` | PASS |
| Native unit command interface | `commandable=LuaCommandable` | PASS |
| Movement command | `move_issued_tick=0` using `defines.command.go_to_location` | Accepted |
| Real walk | `native_walk_tiles=4.887`, `walk_verified=true` | PASS |
| Native attack command | `attack_issued_tick=60` using `defines.command.attack` | Accepted |
| Genuine damage | `native_damage=3.000`, `native_attack_verified=true` | PASS |
| Scenario exit | `STATUS=PASS` and `script.finish_test(true)` | PASS |

The *direct native attack* is a small deliberately modified `AttackParameters.ammo_type` effect in the disposable Skitarii prototype. This first test **does not prove ammo reservation/consumption, weapon selection, simulated projectile travel or fire-control teleoperation**. It confirms genuine engine movement and native attack damage on an enemy-owned entity.

## 3. WAR-SKIT-002 — existing native gun proxy, actual firearm-magazine consumption (PASS)

Source: [`scenarios/skitarii-ammo-proxy/control.lua`](experiments/skitarii-ci-mod/scenarios/skitarii-ammo-proxy/control.lua).

The test creates an experimental Skitarii `unit`, places a **real native `tech-priest-small-arms-proxy` `ammo-turret`** next to it, and script-inserts exactly five existing `firearm-magazine` items into `defines.inventory.turret_ammo`. This scenario **does not invent or manually apply combat damage**. An enemy-owned chest is located **14 tiles away**: outside the clone's 12-tile direct attack range but inside the existing proxy's 15-tile native bullet range. The engine receives a real `proxy.shooting_target` entity.

Successful [run #42166015258](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42166015258) logged:

| Proof element | Native engine observation |
| --- | --- |
| Proxy active in engine | `proxy_active_native=true` |
| Bound infantry and proxy types | `warfare-skitarii-experiment`, `tech-priest-small-arms-proxy` |
| Real separation from soldier attack | `target_distance=14.000` |
| Physical ammo inserted | `initial_magazines=5`, `initial_loaded_rounds=10` |
| Before/after enemy health | `target_hp=100` and `native_damage=5.000` (target 95 HP) |
| After native firing | `magazines_now=5`, `loaded_rounds_now=9` |
| Outcome | `ammo_consumption_verified=true`; `proxy_damage_verified=true`; `STATUS=PASS` |

**This proves one bullet from a real native magazine was consumed by a real turret during an enemy damage event in a disposable test scenario.** The five magazines remaining is expected: a partially spent magazine still counts as a magazine until depleted. Count plus `LuaItemStack.ammo` must be tracked for actual remaining ammunition, especially in future combat logistics.

**It does not prove that the proxy follows a moving Skitarius**, persists across saves, respects exclusive unit ownership, properly clears its target, handles multiple simultaneous enemies or can be safely remotely teleoperated. Those are separate next-stage acceptance gates.

## 4. Real Factorio 2.1 API failure discovered and corrected in the isolated experiment

First ammo-proxy attempt, [run #42165836096](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42165836096), failed with:

```text
[WAR-AMMO] FAIL=runtime-exception: LuaEntity::active is read only.
[WAR-AMMO] STATUS=FAIL
```

The test was corrected by removing the illegal `proxy.active=true` assignment and **reading** `proxy.active` instead. The corrected run passed with the engine reporting `true`.

**Important main-code review item, not repaired by this branch:** [`tech-priests_src/scripts/core/proxy_turret_alignment.lua`](../tech-priests_src/scripts/core/proxy_turret_alignment.lua) contains a `pcall(function() proxy.active = true end)` attempt. Under Factorio 2.1 this write is invalid and the surrounding `pcall` can quietly hide the failure. A real proxy shown `active=true` does **not** require this assignment. Any actual production correction needs separate scope/test authorization, not a warfare-branch silent edit.

Additional known 2.1 consideration: `LuaEntity.shooting_target` cannot be set to `nil` via script. This experiment assigned a **live hostile target** and ended without attempting a release; safe target cancellation/cleanup still needs its own isolated controlled test and eventual owner policy. Do not reuse `pcall` as evidence of a successful target release.

## 5. Next safe, isolated warfare experiments

- **WAR-SKIT-003 — moving coupled entities**: compare real unit movement with proxy alignment, collision-free co-location, and explicit native ammo-state preservation. Keep movement and firing phases observable separately; do not adopt the priest worker's event ownership.
- **WAR-SKIT-004 — turret release and target death**: test what a native turret does after the target is destroyed/replaced or command authority expires. Reject lingering manual target locks; no `shooting_target=nil` attempt.
- **WAR-SKIT-005 — lifecycle and multiplayer-safe ownership**: verify destruction, force/surface changes and save/reload clear all test-only controlled assets and preserve physical ammunition, with exactly one owner.
- **WAR-SKIT-006 — teleoperation contract**: separate a remote camera, native unit move/attack commands, and actual direct operator controls; no claim of player possession until input, lease, and release behave correctly.
- **WAR-VEH-001** (later): AAI owns vehicle navigation. Do not touch AAI's internal commands until their public contract is independently validated.

No branch merge, Warfare release, original Blender model generation, Skitarii graphics replication or main-branch factory workflow change is authorized/claimed by these passing tests.

## 6. CI evidence and executable test sources

One [isolated Warfare CI workflow](../.github/workflows/warfare-readonly-investigation.yml) still runs **one job**, with the old read-only AAI/vehicle census followed by two separate temporary Skitarii gameplay test scenarios. It downloads the same 13 integrity-checked external Mod Portal archives and Factorio 2.1.24 engine. The existing main factory validation remains independent.

The test's disposable `warfare-skitarii-experiment` package is **never a release artifact**. Only sanitized text logs, source metadata observations and manifests are uploaded to GitHub Actions as `warfare-investigation-2.1-capabilities-and-skitarii`.

**Verdict:** Engineer-Skitarii sprite-based unit proof **PASS**. Independent native movement and marker damage **PASS**. Native hidden ammo turret consumes a real round and deals native bullet damage **PASS**. Full Warfare infantry, coupled motion + fire control, visual render parity, Skitarii model/rig/animation, multiplayer and remote possession remain **unimplemented / unverified**.
