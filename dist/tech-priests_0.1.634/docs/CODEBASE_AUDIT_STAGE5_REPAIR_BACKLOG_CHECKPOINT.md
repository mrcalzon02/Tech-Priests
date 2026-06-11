# Stage 5 Checkpoint — Repair Backlog and Triage

This checkpoint consolidates the Stage 5 dead-end/state audit into a repair backlog.

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

Stage 5 found that the codebase is not simply broken by one missing module or one bad owner.

The modern authority stack is mostly present:

```text
movement_controller.lua is installed through bootstrap_runtime.lua
single_dispatcher_0510 owns modern behavior selection
order_queue_0469 is structurally coherent
work_reservations has expiry cleanup
legacy/generated paths are partly suppressed by 0509/0511/0518/0566 wrappers
ground combat is increasingly proxy/safety-owned rather than raw visible-priest-owned
```

The recurring problem is instead a contract problem:

```text
Movement request submission is an intent contract, not a completion contract.
Many executors still treat movement as fire-and-forget and then maintain their own local moving/walking/returning phase.
```

That means a behavior can become stale when:

```text
movement request submission fails;
movement request expires;
movement is clamped;
movement is replaced by another owner;
movement arrives but the task owner does not advance;
movement is active but no progress is made;
a task waits for another module to satisfy an item/request state that never resolves.
```

Stage 5 also found a separate resource-accounting risk:

```text
direct acquisition can count gathered_units even when station deposit fails,
and emergency production can trust gathered_units as readiness.
```

## Confirmed non-problems or reduced concerns

### Movement controller install is confirmed

The movement controller is installed through:

```text
control.lua
  -> scripts.generated.control_legacy_part_022
    -> scripts.core.bootstrap_runtime.install()
      -> TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
        -> movement_controller.install()
```

Therefore, the problem is not simply that `movement_controller.lua` was never installed.

### 0517 no-broker concern is mostly resolved

`combat_repair_doctrine_0517.lua` does not need its own broker service in normal flow because `single_dispatcher_0510.lua` calls `CombatRepair0517.recommend_action(pair)` before ordinary combat arbitration and then executes 0517 service if selected.

### Direct-command count is not a direct bug count

The direct-command report found many command surfaces, but several are expected:

```text
movement_controller.lua canonical engine command boundary
movement_enforcement_0566 safety stop/home governor
combat_safety.lua blocked-attack stop fallback
platform guarded walking exceptions
generated legacy code that is partially wrapped or suppressed
```

Therefore, a broad direct-command purge is not recommended.

### Order queue is not the first repair target

`order_queue_0469.lua` is noisy because it owns many legitimate transitions. Manual review found coherent current/pending promotion, failure, cancellation, completion, and duplicate-blocking paths.

## Priority 1 — Coordinated 0527/0528 logistics stale-state cleanup

### Files

```text
scripts/core/logistics_fetch_executor_0527.lua
scripts/core/logistics_machine_fulfillment_0528.lua
scripts/core/movement_controller.lua
```

### Why this is priority 1

This is the clearest high-risk stale-state family.

0528 can enter:

```text
waiting-known-source-fetch
move-to-machine
move-to-storage
```

0527 can enter:

```text
moving-to-known-source
```

The audit found:

```text
0528 waiting-known-source-fetch has no visible timeout.
0528 move-to-machine ignores failed movement request submission.
0528 move-to-storage ignores failed movement request submission.
0528 can remove output from a machine before guaranteeing a destination.
0527 clears logistic_requested_item on success but not active_supply_request.
0527 does not directly complete/clear 0528 waiting state.
0527 no-known-source/source-empty/deposit-failed paths do not clear higher-level requesters.
```

### Repair family

This should be a coordinated repair, not a one-file patch.

Recommended staged repair:

```text
Batch 1: movement request failure handling for 0527/0528 only.
Batch 2: waiting-known-source-fetch timeout and owner-aware request cleanup.
Batch 3: output destination prevalidation before removing machine output.
```

### Risk

Medium. These modules are behavior-critical, but the fixes can be staged and locally tested.

### Live diagnostics

```text
/tp-logistics-fetch-0527
/tp-machine-logistics-0528
/tp-movement-0429
/tp-task-auspex
/tp-runtime-report
```

Watch for:

```text
waiting-known-source-fetch that never clears
move-to-machine with no movement_request_0418
move-to-storage with no movement_request_0418
active_supply_request remaining after successful fetch
machine output removed but no storage destination exists
```

## Priority 2 — Direct acquisition deposit/gathered_units correctness

### Files

```text
scripts/core/direct_acquisition_executor_0513.lua
scripts/core/emergency_production_executor_0514.lua
```

### Why this is priority 2

