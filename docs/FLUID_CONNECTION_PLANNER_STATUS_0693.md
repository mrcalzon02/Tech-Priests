# Reserved Fluid Input-Pipe Planner Status — 0.1.667

Scope: safe construction of ordinary pipe routes from an exact manual-machine fluid input port to an exact unconnected interface on a real compatible source segment. The planner consumes the read-only proposals produced by `fluid_network_doctrine_0689.lua` and delegates every physical placement to the existing station-bound construction executor.

## Current status

- Exact machine input-port endpoints: **implemented**
- Exact compatible source-segment interfaces: **implemented**
- Station-interior territory enforcement: **implemented**
- Collision-aware ordinary-pipe path search: **implemented**
- Adjacent incompatible-fluid rejection: **implemented**
- Existing compatible pipe adoption: **implemented**
- Shared construction reservation for every new tile: **implemented**
- Source-to-machine construction order: **implemented**
- Missing physical pipe-item request handoff: **implemented**
- Existing construction executor delegation: **implemented**
- Per-tile retries and terminal abort: **implemented**
- Reservation release on completion or abort: **implemented**
- Waiting-plan construction-slot ownership: **implemented**
- Rejected-proposal cooldown: **implemented**
- Automatic output-fluid routing: **not implemented by design**
- Underground pipe, pump, and tank planning: **not implemented by design**
- Direct entity placement by this planner: **zero by design**
- Fluid mutation by this planner: **zero by design**
- Runtime Factorio validation: **pending**

---

## Authority boundary

The planner owns only route selection, validation, reservation, sequencing, and construction-task seeding.

The existing `construction_planner.lua` remains the sole authority for:

1. Finding a physical pipe item in station-bound inventory.
2. Returning the priest to the Cogitator before using station inventory.
3. Removing exactly one physical pipe item.
4. Moving the priest to the selected tile.
5. Calling Factorio entity placement.
6. Refunding the pipe item when placement fails.
7. Recording the successful construction tile.

The fluid planner does not call `surface.create_entity`, does not remove inventory, and does not move the priest directly.

---

## Accepted proposal

A new plan may be created only from a current 0689 proposal satisfying all of these conditions:

- `action == connect-fluid-input`,
- `state == source-network-found`,
- the machine still exists,
- the source entity still exists,
- the source fluidbox index still identifies a compatible segment,
- the proposal is not older than twenty minutes,
- the pair has no unrelated construction task,
- combat, repair, consecration, direct acquisition, and machine custody do not currently block construction,
- the ordinary `pipe` item is technologically available.

Proposals for fluid output are deliberately ignored.

---

## Endpoint rules

### Machine endpoint

The machine endpoint is one of the exact unconnected target positions returned from the required input fluidbox's runtime pipe connections.

A visually adjacent tile does not qualify merely because it is close to the machine.

### Source endpoint

The source endpoint must be an exact unconnected interface on the real source entity and fluidbox index identified by 0689.

The source segment is revalidated before plan creation and before every construction step. If it contains another fluid, becomes filtered or locked to another fluid, or disappears, the plan aborts.

A source network with no available unconnected interface is not modified and does not generate a guessed endpoint.

---

## Route search

The current route search is intentionally conservative:

- four-directional Manhattan movement,
- ordinary `pipe` only,
- maximum 48 route tiles,
- maximum 4,096 searched nodes,
- every tile must remain inside the station's interior construction territory,
- every new tile must pass `surface.can_place_entity`,
- every tile is checked for adjacent fluid entities,
- any adjacent fluid segment containing or requiring another fluid rejects that tile,
- an existing compatible pipe or pipe-to-ground may be adopted rather than rebuilt.

The shortest successful candidate among all exact machine/source port combinations is selected.

---

## Construction order

New pipe tiles are built from the source interface toward the machine.

This intentionally leaves the final machine connection until the rest of the route exists. It avoids connecting the machine to a half-built isolated pipe chain and minimizes the time during which an input port is connected to an incomplete network.

Existing compatible route tiles are skipped automatically.

---

## Reservations

Every new route tile is claimed through the shared `construction` reservation category before the plan becomes active.

Reservation metadata includes:

- surface index,
- force index,
- required fluid,
- plan identity,
- planner source.

If any tile is already claimed by another pair, all reservations acquired for the proposed route are released and the plan is rejected.

Reservations are released when:

- the complete route is built,
- a source or machine disappears,
- source compatibility changes,
- a tile becomes invalid,
- a tile reaches the terminal retry limit,
- the plan is otherwise aborted.

---

## Pipe-item acquisition

When the current route tile requires a new pipe and no physical pipe item is available, the plan writes an exact item request:

- item: `pipe`,
- count: number of remaining new route tiles,
- source: `fluid-connection-planner-0691`,
- purpose: `construction-pipe`,
- plan identity and fluid metadata.

This request enters the existing item chain:

1. Search real known inventory through 0527.
2. Physically fetch pipe items into the Cogitator.
3. Fall through to production or acquisition only when no known source exists.
4. Resume construction when at least one physical pipe item exists.

The execution guard prevents the generic construction planner from selecting another placeable structure while the fluid plan is waiting for pipe items.

---

## Placement confirmation and retries

A tile advances only when:

- `last_construction_success_0338` matches the exact pipe entity and target tile, or
- a compatible pipe now physically exists at that tile.

Blocked placement, creation failure, or item-removal failure increments the tile retry count. After three failed attempts, the full route aborts and releases its reservations.

Missing pipe items do not count as a placement retry; they return the plan to the item-request state.

---

## Rejection cooldown

