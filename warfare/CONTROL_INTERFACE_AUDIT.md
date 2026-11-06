# Warfare — native control, entity and weapon interface audit

**Status:** read-only interface investigation. **No gameplay implementation authorized.** The first two headless probes have now passed; [see real native findings](READONLY_NATIVE_INTERFACE_FINDINGS.md).
**Branch:** `feature/warfare-module-planning`, forked from main commit `55ce75a2aca2e65902af2c86e88da3818f6fa2d1`.
**Native evidence:** [Passing combined Factorio 2.1.24 run #42151378921](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921), artifact `combined-modpack-2.1-evidence`, specifically `factorio-create.log`. The native save-load benchmark did not exercise battle commands.
**Installed:** AAI Programmable Vehicles **0.9.2**, `kj_vehicles` **2.2.1**, `kj_40kbaneblade`, `kj_40kpredator`, `kj_40klemanruss`, `kj_40kdreadnought` all **2.1.0**, plus Tanks for Bob **1.8.95** (temporary 2.1 metadata bridge), and vanilla/Space Age/Quality content.

## 1. Observed AAI vehicle conversion behavior — actual engine log evidence

AAI's published description states that AI car-type vehicles:
- May be selected and commanded through its **Unit Remote Controller** (RTS-style group selection);
- May follow **Path Remote Controller** waypoints and circuit / zone control;
- Use **biter-type AI movement** when ordered via its unit/XY controllers;
- Defend autonomously with their fitted weapon when unmanned; and
- Are deliberately **limited to one weapon type** in their AI-unit configuration.

These are documented AAI features, not proof of every modded vehicle completing a mission. Source: [AAI Programmable Vehicles](https://mods.factorio.com/mod/aai-programmable-vehicles).

### Native prototype-creation evidence (2026-11-06 UTC)

The combined headless `factorio-create.log` shows calls from `__aai-programmable-vehicles__/prototypes/ai-vehicles.lua`, including `aai_make_ai_vehicles: <vehicle> valid guns: N` and separate `aai_make_ai_vehicles ai version: <vehicle> with <gun>` records:

| Vehicle / source ID | Source car valid guns | AAI gun-specific AI variants observed |
| --- | ---: | --- |
| `tank` | 3 | `tank-cannon`, `tank-flamethrower`, `tank-machine-gun` |
| `car` | 1 | `vehicle-machine-gun` |
| `kj_40kbaneblade` | 2 | `kj_baneblade`, `kj_baneblade_bolter` |
| `kj_40kpredator` | 2 | `kj_predator`, `kj_predator_bolter` |
| `kj_40klemanruss` | 2 | `kj_lemanruss`, `kj_lemanruss_bolter` |
| `kj_40kdreadnought` | 2 | `kj_dreadnought_cannon`, `kj_bolter` |
| `spidertron` | 1 valid | AAI logs four raw launcher names but **one** valid gun/AI version `spidertron-rocket-launcher-1`; do not equate gun listing with four simultaneous AI guns |

**Interpretation:** AAI creates **distinct single-weapon AI conversions** of multi-weapon car prototypes. This is stronger evidence than the original assumption that all AI vehicles simply *lose* their extra guns. It does **not** show which gun is selected by default, whether selecting another AI variant preserves equipment/cargo/ammo/quality, or whether switching can happen mid-combat. Do not manufacture a multi-weapon conclusion.

**Known separate warnings:** `kj_vehicles/data-final-fixes.lua:775` says `Turret not found` when attempting health/resistance matching for four KJ vehicle families. Loading and 123k ticks passed anyway. Investigate during the eventual combat-validation phase; the warning must not be silently treated as a verified functioning turret.

### Factorio engine distinction: original car versus AI unit

- [CarPrototype.guns](https://lua-api.factorio.com/latest/prototypes/CarPrototype.html) permits an **array of GunPrototype IDs**. Car multi-gun capacity is real at prototype level.
- [LuaEntityPrototype.indexed_guns](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html) exposes current engine gun slots; [LuaEntity.selected_gun_index](https://lua-api.factorio.com/latest/classes/LuaEntity.html) selects the current car/character/spider gun when applicable. **Gun selection is not concurrent multi-gun firing.**
- [UnitPrototype.attack_parameters](https://lua-api.factorio.com/latest/prototypes/UnitPrototype.html) exposes one primary attack-parameters object. [LuaCommandable](https://lua-api.factorio.com/latest/classes/LuaCommandable.html) applies to units, spider units and groups. **Cars are not automatically `commandable`** just because `LuaEntity` exposes the optional field. Do not call `car.commandable:set_command` without a proven non-nil commandable.
- [`LuaEntity.get_driver/set_driver`](https://lua-api.factorio.com/latest/classes/LuaEntity.html), `riding_state`, `shooting_state`, `selected_gun_index`, and `get_inventory` are native capabilities with differing entity-type restrictions. Never assume a `unit` accepts `set_driver` or that a car accepts a unit attack command.
- **Actual read-only engine investigation now confirms** `remote.interfaces['aai-programmable-vehicles']` with 13 registered function names, including `set_unit_command`, `set_unit_data`, `set_path_waypoint` and read/query functions. [See verified enumeration and source declaration sites](READONLY_NATIVE_INTERFACE_FINDINGS.md). This confirms **names, not safe argument contracts or allowed usage**. No `remote.call` is authorized until further non-mutating semantic analysis.

### Critical hypothesis to test later: why one weapon?

1. **Confirmed observation:** AAI creates one AI variant per accepted gun on multi-gun cars.
2. **Plausible technical constraint:** AAI uses a `unit`-like biter movement/attack abstraction with one attack definition; native `UnitPrototype` has one `attack_parameters` object. This may explain the design, but the underlying AAI source and conversion implementation have **not** been read; do not claim causation as proven.
3. **Alternative explanation:** An intentional specialization rule that simplifies AI target selection and ammo behavior, explicitly stated on the AAI mod page, may also explain the choice.
4. **Conclusion:** Treat one-weapon AI modes as contractual **until tests establish otherwise**. Do not override AAI's source, reinterpret its license or fabricate simultaneous fires.

### Design alternatives to assess in a future **isolated** gameplay test (none implemented)

| Candidate | How it might work | Risk / feasibility test |
| --- | --- | --- |
| A. **Preserve AAI single-weapon variants** (default) | Assign separate tank units by main weapon / secondary gun role, coordinate squads instead of firing two guns at once | Least invasive; verify correct ammo, spawned AI item, conversion and health/cargo persistence |
| B. **Switch eligible AI weapon configuration** | Order AAI mode change when an installed supported switching interface exists | Must inspect actual API and prove complete inventory/equipment/force/quality custody across mode change; cannot assume it exists |
| C. **Composite native fire components** | Use a vehicle with separately owned native turret entities under a single visible hull; primary AAI AI controls movement only | Significant identity, collision, target/rotation, ammo, lifetime, multiplayer, save/reload and disposal risks; may duplicate Tech-Priests proxy architecture; defer |
| D. **Vanilla multi-gun player/vehicle control** | Leave car prototype intact; human manually changes selected gun in existing game controls | No automatic concurrent secondary fire; accepted as distinct from AI mode |

**No recommendation to modify AAI itself** in this planning branch. Begin future combat testing with A.

## 2. Existing Tech-Priests control and combat architecture — avoid duplicate owners

`tech-priests_src/prototypes/entity.lua` creates a visible commandable **`unit`** using `attack_parameters` that deal almost no damage; the real ranged damage goes through the hidden `tech-priest-small-arms-proxy` native **ammo turret** with physical ammunition. Source around lines 496–580. `scripts/core/proxy_turret_alignment.lua` aligns the proxy to its owner and assigns a native hostile `shooting_target` through the current broker rather than creating custom projectiles.

**Important 2.1 API observation:** [LuaEntity.shooting_target](https://lua-api.factorio.com/latest/classes/LuaEntity.html) for turrets **cannot be set to nil through the public scripting API**. The current `proxy_turret_alignment.lua` around line 168 attempts `proxy.shooting_target = nil` inside `pcall`; this is a **known potential stale-target cleanup failure** that must be tested independently before recycling the approach for a remote gun. No correction to the active main-branch combat code is authorized here.

Existing relevant owners:
- `scripts/core/runtime_event_registry.lua` / `runtime_tick_broker.lua`: event and bounded-tick ownership;
- `scripts/core/single_dispatcher_0510.lua` and `action_state_arbiter_0488.lua`: exclusive material/work execution;
- `scripts/core/movement_controller.lua`, `behavior_mutex_0466.lua`, `command_hierarchy_0480.lua`: priest movement and action arbitration;
- `scripts/core/combat_safety.lua`, `combat_defense_reaction_0816.lua`, `defense_layer_audit_1091.lua`, `defense_perimeter.lua`: existing defensive sensing, target validation, turret readiness and construction;
- `scripts/core/item_family_logistics_0702.lua`, `fluid_turret_readiness_0716.lua`, `energy_family_logistics_0707.lua`: real turret ammo, fuel/fluid and power support.

**Boundary:** Future Warfare owns missions and combat-unit control **only**. It may submit physical supply/build requests to original owners and observe real receipts. It **must never register a parallel main-branch `script.on_event` handler or tick loop** or write the existing priest/robot movement state directly.

## 3. Remote / teleoperation interfaces — separate three modes

1. **Observation:** [LuaPlayer.set_controller](https://lua-api.factorio.com/latest/classes/LuaPlayer.html) can enter `defines.controllers.remote`, set surface/position, and `LuaPlayer.centered_on` can show an entity. This is a **camera/remote-view interface**, *not* remote steering or gunnery.
2. **Command designation:** AAI Unit Remote Controller, paths, XY commands, circuit zones. These are **high-level missions**, not continuous teleoperation or possession.
3. **Direct teleoperation:** still requires a validated input-to-actuator bridge. For cars, there are native `riding_state` and weapon-selection/shooting facilities, but the vehicle/driver control model and AAI AI ownership must be resolved. For **Skitarii (unit)**, `LuaCommandable` handles movement orders but **does not make it a remotely driven character**. For **bunkers (turrets)**, direct target designation is possible for an entity target, but arbitrary mouse-point firing and target-release are **not proven**.

**Non-negotiable future teleoperation invariants:** explicit player opt-in; same-force/approved-control rights; live entity, surface and lease readback; one effective controller; no simultaneous command conflict; bounded heartbeat/timeout; safe return to native AI on cancel, disconnect, death, power/network loss, damage, mod configuration change or save/reload; preserve a physical operator/character rather than destroying or teleporting it. Multiplayer contention resolution must be deterministic.

## 4. Ordering to inspect before implementing anything

Two kinds of order are distinct:

- **Prototype / mod-data order:** base, Quality/Space Age/KJ, AAI's data-stage creation of AI derivatives and any future Tech-Priests warfare prototype compatibility. New warfare prototypes must be registered only after their donors/dependencies exist, using explicit `info.json` load-order constraints where needed. Current Tech-Priests `info.json` is shipping **2.0** metadata and the unified 2.1 smoke stages a temporary metadata shim; do not use that diagnostic bridge as publishing evidence.
- **Runtime control priority:** player/manual lease → safety emergency/forced disengage → approved Warfare task owner → AAI/engine autonomous order → passive vanilla defense. Priorities are a **proposal**, not working code. No hidden second steering writer; preserve previous native AAI state only if its public interface permits readback.

Entities, gun slots and target references must be read by native `name` / `unit_number` / force / surface / indexed guns and actual item ammo category, not sorted localization labels or guessed prefix conventions.

## 5. Open evidence blockers (future test designs, NOT branch failures now)

- **Observed:** installed AAI 0.9.2 exposes the `aai-programmable-vehicles` interface and 13 function names ([native run #42162178961](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42162178961)); **still unknown:** exact delegate argument/data-field contracts and safe operational semantics.
- Exact **generated AI entity and item IDs** for each weapon configuration (the log records source car and gun, but not reliably the derivative prototype name).
- Whether AAI can switch mode mid-mission without replacing an entity; whether players can take/release manual control and restore AAI orders.
- Per-weapon target policy, range, ammo category, initial ammo, quality, projectile effects, turret orientation, multi-target acquisition and firing cooldown.
- What happens when the remote operator leaves, is disconnected, loses power/command coverage, or the controlled entity dies; cross-surface restrictions.
- What is meant by **AA** in future feature scope: AAI control/teleoperation versus separate anti-air emplacements. Preserve both as separate terminology until specified.
- Multiplayer/simultaneous-operator arbitration, save/reload, and performance across 200+ battle entities.
- Native air-target discrimination: Factorio and installed mods may not supply a consistent `airborne` classification. Do not promise true anti-air targeting without concrete projectile/target support.

## References

- [AAI Programmable Vehicles official description and license](https://mods.factorio.com/mod/aai-programmable-vehicles)
- [AAI Programmable Vehicles changelog 0.9.2](https://mods.factorio.com/mod/aai-programmable-vehicles/changelog)
- [LuaCommandable](https://lua-api.factorio.com/latest/classes/LuaCommandable.html)
- [LuaEntity](https://lua-api.factorio.com/latest/classes/LuaEntity.html)
- [LuaPlayer](https://lua-api.factorio.com/latest/classes/LuaPlayer.html)
- [LuaEntityPrototype](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html)
- [UnitPrototype](https://lua-api.factorio.com/latest/prototypes/UnitPrototype.html)
- [CarPrototype](https://lua-api.factorio.com/latest/prototypes/CarPrototype.html)
- [AmmoTurretPrototype](https://lua-api.factorio.com/latest/prototypes/AmmoTurretPrototype.html)
- [LuaRemote](https://lua-api.factorio.com/latest/classes/LuaRemote.html)
- [Existing Tech-Priests proxy turret implementation](../tech-priests_src/scripts/core/proxy_turret_alignment.lua)
- [Current native engine authority rules](../docs/FACTORIO_NATIVE_ENGINE_AUTHORITY.md)
