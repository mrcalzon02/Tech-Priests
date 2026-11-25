# Tech Priests UPS Validation Runbook 0742

**Status:** measurement protocol; an unexecuted procedure is not performance evidence

**Purpose:** identify runtime cost, prove the scope of a change, and prevent unsupported performance claims

**Applies to:** the owner's reported save, controlled new worlds, and exact source/package comparisons

## Current Incident and Evidence Boundary — 2026-11-25

The immediate reproduction is the reported severe slowdown with one of each of
four priests. Start with an untouched copy of that save and its exact mod list.
A clean world cannot rule out a failure in the populated owner save; a fast
four-priest case cannot establish 25-, 80-, or 100-priest scalability.

Existing registry throttling, idle caches, scan caches and per-service work
budgets are separate controls. Their presence does not prove that every broker
callback, registry route, direct executor call, or native query passes through
them. A per-service item budget is not a cap on the number of callbacks due on a
tick, and a Lua inspection limit is not a native-query result limit. The current
behavior maps must show these boundaries and known bypasses.

Source inspection, Lua fixture results, native load results, callback timings,
whole-engine timings, and owner-save reproduction are distinct evidence states.
Do not describe a source-only repair as "performance ready" or a measured win.
Performance observations remain diagnostics under the owner's release policy;
they do not create an additional release approval gate. This does not authorize
claiming that an unresolved slowdown is fixed.

### Owner-save fixture and runner identity

The supplied `_autosave1.zip` has SHA-256
`12aca8ea806977251dd0683fa56c8ab9a04e992de0ae12914ca544f380e66b6c`.
It predates the four station placements. The diagnostic explicitly reconstructs
one planetary, junior, intermediate and senior station on each disposable copy,
then records and preserves their station/priest identities. These reconstructed
pairs must not be described as entities already present in the supplied save.
The pinned graphics baseline is `tech-priests_1.0.0.zip`, SHA-256
`6870e0b0ad71501d501eb9fc66853d81b12d617e4876b8c9ebd1138a6d464ab6`.

`OLD-CORE30-homebrew` is the Windows/GTX 1660 SUPER runner. Its service context
is Session 0. The attempted interactive-desktop handoff in private Actions run
[45601230986](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45601230986) failed at `Register-ScheduledTask` with `0x80070005` (access denied).
The existing desktop bridge uses the same operation; it is not a second
permission route. The approved alternative is native OpenGL rendering in the
existing session with `--force-opengl --fullscreen=false --disable-audio
--gfx-safe-mode`, retaining the installed engine and normal Steam initialization.
The runner's prior native capture run [43352927548](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43352927548) establishes this capability
for Factorio 2.1.24; it does not establish success for this 2.1.25 owner-save test.
Record the actual session, renderer lines, exact command and native PNG before
claiming a graphical run. Session 0 rendering is not a visible foreground desktop.

### Retained diagnostic observations

| Private Actions run | Actual result | Evidence limit |
|---|---|---|
| [45593930310](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45593930310) | Exact save/mod staging succeeded; graphical launch requested a Steam restart and performed zero updates | No native performance measurement or screenshot |
| [45600647747](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45600647747) | Matched `5934720f` request was cancelled while pending by a subsequent fresh-world request | No job ran; it is not a comparison |
| [45601230986](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45601230986) | Fresh-world staging succeeded; desktop task registration was denied | No visible-desktop performance result |
| [45602737126](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45602737126) | Candidate-only Linux headless diagnostic of `f209086407c2a20aa9d4ac0e68d8fd539dea289c`; 6,000 native updates, 5,400 after warmup, four stable identities, no isolated/runtime errors | Callback instrumentation enabled; baseline and paired-comparison steps skipped |

In [45602737126](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/45602737126), steady-state whole-update mean/p95/p99/max were
3.179/9.728/39.376/340.245 ms. All-mod script-update mean/p99/max were
2.662/38.089/333.707 ms; nine script-update ticks exceeded 100 ms. A sampled
catalog callback took 247.305 ms at elapsed tick 59, **before** the 600-tick
warmup ended. Its first planetary and junior scans took 182.005 and 65.165 ms.
The sampled warm callbacks do not identify the nine later >100 ms script ticks.
Do not attribute those spikes to catalog work merely because nine incomplete
catalog scans were also counted.

