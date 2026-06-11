# Stage 2 Rebase Refresh — Event and Timing Authority After 0.1.628 Recovery

This document updates the Stage 2 event/timing authority audit after the recovered 0.1.628 runtime was identified as the current baseline.

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English purpose

The earlier Stage 2 audit was built against an older visible source state. The recovered 0.1.628 runtime adds profiler/config telemetry around the event registry and runtime broker, so the event/timing authority map needs a refresh before any event-route repair continues.

The refreshed question is:

> Who owns event/tick dispatch in recovered 0.1.628, and how do the new profiler/config layers change the risk of event-route migration?

## Corrected baseline

- Current recovered runtime baseline: `tech-priests_0.1.628/`
- Source-forward target: `tech-priests_src/`
- Old 0.1.620 event-authority reports are still useful as historical scanner output, but must be regenerated from the corrected source baseline before being treated as current.

## Major Stage 2 changes discovered in recovered 0.1.628

### 1. Runtime config 0.1.626 now controls profiler/debug state

`runtime_config_0626.lua` loads before the broker in recovered `control.lua`.

It is not a scheduler, task selector, movement owner, cache authority, queue, reservation, or executor. It is a canonical runtime settings snapshot for debug/profiler/log-spam behavior.

Important event/timing implications:

- It reads `tech-priests-debug-mode` and legacy debug aliases.
- It exposes `_G.TechPriestsRuntimeConfig0626` and helper globals.
- It registers `on_runtime_mod_setting_changed` through the runtime event registry if available.
- It falls back to direct `script.on_event` if the registry is unavailable.
- When the debug mode changes, it attempts to update profiler state on the broker and registry.

Disposition: configuration/telemetry route, not behavior authority. Stage 2 must classify its direct fallback as a config fallback, not a work-controller conflict.

### 2. Runtime event registry 0.1.625 now profiles routes

Recovered `runtime_event_registry.lua` is still the canonical event/nth-tick dispatcher, but it now includes 0.1.625 route profiling.

Observed additions:

- `profiler_root_0625()`
- `registry_profiler_enabled_0625()`
- `start_profiler_0625()`
- `record_route_profile_0625(...)`
- `Registry.profiler_report_lines(limit)`
- `Registry.set_profiler_enabled(enabled)`

`call_handler(...)` now starts/stops a profiler around every registered route handler and records route profile data before raising handler errors.

Disposition: canonical event/tick registry plus profiler instrumentation.

Migration requirement:

Every future migration into the registry should preserve useful route metadata:

```lua
{ owner = "module_name", category = "behavior/gui/visual/audio/etc", note = "why this route exists" }
```

Without owner/category/source metadata, the new profiler output becomes much less useful.

### 3. Runtime broker 0.1.626 now profiles broker services

Recovered `runtime_tick_broker.lua` still describes itself as the central budgeted runtime service broker, but its version is now `0.1.626` and it has profiler/debug-output support.

Observed additions/clarifications:

- `r.profiler`
- `M.profiler_enabled()`
- `M.set_profiler_enabled(enabled)`
- `M.start_profiler()`
- `M.record_profile(...)`
- `M.note_debug_output(...)`
- profiler report lines in `/tp-runtime-report`

Disposition: canonical broker/timing budget authority, now with profiler telemetry. Still not a task selector or executor.

Migration requirement:

Recurring service migrations should prefer broker registration when the route is a periodic service rather than a raw event response. That preserves broker profiling, adaptive budget weighting, and `/tp-runtime-report` visibility.

### 4. Global registry discovery remains unresolved in recovered 0.1.628

Recovered `runtime_event_registry.lua` still ends with:

```lua
return Registry
```

It does not include the rejected direct assignment:

```lua
_G.TechPriestsRuntimeEventRegistry = Registry
```

That previous direct patch caused a hard-load failure in testing and must not be reintroduced as-is.

Current interpretation:

- The registry is safe for modules that use `require("scripts.core.runtime_event_registry")`.
- Modules that only read `rawget(_G, "TechPriestsRuntimeEventRegistry")` may still miss it unless some other loader assigns it.
- The correct repair shape should be explicit, narrow, and tested; not a casual global write at the bottom of the registry file.

