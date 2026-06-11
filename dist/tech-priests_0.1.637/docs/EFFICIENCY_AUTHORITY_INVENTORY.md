# Efficiency Authority Inventory — 0.1.606

This document exists to prevent optimization layers from duplicating one another. Before adding a new efficiency system, review this inventory and either route through an existing authority or explicitly retire/replace the older one.

## Canonical runtime authorities

| Layer | Canonical authority | Owns | Must not own |
|---|---|---|---|
| Low-level event registration | `runtime_event_registry.lua` | Factorio `script.on_event`, `script.on_nth_tick`, init/config-change registration | Task choice, target choice, broad service budgeting |
| Budgeted service cadence | `runtime_tick_broker.lua` | Recurring service registration, service interval, soft budget, service counters | World discovery, target claims, per-priest execution |
| Whole-runtime dormant gate | `efficiency_economy_0595` | Skip dormant nth-tick route lattice when no runtime Tech-Priest assets exist | Individual pair sleep decisions |
| Registry route budget gate | `efficiency_economy_0598` | Throttle registry-owned route execution | Broker service ownership or task selection |
| Pair classification | `pair_bucket_registry.lua` | `active`, `idle`, `sleeping`, `repair`, `invalid`, etc. buckets | Sleep policy, task execution, target claiming |
| Shared work backlog | `work_queue_authority.lua` | Discovered world work orders | Per-priest action stack, claim locking |
| Target claims | `work_reservations.lua` | Exclusive claims/leases on repair/sanctify/resource/construction/pickup targets | Finding work, executing work |
| Per-priest execution | `order_queue_0469.lua` | Individual priest action stack and current order | Shared discovery, global reservation policy |
| Dirty/cached world lookup | `efficiency_economy_0579` indexed catalog | Cached indexed entity lookups and dirty invalidation | Task assignment, sleep, reservations |

## Governing rule

```text
Work Queue finds jobs.
Reservation claims jobs.
Order Queue executes jobs.
```

The timing equivalent is:

```text
Registry owns Factorio hooks.
Broker owns budgeted recurring services.
Modules own behavior logic only.
```

## 0.1.605 timing consolidation pass

The following recurring direct timers were migrated to `runtime_tick_broker` services, with registry/direct `script.on_nth_tick` retained only as fallback if the broker is unavailable during install:

- `behavior_execution_doctrine_0505`
- `construction_planner_0359`
- `emergency_facility_doctrine_0357`
- `inventory_steward_0357`
- `mobility_recovery_contract_0506`

`/tp-runtime-report` now surfaces timing-authority counts: registry nth-tick route keys, registry nth-tick handlers, broker service count, and the static direct fallback audit count.

## Remaining direct timer audit candidates

These are not necessarily bugs. Many already route through `runtime_event_registry` or are legacy fallbacks. They should be reviewed before any new scheduler/broker/cache layer is added:

```text
acquisition_executor
acquisition_repair
acquisition_unstick
action_state_arbiter_0488
alt_writ_visual_stability_0474
behavior_contracts_0479
behavior_stack_cleanup_0509
bootstrap_runtime
chatter
combat_magos_movement_authority_0472
command_hierarchy_0480
conversation_voice_0530
crafting_executor
diagnostics_behavior_authority_0468
direct_mining_safety_0490
doctrine_argument
emergency_supply_reserve_0497
magos_planning_queue_0471
movement_bounds_contract_0511
placeholder_audio_0533
priest_lifecycle_authority_0499
priest_lifecycle_seal_0500
priest_recovery_safety_0503
priest_vanish_guard_0501
priest_vanish_guard_0502
proxy_turret_alignment
scheduler_contract_0512
self_station_scan_visual_authority_0489
single_dispatcher_0510
sound_manager_0475
startup_provisioning
station_catalog
station_network_overlay
station_pair_recovery
station_work_inventory
status_churn_damper_0532
status_state_sanity
stone_cache_filter_0534
task_execution_sound_governor_0477
task_lifecycle_authority_0478
task_pair_audit_0498
```


## 0.1.606 telemetry refinement pass

This pass adds measurement, not a new runtime authority.

- `runtime_tick_broker.lua` remains the timing/budget authority and now owns rolling metric storage for reporting.
- `_G.tech_priests_runtime_metric_0606` is a telemetry sink only. It must not be used to schedule work, choose targets, claim reservations, or alter behavior.
- Existing cache authority remains `efficiency_economy_0579.lua`; it now reports cache hits/misses to runtime telemetry.
- Existing movement authority remains `movement_controller.lua`; it now reports movement request, collapse, hold, and command counters to runtime telemetry.
- Existing work discovery remains `work_queue_authority.lua`; it now reports direct repair discovery scans to runtime telemetry.

Future efficiency candidates must use these counters to prove need before implementation.


## 0.1.607 event-driven feeder pass

`event_driven_work_feeder_0608.lua` is not a new authority. It is a leaf helper under `runtime_event_registry.lua` that feeds existing authorities.

| Event feeder | Owns | Must not own |
|---|---|---|
| `event_driven_work_feeder_0608.lua` | Translating selected high-signal world events into `work_queue_authority.lua` submissions and telemetry counters | Scheduling, sleep decisions, cache ownership, target reservation policy, per-priest order state, movement, repair execution |

Current implemented event path:

```text
on_entity_damaged
→ event_driven_work_feeder_0608.lua validates repair candidate
→ work_queue_authority.lua receives/duplicates-folds repair order
→ work_reservations.lua claims later
→ order_queue_0469.lua / repair_executor_0516.lua execute later
```

This is the first bounded implementation of Future Efficiency Candidate E. Additional event-fed categories must follow the same pattern and must not directly execute work.


### 0.1.608 directed wakeup note

`event_driven_work_feeder_0608.lua` remains a leaf helper. It submits repair jobs to `work_queue_authority.lua`, asks `pair_bucket_registry.lua` for a short-lived repair bucket hint on the nearest relevant pair, asks `efficiency_economy_0599.lua` to wake that specific pair, and asks existing dirty/negative helpers to clear stale local knowledge. It does not own scheduling, target reservation, execution, pathing, or a new cache.


## 0.1.610 Scan Routing Helper

`scan_routing_0610.lua` is a routing helper, not a new cache authority.

Owns:

```text
cache-first discovery call pattern
unified scan-routing telemetry
short caller-scoped negative scan hints
```

Does not own:

```text
indexed cache storage — owned by 0579
dirty-region marking — owned by existing dirty/index systems
work discovery semantics — owned by each discovery authority or work_queue_authority
target claims — owned by work_reservations / existing per-system claims
execution — owned by order/executor systems
scheduling — owned by runtime_tick_broker / runtime_event_registry
```

## 0.1.613 Queue/Event Pressure Reduction

This pass does not add a new authority.

- Duplicate work-order pressure remains owned by `work_queue_authority.lua`.
- Dirty/index invalidation remains owned by `efficiency_economy_0579.lua`.
- Negative-source invalidation remains owned by `efficiency_economy_0570.lua`.
- `event_driven_work_feeder_0608.lua` is still a leaf feeder beneath the event registry.

Authority boundary preserved:

```text
Events feed existing authorities.
Work Queue stores/folds jobs.
Reservations claim jobs.
Order Queue executes jobs.
Executors perform work.
```

New report counters:

```text
work-queues refreshed
work-queues claim_examined
event-driven-feeder dirty_seen / dirty_touched / dirty_invalid
```
