# Runtime Script Organization

New behavior belongs in `scripts/core/` and must follow the authority contracts
in `docs/BEHAVIOR_ORDER_OF_OPERATIONS.md` and
`docs/AUTHORITY_REFACTOR_CONTINUITY.md`.

## Canonical authorities

- `runtime_tick_broker.lua`: recurring cadence and budgets.
- `work_queue_authority.lua`: shared world-work backlog.
- `work_reservations.lua`: short-lived target and site claims.
- `order_queue_0469.lua`: per-pair intent and order lifecycle.
- `single_dispatcher_0510.lua`: one visible action family per pair.
- `movement_controller.lua`: ground movement requests.
- `action_state_arbiter_0488.lua`: visible action classification.
- `station_work_inventory.lua` and inventory stewards: durable station stock.

## Dispatcher-owned executors

- `direct_acquisition_executor_0513.lua`
- `emergency_production_executor_0514.lua`
- `consecration_executor_0515.lua`
- `repair_executor_0516.lua`
- `combat_repair_doctrine_0517.lua`

`logistics_machine_fulfillment_0528.lua` is a dispatcher wrapper for
machine-specific fuel, ingredient, and output transfers.

## Construction and planning

- `master_infrastructure_plan_0644.lua`: chooses the next unlocked infrastructure need.
- `construction_bootstrap_ghost_planner_0645.lua`: creates one planning ghost per station.
- `planning_constraints_0646.lua`: shared technology and territory policy.
- `construction_site_planner.lua`: bounded site selection.
- `construction_planner.lua`: legacy physical construction path pending migration.
- `defense_perimeter.lua`: legacy perimeter planning and placement pending migration.
- `arterial_planner.lua`: recipe dependency and minimum-machine planning scaffold.
- `logistics_machine_fulfillment_0528.lua`: services already configured machines.

Planning ghosts are not completed construction. Construction and defense must
eventually submit shared work, reserve sites, enter the order queue, and execute
through one dispatcher-owned construction executor.

## Observational maps

- `scheduler_behavior_tree.lua` is a legacy ownership map.
- `behavior_tree_monitor_0642.lua` infers `BT-*` telemetry from current pair state.

Neither module controls behavior.

## Legacy modules

Generated control fragments and top-level scripts remain compatibility surfaces.
Do not add new independent `tick_pair`, direct timer, movement, construction, or
inventory authority to them. Migrate one behavior family at a time and demote the
old controller when its canonical executor is proven.
