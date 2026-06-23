# Real Fluid-Network Doctrine Status — 0.1.666

Scope: manual production machines with fluid ingredients or fluid products, the relationship between 0528 item logistics and Factorio's native fluid simulation, and the prohibition against synthetic or teleported fluid transfers.

## Current status

- Recipe fluid input detection: **implemented**
- Recipe fluid output detection: **implemented**
- Actual machine fluidbox inspection: **implemented**
- Input/output production-direction classification: **implemented**
- Fluidbox filter and locked-fluid inspection: **implemented**
- Actual pipe-connection inspection: **implemented**
- Fluid-segment content and capacity inspection: **implemented**
- Temperature-range validation: **implemented**
- Connected/empty/low/unconnected/wrong-fluid classification: **implemented**
- Output buffer and output blockage classification: **implemented**
- Barrel-mediated recipe recognition: **implemented**
- Fluid prototype names blocked from item logistics: **implemented**
- Read-only source-network discovery: **implemented**
- Read-only connection proposals: **implemented**
- Fluid insertion/removal/flush operations: **zero by design**
- Automatic pipe construction: **not yet implemented**
- Runtime Factorio validation: **pending**

---

## Central doctrine

Factorio's native fluid simulation remains the only fluid authority.

The Tech Priest code may inspect:

- `LuaEntity.fluidbox`,
- each fluidbox prototype and production type,
- filters and locked fluids,
- current local fluid,
- actual pipe connections,
- connected segment contents,
- connected segment capacity,
- segment identity,
- recipe fluid requirements,
- required temperature boundaries.

The Tech Priest code may not:

- call `insert_fluid`,
- call `remove_fluid`,
- write directly to a fluidbox,
- clear a fluidbox,
- flush a segment,
- create fluid from a recipe declaration,
- remove fluid merely because a machine needs it,
- place a fluid name in `active_supply_request`,
- ask 0527 to fetch a fluid prototype as an item,
- represent unbarrelled fluid as priest custody.

The diagnostic block explicitly reports `fluid_mutations=0`.

---

## Machine inspection states

### Ready states

| State | Meaning |
|---|---|
| `input-ready` | Correct fluid is connected, temperature-valid, and sufficient for at least the configured per-craft threshold |
| `output-ready` | Correct output segment is connected and has enough available capacity |
| `fluid-ready` | Every required input and output record is ready |

### Waiting states

| State | Meaning |
|---|---|
| `input-connected-empty` | A real pipe connection exists, but the connected segment currently contains none of the required fluid |
| `input-connected-low` | Correct fluid exists in the connected segment, but less than the recipe requirement is currently available |
| `output-connected-low-capacity` | Output is connected but the real segment lacks room for the expected product amount |
| `output-unconnected-buffer` | Output is not connected, but the local machine fluidbox can still buffer at least one expected craft |
| `fluid-network-waiting` | At least one record is waiting and none are fatal or require a new connection |

### Connection-required states

| State | Meaning |
|---|---|
| `input-unconnected` | The machine has an appropriate input fluidbox but no real connected fluidbox at its pipe port |
| `output-unconnected-blocked` | The output port is unconnected and its remaining local capacity is below the expected output amount |
| `fluid-connection-required` | At least one connection-required record exists and no fatal record exists |

### Fatal states

| State | Meaning |
|---|---|
| `input-no-fluidbox` | No input fluidbox can legitimately satisfy the recipe requirement |
| `input-wrong-fluid` | The local or connected segment contains another fluid |
| `input-temperature-invalid` | The correct fluid exists outside the recipe's accepted temperature range |
| `output-no-fluidbox` | No output fluidbox can legitimately hold the recipe product |
| `output-wrong-fluid` | The output segment contains another fluid |
| `output-temperature-invalid` | Existing output fluid violates the required product temperature constraint |
| `fluid-fatal` | At least one fatal record exists |

The doctrine never flushes or replaces a wrong fluid. It reports contamination and leaves correction to the player or a later explicit maintenance doctrine.

---

## Fluidbox matching

Each recipe fluid requirement is matched against an actual machine fluidbox using:

