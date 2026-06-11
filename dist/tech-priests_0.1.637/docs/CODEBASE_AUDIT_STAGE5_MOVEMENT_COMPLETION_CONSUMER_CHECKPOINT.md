# Stage 5 Checkpoint — Movement Completion Consumers

This checkpoint records the audit of activities that depend on movement reaching a target, station, source, machine, storage box, or work site.

This is documentation-only. No runtime behavior has been changed by this note.

## Files and reports reviewed

Generated report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_MOVEMENT_COMPLETION_CONSUMERS.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_MOVEMENT_COMPLETION_CONSUMERS.json
```

Scanner:

```text
tools/audit_movement_completion_consumers.py
```

Manual review focus:

```text
scripts/core/logistics_fetch_executor_0527.lua
scripts/core/logistics_machine_fulfillment_0528.lua
scripts/core/ground_item_hoover_0529.lua
scripts/core/crafting_executor.lua
previous Stage 5 reviews of construction, repair, consecration, emergency production, direct acquisition
```

## Plain-English result

The codebase still does not have a broad movement-finished message/event consumed by behavior modules.

Instead, the dominant pattern is:

```text
Activity requests movement.
Movement controller accepts/rejects the intent.
Activity keeps a local phase such as moving/walk/returning.
Activity later polls distance/proximity and proceeds if close enough.
```

Batch 1 improved this for 0527 and 0528 by checking immediate movement request failure, but it did not make activities consume full movement status.

The movement status helper now exists, but most activities do not yet call it:

```text
tech_priests_movement_status_0418(pair, owner)
```

Therefore the current movement completion state is:

```text
immediate request failure: handled in 0527/0528 only so far
arrival: usually detected by local distance/proximity checks
expired/replaced/clamped/no-progress: generally not consumed by activity owners yet
```

## Generated report summary

The movement completion consumer report found:

```text
Total hits: 2357
Files with hits: 159
```

Counts by kind:

```text
proximity-or-radius-check: 1509
movement-phase-string: 444
movement-request: 243
movement-status-or-state: 161
```

Interpretation:

```text
The codebase contains many proximity checks and many movement phase strings.
Movement request usage is widespread.
Explicit movement status/state consumption is much less common.
```

The scanner is intentionally broad. It identifies review targets, not proven bugs.

## Important scanner limitation

The `risk_hint` is heuristic.

For example, files marked `high-no-status` may still be partially healthy if they:

```text
poll distance every service pulse;
clear invalid targets;
retry movement;
have local stale-progress detection;
are wrapped by modern authority layers.
```

But `high-no-status` is still useful because it usually means:

```text
the activity does not consume movement status/expired/replaced/clamped information.
```

## Confirmed consumer classes

### Class A — Now handles immediate request failure, but not full status

```text
logistics_fetch_executor_0527.lua
logistics_machine_fulfillment_0528.lua
```

Batch 1 added:

```text
movement-request-failed-0527
movement-request-failed-0528
```

These modules now avoid claiming movement when movement request submission returns false.

Remaining gap:

```text
They still do not consume movement status for expired/replaced/clamped/no-progress request states.
```

### Class B — Polls distance/proximity, but ignores movement request failure

These activities rely on local distance checks to determine arrival but do not yet handle request failure consistently:

```text
ground_item_hoover_0529.lua
construction_planner.lua
repair_executor_0516.lua
consecration_executor_0515.lua
emergency_production_executor_0514.lua
crafting_executor.lua
older acquisition_executor.lua
```

Typical pattern:

```text
if far then
  request_move(...)
  phase = "moving/walking/returning"
  return true, "moving"
end

if close enough then
  do work
