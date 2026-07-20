# Runtime Authority Continuity

Read this file, `STANDARDS_AND_PRACTICES.md`, `../../docs/STANDARDS_AND_PRACTICES.md`, and `../../RECOVERY_REPAIR_SEQUENCE.md` before changing runtime behavior.

`RECOVERY_REPAIR_SEQUENCE.md` governs the temporary repair order. This file governs the ownership boundaries that every repair must preserve or simplify. Recovery work must edit the authoritative implementation, consolidate useful rules into it, and retire overlapping schedulers, wrappers, executors, movement owners, or terminal-state writers.

## Canonical ownership chain

```text
runtime_event_registry
  -> runtime_tick_broker central-pulse
  -> bounded discovery or read-only readiness
  -> action_state_arbiter_0488 pure classification
  -> single_dispatcher_0510
  -> canonical_action_0744
  -> one physical executor
  -> canonical movement authority
  -> exact removal and persistent custody
  -> checked destination mutation
  -> exact source return or atomic generic storage
  -> one truthful terminal transition
```

Planning may inspect, score, propose, reserve, and publish identified work. It may not move priests, remove items, place entities, mutate fluids, or claim physical completion. Presentation and diagnostics may observe state but may not create or redirect work.

Protected calls are not success unless the documented API returns literal success. Periodic services must register through `runtime_tick_broker`; direct `script.on_nth_tick` fallback is not an accepted recovered path.

## Declarative installation boundary

`planning_constraints_0646.lua` must establish `runtime_tick_broker_0600:central-pulse` before hardener prearm.

The active `HARDENERS` table contains **32 retained hardeners**. Every listed installer must return literal `true`. A missing service, `nil`, `false`, exception, or incomplete finalizer is an installation failure and degrades the affected family.

The `RETIRED` table contains **23 source-preserved authorities**. It is not a secondary loader. A retired module may remain for historical comparison but may not install, register a cadence, wrap a canonical API, mutate pair state, or perform physical work.

The retired authorities are:

- `direct_acquisition_movement_lock_0650.lua`;
- `movement_vector_enforcer_0651.lua`;
- `movement_target_reconciler_0652.lua`;
- `movement_intent_authority_0654.lua`;
- `active_leaf_task_truth_0655.lua`;
- `construction_placement_authority_0656.lua`;
- `logistics_mineable_source_bridge_0657.lua`;
- `repair_executor_integrity_0673.lua`;
- `combat_repair_integrity_0676.lua`;
- `combat_repair_terminal_cleanup_0677.lua`;
- `machine_logistics_integrity_0682.lua`;
- `machine_logistics_candidate_recovery_0683.lua`;
- `machine_logistics_final_authority_0684.lua`;
- `item_family_integrity_0703.lua`;
- `fusion_reactor_readiness_guard_0727.lua`;
- `energy_readiness_diagnostics_0711.lua`;
- `energy_item_automation_guard_0722.lua`;
- `energy_automation_guard_install_assertion_0726.lua`;
- `rocket_silo_live_ownership_guard_0728.lua`;
- `artillery_train_validity_guard_0724.lua`;
- `fluid_turret_internal_buffer_guard_0731.lua`;
- `fluid_turret_proposal_integrity_0718.lua`;
- `fluid_turret_planner_integrity_0730.lua`.

## Construction placement authority

`construction_site_planner.lua` is the **placement authority**. It is read-only and owns placement effectiveness for defensive walls, gates, mines, turrets, artillery, radar, and roboports. It scores perimeter validity, threat alignment, coverage, spacing, support, power, charging access, and overlap with existing structures.

`construction_planner.lua` is the sole physical construction owner:

```text
construction request or scored placement
  -> construction_candidate_0338
  -> action_state_arbiter_0488
  -> single_dispatcher_0510
  -> construction-placement reservation
  -> literal-true movement
  -> exact placeable-item removal
  -> construction_custody_0338
  -> exact coordinate and direction revalidation
  -> entity placement or ghost revival
  -> source return or physical station return on failure
```

No placement helper may wrap `service_pair`, clear acquisition state, write movement storage, issue commands, consume stock, or place entities. Fluid and infrastructure planners must publish ordinary identified construction requests rather than patching the construction executor.

