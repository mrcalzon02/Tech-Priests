# Tech-Priests — Warfare module architecture and escalation plan

**Status: PLANNING ONLY.** No Skitarii, custom fortification, remote-input system, warfare AI, combat asset or integration hook is implemented by these documents.
**Work branch:** `feature/warfare-module-planning`. **Base:** main commit `55ce75a2aca2e65902af2c86e88da3818f6fa2d1`. No writes to current `main`, no branch merge or release.
**Strategic goal:** grow from reliable, native defensive installations into offensively capable, physically supplied combined arms with directly teleoperable Skitarii and fortress guns. Integrate vanilla vehicles and the existing KJ/Warhammer 40K lineup. Do not replace AAI's navigation, Factorio's combat physics, or Tech-Priests' existing factory/resource authority.

## 0. Design premises and vocabulary

The requested initial warfare trio is:
1. **Standard turret doctrine**: use the *already existing vanilla* gun, laser and flamethrower turrets (later artillery). New Tech-Priests-specific turret prototypes/art may be added **later**, but **are not presently part of this architecture**.
2. **Skitarii**: planned custom Tech-Priests infantry units. They **do not exist as a registered game entity** in this project; initial designs use a hypothetical `unit`-based soldier and/or allied native `character` behavior only after prototype testing. Do not create placeholder sprites or invisible actors now.
3. **Dedicated networked defense cannon/bunker**: planned original fortified turret with a separate operator/network controller, native ammo/power and a real ammunition path. It **does not exist as a shippable prototype yet**. The separate [Red Tech-Priests construction doctrine](../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md) controls future industrial/brutalist form, heavy ferrocrete, real bearings/sensors, power/control conduits and Factorio-scale readable renders.

**Terminology:** `AAI` = Advanced Autonomous Industries (existing vehicle mod); `AA` = anti-air / point defense, a possible **future** role; **teleoperation** = a player directly commands a specific unit or gun, not merely issuing AAI waypoints. Do not conflate the three.

**Operational boundary:** The existing factory/defense branch continues to discover/build/repair vanilla turret networks, mine/create ammo, connect power/fluids, and stock resources. The *future Warfare module* handles operator tactical control, Skitarii units, network cannon and offensive missions. Existing Tech-Priests move/dispatch/work reservations remain unique owners of their own workers.

## 1. Modular separation and eventual layout (planned, not created)

Within the existing Factorio `tech-priests` mod, future Lua submodules under `scripts/warfare/` may be **loaded only behind deliberate feature enablement** once the branch is approved for integration. These are **proposed module contracts, not source files**:

| Future interface | Sole responsibility | Forbidden overlap |
| --- | --- | --- |
| `warfare_registry` | Static recognition of supported native turret / Skitarii / car prototypes and measured combat capabilities | Never clone the station catalog's resource inventory or label strings as IDs |
| `asset_ownership` | Observe force/surface/unit number, command role, status, assigned group | Never change a priest's station/worker ownership |
| `warfare_command_arbiter` | One effective order per combat asset, takeover/release, precedence and lease expiration | Never own priest movement controller, AAI steering internals, or factory work dispatch |
| `warfare_teleoperation` | UI/input state, camera, operator lease, target and aim request routing, safe exit | Never silently turn map remote-view into assumed physical control |
| `warfare_targeting` | Valid enemy targets, weapon ranges, safety arcs and target designation | Never write fake bullet hits or replace native attack/AmmoType resolution |
| `warfare_squad_doctrine` | Formations, readiness, shared objective ordering, fallback and retreat proposals | Never fabricate native AAI route or `LuaCommandable` support |
| `warfare_emplacement_network` | Read live powered/circuit command links for cannons and control posts | Never infer native connectivity solely from distance / antenna decoration |
| `warfare_supply_requests` | Demand only: ammo, fuel, repairs, artillery logistics and unit replenishment | Never remove/insert items directly or duplicate 0510 / 0686 / 0702 / 0707 |
| `warfare_observation` | Bounded combat evidence, alerts, lease/status telemetry and instrumentation | Never register a second raw tick/event dispatcher |

