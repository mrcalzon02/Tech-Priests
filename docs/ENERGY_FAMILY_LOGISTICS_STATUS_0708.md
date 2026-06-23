# Physical Energy-Family Logistics Status — 0.1.673

Scope: physical fuel delivery and burnt-result evacuation for energy entities that pass `energy_family_readiness_0705.lua`.

## Current status

- Readiness-gated candidate selection: **implemented**
- Existing burnt-result evacuation first: **implemented**
- Exact target fuel-inventory compatibility: **implemented**
- Exact selected-fuel burnt-result compatibility: **implemented**
- Home-local physical source selection: **implemented**
- Source visit before removal: **implemented**
- Persistent fuel/byproduct custody: **implemented**
- Final readiness revalidation at destination: **implemented**
- Exact destination insertion: **implemented**
- Partial insertion leftover return: **implemented**
- Burnt-result return to role-aware storage: **implemented**
- Missing-fuel request handoff: **implemented**
- Shared target reservation: **implemented**
- Concrete leaf truth: **implemented**
- Ordinary generators left untouched: **implemented**
- Fluid and heat mutation: **zero by design**
- Runtime Factorio validation: **pending**

---

## Burnt results are handled first

Whenever a readiness report exposes physical items in a burnt-result inventory, evacuation takes precedence over refueling.

The priest:

1. Reserves the energy entity.
2. Walks to the entity.
3. Removes an exact stack from the burnt-result inventory.
4. Records persistent custody.
5. Returns to the Cogitator.
6. Deposits the exact count through role-aware retention storage.
7. Clears custody only after complete storage.

This prevents additional fuel from being supplied behind a blocked spent-fuel inventory.

---

## Fuel selection

Fuel is eligible only when:

- its item prototype has positive fuel value,
- the exact target fuel inventory accepts that item,
- any exact burnt-result item has a legitimate target burnt-result inventory,
- that burnt-result inventory can accept the exact byproduct.

The selector first attempts to continue the machine's currently burning fuel type when physical stock exists. It then considers conservative preferred fuels before deterministically scanning other compatible fuel prototypes.

A missing compatible fuel produces an exact item request rather than a substitute or invented item.

---

## Physical transfer sequence

1. Select a readiness-approved entity and exact compatible fuel.
2. Reserve the target.
3. Select one exact home-local station or stash source.
4. Walk to the source.
5. Remove the exact item count.
6. Record `pair.energy_family_custody_0707`.
7. Walk to the energy entity.
8. Force a fresh readiness inspection.
9. Recheck exact fuel and burnt-result compatibility.
10. Insert the exact accepted count.
11. Return every leftover item to the Cogitator.

Fuel is never removed remotely and custody is never relabelled as another fuel.

---

## Final destination revalidation

Immediately before insertion, the executor forces a new 0705 inspection.

Fuel returns to the Cogitator when the target has become:

- dry or fluid-blocked,
- output-fluid blocked,
- disconnected from its electrical network,
- disconnected from its heat network,
- full in its burnt-result inventory,
- externally refueled and therefore already sufficient,
- incompatible with the selected fuel or its burnt result,
- invalid or destroyed.

This avoids spending physical fuel merely because the machine was eligible when the trip began.

---

## Missing-fuel handoff

When no home-local source contains compatible fuel, 0707 writes an exact request containing:

- fuel item,
- count,
- purpose `energy-fuel`,
- target identity,
- source `energy-family-logistics-0707`.

The existing chain may physically fetch or produce that item. The task resumes only after a home-local physical source exists.

---

## Family exclusions

The executor acts only on entities with a legitimate runtime fuel inventory and a `fuel-service-eligible` report.

Ordinary generators and other fluid-only producers remain read-only. The executor does not invent a fuel inventory for them.

It also performs no:

- fluid insertion/removal,
- heat mutation,
- electrical-network modification,
- pipe construction,
- recipe change,
- direct entity creation.

---

## File added

`tech-priests_src/scripts/core/energy_family_logistics_0707.lua`

The module registers one budgeted broker service and reuses the shared movement, reservation, item-fetch, production, storage, and leaf-truth authorities.

---

## Automatic diagnostics

`PAIR-DUMP-0468 ENERGY-FAMILY-LOGISTICS-0707` reports:

- corrected readiness eligible/sufficient counters,
- exact missing-fuel requests,
- physical pickups,
- fuel items delivered,
- burnt-result tasks,
- orphan custody recovery,
- per-pair family, phase, item, target, and custody,
- `remote_removals=0`,
- `fluid_mutations=0`,
- `heat_mutations=0`.

---

## Runtime validation scenarios still pending

1. Readiness-approved boiler receives coal physically.
2. Dry boiler does not receive fuel.
3. Boiler loses water during delivery and fuel returns.
4. Boiler output fills during delivery and fuel returns.
5. Connected burner generator receives compatible fuel.
6. Burner generator loses grid and fuel returns.
7. Reactor with heat neighbour receives uranium fuel cells.
8. Reactor without heat neighbour remains untouched.
9. Spent uranium fuel cells are evacuated before refueling.
10. Full burnt-result inventory blocks fuel delivery.
11. Selected fuel with incompatible burnt result is rejected.
12. Currently burning fuel type is preferred when stocked.
13. Missing fuel creates an exact request.
14. 0527 fetches fuel from a real home-local source.
15. Production fallback creates compatible fuel and delivery resumes.
16. Borrowed superior inventory is not remotely consumed.
17. Two stations discover the same reactor; only one reserves it.
18. Target destroyed after pickup returns fuel.
19. Target externally refueled during travel causes return.
20. Partial target insertion returns leftovers.
21. Burnt-result source empties before pickup and task aborts safely.
22. Cogitator storage full preserves custody without spill.
23. Lost task table reconstructs return custody.
24. Save/load resumes source travel.
25. Save/load resumes carried fuel.
26. Save/load resumes carried burnt result.
27. Combat suspends carried custody without loss.
28. No generator without a fuel inventory receives an item task.
29. No fluidbox value changes during service.
30. No heat or temperature value changes during service.
31. Leaf status and movement target agree.
32. Exact one-to-one source removal and destination insertion holds over repeated trips.

---

## Known limitations

1. Fuel preference is conservative, not an economic optimizer.
2. Electrical connection proves network existence, not current demand.
3. Heat-neighbour existence proves a physical heat connection, not throughput.
4. Fusion-family runtime semantics require extensive Factorio and Space Age testing.
5. Modded fuel categories and burnt-result inventories may expose unusual compatibility behavior.

---

## Completion estimate

- Physical fuel custody: **100% implemented**
- Physical burnt-result evacuation: **100% implemented**
- Final prerequisite revalidation: **100% implemented**
- Runtime scenarios: **0 of 32 executed**

**Overall confidence: approximately 72%.**

---

## Next sequential development target

Audit rocket silos, artillery, roboports, and fluid turrets separately. Begin with rocket silos because they combine item ingredients, output/result inventories, possible fuel/fluid interfaces, launch state, and externally automated logistics. Do not treat them as generic assemblers or ordinary storage containers.
