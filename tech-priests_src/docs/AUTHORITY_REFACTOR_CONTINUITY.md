# Runtime Authority Continuity

Read this file, `STANDARDS_AND_PRACTICES.md`, and `../../RECOVERY_REPAIR_SEQUENCE.md` before changing runtime behavior.

`../../RECOVERY_REPAIR_SEQUENCE.md` governs the temporary repair order. This file governs the runtime ownership boundaries that every repair must preserve or simplify. Recovery work must replace, demote, retire, or consolidate existing authorities rather than add another parallel controller.

## Authority boundaries

```text
Runtime event registry owns Factorio event and lifecycle composition.
Runtime broker owns periodic service cadence.
Broker discovery may cache bounded candidates but may not execute physical work.
Work queue stores shared world work.
Reservation claims a target or site.
Order queue stores truthful per-pair intent.
Action arbiter classifies without mutation.
Single dispatcher publishes canonical_action_0744 and selects one owned family.
One executor performs physical work for that family.
Movement controller or the documented Void authority owns movement.
Persistent custody records physically removed items.
Atomic storage owns final deposit or exact return.
Visuals, audio, GUI, maps, and diagnostics observe state.
```

- Lifecycle code may validate, relink, or respawn pairs. It may not select work.
- Planning code may describe needs and submit work. It may not move priests, consume stock, place entities, or claim completion.
- Generic inventory deposits use safe station or container storage. Machine inventories are touched only by machine-specific executors.
- Action classification is read-only. It may identify a family but may not clear tasks, fail orders, request movement, mutate presentation, or write pair targets and modes.
- A hardener may enforce an invariant, but it must not become a second scheduler, executor, movement owner, or permanent substitute for repairing the canonical authority.
- A protected call is not success unless the documented contract explicitly returns success.
- A periodic service must register through `runtime_tick_broker`; direct `script.on_nth_tick` fallback is not an accepted recovered path.

## Broker-before-prearm installation

`planning_constraints_0646.lua` must establish the canonical registry-backed broker route `runtime_tick_broker_0600:central-pulse` before installing any hardener.

The active install sequence is the declarative `HARDENERS` table. It currently contains **41 retained hardeners**. Every listed installer must return literal `true`. `nil`, `false`, an exception, a missing broker service, or an incomplete finalizer is a failed installation. The final audit records the failure and degrades the affected family instead of silently treating it as protected.

The declarative `RETIRED` table contains **14 source-preserved authorities**. It is not an alternate loader. A retired module may remain for history and comparison, but it may not install, register a cadence, wrap a canonical API, or mutate runtime state.

## Retired parallel authorities

The following source files are deliberately absent from the active hardener table:

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
- `item_family_integrity_0703.lua`.

They were retired because they independently scheduled work, wrote movement-controller tables, issued commands, redirected valid requests, cleared queue internals, rewrote pair targets or modes, synthesized success, spilled refunds, transferred products without canonical carried custody, or wrapped a canonical executor with another terminal owner.

Their replacement path is:

```text
broker-budgeted discovery
  -> read-only action_state_arbiter_0488
  -> single_dispatcher_0510
  -> canonical_action_0744
  -> one owned executor
  -> canonical movement owner
  -> exact physical removal
  -> persistent custody
  -> atomic storage or exact return
  -> one truthful terminal queue transition
```

## Repair authority

`repair_executor_0516.lua` is the sole physical repair authority. It owns literal-true movement requests, shared repair reservations, exact repair-pack removal, `repair_pack_custody_0516`, verified health mutation, atomic refund, abort-after-refund retry, and canonical queue completion or failure.

`combat_repair_doctrine_0517.lua` owns tactical selection only. It may evaluate enemy pressure, allied turret readiness, armed priest cover, cluster ownership, and target priority. It delegates every physical effect to `repair_executor_0516` and calls that executor's `abort_pair` when cover or target validity is lost.

No repair wrapper may directly complete queue internals, clear another module's task state, spill a pack, issue a movement command, or run an independent cadence.

## Machine logistics authority

`logistics_machine_fulfillment_0528.lua` owns visible assembler and furnace service. Its broker service may discover candidates only. `action_state_arbiter_0488` reads the cached candidate, and `single_dispatcher_0510` calls `service_pair`.

The executor owns target reservation, literal-true movement, exact generic-storage removal, specialized machine input/output/fuel access, persistent `machine_logistics_custody_0528`, exact return, and terminal cleanup. The retired `0682`, `0683`, and `0684` wrappers may not be reactivated.

