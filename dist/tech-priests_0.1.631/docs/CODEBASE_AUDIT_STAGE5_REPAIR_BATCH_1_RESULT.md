# Stage 5 Repair Batch 1 Result

This file is written by `tools/apply_stage5_repair_batch1.py` after applying the local source patch.

No version bump is included in this batch.

## Applied changes

- Added M.request_status(pair, owner) and optional second return from M.request.
- Exported _G.tech_priests_movement_status_0418.
- Added request status line to /tp-movement-0429.
- 0527 no longer reports moving-to-known-source after failed movement request.
- 0528 no longer reports moving-to-storage after failed movement request.
- 0528 no longer reports moving-to-machine after failed movement request.

## Explicitly not changed

- No timeout behavior added.
- No machine output destination prevalidation added.
- No direct acquisition gathered_units/deposit behavior changed.
- No generated legacy files changed.
- No version bump applied.

## Required inspection

Run:

```text
git diff -- tech-priests_src/scripts/core/movement_controller.lua
git diff -- tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua
git diff -- tech-priests_src/scripts/core/logistics_machine_fulfillment_0528.lua
```

Then package/test before any version bump.
