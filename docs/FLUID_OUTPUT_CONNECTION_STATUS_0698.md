# Compatible-Sink Output Pipe Construction Status — 0.1.669

Scope: physically construct an ordinary pipe route from a manual machine's exact unconnected output port to a sink previously proven safe by `fluid_output_sink_doctrine_0694.lua`.

## Current status

- Compatible-sink proposal requirement: **implemented**
- Sink identity/capacity revalidation: **implemented**
- Free sink interface required at plan creation: **implemented**
- Consumed sink interface accepted during later route steps: **implemented**
- Machine output segment contamination checks: **implemented**
- Input-route precedence: **implemented**
- Station-interior route enforcement: **implemented**
- Conservative adjacent-fluid checks: **implemented**
- Ordinary-pipe BFS routing: **implemented**
- Existing compatible route adoption: **implemented**
- Complete route reservation: **implemented**
- Surface-scoped positional reservation keys: **implemented**
- Sink-to-machine construction order: **implemented**
- Physical pipe-item request handoff: **implemented**
- Construction-slot ownership while waiting: **implemented**
- Existing construction executor delegation: **implemented**
- Per-step sink-capacity validation: **implemented**
- Completion/abort reservation cleanup: **implemented**
- Direct fluid mutation: **zero by design**
- Direct pipe placement by 0696: **zero by design**
- Runtime validation: **pending**

---

## Plan admission

A plan may begin only when:

- 0694 produced `compatible-sink-found`,
- machine and sink entities remain valid,
- the proposal is no more than twenty minutes old,
- the sink still accepts input or bidirectional flow,
- the sink contains only the expected fluid or remains explicitly filtered/locked to it,
- free segment capacity remains sufficient for at least one expected craft,
- a free sink interface exists,
- an actionable input-fluid connection proposal does not still have priority,
- no input pipe plan, unrelated construction task, combat, repair, consecration, direct acquisition, or machine custody blocks the construction slot,
- ordinary pipe technology is available.

Input routes are intentionally completed before output routes when both are actionable.

---

## Revalidation lifecycle

### At plan creation

The sink must expose a real unused interface. That exact interface becomes the route endpoint.

### During construction

After the first route pipe attaches to the sink, that interface is expected to stop being unused. Later revalidation therefore continues to require:

- valid sink entity and fluidbox,
- input capability,
- same-fluid or explicit filter identity,
- no contamination,
- sufficient free capacity,

but no longer requires the already-consumed interface to remain unused.

This prevents an expected route attachment from aborting its own plan.

### Before every tile

The planner also rechecks:

- machine output fluidbox validity,
- machine output contamination,
- sink/output segment identity,
- current tile territory,
- collision state,
- adjacent fluid compatibility.

If the sink and machine become part of the same segment through external construction, the plan stops and releases its remaining reservations.

---

## Route policy

- Ordinary `pipe` only.
- Four-directional Manhattan BFS.
- Maximum 48 route tiles.
- Maximum 4,096 searched nodes.
- Entire route stays in the Cogitator interior.
- No defense-perimeter crossing.
- No obstacle destruction to shorten the route.
- No adjacent wrong-fluid segment.
- No ambiguous empty unfiltered neighboring segment unless it is an endpoint or already part of the selected sink/output segment.
- Existing same-fluid, explicitly typed, or selected-segment pipes may be adopted.

The selected route is built from the sink toward the machine. The final placement connects the machine only after the downstream route exists.

---

## Sink protection

Construction aborts if the sink:

- disappears,
- loses its fluidbox,
- becomes output-only,
- becomes contaminated,
- changes its filter or lock,
- becomes empty and unfiltered,
- loses sufficient free capacity.

No fluid is drained, flushed, moved, or deleted in response. The plan simply releases its claims and stops.

---

## Physical pipe accounting

When the route lacks pipe items, 0696 writes an exact remaining-count request using the existing item logistics chain.

The ordinary construction executor then:

1. Returns the priest to station inventory.
2. Removes one physical pipe item.
3. Walks to the reserved tile.
4. Places one pipe entity.
5. Refunds the item if placement fails.
6. Records the exact successful tile.

0696 advances only after matching construction success or observing a compatible physical pipe at the tile.

---

## Reservations

