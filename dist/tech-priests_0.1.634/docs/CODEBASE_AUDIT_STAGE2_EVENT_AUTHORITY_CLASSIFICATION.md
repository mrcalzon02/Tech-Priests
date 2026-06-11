# Stage 2 Event Authority Classification

This document classifies the generated Stage 2 scanner report and turns the raw hit list into an actionable event/tick authority cleanup map.

This is documentation-only. No runtime behavior has been changed, no version has been incremented, and no release package has been prepared.

## Scanner baseline

Generated report:

- `tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.md`
- `tech-priests_src/docs/CODEBASE_AUDIT_STAGE2_EVENT_AUTHORITY_REPORT.json`

Scanner totals:

- Total event/timing authority hits: `494`
- Direct `script.*` registration hits: `127`
- Registry route hits: `114`

Counts by kind:

| Kind | Count |
|---|---:|
| `registry_global_read` | 187 |
| `direct_script_on_nth_tick` | 91 |
| `registry_on_nth_tick` | 71 |
| `registry_require` | 52 |
| `registry_on_event` | 39 |
| `direct_script_on_event` | 34 |
| `broker_register_service` | 12 |
| `registry_on_configuration_changed` | 2 |
| `registry_on_init` | 2 |
| `tick_broker_require` | 2 |
| `direct_script_on_configuration_changed` | 1 |
| `direct_script_on_init` | 1 |

Counts by scanner provisional classification:

| Provisional classification | Count |
|---|---:|
| `registry-global-reference` | 187 |
| `registry-owned` | 114 |
| `direct-registration-review-required` | 113 |
| `registry-require` | 52 |
| `broker-service-registration` | 12 |
| `direct-compatibility-fallback` | 8 |
| `canonical-registry-internal` | 6 |
| `tick-broker-require` | 2 |

## Plain-English interpretation

The report confirms that the codebase is not missing a central event authority. It has one. It also confirms that the central authority is only partially adopted.

The important distinction is that not all `direct_script_on_*` hits are equally bad. Many are fallback branches that only run if the broker or registry cannot be found. However, because the runtime event registry is not exposed as `_G.TechPriestsRuntimeEventRegistry`, global-registry-first modules may miss the registry and activate their direct fallback path even though the registry module exists.

The high-level problem is therefore:

```text
The codebase has a registry, but registry discovery is inconsistent.
Some modules use require("scripts.core.runtime_event_registry").
Some modules only look for _G.TechPriestsRuntimeEventRegistry.
Some modules use the broker first, registry second, direct fallback last.
Some older modules still direct-register event handlers with no registry path.
```

## Classification groups

### Group A — Canonical registry internals

These direct `script.*` calls are expected. They are the central dispatch surface and are not migration targets.

Representative hits:

- `scripts/core/runtime_event_registry.lua` direct `script.on_event(...)` dispatcher install.
- `scripts/core/runtime_event_registry.lua` direct `script.on_nth_tick(...)` dispatcher install.
- `scripts/core/runtime_event_registry.lua` route clear calls.
- `scripts/core/runtime_event_registry.lua` `script.on_init(...)` dispatcher.
- `scripts/core/runtime_event_registry.lua` `script.on_configuration_changed(...)` dispatcher.

Disposition: safe / canonical.

### Group B — Early raw nth-tick monkey-patch firewall

`efficiency_economy_0596.lua` deliberately monkey-patches `script.on_nth_tick` before legacy fragments load. This is not ideal architecture, but it is an intentional compatibility firewall for old direct nth-tick handlers.

Disposition: leave in place until raw direct nth-tick handlers are fully classified and either migrated or proven safe.

### Group C — Broker-first or registry-first fallback patterns

These modules are not immediately rogue. They try to use the broker or registry first, then fall back to direct `script.*` registration only if the modern authority is unavailable.

Representative examples inspected:

- `scripts/core/movement_controller.lua` uses `TechPriestsRuntimeTickBroker0600` first, then `runtime_event_registry`, then direct `script.on_nth_tick` fallback.
- `scripts/core/efficiency_economy_0595.lua` requires `runtime_event_registry` and uses direct `script.on_event` only as an unusual-loader fallback.
- `scripts/core/acquisition_executor.lua` uses `_G.TechPriestsRuntimeEventRegistry` first, then direct `script.on_nth_tick` fallback.

