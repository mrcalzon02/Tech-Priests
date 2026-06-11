# Tech Priests Behavior and Construction Contract

This is the current behavior-development contract. It replaces the historical
behavior-tree foundation and version-by-version behavior addenda.

## Runtime truth

The code does not yet execute one complete behavior tree.

- `scheduler_behavior_tree.lua` is a legacy ownership map and diagnostic view.
  It does not select or execute current work.
- `behavior_tree_monitor_0642.lua` observes pair state and assigns `BT-*` labels.
  Its labels are telemetry, not control flow.
- `runtime_tick_broker.lua` owns recurring service cadence and budgets.
- `work_queue_authority.lua` owns shared world-work discovery and backlog.
- `work_reservations.lua` owns short-lived target claims.
- `order_queue_0469.lua` owns per-pair intent and action ordering.
- `single_dispatcher_0510.lua` executes direct acquisition, station production,
  consecration, repair, and combat repair through their leaf executors.
- `logistics_machine_fulfillment_0528.lua` wraps dispatcher service to perform
  machine-specific input, fuel, and output transfers.
- Construction and combat are not fully dispatcher-owned. Bootstrap ghosts are
  broker-driven planning records; physical construction still uses legacy
  construction paths. `defense_perimeter.lua` still participates through the
  legacy `tick_pair` chain.

No document or `BT-*` label may be cited as proof that a behavior is executable.
The owning module and its call path are the proof.

## Governing flow

```text
pair lifecycle validates identity
-> planner or event source discovers a need
-> work queue stores shared work when applicable
-> reservation claims a target or site
-> order queue stores per-pair intent
-> dispatcher selects one visible action family
-> one executor performs physical work
-> inventory, machine, and world state prove completion
-> order completes or returns a specific blocker
```

The station owns intent, plans, facilities, and durable inventory. The priest
owns physical movement and short-lived carried material. Machines own recipe
progress. GUI, audio, visuals, scheduler maps, and behavior monitors report
state only.

## Priority order

1. Pair validity and lifecycle recovery.
2. Immediate hostile combat and combat repair.
3. Repair of friendly infrastructure.
4. Continue already claimed physical work.
5. Satisfy critical supply and clear unsafe transient cargo.
6. Complete station or emergency-machine production already in progress.
7. Acquire exact missing materials for active work.
8. Execute claimed construction.
9. Service configured machines and move their products downstream.
10. Routine consecration and maintenance.
11. Planning, catalog refresh, conversation, and idle behavior.

Background planning must never overwrite active execution state merely because
its service pulse is due.

## Behavior labels

The monitor's current labels remain useful as a vocabulary:

| Label | Meaning in current code | Authority status |
| --- | --- | --- |
| `BT-020` | Invalid pair or recovery gate | Observed from lifecycle state |
| `BT-100` | Combat-like family or mode | Mixed dispatcher and legacy control |
| `BT-120` | Repair | Dispatcher executor owned |
| `BT-140` | Recently satisfied supply | Observational completion state |
| `BT-200` | Infrastructure-first blocker | Governor state, not construction execution |
| `BT-240` | Emergency/station production | Dispatcher executor owned |
| `BT-260` | Direct acquisition or acquisition intent | Direct executor owned when a concrete direct task exists |
| `BT-280` | Construction | Legacy task observation plus explicit planning marks |
| `BT-300` | Machine logistics | Dispatcher wrapper and phase record |
| `BT-320` | Consecration | Dispatcher executor owned |
| `BT-900` | Conversation or idle | Observational fallback |

`BT-220`, `BT-230`, and `BT-340` remain useful design concepts for emergency
facility construction, facility operation, and background planning, but the
monitor does not currently infer them as distinct runtime nodes.

## Construction planning contract

### Actual 0.1.646 planning path

```text
master_infrastructure_plan_0644
-> chooses an unlocked next infrastructure item
-> construction_bootstrap_ghost_planner_0645
-> asks construction_site_planner for one site
-> planning_constraints_0646 checks technology and territory
-> creates at most one station-local planning ghost
-> behavior monitor may mark BT-280
```

This path plans only. A ghost is not completed infrastructure and does not prove
that stock, movement, reservation, or construction execution exists.

`planning_constraints_0646.lua` is the shared policy owner:

- A building is eligible only when its placeable item has an enabled force recipe.
- Ordinary production sites stay inside the station yard and preserve the outer
  defense band.
- Defense sites must lie in the station perimeter band.
- Defense sites inside another friendly station's control radius are rejected.

`defense_perimeter.lua` consumes the same policy for wall arcs, cardinal gates,
turret fire slots, and turret support structures. It is still a legacy physical
controller and must eventually become a planning producer plus construction
executor input.

### Required construction migration

The desired executable path is:

```text
science objective or infrastructure deficit
-> recipe dependency and minimum-machine plan
-> technology and territory validation
-> construction work submitted by surface/force/station/category
-> site reservation
-> order queue construction intent
-> dispatcher construction family
-> construction executor walks, consumes station stock, and places entity
-> recipe assignment configures the new machine
-> machine logistics supplies inputs/fuel and extracts outputs
-> downstream recipe demand or science pack completion closes the order
```

Required implementation boundaries:

1. Planning modules may create plans and submit work. They must not directly move
   priests, consume stock, or claim completion.
2. Construction work must use the shared work queue and reservation authority so
   production, defense, and station expansion cannot claim the same site.
3. A construction executor must replace physical placement in legacy planners.
4. Recipe assignment must be explicit. An unconfigured or wrongly configured
   machine is a blocked construction result, not a valid production node.
5. Machine logistics must consume decomposed recipe demand, not scan every local
   machine as an unrelated maintenance opportunity.
6. Defense plans reserve the perimeter; production plans reserve interior sites.
   Neither planner may silently relocate into the other's territory.
7. All locked prototypes return `technology-locked`; they are not requested,
   ghosted, or treated as future stock.

## Construction failure exits

Every construction order must end in one of these states:

- `complete`: entity exists, stock was consumed, ownership recorded, and required
  recipe configuration succeeded.
- `already-satisfied`: a valid matching entity already occupies the intended role.
- `technology-locked`: no enabled placeable-item recipe.
- `missing-stock`: item is unlocked but unavailable; production/acquisition owns
  the next step.
- `site-conflict`: site is reserved, in another station's control area, or in the
  wrong interior/perimeter zone.
- `no-site`: bounded site search found no legal candidate.
- `movement-failed`: executor could not reach the reserved site.
- `placement-failed`: Factorio rejected placement after revalidation.
- `configuration-failed`: entity exists but required recipe or machine role could
  not be assigned.
- `stale-plan`: science objective, station radius, technology, or infrastructure
  state changed before execution.

Blocked plans must yield and be reevaluated. They must not become permanent modes
or repeated per-tick scans.

## Required diagnostics

Behavior work must expose:

- owner module and action family;
- current phase and entry reason;
- item, target, site, and station owner;
- progress or wait condition;
- blocker and retry policy;
- completion or failure reason;
- queue and reservation identifiers for shared work.

Useful current commands include `/tp-runtime-report`, `/tp-dispatcher-0510`,
`/tp-behavior-tree-0642`, `/tp-infra-plan-0644`,
`/tp-bootstrap-ghost-0645`, `/tp-machine-logistics-0528`, and
`/tp-defense-debug`.

## Development rule

Before changing behavior, identify the current executable owner and whether the
change replaces, feeds, or observes it. Do not add a parallel timer, planner,
queue, reservation layer, movement route, or physical executor. When a legacy
controller is migrated, disable or demote that controller in the same testable
pass.
