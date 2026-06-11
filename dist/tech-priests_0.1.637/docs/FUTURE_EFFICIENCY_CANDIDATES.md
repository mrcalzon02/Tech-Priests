# Future Efficiency Candidates

This document is planning-only. It does not authorize adding another scheduler, cache, queue, reservation layer, sleep layer, or delayed-processing authority. Any future implementation must first pass the Efficiency Authority Inventory rule in `docs/STANDARDS_AND_PRACTICES.md`.

Current canonical authorities remain:

```text
Timing: runtime_tick_broker.lua through runtime_event_registry.lua
Pair classification: pair_bucket_registry.lua
Shared work discovery: work_queue_authority.lua
Target claims: work_reservations.lua
Per-priest execution: order_queue_0469.lua
Indexed dirty/cache scanning: efficiency_economy_0579.lua, with 0569/0570/0571/0585 as subordinate helpers
Whole-runtime sleep: efficiency_economy_0595/0598
Pair/priest sleep: efficiency_economy_0599
Legacy calm/idle shim: efficiency_economy_0582
Movement/path ownership: movement_controller.lua and documented movement authorities
```

## Candidate A — Spatial Interest Management

Potential value: very high.

Concept: downgrade simulation detail for priests and stations that are neither near a player nor near an active industrial emergency. This is not another sleep layer. It is a fidelity tier that tells existing authorities how much theater and reevaluation to run.

Must use existing authorities:

- Pair classification remains in `pair_bucket_registry.lua`.
- Sleep remains owned by 0595/0599/0582.
- Visual/audio chatter throttling remains owned by existing visual/audio authorities.

Telemetry needed before implementation:

- `visible` bucket count
- `sleeping` bucket count
- audio/visual emissions per minute
- service skips by sleeping/empty reason

Risk: if implemented as a new sleep decision-maker, it will conflict with 0599 and pair bucket sleeping classification.

## Candidate B — Pathfinding Reuse / Movement Intent Deduplication

Potential value: high.

Concept: reduce repeated movement churn by recognizing repeated local movement requests from the same station region to the same target cell. This should not cache full global engine paths. It should only collapse or reuse short-lived movement intent where the movement controller already owns command routing.

Must use existing authorities:

- `movement_controller.lua` remains the command/path owner.
- `runtime_tick_broker.lua` only reports telemetry.
- No direct priest `set_command` bypass should be added.

Telemetry needed before implementation:

- path requests per minute
- collapsed path requests
- retarget holds
- engine commands issued
- speed governor/snap events

Risk: stale movement reuse can cause priests to walk to obsolete targets or fail to recover from changed terrain.

## Candidate C — Multi-Priest Squad Tasks

Potential value: high for large deployments.

Concept: allow a senior priest or station-local coordinator to claim one shared work package and assign sub-steps to nearby priests instead of every priest independently evaluating the same expansion, repair, pickup, or acquisition need.

Must use existing authorities:

- Shared job still originates in `work_queue_authority.lua`.
- Target ownership still uses `work_reservations.lua`.
- Per-priest sub-actions still enter `order_queue_0469.lua`.

Telemetry needed before implementation:

- duplicate work queue folds
- reservation denials
- path requests for the same target area
- claim-to-completion ratio by category

Risk: if squad logic becomes a new task selector, it will duplicate work queue and order queue ownership.

## Candidate D — Standardized Deferred Reevaluation Windows

Potential value: moderate to high.

Concept: when a region or target category returns no useful work, remember that negative result for a short time so priests do not repeatedly ask the same question. Some negative cooldown behavior already exists in 0570 and related economy modules. This candidate should consolidate existing negative-result handling, not add a new cooldown system.

Must use existing authorities:

- Dirty/negative scan helpers remain subordinate to 0579/0570.
- Work queues should ask those helpers instead of inventing local cooldown maps.

Telemetry needed before implementation:

- negative cache skips
- dirty-region wakeups
- direct scans after negative cooldown expiry
- cache misses caused by dirty/unknown cells

Risk: overly long negative windows can make priests slow to notice newly built or newly damaged work.

## Candidate E — Event-Driven State Transitions

