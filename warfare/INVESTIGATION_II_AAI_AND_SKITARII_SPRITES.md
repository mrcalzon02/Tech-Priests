# Warfare investigation II — AAI command data and Skitarii sprite feasibility

**Status:** evidence-based, **read-only**, branch-only. **No Warfare gameplay behavior, new Skitarii, combat asset, art copy or weapon-control action implemented.**
**Branch:** `feature/warfare-module-planning`.
**Native evidence:** [run #42164556635](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164556635), [run #42164879426](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42164879426), both **PASS** (Factorio 2.1.24, the verified 13-external-mod unified pack). The latter recorded PNG header dimensions from the **authenticated installed archive** without extracting or sharing proprietary graphics.
**Tool:** [`tools/inspect_runtime_control_contracts.py`](tools/inspect_runtime_control_contracts.py). Result artifact `warfare-readonly-2.1-capabilities`, notably `warfare-control-and-skin-source-census.json`.

## 1. Discovery: Tech-Priests already consumes Mechanicus Reborn engineer images as a native `unit`

This is stronger than the earlier general assumption that a character retexture would have to be mapped into a commandable `unit` from scratch.

Existing checked-in [`tech-priests_src/prototypes/entity.lua`](../tech-priests_src/prototypes/entity.lua) defines:

- `MR_BASE_PATH = "__mechanicus-reborn__/images/"` and `MODEL_SCALE = 0.65` near file start.
- A native Factorio `unit` cloned from `compilatron` or `small-biter` with explicit `run_animation`, `attack_parameters`, and damage/death handling.
- `sprite()` uses `width=150`, `height=160`, `frame_count=22`, `direction_count=8` for the engineer sheets.
- `make_priest()` uses `level1_running.png` + `level1_running_shadow.png` and `level1_idle_gun.png` + `level1_idle_gun_shadow.png`.
- `make_priest_corpse()` references `level1_dead.png`, two frames, one direction.
- The visible priest has a deliberately low-damage native attack animation; its existing independent `tech-priest-small-arms-proxy` is a physical native ammo turret aligned to the priest, with a real ammo-based damage path.

The successful unified native smoke proves those sprite references **load as part of the existing modpack**. It does **not** prove new Skitarii infantry, independent teleoperation, mixed squads or alternate armaments are already functional.

**Decision:** The future Warfare Skitarii prototype can use this **existing dependency-only, no-asset-copy** engineer skin reference pattern for early experiments, then replace it with an original Skitarii model/rig/render pack. Do **not** modify existing worker/priests or reuse their ownership queues as military AI. The current branch remains planning and read-only investigation only.

## 2. Mechanicus Reborn 0.0.3 installed graphics — actual PNG header measurements

The archive contains **14 PNGs** and two Lua files. Its filenames do not say `character` or `engineer`; that explains why the first keyword-only filename search returned zero despite the images being present.

All image paths below are **relative names in the installed mod ZIP**, not files added to Tech-Priests. No image bytes were committed.

| Existing resource | Verified overall PNG resolution | 150 × 160 cell interpretation |
| --- | --- | --- |
| `level1_idle.png` | 3300 × 1280 | 22 columns × 8 rows |
| `level1_idle_shadow.png` | 3300 × 1280 | 22 × 8 |
| `level1_idle_mask.png` | 3300 × 1280 | 22 × 8 |
| `level1_idle_gun.png` | 3300 × 1280 | 22 × 8 |
| `level1_idle_gun_shadow.png` | 3300 × 1280 | 22 × 8 |
| `level1_running.png` | 3300 × 1280 | 22 × 8 |
| `level1_running_shadow.png` | 3300 × 1280 | 22 × 8 |
| `level1_running_gun.png` | 3300 × 2880 | 22 × 18 |
| `level1_running_gun_shadow_1.png` | 3300 × 2880 | 22 × 18 |
| `level1_running_gun_shadow_2.png` | 3300 × 2880 | 22 × 18 |
| `level1_mining_tool.png` | 3300 × 1280 | 22 × 8 |
| `level1_mining_shadow.png` | 3300 × 1280 | 22 × 8 |
| `level1_dead.png` | 300 × 160 | 2 × 1 |
| `thumbnail.png` | 144 × 144 | not an animation |

The **cell interpretations are arithmetic consistent with current Tech-Priests `150×160` sprite declarations**; the PNG header alone does **not** determine animation speeds, masks, per-frame origins or which rows are legally usable in a new `unit`. The current engineer data stage references the moving, aiming and mining PNG paths; ordinary Skitarii infantry does not need mining behavior.

**Important asymmetry:** `level1_running_gun.png` and both corresponding shadow files have **18 rows**, whereas the existing Tech-Priest combat `unit` path chooses the **8-row `level1_idle_gun`** animation. Do not treat an 18-direction sheet as if it were 8-direction or silently crop it; future infantry needs an explicit rendering policy. The 8-row running and weapon-ready sheets already provide a simpler provisional visual path.

### Original Blender model target (later, not started)

- Match the temporary **150×160 cell envelope** and Factorio game-camera framing *for silhouette comparison*, not necessarily as an immutable final output size.
- Export a **directional run/idle/aim-fire** animation set with real consistent frames, shadows and origin shifts. Start from eight directions to align with existing `UnitPrototype.run_animation`; add more directions only if justified by the final animation and prototype contract.
- Build a new **Skitarii-specific** visible silhouette with appropriate armor, rifle, respiratory hood, optics and augmentations; do not present the borrowed engineer as the final custom model.
- Rig torso, shoulders/weapon grip, legs, head, backpack and cloth/mechanical pieces so rifle recoil, movement and death remain consistent in every render direction.
- Preserve alignment through movement and gun elevation; validate rendered sheets against native Factorio readability, origin positions, selection boxes, shadow footprints, and weapon muzzle timing.
- Do not spend geometry on unseen internals or undersides; use the [Red Tech-Priests modeling doctrine](../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) where it applies.
- Replace dependency-based art only when the independent original 3D model, rig, animations and native combat test are approved and verified.

**Asset and permissions:** The Mod Portal lists Mechanicus Reborn's package license as MIT, but it is a fork of the earlier Mechanicus project. Do not assert that all upstream artist assets are separately relicensable from that portal label alone. Continue the existing **runtime dependency-reference** approach for the temporary skin; no artwork redistribution or hidden model extraction.

## 3. Actual AAI 0.9.2 function definitions — source metadata, not contract certification

Static scan of the authenticated AAI 0.9.2 archive identified the following *implementation declarations*; the scanning tool retained file paths, line numbers, parameter names and nearby **key identifiers only**, not copied Lua bodies.

| Registered remote method / delegate | Native source declaration | Preliminary observed fields / invocation shape |
| --- | --- | --- |
| `set_unit_command` → `unit_set_command(data)` | `control.lua:2484` | `unit_id`, `target_position`, `target_position_direct`, `target_speed`, `target_angle`, `path_id`, `waypoint_id`, following-target options |
| `set_unit_data` → `unit_set_data(data)` | `control.lua:597` | `unit_id`; extended mutation semantics **unknown** |
| `get_unit_by_entity` → `unit_find_from_entity(entity)` | `control.lua:545` | **One entity reference** at the delegate level; internal structures and result shape **unverified** |
| `get_unit_by_signal` → `unit_find_from_signal(data)` | `control.lua:572` | `unit_id`, `surface_index`, `signal`, `signal_count` nearby |
| `set_path_waypoint` → `Path.set_path_waypoint_data(data)` | `scripts/path.lua:469` | `force_name`, `surface_index`, `path_id`, `waypoint_id`, `position_x`, `position_y`, `speed_limit`, `allow_pathfinding`, `direct_drive_through`, `goto_unit_id`, `goto_player_id`, `vehicle_depot_id` and position-beacon ID |

**Important limitation:** A bounded 100-line lexical scan can include nested/following scopes and does **not** establish which fields are mandatory, the enum values, the return types, the side effects or the authority boundary. Never submit the table above as a verified example `remote.call()` invocation. The next investigation should focus on control order precedence, data validation and native readback **without making a mutating remote call**.

## 4. Concrete next research / engineering gates

1. **AAI ownership documentation:** trace `unit_set_command` and waypoint validation/return paths, record supported command discriminator values, unit ID lifecycle and error exits from static code without revealing source bodies.
2. **Skitarii placeholder visual proof:** retain `MR_BASE_PATH` and native eight-way run/shoot animation as a reference. Future branch-only new `unit` is a separate *implementation* decision and requires explicit authorization; no new infantry asset is created here.
3. **Skitarii control contract:** use `LuaCommandable` for a native `unit` and establish one effective controller; do not misuse `LuaPlayer.set_controller(remote)` as possession.
4. **Network cannon targeting:** document valid turret target designation and safe release after target destruction; existing `shooting_target=nil` under `pcall` is not a reliable reset proof.
5. **Art replacement readiness:** preserve original-model Blender workstream and directional sheet parity, with no upstream art files bundled.
6. **Tests:** continue the **single branch-only read-only native job**. Active factory CI and resource issue #11 remain separate; this document and probe do not gate factory release.

## Sources

- [Native Factorio 2.1.24 control evidence, first audit](READONLY_NATIVE_INTERFACE_FINDINGS.md)
- [Existing `entity.lua` Mechanicus image adapter](../tech-priests_src/prototypes/entity.lua)
- [Existing hidden turret alignment and fire owner](../tech-priests_src/scripts/core/proxy_turret_alignment.lua)
- [Mechanicus Reborn 0.0.3 Mod Portal](https://mods.factorio.com/mod/mechanicus-reborn)
- [Factorio `CharacterPrototype`](https://lua-api.factorio.com/latest/prototypes/CharacterPrototype.html)
- [Factorio `UnitPrototype`](https://lua-api.factorio.com/latest/prototypes/UnitPrototype.html)
- [Factorio `LuaCommandable`](https://lua-api.factorio.com/latest/classes/LuaCommandable.html)
- [Factorio `LuaRemote`](https://lua-api.factorio.com/latest/classes/LuaRemote.html)