## Repair authority

`repair_executor_0516.lua` is the sole physical repair owner. It owns literal-true movement, repair reservations, exact repair-pack removal, `repair_pack_custody_0516`, verified health mutation, atomic refund, abort-after-refund retry, and canonical queue completion or failure.

`combat_repair_doctrine_0517.lua` owns tactical selection and cover assessment only. It delegates all physical effects and interruption cleanup to `0516`.

## Storage and transfer authority

`storage_role_authority_0686.lua` owns generic container-only storage. Assembler, furnace, lab, fuel, silo, turret, and other working inventories belong only to the exact specialized executor.

`inventory_transfer_integrity_0687.lua` records removed priest cargo as `inventory_transfer_custody_0687`. A blocked credit restores the exact original inventory; any shortfall remains persistent custody.

## Specialized logistics authority

The dispatcher owns physical execution for:

- machine logistics `0528`;
- visible item-family logistics `0702`;
- energy logistics `0707` with read-only readiness `0705`;
- rocket-silo logistics `0710` with read-only readiness `0709`;
- artillery logistics `0713` with read-only readiness `0712`;
- roboport repair-pack logistics `0715` with read-only readiness `0714`.

Each broker service performs bounded discovery or inspection only. Each physical executor owns a dedicated reservation family, literal-true movement, exact source removal, persistent family custody, checked target mutation, and exact return.

Hidden paired-proxy ammunition remains exclusively owned by `proxy_ammo_hardener_0649`; it must not be merged into visible item-family logistics.

Roboport placement is not owned by `0714` or `0715`. Those modules inspect and service existing roboports only. New roboport placement and effectiveness remain construction concerns.

## Fluid-turret authority

`fluid_turret_readiness_0716.lua` is the canonical read-only fluid-turret doctrine. It owns accepted attack-fluid inspection, connected-pipeline state, contamination detection, and corrected internal ammunition-buffer calculation using entity aggregate fluid minus local fluidbox contents. `fluid_turret_internal_buffer_guard_0731.lua` is retired.

`fluid_turret_connection_proposals_0717.lua` owns read-only source selection and exact endpoint validation. It resolves the selected source and turret fluidbox indexes, confirms exclusive fluid identity, verifies free interfaces, enforces force/surface identity and freshness, and publishes compatibility-safe proposals. `fluid_turret_proposal_integrity_0718.lua` is retired.

`fluid_turret_connection_planner_0719.lua` owns route search, route reservations, request identity, retries, and final connection verification:

```text
0716 corrected readiness
  -> 0717 exact safe proposal
  -> 0719 wrapper-free route plan
  -> identified construction_request
  -> construction_planner physical pipe placement
  -> construction_last_task_0338
  -> 0719 route advance, retry, abort, or connection completion
```

`0719` may publish one fixed-position pipe construction request at a time. It may not wrap construction, move priests, remove or insert items, create entities, clear construction tasks, or mutate fluid contents. `fluid_turret_planner_integrity_0730.lua` is retired.

## Canonical action and presentation

Every active pair must converge on one `canonical_action_0744` containing family, owner, phase, status, target or position, item, order identity, source, and timestamps.

Legacy `pair.mode`, `pair.target`, compatibility task fields, visuals, audio, GUI, maps, and diagnostics are mirrors or observers. They are not independent authorities.

`visual_intent_line_authority_0657.lua` remains active only as a read-only observer of `canonical_action_0744` or the canonical movement request.

## Evidence boundary

Source consolidation is not runtime proof. The current source still requires:

1. a complete successful `Source validation` run for one exact SHA;
2. Factorio 2.x new-save and protected `0.1.672` upgrade loads;
3. configuration-change and save/reload evidence;
4. the complete behavioral matrix, including placement effectiveness and fluid turret route recovery;
5. idle, active, and high-count profiler evidence;
6. digest-bound evidence validation and reviewed authorization;
7. qualified version advancement, deterministic packaging, and packaged-load testing.

Until accepted evidence exists, `info.json` remains `0.1.672`, no package is verified, and no release is authorized.
