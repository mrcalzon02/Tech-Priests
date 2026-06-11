# Stage 5 Checkpoint — Emergency Production Executor 0514

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/emergency_production_executor_0514.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`emergency_production_executor_0514.lua` is a dispatcher-owned production leaf. It is not a free-running emergency craft controller. It exists to keep older emergency facility doctrine and desperation craft logic as helpers while the dispatcher owns the production chain.

The file is structurally healthier than expected. It already separates:

```text
await direct acquisition
collect output from emergency facilities
call facility doctrine as a leaf helper
wait briefly for machine/facility production
fall back to timed station craft
retry station output deposit if station inventory is blocked
complete matching order queue entries
suppress independent legacy emergency craft/facility pulses
```

No immediate behavior repair is recommended from this pass.

## Confirmed healthy structures

### Dispatcher-owned emergency production

The header explicitly says this module is dispatcher-owned and prevents old emergency facility/desperation craft handlers from acting as independent controllers.

Confirmed wrapper behavior:

- `wrap_facility_doctrine()` suppresses independent facility pulses unless the call is from dispatcher/manual/command context.
- `wrap_legacy_desperation_craft()` reroutes legacy emergency craft handling through `M.service_pair(...)` when 0514 owns the production state.
- `wrap_legacy_finish()` similarly blocks legacy finish behavior while 0514 owns the state.

Disposition: healthy ownership consolidation.

### Direct acquisition handoff wait

If the task still has a direct current resource target, `M.service_pair(...)` sets:

```text
phase = "await-direct-acquisition"
return false, "await-direct-acquisition"
```

Disposition: healthy defer to direct acquisition. The executor does not fight direct acquisition while resource gathering is still active.

### Facility output collection has rollback

`collect_from_facilities(...)` removes output from facility inventory and attempts to insert it into station inventory. If station insertion is partial, it reinserts the leftover back into the facility inventory.

Disposition: healthy partial-transfer mitigation.

### Timed station fallback deposit-block retry

When timed fallback craft completes, the module attempts to insert output into station inventory. If insertion is blocked, it resets the craft due tick and waits:

```text
phase = "deposit-output"
reason = "station insert blocked"
return true, "deposit-blocked"
```

Disposition: healthy blocked-output retry loop, not false completion.

### Completion cleanup

On successful fallback craft or facility collection, the module:

- clears the relevant task field;
- completes matching order queue current entry;
- sets dispatcher phase `complete`;
- records diagnostics.

Disposition: healthy completion cleanup.

## Watch item 1 — readiness trusts `gathered_units`

`ready_materials(task)` returns true if:

```text
gathered_units(task) >= needed_units(task)
```

Earlier Stage 5 direct acquisition review found that `direct_acquisition_executor_0513.lua` can increment `task.gathered_units` even when deposit into station inventory failed.

Potential consequence:

```text
0514 can inherit a false readiness signal from 0513.
Emergency production may proceed to station fallback craft because gathered_units says materials are ready even if station inventory never received those materials.
```

This does not appear to originate inside 0514. It is a downstream consequence of the 0513 deposit/gathered_units watch item.

Current disposition:

```text
Carry forward. Do not patch 0514 first. Revisit after direct acquisition deposit semantics are corrected or live-tested.
```

## Watch item 2 — return-to-station movement request failure is soft but visible

`request_move_station(...)` returns `ok` and records:

```text
pair.last_emergency_production_move_0514 = { tick=now(), ok=ok, reason=... }
```

However, `service_timed_station_fallback(...)` calls `request_move_station(...)` while away from station and returns:

```text
true, "returning"
```

without checking whether `ok` was false.

Potential consequence:

```text
The executor can report returning-to-station even if movement request submission failed.
```

This is the same movement-contract pattern found in 0527/0528, but it is lower priority because:

- it records the ok/failure state in `last_emergency_production_move_0514`;
- it refreshes only after `move_refresh_ticks`;
- it is not currently tied to logical carried inventory removed from another machine.

Current disposition:

```text
Watch item. Do not patch until the movement completion contract repair family is resumed.
```

## Watch item 3 — facility wait can fall back after timeout

If a facility role exists and the task has a `facility_started_tick_0514`, 0514 waits up to:

```text
M.facility_wait_ticks = 60 * 8
```

Then it can fall back to timed station craft if materials are ready.

Disposition:

```text
Probably healthy. There is a timeout, unlike 0528 waiting-known-source-fetch.
```

## Watch item 4 — station fallback can loop forever if output is blocked

When station insertion is blocked, 0514 retries by resetting `craft_due_tick_0514` to `now() + 60`.

Potential consequence:

```text
If station inventory never has space, 0514 can remain in deposit-output retry indefinitely.
```

This is likely acceptable because it is an honest blocked-output state and is visible in diagnostics. It is not a false completion.

Current disposition:

```text
Diagnostic watch only.
```

## Relationship to previous Stage 5 findings

### Direct acquisition 0513

0514 depends on `gathered_units` and task readiness fields that can be set by 0513. Therefore, the 0513 deposit-failure false-completion risk is now confirmed as a cross-module concern.

### Movement controller 0418/0429

0514 uses the same movement request model as other modules. It records request ok/failure but still reports returning. This belongs in the broader movement completion contract work, but it is not the highest-risk first patch.

### Machine logistics 0527/0528

0528 remains higher priority because it can remove machine output before ensuring storage destination and because its waiting-known-source-fetch phase lacks an obvious timeout. 0514 has clearer timeout/retry behavior.

## Current Stage 5 decision

No code repair from this pass.

Current priority ranking after this review:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. 0514 emergency production fallback returning/deposit-block diagnostics.
```

## Recommended next manual targets

Continue Stage 5 audit with the other dispatcher leaf executors:

```text
scripts/core/repair_executor_0516.lua
scripts/core/consecration_executor_0515.lua
scripts/core/combat_repair_doctrine_0517.lua
```

Focus:

- movement request semantics;
- claim/release behavior;
- target invalidation;
- completion cleanup;
- whether they inherit false readiness from other modules.

## Useful live diagnostics after packaging

```text
/tp-emergency-production-0514
/tp-task-auspex
/tp-runtime-report
/tp-order-queue-0469
```

Watch for:

- `phase=await-direct-acquisition` that never clears;
- `phase=deposit-output` with repeated station insert blocking;
- `returning-to-station-for-production` while `last_emergency_production_move_0514.ok=false`;
- emergency production completing while station inventory never received direct-acquisition materials.