Status: first bounded slice implemented in 0.1.607 for repair damage events only.

Potential value: extremely high but higher risk.

Concept: move more behavior from polling to event-fed dirty marking and queue submission. For example, damage events submit/dirty repair candidates, build events submit construction or consecration candidates, and inventory changes wake only affected local work systems.

Must use existing authorities:

- Events feed `work_queue_authority.lua` or dirty/index authorities.
- Events do not directly execute priest actions.
- Broker still owns budgeted processing.

Telemetry needed before implementation:

- direct scans per minute
- event-fed submissions per minute
- queue duplicate folds
- cache hit rate after event-fed dirty marking

0.1.607 implementation note: `event_driven_work_feeder_0608.lua` currently submits repair work candidates from `on_entity_damaged` into the existing shared work queue. It intentionally does not handle construction, sanctification, resource discovery, pickup, or combat yet. Those future additions require separate telemetry review.

Risk: Factorio event coverage is not perfect for every semantic condition. Polling fallback must remain, but budgeted and cache-aware.

## Candidate F — GUI / Audio / Visual Emission Budgeting

Potential value: moderate, especially with many priests.

Concept: surface how often text, sound, beams, overlays, GUI refreshes, and diagnostic prints occur, then throttle them through their existing owners. This is not a new visual authority; it is telemetry and budget hints for existing visual/audio systems.

Must use existing authorities:

- Overhead text remains with overhead text/status authorities.
- Sound remains with sound/placeholder audio authorities.
- Network visuals remain with network/visual lease authorities.

Telemetry needed before implementation:

- sounds emitted per minute
- beams created/cleared per minute
- overhead text lines per minute
- GUI refreshes per minute

Risk: over-throttling can make priests feel dead or unresponsive even when the simulation is working.

## Required decision rule before any candidate becomes implementation

Before implementing any candidate, answer:

```text
1. Which current authority owns this behavior now?
2. Which existing counters show the pain is real?
3. Is this replacing, feeding, or simplifying an existing authority?
4. What duplicate loop or local cache will be removed?
5. Which /tp-runtime-report metric should improve after the change?
```

If those answers are not clear, the correct action is audit, not code.


### 0.1.608 directed wakeup note

`event_driven_work_feeder_0608.lua` remains a leaf helper. It submits repair jobs to `work_queue_authority.lua`, asks `pair_bucket_registry.lua` for a short-lived repair bucket hint on the nearest relevant pair, asks `efficiency_economy_0599.lua` to wake that specific pair, and asks existing dirty/negative helpers to clear stale local knowledge. It does not own scheduling, target reservation, execution, pathing, or a new cache.


## 0.1.609 bounded implementation note — Candidate A/F

`spatial_interest_0609.lua` implements only the safe first slice of Spatial Interest Management: telemetry and nonessential theater gating. It does not sleep pairs, change task cadence, alter queue/reservation behavior, or create another scheduler. Current use is deliberately limited to presentation churn:

- periodic overhead status refreshes can skip low-detail remote pairs;
- machine audio emissions can skip offscreen entities;
- `/tp-runtime-report` exposes observed/active-remote/nearby-remote/low-detail counts and suppression counters.

Future expansion must remain under existing authorities. Any actual simulation-detail downgrade must be justified by telemetry and must route through 0599 adaptive pair sleep or the broker, not through a new independent low-detail controller.


## 0.1.610 Implementation Note — Scan Routing & Polling Reduction

Implemented the first cache-first scan routing pass. This does not create a new cache. It standardizes the call pattern for repeated discovery:

```text
existing indexed catalog 0579 → filtered result → direct scan fallback only if unknown/dirty
```

Converted first high-frequency targets:

```text
repair discovery
consecration target discovery
ground item pickup discovery
retention container discovery
resource doctrine loose item / inventory / mineable source discovery
```

Further candidates should follow the same rule and must not add another dirty region cache.

## 0.1.611 Implementation Note — Candidate B partial

Implemented the safe first slice of Pathfinding Reuse / Movement Intent Deduplication without caching engine paths. The existing movement controller remains the sole owner of ground-priest movement commands.