Disposition: mostly safe if registry/broker discovery works. These become risky when the global registry is absent or broker installation falls back to direct routes.

### Group D — Global-registry dependency risk

The report found `187` references to `TechPriestsRuntimeEventRegistry`. The registry file itself returns `Registry` but does not assign `_G.TechPriestsRuntimeEventRegistry`.

This creates a specific failure mode:

```text
Module checks rawget(_G, "TechPriestsRuntimeEventRegistry")
-> gets nil
-> may fall back to direct script.on_event/script.on_nth_tick
-> registry module exists but is bypassed
```

Disposition: high-leverage infrastructure issue.

Likely repair shape:

1. Expose the registry table as `_G.TechPriestsRuntimeEventRegistry` inside `runtime_event_registry.lua`, or through a tiny installer.
2. Update `runtime_tick_broker.lua` to `pcall(require("scripts.core.runtime_event_registry"))` before falling back to direct `script.on_nth_tick`.
3. Keep direct fallback branches for unusual loader states until live testing proves they are unnecessary.

### Group E — GUI direct owners and router conflicts

Several GUI modules still direct-register GUI events.

Representative hits:

- `scripts/core/station_work_inventory.lua` directly registers `on_gui_opened`, `on_gui_closed`, `on_gui_click`, plus boot refresh `on_nth_tick`.
- `scripts/core/workstate_gui_radar_recovery_0465.lua` directly registers `on_gui_opened`, `on_gui_closed`, and `on_gui_click`, then manually calls router first and Work State second.
- `scripts/core/consecration/history_gui.lua` prefers `gui_bus`, falls back to direct GUI events, tries to additionally use `TechPriestsRuntimeEventRegistry`, and directly registers a refresh nth-tick.
- `scripts/core/station_catalog.lua` directly registers GUI events and destroy events.

Important warning:

The GUI router already exists and is designed to dispatch GUI events through the runtime event registry. Migration must not double-dispatch GUI handlers. For example, if `workstate_gui_radar_recovery_0465.lua` is moved into the registry while it still calls `Router.dispatch_*`, and the router itself is also registry-registered, GUI routes may run twice.

Disposition: high-priority but delicate migration area. Do not blindly convert one line at a time.

Likely cleanup shape:

1. Make registry discovery reliable first.
2. Confirm `scripts.gui.gui_router` is installed exactly once.
3. Register Work State, Station Catalog, Consecration History, and Machine-Spirit GUI handlers through `gui_bus` / `gui_router` instead of raw `script.on_event`.
4. Retire the direct Work State GUI recovery event override only after router order is proven correct.

### Group F — Movement, dispatcher, lifecycle, and recovery nth-tick services

The scanner found many direct nth-tick registrations in behavior-critical services:

- acquisition executor / repair / unstick
- movement controller / movement recovery / movement enforcement / movement contracts
- single dispatcher
- order queue / scheduler contracts
- priest lifecycle authority / lifecycle seal / vanish guards / recovery safety
- combat movement authority
- obstruction guard

Some of these may be fallback branches. Some are probably true direct service registrations.

Disposition: behavior-critical. Do not migrate first unless a specific conflict is proven. These need one family at a time, with live test coverage, because they are involved in the disappearing-priest and stalled-priest problem domain.

Likely cleanup shape:

1. Establish registry/broker discovery reliability.
2. Classify each behavior-critical route as broker service, registry route, fallback, or raw service.
3. Move raw recurring services to `runtime_tick_broker` where suitable, not merely to registry nth-ticks.
4. Preserve cadence, priority, and budget semantics.

### Group G — Presentation, audio, visual, and diagnostics nth-tick services

Many direct nth-tick hits belong to lower-risk presentation/reporting systems:

- chatter
- network visuals
- operational sounds
- placeholder audio
- overhead status/text
- status churn damper
- doctrine argument/reporting
- diagnostics behavior authority
- visual lease cleanup

Disposition: good later migration candidates. These are less likely to break priest behavior if migrated carefully, but they are also less urgent than GUI event ownership and registry discovery.

