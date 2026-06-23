# Burner, Heat, and Generator Readiness Status — 0.1.672

Scope: read-only operating-readiness inspection for boilers, burner generators, reactors, fusion reactors, ordinary generators, and fusion generators. This is the prerequisite for any later physical fuel or burnt-result logistics.

## Current status

- Runtime fuel inventory detection: **implemented**
- Runtime burnt-result inventory detection: **implemented**
- Burner current-fuel and remaining-energy inspection: **implemented**
- Boiler/fusion fluid input readiness: **implemented**
- Boiler/fusion fluid output readiness: **implemented**
- Burner-generator electrical-network readiness: **implemented**
- Generator electrical-network observation: **implemented**
- Reactor/fusion-reactor heat-neighbour readiness: **implemented**
- Burnt-result capacity blocking: **implemented**
- Fuel-sufficient versus fuel-service-eligible classification: **implemented**
- Ordinary fluid generators classified observation-only: **implemented**
- Item removal/insertion: **zero by design**
- Fluid mutation: **zero by design**
- Heat mutation: **zero by design**
- Fuel delivery: **not enabled yet**
- Runtime Factorio validation: **pending**

---

## Core rule

An empty fuel inventory is not sufficient authorization to spend fuel.

A fuel-bearing entity becomes `fuel-service-eligible` only when:

1. It exposes a legitimate runtime fuel inventory.
2. Its burnt-result inventory is absent or has available space.
3. Any relevant electrical output is connected.
4. Any relevant heat output has at least one live heat neighbour.
5. Every runtime fluid input is physically connected and contains fluid.
6. Every runtime fluid output is physically connected and has measurable free capacity.
7. The fuel inventory is below the configured minimum and no current burning fuel energy remains.

The doctrine is deliberately conservative. A false negative wastes no fuel; a false positive could consume physical fuel into a useless or blocked machine.

---

## Family rules

### Boilers

A boiler is eligible only when its burner/fuel inventory exists, burnt results can be accepted, input fluid is connected and non-empty, and output fluid is connected with capacity.

An unconnected or dry boiler is reported but not authorized for fuel service.

### Burner generators

A burner generator is eligible only when its fuel and burnt-result conditions are valid and it is connected to an electrical network.

The doctrine does not infer demand merely because the network exists; later fuel service will still use a conservative minimum stock.

### Reactors

A reactor is eligible only when its fuel and burnt-result conditions are valid and it has at least one live heat neighbour.

Neighbour bonus, current temperature, status, and remaining burning fuel are recorded for diagnosis. No heat is synthesized or altered.

### Fusion reactors

A fusion reactor is treated as a combined item/fluid/heat/electrical family. It must satisfy every exposed prerequisite before it can become fuel-service-eligible.

### Generators and fusion generators

Ordinary fluid generators do not expose a legitimate item-fuel path and are classified `monitor-only`.

Their fluid and electrical state is reported, but no item logistics task is permitted solely because generation is absent.

---

## Readiness states

| State | Meaning |
|---|---|
| `fuel-service-eligible` | Legitimate fuel inventory is low and every non-item prerequisite is viable |
| `fuel-sufficient` | Enough fuel is already present or current burning energy remains |
| `burnt-result-blocked` | Spent-fuel/byproduct inventory cannot accept another result |
| `electric-network-missing` | An electrical-output family is not connected |
| `heat-network-missing` | Reactor/fusion heat has no live neighbour |
| `input-fluid-not-ready` | A required runtime input fluidbox is unconnected or empty |
| `output-fluid-not-ready` | A required output fluidbox is unconnected or full |
| `monitor-only` | Entity has no legitimate item-fuel inventory |

---

## Runtime evidence recorded

Each report stores:

- entity identity and type,
- fuel inventory and item count,
- current burning fuel,
- remaining burning energy,
- burner heat,
- burnt-result inventory and count,
- burnt-result free-slot readiness,
- every runtime fluidbox direction/filter/contents/connections/capacity/free capacity,
- electrical connection and network ID,
- heat-neighbour count,
- runtime entity status,
- temperature,
- energy generated last tick,
- reactor neighbour bonus.

The report is exposed through:

- `TechPriestsEnergyFamilyReadiness0705.inspect_entity`,
- `tech_priests_energy_family_inspect_0705`.

---

## File added

`tech-priests_src/scripts/core/energy_family_readiness_0705.lua`

The module registers one budgeted read-only broker service. It creates no movement, reservations, item requests, custody, or construction tasks.

---

## Automatic diagnostics

`PAIR-DUMP-0468 ENERGY-READINESS-0705` reports:

- `read_only=true`,
- `item_mutations=0`,
- `fluid_mutations=0`,
- `heat_mutations=0`,
- inspected entities,
- eligible and fuel-sufficient counts,
- fluid/electrical/heat/burnt-result blockers,
- monitor-only entities,
- per-pair inspected/eligible totals and worst state.

---

## Runtime validation scenarios still pending

1. Dry boiler remains blocked despite empty fuel inventory.
2. Boiler with input water but no output connection remains blocked.
3. Boiler with viable water/steam network becomes eligible.
4. Boiler with current burning fuel reports fuel-sufficient.
5. Burner generator without electrical network remains blocked.
6. Connected burner generator becomes eligible.
7. Reactor without heat neighbours remains blocked.
8. Reactor connected to heat pipe becomes eligible.
9. Reactor with full burnt-result inventory remains blocked.
10. Reactor neighbour bonus is recorded correctly.
11. Fusion reactor with missing fluid remains blocked.
12. Fusion reactor with missing electrical network remains blocked.
13. Fusion reactor with all prerequisites becomes eligible.
14. Fluid generator is monitor-only.
15. Fusion generator is monitor-only unless it exposes a real fuel inventory.
16. Modded burner entity with no burnt-result inventory is accepted conservatively.
17. Multiple fluidboxes are classified by runtime production direction.
18. Input connected but empty remains blocked.
19. Output connected but full remains blocked.
20. Save/load preserves cached reports without stale entity failures.
21. No fuel is removed during inspection.
22. No item is inserted during inspection.
23. No fluidbox is changed during inspection.
24. No temperature or heat value is changed during inspection.
25. No movement or work reservation is created.

---

## Known limitations

1. Runtime production-direction metadata on unusual modded fluidboxes may be incomplete; conservative blocking is expected.
2. Heat-neighbour existence proves connectivity, not downstream heat demand or throughput.
3. Electrical connection proves a network exists, not that generation is economically needed.
4. Burnt-result free slots are a broad readiness test; the later fuel selector must prove compatibility with the selected fuel's exact burnt result.
5. Fuel quality and fuel categories require exact destination-inventory compatibility during physical service.

---

## Completion estimate

- Read-only family readiness: **100% implemented**
- Physical fuel delivery: **0% implemented**
- Burnt-result evacuation: **0% implemented**
- Runtime scenarios: **0 of 25 executed**

**Overall confidence: approximately 77%.**

---

## Next sequential development target

Implement physical energy-family custody only for `fuel-service-eligible` reports:

1. Select fuel accepted by the exact target fuel inventory.
2. Prove the selected fuel's burnt result can be accepted.
3. Reserve the target.
4. Visit the exact home-local source before removing fuel.
5. Deliver exact fuel physically and return leftovers.
6. Evacuate existing burnt results physically before adding fuel when necessary.
7. Revalidate fluid, heat, electrical, and capacity prerequisites before target insertion.
8. Leave monitor-only generators untouched.