end
```

This works only while movement succeeds or eventually arrives.

Missing consumption:

```text
request rejected
request missing
request expired
request replaced by other owner
request clamped forever
request active but no progress
```

### Class C — Polls distance and has some local stale-progress logic

```text
direct_acquisition_executor_0513.lua
```

Direct acquisition is better than most because it has:

```text
movement refresh
stall/progress checks
repath behavior
target invalidation cleanup
work clamp transition
```

Remaining gap:

```text
deposit/gathered_units correctness, not movement completion, is its larger Stage 5 concern.
```

### Class D — Movement authority/governor modules

```text
movement_controller.lua
movement_bounds_contract_0511.lua
movement_cadence_contract_0518.lua
movement_enforcement_0566.lua
authority_corridor_pathing_0574.lua
```

These modules inspect movement state because they are part of movement authority, enforcement, or bounds logic.

They are not normal activity consumers.

### Class E — Generated legacy/platform/special-case modules

Generated legacy files show many hits, but they must be handled carefully because:

```text
some are wrapped by 0509/0511/0518/0566;
some are platform movement exceptions;
some are legacy direct-command surfaces that should not be mass-edited.
```

Generated file risk should remain behind modern owner-layer repairs.

## Manual finding — `ground_item_hoover_0529.lua`

`ground_item_hoover_0529.lua` is the most important newly surfaced modern activity consumer.

It does physically poll distance for pickup and storage deposit:

```text
move-to-item
move-to-storage
```

But it currently does this pattern:

```text
request_move(pair, box, ...)
record(pair, "move-to-storage", ...)
return true, "moving-to-storage"
```

and:

```text
request_move(pair, src, ...)
return true, "moving-to-ground-item"
```

without checking whether `request_move(...)` returned false.

Risk:

```text
The pair can report moving-to-ground-item or moving-to-storage even if no movement request was accepted.
```

This is more important than some other modules because 0529 can hold logical carried items after pickup.

Recommended next repair candidate after Batch 1:

```text
Add movement request failure handling to 0529 move-to-item and move-to-storage paths.
Do not add timeout or storage behavior changes in the same patch.
```

## Manual finding — `crafting_executor.lua`

`crafting_executor.lua` checks proximity with:

```text
at_station(pair)
```

and repeatedly asks the priest to return to the station before crafting.

But `move_to_station(...)` returns true and sets:

```text
pair.mode = "returning-to-station-for-craft"
```

even if movement request submission did not succeed.

Risk:

```text
The visible craft ritual can remain in returning-to-station behavior without a valid movement request.
```

Severity is lower than 0529 because it does not appear to hold a logical carried item removed from another inventory. It is still a movement-contract consumer gap.

## Manual finding — construction / repair / consecration / emergency production

Previous Stage 5 reviews found the same pattern:

```text
construction: returning-to-station and moving-to-site ignore movement request failure
repair: walk-to-target ignores movement request failure
consecration: walk-to-target ignores movement request failure
emergency production: returning-to-station records movement ok/failure but still reports returning
```

They usually poll distance/proximity to advance, but do not consume expired/replaced/clamped/no-progress movement status.

## Meaning of “movement finished” in current code

There is still no central callback/event like:

```text
movement_finished(pair, owner, result)
```

The current behavior is:

```text
Movement controller stores request state.
Activity owner must poll proximity or status.
```

That design is acceptable if activity owners consistently poll and handle terminal states.

Current problem:

```text
activity owners mostly poll proximity but do not handle terminal failure/status states.
```

## Recommended repair rollout

### Batch 2 candidate — 0529 immediate movement request failure handling

Scope:

```text
ground_item_hoover_0529.lua move-to-item
ground_item_hoover_0529.lua move-to-storage
record movement-request-failed-0529
do not add timeout
do not change storage placement/deposit behavior
```

Reason:

```text
0529 is a modern dispatcher-owned logistics activity and can hold carried items.
It has the same simple failure-handling gap that Batch 1 fixed for 0527/0528.
```

### Batch 3 candidate — crafting/emergency return-to-station failure handling

Scope:

```text
crafting_executor.lua move_to_station
emergency_production_executor_0514.lua return-to-station path
```

Reason:

```text
Both can report returning-to-station even when movement request submission failed.
```

### Batch 4 candidate — repair/consecration/construction failure handling

Scope:

```text
repair_executor_0516.lua walk-to-target
consecration_executor_0515.lua walk-to-target
construction_planner.lua returning-to-station / moving-to-site
```

Reason:

```text
These are visible work phases that depend on eventual proximity.
```

### Later coordinated movement-status integration

After simple request-failure handling is applied, add actual status consumption to selected modules:

```text
if movement status is arrived:
  allow phase transition if proximity agrees

if movement status is expired/missing/replaced:
  retry, clear, or fall through

if movement status is clamped:
  wait only while clamp is legitimate, eventually timeout or replan
```

Do not try to apply this across all modules at once.

## Current priority update

```text
1. 0529 ground item hoover movement request failure handling.
2. 0527/0528 later status/timeout cleanup after Batch 1 smoke test.
3. 0513 deposit/gathered_units correctness.
4. crafting/emergency return-to-station movement failure handling.
5. repair/consecration/construction movement failure handling.
6. broader movement status consumption for expired/replaced/clamped/no-progress.
7. generated legacy reachability only after modern owners are patched.
```

## Live diagnostics

Use:

```text
/tp-movement-0429
/tp-ground-hoover-0529
/tp-logistics-fetch-0527
/tp-machine-logistics-0528
/tp-task-auspex
/tp-runtime-report
```

Watch for:

```text
phase=move-to-item with missing/expired movement request
phase=move-to-storage with missing/expired movement request
phase=returning-to-station-for-craft with missing movement request
movement_controller_status_0418=expired while activity phase still says moving
movement_controller_status_0418=replaced-by-other-owner while old activity phase still owns task
```

## Current decision

No source repair from this checkpoint.

The next source repair should likely be a small Batch 2 for `ground_item_hoover_0529.lua`, using the same narrow pattern as Batch 1:

```text
check request_move return value;
record movement-request-failed-0529;
return false instead of reporting moving;
do not alter timeout/storage/inventory behavior.
```
