# Stage 5 Checkpoint — Consecration Executor 0515

This checkpoint records the Stage 5 dead-end/state review of:

```text
scripts/core/consecration_executor_0515.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

`consecration_executor_0515.lua` is a dispatcher-owned visible rite executor. It converts older direct sanctification into a phased priest action:

```text
choose eligible target
  -> claim target
    -> walk to rite range
      -> spend ritual time
        -> consume consecration item
          -> apply source-context sanctity
            -> release claim and complete
```

The module is structurally cleaner than the logistics chain and broadly comparable to repair. It has target travel limits, target claims, item/cooldown handling, apply/refund behavior, legacy wrapping, and diagnostics.

No immediate code repair is recommended from this pass.

## Confirmed healthy structures

### Visible phased rite design

The header explicitly says the old station-rite function may remain only as a legacy helper, while consecration becomes a visible phased priest action: choose target, walk within range, spend ritual time, consume a capsule from the station, and apply sanctity with explicit priest/station source context.

Disposition: coherent dispatcher leaf design.

### Local travel limits

0.1.518 added doctrine that consecration is local machine maintenance, not a reason for priests to crawl halfway across the surface. The module defines tier-specific travel limits and rejects targets too far from the station.

Disposition: healthy anti-overreach guard.

### Target claims exist

The module maintains `target_claims` with owner, station, priest, target, reason, tick, and expiry.

Important functions:

```text
claim_target(...)
release_target_claim(...)
cleanup_claims()
```

Disposition: healthy anti-pileup mechanism.

### Target invalidation releases claims

If a remembered target fails eligibility, the executor releases the target claim before clearing the target and setting `target-invalid`.

Disposition: healthier than repair in this specific path.

### Missing item has retry cooldown

If there is no useful consecration item, the executor sets:

```text
state.no_item_retry_until = now() + M.no_item_retry_ticks
```

and returns false instead of constantly rescanning.

Disposition: healthy anti-churn behavior.

### Consume/apply failure is handled carefully

If item consumption fails, the executor releases the target claim and enters `need-item`.

If sanctity application fails after consumption, it attempts to refund the item into station inventory, releases the target claim, records `apply-failed`, and returns false.

Disposition: healthy rare-item protection.

### Completion cleanup is strong

On successful completion, the executor:

- updates target cooldown;
- sets pair cooldown;
- releases target claim;
- sets phase `complete`;
- clears state target/timing fields;
- sets `pair.mode = "idle"`;
- clears `pair.target`;
- completes matching order queue entry;
- records completion.

Disposition: healthy completion path.

### Diagnostics exist

The module installs:

```text
/tp-consecration-executor-0515
```

and adds pair-dump lines including phase, target, item, blocker, due tick, retry tick, restored amount, and claim counts.

Disposition: useful live diagnostic surface.

## Watch item 1 — `walk-to-target` ignores movement request failure

When target distance exceeds rite reach, the executor does:

```text
request_move(pair, target, "consecration-executor-0515-walk-to-target")
state.phase = "walk-to-target"
pair.mode = "moving-to-consecrate"
return true, "walk-to-target"
```

The return value from `request_move(...)` is ignored.

`request_move(...)` itself has fallback layers:

1. `tech_priests_request_movement_0418`
2. `move_priest_to`
3. `tech_priests_route_ground_command_0429`
4. direct set-command fallback

Therefore failure may be uncommon. But if all movement routes fail, the executor can still claim `walk-to-target` and `moving-to-consecrate`.

Current disposition:

```text
Movement-contract watch item. Do not patch during audit-only continuation.
```

Future repair shape:

```text
If request_move(...) returns false, record movement-request-failed-0515 and return false or enter a retry/cooldown phase instead of claiming walk-to-target.
```

## Watch item 2 — target may be claimed before pair cooldown is checked

The executor selects and claims a target, then later checks:

```text
if tonumber(pair.next_consecration_tick or 0) > now() then
  state.phase = "cooldown"
  pair.mode = "consecrating-cooldown"
  return true, "cooldown"
end
```

Potential consequence:

```text
A pair can claim a target and then enter cooldown, holding that claim until claim expiry or later continuation.
```

This is probably low risk because pair cooldown is short and claim expiry is bounded. But it may temporarily block another priest from using a valid target.

Current disposition:

```text
Low-priority target-claim watch item.
```

Future repair shape:

```text
Check pair cooldown before claiming a newly selected target, or release the claim when entering cooldown.
```

## Watch item 3 — no broker service registration is visible

Unlike `repair_executor_0516.lua`, the consecration executor install path does not appear to register a runtime broker service. It wraps legacy sanctify, wraps scheduler try-consecration, installs diagnostics, and exposes `_G.TechPriestsConsecrationExecutor0515`, but there is no visible `register_service(...)` call in this file.

Potential consequence:

```text
If a pair enters consecration_0515 phase, continuation may depend on scheduler/manual/legacy entry points rather than a dedicated brokered consecration pulse.
```

This may be intentional because consecration should be lower-frequency opportunistic maintenance. But it is different from repair and worth checking against dispatcher/scheduler flow.

Current disposition:

```text
Stage 5 flow ownership watch item. Not a repair yet.
```

Recommended follow-up:

```text
Verify whether single_dispatcher_0510 or task scheduler repeatedly calls service_pair for active consecration tasks.
```

## Watch item 4 — stale diagnostic target after target-claimed/no-target paths

The module usually clears/replaces target state correctly, especially on completion and apply failure. However, diagnostic fields such as `state.target_name` and `state.target_unit` may remain visible if a claim is blocked or if the selected target changes after a previous state.

Current disposition:

```text
Diagnostic stale-state watch only.
```

## Comparison to previous Stage 5 findings

Compared with machine logistics 0528:

```text
consecration is much safer.
It does not remove machine output before finding storage.
It does not hold logical carried items.
It has bounded item retry cooldown.
It releases claims on most failure/completion paths.
```

Compared with repair 0516:

```text
consecration has better claim release around invalid/no-item/apply-failed paths,
but it may not have an obvious broker service registration.
```

Its main shared weakness remains:

```text
movement requested does not equal movement completed;
movement request failure is not checked by the task owner.
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
6. 0515 consecration movement failure/cooldown-claim refinement.
```

## Recommended live diagnostics after packaging

Use:

```text
/tp-consecration-executor-0515
/tp-runtime-report
/tp-task-auspex
/tp-order-queue-0469
```

Watch for:

- `phase=walk-to-target` while `movement_request_0418` is nil;
- repeated `walk` records without distance shrinking;
- `phase=cooldown` while target claim count remains elevated;
- active consecration phases that do not receive repeated service;
- `target-claimed` with stale target name/unit still visible.

## Recommended next manual target

Continue with:

```text
scripts/core/combat_repair_doctrine_0517.lua
```

Focus:

- combat repair movement request semantics;
- cluster reservation cleanup;
- interaction with ordinary combat ownership;
- target invalidation;
- completion or abandonment cleanup.
