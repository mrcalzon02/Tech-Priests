# Stage 5 Checkpoint — Logistics Fetch Executor 0527

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/logistics_fetch_executor_0527.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`logistics_fetch_executor_0527.lua` is a dispatcher-priority known-source fetch executor. It physically moves the priest to known storage, loose ground items, machine inventories, vehicles, corpses, or nearby containers before raw acquisition/emergency crafting is considered.

It is useful and intentional, but it confirms several machine-logistics stale-state concerns from the previous checkpoint.

The strongest finding is:

```text
Successful fetch clears pair.logistic_requested_item,
but does not clear pair.active_supply_request,
and does not directly clear pair.machine_logistics_0528 waiting state.
```

Machine logistics can later observe station stock and advance itself from `waiting-known-source-fetch` to `move-to-machine`, so this may work in practice. But state ownership is split across 0527 and 0528, and stale request fields can remain.

No behavior repair is recommended yet. Any repair here should be coordinated across 0527/0528.

## Confirmed healthy structures

### Dispatcher-priority wrapper

Like machine logistics, logistics fetch wraps `single_dispatcher_0510.service_pair` and acts before the previous dispatcher service when a known source can satisfy an active item request.

Disposition: intentional dispatcher-priority logistics leaf.

### Active request discovery is broad

`active_request(pair)` can source item intent from:

```text
order_queue_0469.current
pair.active_order_0469
pair.active_supply_request
pair.logistic_requested_item
pair.scavenge
pair.inventory_scan
pair.mode ammo/repair hints
emergency operation fields
```

Disposition: useful compatibility surface, but broad enough that stale fields can keep logistics fetch interested in old needs.

### Source discovery has fallback layers

Known-source lookup tries:

```text
station catalog known storage
nearby storage/entity fallback
loose ground item fallback
```

Disposition: healthy practical fallback design.

### Deposit failure attempts rollback

If the executor removes items from a source but cannot deposit all of them into station inventory:

- for inventory sources, it attempts to reinsert leftovers into the source inventory;
- for loose ground sources, it spills leftovers near the priest.

Disposition: healthy mitigation, but not a full success path.

## Watch item 1 — movement request failure is ignored

When the source is out of pickup range, `service_pair(...)` does:

```text
request_move(pair, src.source, item)
return true, "moving-to-known-source"
```

`request_move(...)` returns `false` if movement request fails, but `service_pair(...)` ignores that result and still reports that it acted.

Potential consequence:

```text
Dispatcher thinks logistics fetch is active, but the priest may not move.
The pair can keep reporting moving-to-known-source without actual progress.
```

Current disposition:

```text
Real Stage 5 watch item. Do not patch before movement_controller.lua review.
```

## Watch item 2 — successful fetch clears `logistic_requested_item` but not `active_supply_request`

On successful insert, the executor clears:

```text
pair.scavenge = nil
pair.inventory_scan = nil
pair.logistic_requested_item = nil
```

It does **not** clear:

```text
pair.active_supply_request
```

Potential consequence:

```text
A machine-logistics request can remain as active_supply_request after a successful fetch.
If station_count is already enough, fetch returns already-in-station and falls through, so this may not cause repeated fetching.
But it can leave stale diagnostic/request state attached to the pair.
```

Current disposition:

```text
Likely stale-state risk, not immediately proven behavior bug.
```

Recommended future repair shape:

```text
When inserted > 0 and req.source == "active_supply_request" or req.source == "logistic_requested_item", clear only the request object that still matches the fetched item and source owner.
For machine-logistics, coordinate with 0528 so the waiting phase advances or times out cleanly.
```

## Watch item 3 — `waiting-known-source-fetch` is not directly completed by fetch

`0527` does not directly update:

```text
pair.machine_logistics_0528.phase
```

Instead, `0528` later checks:

```text
station_count(pair, task.item) >= task.count
```

and then advances the machine task to `move-to-machine`.

Potential consequence:

```text
If 0528 does not get serviced after fetch, the pair can still show waiting-known-source-fetch until the next machine-logistics pass.
If fetch partially succeeds but station count remains below requested count, the waiting phase remains.
```