Every new route tile is reserved before construction begins. The 0.1.669 reservation hardener adds surface identity to positional keys, preventing the same `x,y` coordinates on different surfaces from colliding.

Entity and unit-number reservation keys remain unchanged.

All route reservations are released on completion or abort.

---

## Files added or changed

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/fluid_output_connection_planner_0696.lua` | Output route planning, sink revalidation, reservations, item requests, task sequencing, completion/abort, diagnostics |
| `tech-priests_src/scripts/core/reservation_position_scope_0697.lua` | Surface-scoped positional reservation keys |
| `tech-priests_src/scripts/core/planning_constraints_0646.lua` | Ordered hardener activation |

---

## Automatic diagnostics

### `PAIR-DUMP-0468 FLUID-OUTPUT-CONNECTION-0696`

Reports:

- `ordinary_pipe_only=true`,
- `compatible_sink_required=true`,
- `direct_placements=0`,
- `fluid_mutations=0`,
- plans created/completed/aborted,
- tiles planned/reserved/completed,
- pipe-item requests,
- current fluid, machine, sink, tile, progress, and rejection cooldown.

### `PAIR-DUMP-0468 RESERVATION-SCOPE-0697`

Reports the number of surface-scoped positional keys issued.

---

## Explicit non-goals

0.1.669 still refuses:

- automatic creation of a sink when none exists,
- empty unfiltered tank selection,
- venting or deleting output fluid,
- underground pipes,
- pump or storage-tank construction,
- pressure/throughput optimization,
- cross-station routes,
- recipe changes,
- direct fluidbox writes,
- direct pipe entity creation by the route planner.

---

## Runtime validation scenarios still pending

1. Same-fluid storage tank output route.
2. Empty filtered tank output route.
3. Sink interface consumed after first tile without false abort.
4. Sink fills before first tile and plan aborts.
5. Sink fills midway and plan aborts.
6. Sink contamination before construction.
7. Sink contamination midway.
8. Sink filter changes before construction.
9. Empty filtered sink loses its filter.
10. Sink entity is destroyed.
11. Machine entity is destroyed.
12. Machine output becomes contaminated.
13. Input proposal takes precedence over output proposal.
14. Input plan blocks output plan.
15. Same `x,y` reservations on different surfaces do not conflict.
16. Same-surface overlapping routes do conflict.
17. Partial route reservation denial releases earlier claims.
18. Missing pipes trigger an exact remaining-count request.
19. 0527 fetches physical pipes and route resumes.
20. Pipe production fallback resumes route.
21. Waiting output plan owns the construction slot.
22. One physical pipe is consumed per new tile.
23. Placement failure refunds the pipe.
24. Three tile failures abort the plan.
25. Abort releases all route reservations.
26. Completion releases all route reservations.
27. Route builds sink-to-machine.
28. Machine is connected only on the final tile.
29. Existing compatible tiles are adopted.
30. Existing empty unfiltered pipe is rejected unless proven part of the selected segment.
31. Adjacent wrong-fluid network rejects the route.
32. Multi-fluid machine ports are conservatively rejected when adjacency is ambiguous.
33. Completed route triggers forced 0689/0694 reinspection.
34. No fluid mutation occurs.
35. No direct placement originates from 0696.
36. Save/load resumes the exact route index and reservations.

---

## Known limitations

1. Multi-fluid machines may have several ports close enough that a single pipe tile could geometrically touch more than the intended fluidbox. Current checks are conservative but need a dedicated shared-port collision validator.
2. Ordinary pipes cannot route through large obstacles efficiently.
3. Throughput is not modeled; capacity is proven, but sustained flow may still be inadequate.
4. The destination may be a compatible consumer or storage segment; strategic production-chain intent is not inferred.
5. Modded fluidbox geometry needs runtime evidence.

---

## Completion estimate

- Proven-sink output route implementation: **100%**
- Physical construction delegation: **100%**
- Surface-scoped reservation integrity: **100%**
- Runtime scenarios: **0 of 36 executed**

**Overall confidence: approximately 68%.**

---

## Next sequential development target

Add a shared fluid-port collision validator for both input and output plans. It must prove that each endpoint tile connects only to the intended fluidbox or to fluidboxes compatible with the same fluid, rejecting shared-port geometry that could join different recipe fluids when a pipe is placed.
