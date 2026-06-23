# Collision-Safe Fluid Port Validation Status — 0.1.670

Scope: prove that a proposed input or output pipe endpoint touches only the intended fluidbox or other fluidboxes already proven compatible with the same fluid.

## Current status

- Exact runtime connection-target comparison: **implemented**
- Intended fluidbox ownership proof: **implemented**
- Shared-port enumeration: **implemented**
- Recipe fluid identity use: **implemented**
- Filter and locked-fluid identity use: **implemented**
- Existing segment/local-fluid identity use: **implemented**
- Different-fluid shared-port rejection: **implemented**
- Empty unfiltered shared-port rejection: **implemented**
- Same-fluid shared-port acceptance: **implemented**
- Input proposal target filtering: **implemented**
- Output machine target filtering: **implemented**
- Output sink-interface filtering: **implemented**
- Active input-plan revalidation: **implemented**
- Active output-plan revalidation: **implemented**
- Exact-machine report refresh: **implemented**
- Unsafe plan reservation cleanup: **implemented**
- Fluid mutation: **zero by design**
- Direct construction: **zero by design**
- Runtime Factorio validation: **pending**

---

## Why this authority exists

A single map tile can be adjacent to more than one fluidbox connection on complex, rotated, Space Age, or modded machines. A route planner that validates only the intended fluidbox can still place a pipe that physically joins another port at the same tile.

The validator now treats endpoint geometry as a shared resource. Every fluidbox whose runtime connection target occupies the proposed tile is inspected before that tile may enter a route proposal.

---

## Fluid identity proof

A touching fluidbox is compatible when at least one authoritative source identifies its fluid and every known identity equals the intended route fluid.

Identity sources are:

1. Current recipe requirement associated with that runtime fluidbox index.
2. Runtime fluidbox filter.
3. Runtime locked fluid.
4. Prototype filter.
5. Current connected-segment contents.
6. Current local fluidbox contents.

The result is classified as:

- **Compatible:** all known names equal the route fluid.
- **Different fluid:** at least one known name differs.
- **Ambiguous:** no recipe, filter, lock, segment content, or local fluid establishes an identity.

Ambiguous empty unfiltered shared ports are rejected.

---

## Proposal filtering

### Input proposals

For each 0689 input proposal:

- machine connection targets are filtered individually,
- every remaining machine target must be collision-safe,
- every free source interface must be collision-safe,
- the whole proposal is rejected when no safe machine target remains or any source interface is unsafe or ambiguous.

The source rule is deliberately conservative because 0691 discovers source interfaces dynamically and could otherwise choose an unsafe one.

### Output proposals

For each 0694 output proposal:

- machine output targets are filtered individually,
- sink interfaces are filtered individually,
- the proposal survives only when at least one safe machine target and one safe sink target remain.

Filtered copies are presented to the inner route planners only for the duration of the construction service call. Original read-only diagnostic proposals are restored afterward.

---

## Active plan revalidation

A plan that was safe when created may become unsafe when:

- the machine recipe changes,
- a fluidbox filter changes,
- another segment is connected,
- a previously empty shared port receives a different fluid,
- machine rotation or replacement changes port geometry,
- a mod changes runtime fluidbox structure.

Before the construction stack executes, the validator rechecks both endpoints of every active input and output route.

When a route becomes unsafe:

1. Every shared construction reservation is released.
2. A matching construction task is cleared.
3. Matching pipe-item requests are cleared.
4. The plan is marked aborted and preserved as the last plan record.
5. A rejection cooldown is applied.
6. No placed pipe or fluid is deleted or modified.

---

## Exact-machine context

`fluid_port_context_guard_0700.lua` ensures that `pair.machine_fluid_network_0689` belongs to the exact machine under active or proposed construction.

The guard selects context in this order:

1. Active input pipe plan.
2. Active output pipe plan.
3. Current input proposal.
4. Current output proposal.

A recent matching report is reused. Otherwise, 0689 performs a forced read-only reinspection of that exact machine before the collision validator runs.