The change tracks active movement request ids inside `movement_controller.lua` and services those requests through the runtime broker. This reduces broad movement polling because the controller no longer has to iterate every pair just to find the few pairs that currently have movement intent.

This is deliberately not full path reuse. Future path corridor caching remains deferred until telemetry proves repeated same-cell movement is a real cost and until stale-path invalidation rules are designed.

Metrics to watch:

```text
/tp-runtime-report
movement-controller-0611 active_requests
movement-controller-0611 active_processed
pathing-accounting active_processed
pathing-accounting movement_budget_exhausted
service movement_controller_service_0611 budget_exhausted
```

If active requests stay low while all-pair counts are high, this pass is doing useful work. If movement budget exhaustion rises, the next revision should increase broker budget or add fair round-robin indexing inside the existing active-request set, not another movement authority.

## 0.1.612 Implementation Note — Scan Routing Batch 2

Continued Candidate D / scan-routing work without creating a new cache authority. Additional repeated discovery sites now use `scan_routing_0610.lua` as a leaf helper over the existing indexed catalog:

```text
construction planner clearance/resource/miner checks
construction site planner clearance/resource/miner checks
logistics fetch loose ground item checks
machine fulfillment machine/service scans
machine fulfillment adjacent automation checks
machine fulfillment retention/waste container scans
```

The scan-routing report now sums counters by prefix so new categories such as `construction-resource`, `construction-clearance`, `machine-logistics`, `machine-automation`, and `machine-container` appear in aggregate scan totals automatically. Future scan-routing passes should continue this pattern and should not add another dirty-region cache.


## 0.1.613 Implementation Note — Queue/Event Pressure Reduction

Implemented a safe continuation of Candidate E and Candidate D without creating another authority.

`work_queue_authority.lua` now refreshes folded duplicate orders. This means repeated discoveries or event-fed submissions for the same target update the existing order priority/expiry instead of accumulating duplicates or leaving a stale low-priority order behind.

`event_driven_work_feeder_0608.lua` now also treats build/mine/destroy events as dirty/negative invalidation signals. These events feed existing authorities only:

```text
world-change event
→ mark existing 0579 indexed cache/dirty authority
→ clear nearby 0570 negative-source cooldowns where applicable
→ do not execute work directly
→ do not create another scheduler/cache/task authority
```

New counters to watch:

```text
work-queues refreshed
work-queues claim_examined
event-driven-feeder dirty_seen
event-driven-feeder dirty_touched
event-driven-feeder dirty_invalid
```

If `claim_examined` becomes large compared with useful claims, future work should optimize inside `work_queue_authority.lua` itself, likely by adding an internal cell index or cursor. That would be a refinement of the existing queue authority, not a second queue system.


## 0.1.614 Implementation Note — Work Queue Internal Spatial Claim Index

Implemented a bounded internal refinement of Candidate C/D pressure points: queue claim pressure reduction. This does not create a second queue. `work_queue_authority.lua` remains the sole shared backlog owner. The new spatial cell index is an implementation detail beneath that owner, used only to reduce how many queued orders `claim_nearest()` must examine before it finds nearby work.

Future tuning must use telemetry before changing behavior:

```text
work-queues spatial_hit
work-queues spatial_miss
work-queues spatial_examined
work-queues full_fallback
work-queues claim_examined
```

If spatial misses or full fallbacks dominate, tune the internal cell size/search radius. Do not add another work queue, another reservation layer, or another scheduler.


## Candidate status after 0.1.615

Implemented or partially implemented:

- Event-driven repair work feeding.
- Directed repair wakeups.
- Spatial-interest theater suppression for overhead/audio presentation.
- Cache-first scan routing for repair, consecration, pickup, construction, logistics, and resource doctrine paths.
- Movement active-request servicing.
- Work-queue spatial claims.
- Work-queue no-work claim cooldowns invalidated by category generation changes.

Next highest-value candidates remain planning-only until telemetry shows need:

- Broader movement command funnel adoption for remaining direct `set_command` callers.
- Dynamic broker budget weighting based on live queue/crisis pressure.
- Event-fed construction/pickup/sanctification order creation where existing event data is reliable.
- Senior-priest squad delegation, only after executor ownership is stable.