## Item-family and proxy-ammunition authority

`proxy_ammo_hardener_0649.lua` exclusively owns hidden paired-proxy ammunition. It remains broker-owned because the hidden proxy is not a visible dispatcher work target. It must preserve exact station removal, checked proxy insertion, atomic remainder return, and persistent `proxy_ammo_refund_custody_0649`.

`item_family_logistics_0702.lua` owns only visible unautomated ammunition turrets and laboratories:

```text
item_family_discovery_0702
  -> item_family_candidate_0702
  -> action_state_arbiter_0488 recommendation
  -> single_dispatcher_0510
  -> item_family_logistics_0702.service_pair
  -> literal-true movement
  -> exact home-source removal
  -> item_family_custody_0702
  -> visible turret-ammo or lab-input insertion
  -> exact source return or atomic station deposit
```

The broker service is discovery-only. It may cache a candidate but may not move a priest or transfer an item. The classifier may read `recommend_action` but may not require the module, mutate candidate state, or execute work. The dispatcher is the sole executor caller.

Ammunition compatibility, current-research validation, stale-task interruption, custody return, reservations, and terminal cleanup are consolidated into `0702`. `item_family_integrity_0703.lua` is retired and may not wrap `install`, `service_pair`, reservations, requests, task items, phases, or terminal state.

Hidden proxy ammunition must not be added back to `0702`; visible turret/lab logistics must not be added to `0649`.

## Generic storage and priest cargo

`storage_role_authority_0686.lua` is the canonical generic storage owner. Generic station storage is restricted to container or trunk inventories. Assembler input/output, furnace source/result, laboratory input, and fuel inventories belong only to dedicated family executors.

`inventory_transfer_integrity_0687.lua` removes accidental priest cargo before crediting storage and records `inventory_transfer_custody_0687`. An exact deposit clears custody. A blocked deposit restores the same stack to the original physical inventory. Any restore shortfall remains persistent `removed-not-credited` custody.

## Retained presentation layer

`visual_intent_line_authority_0657.lua` remains active only as a read-only presentation layer. It reads `canonical_action_0744` or the current canonical movement request, reports truthful draw counts, and may not create work or mutate pair behavior.

## Canonical action target

Every active pair must converge on one `canonical_action_0744` record containing the selected family, owner, phase, physical target or position, order identity, item, source, status, and timestamps.

Legacy `pair.mode`, `pair.target`, broad dispatcher status, and compatibility fields should become generated mirrors of canonical state rather than independent writable authorities.

## Current migration truth

Dispatcher-owned recovered physical families:

- direct acquisition;
- station and emergency production;
- repair and combat repair;
- consecration;
- machine logistics;
- visible item-family logistics.

Specialized or partially migrated families still requiring focused audit:

- construction planning remains broker-driven, but the retired `0656` movement/preemption wrapper is no longer active;
- defense planning and placement still pass through legacy defense paths;
- combat has remaining compatibility ownership paths;
- energy, silo, artillery, roboport, fluid, and fluid-turret families remain specialized leaves pending consolidation and live proof;
- ordinary and Void movement require separate runtime evidence.

## Construction migration after base recovery

Construction migration may resume only by simplifying the existing chain:

1. planners submit construction work through the shared queue;
2. sites are reserved before movement or stock consumption;
3. one dispatcher-owned construction executor performs placement;
4. legacy placement routines become data or site helpers;
5. machine recipes are configured only after successful placement;
6. resulting production nodes enter canonical machine logistics.

The shared planning policy is `planning_constraints_0646.lua`. Future construction work must consume it rather than duplicating technology or territory checks.

## Migration method

For one behavior family at a time:

1. identify scheduler input, classification, movement contract, executor, completion signal, diagnostics, persistent state, and every legacy writer;
2. update the current Mermaid authority map before or with implementation;
3. repair the canonical path;
4. gate, demote, or retire the conflicting controller;
5. add source checks that prevent the retired ownership from returning;
6. run focused static and live tests, including save/load and terminal cleanup;
7. record the exact evidence state in `../../docs/DEVELOPMENT_HISTORY.md` and set the next active scenario in `CURRENT_TESTING_GOALS.md`.

Do not restore an independent legacy pulse after dispatcher or broker ownership exists. Source implementation remains distinct from CI, Factorio load, migration, save/reload, behavioral, profiler, package, and publication evidence.
