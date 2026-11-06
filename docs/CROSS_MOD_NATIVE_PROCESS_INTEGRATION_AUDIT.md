# Cross-mod native-process integration audit — unified Tech-Priests modpack

**Assessment:** 2026-11-05 local / 2026-11-06 UTC. **Status:** implementation requirements and test plan, **not proof** that every gameplay operation is integrated.
**Reference smoke:** [Unified Factorio 2.1.24 PASS, run #42151378921](https://github.com/mrcalzon02/Tech-Priests/actions/runs/42151378921). One job; 123,000 benchmark ticks plus a 1,200-tick separate-process reload of the created save.
**Core engineering standard:** [Factorio native engine authority](FACTORIO_NATIVE_ENGINE_AUTHORITY.md): the game owns inventories, equipment, machines, positions, power, fluid, research, robots, trains and real receipts. Tech-Priests plans and coordinates them. No synthetic supplies, assumed connections, or bypass of existing custody and dispatch authority.

## 1. Exactly which mods are in scope

The [2.1 required contract](../tests/modpacks/required_21_1271.json) names nine primary dependencies:

- `mechanicist-factorio` **0.1.3** — in-place localization / lore retheme.
- `tanks_for_bob_fork` **1.8.95** — new tank/ammunition and island-survival production/research chains. **Published archive is Factorio 2.0**; 2.1 smoke uses an explicitly marked, disposable metadata bridge; a real 2.1 release is **not** proven.
- `mechanicus-reborn` **0.0.3** — character / armor appearance customization, not a second workforce.
- `aai-programmable-vehicles` **0.9.2** — autonomous vehicle orders, navigation and circuit/zones.
- `kj_40kbaneblade`, `kj_40kpredator`, `kj_40klemanruss`, `kj_40kdreadnought` — each **2.1.0**, vehicle families and equipment/ammunition.
- `kj_servoskull` **2.1.0** — skins for existing construction/logistic robot types.

Required transitive installed mods: `aai-signals` **0.8.0**, `informatron` **0.5.0**, `kj_fuel` **2.1.1**, `kj_vehicles` **2.2.1**. Native modules enabled in the unified 2.1 job: `base`, `elevated-rails`, `quality`, `recycler`, `space-age`.

**Excluded by explicit decision:** `40kvehicles-AAI-fix` is a retired, nonblocking Factorio 1.1-era workaround. Retiring it is **not** proof that all AAI vehicle orders work. `factoryplanner`, `boblogistics`, optional AAI expansion mods and companion drones are **not in the verified 2.1 pack**; do not silently claim them integrated.

## 2. Where native mod behavior already exists — do not duplicate

| Dependency/process | Verified source behavior | Tech-Priests integration responsibility |
| --- | --- | --- |
| Mechanicist 0.1.3 | [data-updates.lua](https://github.com/mrcalzon02/mechanicist-factorio/blob/main/mechanicist-factorio_0.1.3/data-updates.lua) changes `localised_name` / `localised_description`, **not internal IDs**; [control.lua](https://github.com/mrcalzon02/mechanicist-factorio/blob/main/mechanicist-factorio_0.1.3/control.lua) handles its own GUI/optional Informatron | Resolve `prototypes.*[internal_name]`, runtime `LuaEntity.name`, and `LuaRecipe.name`; avoid parsing displayed labels; verify labels resolve when both rethemes enabled |
| Mechanicus Reborn 0.0.3 | [Mod Portal](https://mods.factorio.com/mod/mechanicus-reborn) describes player/armor skin and settings | No new Tech-Priests actor, move controller, robot network or research model. Validate player/armor coexistence only where relevant |
| Servo-Skull 2.1.0 | [Mod Portal](https://mods.factorio.com/mod/kj_servoskull) explicitly swaps *construction/logistic robot skins* | Reuse Factorio `LuaLogisticNetwork`, `LuaLogisticCell`, native robot counts, actual `on_robot_built_entity`; don't create fictional "skull" resource or simulate deliveries |
| AAI Programmable Vehicles 0.9.2 | [Mod Portal](https://mods.factorio.com/mod/aai-programmable-vehicles) owns RTS vehicle navigation/commands; supports modded car-type vehicles | AAI owns its vehicle AI; Tech-Priests may monitor, provision and request support through **only inspected/documented** interfaces, not write a parallel car controller |
| AAI Signals 0.8.0 | [Mod Portal](https://mods.factorio.com/mod/aai-signals) adds circuit virtual signals (position, health, speed, enemy, etc.) | Do not assume a signal's exact prototype name or connect wires without genuine native signal/connector discovery. Optional read-only circuit telemetry phase |
| KJ vehicle family + `kj_vehicles` | Vehicle prototypes, mounted guns, ammo, fuel and KJ 2.1 shared adaptation; AAI/KJ generated AI derivatives were observed in native 2.1 logs | Discover real car inventories, actual gun/ammo prototypes, fuel categories and equipment grids; handle physical supply in canonical logistics only |
| `kj_fuel` | Transitive fuel prototype dependency | Recognize **real fuel-category compatibility** and available burned-result custody; do not assume vanilla fuel-name allowlist |
| Tanks for Bob 1.8.95 | [Source](https://github.com/mrcalzon02/Tanks-for-bob-Fork/tree/main/tanks_for_bob_fork_1.8.95/prototypes) adds specialized categories, machine entities, food, steam, ammunition, research/recipe chains | Treat those as real Factorio prototypes and machine obligations, not free items or an unrelated minigame |
| Informatron 0.5.0 | Transitive AAI documentation/UI dependency | No production/AI integration needed. Optional player help panel only after inspecting its documented remote interface |
| Factory Planner | Optional, not installed in reference pack | Tech-Priests must not depend on private planner state, require it, or copy its solver without specific authorization |

## 3. Actual Tech-Priests ownership and gaps (ranked)

### P0-A — Specialty machine and recipe discovery — **real gap**

Current [`scripts/core/logistics_machine_fulfillment_0528.lua`](../tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua) restricts its candidate scan to `assembling-machine`, `furnace`, `mining-drill`, `container` and `logistic-container` (lines 26–32, 727ff). Its `get_recipe()` and ingredient enumeration are good starting points, but raw `defines.inventory.assembling_machine_input` and `furnace_source` lookups (lines 167–178) bypass the existing [`native_crafter_inventory_1277.lua`](../tech-priests_src/scripts/core/native_crafter_inventory_1277.lua) adapter for 2.0/2.1. It currently excludes fluid ingredients **inside this item-only worker**; they must be delegated, never pretended supplied.

Tanks for Bob declares specialty recipe categories `tank-crafting`, `tank-ammo-component`, `Seablock`, `growing`, `clay`, `fishery`, `cooking`, `pit-kiln`, `Steam`, `Calcifier`, `shaler`, `quarrying`, `advcooking` and `Steam-Compressor`; see [category source](https://github.com/mrcalzon02/Tanks-for-bob-Fork/blob/main/tanks_for_bob_fork_1.8.95/prototypes/categories/recipe-category.lua). Its recipes include `clay-pit`, `fish-pond`, `cooking-fire`, `primitive-steam-powered-pump`, `steam-condenser` and `quarry`. Some recipes require real fluids/steam and some produce several outputs or return inputs. See [recipes](https://github.com/mrcalzon02/Tanks-for-bob-Fork/blob/main/tanks_for_bob_fork_1.8.95/prototypes/recipe/recipe.lua) and [1.8.95 repair report](https://github.com/mrcalzon02/Tanks-for-bob-Fork/blob/main/docs/releases/v1.8.95.md).

**Add:** one **read-only prototype/machine capability catalog** resolved from `prototypes.entity`, active `LuaRecipe`, actual crafting categories, recipes/unlocks, real outputs, machine inventories, fluidboxes, energy source and real machine state. Reuse 0528/0702/0689/0691/0510 and existing station discovery. Extend machine candidates **only where no other existing family owner is responsible**; do not build a new executor or duplicate specialty fluid/energy authority.

**Acceptance:** construct/load a real Workbench recipe needing three ingredients, Cooking Fire steam, tank ammo assembler input/output fluid ports, and a mine/craft/consume chain with native inventory debit and physical produced output; no receipt for merely finding the recipe. Preserve catalysts/returned tools and any non-item products.

### P0-B — Quality-preserving item custody and modded inventory shape — **real gap**

In [0528](../tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua), `each_inventory_item` pulls a name and count from `get_contents()`, but discards `quality` on `ItemWithQualityCount`; `remove_inventory` and `insert_inventory` then use only `{name,count}` (lines 129–166). These operations are not safe for a general 2.1 Quality/modded-stack logistics contract. [`item_family_logistics_0702.lua`](../tech-priests_src/scripts/core/item_family_logistics_0702.lua) and [`station_catalog.lua`](../tech-priests_src/scripts/core/station_catalog.lua) also normalize item content by name/count in some paths. [Belt contract 1266](../tech-priests_src/scripts/core/belt_logistics_contract_1266.lua) already takes an explicit quality but is **read-only**.

**Add:** normalize item records to a native `{name,quality,count}` identity at every catalog/reservation/source/target/actual transfer boundary that handles Quality. Use quality-aware native methods, check counted remove/insert receipts and preserve failure/remainder custody. Keep existing storage-role authority and work reservations; no item teleport. **Do not** roll this across all workers without per-path audit and 2.0 backcompat tests.

**Acceptance:** common/rare item coexist in one source and arrive at correct dedicated targets with original quality, exact count, no quality downgrades, duplications or losses; intermittent interruption and reload still preserve ownership.

### P0-C — Actual burner/fuel/burnt-result capability discovery — **real gap**

[`logistics_machine_fulfillment_0528.lua`](../tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua) lists only `coal`, `wood`, `solid-fuel`, `rocket-fuel`, `nuclear-fuel` as candidates (lines 37–39, 615–632). [`energy_family_logistics_0707.lua`](../tech-priests_src/scripts/core/energy_family_logistics_0707.lua) also begins with hard-coded vanilla fuel preferences (lines 24–36). This omits modded fuel categories, including potential KJ-supplied items, and can prefer wrong stage fuel. Existing `energy_family_logistics_0707` already handles physical custody and burnt results — **extend it**, don't replace it.

**Add:** discover stocked and craftable fuel candidates through actual native `fuel_categories`, machine burner/electric/fluid energy source, `get_fuel_inventory()` / native inventory capability, and `can_insert` checks; validate `burnt_result` destinations. Prioritize low-cost attainable compatible fuel for bootstrap; never request a late-game fuel for a primitive boiler solely because of a ranking list.

**Acceptance:** an actual modded vehicle/machine accepts its matching fuel; an incompatible fuel cannot become a task; burner-produced spent item goes to its native storage; otherwise the job remains blocked with provenance intact.

### P1-A — Vehicle logistics and combat readiness (KJ + Tanks + AAI) — **new coverage boundary**

The [`item_family_logistics_0702.lua`](../tech-priests_src/scripts/core/item_family_logistics_0702.lua) turret family uses `defines.inventory.turret_ammo` and a dynamic ammo fallback (lines 257–295, 437–462); this is **not the same as servicing a vehicle's** `car_ammo`, `car_trunk`, fuel, equipment grid or weapon-category requirements. [Native Factorio 2.1 inventory definitions](https://lua-api.factorio.com/latest/defines.html) enumerate dedicated vehicle inventories. Historical KJ shared-module logs included *nonfatal* turret lookup warnings despite successful endurance, which merit diagnostic checks.

**Add:** **one native vehicle-service candidate family** through the existing 0702/0528/0510 reservation and custody chain: detect real `car`/applicable vehicle prototype, force/surface, stopped/safe contact, compatible gun/ammo inventory (actual `can_insert`), fuel, equipment grid, health/repair state and storage. Avoid moving or steering AAI-controlled vehicles; coordinate only when a genuine physical supply handoff is possible, and never overfill by guessing total ammunition. Keep base-damage/combat recovery owner and moving-target safeguards.

**Acceptance:** each named Predator/Leman Russ/Dreadnought/Baneblade plus one Tanks-for-Bob tank can be supplied with actual compatible ammunition and fuel (or produce an explicit native rejection). Real ammo inventory decreases on firing; no synthetic item or impossible reload while moving/hostile.

### P1-B — Native Servo-Skull robot readiness and delivered construction — **existing monitor, missing end-to-end proof**

[`roboport_readiness_0714.lua`](../tech-priests_src/scripts/core/roboport_readiness_0714.lua) already classifies robot items by `place_result.type` (construction/logistic robot), reads actual `LuaLogisticCell`, `LuaLogisticNetwork` counts and power, and monitors repair packs. [`roboport_expansion_frontier_1076.lua`](../tech-priests_src/scripts/core/roboport_expansion_frontier_1076.lua) is planning-only, with actual priest build ownership in 0338; [control.lua](../tech-priests_src/control.lua) explicitly reconciles `on_robot_built_entity` event delivery. Do **not** create a Servo-Skull-specific logistics simulator.

**Add/check:** verify that skin changes, native robot items and actual network members are all recognized in 0714; if truly different robot prototype IDs are present under a mod setting, discover by type rather than hardcoding `kj_servoskull` as an entity. Verify the event handler, required actual items, connected powered roboport, force/surface and finished ghost. The network must genuinely consume stock and construct before frontier advances.

**Acceptance:** building placed inside native construction coverage receives a real robot-build event, inventory debits match the ghost's required material, connected port stays powered and a save/reload retains correct completion. Outside coverage/unpowered/without robots remains an unbuilt proposal.

### P1-C — AAI interface and current KJ AI variant discovery — **assumed compatible; optional diagnostics**

The user's explicit decision retires the legacy `40kvehicles-AAI-fix` and waives that **patch's absence** as a smoke-test blocker. Current 2.1 native logs show AAI generating AI-capable derivative prototypes for KJ vehicles, but **no actual patrol/stop/resume was executed** in the reference run. AAI already owns vehicle commands.

**Add only if behavior is requested:** inspect the *installed* AAI 0.9.2 `remote.interfaces` and supported control/zone entities at runtime, plus AAI/KJ real prototype names. Implement a guarded, opt-in command-request boundary only using verified public interfaces and respect existing orders, ownership and AAI's steering. No guessed `remote.call` methods or direct `vehicle.teleport` to simulate navigation. This is **not** a mandatory gate solely because the retired patch is absent.

**Acceptance (diagnostic):** spawned actual equipped KJ vehicle turns/moves to an assigned AAI destination, stops, resumes, retains fuel/ammo and ownership after reload; commands do not conflict with Tech-Priests priest movement controller.

### P1-D — Recipe / science / technology graph and factory layout — **partially present**

[`item_family_logistics_0702.lua`](../tech-priests_src/scripts/core/item_family_logistics_0702.lua) already reads real `force.current_research.research_unit_ingredients`; preserve this. Tanks for Bob adds early `Seared-fish` / meal research branches and many specialized machines; [technology source](https://github.com/mrcalzon02/Tanks-for-bob-Fork/blob/main/tanks_for_bob_fork_1.8.95/prototypes/technology/technology.lua). Existing [belt contract 1266](BELT_AND_INSERTER_FACTORY_LOGISTICS_ARCHITECTURE_1266.md) and [1268 doctrine matrix](DOCTRINAL_FACTORY_ORGANIZATION_MATRIX_1268.md) explicitly have **no complete built autonomous material-transport route**.

**Add:** engine-discovered enabled tech prerequisites, actual recipe unlocks, native research packs, permitted crafting machine categories and actual item+fluid production graph. Integrate with existing bootstrap research exit, station catalog, infrastructure plan and the **one canonical** construction dispatcher. Have doctrine score feasible topologies only; no secondary physics or implied item flow because a ghost was placed.

**Acceptance:** a physically built specialty-machine-to-belt/inserter-to-consumer chain transfers counted product and produces actual science from modded ingredients. Record connected real source/sink, native lane occupancy and measured progress. Invalid categories, missing fluid, insufficient research or unavailable inventory block accurately.

### P2 — Localization, circuit/help and optional mod extensions

- **Mechanicist + Tanks conditional localization:** [Tanks' `mechanicus-locale.lua`](https://github.com/mrcalzon02/Tanks-for-bob-Fork/blob/main/tanks_for_bob_fork_1.8.95/prototypes/Compatibility/mechanicus-locale.lua) explicitly recognizes `mechanicist-factorio`, `mechanicus-reborn` and alternate Mechanicus IDs, applying `localised_name` overlays. Test key resolution in both mods' startup-settings configurations while Tech-Priests continues to use original internal prototype IDs. The empty [`prototypes/compatibility/mechanicus-reborn.lua`](../tech-priests_src/prototypes/compatibility/mechanicus-reborn.lua) needs no functionality until a concrete prototype conflict is demonstrated.
- **AAI Signals/circuits:** only if Tech-Priests needs circuit-controlled external vehicle missions; inspect actual virtual-signal prototypes and native wire connectors, avoid second circuit simulation.
- **Informatron:** [existing Tech-Priests compatibility file](../tech-priests_src/prototypes/compatibility/informatron.lua) is only a stub. Optional user guidance pages are worthwhile but do not gate logistics. Inspect `remote.interfaces["informatron"]` and provider contract before any page registration.
- **Factory Planner:** not required or present in the 2.1 unified run. No direct runtime API integration is needed for automatic production; optional manual plan reconciliation is separately scoped.
- **Official Quality/Recycler/Space Age:** mixed item-quality, recycle-loop returned products, item/fluid separation, temperature, heat/power and true platform placement all remain native-engine facts, not static mod-ID exceptions. `native_crafter_inventory_1277`, `native_fluidbox_1279`, 0689/0691 and Space Age prototypes already provide a foundation.

## 4. Sequenced work and tests without a job explosion

| Phase | Files / original owner | Minimum new proof | Gates |
| --- | --- | --- | --- |
| A — read-only installed-mod capability census | `prototype_compat`, station catalog, 0528, 0702, native 1277/1279 | Exact live machine types/categories, fuels, vehicle inventories, Quality variants and real recipes from current 13-ZIP pack | Deterministic source/prototype probe; **no world writes** |
| B — modded production + fluid handoff | 0528 + 0689/0691 + canonical 0510 | Three-input Workbench, real steam Cooking Fire, tank-ammo assembler fluid recipe, multi-output/returned tool | Native input debit + output receipt |
| C — quality- and fuel-safe logistics | 0528, 0702, 0707 and storage/reservations | Separate quality variants and modded fuel with retained byproducts; transactional interruption/reload | No lost, duplicated, downgraded or fabricated stacks |
| D — native robots and vehicle service | 0714/1076, 0702, 0510, combat owners | Servo-Skull native build from powered network; real 40K/Tanks gun/ammo/fuel stocking | Physical delivered build/stock proof |
| E — doctrine/transport and acceptance | 1266/1267/1268, original construction authority | Working modded recipe-to-belts/inserters-to-labs chain + research/science | 123k functional scenario with native assertions and checkpoint reload |
| Optional — AAI behavior diagnostics | AAI-owned vehicle interfaces; no overlapping priest path executor | Real waypoint → stop → resume while preserving orders | Nonblocking by the user's legacy-fix retirement decision |

**Keep exactly one unified 2.1 headless CI profile**, adding diagnostic/assertion stages within it, and retain the existing separate 2.0 regression workflow. Do not create a matrix of dozens of profiles or duplicate material/robot/vehicle work authorities.

## 5. Findings versus assumptions

- **Proven:** one combined native Factorio 2.1.24 job with 13 external ZIPs, engine map creation, 123,000 ordinary benchmark ticks and a separate 1,200-tick load; no fatal modpack load error.
- **Proven by source inspection:** specific Tech-Priests machine-type and fuel allowlists, name/count normalization, read-only robot and belt architecture, existing native runtime event hooks, and available Tanks recipe categories and conditional localization.
- **Not yet proven:** complete crafting/research closure of Tanks/Space Age under Tech-Priests decisions; 2.1 native public releases of Tech-Priests/Tanks (the smoke uses ephemeral metadata staging); real KJ vehicle refueling or weapons firing; AAI movement; Servo-Skull physical construction; end-to-end belts/fluids; persistence of changed gameplay state.
- **Decision:** the legacy AAI fix remains retired/nonblocking; do not reintroduce it merely to make an integration checklist look complete.

## 6. Authoritative references

- [Unified version manifest, smoke facts and legacy-fix decision](UNIFIED_FACTORIO_MODPACK_TEST_STATUS.md)
- [Current mandatory external mods](../tests/modpacks/required_21_1271.json)
- [Native engine authority (current project standard)](FACTORIO_NATIVE_ENGINE_AUTHORITY.md)
- [Factorio 2.1.24 inventory definitions](https://lua-api.factorio.com/latest/defines.html), [LuaEntity](https://lua-api.factorio.com/latest/classes/LuaEntity.html), [LuaLogisticNetwork](https://lua-api.factorio.com/latest/classes/LuaLogisticNetwork.html), [LuaEquipmentGrid](https://lua-api.factorio.com/latest/classes/LuaEquipmentGrid.html)
- [AAI Programmable Vehicles](https://mods.factorio.com/mod/aai-programmable-vehicles), [AAI Signals](https://mods.factorio.com/mod/aai-signals), [Servo-Skull](https://mods.factorio.com/mod/kj_servoskull), [Mechanicus Reborn](https://mods.factorio.com/mod/mechanicus-reborn), [KJ Entity Master](https://mods.factorio.com/mod/kj_vehicles)
- [Mechanicist Factorio 0.1.3](https://github.com/mrcalzon02/mechanicist-factorio/tree/main/mechanicist-factorio_0.1.3), [Tanks for Bob 1.8.95](https://github.com/mrcalzon02/Tanks-for-bob-Fork/tree/main/tanks_for_bob_fork_1.8.95)
