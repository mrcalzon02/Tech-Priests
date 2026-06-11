# Stage 5 Repair Planning — Movement Completion Contract

This document records the planning conclusion reached after the Stage 5 movement and logistics audits.

This is planning-only documentation. No runtime behavior has been changed by this note.

## Plain-English diagnosis

The current movement controller is an intent-submission system, not a completed-action contract.

The current pattern is often:

```text
Behavior module says: move this priest to X.
Movement controller says: movement request accepted.
Behavior module keeps a local phase such as moving-to-source, move-to-machine, or move-to-storage.
Later behavior only advances if it happens to poll distance/proximity and notice it is close enough.
```

This can work when every task owner polls correctly, clears stale movement state correctly, and handles request failure correctly. But the audit shows that several behavior modules treat movement as fire-and-forget.

The missing contract is:

```text
A movement request needs an observable terminal state.
The requesting behavior needs to know whether movement is still pending, arrived, failed, expired, blocked, clamped, invalid, or replaced.
```

## Corrected understanding

The problem is not simply that the priest cannot move.

The problem is:

```text
Movement can be requested without a reliable completion/failure handshake.
Some task phases wait for proximity, but the movement system does not fire an owner-facing completion message.
Some task phases can say they are moving even when no movement request was accepted.
Some task phases can remain active after movement expires, is clamped, is replaced, or reaches loiter state.
```

Therefore, many buggy behaviors can appear as:

```text
The priest walked partway and stopped.
The priest reached the target but did not begin work.
The priest never reached the target and the task never timed out.
The task says moving-to-X while movement_request_0418 is nil.
The movement controller says loitering but the task still says moving.
The movement request expired but the task phase remains active.
```

## Current movement-controller semantics

From the Stage 5 review of `movement_controller.lua`:

```text
tech_priests_request_movement_0418(...) is an intent-submission API.
```

Return semantics:

```text
true  = request accepted, collapsed, held, or queued for service
false = request not accepted; no reliable movement intent exists
```

Important detail:

```text
true does not mean arrived.
true does not mean the priest has moved yet.
true only means the movement controller accepted ownership of a movement intent.
```

Actual engine commands are issued later by the brokered movement service.

## Why this matters for 0527 and 0528

### `logistics_fetch_executor_0527.lua`

Current problematic pattern:

```text
request_move(pair, src.source, item)
return true, "moving-to-known-source"
```

This ignores whether `request_move(...)` returned false.

### `logistics_machine_fulfillment_0528.lua`

Current problematic patterns:

```text
request_move(pair, machine, "machine-service-0528", 1.25)
return true, "moving-to-machine"
```

and:

```text
request_move(pair, box, "retention-box-deposit-0528", 1.25)
return true, "moving-to-storage"
```

These also ignore request failure.

The movement-controller audit confirms that this is a real stale-state risk. If movement request submission fails, those modules should not claim successful movement.

## Required contract revision

The repair should not be an uncontrolled rewrite of movement. The safer approach is to add a compatibility-preserving movement completion contract.

The contract should answer these questions for a task owner:

```text
Was the request accepted?
Is the request still active?
Was it replaced by another owner?
Has it expired?
Is the priest clamped?
Is the priest close enough to the requested destination?
Did the controller command movement recently?
Is there no progress?
Should the task retry, continue waiting, advance phase, or abandon?
```

## Proposed staged implementation

### Phase 1 — Diagnostics and status helpers only

Add read-only/helper functionality to `movement_controller.lua` without changing current behavior:

```text
M.request_status(pair, owner_or_request_id)
M.has_arrived(pair, request_or_destination, radius)
M.describe_request(pair)
```

Potential returned status vocabulary:

```text
accepted
active
arrived
loitering
clamped
expired
invalid-pair
missing-request
replaced-by-other-owner
no-progress
command-failed
```

Compatibility rule:

```text
Do not change M.request(...) return shape in a breaking way.
Existing callers expecting boolean true/false must continue to work.
```

A safe Lua-compatible pattern would be:

```text
return true, request_id_or_request_table
```

Existing callers using only the first return value remain compatible.

### Phase 2 — Add request IDs / owner tracking if needed

Current movement requests are keyed by pair. That is useful, but task owners also need to know whether their specific request is still the active one.

Add or standardize fields such as:

```text
req.id
req.owner
req.reason
req.phase_owner
req.issued_tick
req.updated_tick
req.expires_tick
req.arrived_tick
req.last_command_tick
req.last_distance_sq
req.last_status
```

Then task modules can ask:

```text
Is my movement request still active?
Was it replaced by another higher-priority owner?
Did it expire?
```

### Phase 3 — Patch high-risk callers first

Patch 0527 and 0528 first because the audit found concrete stale-state risks.

For 0527:

```text
if not request_move(...) then
  record movement-request-failed-0527
  return false, "movement-request-failed"
end
return true, "moving-to-known-source"
```

For 0528:

```text
if not request_move(...) then
  record movement-request-failed-0528
  either return false or clear/cooldown the phase safely
end
```

Important:

```text
Do not yet force all movement-using modules into the new contract.
Start with 0527/0528 because they are already identified as the first repair family.
```