A recently rejected route proposal is suppressed for ten minutes after:

- no compatible route is found,
- pipe technology is unavailable,
- a live plan aborts.

This prevents the construction service from recomputing the same impossible route every tick. A successful active plan clears the rejection cooldown.

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/fluid_connection_planner_0691.lua` | Exact endpoint validation, conservative BFS routing, compatibility checks, tile reservation, pipe-item requests, sequential task seeding, completion, abort, and diagnostics |
| `tech-priests_src/scripts/core/fluid_connection_execution_guard_0692.lua` | Construction-slot ownership while waiting for pipe items and cooldown of repeatedly rejected proposals |

## Loader changes

`planning_constraints_0646.lua` now installs:

1. `fluid_network_doctrine_0689`,
2. `fluid_connection_planner_0691`,
3. `fluid_connection_execution_guard_0692`,
4. final movement-vector enforcement.

The planners wrap the already existing construction service. They do not register a second construction pulse or create another placement executor.

---

## Automatic diagnostics

### `PAIR-DUMP-0468 FLUID-CONNECTION-0691`

Reports:

- `ordinary_pipe_only=true`,
- `input_routes_only=true`,
- `direct_placements=0`,
- `fluid_mutations=0`,
- plans created/completed/aborted,
- tiles planned/reserved/completed,
- missing-pipe item requests,
- reservation denials,
- current pair plan, fluid, tile index, machine, and source.

### `PAIR-DUMP-0468 FLUID-CONNECTION-GUARD-0692`

Reports:

- construction-slot holds while waiting for pipe items,
- rejected-proposal cooldown hits,
- rejection cooldown registrations.

---

## Explicit non-goals in 0.1.667

The planner refuses to automate any of the following:

- fluid output networks,
- output sink selection,
- underground pipe pairs,
- pump orientation or pressure management,
- storage-tank placement,
- offshore-pump placement,
- cross-station territory routing,
- routing through the defense perimeter,
- clearing rocks or buildings merely to shorten a pipe route,
- crossing a segment carrying another fluid,
- flushing or replacing contaminated fluid,
- changing a machine recipe,
- direct fluidbox mutation,
- direct pipe entity placement outside the construction executor.

---

## Runtime validation scenarios still pending

1. One-tile water connection from tank to assembler.
2. Multi-tile obstacle-free water connection.
3. Route around a solid obstacle.
4. No route inside station territory.
5. Route would cross the defense perimeter.
6. Source segment disappears before construction.
7. Machine disappears before construction.
8. Source segment changes to another fluid.
9. Adjacent incompatible fluid pipe blocks a proposed tile.
10. Existing compatible pipe tiles are adopted.
11. Existing compatible pipe-to-ground tiles are adopted.
12. Existing wrong-fluid pipe rejects the route.
13. Two stations propose the same route tiles; only one reserves them.
14. Partial reservation acquisition releases earlier claims after denial.
15. No pipe stock creates an exact pipe request.
16. 0527 fetches pipes from a real chest and construction resumes.
17. Pipe production fallback resumes the same plan.
18. Waiting pipe plan prevents unrelated generic construction.
19. Repair or combat blocks new plan creation.
20. Active machine custody blocks new plan creation.
21. Construction physically removes exactly one pipe per new tile.
22. Placement failure refunds the pipe item.
23. Three terminal failures abort the route.
24. Abort releases every reservation.
25. Completion releases every reservation.
26. Source-to-machine tile order is observed.
27. Final tile connects the machine only after the rest of the route exists.
28. Completed route triggers forced 0689 reinspection.
29. Rejected proposal is not recomputed each tick during cooldown.
30. No output proposal creates a construction plan.
31. No underground pipe, pump, or tank is automatically placed.
32. No direct entity placement originates from 0691.
33. No fluid mutation originates from 0691 or 0692.
34. Save/load resumes an active route at the correct tile.
35. Save/load while waiting for pipes preserves item request and reservations.
36. Space Age multi-fluid machines reject unsafe adjacency conservatively.

---

## Known limitations and risks

1. The adjacency check is deliberately broad and may reject a safe route near a multi-fluid machine. False rejection is preferable to mixing segments.
2. Ordinary pipe routing cannot cross large obstacles efficiently without underground pipes.
3. The BFS is bounded and may reject a route that exists beyond the configured search budget.
4. A source segment may contain enough fluid when planned but become empty during construction; 0689 will report the resulting waiting state after connection.
5. Output-fluid routing requires proof of a real compatible sink with sufficient capacity and remains a separate development phase.
6. Runtime semantics of unusual modded fluidboxes and connection positions still require Factorio testing.

---

## Completion estimate

- Safe ordinary input-pipe route implementation: **100%**
- Physical construction delegation: **100%**
- Reservation and item-request integration: **100%**
- Output network planning: **0%**
- Underground/pump/tank planning: **0%**
- Static source review: completed
- External Lua parser: pending
- Factorio load test: pending
- Runtime scenarios: **0 of 36 executed**

**Overall confidence: approximately 70%.**

The input-pipe implementation is complete, but runtime validation is essential because fluidbox connection geometry varies substantially across base, Space Age, and modded machines.

---

## Next sequential development target

Implement a safe output-fluid sink doctrine before any output pipe construction:

1. Identify only real same-fluid sinks or empty filtered storage segments.
2. Prove available capacity for the expected machine output.
3. Reject inputs, source-only boxes, wrong-fluid segments, and unfiltered empty segments that could later mix fluids.
4. Produce read-only output-sink proposals first.
5. Only after the sink doctrine is stable should output pipe construction reuse the 0691 reservation and construction model.
