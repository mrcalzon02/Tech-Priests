# Tech-Priests Behavior / Function Map

Version: 0.1.659
Purpose: establish the current intended behavior authority map so repair work stops adding overlapping ad-hoc systems.

Companion visual map: `docs/BEHAVIOR_MERMAID_MAP_0660.md`

This is a function map, not a lore document. Every behavior should eventually have a clear entry condition, active owner, movement target, overhead status, and exit condition. If a future patch adds a behavior without placing it in this map, it is probably adding another hidden competing authority.

## 1. Top-Level Runtime Shape

### Loader / policy entry

`planning_constraints_0646.lua`

Role:
- Provides shared planning checks such as technology unlock checks, placeable item mapping, interior station territory checks, and defense perimeter checks.
- Installs late-cycle repair authorities from one already-loaded module to avoid repeated rewrites of the large ground-route/control files.

Current installed authorities in order:
1. `direct_acquisition_physical_guard_0649`
2. `proxy_ammo_hardener_0649`
3. `direct_acquisition_movement_lock_0650`
4. `movement_target_reconciler_0652`
5. `movement_intent_authority_0654`
6. `construction_placement_authority_0656`
7. `active_leaf_task_truth_0655`
8. `logistics_mineable_source_bridge_0657`
9. `visual_intent_line_authority_0657`
10. `movement_vector_enforcer_0651`

Important ordering rule:
- Movement target truth must be settled before vector enforcement.
- Active leaf task truth must be settled before overhead status and visual intent line rendering.
- Real inventory fetch happens through `logistics_fetch_executor_0527` rather than the removed duplicate `nearby_inventory_scavenge_authority_0658`.

### Main arbitration layer

`single_dispatcher_0510.lua`

Role:
- General pair-level action arbiter.
- Chooses broad behavior family when no higher-priority patched authority has claimed the pair.
- Wrapped by `logistics_fetch_executor_0527` so known-source fetches can preempt raw acquisition or emergency fabrication when the needed item already exists nearby.

Expected invariant:
- The dispatcher may choose a parent order, but it should not own concrete movement once a leaf task has a real target.

### Behavior monitor

`behavior_tree_monitor_0642.lua`

Role:
- Samples current behavior into canonical broad nodes.
- Does not decide behavior.
- Should be treated as state observation, not state ownership.

Canonical broad nodes:
- `BT-020` pair validation / invalid pair recovery
- `BT-100` combat / defense
- `BT-120` repair
- `BT-200` infrastructure-first / bootstrap gating
- `BT-240` emergency production
- `BT-260` direct acquisition
- `BT-280` construction
- `BT-300` machine logistics
- `BT-900` idle / waiting / chatter

## 2. Movement Authority Map

### Movement request storage

`movement_controller.lua`

Primary state fields:
- `pair.movement_request_0418`
- `storage.tech_priests.movement_controller_0419.requests[key]`
- `storage.tech_priests.movement_controller_0419.active_request_ids[key]`

Role:
- Stores and refreshes movement requests.
- Issues Factorio `go_to_location` commands.

Known limitation:
- Factorio unit movement is not precise; a submitted movement request is an intent, not guaranteed vector discipline.

### Direct target reconciliation

`movement_target_reconciler_0652.lua`

Entry:
- Active direct acquisition target lock exists.

Role:
- Rewrites stale movement requests to the direct acquisition target.
- Prevents generic station/action-arbiter movement from overriding an active resource target.

Exit:
- Direct acquisition lock clears or enters return/complete phase.

### Movement intent authority

`movement_intent_authority_0654.lua`

Entry:
- Active physical direct acquisition target exists.

Role:
- Makes direct acquisition target the movement truth.
- Rewrites `pair.target`, `pair.current_target`, `pair.current_work_target_0654`, `pair.movement_request_0418`, and movement controller request tables.

Exit:
- Direct acquisition completes or loses valid target.

### Active leaf task truth

`active_leaf_task_truth_0655.lua`

Entry:
- A concrete leaf action exists with a real target.

Recognized leaf families:
- acquisition
- consecration
- logistics
- emergency work
- construction, indirectly via `construction_placement_authority_0656`

Role:
- Publishes `pair.active_leaf_task_0655`.
- Publishes `pair.actual_task_status_0655`.
- Publishes `pair.current_work_target_0655`.
- Rewrites movement request to the concrete target.
- Patches overhead status so the visible text shows the current leaf action, not the parent order.

Expected overhead examples:
- `Mining stone`
- `Mining iron ore`
- `Fetching iron plate from crash-site-spaceship-wreck`
- `Walking to consecrate assembling-machine-1`
- `Consecrating burner-mining-drill`
- `Walking to build tech-priests-emergency-smelter`
- `Placing tech-priests-emergency-smelter`

Exit:
- Leaf task expires, completes, or is replaced by a higher-priority active leaf task.

### Vector enforcement