### Phase 4 — Add timeout/progress policy to task owners

Movement controller should expose status. Task owners should decide what status means for their phase.

Example policy for a task phase:

```text
if movement arrived:
  advance to work/deposit phase

if movement missing/replaced/expired:
  retry if still valid and under retry limit
  otherwise clear task and fall through

if movement clamped:
  wait while clamp is valid, but timeout eventually if task owner cannot proceed

if no progress:
  repath or abandon after threshold
```

### Phase 5 — Extend to other movement-dependent executors

After 0527/0528 are stable, review and patch additional families:

```text
direct_acquisition_executor_0513.lua
emergency_production_executor_0514.lua
consecration_executor_0515.lua
repair_executor_0516.lua
combat_repair_doctrine_0517.lua
construction logistics contract paths
legacy movement wrappers still using direct set_command fallbacks
```

## Movement terminal states

Recommended terminal/non-terminal distinction:

### Non-terminal

```text
active
moving
held
clamped
retarget-held
loitering-but-not-owner-confirmed
```

### Terminal success

```text
arrived
within-radius
owner-confirmed-arrival
```

### Terminal failure

```text
request-rejected
expired
invalid-pair
invalid-destination
replaced-by-other-owner
movement-command-failed
no-progress-timeout
```

## Avoiding a dangerous rewrite

This should not be a giant replacement of the movement controller.

The movement controller currently has useful protections:

```text
central request storage
retarget collapse
retarget hold
brokered service
invalid/expired pruning
clamp handling
speed/snap audit
legacy route-command compatibility
```

Preserve those. Add a clearer contract around them.

## Repair risk warnings

### Do not make movement callbacks execute behavior directly

A tempting but dangerous design would be:

```text
movement completes -> movement controller calls behavior executor callback
```

Avoid that for now. That creates cross-owner recursion and could make movement controller a behavior dispatcher.

Better design:

```text
movement controller records status;
behavior owner polls status and advances itself.
```

### Do not break boolean callers

Many current callers expect `tech_priests_request_movement_0418(...)` to return true/false. Keep that behavior.

### Do not remove direct command fallback yet

Direct command fallback remains necessary for space/platform/non-ground exceptions and compatibility wrappers. The Stage 5 movement review did not recommend removing it.

## First concrete repair batch proposal

The first real repair batch should be small and testable:

```text
Batch: Movement contract diagnostics + 0527/0528 request-failure handling
```

Potential contents:

1. Add movement request status helper and diagnostic fields to `movement_controller.lua`.
2. Add `/tp-movement-0429` output for request status, owner, expiry, and arrived/expired/replaced state if not already visible.
3. Patch 0527 so failed request_move does not report moving-to-known-source.
4. Patch 0528 so failed request_move does not report moving-to-machine or moving-to-storage.
5. Do not yet change timeout behavior or output-removal behavior.

Why this is small enough:

```text
It fixes false moving state without changing arrival/progress semantics globally.
It preserves the existing request system.
It gives diagnostics for the next live test.
```

## Second repair batch proposal

After the first batch is tested:

```text
Batch: 0527/0528 stale request cleanup
```

Potential contents:

1. Add timeout to `waiting-known-source-fetch`.
2. Clear matching `active_supply_request` and `logistic_requested_item` when fetch succeeds or when the wait times out.
3. Add owner-aware cleanup so unrelated logistics requests are not accidentally cleared.
4. Record events for timeout, abandoned request, and fetch-satisfied-machine-need.

## Third repair batch proposal

After stale request cleanup is tested:

```text
Batch: 0528 output destination pre-validation
```

Potential contents:

1. Verify retention/waste destination before removing output from machine inventory.
2. If no destination exists, do not remove the item.
3. Add clear diagnostic reason such as no-storage-destination-0528.
4. Preserve existing partial deposit behavior after removal only when destination was validated first.

## Live test scenarios

### Test 1 — Known source exists and movement works

Expected:

```text
0528 enters waiting-known-source-fetch.
0527 fetches item.
0528 sees station count and advances to move-to-machine.
Movement request exists with owner logistics-fetch-0527 or machine-logistics-0528.
Task completes and clears stale fields.
```

### Test 2 — Known source exists but movement request fails/rejects

Expected after repair:

```text
0527/0528 record movement-request-failed.
They do not claim moving-to-known-source/move-to-machine/move-to-storage.
Dispatcher can fall through or retry later.
```

### Test 3 — No known source exists

Expected after later cleanup repair:

```text
waiting-known-source-fetch eventually times out or falls through cleanly.
active_supply_request/logistic_requested_item do not remain forever unless still valid and owner-confirmed.
```

### Test 4 — No storage destination for machine output

Expected after destination-validation repair:

```text
Machine output is not removed unless a valid destination exists.
No logical carried item remains forever without storage.
```

## Current decision

The next step should be planning-to-repair, not more broad audit.

Recommended next action:

```text
Prepare a small source repair batch for movement contract diagnostics + 0527/0528 request-failure handling.
No version bump until the batch is ready for local packaging/testing.
```
