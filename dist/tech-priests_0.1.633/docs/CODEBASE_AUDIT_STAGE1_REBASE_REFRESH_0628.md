# Stage 1 Rebase Refresh — Recovered 0.1.628 Runtime Load Graph

This document updates the Stage 1 runtime-load audit after the recovered 0.1.628 output tree was identified as the current baseline. It is a source-forward audit checkpoint: the old Stage 1 notes remain useful for the broad architecture, but any 0.1.620-only assumption must be refreshed against this recovered 0.1.628 load graph.

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English purpose

The earlier Stage 1 audit was created while the visible source tree still looked like 0.1.620. The recovered candidate is now 0.1.628, and the runtime load graph has changed enough that Stage 1 must be refreshed before Stage 2 event/timing work continues.

The corrected Stage 1 question is:

> What does the recovered 0.1.628 runtime actually load, in what order, and what new authority/reporting layers were introduced by the rebase?

## Corrected baseline

- Recovered/current output baseline: `tech-priests_0.1.628/`
- Source-forward target: `tech-priests_src/`
- Old output folder `tech-priests_0.1.620/` is not the current audit baseline.
- Source may still need to be backpatched from the recovered 0.1.628 tree before source-only edits continue.

## High-level Stage 1 conclusion after rebase

The broad architecture is still the same layered compatibility stack:

```text
control.lua
  -> early passive-service austerity hook
  -> generated legacy fragments 001–022
  -> bootstrap_runtime.lua from legacy fragment 022
  -> late recovery / dispatcher / executor / lifecycle / economy / telemetry layers
```

The recovered 0.1.628 tree adds or clarifies several post-0.1.620 layers:

```text
0.1.622 Task Auspex debug/readout UI
0.1.625 runtime event registry profiler integration
0.1.626 canonical runtime config snapshot and profiler/debug master switch
0.1.626 runtime broker profiler/debug integration
0.1.628 recovered package/version baseline
```

These additions are mostly telemetry, configuration, profiler, and debug-UI layers. They do not appear to introduce a new task selector, movement authority, queue authority, reservation authority, or executor authority. However, they do affect Stage 2 because event/tick registry and broker diagnostics now depend on the runtime config/profiler state.

## Updated runtime entry path

### 1. `control.lua` early pre-legacy hook remains

`control.lua` still starts by loading `efficiency_economy_0596` before generated legacy fragments. This early hook wraps raw direct `script.on_nth_tick` registrations so passive services stay dormant until a Tech-Priest runtime entity exists.

Disposition: still part of the Stage 2 timing-authority audit; do not remove casually.

### 2. Generated legacy fragments remain active

`control.lua` still hard-loads `scripts.generated.control_legacy_part_001` through `control_legacy_part_022` in fixed order. The old conclusion remains valid: generated fragments are active behavior, not dead archive.

Disposition: unchanged from the first Stage 1 audit.

### 3. Work State GUI recovery still loads before the broker

`workstate_gui_radar_recovery_0465` still loads early in the post-legacy chain, before the runtime broker. This matters because GUI recovery and router/event-registry bootstrapping can happen before the main broker stack.

Disposition: keep as a Stage 2 GUI event ownership hotspot.

### 4. New 0.1.626 runtime config snapshot now loads before the broker

Recovered `control.lua` loads `scripts.core.runtime_config_0626` after the older 0468 diagnostics layer and before `runtime_tick_broker` / `pair_bucket_registry`.

Purpose of `runtime_config_0626`:

- Centralizes debug/profiler/log-spam settings into one storage snapshot.
- Governs effective debug mode: `off`, `summary`, `verbose`, `profiler`, or `legacy`.
- Exposes globals such as:
  - `_G.TechPriestsRuntimeConfig0626`
  - `_G.tech_priests_runtime_config_refresh_0626`
  - `_G.tech_priests_runtime_debug_enabled_0626`
  - `_G.tech_priests_runtime_setting_bool_0626`
  - `_G.tech_priests_compatibility_scan_0626`
- Refreshes when `tech-priests-debug-mode` or legacy debug aliases change.
- Attempts to update broker and registry profiler state when debug mode changes.

Disposition: configuration/telemetry authority only. It must not be treated as a scheduler, cache, queue, reservation, movement, task, or execution authority.

Stage 2 impact:

- Event/tick audit must account for `runtime_config_0626` registering `on_runtime_mod_setting_changed` through the registry when available, with direct fallback otherwise.
- Runtime profiler state is now configuration-driven.

### 5. Runtime broker is now a 0.1.626 profiler-aware broker

Recovered `runtime_tick_broker.lua` reports `M.version = "0.1.626"` even though its file header still says the broker originated in 0.1.607. It now includes profiler storage and profiler output around brokered services.

Important new or clarified functions/fields:

- `r.profiler`
- `M.profiler_enabled()`
- `M.set_profiler_enabled(enabled)`
- `M.start_profiler()`
- `M.record_profile(...)`
- `M.note_debug_output(...)`
- `M.profiler_report_lines(...)`
- adaptive budget reporting remains present from 0.1.618.

Disposition: still the canonical recurring-service broker, now with profiler/debug telemetry. It remains a timing/budget authority, not a behavior selector.

Stage 2 impact:

- Broker service migration should preserve profiler reporting.
- Runtime report output now includes profiler lines and registry profiler lines when available.

### 6. Runtime event registry now includes 0.1.625 route profiler instrumentation

