# Stage 5 Checkpoint — Dead-End Transition Site Report

This checkpoint records the first interpretation of the Stage 5 transition-site report.

This is documentation-only. No runtime behavior has been changed by this note.

## Reports reviewed

Broad field inventory:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_STATE_FIELDS.json
```

Second-pass transition report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.json
```

Scanner:

```text
tools/audit_dead_end_transition_sites_v2.py
```

## Plain-English result

The broad Stage 5 inventory is real and large:

```text
8094 state-field hits
```

That report is useful as a map, but too broad for repair. The second-pass transition scanner reduced it to likely state mutation points:

```text
1593 transition sites
```

This gives us a practical review order without treating every field reference as a bug.

## Transition report counts

From `CODEBASE_AUDIT_STAGE5_DEAD_END_TRANSITION_SITES.md`:

| Group | Count |
|---|---:|
| `mode` | 558 |
| `order-queue` | 348 |
| `reservations` | 125 |
| `status-transition` | 98 |
| `direct-acquisition` | 87 |
| `active-task` | 67 |
| `pause-resume` | 61 |
| `emergency-craft` | 58 |
| `logistics` | 41 |
| `combat` | 40 |
| `movement` | 39 |
| `lifecycle-recall-missing` | 37 |
| `mode-transition` | 26 |
| `consecration` | 7 |
| `repair` | 1 |

By transition kind:

| Kind | Count |
|---|---:|
| `assignment` | 1016 |
| `clear` | 303 |
| `status-assignment` | 98 |
| `reservation-transition-reference` | 78 |
| `pause-resume-reference` | 61 |
| `mode-assignment` | 26 |
| `reservation-api-call` | 11 |

By risk hint:

| Risk hint | Count |
|---|---:|
| `transition review` | 804 |
| `cleanup/clear path` | 303 |
| `order queue state set` | 280 |
| `pause/resume transition` | 61 |
| `executor phase/task set` | 52 |
| `wait/travel/pause state set` | 31 |
| `reservation claim path` | 24 |
| `movement state/request set` | 20 |
| `lifecycle pressure set` | 12 |
| `reservation release path` | 6 |

## First manual target: `order_queue_0469.lua`

`order_queue_0469.lua` is the largest single modern transition owner in the report.

Manual review found that the order queue is noisy because it legitimately owns many transitions:

- `q.current` assignment and clear.
- `pair.active_order_0469` assignment and clear.
- pending queue insertion.
- pending key rebuild.
- duplicate blocking.
- active order start.
- preemption and pause.
- promotion from pending to current.
- failure.
- cancellation.
- expiry/completion.
- surface adoption from existing legacy state.

Important healthy structures:

- `queue(pair)` rebuilds `pending_keys` defensively and filters completed/failed/cancelled pending orders.
- `M.submit(...)` blocks duplicate current/pending keys.
- Higher-priority orders pause the current order and put it at the front of pending.
- `order_should_finish(...)` handles expired orders, invalid pair, invalid target, cleared combat, cleared legacy surface, and idle/returning surfaces.
- `pop_next(...)` skips complete/failed/cancelled/expired pending orders.
- `M.fail_current(...)`, `wrap_cancel_task(...)`, and `tick_pair(...)` clear `q.current` and `pair.active_order_0469`.

Potential watch items, but not confirmed bugs:

1. `fail_current_if_order(...)` clears the current order but does not immediately call `promote(...)`. This may be intentional because the next tick can promote, but it is a possible one-tick no-current gap.
2. `promote(...)` can set a new current order whose activation callback returns `no-direct-callback`. The current order remains active and may complete on later legacy-surface checks. This may be intentional compatibility behavior, but is worth checking in live diagnostics.
3. `q.stats.completed` increments even when the current order is marked failed due to expiry. This is diagnostic noise, not necessarily behavior-critical.

Current disposition:

```text
order_queue_0469.lua looks structurally coherent.
No code repair from this first review.
Keep it as a Stage 5 watch area, especially around activation callback failures and paused order resume behavior.
```

## Second manual target: `work_reservations.lua`

The transition report showed more claim-like than release-like sites. Manual review found that this is not automatically a bug because reservations are designed to be short-lived and expire.

Important healthy structures:

- `M.claim(...)` sets `expires_tick` on every reservation.
- `M.get(...)` removes an expired reservation when it is observed.
- `M.cleanup_expired(...)` removes expired reservations through the broker service.
- `M.release(...)` exists for explicit release.
- `M.install()` registers broker cleanup as `work_reservations_0601_cleanup`.

Current disposition:

```text
Claim/release imbalance is expected in this design because expiry cleanup is a primary release path.
No code repair from claim/release counts alone.
```

Remaining watch item:

```text
M.categories = { "repair", "sanctify", "resource", "construction", "pickup", "combat" }
```

The reservation authority can dynamically create unknown category buckets through `M.claim(...)`, but rotated cleanup and report output only walk `M.categories`. Therefore, if an `emergency` reservation is ever actually created, it may not be part of regular rotated cleanup or report output.

This keeps the earlier `emergency` mismatch as a probable tiny repair candidate only if reachability is confirmed.

## Current Stage 5 decision

No repair yet.

The transition report is now good enough to guide manual review, but the first two high-count areas are not obvious broken code:

```text
Order queue: structurally coherent, watch activation/resume edges.
Reservations: expiry cleanup explains claim/release imbalance, watch dynamic category cleanup.
```

## Recommended next manual targets

The next Stage 5 review should focus on wait/travel states because those are more likely to produce visible stuck behavior than the order queue itself:

1. `direct_acquisition_executor_0513.lua`
   - phases around walk/work/deposit/return/yield.
   - `travelling-to-direct-acquisition` and `travelling-to-dirt-scrape` interactions.
   - target invalidation and deposit failure cleanup.

2. `logistics_machine_fulfillment_0528.lua`
   - `waiting-known-source-fetch`.
   - `move-to-machine`.
   - `move-to-storage`.
   - output/fuel/ingredient partial transfer cleanup.

3. `movement_controller.lua`
   - movement request set/clear.
   - stale lease cleanup.
   - direct command fallback review.

4. `priest_recovery_safety_0503.lua` / `movement_recovery_authority_0508.lua`
   - lifecycle pressure fields.
   - missing-priest pause/unpause.
   - recall/stuck flag clearing.

## Live diagnostic commands to use after packaging

```text
/tp-order-queue-0469
/tp-runtime-report
/tp-task-auspex
/tp-priest-lifecycle-0500
```

Useful observations:

- Is `current` stuck on an order with `last_activate_result=no-direct-callback`?
- Do pending orders resume after preemption?
- Are reservation counts decaying over time?
- Are missing-priest pause states being unpaused by 0508 when the priest is valid?