Recommended future repair shape:

1. Inventory which modules still rely only on the global registry name.
2. Prefer changing those modules to require the registry if absent, using the registry-first fallback pattern already seen elsewhere.
3. If a global alias is still needed, expose it through an explicit `install()` or bootstrap step after confirming Factorio does not treat the assignment as unsafe in that context.
4. Never shadow or reassign protected Factorio globals such as `log`, `script`, `game`, `defines`, `storage`, or `commands`.

### 5. Task Auspex 0.1.622 extends GUI/telemetry, not event authority

`task_auspex_0622.lua` is a late-loaded UI/telemetry module. It reads telemetry from the broker, work queues, reservations, buckets, sleep/dirty/cache authorities, movement controller, and event feeder. It explicitly says it must not own scheduling, tasks, queues, reservations, sleep states, movement, or cache invalidation.

Stage 2 impact: low.

Stage 6 impact: high enough to include in GUI containment and refresh-throttle audit.

## Updated Stage 2 classification adjustments

| Prior classification | 0.1.628 adjustment |
|---|---|
| Runtime event registry as canonical dispatcher | Still true, but now also route profiler. Preserve owner/category/source metadata. |
| Runtime broker as canonical service broker | Still true, but now profiler/debug-output aware. Recurring service migration should preserve broker profiling. |
| Registry global missing | Still unresolved in recovered registry. Do not repeat direct bottom-of-file global assignment. Prefer require-first discovery repair. |
| Direct setting-change events | Reclassify `runtime_config_0626` setting-change route as config/profiler fallback, not behavior conflict. |
| Event scanner report from 0.1.620-era source | Historical only until regenerated from corrected 0.1.628 source. |
| GUI direct owners | Still a major Stage 2/Stage 6 hotspot, now with Task Auspex also joining the GUI audit surface. |

## Updated Stage 2 repair ordering

### Repair 1 — Regenerate current event-authority report from corrected source

Before code changes:

```bash
python tools\update_github_manifest.py
python tools\audit_event_authority.py
```

Then push:

```bash
git add GITHUB_FILE_MANIFEST.md tech-priests_src\docs\CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.*
git commit -m "Refresh audit reports from recovered 0.1.628 source baseline"
git push
```

Reason: the existing scanner report counted the old source state and does not include 0.1.625/0.1.626 profiler/config changes accurately.

### Repair 2 — Registry discovery repair, require-first

Do not repeat the rejected direct global assignment.

Safer candidate:

- Update modules that do `rawget(_G, "TechPriestsRuntimeEventRegistry")` only to attempt `pcall(require, "scripts.core.runtime_event_registry")` before direct fallback.
- Start with non-behavior-critical modules, such as telemetry/config/reporting paths.
- Leave behavior-critical movement/lifecycle/dispatcher routes until Stage 3/4 confirms ownership.

### Repair 3 — Broker install discovery check

If the refreshed scanner/runtime report shows broker still falls back directly, update `runtime_tick_broker.lua` to require the registry before direct `script.on_nth_tick` fallback.

This should preserve profiler behavior and should not change task ownership.

### Repair 4 — GUI event/router consolidation planning

Still needed, but should follow report regeneration and registry discovery repair.

The Work State / Station Work / Consecration History / Machine-Spirit Ledger / Task Auspex GUI surface should be mapped together to avoid double-dispatching GUI events.

## Updated local test commands after refreshed reports

Useful commands remain:

```text
/tp-runtime-report
/tp-gui-router-0427
/tp-task-auspex
```

Expected useful runtime report areas in 0.1.628:

- broker service count
- registry nth-key / handler count
- direct fallback audit remaining count
- broker profiler lines
- registry profiler lines
- runtime-config-0626 line
- compatibility-scan audit lines

## Stage 2 refreshed conclusion

The recovered 0.1.628 runtime makes Stage 2 more diagnostic-friendly but also more metadata-sensitive. The event registry and broker are not merely dispatchers anymore; they are profiler/reporting surfaces. The next event/timing cleanup must preserve metadata and should prefer require-first discovery repairs over broad global aliases or direct output-folder patches.