This prevents fluidbox index 1 on one machine from being interpreted using fluidbox index 1 from another machine's recipe report.

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/fluid_port_collision_validator_0699.lua` | Shared-port identity proof, proposal filtering, active route abort, diagnostics |
| `tech-priests_src/scripts/core/fluid_port_context_guard_0700.lua` | Exact-machine report selection and refresh before endpoint validation |

## Loader order

The outer fluid construction stack is now:

1. 0689 real fluid inspection.
2. 0694 output sink proof.
3. 0697 surface-scoped positional reservations.
4. 0691 input route planning.
5. 0692 input-plan execution guard.
6. 0696 output route planning.
7. 0699 shared-port collision validation.
8. 0700 exact-machine context refresh.
9. Final movement-vector enforcement.

0700 is outermost at runtime and refreshes context before 0699 filters proposals or validates live routes.

---

## Automatic diagnostics

### `PAIR-DUMP-0468 FLUID-PORT-COLLISION-0699`

Reports:

- validated endpoints,
- compatible shared ports,
- proposal targets rejected,
- complete input/output proposals rejected,
- active plans aborted,
- `fluid_mutations=0`,
- `direct_construction=0`,
- recent abort reasons.

### `PAIR-DUMP-0468 FLUID-PORT-CONTEXT-0700`

Reports:

- matching context reports reused,
- exact machine contexts refreshed,
- context refresh failures.

---

## Runtime validation scenarios still pending

1. Single-port base assembler accepts a safe input endpoint.
2. Single-port output accepts a safe endpoint.
3. Two shared ports both requiring water are accepted.
4. Shared water and crude-oil ports are rejected.
5. Shared intended port plus empty unfiltered port is rejected.
6. Shared intended port plus empty water-filtered port is accepted for water.
7. Shared intended port plus empty steam-filtered port is rejected for water.
8. Current segment identity proves compatibility without a filter.
9. Runtime locked-fluid identity proves compatibility.
10. Prototype filter identity proves compatibility.
11. Recipe requirement proves an otherwise empty intended port.
12. Input proposal retains only safe target positions.
13. Input proposal is rejected when all machine targets are unsafe.
14. Input proposal is rejected when any dynamic source interface is unsafe.
15. Output proposal retains only safe machine and sink positions.
16. Output proposal is rejected when no safe sink interface remains.
17. Active input plan survives unchanged geometry.
18. Active output plan survives unchanged geometry.
19. Recipe change makes active input endpoint unsafe and aborts it.
20. Recipe change makes active output endpoint unsafe and aborts it.
21. New wrong-fluid segment connection aborts a live route.
22. Abort releases all route reservations.
23. Abort clears only its matching construction task.
24. Abort clears only its matching item requests.
25. Placed pipes remain untouched after abort.
26. Fluid remains untouched after abort.
27. Pair report for another machine is not reused.
28. Matching recent machine report is reused.
29. Stale matching report is refreshed.
30. Missing doctrine report prevents unsafe interpretation rather than guessing.
31. Rotated Space Age machine port geometry is validated correctly.
32. Modded merged fluidboxes are conservatively handled.
33. Save/load revalidates active route endpoints.
34. No direct construction originates from 0699 or 0700.
35. No fluid mutation originates from 0699 or 0700.

---

## Known limitations

1. Source proposals are rejected when any free source interface is ambiguous, even when another interface is safe. This avoids 0691 selecting the unsafe shorter route.
2. Runtime connection geometry differs across modded machines and requires actual Factorio tests.
3. Compatible shared ports may still have throughput consequences outside the scope of identity safety.
4. The validator does not rotate machines or move existing pipes.
5. Unknown fluidbox identity is treated as unsafe, which can create false negatives.

---

## Completion estimate

- Shared-port identity validation: **100% implemented**
- Proposal filtering: **100% implemented**
- Active route revalidation and cleanup: **100% implemented**
- Exact-machine context integrity: **100% implemented**
- Runtime scenarios: **0 of 35 executed**

**Overall confidence: approximately 72%.**

---

## Next sequential development target

Audit and extend machine logistics beyond assemblers and furnaces using family-specific doctrines. Begin with labs and ammunition turrets because their inventories are item-based and can reuse physical custody safely. Boilers, reactors, generators, rocket silos, and fluid turrets require separate family rules and must not be folded into a generic inventory loop.
