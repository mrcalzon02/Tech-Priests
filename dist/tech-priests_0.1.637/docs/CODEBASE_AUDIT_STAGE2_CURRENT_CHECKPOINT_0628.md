# Stage 2 Current Checkpoint — Refreshed 0.1.628 Event Authority Index

This checkpoint records the current Stage 2 status after the source tree was refreshed to 0.1.628 and the audit index/scanner report were regenerated.

This is documentation-only. No runtime behavior has been changed by this checkpoint.

## Confirmed source baseline

`tech-priests_src/info.json` now reports:

```json
"version": "0.1.628"
```

The source tree is no longer anchored to the stale 0.1.620 baseline.

## Refreshed scanner report

Current report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md
```

Current scanner totals:

- Total event/timing authority hits: `500`
- Direct `script.*` registration hits: `128`
- Registry route hits: `115`

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

Counts by provisional scanner classification:

| Classification | Count |
|---|---:|
| `registry-global-reference` | 191 |
| `registry-owned` | 115 |
| `direct-registration-review-required` | 114 |
| `registry-require` | 52 |
| `broker-service-registration` | 12 |
| `direct-compatibility-fallback` | 8 |
| `canonical-registry-internal` | 6 |
| `tick-broker-require` | 2 |

## Plain-English interpretation

The source refresh confirms that Stage 2 is still a real event/timing authority cleanup project. The rebase did not remove the mixed event architecture. It slightly expanded the audit surface:

```text
old mixed direct/registry event model
  + runtime config setting-change route
  + event registry profiler instrumentation
  + broker profiler/debug-output tracking
  + Task Auspex telemetry UI
```

The central event registry and runtime broker are still present. Many modules still register directly or retain direct fallback branches.

## Key differences from the old report

Compared with the previous 0.1.620-era report:

- Total hits increased from `494` to `500`.
- Direct registrations increased from `127` to `128`.
- Registry route hits increased from `114` to `115`.
- Registry global reads increased from `187` to `191`.
- Direct event hits increased from `34` to `35`.
- Registry event hits increased from `39` to `40`.

This matches the recovered 0.1.625/0.1.626 additions: runtime config and profiler/reporting paths add a small number of event/global/registry references rather than replacing the old mixed architecture.

## Current direct-registration hotspots

### Behavior-critical timing services

These should not be migrated first without Stage 3/4 ownership confirmation:

- acquisition executor / repair / unstick
- movement controller / movement contracts / movement enforcement / movement recovery
- single dispatcher and scheduler/order paths
- lifecycle authority / lifecycle seal / vanish guards / recovery safety
- combat movement authority
- direct mining safety and obstruction clearing

Risk: these are connected to real behavior, movement, recovery, disappearing-priest prevention, and dead-end state cleanup.

### GUI direct owners

These remain high priority, but must be handled carefully to avoid double-dispatch:

- `station_work_inventory.lua`
- `workstate_gui_radar_recovery_0465.lua`
- `consecration/history_gui.lua`
- `station_catalog.lua`
- Conclave/Task Auspex/Doctrine GUI paths where applicable

Risk: direct GUI event registration can overwrite router dispatch or be overwritten by recovery handlers. This likely relates to GUI instability and containment issues.

### Presentation/audio/diagnostic recurring services

Likely safer later broker-migration candidates:

- chatter
- network visuals
- operational sounds
- placeholder audio
- overhead/status/diagnostic reporters
- visual lease cleanup
- doctrine argument/reporting

Risk: lower behavior risk, but still can create background nth-tick churn.

### Config/profiler/telemetry routes

New 0.1.625/0.1.626 paths should be classified as telemetry/config fallback, not behavior conflict:

- `runtime_config_0626.lua` setting-change route
- registry profiler route tracking
- broker profiler/debug-output reporting
- Task Auspex telemetry reads

Risk: mostly reporting/debug overhead and direct fallback consistency.

## Current registry-discovery conclusion

The recovered 0.1.628 `runtime_event_registry.lua` still returns `Registry` directly and does not include the rejected bottom-of-file global assignment.

The refreshed scanner still finds `191` global registry references. This keeps registry discovery as a real issue, but the repair strategy must avoid the previous unsafe patch.

Safer direction:

```text
Where a module does:
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")

Prefer:
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then
    local ok, mod = pcall(require, "scripts.core.runtime_event_registry")
    if ok then R = mod end
  end
```

This is a require-first discovery repair. It does not assign or monkey-patch Factorio globals, and it does not require the registry module itself to write a global alias.

## Recommended next repair path

### Step 1 — Improve scanner classification before code migration

The scanner is currently conservative. It marks many fallback lines as `direct-registration-review-required` because the direct fallback appears on a different line from the registry/broker check.

Update `tools/audit_event_authority.py` so it better detects:

- broker-first fallback blocks
- registry-first fallback blocks
- direct fallback after `pcall(require, "scripts.core.runtime_event_registry")`
- raw direct installs with no registry/broker branch
- GUI direct owners
- behavior-critical timing services
- config/profiler setting routes

Reason: better classification will prevent us from treating all 128 direct hits as equally dangerous.

### Step 2 — Generate a true raw-direct shortlist

After scanner refinement, regenerate:

```text
CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md
CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json
```

Then produce a shortlist of:

- true raw direct event/tick owners
- fallback-only direct calls
- broker-first services
- registry-first services
- GUI direct owners
- behavior-critical services

### Step 3 — Apply require-first discovery repair to low-risk modules

Start with telemetry/config/reporting paths, not behavior-critical movement/lifecycle routes.

Good first candidates:

- `runtime_config_0626.lua` registry discovery
- report/diagnostic modules that read `TechPriestsRuntimeEventRegistry`
- broker/report helpers that only need registry visibility for reporting or profiler toggles

### Step 4 — Broker discovery hardening

If the refreshed runtime report still shows broker direct fallback behavior, update `runtime_tick_broker.lua` to require the registry before direct fallback.

Preserve:

- broker profiler reporting
- adaptive budget behavior
- service metadata
- direct fallback only as last resort

### Step 5 — GUI router consolidation plan

Do not start by changing behavior-critical timing services. The next major functional cleanup should be GUI router ownership, because the original user-visible issue involves GUI frame/containment instability and GUI direct ownership remains visible in the scanner report.

## Immediate next action

Update the scanner to produce better current classifications before touching runtime code. The next commit should be tooling/documentation only unless a tiny require-first repair is clearly isolated and safe.
