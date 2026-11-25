# Tech-Priests Current Behavior / Function Ownership Index

**Reviewed:** 2026-11-25. This is a source map, not native behavior or performance acceptance.
The number in this filename is retained for existing links; it is not a claim that the old implementation is still active.

Use the [complete source inventory](BEHAVIOR_SOURCE_INVENTORY.md) and its
[content hashes and source sites](BEHAVIOR_SOURCE_INVENTORY.json) for the full module/function/registration index.
Potential reachability, conditional wrappers, and retired source are distinguished there.
Source presence does not prove that a callback installed or ran in Factorio.

## Governing rule

Each behavior needs an entry condition, current owner, scheduling path, movement owner, physical state, and terminal outcome. The original map treated a proposed priority stack as the runtime graph. This index describes current source ownership and links the executable inventory; it does not assert that all installation/runtime gates passed.

## Shared authority and function map

| Concern | Source and principal functions | State / exit boundary |
| --- | --- | --- |
| Event composition | `runtime_event_registry.on_event`, `.on_nth_tick`, lifecycle registration and `reconcile_event` | Owner-keyed route replacement; callback failures isolated and recorded. |
| Broker scheduling | `runtime_tick_broker.register_service`, `.pulse`, `.normalize_result`; `efficiency_economy_0598.broker_plan`, `.broker_ran` | Due tick, priority, offered work budget and normalized result; 0598 phases and rotates at most four eligible background callbacks per pulse with active-work exclusions. Separate registry callbacks remain outside that cap. |
| Policy installation | `planning_constraints_0646.install`, `.finalize_installation`, `.feature_available` | Declarative active/retired list and family degradation. |
| Pair work rotation | `single_dispatcher_0510.service_all` | Cached roster plus rotating cursor; live pair validity remains checked. |
| Action choice | `action_state_arbiter_0488.action` / `.classify` | Returns recommendation; no scheduled task-mutating pass. Visual helper functions may clean rendering objects. |
| Routine execution | `single_dispatcher_0510.service_pair` and local `execute` | `canonical_action_0744`, family-specific result and legacy gate. Early incumbent/strategic owners precede ordinary classification. |
| Queue lifecycle | `order_queue_0469.submit`, `.complete_current`, `.fail_current`, `.cancel_current`, `.transition_current`, `.tick_pair` | Canonical acceptance, duplicate merge, pause, terminal record and promotion. |
| Ground movement | `movement_controller.request`, `.request_status`, `.stop`, `.service`, `.sample` | One stored owner/priority/TTL request; native commands and leases. |
| Generic storage | `storage_role_authority_0686.deposit_exact`, `.remove_generic_item`; `inventory_steward.service_custody` | Generic stores and exact held remainder. Specialized machine inputs/outputs use family executors. |
| Retained inventory-source discovery | `efficiency_economy_0587.source_candidates`, `.container_candidates`, `.invalidate_entity_sources`; callers 0527/0686 | Item-independent typed membership, immediate event updates and 1,800-tick demand expiry, including empty results; actual inventory, wire permissions, role and stock remain live. Initial, expired, changed-domain and explicit-refresh searches are complete and uncapped. |
| Catalog and other discovery | `station_catalog.scan_due`, `.get_for_pair`; `station_area_change_invalidator_0634`; `scan_routing_0610`, `efficiency_economy_0579`, `work_queue_authority`, `event_driven_work_feeder_0608` | Dirty catalog snapshots retained until rotating two-station refresh on the separate 60-tick registry route; cold direct access may scan synchronously. Within a scan, identity/product reuse and authoritative connector counts avoid repeated work. Dense subdivision has no retained entity/subtree cursor; incomplete snapshots preserve ownership, not complete coverage. |
| Infrastructure survey continuation | `master_infrastructure_plan_0644.service_pair`, `.service_all`, `.install`; local `broker_survey_pulse` | The broker keeps an offered eight-ID batch per 97-tick cycle, attempts one current pair per admitted five-tick pulse, and persists its cursor and original cycle deadline through 0598. Public synchronous calls and the conditional 97-tick registry fallback keep their separate contracts. |
| Proxy ammunition | `proxy_ammo_hardener_0649.station_ammo`, `.proxy_has_ammo`, `.load_proxy_from_station` | Live stock and exact refund custody; one source collection per ammo lookup and runtime-derived prototype list. Combat service remains outside background admission. |
| Shared claims | `work_reservations.claim`, `.release`, `.target_key` | Surface/force/owner identity, TTL and explicit release. |
| Lifecycle | `priest_lifecycle_authority_0499`, `station_pair_state`, generated lifecycle, 0503 recovery | Original identities, custody and authorized recovery; no broad respawn inference. |
| Bunker integration and unlock recovery | `bunker_cannon_integration.install_main`; `bunker_family_visuals.init`, `.shot`, `.tick` | Canonical registry lifecycle/event composition. Initialization registers existing visuals and restores researched recipe unlocks from technology prototype effects; native weapons retain targeting, damage and ammunition ownership. |
| Observation | `behavior_tree_monitor_0642`, overhead governor, visual intent, diagnostics | Partial observer vocabulary; never substitute it for the complete source inventory. |