Likely cleanup shape:

- Register as broker services with category `visuals`, `audio`, `gui`, or `diagnostics` where possible.
- Let adaptive route/budget systems throttle them through broker/registry authority.

### Group H — Prototype/runtime setting events and startup provisioning

Direct event hits include runtime setting changes, player creation/join events, and script-trigger effects.

Representative hits:

- `startup_provisioning.lua` direct `on_player_created` / `on_player_joined_game`.
- `network_visuals.lua` and `efficiency_economy_0576.lua` direct `on_runtime_mod_setting_changed`.
- `conclave_center_0558.lua` direct `on_script_trigger_effect`.

Disposition: moderate migration candidates. These are event routes, not high-frequency ticks, but they can still overwrite each other if duplicated.

## Current risk ranking

### Highest leverage infrastructure risk

1. `_G.TechPriestsRuntimeEventRegistry` appears unassigned.
2. `runtime_tick_broker.lua` only checks the global registry and does not require the registry before direct fallback.
3. Many modules depend on that global to avoid direct fallback.

### Highest functional conflict risk

1. GUI event ownership, especially Work State, Station Catalog, Consecration History, Machine-Spirit ledger, and the final Work State recovery owner.
2. Bootstrap consecration visibility handlers, because they directly re-register build/remove/selection events and a watchdog tick.
3. Lifecycle/recovery/vanish guard nth-ticks, because they are behavior-critical and directly related to the disappearing-priest problem domain.

### Lowest-risk later cleanup

1. Audio/presentation/diagnostic ticks.
2. Cache cleanup/prune ticks, once broker service categories are stable.
3. Runtime setting / player join event routes.

## Recommended repair order after Stage 2 classification completes

### Repair 1 — Registry exposure and broker discovery

Small infrastructure repair.

- Expose the registry as `_G.TechPriestsRuntimeEventRegistry` from `runtime_event_registry.lua`.
- Make `runtime_tick_broker.lua` require `runtime_event_registry` before falling back to direct `script.on_nth_tick`.
- Do not remove direct fallback branches yet.

Expected effect:

- Registry-aware modules stop missing the registry global.
- Broker is more likely to register through the registry instead of direct nth-tick.
- Many currently scary direct fallback branches remain dormant.

Test target:

- Load save.
- Run runtime report / event registry summary commands.
- Confirm broker route appears under registry nth-tick routes.
- Confirm no startup crash.

### Repair 2 — GUI router consolidation planning

Documentation/planning plus narrow migration.

- Confirm `gui_bus` delegates to `scripts.gui.gui_router`.
- Confirm `gui_router` registers through `runtime_event_registry`.
- Choose one GUI owner to migrate first, likely `station_work_inventory.lua` or `consecration/history_gui.lua`, but avoid double-dispatch.
- Keep `workstate_gui_radar_recovery_0465.lua` until router order is proven.

Expected effect:

- Start reducing direct GUI event replacement.
- Reduce instability around Work State and Machine-Spirit Ledger windows.

### Repair 3 — Presentation/audio/diagnostic broker migration

Lower-risk recurring services.

- Move noncritical recurring presentation services to broker or registry route.
- Preserve existing intervals.
- Assign categories so adaptive budget logic can throttle them correctly.

Expected effect:

- Fewer raw nth-tick routes.
- Less synchronized background churn.

### Repair 4 — Behavior-critical route migration

Only after Stage 3/4 behavior ownership audit.

- Movement, dispatcher, order queue, lifecycle seal, vanish guard, recovery safety, acquisition executor, and combat movement authority must be migrated one family at a time.
- These should not be casually changed during GUI cleanup.

Expected effect:

- Long-term event/timing authority cleanup without creating new dead-end priest states.

## Immediate next audit tasks

1. Inspect the JSON report for context around direct hits that are likely fallback branches.
2. Produce a narrowed list of true raw direct registrations versus fallback branches.
3. Confirm which direct GUI owners are actually active after final load order.
4. Decide whether Repair 1 is safe enough to implement before Stage 3, because it is infrastructure and may reduce false direct fallback activation without changing behavior ownership.