That diagnostic's worker hash differs from the earlier `9a67b586` diagnostic,
so their elapsed times are not an accepted matched improvement ratio. Artifact
upload failed because the account's artifact quota was exhausted. The complete
JSON survived in job-log chunks, but its raw per-tick CSV did not. Subsequent
runs must retain bounded exact spike rows in the JSON as well as the full CSV,
and preserve the JSON and actual screenshot chunks in logs. An upload failure
must not silently discard the evidence needed to investigate the remaining lag.

## Objective

The UPS pass answers two questions:

1. Which service or fallback path consumes the most runtime when priests are idle, working, moving, scavenging, repairing, or blocked?
2. Which behavior keeps generating work without completing anything?

This is not a substitute for behavioral validation. Record completed mining,
fetching, repair and consecration work alongside timing, so a loop that merely
stops doing its job cannot be reported as a performance improvement.

## Matched Before/After Procedure

1. Record both full source SHAs, archive hashes, Factorio version, mod list and
   settings, save SHA-256, initial game tick, station/priest counts, scenario,
   runner identity and concurrent runner load. Preserve the original save.
2. Run the baseline and candidate from separate identical copies of the same
   save, with the same warmup and measurement tick counts. Do not compare a
   candidate's later, warmer world against the baseline's initial world.
3. Measure production cost with optional diagnostics off. Run a separate,
   identically configured attribution pass with profiling enabled. Profiling
   creates timers and sampled logs; it has its own cost.
4. Retain native benchmark output and raw per-tick timings. Report mean,
   p50/p95/p99, maximum, sample count and ticks over 16.67 ms and 100 ms when the
   trace provides them. A mean alone cannot characterize the reported jutter.
5. Keep whole-engine update, all-mod `scriptUpdate`, registry dispatch, broker
   pulse and individual callback timings in separate columns. Callback p95s
   cannot be summed into total CPU share. Sparse samples are not every-tick
   coverage, and broker timings are not whole-mod timings.
6. Capture callback invocations/deferrals, scanned candidates and native query
   calls, cache hits/misses/invalidations, queue depth, oldest pending age and
   actual completed actions. A deferred callback must retain its obligation.
7. Exercise the concrete change: repeated item lookups reuse one typed physical
   membership discovery within its 1,800-tick lifetime; build/mine/destroy and
   vehicle/corpse events update known membership immediately; stock and source
   eligibility remain live. A previously unseen vehicle can enter an empty
   cached area without a movement event, so prove that the next requested
   lookup at expiry discovers it. This bounded fallback is required for
   correctness; an event-only fixture does not cover autonomous entry. Verify
   that smoothing planner work preserves the former per-cycle attempt quota,
   cursor fairness, failure accounting and pending deadlines across reload.
   Keep movement, combat, lifecycle and physical custody work responsive.
8. Once the four-priest failure is resolved, repeat the established higher-count
   cases and representative idle/logistics/combat/construction workloads before
   extending the performance claim to those populations. Report any unrun case
   as unmeasured. Use the two-hour retention test only for a memory/save-growth
   claim; do not substitute it for the immediate slowdown reproduction.

Retain raw logs, the exact commands, measurement JSON and behavioral outcomes in
the same evidence bundle. A parser must preserve missing values as unknown and
reject mismatched populations, source revisions or scenarios as a comparison.

## Required Clean-World Procedure

This separate clean-world pass isolates initialization and ordinary behavior.
Use a fresh world for this pass. The owner-save reproduction and migration test
above intentionally use disposable copies of older saves and remain separate.

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

`/tp-runtime-report` supplies control and accounting evidence. Its counters and
unparsed profiler objects do not establish elapsed milliseconds.

- `broker-profiler slow[]` and `registry.profile`: show calls, numeric
  `timed_samples`, and `native_log_samples`. `avg_ms=unavailable` and
  `worst_ms=unavailable` mean no numeric duration was available in Lua. This is
  expected for native `LuaProfiler`; it is not a zero-cost route.
- `[TP-RUNTIME-PROFILE]`: bounded native callback samples, emitted on the first
  profiled invocation and every 32nd thereafter. The engine serializes the
  profiler through a `LocalisedString`; retain the resulting `Duration: ...ms`
  log text and parse it externally. Samples are scoped to broker or registry
  callbacks and stop timing before the sample is logged.