Direct acquisition can increment:

```text
task.gathered_units
```

even if deposit into station inventory failed.

Emergency production later uses readiness logic that can trust gathered units.

Potential consequence:

```text
materials are counted as gathered even though the station never received them;
emergency production proceeds as if prerequisites exist;
craft readiness can become false-positive.
```

### Repair shape

```text
Only increment gathered_units when deposit succeeds.
If deposit fails, retry, delay, or enter a visible deposit-blocked phase instead of counting success.
Record diagnostic event for deposit-failed-direct-acquisition.
Verify 0514 readiness against actual station inventory where possible.
```

### Risk

Medium. This touches emergency production pacing and must be tested.

### Live diagnostics

```text
/tp-emergency-production-0514
/tp-task-auspex
/tp-runtime-report
```

Watch for:

```text
gathered_units increasing without station item count increasing
await-direct-acquisition clearing before real deposit
emergency production completing despite missing station materials
```

## Priority 3 — Movement completion/status contract

### Files

```text
scripts/core/movement_controller.lua
movement-dependent executors broadly
```

### Why this is priority 3

The movement controller is installed and canonical, but its current public request API is an intent-submission contract:

```text
true = request accepted/collapsed/held/queued
false = request rejected/not accepted
```

It does not mean:

```text
arrived
moving successfully
task may proceed
```

Many task owners still need a way to ask:

```text
is my request still active?
did it arrive?
did it expire?
was it replaced?
is the priest clamped?
is there no progress?
```

### Repair shape

Add compatibility-preserving helpers rather than a rewrite:

```text
M.request_status(pair, owner_or_request_id)
M.has_arrived(pair, destination_or_request, radius)
M.describe_request(pair)
```

Do not break callers that expect boolean true/false from `tech_priests_request_movement_0418`.

Do not make movement controller execute behavior callbacks. Task owners should poll movement status and advance themselves.

### Risk

Medium/high if done broadly. Low if added as read-only diagnostics/helpers first.

### Live diagnostics

```text
/tp-movement-0429
/tp-movement-cadence-0518
/tp-movement-bounds-0511
/tp-runtime-report
```

Watch for:

```text
request absent while task says moving
request expired while task phase remains travel/walk/return
movement_controller state loitering while task does not advance
clamp remains active and task never times out
```

## Priority 4 — Movement request failure handling in callers

### Files/families

```text
logistics_fetch_executor_0527.lua
logistics_machine_fulfillment_0528.lua
emergency_production_executor_0514.lua
repair_executor_0516.lua
consecration_executor_0515.lua
construction_planner.lua
older acquisition_executor.lua
```

### Why this is priority 4

Multiple modules submit movement and then report moving/walking/returning without checking the movement request return value.

Observed patterns:

```text
request_move(...)
return true, "moving-to-known-source"

request_move(...)
return true, "moving-to-machine"

request_move(...)
state.phase = "walk-to-target"
return true, "walk-to-target"
```

### Repair shape

After movement status helpers exist, patch callers gradually:

```text
if not request_move(...) then
  record movement-request-failed-XXXX
  return false, "movement-request-failed"
end
```

For phases carrying logical inventory, consider stronger cleanup or cooldown.

### Risk

Low/medium per caller. Must be staged because behavior fallback timing can change.

## Priority 5 — Emergency production diagnostics/refinement

### File

```text
scripts/core/emergency_production_executor_0514.lua
```

### Findings

0514 is structurally healthy. It has:

```text
direct acquisition wait
facility output collection
facility wait timeout
timed station fallback
deposit-block retry
legacy suppression
```

Watch items:

```text
trusts gathered_units from 0513
returning-to-station reports returning even if movement request failed
station fallback can retry forever if station output insertion remains blocked
```

### Repair shape

Mostly diagnostic/refinement unless 0513 false readiness is proven in live test.

## Priority 6 — Repair executor refinement

### File

```text
scripts/core/repair_executor_0516.lua
```

### Findings

Repair is structurally coherent:

```text
urgency-based target selection
shared reservations
repair pack consumption
timed repair ticks
completion cleanup
diagnostics
```

Watch items:

```text
walk-to-target ignores movement request failure
reservations may remain until TTL after supply/movement failure
target-invalid may leave stale diagnostic target fields
order completion is narrow outside current order queue state
```

### Repair shape

After movement contract work:

```text
handle failed movement request;
release reservation on durable need-item / movement-request-failed / target-invalid if owned;
clear stale target diagnostics on invalidation.
```

## Priority 7 — Consecration executor refinement

### File

```text
scripts/core/consecration_executor_0515.lua
```

### Findings

Consecration is structurally clean:

```text
local travel limits
target claims
item cooldown
consume/apply/refund
claim release on most failure paths
completion cleanup
diagnostics
```

