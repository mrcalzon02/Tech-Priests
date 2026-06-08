# Current Testing Goals

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