Recovered `runtime_event_registry.lua` contains profiler support:

- `profiler_root_0625()`
- `registry_profiler_enabled_0625()`
- `start_profiler_0625()`
- `record_route_profile_0625(...)`
- `Registry.profiler_report_lines(limit)`
- `Registry.set_profiler_enabled(enabled)`

The profiler checks `TechPriestsRuntimeConfig0626` when available, then falls back to its own enabled state.

Disposition: canonical event/tick registry plus profiler instrumentation. Do not treat profiler storage as a new event authority.

Stage 2 impact:

- Event registry calls are no longer just dispatch; they also profile route execution when enabled.
- Any event-route migration must preserve owner/category/source metadata so profiler output remains useful.
- The recovered 0.1.628 registry still returns `Registry` directly at end of file and does not include the rejected global-assignment patch.

### 7. Task Auspex 0.1.622 is now part of the late load graph

Recovered `control.lua` loads `scripts.core.task_auspex_0622` at the end of the visible late chain after the 0.1.599 adaptive sleep state layer.

Purpose of `task_auspex_0622`:

- Adds a diegetic Conclave / Command Overview Task Auspex debug/readout tab.
- Adds `/tp-task-auspex` command.
- Reads existing telemetry from runtime broker, work queues, reservations, buckets, sleep/dirty/cache authorities, movement controller, and event feeder.
- Throttles refreshes so the UI does not become a UPS tax.

Disposition: UI/telemetry-only. It must not own scheduling, tasks, queues, reservations, sleep states, movement, or cache invalidation.

Stage 6 impact:

- GUI audit must include the Task Auspex tab and its refresh throttling.
- GUI containment/frame audit should consider Auspex tables/labels because they add wide telemetry display sections.

## Updated Stage 1 classification table additions

| Layer / file family | Load classification | Practical meaning | Current audit disposition |
|---|---|---|---|
| `runtime_config_0626.lua` | Soft-loaded from recovered `control.lua` before the broker | Canonical runtime debug/profiler/log-spam setting snapshot. Exposes configuration globals and controls profiler state. | Configuration/telemetry authority only. Stage 2 must account for its runtime-setting event route. |
| `runtime_event_registry.lua` 0.1.625 profiler additions | Required by registry users | Canonical event/tick registry now records route profiler data when profiler mode is active. | Still canonical event authority. Preserve owner/category/source metadata during migrations. |
| `runtime_tick_broker.lua` 0.1.626 profiler additions | Soft-loaded from recovered `control.lua` after runtime config | Canonical service broker now includes profiler storage, route timing, and debug-output counters. | Still timing/budget authority, not behavior selector. Preserve profiler reporting during service migration. |
| `task_auspex_0622.lua` | Soft-loaded late from recovered `control.lua` | Diegetic debug/readout UI that reads existing telemetry and exposes `/tp-task-auspex`. | UI/telemetry-only. Include in Stage 6 GUI audit and containment work. |
| `info.json` recovered baseline | Factorio metadata | Recovered output reports version 0.1.628. Visible description contains notes through 0.1.624 in the inspected line, so version-description completeness should be checked during versioning repair. | Stage 7/versioning repair item, not runtime authority. |

## Updated Stage 2 implications from the refreshed Stage 1 graph

The Stage 2 event/timing audit should be refreshed with these facts:

1. Runtime config now participates in event/tick telemetry by controlling profiler enablement.
2. Runtime config may register `on_runtime_mod_setting_changed` through the event registry when available, otherwise direct fallback.
3. Event registry includes profiling and should keep rich metadata on every route.
4. Runtime broker includes profiling and debug-output counters.
5. Direct fallback analysis should distinguish direct behavior authority from direct profiler/config fallback.
6. The rejected `_G.TechPriestsRuntimeEventRegistry = Registry` source patch should not be reintroduced as-is; the recovered 0.1.628 registry returns `Registry` directly.

## Updated Stage 6 implications

The GUI audit should add `task_auspex_0622` to the GUI owner list:

- It adds a debug/readout tab and command.
- It reads a large amount of telemetry and may create wide labels/tables.
- It throttles refreshes with `M.min_refresh_ticks = 30`.
- It should be checked during the same containment/frame pass as Work State, Machine-Spirit Ledger, and Conclave GUI.

## Updated versioning implications

The recovered output version is 0.1.628, while the stale source previously inspected still reported 0.1.620. Source must be backpatched before source-only edits continue.

Recommended local recovery command:

```bash
cd "C:\GITS\Tech-Priests"
python tools\backpatch_recovered_output.py --output tech-priests_0.1.628 --all --write-note --apply
```

Then regenerate the manifest and audit scanners from the corrected source baseline:

```bash
python tools\update_github_manifest.py
python tools\audit_event_authority.py
```

## Stage 1 refreshed conclusion

The old Stage 1 conclusion remains structurally correct, but incomplete for 0.1.628. The recovered runtime is still a layered compatibility stack, but it now includes a more explicit telemetry/profiler/config layer:

```text
legacy fragments / bootstrap behavior
  -> dispatcher / executor / lifecycle authorities
    -> runtime broker / work queues / reservations / event feeder
      -> 0625/0626 profiler + runtime config telemetry
        -> 0622 Task Auspex debug UI
```

The next safe step is to regenerate the manifest and event-authority scanner from the recovered source baseline, then continue Stage 2 using the 0.1.628 event/timing graph.
