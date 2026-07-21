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

Action classification must become and remain read-only. Planning may inspect, score, propose, reserve, and publish identified work. It may not move priests, remove items, place entities, mutate fluids, or claim physical completion. Presentation and diagnostics may observe state but may not create or redirect work.

Protected calls are not success unless the documented API returns literal success. Periodic services must register through `runtime_tick_broker`; direct `script.on_nth_tick` fallback is not an accepted recovered path.

## Declarative installation boundary

`planning_constraints_0646.lua` must establish `runtime_tick_broker_0600:central-pulse` before hardener prearm.

The active `HARDENERS` table contains **26 retained hardeners**. Every listed installer must return literal `true`. A missing service, `nil`, `false`, exception, or incomplete finalizer is an installation failure and degrades the affected family.

The `RETIRED` table contains **46 source-preserved authorities**. It is not a secondary loader. A retired module may remain for historical comparison but may not install, register a cadence, wrap a canonical API, mutate pair state, or perform physical work.

`pair_link_hardening_0495` is retired. Reverse-map truth, conservative nearby orphan rebinding, and missing-priest observation are native to broker-owned `priest_lifecycle_authority_0499`; replacement remains disabled.

`priest_lifecycle_seal_0500` is retired. Valid-priest preservation and destruction/replacement authorization are native to `0499`; original creation, removal, respawn, mobility, orphan, and platform functions now check that authority before mutating physical priest state.

`priest_vanish_guard_0501` is retired. `0513` owns protected-target and physical-output truth, `0490` is legacy mining/no-spill safety only, and `0499` owns disappearance observation and pair integrity.

`mobility_recovery_contract_0506` and `movement_recovery_authority_0508` are retired together. Visible movement belongs to `movement_controller`, direct work to `0513`, pair observation to `0499`, and controlled missing recovery temporarily to `0503`.

`priest_recovery_safety_0503` is now narrow and broker-owned. It may request only the exact `controlled-missing-recovery-0503` lease after `0499` has observed a missing priest. The generated canonical respawn consumes that one-shot lease, restores every reverse map, and reports recovery to `0499` without recall, teleport, mobility replacement, or movement commands.

`task_pair_audit_0498` is retired. `order_queue_0469` now owns indefinite missing-priest pause and explicit recovery resume, while `0499` drives those transitions from observed lifecycle state. Direct-target, map, removal, respawn, command, and timer wrappers are gone.

`behavior_execution_doctrine_0505` is retired. `emergency_production_executor_0514` owns facility-first production, visible timed station fallback, strict recipe transactions, movement, custody, and terminal completion. Direct acquisition belongs to `0513`; recovery belongs to `0499`/`0503`; the old visual, command, and timer surfaces are removed.

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
- `movement_cadence_contract_0518.lua`;
- `combat_magos_movement_authority_0472.lua`;
- `movement_bounds_contract_0511.lua`;
- `movement_enforcement_0566.lua`;
- `efficiency_economy_0572.lua`;
- `efficiency_economy_0577.lua`;
- `direct_acquisition_recall_guard_0632.lua`;
- `ground_route_authority_0633.lua`;
- `priest_vanish_guard_0502.lua`;
- `behavior_execution_doctrine_0505.lua`;
- `fluid_output_sink_doctrine_0694.lua`;
- `reservation_position_scope_0697.lua`;
- `fluid_connection_execution_guard_0692.lua`;
- `fluid_output_connection_planner_0696.lua`;
- `fluid_port_collision_validator_0699.lua`;
- `fluid_port_context_guard_0700.lua`;
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

## Movement cadence authority

`movement_controller.lua` is the sole ground movement and cadence authority. It owns request identity, destination, owner, priority, TTL, long-action lease duration, retarget suppression, command refresh, active-request service, and displacement sampling. Its two services require `runtime_tick_broker`; registry and direct `script.on_nth_tick` fallbacks are forbidden.

`movement_cadence_contract_0518.lua` is retired. Its useful lease and churn rules are consolidated into the movement request record. It may not wrap `tech_priests_request_movement_0418`, create `movement_lease_0518`, install a command, or register a service.

## Combat proxy and command-territory authority

`command_hierarchy_0480.lua` owns direct-subordinate topology and native command-territory membership. The legacy radar function reads that authority directly. `movement_controller.lua` owns proxy-prime throttling and visible combat positioning. `behavior_mutex_0466.lua` owns force-combat cooldown and staggering. `proxy_turret_alignment.lua` owns hidden-proxy identity, physical alignment, attachment recovery, and broker-driven target sustain.

`combat_magos_movement_authority_0472.lua` is retired and inert. It may not wrap radar, movement, combat entry points, visible commands, diagnostics, or timers.

## Retired station-side vanish quarantine

`priest_vanish_guard_0502.lua` is retired. It may not duplicate direct acquisition, wrap movement requests, issue engine commands, own task/mode state, run a watchdog, or install commands. Missing-priest observation and controlled rescue remain with the still-active lifecycle/recovery authorities pending their consolidation.

