# Stage 5 Checkpoint — Direct Acquisition Executor 0513

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/direct_acquisition_executor_0513.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`direct_acquisition_executor_0513.lua` is not a random legacy controller. It is a dispatcher-owned explicit phase machine:

```text
choose/adopt target
  -> walk to target
    -> work target over time
      -> deposit gathered unit
        -> continue, return for station craft, or complete and return
```

The file is structurally much cleaner than the broad transition count alone suggested. It already has target invalidation cleanup, out-of-bounds rejection, stalled movement repath, work clamp, completion cleanup, and legacy-direct-controller blocking.

No immediate behavior patch is recommended from this first review.

## Confirmed healthy structures

### Target invalidation cleanup

If `cur.entity` exists but is invalid, the executor:

```text
clear_direct_due(task)
task.current = nil
pair.target = nil
pair.mode = "direct-acquisition-replan"
phase = "target-invalid"
return false, "target-invalid"
```

Disposition: healthy replan path.

### Missing target-position cleanup

If no target position exists, the executor:

```text
clear_direct_due(task)
task.current = nil
pair.target = nil
phase = "need-target"
return false, "no-target-position"
```

Disposition: healthy replan path.

### Bounds rejection cleanup

If the target is outside movement bounds, the executor:

```text
clear_direct_due(task)
task.current = nil
pair.target = nil
pair.mode = "direct-acquisition-target-rejected"
phase = "target-rejected"
return false, "target-out-of-bounds"
```

Disposition: healthy rejection path.

### Walking/repath behavior

While far from the target, the executor:

- clears old direct due ticks,
- records progress distance,
- refreshes movement after `move_refresh_ticks`,
- repaths after `stall_ticks`,
- sets `pair.mode = "travelling-to-direct-acquisition"`,
- requests movement through `tech_priests_request_movement_0418` when available,
- otherwise routes/falls back to direct command,
- marks phase `walk-to-target`.

Disposition: intentional movement phase. Direct command fallback should remain blocked from migration until movement dead-end audit is complete.

### Work clamp

Once adjacent, the executor:

- stops movement,
- clears `pair.movement_request_0418`,
- clears `pair.pathing_target_0418`,
- clears movement lease where possible,
- sets mode `direct-acquisition-working`,
- sets phase `work-target`,
- starts `task.direct_due_tick_0513` if missing.

Disposition: healthy local work ownership.

### Completion cleanup

On normal non-crafting completion, the executor clears:

```text
task.current = nil
pair.emergency_craft = nil
pair.direct_acquisition_task_0336 = nil
pair.active_acquisition_0333 = nil
pair.target = nil
phase = "complete"
return_to_station(...)
```

Disposition: healthy cleanup path.

### Craft handoff

If the task has a recipe and output item, it clears `task.current`, sets craft-pending flags, sets mode `returning-to-station-for-craft`, and returns to station instead of clearing the whole emergency-craft task.

Disposition: likely intentional handoff to station craft/emergency production.

## Main Stage 5 watch item: deposit failure still increments gathered units

After work finishes, the executor does this in effect:

```text
item = output_item(task, cur)
deposited = deposit(pair, item, 1)
task.gathered_units = gathered_units + 1
```

The `gathered_units` counter increments even when `deposit(...)` returns false.

Potential consequence:

```text
If station inventory insertion is blocked, the executor can still count that unit as gathered.
The task may continue or complete as though materials were acquired.
A recipe handoff may be triggered without actual stored materials.
```

This does not look like the vanished-priest bug. It is more likely an economy/state false-completion risk. But it is a legitimate Stage 5 watch item.

Recommended future repair shape, not yet applied:

```text
Only increment gathered_units when deposit succeeds,
or record failed deposit and retry/return/replan instead of treating it as acquired.
```

This should be delayed until after live diagnostics, because changing this behavior may alter emergency production pacing and could strand priests if deposit failure is common due to a station inventory API mismatch.

## Secondary watch item: direct fallback movement commands

`request_movement(...)` and `return_to_station(...)` both prefer:

```text
tech_priests_request_movement_0418
```

Then they try:

```text
tech_priests_route_ground_command_0429
```

Then they fall back to direct `commandable.set_command(...)` or `set_command(...)`.

Disposition:

```text
Keep for now. Do not remove during Stage 5 until movement_controller.lua has its own dead-end review.
```

## Secondary watch item: stalled progress uses distance only

The walking phase considers progress by comparing current distance to `state.last_distance`. It repaths if no progress is made for `stall_ticks`.

This is probably correct. The only watch item is that pathing around obstacles may temporarily increase distance and trigger repath churn. This is not currently a repair candidate.

## Current Stage 5 decision

No direct acquisition behavior repair yet.

Current disposition:

```text
direct_acquisition_executor_0513.lua is structurally coherent.
Track deposit-failure false completion as the main risk.
Review movement_controller.lua before changing direct movement fallback behavior.
```

## Recommended live diagnostics after packaging

Use:

```text
/tp-order-queue-0469
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- `dispatcher_phase = work-target` with repeated failed deposits.
- acquisition orders completing while station inventory did not receive items.
- `returning-to-station-for-craft` with no actual ingredients stored.
- repeated `travel-repath-0513` records without target invalidation.

## Next Stage 5 manual targets

1. `logistics_machine_fulfillment_0528.lua`
   - `waiting-known-source-fetch`
   - `move-to-machine`
   - `move-to-storage`
   - partial transfer cleanup

2. `movement_controller.lua`
   - request/lease clear
   - stale lease handling
   - direct command fallback boundary

3. lifecycle pressure fields in `0503` / `0508`
   - recall/stuck/missing-priest pause/unpause state
