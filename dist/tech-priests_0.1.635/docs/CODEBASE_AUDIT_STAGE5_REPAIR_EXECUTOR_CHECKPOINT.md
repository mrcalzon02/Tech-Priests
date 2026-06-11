# Stage 5 Checkpoint — Repair Executor 0516

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/repair_executor_0516.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`repair_executor_0516.lua` is a dispatcher-owned repair leaf. It is structured and intentional: it selects damaged targets, spreads repair work through shared reservations, walks to repair range, consumes repair packs on timed ticks, repairs until full health or supply failure, wraps legacy repair entry points, and exposes diagnostics.

No immediate repair is recommended from this pass.

However, it confirms the movement-completion audit pattern again:

```text
The executor can enter walk-to-target after submitting movement intent, but it does not check whether movement request submission failed.
```

It also uses TTL-based reservation cleanup in several failure paths rather than immediate release. That is not automatically wrong, but it is worth tracking in live diagnostics.

## Confirmed healthy structures

### Dispatcher-owned repair design

The file header states the intent clearly: the old `repair_target` path made priests look lazy, allowed partial repairs, and allowed multiple priests to pile onto one target. This executor converts repair into a visible phased action:

```text
select damaged target by urgency
reserve target
walk to repair range
spend timed repair ticks
consume repair packs
continue until fully repaired or supplies fail
```

Disposition: coherent dispatcher leaf.

### Target selection is urgency-aware

`score_target(...)` prioritizes:

- damage ratio;
- missing health;
- target type urgency such as walls/turrets/machines;
- priest/station proximity.

Disposition: healthy target selection.

### Reservation integration exists

The executor first uses shared `work_reservations` when available:

```text
R.claim("repair", entity, pair, M.reservation_ttl_ticks, ...)
R.release("repair", entity, pair)
```

It also has local fallback reservations if shared reservations are unavailable.

Disposition: healthy spread-target intent.

### Completion cleanup is strong

On full repair, the executor:

- sets state phase `complete`;
- records completed tick;
- releases the target reservation;
- places the target on cooldown;
- sets pair repair cooldown;
- clears `pair.target`;
- sets `pair.mode = "idle"`;
- completes matching order queue current repair order;
- clears state target/timing fields after pack-driven completion.

Disposition: healthy completion path.

### Diagnostics exist

The module installs:

```text
/tp-repair-executor-0516
```

and adds pair-dump lines for phase, target, missing health, packs, blocker, due tick, and distance.

Disposition: useful live diagnostic surface.

## Watch item 1 — `walk-to-target` ignores movement request failure

When the target is outside repair range, the executor does:

```text
request_move(pair, target, "repair-executor-0516-walk-to-target")
state.phase = "walk-to-target"
pair.mode = "moving-to-repair"
return true, "walk-to-target"
```

The return value from `request_move(...)` is ignored.

`request_move(...)` itself has several fallback layers:

1. `tech_priests_request_movement_0418`
2. `move_priest_to`
3. `tech_priests_route_ground_command_0429`
4. direct priest command fallback

Because of those fallbacks, failure may be rare. But if all movement routes fail, the executor can still claim `walk-to-target` and `moving-to-repair`.

Current disposition:

```text
Movement-contract watch item. Do not patch during audit-only continuation.
```

Future repair shape:

```text
If request_move(...) returns false, record movement-request-failed-0516 and return false or enter a retry/cooldown phase instead of claiming walk-to-target.
```

## Watch item 2 — reservation may remain through TTL after movement/supply failure

The executor reserves the target before movement and before the final supply check. It releases the target on completion, but some failure paths leave release to TTL cleanup:

- movement request failure is not observed, so no release occurs there;
- `consume_pack(...)` failure sets `need-item` and returns false without immediate release;
- if the target becomes invalid after being remembered in `state.target`, the executor sets `target-invalid` and seeks another target, but previous shared reservation release is not obviously paired at that moment;
- if station repair packs disappear after target reservation, the target can remain claimed until reservation TTL.

This is not automatically wrong because:

- reservations have TTL;
- holding a target briefly during supply uncertainty may prevent thrashing;
- shared reservation cleanup is brokered elsewhere.

Current disposition:

```text
Watch in live diagnostics. Not a repair yet.
```

Future repair shape:

```text
Release target immediately when entering durable need-item / target-invalid / movement-request-failed states, but only if the reservation still belongs to this pair.
```

## Watch item 3 — `target-invalid` does not obviously clear `state.target`

When a remembered target fails `eligible(...)`, the executor does:

```text
target = nil
state.phase = "target-invalid"
state.last_blocker = why
```

Then it searches for a new target. Later, if a new target is found, `state.target` is replaced. If no target is found, the old state target may remain visible in diagnostics unless overwritten/cleared elsewhere.

Current disposition:

```text
Diagnostic stale-state watch item, not confirmed behavior bug.
```

Future repair shape:

```text
When target is declared invalid, clear state.target/state.target_unit/state.target_name if they still refer to that invalid target.
```

## Watch item 4 — repair order completion is narrow

`complete_order(...)` only completes the current order if `q.current` exists and is repair-like. If the repair task was adopted through task scheduler or legacy task fields without a matching order queue current, completion still repairs the target but may not clear all legacy task surfaces.

Current disposition:

```text
Low-priority compatibility watch item.
```

No clear bug was proven in this pass.

## Comparison to previous Stage 5 findings

Compared with `logistics_machine_fulfillment_0528.lua`, repair is safer because it does not remove machine inventory before destination validation and does not hold logical carried items.

Compared with `direct_acquisition_executor_0513.lua`, repair is safer because it does not count a failed deposit as gathered material.

Its main shared weakness is the movement contract issue:

```text
movement requested does not equal movement completed;
movement request failure is not always handled by the task owner.
```

## Current Stage 5 decision

No code repair from this pass.

Current priority ranking remains:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. 0514 emergency production returning/deposit-block diagnostics.
5. 0516 repair movement failure/reservation release refinement.
```

## Recommended live diagnostics after packaging

Use:

```text
/tp-repair-executor-0516
/tp-runtime-report
/tp-task-auspex
/tp-order-queue-0469
```

Watch for:

- `phase=walk-to-target` while `movement_request_0418` is nil;
- repeated `walk` records without distance shrinking;
- `need-item` while the repair target remains reserved;
- `target-invalid` with stale target name/unit still visible;
- shared repair reservation counts not decaying after failures.

## Recommended next manual target

Continue with:

```text
scripts/core/consecration_executor_0515.lua
```

Focus:

- movement request semantics;
- target claim/release;
- target invalidation;
- completion cleanup;
- whether consecration can hold stale work phases like repair/logistics.