`behavior_stack_cleanup_0509.lua` is broker-only passive maintenance for pair reverse maps and UI/cascade debounce. It no longer requires, disables, reports, or wraps `0502`, acquisition executors, or movement APIs.

## Visible ground route and explicit loader authority

`movement_controller.lua` owns visible ground route chunking and clears retired `0632`/`0633` pair state during installation. `direct_acquisition_pulse_0631.lua` is broker-only and does not install a recall wrapper or command. `direct_acquisition_recall_guard_0632.lua` and `ground_route_authority_0633.lua` are retired and inert.

The unrelated `0634`–`0643` repair modules formerly hidden behind `0633` are now loaded explicitly in `control.lua`, preserving behavior while removing the dependency chain.

## Movement economy boundary

Ground-priest transit remains physical regardless of player observation. `efficiency_economy_0572.lua` is retired because unseen teleportation violates physical honesty. Executor work is budgeted by named broker services rather than service-pair wrappers. `efficiency_economy_0577.lua` is retired; its useful low-priority path budget is applied inside `movement_controller` immediately before an engine command.

## Authority-corridor route planning

`authority_corridor_pathing_0574.lua` is an observer-only authorization and waypoint planner. It reads the authorized-pair topology from `0573`, determines whether a destination is legal, and may propose a superior-station waypoint plus the preserved final destination. It does not replace the movement API, clear pair movement state, command priests, return them home, register a timer, or install commands.

`movement_controller.lua` consumes the proposal before accepting a request and remains the sole owner of request state, rejection, return routing, and engine commands.

## Ground enforcement and Void backend authority

`movement_controller.lua` owns the public request, stop, status, command-routing, ground envelope, stale-request rejection, and overleash-return paths. `void_movement_authority_0630.lua` is a specialized broker-only stepped-relocation backend reached through the controller for Void/platform pairs; it does not replace global movement APIs or patch ground modules.

`movement_enforcement_0566.lua` is retired and inert. `control.lua` installs the Void backend and direct-acquisition pulse explicitly instead of through a hidden parent installer chain.

## Direct acquisition bounds authority

`direct_acquisition_executor_0513.lua` owns tier-capped target bounds, authority-corridor allowance, active-task overleash return, target movement, extraction, custody, return, deposit, replan, and terminal state. `runtime_command_cleanup_0720.lua` removes the exact obsolete 61-tick direct-gather route and the historical movement-bounds command.

`movement_bounds_contract_0511.lua` is retired and inert. It may not wrap target discovery, movement requests, executors, legacy direct functions, diagnostics, commands, or timers.

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

## Standard-fluid authority

`fluid_network_doctrine_0689.lua` is the canonical read-only standard-fluid authority. It owns exact recipe and machine context, fluidbox and segment identity, shared-port collision validation, compatible source and sink discovery, proposal freshness, and exact input/output proposals. Its broker service is `fluid_network_doctrine_0689` and must report `acted=0`.

`work_reservations.lua` natively owns surface-scoped positional reservation keys. `reservation_position_scope_0697.lua` is retired and may not wrap `target_key` or `claim`.

`fluid_connection_planner_0691.lua` is the sole standard-fluid route coordinator:

```text
0689 exact machine context and safe proposal
  -> 0691 wrapper-free input/output route plan
  -> standard-fluid-pipe-route reservations
  -> identified construction_request
  -> construction_planner physical pipe placement
  -> construction_last_task_0338
  -> 0691 route advance, retry, abort, or connection completion
```

`0691` owns route search, route reservations, rejection cooldowns, retries, request identity, and final connection verification. It may not wrap construction, move priests, remove or insert items, create entities, clear construction tasks, or mutate fluid contents.

The retired standard-fluid wrappers are `fluid_output_sink_doctrine_0694.lua`, `fluid_connection_execution_guard_0692.lua`, `fluid_output_connection_planner_0696.lua`, `fluid_port_collision_validator_0699.lua`, and `fluid_port_context_guard_0700.lua`. Their useful rules are consolidated into `0689` and `0691`.

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
4. the complete behavioral matrix, including placement effectiveness, standard fluid route recovery, and fluid turret route recovery;
5. idle, active, and high-count profiler evidence;
6. digest-bound evidence validation and reviewed authorization;
7. qualified version advancement, deterministic packaging, and packaged-load testing.

Until accepted evidence exists, `info.json` remains `0.1.672`, no package is verified, and no release is authorized.


## Priest-death and re-imprint authority

`pair_death_and_respawn.lua` is source-preserved and inert. `priest_lifecycle_authority_0499` is the sole priest-death event owner and enters the existing generated `0298` re-imprint state before linked-removal cleanup can run. The generated `0298` code remains a state, text, and rendering adapter only: it does not wrap ensure/respawn and owns no timer. Broker-owned `priest_recovery_safety_0503` waits until `finish_tick`, then uses the same short-lived one-shot replacement lease and canonical respawn used for an ordinary proven disappearance. `station_pair_recovery_0363` remains a separate unresolved recovery layer and is not made authoritative by this retirement.