1. An explicit recipe `fluidbox_index`, when present.
2. Fluidbox production direction: input, output, or input-output.
3. Runtime fluidbox filter.
4. Runtime locked fluid.
5. Prototype filter fallback.
6. Existing correct local fluid as a weaker matching signal.

One fluidbox index is not assigned to multiple recipe members during a single inspection unless Factorio itself exposes separate merged boxes through its runtime prototype data.

---

## Real connection inspection

For each matched fluidbox, the doctrine reads actual runtime pipe connections.

A port is considered connected only when:

- `get_pipe_connections(index)` reports a target fluidbox or target owner, or
- `get_connections(index)` reports at least one valid connected fluidbox.

Nearby visual proximity does not count as a connection.

This is intentionally stricter than the old 0528 automation test, which treated any nearby pipe or pump as general machine automation.

---

## Segment accounting

The doctrine reads the real connected segment using:

- `get_fluid_segment_contents(index)`,
- `get_capacity(index)`,
- `get_fluid_segment_id(index)`,
- the local `fluidbox[index]` record as a fallback.

Input readiness is based on actual required-fluid amount in the connected segment.

Output readiness is based on actual segment occupancy and capacity. The doctrine does not assume that an empty-looking local box means an attached network has room.

Wrong-fluid detection examines every named fluid returned for the segment, not merely the local machine box.

---

## Barrel-mediated recipes

A recipe is marked `barrel_mediated=true` when its item ingredients or products include `empty-barrel` or another item name containing `barrel`.

This marker does not change the recipe.

Barrel behavior remains physically honest:

- filled barrels are ordinary physical items and may be fetched by 0527,
- filled barrels may be carried through the 0682 station-to-machine custody chain,
- empty barrels are ordinary physical machine output and may be cleared into retention storage,
- the fluid produced or consumed by the active barrel recipe remains inside Factorio's actual fluidbox and pipe network,
- no barrel item is synthesized from a fluid declaration.

---

## Anti-teleport guard

The doctrine checks these pair fields before and after every 0528 service call:

- `active_supply_request`,
- `logistic_requested_item`,
- `supply_request`,
- `machine_logistics_0528.item`.

When any field attempts to use a registered fluid prototype as an item under machine/fluid logistics authority, the request is removed automatically.

If a live 0528 state itself names a fluid as its carried/fetched item, the machine reservation is released and the invalid state is cleared.

This prevents:

- 0527 inventory searches for fluid prototype names,
- raw mining requests for water, oil, steam, or modded fluids,
- station custody records pretending to carry unbarrelled fluid,
- future regressions that reintroduce fluid ingredients into the item ingredient loop.

---

## Read-only connection proposals

For a missing input connection, the doctrine records:

- machine identity,
- recipe identity,
- required fluid,
- required amount per craft,
- machine fluidbox index,
- exact runtime connection target positions,
- nearest real same-force source segment containing the required fluid, when found,
- source entity, position, fluidbox index, segment ID, amount, capacity, and distance.

For an unconnected output, the doctrine records the exact output connection positions and required output fluid.

These proposals are intentionally read-only. They do not:

- reserve a route,
- place pipe ghosts,
- choose pipe versus underground pipe,
- rotate pumps,
- cross another station's territory,
- connect two different fluids,
- modify the machine recipe.