**Integration rule:** When later merged, one small `control.lua` install hook delegates to existing `runtime_event_registry` and `runtime_tick_broker`. When Warfare is **off**, no active warfare workers, AI orders, scripted gun firing, UI hooks or per-tick scans run. Feature flag default = **off** for first integration. Branch remains independent throughout planning and module testing.

## 2. Warfare behavior layers

- **Native layer:** Factorio owns prototype guns, turret target selection, car ammo/fuel, collision/pathfinding, line of sight where supported, projectile damage, armor, power, circuits, player controllers and force hostility.
- **Asset layer:** vanilla turrets, native vehicles, existing KJ tanks, future Skitarii and network cannon. Real identities and quality/ammo remain authoritative.
- **Command arbitration:** player takes explicit control; orders survive release only when that asset's native behavior can accept/read them back; one active author at any time.
- **Operational doctrine:** hold / defend / escort / patrol / assault / withdraw / resupply; a **request** is not proof of execution.
- **Intelligence/targeting:** sensor records are native observations with confidence and an expiry; no fabricated omniscience. If a spotter loses sight of an enemy, do not issue magical long-range targeting through buildings.
- **Logistics:** use factory outputs and original dispatch to feed real inventories, energy and repairs. No free garrisons, power, ammo or spawned vehicles.

### Proposed order and lease precedence

