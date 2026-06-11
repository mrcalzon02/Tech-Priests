# Stage 5 Checkpoint — Movement Controller 0418/0429

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/movement_controller.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`movement_controller.lua` confirms the important semantics for callers such as `logistics_fetch_executor_0527.lua` and `logistics_machine_fulfillment_0528.lua`:

```text
tech_priests_request_movement_0418(...) is an intent-submission API.
It does not mean the priest has moved yet.
It means the movement controller accepted, collapsed, or held the request.
Actual engine commands are issued later by the brokered movement service.
```

Therefore:

```text
true  = request accepted / collapsed / held / queued for service
false = request was not accepted and no reliable movement intent exists
```

This strengthens the previous 0527/0528 finding. It is acceptable for those modules to continue waiting after a successful request. It is **not** ideal for them to claim they are moving after a failed request.

## Confirmed movement design doctrine

The file header states the doctrine clearly:

```text
One module owns ground-priest go-to-location commands.
Other systems submit movement intent; they do not command the entity.
Conversations, mining/work, crafting, and post-snap stabilization are clamp bands.
Space-platform hover/pathing is outside this controller.
```

Disposition:

```text
movement_controller.lua is the canonical ground movement command authority.
```

## Request semantics

`M.request(pair, destination, reason, opts)` returns `false` when the request cannot be accepted, including cases such as:

```text
invalid pair/priest/destination
missing pair key
space pair direct_go_to failure when not forced into ground controller
```

It returns `true` when:

```text
an existing matching request was collapsed/refreshed;
a low/equal-priority retarget was held;
a new request was stored in root.requests;
pair.movement_request_0418 was set;
active_request_ids was marked.
```

Important interpretation:

```text
M.request true does not mean the priest has arrived.
M.request true only means movement intent exists.
```

## Service semantics

Movement engine commands are issued later by:

```text
M.service(event, budget)
  -> apply_request(pair, req)
    -> direct_go_to(...) when not clamped and far from target
```

The service loop:

- prunes invalid pair requests;
- prunes expired requests;
- applies valid active requests;
- clears empty request IDs;
- is registered through the runtime tick broker when available;
- falls back to the event registry or direct `script.on_nth_tick` only if needed.

Disposition:

```text
Broker-owned movement service is structurally healthy.
```

## Clamp semantics

`apply_request(...)` checks `clamp_reason(pair)` before issuing a command. Clamp reasons include:

```text
movement stabilization
conversation lock
work clamps such as mining/crafting locks
```

If clamped, it stops the priest and returns false without clearing the request.

Interpretation:

```text
This is intentional. A clamped request can remain present and be serviced later when the clamp clears.
```

This matters because a caller seeing movement not progress immediately should not assume failure if the original request returned true.

## Arrival / loiter semantics

If the priest is inside request radius, `apply_request(...)` sets:

```text
pair.movement_controller_state_0418 = "loitering"
```

and stops the priest. It does not immediately clear the request. The request remains until another owner clears it, it expires, or a later retarget replaces it.

Disposition:

```text
Probably intentional loiter behavior, but useful for diagnostics.
```

Watch item:

```text
A task owner should clear or replace movement requests when it transitions to work/complete state.
```

Direct acquisition already does this in its work clamp. Machine logistics/fetch should be checked against this doctrine when patched.

## Route-command wrapper semantics

`M.route_command(...)` is the compatibility boundary for legacy direct commands:

- ground `go_to_location` commands become `M.request(...)`;
- ground attack commands become combat intent / proxy-owned damage;
- ground stop commands become `M.stop(...)`;
- space/platform/non-ground exceptions fall back to direct engine command.

Disposition:

```text
Direct command fallback inside movement_controller.lua is intentional and canonical.
```

Do not remove it casually.

## Direct answer for 0527/0528 movement failure handling

### 0527 `moving-to-known-source`

`logistics_fetch_executor_0527.lua` currently does:

```text
request_move(pair, src.source, item)
return true, "moving-to-known-source"
```

even if `request_move(...)` returns false.

Based on movement-controller semantics, this is a real possible stale-state issue:

```text
If request_move returns false, no movement intent exists.
The dispatcher should probably not be told that logistics fetch acted/moved.
```

### 0528 `move-to-machine`

`logistics_machine_fulfillment_0528.lua` currently does:

```text
request_move(pair, machine, "machine-service-0528", 1.25)
return true, "moving-to-machine"
```

again ignoring request failure.

Based on movement-controller semantics, this is also a real possible stale-state issue.

### 0528 `move-to-storage`

`deposit_carried(...)` sets move-to-storage state, calls `request_move(...)`, and returns moving-to-storage without checking request success.

This is the highest-risk variant because the task may already hold a logical carried item removed from a machine inventory.

## Current Stage 5 decision

No immediate patch yet, but the repair family is now clearer:

```text
Machine logistics / known-source fetch stale-state cleanup should include movement request failure handling.
```

A safe future repair should likely change 0527/0528 so failed movement request submission does not claim successful movement.

Possible repair shape:

```text
if not request_move(...) then
  record movement-request-failed event;
  either return false so dispatcher falls through,
  or clear/timeout the current machine/fetch phase if it is unrecoverable,
  or set a short cooldown and retry later.
end
```

Do not apply this yet until the exact coordinated 0527/0528 repair batch is planned.

## Current movement-controller disposition

`movement_controller.lua` itself appears structurally coherent from this pass:

- central request storage;
- active request IDs;
- request collapse/retarget hold;
- brokered service;
- expired/invalid pruning;
- clamp handling;
- speed/snap audit;
- route-command compatibility wrapper;
- runtime diagnostics command.

No direct movement-controller repair is recommended from this pass.

## Live diagnostics after packaging

Use:

```text
/tp-movement-0429
/tp-logistics-fetch-0527
/tp-machine-logistics-0528
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- movement request absent while 0527 says `moving-to-known-source`;
- movement request absent while 0528 says `move-to-machine`;
- movement request absent while 0528 says `move-to-storage`;
- request owner/reason mismatches;
- expired requests while executor phase remains travel/wait;
- repeated clamp state preventing movement but task never timing out.

## Recommended next Stage 5 action

Begin a small repair-planning document for the emerging coordinated batch:

```text
0527/0528 logistics stale-state cleanup planning
```

Before coding, that plan should decide:

1. whether movement request failure should clear phase or simply return false;
2. whether waiting-known-source-fetch needs a timeout;
3. whether active_supply_request should be cleared by 0527 on successful fetch;
4. whether 0528 should validate storage destination before removing output;
5. which diagnostics/live tests prove the repair works.
