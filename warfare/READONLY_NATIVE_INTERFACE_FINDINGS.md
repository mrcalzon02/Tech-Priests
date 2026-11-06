# Warfare investigation I — native 2.1.24 AAI interfaces and combat prototypes

**Actual read-only engine test:** [run #42161867582](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42161867582) **PASS**, [extended source-signature inspection run #42162178961](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42162178961) **PASS**.
**Evidence artifacts:** both GitHub Actions runs publish `warfare-readonly-2.1-capabilities`, including `native-capabilities.json` and real Factorio log; second also includes `aai-static-interface-inventory.json`. No vendor source code copied to GitHub or included in artifacts.
**Isolation:** `feature/warfare-module-planning` only. No combat assets constructed, no AAI commands invoked, no projectile or turret targets changed, and no player controllers modified.
**Engine:** Factorio 2.1.24 with all 13 external mod ZIPs installed and integrity-checked, including AAI Programmable Vehicles 0.9.2, KJ core 2.2.1, each KJ 40K vehicle 2.1.0, Tanks for Bob 1.8.95 (runner-only Factorio 2.1 metadata bridge).

## Verified runtime discovery: `remote.interfaces`

**Five** interfaces are registered by the combined modpack:

| Interface | Confirmed |
| --- | --- |
| `aai-programmable-vehicles` | Yes — the only AAI vehicle-control interface name registered |
| `informatron` | Yes |
| `mechanicist-factorio` | Yes |
| `mechanicist-quality` | Yes |
| `mechanicist-space-age` | Yes |

The 13 AAI interface function names **as read by the engine itself**:

```text
get_surface_paths
get_unit_by_entity
get_unit_by_signal
get_unit_count_by_type
get_units
informatron_menu
informatron_page_content
on_entity_deployed
set_path_waypoint
set_unit_command
set_unit_data
write_global
write_unit
```

**Consequence:** A future Warfare adapter can potentially use the existing `aai-programmable-vehicles` interface. The runtime API proves the functions **exist**, not their argument contracts, safety, or permission for external mod callers. Zero `remote.call()` invocations were made. Do not call `write_global` or `write_unit` from Warfare without understanding the AAI code and save-state invariants: these sound like internal mutation/maintenance endpoints.

## Read-only inspection of the original authenticated AAI 0.9.2 archive

The CI scanned the actual SHA-1-verified archive **in memory** and produced **function identifiers, candidate parameter names and file/line locations only**. These source facts were observed:

| Registered function | Entry in original AAI archive | Signature/delegate read, not execution proof |
| --- | --- | --- |
| `get_units` | `scripts/remote.lua:11` | Zero-argument function |
| `get_unit_count_by_type` | `scripts/remote.lua:12` | Function taking `data` |
| `get_unit_by_signal` | `scripts/remote.lua:18` | Delegates to `unit_find_from_signal` |
| `get_unit_by_entity` | `scripts/remote.lua:19` | Delegates to `unit_find_from_entity` |
| `on_entity_deployed` | `scripts/remote.lua:20` | Delegates to `on_entity_deployed` (definition `control.lua:3604(data)`) |
| `set_unit_command` | `scripts/remote.lua:26` | Delegates to `unit_set_command` |
| `set_unit_data` | `scripts/remote.lua:27` | Delegates to `unit_set_data` |
| `set_path_waypoint` | `scripts/remote.lua:28` | Delegates to `Path.set_path_waypoint_data` |
| `get_surface_paths` | `scripts/remote.lua:29` | Function taking `data`; separate implementation `scripts/path.lua:69(force_name,surface_index)` |
| `write_global` | `scripts/remote.lua:6` | Zero-argument function; **do not call** |
| `write_unit` | `scripts/remote.lua:7` | Function taking `data`; **do not call** |

Other `remote.add_interface` call sites were located in the original `control.lua:96,100,104,108,112` and `scripts/remote.lua:3`. These are **source locations**, not a reproduction of its source or confirmation that every function is intended as a public integration API.

**Immediate next investigation:** identify signatures and supported `data` fields for `unit_set_command`, `unit_set_data`, `Path.set_path_waypoint_data`, `unit_find_from_entity` and `unit_find_from_signal` through read-only analysis. Do not issue a command or mutate AAI storage yet.

## Vehicle model: distinct hull, gun-specific modes, navigator and shadow elements

Engine enumerated **169 selected car/AI candidate prototypes**, of which **38 are `unit`-type navigator candidates** (this is a filtered census, not a total installed entity count).

All four original 40K cars expose **two native gun slots**. AAI generated **two gun-specific car configurations per hull**, each with an additional `-_-navigator` (`unit`), `-_-solid` (`car`) and `-_-ghost` (`car`) variant. For example:

```text
kj_40kpredator                            car, guns: kj_predator + kj_predator_bolter
kj_40kpredator-kj_predator                car, gun: kj_predator
kj_40kpredator-kj_predator-_-navigator    unit (range 0.5)
kj_40kpredator-kj_predator-_-solid        car, gun: kj_predator
kj_40kpredator-kj_predator-_-ghost        car, gun: kj_predator
kj_40kpredator-kj_predator_bolter         car, gun: kj_predator_bolter
... corresponding bolter navigator/solid/ghost variants ...
```

The vehicle weapon inventory and **prototype attack range** observations:

| Original 40K vehicle | Native source guns | Gun-specific AAI configuration ranges |
| --- | --- | --- |
| `kj_40kbaneblade` | `kj_baneblade`, `kj_baneblade_bolter` | Main 35 tiles, bolter 25 tiles |
| `kj_40kpredator` | `kj_predator`, `kj_predator_bolter` | Main 35 tiles, bolter 25 tiles |
| `kj_40klemanruss` | `kj_lemanruss`, `kj_lemanruss_bolter` | Main 45 tiles, bolter 25 tiles |
| `kj_40kdreadnought` | `kj_dreadnought_cannon`, `kj_bolter` | Cannon 35 tiles, bolter 25 tiles |

**Vanilla `tank`** has guns `tank-cannon`, `tank-flamethrower`, `tank-machine-gun`. Its AI gun-specific car configs are `tank-tank-cannon` (range 30), `tank-tank-flamethrower` (range 9), `tank-tank-machine-gun` (range 20), with companion navigator units. **Vanilla Spidertron** has four indexed rocket-launcher gun slots; AAI's data-stage valid-gun criteria are separate from that slot count. Do not treat four source guns as four autonomous AI firing channels.

**Important inference boundary:** AAI's `navigator` is a Factorio `unit` and the other three registered elements are `car` prototypes, but this read-only census does not prove which live entities AAI spawns/attaches during actual navigation. That must be tested **later in an isolated, explicit movement experiment**. Do not infer direct possession, simultaneous fire, or valid control of all four elements merely from their prototypes.

## Existing vanilla turret prototype audit

Engine read the following native `attack_parameters.range` from prototypes, not actual combat tests:

| Target | Native type | Prototype range (tiles) |
| --- | --- | ---: |
| Gun turret | `ammo-turret` | 18 |
| Laser turret | `electric-turret` | 24 |
| Flamethrower turret | `fluid-turret` | 30 |
| Artillery turret | `artillery-turret` | 224 |
| Tech-Priests existing small-arms proxy | `ammo-turret` | 15 |

These support initial W0/W1 doctrinal comparison of fixed defenders. **They do not establish effective target acquisition, physical turret rotation, ammo consumption, available power or actual combat DPS**. Final values may vary with research/quality, prototype upgrades, attack constraints or target conditions.

## Safe API boundaries for the future teleoperation investigation

- Official Factorio 2.1.24 [`LuaRemote.interfaces`](https://lua-api.factorio.com/latest/classes/LuaRemote.html) maps interface/function names to `true`; names alone do not define accepted arguments. Any AAI `set_unit_command` call **mutates AI state**, so it is excluded from this phase.
- [`LuaEntityPrototype.indexed_guns`](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html) is a vector of gun prototypes for cars/spiders. It is **not** an interface for simultaneously firing them.
- [`LuaCommandable`](https://lua-api.factorio.com/latest/classes/LuaCommandable.html) represents native unit/spider-unit/group commandability; the original car itself is a different entity class. AAI's observed navigator/solid/ghost derivatives are a strong reason to keep one carefully owned command bridge.
- [`LuaPlayer.set_controller`](https://lua-api.factorio.com/latest/classes/LuaPlayer.html) and `centered_on` provide camera/remote-view capabilities; remote viewing is **not** the same as Skitarii movement or bunker weapon input.
- [`LuaEntity.shooting_target`](https://lua-api.factorio.com/latest/classes/LuaEntity.html) for native turrets **cannot be set to `nil` via script**. Any future remote bunker targeting lease must prove a genuine release/fallback method. Current Tech-Priests proxy code contains an attempted `shooting_target=nil` under `pcall`; it is a candidate for a future separate compatibility test, not something altered during this read-only investigation.
- AAI's original changelog [0.6.2](https://mods.factorio.com/mod/aai-programmable-vehicles/changelog) explicitly documents preserving original multi-gun vehicles while creating one AI type per weapon. Current 0.9.2 extends to Factorio 2.1.24, but no actual switching test has been run.

## Investigative next steps (not gameplay implementation permission)

1. Resolve safe input fields for AAI's discovered `set_unit_command`, `get_unit_by_entity`, `set_path_waypoint` from the **installed** implementation without copying source or invoking mutations.
2. Design a branch-only **non-destructive observation of live AAI unit identity** (spawn/test assets only after separately authorizing controlled experiments), comparing car/navigator/solid/ghost lifetimes and command ownership.
3. Inspect native turret target priority and selection/reset surfaces before any player remote-aim experiment, especially safe release when target dies.
4. Compare Factorio's remote camera and player controller lifecycle against planned Skitarii and bunker operator leases, including multiplayer/latency and genuine network power/circuit authority.
5. Preserve the existing factory/resource/defense dispatchers, keep Skitarii and bunker as **unbuilt conceptual assets**, and do not create warfare runtime installers on `main`.

**Verdict:** Native control **discovery successful**. **No combat, remote-driving, multiweapon, or Skitarii/bunker gameplay behavior proven**; this phase's pass is a *read-only census pass* only.