Current disposition:

```text
Probably intentional loose coupling, but timeout/retry diagnostics are needed.
```

## Watch item 4 — no-known-source does not clear the requester

If there is no known source, `service_pair(...)` returns:

```text
false, "no-known-fetch-source"
```

It does not clear `active_supply_request`, `logistic_requested_item`, or `machine_logistics_0528`.

Potential consequence:

```text
Machine logistics can keep waiting for known-source fetch even when there is no known source.
Dispatcher falls through to raw acquisition/emergency crafting, which may eventually solve the need, but the stale waiting state remains until station stock appears or machine task is invalidated.
```

Current disposition:

```text
Carry forward to coordinated 0527/0528 repair planning.
```

## Watch item 5 — source-empty/source-invalid failures use cooldown but do not clear requester

When an identified source is empty or invalid, the executor sets a cooldown for that source/item key and returns failure. It does not clear the higher-level requester fields.

This is probably correct because another source may exist or raw acquisition may solve the need, but it means stale requests depend on later passes to resolve.

Current disposition:

```text
Expected compatibility behavior, but should be visible in diagnostics.
```

## Watch item 6 — deposit-failed does not clear requester

If deposit fails entirely after successful removal/rollback attempt, `service_pair(...)` returns:

```text
false, "deposit-failed"
```

Requester fields remain.

Potential consequence:

```text
The pair can keep needing the item, but station inventory may remain blocked.
The executor may retry after cooldown/source availability, or fall through to other behavior.
```

Current disposition:

```text
Watch item. Likely belongs with direct acquisition deposit-failure review and station inventory safe-deposit review.
```

## Relationship to machine logistics 0528

The previous checkpoint found:

```text
0528 waiting-known-source-fetch has no visible timeout.
0528 movement states ignore request_move failure.
0528 does not verify destination before removing machine output.
0528 sets active_supply_request/logistic_requested_item for 0527.
```

This checkpoint adds:

```text
0527 clears logistic_requested_item on success but not active_supply_request.
0527 does not explicitly complete or clear 0528 waiting state.
0527 does not clear requesters when no source exists, source fails, or deposit fails.
```

Combined interpretation:

```text
0527 and 0528 form a loose two-module state machine.
It probably works when station stock arrives quickly.
It is vulnerable to stale waiting/request fields when fetch cannot complete cleanly.
```

## Current Stage 5 decision

No code repair yet, but the first serious candidate repair family is emerging:

```text
Machine logistics / known-source fetch stale-state cleanup.
```

Do not patch one side blindly. A safe repair should probably be a small coordinated batch that:

1. Adds owner-aware timeout or failure cleanup to `waiting-known-source-fetch` in 0528.
2. Clears matching `active_supply_request` and `logistic_requested_item` when 0527 succeeds or when 0528 abandons the request.
3. Checks movement request return values in 0527 and 0528 movement phases.
4. Avoids removing machine output unless a valid destination exists or a recovery destination is guaranteed.

## Recommended next manual target

Review:

```text
scripts/core/movement_controller.lua
```

Reason:

Both 0527 and 0528 ignore failed movement requests. Before patching those paths, we need to know whether `tech_priests_request_movement_0418` usually fails only when movement is unavailable/invalid, or whether direct fallback is expected elsewhere.

Focus:

- request/lease ownership;
- stale lease cleanup;
- movement request success/failure semantics;
- whether callers should treat `false` as hard failure or soft defer;
- direct command fallback boundary.

## Live diagnostics after packaging

Use:

```text
/tp-logistics-fetch-0527
/tp-machine-logistics-0528
/tp-order-queue-0469
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- `logistics-fetch` item remains set after successful fetch.
- `active_supply_request` remains after station inventory has enough stock.
- `machine-logistics task_phase=waiting-known-source-fetch` persists indefinitely.
- repeated `no-known-fetch-source` while raw acquisition later succeeds.
- repeated `deposit-failed` while requester remains active.
- moving-to-known-source without actual movement progress.
