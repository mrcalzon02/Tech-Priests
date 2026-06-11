# Current Testing Goals

## 0.1.648 - Immediate ammunition satisfaction

1. Trigger a red pinned/no-ammo signature, then place any compatible magazine into the Cogitator Station.
2. Confirm the warning clears immediately on fast transfer or station GUI close and is replaced briefly by `ammunition received`.
3. Confirm one compatible magazine transfers into the hidden proxy gun and combat resumes without another supply writ.
4. Confirm ammunition already in the proxy prevents the generic survival-ammo request from returning.

## 0.1.647 - Honest Martian bootstrap construction

1. Place a fresh Cogitator Station and confirm no emergency smelter item or entity appears before four stone are acquired.
2. Confirm the central ghost sequence prefers a Martian stone cache and emergency machinery rather than a vanilla furnace or miner.
3. Let the priest acquire the missing recipe ingredients, return to station, craft the requested emergency structure, walk to its ghost, consume the item, and place the real entity.
4. Request iron plates and confirm ore and fuel are serviced into the emergency smelter; no timed station fallback may create plates directly.
5. Confirm the legacy Magos ratio planner does not place vanilla factory ghosts until the central bootstrap plan reaches `ready`.

Regression watch: failed placement must refund the item and restore the planning ghost; no recipe-less building request may enter direct resource acquisition.

## 0.1.646 - Technology-gated, non-conflicting station planning

Primary live-test target: verify that construction and defense planners share station territory without placing locked infrastructure or overlapping another station's control area.

1. With walls, gates, and advanced turrets locked, confirm `/tp-defense-debug` does not request or place those entities.
2. Unlock walls and confirm the ring uses only the outer station band and omits arcs inside another friendly station's control radius.
3. Unlock gates and confirm north, south, east, and west wall gaps become gates where those sites remain station-owned.
4. Unlock the first turret and confirm range-spaced fire slots appear without entering another station's control radius.
5. Trigger bootstrap construction and confirm locked buildings are not ghosted while unlocked production sites remain inside the perimeter reservation.
6. Expand or overlap station radii and confirm obsolete tracked walls in newly shared arcs are recovered rather than duplicated.

Regression watch: defense remains in the existing legacy construction path for this pass. It must not create a second scheduler, queue, reservation, or movement authority.

## 0.1.638 — Fresh-world inventory-insert crash safety

Primary live-test target: verify that a fresh freeplay world no longer hard-crashes around the previous 0.1.637 failure window while the bootstrap resource governor is installed but disabled by default and generic deposits are constrained to chest/container storage.

Suggested smoke test:

1. Start a fresh freeplay world with `tech-priests` 0.1.638.
2. Place/create a single Cogitator Station and allow the Tech-Priest pair to exist.
3. Run `/tp-bootstrap-0637` and confirm `enabled=false` before any manual enablement.
4. Run `/tp-inventory-safety-0638` and confirm the safety guard is installed and enabled.
5. Let the world run past tick 7160, the previous native crash tick from the 0.1.637 failure report.
6. Watch for hard crashes, Lua errors, and `generic-deposit-blocked-0638` entries.
7. Do not run `/tp-bootstrap-0637 on` until the disabled-bootstrap fresh-world pass survives beyond the previous crash window.

Regression watch:

- No generic deposit path should use `furnace_result`, `furnace_source`, `fuel`, `assembling_machine_output`, or any machine result inventory as arbitrary storage.
- Machine-specific logistics may still service machine inputs/outputs through dedicated machine-service executors, but generic reserve/deposit code must stay chest/container-only.
- If deposits block because no safe chest/container space exists, treat that as a safe failure for this patch, not as permission to re-enable machine inventory fallback.

## 0.1.607 — Event-driven repair work feeder smoke test

Primary live-test target: verify that damaged repairable entities enter the shared repair work queue through the event-fed path without creating duplicate repair orders or bypassing reservations/order execution.

Suggested smoke test:

1. Place a Cogitator Station and allow a priest pair to exist.
2. Damage a wall, turret, assembler, or other repairable friendly entity near the station.
3. Run `/tp-runtime-report`.
4. Confirm:
   - `event-fed-accounting repair_submitted` increases.
   - `event-driven-feeder-0607 repair_submitted` increases.
   - repeated damage to the same entity folds duplicates rather than producing many queued orders.
   - repair execution still flows through the shared work queue/reservation/order queue path.

Regression watch:

- No load error from `runtime_tick_broker.lua` report formatting.
- No event flood during combat; `budget_skipped` should rise rather than allowing unbounded same-tick event submissions.
- No repair execution should happen directly from the event feeder.


## 0.1.608 directed wakeup test focus

- Damage a friendly repairable entity near a Cogitator Station and run `/tp-runtime-report`. Confirm `event-fed-accounting directed_wake` increases.
- Confirm repair work still enters the shared repair queue and is not stranded.
- Confirm adaptive sleep does not keep the nearest pair dormant after a damage event.
- Watch for broad repair bucket counts; broad fallback remains intentionally enabled but should be monitored as future cleanup target.


## 0.1.616 live-test focus

- Run `/tp-runtime-report` after damaging machines, placing ghosts, building machines, and dropping items. Confirm event-fed repair/construction/sanctify/pickup counters move without large direct-scan increases.
- Watch movement report route counters. `route_ground` should rise when legacy fallback commands are successfully funneled; `route_direct_fallback` should remain low except for documented space-platform or non-ground exceptions.
- Confirm no new duplicate behavior: event-fed construction/sanctify/pickup jobs should appear as queue backlog only, with execution still governed by existing consumers.


## 0.1.618 test focus

Run `/tp-runtime-report` during a busy repair/construction/pickup moment and confirm adaptive-budget-0618 pressure and boost counters rise only when work pressure exists. Confirm no new direct scheduler/cache/sleep authority appears in the report.

## 0.1.628 live-test focus

Fresh freeplay smoke test:

1. Place a Cogitator Station near the starting crash-site inventory/wreckage that contains firearm magazines. Confirm the pair moves to the source, fetches ammunition, deposits it to the station, and `/tp-logistics-fetch-0527` reports a source rather than `none`.
2. Place multiple stations in overlapping range after ammo is fetched. Confirm emergency reserve balancing can spread at least one magazine where stations are missing critical ammo.
3. Assign/observe stone or rock acquisition. Confirm the pair enters acquisition/working state and mining/scan beam visuals are no longer suppressed by stale consecration labels.
4. Place a furnace or Martian emergency smelter within station range, set a simple solid-fuel/ingredient recipe, and provide nearby coal/wood/ore either in station inventory or local container. Confirm `tp-machine-logistics-0528` reports fuel/ingredient tasks and that supplied fuel/ingredients move through station stock and physical service.
5. Watch `/tp-runtime-report` and Task Auspex for logistics fetch, machine logistics, and action-arbiter counters. Regression watch: no new scheduler/cache/queue authority should appear, and direct raw `set_command` fallback should remain low.