`movement_vector_enforcer_0651.lua`

Entry:
- Active movement request exists and pair is not clamped by mining/crafting/conversation locks.

Role:
- Samples priest movement.
- If the priest moves away from the active movement request target, reissues movement to that target.
- This module must never decide the target; it only enforces the current request.

Exit:
- Pair reaches target radius, request expires, or no active request exists.

Important invariant:
- If vector enforcement appears to move a priest wrong, the bug is probably upstream: the movement request points at the wrong target.

## 3. Visual Intent / Overhead Status Map

### Overhead status governor

`overhead_status_governor_0471.lua`

Role:
- Draws visible text over priests.

Patch:
- `active_leaf_task_truth_0655` patches canonical status resolution so leaf task text wins over generic parent order text.

Expected invariant:
- Overhead text must describe the actual concrete action being performed, not the broad parent goal.

### Visual intent line

`visual_intent_line_authority_0657.lua`

Role:
- Patches selected pair line rendering.
- When active leaf task or movement request exists, selected/hovered intent line points from priest to active work target.
- If no active work target exists, falls back to subdued station ownership link.

Expected invariant:
- Bright intent line should point at the thing the priest is trying to reach or work on right now.

## 4. Logistics / Scavenge / Salvage Map

### Canonical real-inventory fetch

`logistics_fetch_executor_0527.lua`

Role:
- Canonical physical fetch and inventory scavenging behavior.
- Searches known catalog sources, nearby real inventories, and loose ground item stacks.
- Moves priest to source.
- Removes item from exact inventory or loose stack.
- Deposits item into the station.

Source types:
- known station catalog storage source
- nearby containers / logistic containers
- assembler input and output inventories
- furnace source and result inventories
- mining drill inventories
- lab input inventory
- car / spider trunk
- cargo wagon inventory
- rocket silo result/output inventory
- character corpse inventory
- roboport material/robot inventories
- turret ammo inventories
- loose ground item stacks

Entry:
- Pair has an active item need and station does not already have enough of that item.

Exit success:
- Item is deposited into station.
- `pair.logistics_fetch_0527.phase = "deposited"`.
- Stale `scavenge`, `inventory_scan`, and `logistic_requested_item` fields are cleared.

Exit failure:
- No known fetch source, source empty, no source inventory, deposit failed, or movement request failed.

Important consolidation note:
- `nearby_inventory_scavenge_authority_0658.lua` was removed in 0.1.659 because it duplicated the intended role of `logistics_fetch_executor_0527.lua`.

### Mineable source fallback

`logistics_mineable_source_bridge_0657.lua`

Role:
- Fallback for known sources that are mineable but do not expose a normal inventory.
- Intended for crash wrecks and similar salvage targets.

Entry:
- Logistics fetch is targeting a source entity.
- Source has no usable inventory.
- Source is mineable and can produce the requested item.
- Priest is adjacent.

Exit success:
- Source is mined or manually converted to deposited output.
- Leaf task becomes `Salvaged <item> from <source>`.

## 5. Direct Acquisition Map

### Direct acquisition executor

`direct_acquisition_executor_0513.lua`

Role:
- Executes direct resource acquisition tasks.
- Should only represent direct acquisition of the immediate leaf resource, not the parent crafted product.

Example:
- Parent goal: make iron plate.
- Leaf task: mine iron ore.
- Overhead should say `Mining iron ore`, not `Acquiring iron plate`.

### Physical target guard

`direct_acquisition_physical_guard_0649.lua`

Role:
- Prevents synthetic acquisition from succeeding without a real physical target.
- Adopts a nearby valid physical resource/rock/tree target when a direct task has only a position.
- Clears stale direct tasks when no physical target exists.

### Direct acquisition movement lock

`direct_acquisition_movement_lock_0650.lua`

Role:
- Locks the current direct acquisition target entity so target churn cannot keep changing the priest's objective while walking.
- Forces direct command fallback if the normal movement request fails.

### Movement target reconciliation

`movement_target_reconciler_0652.lua`

Role:
- Makes the movement request point at the locked direct target instead of station/arbiter fallback coordinates.

## 6. Construction / Infrastructure Map

### Master infrastructure plan

`master_infrastructure_plan_0644.lua`

Role:
- Builds station-local infrastructure target plan.
- Chooses next infrastructure class based on station inventory, local resources, and already-built facilities.

Current broad sequence:
1. Smelting capability
2. Storage buffer
3. Resource extraction
4. Crafting capability
5. Research capability

### Bootstrap ghost planner

`construction_bootstrap_ghost_planner_0645.lua`

Role:
- Places one planning ghost at a time from the master plan.
- Should not count as completed infrastructure until the entity is actually built.

### Construction site planner

`construction_site_planner.lua`

Role:
- Chooses valid local placement sites.
- Handles station-owned interior/perimeter placement constraints.

### Construction planner