1. **Engine safety, validated force/ownership and manual player veto** — abort invalid/hostile/self-harming orders and respond to disconnection.
2. **Explicit live operator teleoperation lease** — direct operator aim/movement within selected asset capabilities; prevent two operators from steering same unit.
3. **Emergency defense doctrine** — if not under manual control, retreat, suppress fire for civilians/friendly targets, respond to base attack and protect real station resources.
4. **Approved Warfare mission owner** — group routes and fire support (not a priest's ordinary job).
5. **Existing AAI or vanilla autonomous behavior** — permitted whenever a higher control level releases the asset.
6. **Safe idle/hold** — if no legal control channel, no valid target or incomplete observation.

This is a **candidate policy**, not an assertion that current engine/AAI lets its orders be suspended/restored. Every takeover must preserve earlier state **only where a documented native readback/cancel/resume interface exists**. AAI's internal AI is not editable merely because a Lua entity is visible.

## 3. Escalation roadmap — retain all current assets, do not invent missing ones

| Gate | What exists today | New warfare planning / eventual deliverable | Native proof before advance |
| --- | --- | --- | --- |
| **W0 — baseline** | Vanilla gun/laser/flamethrower turrets, artillery, native car/tank/spider vehicle; existing KJ tanks, AAI 0.9.2 | Inventory real turret/car capabilities, attack categories, actual command ownership and current defense readiness | Accurate source/prototype census; no code changes to active runtime |
| **W1 — turret doctrine** | Existing vanilla guns, laser/flame + Tech-Priests 0259/0816/1091 defense hooks | Later **Warfare-owned** targeting priority, sensor and remote target designation *on supported vanilla turrets*, not a duplicate base-defense constructor | Real ammo/electric/fluid readiness, native hostile targeting, no friendly fire; safe release |
| **W2 — Skitarii** | **No original unit prototype yet**; current Tech-Priest has a `unit` + hidden native ammo-turret proxy precedent | New visible Skitarii with patrol, guard, tactical lease, direct operator view/control; native ammo and damage; no copied worker identity | Movement/combat at real range, one owner, death/revival, load/save, no proxy leakage |
| **W3 — networked defense cannon / bunker** | **No new cannon/bunker prototype yet**; native turrets, circuits, power and artillery exist | Powered fortified original cannon with local AI and authenticated remote fire-designation channel; sensor telemetry; correct material feed | Real circuit and power link, valid target, normal projectile/AmmoType and ammo spent, manual release and fail-safe |
| **W4 — mechanized offensive formations** | **Existing assets:** vanilla vehicles + AAI + KJ Baneblade, Predator, Leman Russ, Dreadnought and Tanks special tanks | Squad doctrines, garrison support, motorized assaults, escort; AAI's single-weapon AI variants respected | Actual AAI move/stop/resume and physical ammo/fuel, destruction/recovery, save/reload, 2+ vehicles |
| **W5 — combined arms** | Foundation from W0–W4 | Fire support, artillery coordination, target-intelligence fusion, anti-air / point defense if target class actually supported | Live sensor and target restrictions, safe firing arcs, no omniscience or phantom detections |
| **W6 — multi-weapon AI investigation** | AAI makes one AI variant per weapon; original cars can carry multiple guns | Explore noninvasive role switching or separately controlled native weapon components **only if warranted** | Unit/vehicle identity and all ammo/cargo/health/quality preserved; no AAI patch or duplicate AI by assumption |

**No Skitarii, cannon, bunker or other future asset is presently claimed as implemented.** Do not use references to future W2/W3 as if recipes, prototypes, animations or 3D models exist.

## 4. Native station/base integration

Keep original planners as the sole work/physical authority:
- `defense_perimeter_0259` / `combat_defense_reaction_0816`: build / restore protective layers after genuine hostile attack.
- `defense_layer_audit_1091`: native gun/laser/flame readiness and wall health.
- `item_family_logistics_0702` / `artillery_logistics_0713`: counted ammunition supply.
- `fluid_turret_readiness_0716` and 0689/0691/0696: native fluid range/segments and connected feed.
- `power_setup_1252` / `native_electric_authority_1263`: actual grid and generator connection.
- `roboport_readiness_0714` / `roboport_expansion_frontier_1076` / canonical construction: real delivered buildings and repairs.
- `single_dispatcher_0510`, `work_reservations`, `inventory_steward`: task admission and counted custody.

**Future contract:** `Warfare.request_supply(asset_ref,item_identity,count,purpose)` returns *pending request*, not a material transfer. Only the original dispatcher can turn it into an evidenced successful transfer. A future remote defense cannon may ask for ammunition from a Tech-Priest station; it may never silently consume station items.

## 5. Remote teleoperation of Skitarii and bunker/cannon

Three concepts must remain separate:
- **View-only monitor** — place the human camera at a selected entity using Factorio's native remote-view controller. This does not steer/shoot.
- **Tactical order** — choose target/location / doctrine and release. Existing `LuaCommandable` can command native units; AAI owns car waypoint/route commands. Does not imply continuous first-person control.
- **Live teleoperation** — explicit **exclusive lease**; player chooses a Skitarius or a cannon, sees current target/weapon/range/ammo/power, and uses an agreed remote input (later custom input/GUI) to move/aim/fire. Every user action must be validated by engine-authoritative readback.

### Teleoperation user story (future)

1. Player chooses **Warfare Command** and selects a friendly controlled entity from a nearby/current surface or approved map sensor list; unavailable / hostile or missing-signal assets are clearly disabled.
2. Controller enters **Observe**; UI shows actual name, force, health, supply, effective gun mode, target, selected armament and link status.
3. Player presses **Take Control**; arbiter checks claimability, current operator, force, entity validity, remote link, live range and power, then atomically establishes a bounded lease. No other commander can seize it silently.
4. **Skitarii:** aim and move requests route to the *validated* native unit capabilities; pathing must not be replaced with teleports. **Bunker:** gun rotates/targets only through documented turret APIs; shots consume genuine ammo/energy. Skitarii cannot be `set_driver` as though they were car-type entities.
5. **Release/Cancel:** previous valid autonomous rules resume only if authoritative state restoration is possible; otherwise controlled entity enters a safe hold and reports why. Camera/operator returns to prior view.
6. On save/reload, disconnect, invalid entity, world change, loss of command power/circuit, or disconnect timeout, the lease expires and the asset falls back safely. No stuck remote camera and no orphaned hidden turret.

**Vital API limitation:** In 2.1 `LuaEntity.shooting_target` on native turrets **can't be cleared by assigning `nil`**. A future teleoperated bunker cannot just write `shooting_target=nil` and claim reliable release. Investigate native targeting priorities / target filters / lifecycle, or an explicit supported soft-takeover mechanism, and prove proper reset in isolated tests.

**Command network doctrine:** A powered actual command node and verifiable Factorio circuit connection or another deliberately implemented real link must connect the operator to the cannon. Decorative antennae confer **no reach**. Native red/green wire/circuit networks are not arbitrary global wireless; no building gets a universal targeting radius from visual similarity. If more remote links are introduced later, they need actual game prototypes, energy/coverage and traceable connectivity, with local autonomy fallback.

## 6. Data and identity invariants (design only)

Proposed minimal persistent records are primitive, serializable values:
- asset: `{surface_index,force_index,unit_number,prototype_name,asset_role}`
- control: `{lease_id,operator_player_index,mode,start_tick,expiry_tick,prior_authority,lease_epoch}`
- order: `{order_id,asset_ref,objective_type,position_or_target_ref,issue_tick,expiry_tick,writer,priority,status}`
- target: `{target_ref,observed_tick,observed_surface,observed_force,confidence,source_unit}`
- supply need: `{asset_ref,item_name,quality,count,physical_source_unit,request_id,receipt_id?}`

**These are proposed fields, not live storage schema.** Do not store unverified LuaObjects in a cross-version serialized mission ledger. Keep real actual entity/force/surface checks at execution. Do not store a second active command queue in addition to existing Tech-Priests movement orders; Warfare has its own **combat asset** domain only.

## 7. Failure, performance and multiplayer policy

- **Fail closed:** unknown target, wrong force, missing entity, unpowered control node, missing ammo, no known circuit link, unknown AAI command API, destroyed Skitarii, unsupported gun, or conflicting controller => no action and explicit reason.
- **Avoid unbounded polling:** use event registry and broker budget; update only observable assets and active leases; cache static prototypes, invalidate on build/destroy/force/surface/configuration change.
- **Deterministic multiplayer:** one operator lease at a time, stable tie-breaker, no client-local source of truth, no implicit host advantage, always allow release. UI and control must work for late-joiners and save/load.
- **UPS performance:** measure inactive overhead 0/near-zero, then baseline and stress with 1/10/50/200 units plus range-limited sensor scans. No 200+ unit constant per-tick full-map scanning.
- **Projectile physics:** original targetability, range, cooldown, damage types, ammo/energy consumption and friendly-force consequences remain Factorio's. No fake shots, projectile teleportation or synthetic damage receipts.
- **No destructive branch changes:** never delete or alter main's existing factory, priest movement, defense owner or CI job to make Warfare work. First test in branch-only isolated run after explicit implementation approval.

## 8. Staged go/no-go decisions

1. **Architecture planning gate (now):** complete document audit, asset roster, ownership and teleoperation alternatives; create branch and issue; no runtime implementation.
2. **Prototype and control feasibility gate:** obtain read-only native 2.1 snapshots of installed AAI interfaces and car/unit/turret capabilities; confirm Skitarii/bunker donor prototype candidates and safe remote control APIs.
3. **Controlled experiment gate (later):** explicitly authorize one minimal asset/control mode in the isolated warfare branch, keeping all original factory tests unaffected.
4. **Combat functionality gate:** prove native targeting and custody with one vanilla turret, then one Skitarius, then one bunker; later KJ vehicle pairs.
5. **Integration gate:** user approves, separate feature gate default disabled, one isolated branch runtime job and existing main regression readback, no auto-merge.
6. **Release gate:** beyond basic smoke, real battle and save/reload evidence; user separately approves publishing.

## Key links

- [Control and one-weapon evidence](CONTROL_INTERFACE_AUDIT.md)
- [Acceptance gates and asset catalog](WARFARE_TEST_AND_ASSET_MATRIX.md)
- [Current defensive construction doctrine](../docs/RED_TECH_PRIESTS_CONSTRUCTION_DOCTRINE.md)
- [Existing source-backed cross-mod integration audit](../docs/CROSS_MOD_NATIVE_PROCESS_INTEGRATION_AUDIT.md)
- [Factorio native authority](../docs/FACTORIO_NATIVE_ENGINE_AUTHORITY.md)
- [LuaEntity, turret targets and remote view](https://lua-api.factorio.com/latest/classes/LuaEntity.html)