Watch items:

```text
walk-to-target ignores movement request failure
target can be claimed before pair cooldown is checked
no standalone broker service, likely intentional
possible stale diagnostic target fields
```

### Repair shape

Low priority:

```text
check movement request result;
check pair cooldown before claiming or release claim on cooldown;
clear stale diagnostic target fields.
```

## Priority 8 — Combat repair doctrine refinement

### File

```text
scripts/core/combat_repair_doctrine_0517.lua
```

### Findings

Combat repair caller flow is mostly healthy:

```text
single_dispatcher_0510 checks 0517 before ordinary combat
0517 is a dispatcher-selected tactical override
ordinary combat fallback is clear through action_state_arbiter_0488
```

Watch items:

```text
direct service_pair calls could bypass recommend_action cover-loss abort
repair-executor-missing or repair-error can leave cluster reservation until TTL
invalid target can leave cluster reservation until TTL if key is not stored
inherits 0516 movement-contract issue
```

### Repair shape

Low priority:

```text
add service_pair active-target eligibility precheck;
release cluster on repair executor failure;
store cluster key for invalid-target release.
```

## Priority 9 — Construction refinement

### Files

```text
scripts/core/construction_planner.lua
scripts/core/construction_site_planner.lua
```

### Findings

Construction ownership is clear:

```text
construction_planner owns task/source/movement/item removal/entity placement
construction_site_planner only owns placement scanning
```

Watch items:

```text
returning-to-station ignores movement request failure
moving-to-build-site ignores movement request failure
movement phases have no explicit timeout
site can become blocked during travel
remove-before-create is mitigated by refund but still sensitive
no obvious construction-site reservation layer
```

### Repair shape

After movement contract work:

```text
check movement request result;
add phase timeout/progress policy;
improve refund diagnostics;
consider construction-site reservation only if duplicate planning appears in testing.
```

## Priority 10 — Legacy/generated direct command reachability

### Files

```text
scripts/generated/control_legacy_part_*.lua
scripts/core/behavior_stack_cleanup_0509.lua
scripts/core/movement_bounds_contract_0511.lua
scripts/core/movement_cadence_contract_0518.lua
scripts/core/movement_enforcement_0566.lua
```

### Findings

Do not mass-edit generated files.

Modern wrapper coverage is meaningful:

```text
0509 decommissions 0502 station-side executor and wraps old direct acquisition paths
0511 bounds direct targets and decommissions old 61-tick direct gather guard
0518 holds movement leases against churn
0566 rejects far/stale movement and returns overleashed priests
```

Some generated direct commands are platform exceptions, not ground movement bugs.

### Repair shape

Only revisit after live diagnostics prove a generated path still owns ordinary ground behavior incorrectly.

## Safe small repair candidates

These are small enough to become first patches later, but should still be staged and tested.

```text
1. Add movement status diagnostic/helper functions without changing request semantics.
2. Add movement request failure handling for 0527 moving-to-known-source.
3. Add movement request failure handling for 0528 move-to-machine and move-to-storage.
4. Add diagnostic event when 0513 deposit fails before gathered_units increment is changed.
5. Add 0517 cluster release on repair-executor-missing/repair-error.
6. Clear stale diagnostic target fields in 0516/0515 invalid-target paths.
```

## Coordinated repair families

These require careful grouped patches and local testing.

```text
1. 0527/0528 stale logistics request cleanup.
2. 0513/0514 acquisition-to-production readiness correctness.
3. Movement completion/status contract rollout.
4. Movement request failure handling across all movement-dependent executors.
5. Construction timeout/site reservation refinement.
```

## Diagnostic-only watch items

Do not patch these until live evidence says they matter.

```text
order_queue activation callback no-direct-callback behavior
work_reservations emergency category reachability
0514 deposit-output indefinite retry if station inventory remains blocked
0517 direct service_pair cover-loss bypass outside dispatcher flow
platform direct commands in generated legacy files
control.lua/bootstrap runtime documentation cleanup
```

## Recommended next action

Stage 5 audit has enough information to pause broad review and prepare a small, testable repair plan.

Recommended next document:

```text
CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_1_PLAN.md
```

Proposed Batch 1 scope:

```text
movement diagnostics/helper only
0527 movement request failure handling
0528 movement request failure handling
no timeout changes
no output-removal behavior changes
no version bump until local package test
```

Reason:

```text
It addresses the most concrete stale movement bug family without rewriting movement or changing inventory accounting yet.
```

## Versioning note

No version bump should occur from audit-only documentation.

Version bump should occur only after:

```text
source repair batch is applied;
manifest is refreshed;
local package is built;
basic smoke test is ready.
```
