# Stage 2 Refined Classification — 0.1.628 Event Authority Report

This document records the interpretation of the regenerated Stage 2 event-authority scanner after `tools/audit_event_authority.py` was refined to distinguish fallback-shaped direct registrations from true raw direct ownership.

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

The scanner no longer shows the event/tick problem as "128 equally bad raw handlers." It now shows a different, more useful picture:

```text
The codebase has many direct script.* calls,
but nearly all of them appear inside fallback-shaped registration blocks.
```

That changes the repair strategy. The immediate target is not mass deletion or mass migration. The immediate target is making sure the registry/broker discovery path works so fallback branches stay dormant in normal operation.

## Current refined scanner totals

From the regenerated report:

- Total event/timing authority hits: `500`
- Direct `script.*` registration hits: `128`
- Registry route hits: `115`
- Direct fallback-shaped hits: `122`
- True/raw direct review hits: `0`
- Direct GUI-family hits: `23`
- Direct behavior-critical-family hits: `43`

Counts by kind:

| Kind | Count |
|---|---:|
| `registry_global_read` | 191 |
| `direct_script_on_nth_tick` | 91 |
| `registry_on_nth_tick` | 71 |
| `registry_require` | 52 |
| `registry_on_event` | 40 |
| `direct_script_on_event` | 35 |
| `broker_register_service` | 12 |
| `registry_on_configuration_changed` | 2 |
| `registry_on_init` | 2 |
| `tick_broker_require` | 2 |
| `direct_script_on_configuration_changed` | 1 |
| `direct_script_on_init` | 1 |

Counts by refined classification:

| Classification | Count |
|---|---:|
| `registry-global-reference` | 191 |
| `registry-owned` | 115 |
| `registry-first-direct-fallback` | 70 |
| `registry-require` | 52 |
| `require-registry-direct-fallback` | 45 |
| `broker-service-registration` | 12 |
| `broker-registry-direct-fallback` | 7 |
| `canonical-registry-internal` | 6 |
| `tick-broker-require` | 2 |

Counts by risk group:

| Risk group | Count |
|---|---:|
| `behavior-critical` | 167 |
| `legacy-bootstrap` | 88 |
| `economy-housekeeping` | 66 |
| `config-profiler-telemetry` | 59 |
| `gui` | 48 |
| `presentation-diagnostic` | 46 |
| `uncategorized` | 13 |
| `registry` | 6 |
| `startup-lifecycle` | 6 |
| `broker-service` | 1 |

## Corrected interpretation

### Not a raw-handler purge problem

The previous interpretation risked treating direct `script.on_event` and `script.on_nth_tick` appearances as independent rogue registrations. The refined scanner shows most direct calls are embedded in fallback-shaped blocks:

- registry-first direct fallback: `70`
- require-registry direct fallback: `45`
- broker-registry direct fallback: `7`

This means a lot of direct calls may never run in normal operation if the registry or broker is found successfully.

### Still a discovery-hardening problem

The scanner still reports `191` registry-global references. The recovered registry returns `Registry` directly and does not expose a global alias. Therefore the primary remaining risk is not that every module is definitely bypassing the registry; it is that some modules may fail to discover the registry and activate direct fallback branches.

Safer repair pattern:

```lua
local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
if not R then
  local ok, mod = pcall(require, "scripts.core.runtime_event_registry")
  if ok and mod then R = mod end
end
```

This is preferred over reintroducing a bottom-of-file global assignment inside the registry module.

### Behavior-critical timing services must wait

The refined report still shows `43` direct behavior-critical-family hits, but these are fallback-shaped. They include movement, acquisition, dispatcher, lifecycle, recovery, combat, construction, and related timing paths.

These should not be the first code migration target. They need Stage 3 behavior ownership and Stage 4 lifecycle/destruction audit evidence before changing.

### GUI remains the first functional cleanup area

The refined report shows `23` direct GUI-family hits. These are not necessarily raw rogue handlers, but GUI event ownership remains a high-priority area because the original visible issue involves GUI containment/frame instability and because GUI routes can double-dispatch or overwrite each other if the router/recovery layers are not ordered correctly.

The GUI repair path should begin with ownership mapping, not blind event conversion.

## Updated repair order

### Repair A — Discovery hardening, low-risk modules first

Target modules that are not behavior-critical:

- config/profiler telemetry
- diagnostics/reporting
- presentation/visual/audio services
- GUI reporting/readout paths where direct fallback is only for registry absence

Do not start with movement, lifecycle, acquisition, dispatcher, order queue, or recovery timing services.

Goal:

- Make fallback branches less likely to activate in normal operation.
- Preserve direct fallback as last resort.
- Avoid assigning protected globals or patching Factorio globals.

### Repair B — Broker discovery hardening

If `runtime_tick_broker.lua` still only checks `_G.TechPriestsRuntimeEventRegistry` before falling back, it should be updated to require the registry before direct fallback.

This repair is still infrastructure-level, not behavior-family migration.

Required preservation:

- profiler reporting
- adaptive budget behavior
- broker service metadata
- existing fallback as last resort

### Repair C — GUI ownership map

Before event conversion, map GUI ownership:

- `scripts.gui.gui_router`
- `scripts.core.gui_bus`
- `workstate_gui_radar_recovery_0465`
- `station_work_inventory`
- `station_catalog`
- `consecration/history_gui`
- `doctrine_argument`
- `conclave_center_0558`
- `task_auspex_0622`
- Machine-Spirit Ledger owner modules

Goal:

- Determine who should receive `on_gui_opened`, `on_gui_closed`, and `on_gui_click` first.
- Avoid double-dispatching router calls.
- Keep Work State recovery until router order is proven.
- Then fix visual containment/frame issues inside the owning GUI modules.

### Repair D — Behavior-critical timing migration later

Movement, lifecycle, recovery, dispatcher, order queue, acquisition, construction, and combat timing routes should wait for Stage 3/4.

Reason:

These systems can create dead-end states or disappearing-priest behavior if migration changes timing, fallback, or ownership order.

## Immediate next action

Proceed with one of two safe paths:

1. Inspect `runtime_tick_broker.lua` and produce a narrow broker discovery hardening patch if it still uses global-only registry discovery.
2. Start the GUI ownership map for Stage 6 early, because GUI event ownership and visual containment are user-visible and less risky than movement/lifecycle timing routes if handled carefully.

Recommended next move: inspect and patch `runtime_tick_broker.lua` discovery first if it is narrow, then move into GUI ownership mapping.