- `[TP-RUNTIME-SERVICE-1068]`, `[TP-RUNTIME-PROFILE-1064]` and
  `[TP-REGISTRY-NTH-PROFILE-1195]`: existing opt-in native CI sample streams for
  individual services, broker pulses and registry dispatches respectively.
- Numeric averages divide by measured samples, never all calls. Old saved
  broker timing aggregates from arbitrary `tostring(LuaProfiler)` parsing are
  discarded on use/report; their call/error history is retained. Old logs
  without a real duration cannot be repaired by treating a pointer or an
  object-version number as elapsed time.
- `broker budget_exhausted`: indicates services are consistently receiving less budget than the backlog wants.
- `service ... budget_exhausted`: identifies which service is being throttled.
- `scan-accounting direct_surface_scans`: should not climb rapidly during steady state.
- `scan-accounting cache_hits` and `estimated_scans_avoided`: should rise after the first warmup scan.
- `scan-routing-0610 direct_scans`: identifies callers still reaching raw surface scans.
- `work-queues repair_direct_scans`: identifies the work-queue fallback's own
  scans. Also inspect `scan-routing-0610` counters: scans delegated to that
  router are accounted there. A zero local counter does not prove zero native
  queries across the call chain.
- `pathing-accounting engine_commands`: should not grow rapidly from target churn while a priest is trying to finish one leaf task.
- `pathing-accounting movement_budget_exhausted`: indicates movement request volume is outpacing the movement service.
- `event-fed-accounting directed_wake`: confirms event-fed wakeups are replacing polling where possible.
- `efficiency-authorities`: confirms dirty scans, dormant gates, indexed cells, and adaptive sleep are installed.

After each runtime source change, refresh and review the current behavior maps:

```powershell
python tools\audit_ups_hotspots_0743.py --write-behavior-maps
# Review changed source against the affected existing curated diagrams first.
python tools\audit_ups_hotspots_0743.py --acknowledge-behavior-map-review
python tools\audit_ups_hotspots_0743.py --check-behavior-maps
```

The generated inventory identifies actual lexical registration calls, scans,
functions and state-writer candidates, and marks dynamic or conditional edges
as unresolved. It is not a live installation census. The older
`UPS_HOTSPOT_AUDIT_0743.md` is a historical snapshot produced by the legacy
matcher, which also counted some guards/definitions/fallbacks. Do not present
either source count as measured CPU cost. Match the candidates to native
registry/broker observations before attributing the slowdown.

For each changed runtime path, update the existing behavior map with its entry,
owner, cadence, budget unit, fairness cursor, cache/expiry/invalidation, native
query limit, terminal/backoff behavior and profiler scope. Record explicit
unknowns. Update `DEVELOPMENT_HISTORY.md` and the current evidence ledger with
the exact validation state; regeneration alone does not resolve the listed risks.

## Initial Hotspot Findings

The following paths are the first UPS suspects to watch during the next clean-world pass.

1. Station catalog fallback: `station_catalog.scan_pair` still falls back to a bounded area scan when the 0579 cell index is dirty or unknown. This is correct for universal discovery but is the main scan cliff if repeated often.
2. Logistics source fallback: `logistics_fetch_executor_0527` uses 0587's retained, item-independent typed source membership with a 1,800-tick demand expiry for unobserved moving sources. Measure live inventory probes separately from cold/domain-change/expiry discovery, immediate membership events and the independent loose-item scan; an item miss no longer forces a catalog scan.
3. Repair discovery: `work_queue_authority.discover_repair_near` now filters by force before damaged-entity checks. If repair direct scans remain high, repair discovery should be converted to event-fed damage submissions first and scan fallback second.
4. Direct acquisition physical guard: `direct_acquisition_physical_guard_0649` now scans only resource/tree/mineable-debris types. If it still appears in profiler output, the next step is to stop scanning when the task already has a valid entity and only retry after a terminal target failure.
5. Movement ownership: `active_leaf_task_truth_0655`, `movement_intent_authority_0654`, and `direct_acquisition_movement_lock_0650` should reduce repeated engine commands. If `engine_commands` keeps climbing without completions, movement ownership is still fighting.

## Signals to Investigate

Use the following signals to judge the measured scenario and select the next
repair. They are not automatic release gates or proof of every workload:

- No runtime errors, stack traces, or repeated install failures.
- Explain the rate and callers of `direct_surface_scans` after warmup; this is a
  cumulative counter, so growth by itself is not a regression threshold.
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
