# Stage 5 Checkpoint — Machine Logistics Fulfillment 0528

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/logistics_machine_fulfillment_0528.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`logistics_machine_fulfillment_0528.lua` is a dispatcher-priority machine logistics leaf. It is not a free-running controller. It patches `single_dispatcher_0510.service_pair` and tries to service nearby non-automated assemblers/furnaces before the dispatcher falls through to raw acquisition or emergency production.

It has real phased state:

```text
waiting-known-source-fetch
move-to-machine
move-to-storage
complete
```

The file is useful and intentional, but it has more dead-end/stall risk than `direct_acquisition_executor_0513.lua`, mostly because machine logistics can hold a task in memory while waiting for a fetch, a movement request, or a storage deposit that may not ever complete.

No immediate behavior patch is recommended from this first review, but this file is now a high-priority Stage 5 watch area.

## Confirmed healthy structures

### It is dispatcher-priority, not free-running

The file header says it is installed as a high-priority dispatcher wrapper. Manual review confirms this:

```text
patch_dispatcher()
  -> wraps single_dispatcher_0510.service_pair
  -> M.service_pair(...) acts first if machine logistics has work
  -> otherwise falls through to the previous dispatcher service
```

Disposition: intentional dispatcher-priority leaf.

### It skips automated machines by default

The module scans nearby assemblers/furnaces, checks adjacent automation, and defaults to `service_unautomated_only = true`.

Disposition: intentional anti-overreach guard.

### It clears invalid machine tasks

`continue_task(pair)` clears `pair.machine_logistics_0528` when the machine is invalid:

```text
if not valid(machine) then pair.machine_logistics_0528 = nil; return false, "machine-invalid" end
```

Disposition: healthy invalid-target cleanup.

### It clears completed task state

If the active task phase is `complete`, it clears `pair.machine_logistics_0528` on the next continuation pass.

Disposition: healthy completion cleanup.

### It returns station leftovers when partial machine insert happens

For fuel and ingredient supply, if fewer items are inserted than were removed from the station, it attempts to return leftovers through `tech_priests_safe_deposit_item`.

Disposition: healthy partial-insert mitigation, assuming the safe-deposit API is available and accepts the item.

## Watch item 1 — `waiting-known-source-fetch` has no visible timeout

When a machine needs fuel or an ingredient not present in station inventory, `begin_task(...)` sets:

```text
pair.active_supply_request = {...}
pair.logistic_requested_item = {...}
pair.machine_logistics_0528 = {
  phase = "waiting-known-source-fetch",
  ...
}
```

Then `continue_task(...)` does this:

```text
if station_count(pair, task.item) >= needed then
  task.phase = "move-to-machine"
  task.action = fulfill_action
  return true, "known-source-fetched-now-supply"
end
return false, "waiting-known-source-fetch"
```

Potential consequence:

```text
If known-source fetch never obtains the item, pair.machine_logistics_0528 can remain waiting-known-source-fetch indefinitely.
```

Because `M.service_pair(...)` returns `false` for this phase, the dispatcher wrapper falls through to previous dispatcher behavior. That softens the stall, but the stale machine-logistics state can remain attached to the pair and keep rechecking forever.

Current disposition:

```text
Watch item. Not patched yet.
```

Recommended future repair shape:

```text
Add a timeout or retry counter to waiting-known-source-fetch.
On expiry, clear pair.machine_logistics_0528 and pair.logistic_requested_item only if still owned by machine-logistics-0528.
Record a diagnostic event such as machine-need-fetch-timeout.
```

Do not apply until logistics_fetch_executor_0527 is reviewed.

## Watch item 2 — movement request failure is ignored during `move-to-machine`

When the priest is not close enough to the machine, `continue_task(...)` does:

```text
request_move(pair, machine, "machine-service-0528", 1.25)
return true, "moving-to-machine"
```

`request_move(...)` returns false if `tech_priests_request_movement_0418` is unavailable or rejects the request, but `continue_task(...)` ignores that return value and still reports the task as active/moving.

Potential consequence:

```text
If movement request fails, the dispatcher thinks machine logistics acted, but the priest may not move.
The task remains in move-to-machine and can loop forever.
```

Current disposition:

