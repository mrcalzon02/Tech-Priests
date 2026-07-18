# Runtime Authority Continuity

Read this file, `STANDARDS_AND_PRACTICES.md`, and `../../RECOVERY_REPAIR_SEQUENCE.md` before changing runtime behavior.

`../../RECOVERY_REPAIR_SEQUENCE.md` governs the temporary repair order. This file governs the runtime ownership boundaries that every repair must preserve or simplify. Recovery work must replace, demote, or consolidate existing authorities rather than add another parallel controller.

## Authority boundaries

```text
Runtime broker decides when services run.
Work queue stores shared world work.
Reservation claims a target or site.
Order queue stores per-pair intent.
Dispatcher selects one action family.
Executor performs physical work.
Reporters observe state.
```

- Lifecycle code may validate, relink, or respawn pairs. It may not select work.
- Planning code may describe needs and submit work. It may not move priests,
  consume stock, place entities, or claim completion.
- Movement belongs to `movement_controller.lua` and its documented exceptions.
- Generic inventory deposits use safe station/container storage. Machine
  inventories are touched only by machine-specific executors.
- GUI, audio, visuals, scheduler maps, and behavior monitors never create work.
- Action classification must become and remain read-only. It may identify a family but may not clear tasks, fail orders, request movement, or mutate presentation.
- A hardener or integrity layer may enforce an invariant, but it must not become a second scheduler, executor, movement owner, or permanent substitute for repairing the canonical authority.

## Recovery ownership target

Every active pair must converge on one canonical action record containing one family, owner, phase, physical target, movement target, reservation, custody record, priority, and terminal state.

Legacy `pair.mode`, `pair.target`, broad dispatcher status, and compatibility fields should become generated mirrors of that record rather than independent writable authorities.

## Current migration truth

Dispatcher-owned physical families:

- direct acquisition;
- station/emergency production;
- repair and combat repair;
- consecration.

Partially migrated:

- machine logistics is a dispatcher wrapper with its own phase state;
- combat still has legacy ownership paths;
- construction planning is broker-driven, but physical construction remains in
  legacy construction modules;
- defense planning and placement still run through `defense_perimeter.lua` in the
  legacy `tick_pair` chain.

The recovery sequence additionally requires the order queue, event registry, broker result contract, hardener installation phases, and action arbiter to be corrected before another behavior family is expanded.

## Recovery migration order

1. Protect physical item and accepted-order truth.
2. Repair event, lifecycle, hardener, and broker ownership.
3. Separate pure classification from scheduler mutation and presentation.
4. Establish one canonical per-pair action record.
5. Demote legacy controllers family by family after focused runtime proof.
6. Reduce periodic routes, broad scans, wrapper depth, and direct state writers.
7. Complete migration, save/load, overlap, interruption, and packaged evidence.

## Construction migration after base recovery

Construction migration remains required, but it may resume only after the earlier recovery stages pass:

1. Make production, defense, and station-expansion planners submit construction
   work through the shared queue.
2. Reserve sites before movement or stock consumption.
3. Add one dispatcher-owned construction executor.
4. Demote legacy physical placement routines to data/site helpers.
5. Configure machine recipes after placement.
6. Feed configured production nodes through machine logistics until downstream
   demand or science completion is satisfied.

The shared planning policy is `planning_constraints_0646.lua`. Future construction
work must consume it rather than duplicating technology or territory checks.

## Migration method

For one behavior family at a time:

1. Identify scheduler input, action classification, movement contract, executor,
   completion signal, diagnostics, persistent state, and every legacy writer.
2. Update the relevant Mermaid/function map before or with implementation so the
   intended replacement boundary is explicit.
3. Implement or repair the canonical path.
4. Gate or demote the matching legacy controller.
5. Run focused static and live tests, including save/load and terminal cleanup.
6. Remove obsolete wrappers only after the canonical path is proven.
7. Record the exact evidence state in `../../docs/DEVELOPMENT_HISTORY.md` and set
   the next active scenario in `CURRENT_TESTING_GOALS.md`.

Do not restore an independent legacy pulse after dispatcher ownership exists.