`construction_planner.lua`

Role:
- Canonical physical construction execution.
- Scans station-bound inventories for placeable items.
- Plans site.
- Moves priest to build site.
- Removes one item from station inventory.
- Creates the entity.

### Construction placement authority

`construction_placement_authority_0656.lua`

Role:
- Ensures construction becomes the active leaf task once the station has a placeable infrastructure item.
- Preempts more acquisition/scavenge work once a buildable item exists.
- Publishes construction leaf task and movement request.

Entry:
- Existing construction task, bootstrap ghost with item available, master plan target with item available, or any station-held placeable infrastructure item.

Exit:
- Entity placed, item missing, site blocked, or combat priority interrupts.

## 7. Consecration / Maintenance Map

### Consecration executor

`consecration_executor_0515.lua`

Role:
- Selects a target machine requiring maintenance/consecration.
- Moves priest to machine if outside rite range.
- Performs rite when in range.

Leaf truth handling:
- `active_leaf_task_truth_0655` maps consecration into either:
  - `Walking to consecrate <machine>`
  - `Consecrating <machine>`

Expected invariant:
- If consecration is active, the movement target and visual line point to the machine, not the station.

## 8. Combat / Defense / Ammo Map

### Combat behavior

Primary combat modules remain outside this late repair map, but broad behavior is sampled as `BT-100`.

Entry:
- Pair has valid combat target, threat state, defense assignment, or ammunition survival need.

Exit:
- Combat target gone, priest returns to normal task selection, or repair/rearm required.

### Proxy ammo hardener

`proxy_ammo_hardener_0649.lua`

Role:
- Ensures ammunition in station storage is actually loaded into the hidden proxy gun.
- Replaces false satisfaction checks where station had ammo but proxy gun was still empty.

Expected invariant:
- Combat should only treat ammo as satisfied when proxy has usable ammo or station ammo can be loaded immediately.

## 9. Emergency Production Map

### Emergency production executor

`emergency_production_executor_0514.lua`

Role:
- Handles emergency craft and devolved production steps.
- Should request concrete leaf tasks rather than displaying parent goals.

Example:
- Parent goal: make iron plate.
- Leaf tasks should become:
  1. fetch/mine iron ore
  2. feed smelter or emergency smelter
  3. retrieve iron plate

Expected invariant:
- Parent goal belongs in pending/state context.
- Overhead status belongs to the current leaf action.

## 10. Inventory / Station Storage Map

### Inventory steward

Likely module family:
- `inventory_steward_*`
- `_G.tech_priests_inventory_steward_sources_for_pair`
- `_G.tech_priests_0358_station_sources_for_pair`
- `_G.tech_priests_0358_try_deposit_to_station`
- `_G.tech_priests_0358_station_item_count`

Role:
- Provides station-bound inventory views.
- Provides safe station deposit/count helpers.

Expected invariant:
- Any module moving items into station should use safe deposit/count helpers when present.
- Direct raw `LuaInventory.insert` into machine output/result/source inventories should remain audited and avoided unless explicitly safe for that inventory type.

## 11. Current Behavior Priority Stack

This is the intended priority order after 0.1.659:

1. Pair validity / death / station invalid cleanup
2. Combat survival / threat response
3. Construction placement when station already has a buildable structure item
4. Current active leaf task truth target
5. Logistics fetch from real nearby inventories / catalog sources / loose ground stacks
6. Mineable salvage fallback for inventoryless wrecks
7. Direct acquisition of raw resources with physical target lock
8. Emergency production / devolved crafting
9. Consecration / maintenance if no higher-priority material/placement action blocks it
10. Idle / chatter / waiting

Note: Consecration may temporarily outrank logistics once it has already claimed a machine, but if a priest is visibly walking to consecrate a machine, the line and overhead must still point to that machine.

## 12. Pending Cleanup Targets

These should be handled before expanding behavior complexity:

- Remove remaining slash command blocks from old diagnostic modules.
- Reduce duplicated movement wrappers once the leaf task truth layer proves stable.
- Review any remaining module that writes `pair.target` without also publishing a leaf task.
- Review any remaining module that writes `pair.movement_request_0418` without respecting `active_leaf_task_0655`.
- Review any source that displays broad parent task text above the priest without consulting `actual_task_status_0655`.
- Review direct acquisition task naming so devolved requirements do not claim parent product names as current physical work.

## 13. Debugging Rule Going Forward

When a priest appears to be doing the wrong thing, inspect in this order:

1. What is `pair.active_leaf_task_0655`?
2. What is `pair.movement_request_0418`?
3. What is the visible intent line target from `visual_intent_line_authority_0657`?
4. What broad node does `behavior_tree_monitor_0642` report?
5. Which parent order or pending action created the leaf task?
6. Did the correct exit condition fire?

If those six disagree, fix the earliest layer that diverges. Do not add a new behavior module until the disagreement is mapped.