```text
Real possible dead-end, but do not patch before movement_controller.lua review.
```

Recommended future repair shape:

```text
If request_move(...) fails, record movement-request-failed-0528 and either:
  - return false so dispatcher can fall through, or
  - clear/retry with a cooldown, or
  - route through the movement authority fallback if that is the chosen doctrine.
```

## Watch item 3 — movement request failure is ignored during `move-to-storage`

`deposit_carried(...)` behaves similarly when storage is too far away:

```text
task.phase = "move-to-storage"
request_move(pair, box, ...)
return true, "moving-to-storage"
```

Again, request failure is not checked.

Potential consequence:

```text
If movement request fails, the task can remain move-to-storage while carrying a logical item forever.
```

Current disposition:

```text
Real possible dead-end, but delay repair until movement_controller.lua review.
```

## Watch item 4 — output clearing can create logical carried items that cannot be deposited

For `clear-output`, once adjacent to the machine, the module removes items from the machine inventory:

```text
removed = remove_inv(inv, task.item, want)
task.carried = { item=task.item, count=removed, kind=... }
task.phase = "move-to-storage"
return deposit_carried(pair, task)
```

If `deposit_carried(...)` cannot find a box, it returns false, but the logical carried item remains in `task.carried` and the task remains in `move-to-storage`.

Potential consequence:

```text
Machine output/waste is removed from the machine, but no physical inventory receives it.
The pair can hold a logical carried item indefinitely if no valid storage/waste box exists.
```

For retention items, `find_box(...)` can fall back to station chest if it can insert. For waste items, there is no station fallback if no waste box can accept the item.

Current disposition:

```text
High-value Stage 5 watch item.
```

Recommended future repair shape:

```text
Before removing output/waste from the machine, reserve or verify a valid destination.
If no destination exists, do not remove the item from the machine.
For waste, either require a valid waste box before removal or explicitly support station-safe fallback if doctrine allows it.
```

This is probably more important than the direct-acquisition deposit watch item, because here the item is removed first and only then deposited.

## Watch item 5 — `complete` phase clears only on next continuation pass

Several successful paths set:

```text
pair.machine_logistics_0528 = { phase="complete", ... }
```

Then the next `continue_task(...)` clears it.

This is probably intentional so diagnostics can see the last completed state. However, it means diagnostics may show `phase=complete` for one tick/window.

Current disposition:

```text
Likely intentional diagnostic retention, not a bug.
```

## Watch item 6 — `active_supply_request` / `logistic_requested_item` ownership cleanup

The module sets:

```text
pair.active_supply_request
pair.logistic_requested_item
```

when handing off to known-source fetch.

This checkpoint did not verify whether `logistics_fetch_executor_0527.lua` clears both fields on success/failure. That must be reviewed before patching `waiting-known-source-fetch` timeout behavior.

Current disposition:

```text
Carry forward to logistics_fetch_executor_0527 review.
```

## Current Stage 5 decision

No code repair yet, but machine logistics is now a stronger repair candidate than direct acquisition.

Current priority findings:

```text
1. waiting-known-source-fetch lacks visible timeout.
2. move-to-machine ignores movement request failure.
3. move-to-storage ignores movement request failure.
4. clear-output removes item before guaranteeing storage destination.
5. logistic_requested_item / active_supply_request cleanup must be verified in logistics_fetch_executor_0527.
```

## Recommended next manual target

Review:

```text
scripts/core/logistics_fetch_executor_0527.lua
```

Focus:

- Does it clear `pair.logistic_requested_item` after successful fetch?
- Does it clear `pair.active_supply_request`?
- What happens when the known source disappears?
- What happens when the station cannot accept the fetched item?
- Does it time out or fail a request cleanly?
- Does it interact with machine-logistics `waiting-known-source-fetch` in a way that prevents indefinite waiting?

## Live diagnostics after packaging

Use:

```text
/tp-machine-logistics-0528
/tp-order-queue-0469
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- `task_phase=waiting-known-source-fetch` that never clears.
- `task_phase=move-to-machine` without movement progress.
- `task_phase=move-to-storage` without movement progress.
- repeated `insert-failed` / `no-box` outcomes.
- machine output cleared but no retention/waste deposit event.
