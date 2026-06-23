# Real Output-Fluid Sink Doctrine Status — 0.1.668

Scope: prove a real compatible destination for an unconnected manual-machine fluid output before any output pipe route may be planned.

## Current status

- Runtime output-fluid requirement detection: **implemented through 0689 reports**
- Input-capable sink fluidbox classification: **implemented**
- Same-fluid segment proof: **implemented**
- Empty explicitly filtered/locked sink proof: **implemented**
- Empty unfiltered destination rejection: **implemented**
- Wrong-fluid and wrong-filter rejection: **implemented**
- Measured segment free-capacity proof: **implemented**
- Exact unused sink interface discovery: **implemented**
- Same-segment rejection: **implemented**
- Read-only sink proposals: **implemented**
- Output pipe construction: **not enabled yet**
- Fluid mutation: **zero by design**
- Runtime Factorio validation: **pending**

---

## Accepted sink classes

### Existing same-fluid segment

A segment is eligible when it already contains the machine's output fluid, contains no other fluid, accepts input or bidirectional flow, has measured free capacity for at least one expected craft, and exposes a real unconnected interface.

This class is preferred because the segment's existing fluid identity is already physically established.

### Empty explicitly typed sink

An empty segment is eligible only when its runtime filter, locked fluid, or prototype filter explicitly identifies the required output fluid. It must also be input-capable, have sufficient measured capacity, and expose an unused interface.

---

## Rejected destinations

The doctrine rejects:

- output-only fluidboxes,
- the producing machine itself,
- a destination already sharing the machine output segment,
- segments containing another fluid,
- fluidboxes filtered or locked to another fluid,
- segments with insufficient free capacity,
- segments without a real unused interface,
- empty unfiltered pipes, tanks, and machines,
- missing or invalid entities,
- output records that are already connected and healthy.

An empty unfiltered storage tank is deliberately not treated as permission to establish a new fluid identity automatically.

---

## Capacity accounting

The doctrine reads the connected segment's real contents and capacity. Free capacity is calculated as:

`segment capacity - total segment contents`

The expected minimum is the recipe's output amount for one craft, including product probability where exposed by the runtime recipe record.

No fluid is inserted to test the destination.

---

## Interface proof

A sink proposal contains only target positions returned by the candidate fluidbox's runtime pipe-connection records where no target fluidbox is currently attached.

Visual proximity does not qualify as an interface.

---

## Proposal contents

Each `fluid_output_sink_proposals_0694` record includes:

- producing machine and recipe,
- output fluid and amount per craft,
- machine output fluidbox index and segment ID,
- exact machine output connection targets,
- sink entity and fluidbox index,
- sink segment ID,
- sink class,
- current same-fluid amount,
- occupied, total, and free capacity,
- filter identity and source,
- exact sink interface positions,
- distance and scoring metadata,
- a rejection summary when no compatible sink is found.

The proposal is read-only and expires after twenty minutes.

---

## File added

`tech-priests_src/scripts/core/fluid_output_sink_doctrine_0694.lua`

The module wraps `fluid_network_doctrine_0689.inspect_machine`, so output sink evaluation occurs whenever the existing fluid doctrine inspects a machine. No second machine scan scheduler was added.

---

## Automatic diagnostics

`PAIR-DUMP-0468 FLUID-OUTPUT-SINK-0694` reports:

- `read_only=true`,
- `fluid_mutations=0`,
- `direct_construction=0`,
- reports processed,
- sink proposals created,
- compatible sinks found,
- same-fluid versus empty-filtered sink classes,
- proposals with no safe sink,
- per-pair machine, fluid, selected sink, sink class, free capacity, and required capacity.

---

## Runtime validation scenarios still pending

1. Existing same-fluid tank segment with sufficient capacity is selected.
2. Same-fluid segment without a free interface is rejected.
3. Same-fluid segment with inadequate capacity is rejected.
4. Empty tank filtered to the output fluid is selected.
5. Empty unfiltered tank is rejected.
6. Empty tank filtered to another fluid is rejected.
7. Segment containing another fluid is rejected.
8. Input-only consumer fluidbox accepting the same fluid is eligible.
9. Output-only fluidbox is rejected.
10. Input-output storage segment is eligible.
11. Machine output and candidate already share a segment and are rejected as already connected.
12. Multiple interfaces on one segment are deduplicated by segment identity.
13. Nearest safe sink wins among equal sink classes.
14. Existing same-fluid segment outranks a nearer empty filtered sink.
15. Larger available capacity improves scoring within a class.
16. Product probability is reflected in required capacity.
17. Multiple fluid products create independent proposals.
18. Invalid sink entity is ignored without error.
19. Save/load invalidates stale entity references safely.
20. No fluid mutation occurs during repeated inspection.
21. No construction task is created by 0694.
22. No priest movement is created by 0694.
23. Space Age and modded filtered tanks are classified correctly.
24. Empty unfiltered pipe networks remain rejected.

---

## Known limitations

1. Runtime testing is needed for merged crafting-machine fluidboxes.
2. Capacity may change after proposal creation; construction must revalidate before every step.
3. The doctrine does not create a new filtered tank when no sink exists.
4. The doctrine does not decide whether a production chain should consume, store, vent, or recycle the output.
5. Output construction still requires territory, adjacency, reservation, and route checks equivalent to 0691.

---

## Completion estimate

- Safe sink identification: **100% implemented**
- Read-only proposal generation: **100% implemented**
- Output pipe construction: **0% implemented**
- Runtime scenarios: **0 of 24 executed**

**Overall confidence: approximately 76%.**

---

## Next sequential development target

Implement output pipe construction by reusing the 0691 model, but only for `compatible-sink-found` proposals. The output planner must revalidate sink identity and free capacity before each tile, reserve the complete route, build from sink toward machine, request physical pipes through existing logistics, and abort immediately if the destination becomes full, contaminated, unfiltered, or unavailable.