They are the input for the next safe pipe-construction planning phase.

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/fluid_network_doctrine_0689.lua` | Runtime fluidbox/segment inspection, state classification, barrel recognition, anti-fluid-item guard, source discovery, connection proposals, and automatic diagnostics |

## Loader changes

`planning_constraints_0646.lua` now installs the 0689 doctrine after storage and transfer integrity and before final movement-vector enforcement.

The doctrine wraps `machine_logistics_final_authority_0684.activate`, so the final machine service order remains one wrapper chain on `main` rather than a parallel fluid controller.

---

## Automatic diagnostics

`PAIR-DUMP-0468 FLUID-NETWORK-0689` reports:

- `read_only=true`,
- `fluid_mutations=0`,
- total machine inspections,
- ready/waiting/connection-required/fatal state counts,
- blocked fluid-to-item requests,
- connection proposal count,
- per-pair active machine and recipe,
- barrel-mediated status,
- worst observed network state,
- recent anti-teleport events.

The runtime inspector is also exposed as:

- `TechPriestsFluidNetworkDoctrine0689.inspect_machine`,
- `tech_priests_fluid_network_inspect_0689`.

---

## Runtime validation scenarios still pending

1. Connected water input with enough water reports `input-ready`.
2. Connected but empty water segment reports `input-connected-empty`.
3. Connected low-water segment reports `input-connected-low`.
4. Visually adjacent but physically unconnected pipe reports `input-unconnected`.
5. Wrong fluid in an input segment reports `input-wrong-fluid` without flushing it.
6. Temperature-constrained input outside range reports `input-temperature-invalid`.
7. Connected output with capacity reports `output-ready`.
8. Connected output with insufficient capacity reports `output-connected-low-capacity`.
9. Unconnected empty output box reports `output-unconnected-buffer` while one craft still fits.
10. Unconnected full output reports `output-unconnected-blocked`.
11. Missing recipe fluidbox reports the appropriate fatal state.
12. Multi-fluid recipes map each requirement to a distinct correct fluidbox.
13. Merged crafting-machine fluidbox prototypes remain inspectable.
14. A filling-barrel recipe is recognized as barrel-mediated.
15. An emptying-barrel recipe is recognized as barrel-mediated.
16. Filled barrels continue through ordinary 0527 and 0682 item custody.
17. Empty barrels clear through retention storage.
18. A forged water item request is deleted before 0527 sees it.
19. A forged live machine state carrying crude oil is cleared and releases its reservation.
20. A missing input port produces a proposal containing exact connection positions.
21. A nearby real source segment is recorded with segment ID and available amount.
22. No source segment produces `no-source-network-found` rather than invented supply.
23. Output proposals do not identify an input source as an output destination.
24. Save/load preserves cached reports without invalid entity crashes.
25. Diagnostics continue to report `fluid_mutations=0` after extended operation.
26. Modded fluids and machines with filters are classified correctly.
27. Space Age machines with multiple fluidboxes are classified correctly.
28. Fluid wagons and non-fluidbox storages are not incorrectly treated as ordinary pipe segments.
29. Scan routing and cooldowns prevent repeated full-area scans every dispatcher pulse.
30. No priest movement or overhead work task is created solely because a fluid network is waiting.

---

## Known follow-up risks

1. The connection proposal does not yet calculate a collision-free pipe route.
2. It does not yet prove that a proposed route stays inside station territory.
3. It does not yet detect whether a new pipe tile would connect to an adjacent incompatible segment.
4. It does not choose between pipe, pipe-to-ground, pump, or storage tank.
5. It does not reserve source interfaces because no construction task exists yet.
6. Some modded entities may expose nonstandard fluid storage outside `LuaEntity.fluidbox`.
7. Segment capacity semantics and merged crafting fluidboxes require runtime testing across Factorio 2.0 and Space Age machines.
8. A connected-empty network may need player infrastructure rather than priest intervention; the doctrine deliberately does not guess.

---

## Completion estimate

- Real fluid-state inspection: **100% implemented**
- Fluid/item authority separation: **100% implemented**
- Barrel-route recognition: **100% implemented**
- Read-only connection proposal generation: **100% implemented**
- Automatic pipe-route planning: **0% implemented**
- Pipe construction execution: **0% implemented**
- Runtime scenarios: **0 of 30 executed**

**Overall confidence: approximately 74%.**

The fluid-integrity layer is complete. The remaining work is a separate construction problem, not a license to mutate fluid directly.

---

## Next sequential development target

Implement a safe fluid-connection construction planner that:

1. Starts from 0689's exact machine connection target positions.
2. Ends at a real compatible source or output network interface.
3. Rejects every route touching a segment containing another fluid.
4. Remains inside the owning Cogitator's interior territory.
5. Reserves every planned pipe tile before construction.
6. Chooses ordinary pipe first and pipe-to-ground only when necessary.
7. Uses the existing construction executor for physical item removal and placement.
8. Never changes a machine recipe or fluidbox directly.