## 0.1.616 implementation note

The next large clawback began with movement command funnel adoption and event-fed construction/pickup/sanctify queue submission. This remains intentionally bounded: events feed the existing work queue and directed wake paths; movement fallbacks route through the existing movement controller where possible. Future work should connect construction, pickup, and sanctify consumers to the shared queue only where executor ownership is already clear.

## 0.1.618 Implementation Note — Adaptive Broker Budget Weighting

Implemented the safe first slice of runtime budget market behavior inside the existing `runtime_tick_broker.lua` authority. This is not a new scheduler. It only adjusts the soft budget passed to already-registered broker services based on existing rolling telemetry.

Current pressure inputs include:

```text
repair: event_repair_submitted + directed_wake_issued
movement: path_requests + movement_active_requests_processed
construction: event_construction_submitted + directed_wake_construction_issued
sanctify/consecration: event_sanctify_submitted + directed_wake_sanctify_issued
pickup/logistics: event_pickup_submitted + directed_wake_pickup_issued
```

The broker may pass a higher budget to a hot category while leaving cadence, priority, queue ownership, reservations, pathing, and execution untouched. This should help bursty work drain faster without adding another timing authority.

Watch `/tp-runtime-report`:

```text
adaptive-budget-0618 boosts
rolling_boosts
repair_pressure
movement_pressure
construction_pressure
sanctify_pressure
pickup_pressure
service ... offered= ... adaptive_boosts= ...
```

If this creates starvation or noisy budget expansion, refine thresholds inside the broker only. Do not create a second budget manager.


## 0.1.620 Implementation Note — Maintenance cleanup rotation

Implemented a bounded cleanup traversal refinement inside existing authorities. `work_queue_authority.lua` and `work_reservations.lua` now rotate maintenance cleanup by category when invoked by their broker services without an explicit category. This is not a new scheduler; it reduces cleanup spike pressure beneath the existing broker cadence and budget.

Metrics to watch:

```text
/tp-runtime-report
work-queues cleanup_rotations cleanup_budget_exhausted
reservations cleanup_rotations cleanup_budget_exhausted
```

If cleanup budget exhaustion grows continuously, the next action should be raising the existing broker cleanup budget or adding targeted cleanup calls from the existing owner, not creating another cleanup authority.


## 0.1.621 Implementation Note — Movement command funnel adoption

The next safe clawback after cleanup rotation was not another queue/cache/scheduler. The existing movement controller already owns ground priest route requests, active movement service, retarget collapse, and fallback command routing. This pass therefore moved selected raw `set_command` fallback paths underneath that owner instead of introducing a new movement optimization system.

Useful follow-up candidate: continue auditing direct `set_command` callers, but only convert paths where the movement controller can preserve semantics. Combat, platform hover, priest recovery safety, and true emergency stop paths may need to remain direct or be handled through explicitly documented controller APIs.

## 0.1.622 Implementation Note — Conclave Task Auspex telemetry tab

The next efficiency-support tool is an in-game visibility surface rather than another runtime authority. The Task Auspex / Debug Readout tab lives inside the existing Command Overview / Conclave GUI and reads current telemetry from the broker, buckets, queues, reservations, sleep/wake governors, event feeder, scan router, movement controller, and selected pair order queue.

This is intentionally UI-only. It must not become a scheduler, task selector, queue, reservation manager, cache, sleep state, or movement authority. Its value is operational: future performance passes can be validated from the live Conclave menu by watching task churn, queue pressure, wake/sleep behavior, cache hits/misses, path pressure, and individual pair order stacks.


## 0.1.623 Implementation Note — Debug UI must not become the new runtime tax

The Task Auspex is useful because it exposes churn, but a debug UI can itself become churn if it eagerly renders every ledger on every open/click. 0.1.623 therefore keeps the default overview compact and renders heavy diagnostic sections only when explicitly selected. This is a supporting efficiency pass: it does not create a new runtime authority; it only prevents observability from becoming its own UPS burden.

Future GUI/debug efficiency candidates should follow this rule: diagnostics may read existing telemetry, but they should not force repeated full scans, repeated table construction, or repeated command-overview rebuilds while the player is merely observing.
