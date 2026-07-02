# Tech Priests UPS Validation Runbook 0742

**Status:** pre-packaging governance aid  
**Purpose:** measure runtime pressure before a release package is promoted  
**Applies to:** clean new-world manual validation saves and local release candidates

## Objective

The UPS pass answers two questions:

1. Which service or fallback path consumes the most runtime when priests are idle, working, moving, scavenging, repairing, or blocked?
2. Which behavior keeps generating work without completing anything?

This is not a substitute for behavioral validation. A fast loop that silently fails to mine, fetch, repair, or consecrate is still a release blocker.

## Required Clean-World Procedure

Use a fresh Factorio save for each runtime validation pass. Do not load an older test save to prove behavior acceptance.

1. Install the exact candidate archive name and root derived from `info.json`.
2. Set `tech-priests-debug-mode` to `profiler`.
3. Start a new world.
4. Let the save run for 60 seconds with no placed Tech Priest station.
5. Run `/tp-runtime-report` and keep the Factorio log output.
6. Place one new station and wait until the station/priest pair is initialized.
7. Let it run for 120 seconds with no manual interference.
8. Run `/tp-runtime-report` again.
9. Place or expose the intended stimulus:
   - crash-site containers containing ammunition for logistics fetch,
   - nearby ore/stone/tree targets for direct acquisition,
   - damaged same-force entities for repair,
   - missing consecration supplies for terminal/backoff behavior.
10. Let the save run for 300 seconds.
11. Run `/tp-runtime-report` a final time and capture `factorio-current.log` plus script-output diagnostics.

## Report Lines To Inspect

`/tp-runtime-report` is the main UPS acceptance artifact.

- `profiler-0625 slow[]`: identifies broker or registry routes with the highest worst observed profiler time.
- `broker budget_exhausted`: indicates services are consistently receiving less budget than the backlog wants.
- `service ... budget_exhausted`: identifies which service is being throttled.
- `scan-accounting direct_surface_scans`: should not climb rapidly during steady state.
- `scan-accounting cache_hits` and `estimated_scans_avoided`: should rise after the first warmup scan.
- `scan-routing-0610 direct_scans`: identifies callers still reaching raw surface scans.
- `work-queues repair_direct_scans`: identifies repair discovery falling through cache/indexing.
- `pathing-accounting engine_commands`: should not grow rapidly from target churn while a priest is trying to finish one leaf task.
- `pathing-accounting movement_budget_exhausted`: indicates movement request volume is outpacing the movement service.
- `event-fed-accounting directed_wake`: confirms event-fed wakeups are replacing polling where possible.
- `efficiency-authorities`: confirms dirty scans, dormant gates, indexed cells, and adaptive sleep are installed.

Before packaging, refresh the static source catalog with:

```powershell
python tools\audit_ups_hotspots_0743.py --root tech-priests_src --markdown docs\UPS_HOTSPOT_AUDIT_0743.md --json build\ups-hotspot-audit-0743.json --print-summary
```

The static catalog does not prove runtime cost. It identifies authorities that wake often, scan broadly, or rewrite movement/task state so the clean-world profiler pass can focus on the right suspects.

## Initial Hotspot Findings

The following paths are the first UPS suspects to watch during the next clean-world pass.

1. Station catalog fallback: `station_catalog.scan_pair` still falls back to a bounded area scan when the 0579 cell index is dirty or unknown. This is correct for universal discovery but is the main scan cliff if repeated often.
2. Logistics source fallback: `logistics_fetch_executor_0527` now uses typed inventory-source scans before probing broad inventory ids. If this still appears hot, the next step is per-item negative source cooldown by station and source prototype.
3. Repair discovery: `work_queue_authority.discover_repair_near` now filters by force before damaged-entity checks. If repair direct scans remain high, repair discovery should be converted to event-fed damage submissions first and scan fallback second.
4. Direct acquisition physical guard: `direct_acquisition_physical_guard_0649` now scans only resource/tree/mineable-debris types. If it still appears in profiler output, the next step is to stop scanning when the task already has a valid entity and only retry after a terminal target failure.
5. Movement ownership: `active_leaf_task_truth_0655`, `movement_intent_authority_0654`, and `direct_acquisition_movement_lock_0650` should reduce repeated engine commands. If `engine_commands` keeps climbing without completions, movement ownership is still fighting.

## Acceptance Signals

A candidate is UPS-acceptable for the next package only when the report and behavior agree:

- No runtime errors, stack traces, or repeated install failures.
- No rapidly growing `direct_surface_scans` after warmup.
- Cache hits and negative skips appear after repeated empty scans.
- No single service is repeatedly budget-exhausted during idle or one-station operation.
- Movement engine commands grow in proportion to real retargets, not rapid command churn.
- Logistics fetch removes items from a real source and deposits them at the station.
- Direct acquisition produces real inventory results or enters a terminal/backoff state.
- Missing consecration supplies produce one durable request/backoff state rather than repeated priority churn.

## Escalation Order

Use this order when the report points to real UPS pressure:

1. Stop unbounded or untyped surface scans in the hot path.
2. Add negative cooldowns for repeated "nothing found" scans.
3. Move discovery to events when Factorio provides a reliable event.
4. Bucket pairs by active family so idle pairs do not join hot service loops.
5. Increase intervals only after correctness is stable and the service has terminal/backoff states.
6. Reduce visual refresh cadence for non-selected or offscreen priests before reducing visible watched behavior.
