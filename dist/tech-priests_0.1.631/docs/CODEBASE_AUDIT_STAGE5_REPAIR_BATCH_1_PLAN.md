# Stage 5 Repair Batch 1 Plan — Movement Diagnostics and Logistics Request Failure Handling

This document defines the first proposed Stage 5 source repair batch.

This is planning-only documentation. No runtime behavior has been changed by this note.

## Plain-English purpose

Stage 5 found many possible dead-end states, but the safest first repair must be small.

Batch 1 should not rewrite movement. It should not change inventory accounting. It should not add broad timeouts. It should only address the first confirmed logistics movement false-state family and add enough movement diagnostics to make local testing useful.

The core bug shape is:

```text
A logistics module submits a movement request.
The movement request can fail.
The logistics module may still report that it is moving.
The task phase can then remain stale even though no reliable movement intent exists.
```

Batch 1 should make that failure visible and prevent the worst false-moving reports in 0527/0528.

## Scope lock

### Included

```text
1. Add movement-controller read-only status/diagnostic helper.
2. Expose that helper through a safe global or diagnostic path.
3. Improve /tp-movement-0429 output with request status if practical.
4. Patch logistics_fetch_executor_0527.lua so failed movement submission does not report moving-to-known-source.
5. Patch logistics_machine_fulfillment_0528.lua so failed movement submission does not report move-to-machine.
6. Patch logistics_machine_fulfillment_0528.lua so failed movement submission does not report move-to-storage.
7. Record diagnostic events for movement-request-failed-0527 and movement-request-failed-0528.
```

### Excluded

```text
1. No global movement rewrite.
2. No movement callbacks into behavior modules.
3. No timeout implementation yet.
4. No output destination prevalidation yet.
5. No gathered_units/deposit accounting change yet.
6. No broad direct-command removal.
7. No generated legacy file edits.
8. No version bump until local packaging/testing is ready.
```

## Files expected to change

```text
scripts/core/movement_controller.lua
scripts/core/logistics_fetch_executor_0527.lua
scripts/core/logistics_machine_fulfillment_0528.lua
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_REPAIR_BATCH_1_RESULT.md
GITHUB_FILE_MANIFEST.md
```

The result document should be created only after the source patch is actually applied and inspected.

## Movement-controller helper design

The movement controller already owns request storage and service state. Batch 1 should add a read-only helper similar to:

```text
M.request_status(pair, owner)
```

Suggested returned fields:

```text
status
active
owner
reason
owner_match
expires_tick
last_command_tick
last_distance_sq
distance_sq
radius
arrived
clamp
state
```

Suggested status values for Batch 1:

```text
invalid-pair
missing-request
replaced-by-other-owner
expired
arrived
clamped
active
```

This helper should not alter movement behavior except possibly caching a diagnostic string on the pair, such as:

```text
pair.movement_controller_status_0418
```

Compatibility rule:

```text
Do not break tech_priests_request_movement_0418 boolean callers.
```

If `M.request(...)` is enhanced to return an optional second value, it must remain safe for old callers:

```text
return true, req
```

Existing Lua callers using only the first return value remain compatible.

## 0527 expected behavior change

Current risky pattern:

```text
request_move(pair, src.source, item)
return true, "moving-to-known-source"
```

Batch 1 target behavior:

```text
local moved = request_move(pair, src.source, item)
if not moved then
  record(pair, "movement-request-failed-0527", ...)
  return false, "movement-request-failed"
end
return true, "moving-to-known-source"
```

Optional short cooldown is acceptable if it prevents same-tick churn, but do not add long timeout policy in Batch 1.

## 0528 expected behavior change — move-to-machine

Current risky pattern:

```text
request_move(pair, machine, "machine-service-0528", 1.25)
return true, "moving-to-machine"
```

Batch 1 target behavior:

```text
local moved = request_move(pair, machine, "machine-service-0528", 1.25)
if not moved then
  record(pair, "movement-request-failed-0528", "machine-service " .. machine_label(machine))
  return false, "movement-request-failed"
end
return true, "moving-to-machine"
```

## 0528 expected behavior change — move-to-storage

Current risky pattern:

```text
request_move(pair, box, deposit_reason, 1.25)
record(pair, "move-to-storage", ...)
return true, "moving-to-storage"
```

Batch 1 target behavior:

```text
local moved = request_move(pair, box, deposit_reason, 1.25)
if not moved then
  record(pair, "movement-request-failed-0528", ...)
  return false, "movement-request-failed"
end
record(pair, "move-to-storage", ...)
return true, "moving-to-storage"
```

Important nuance:

```text
Do not clear task.carried in Batch 1.
Do not alter output removal behavior in Batch 1.
```

That belongs to a later output destination prevalidation batch.

## Local application guidance

Because the previous local patch attempt failed due to Bash heredoc syntax being pasted into PowerShell, Batch 1 should be applied using one of these safer methods:

```text
Option A: edit files manually in an editor and inspect git diff.
Option B: use a checked-in Python patcher with normal file execution.
Option C: use PowerShell here-string syntax only, not Bash heredoc syntax.
```

Avoid this form in PowerShell:

```text
python - <<'PY'
```

Use a real `.py` file or a PowerShell here-string instead.

## Validation before commit

Before committing a Batch 1 source patch, run:

```text
git diff -- scripts/core/movement_controller.lua
git diff -- scripts/core/logistics_fetch_executor_0527.lua
git diff -- scripts/core/logistics_machine_fulfillment_0528.lua
```

Confirm the diff does not include:

```text
version bump
large unrelated formatting changes
generated legacy edits
inventory/output behavior changes
timeout policy changes
```

Then run:

```text
python tools/update_github_manifest.py
```

## Local smoke-test checklist

After packaging, use:

```text
/tp-movement-0429
/tp-logistics-fetch-0527
/tp-machine-logistics-0528
/tp-task-auspex
/tp-runtime-report
```

Watch for:

```text
movement-request-failed-0527 appears instead of stale moving-to-known-source when request submission fails
movement-request-failed-0528 appears instead of stale moving-to-machine when request submission fails
movement-request-failed-0528 appears instead of stale moving-to-storage when request submission fails
movement request status is visible from diagnostics
normal successful movement still reports moving phases and proceeds as before
```

## Failure rollback criteria

If Batch 1 causes priests to stop servicing logistics entirely, revert the 0527/0528 behavior changes first and keep the movement diagnostics if they are harmless.

If movement diagnostics break load or commands, revert the movement-controller helper and keep the 0527/0528 patches only if they load cleanly.

If both sides are unstable, revert the full Batch 1 source patch and return to audit-only documents.

## Commit message suggestion

```text
Apply Stage 5 movement request failure handling batch 1
```

## Versioning rule

Do not bump version when the plan is written.

Do not bump version when source is first edited.

Only bump version after:

```text
Batch 1 source patch is committed or staged for local packaging;
manifest is refreshed;
output package is prepared;
smoke test target is clear.
```

## Next step after this plan

The next audit step is complete when this plan exists.

The next development step, when ready, is to prepare the actual Batch 1 source patch carefully and inspect the diff before any version bump.