## Current executable family index

The [main Mermaid map](BEHAVIOR_MERMAID_MAP_0660.md#5-full-behavior-family-routes) links every major family, including specialized logistics, rail/courier/relocation, native combat and additional runtimes. This replaces the previous nine-node list as the codebase entry point.

| Routine family returned to 0510 | Executor | Physical state |
| --- | --- | --- |
| `direct-acquisition` | `direct_acquisition_executor_0513` | Actual resource target and `direct_acquisition_custody_0513`. |
| `station-craft` | `emergency_production_executor_0514`, guarded `crafting_executor` fallback | Recipe ingredients, transaction/refund state and counted output. |
| `consecration` | `consecration_executor_0515` | `consecration_0515`, shared sanctify claim and refund custody. |
| `repair` | `repair_executor_0516` | Target reservation and `repair_pack_custody_0516`. |
| `combat-repair` | `combat_repair_doctrine_0517` delegates to 0516 | Tactical cluster selection; pack/health changes remain in 0516. |
| `construction` | `construction_planner` | Candidate, physical carried item, `construction_custody_0338`, terminal ledger. |
| `machine-logistics` | `logistics_machine_fulfillment_0528` | `machine_logistics_0528` and physical cargo custody. |
| `item-family-logistics` | `item_family_logistics_0702` | `item_family_custody_0702`. |
| `energy-family-logistics` | `energy_family_logistics_0707` | `energy_family_custody_0707`. |
| `rocket-silo-logistics` | `rocket_silo_logistics_0710` | `rocket_silo_custody_0710`. |
| `artillery-logistics` | `artillery_logistics_0713` | `artillery_custody_0713`. |
| `roboport-repair-pack-logistics` | `roboport_repair_pack_logistics_0715` | `roboport_repair_custody_0715`. |

`logistics_fetch_executor_0527` remains a dispatcher wrapper, not an entry in this executor table. Ordinary combat, movement and conversation may be compatibility families. A table entry cannot prove sole ownership of every legacy call into that subsystem.

## Retired source must not be drawn as live behavior

| Historical module(s) | Current replacement |
| --- | --- |
| 0650 direct lock; 0652 reconciler; 0654 intent authority | Direct executor plus canonical movement request. |
| 0651 vector enforcer; 0518 cadence; 0566 enforcement; 0632/0633 route wrappers | `movement_controller`, with explicit Void delegation. |
| 0655 leaf truth | `single_dispatcher_0510` publishes `canonical_action_0744`; some legacy fields still exist in active compatibility code. |
| 0656 placement authority | `construction_planner` and read-only `construction_site_planner`. |
| 0657 mineable bridge | Physical direct acquisition and custody. |
| 0673/0676/0677 repair hardeners | Canonical 0516/0517. |
| 0682/0683/0684 machine hardeners | Canonical 0528. |
| 0687 inventory transfer wrapper | `inventory_steward` custody. |
| 0694/0696/0697/0699/0700 fluid wrappers | `work_reservations`, 0689 and 0691. |
| 0703, 0711, 0718, 0722, 0724, 0726–0728, 0730–0731 specialty wrappers | Corresponding item, energy, silo, artillery and fluid-turret owners. |

The exhaustive 48-entry retired declaration is `planning_constraints_0646.RETIRED`; the generated inventory records all modules, including ones outside that declaration. Absence from the retired table is not proof of live execution.

## Performance mapping contract

For every timed route record category, interval, offered work count, actual work visited, cursor/backoff, synchronous scan fanout and cache invalidation. Classify registry siblings separately from broker services. Preserve active movement/cargo progression while deferring discovery. Use native profile evidence to establish cost; do not infer UPS from the number of functions or diagrams.

## Update and evidence rule

Change the relevant diagram and ownership/exit description with the source change. Regenerate the source inventory with `python tools/audit_ups_hotspots_0743.py --write-behavior-maps`, explicitly acknowledge the reviewed curated maps with `--acknowledge-behavior-map-review`, then run `--check-behavior-maps` through the same tool. Generation alone does not bless a changed manual diagram. Follow the [performance validation protocol](UPS_VALIDATION_RUNBOOK_0742.md) for exact source, save, engine version, population, profiling settings, sample window and artifacts. A clean map check proves freshness only.
