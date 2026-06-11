# Runtime Authority Continuity

Read this file and `STANDARDS_AND_PRACTICES.md` before changing runtime behavior.

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

## Next construction migration

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
   completion signal, and diagnostics.
2. Implement or repair the canonical path.
3. Gate or demote the matching legacy controller.
4. Run focused live tests.
5. Remove obsolete wrappers only after the canonical path is proven.

Do not restore an independent legacy pulse after dispatcher ownership exists.
