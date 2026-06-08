# Stage 2 Event and Timing Authority Audit

This document records the Stage 2 event/timing authority audit for the current `tech-priests_src` source tree.

This is documentation-only. No runtime behavior has been changed, no version has been incremented, and no release package has been prepared.

## Plain-English purpose

Factorio event registration is not additive by default. A given `script.on_event(...)` route or `script.on_nth_tick(...)` cadence has one active registered handler. If separate modules register the same event/cadence directly, the later registration can replace the earlier one. That is why this codebase introduced a runtime event registry and a runtime tick broker: they create one registered outer handler, then call internal module handlers in a controlled order.

The Stage 2 audit asks a simple question:

> Who still touches Factorio's event/tick system directly, and who uses the modern registry/broker route?

## Canonical authorities inspected

### `scripts/core/runtime_event_registry.lua`

Classification: canonical event and nth-tick dispatcher.

The registry describes itself as the single runtime surface that should touch `script.on_event`, `script.on_nth_tick`, and `script.on_init` during the cleanup series. It explicitly exists because earlier append-only patch layers could silently replace each other.

Important behavior observed:

- Provides `Registry.on_event(...)`.
- Provides `Registry.on_nth_tick(...)`.
- Provides `Registry.on_init(...)`.
- Provides `Registry.on_configuration_changed(...)`.
- Keeps ordered handler lists for each event/cadence.
- Installs one real Factorio dispatcher for each event/cadence.
- Supports priority/front insertion.
- Supports `stop_on_truthy` handler behavior.
- Provides summary/count helpers for diagnostics.

Current disposition: intended canonical authority. Use as the target pattern for event migration.

Open concern: several modules look for `_G.TechPriestsRuntimeEventRegistry`, but the registry file inspected so far returns `Registry` and does not visibly assign itself to `_G.TechPriestsRuntimeEventRegistry`. This needs verification before assuming all global-lookup users are registry-routed.

### `scripts/core/runtime_tick_broker.lua`

Classification: canonical service broker, but registry access may fall back.

The broker is the central budgeted runtime service broker. Its comments say it replaces many independent broad nth-tick loops with one auditable service broker. Services register with interval, priority, category, and soft budget. The broker pulses from one registry route and decides which services are due.

Important behavior observed:

- `M.register_service(spec)` replaces services by name, making service registration idempotent.
- `M.pulse(event)` runs due services and tracks service statistics.
- `M.install()` looks for `_G.TechPriestsRuntimeEventRegistry`.
- If the global registry exists, it registers its base pulse through `R.on_nth_tick(...)`.
- If the global registry does not exist, it falls back to direct `script.on_nth_tick(...)`.
- It exposes `_G.TechPriestsRuntimeTickBroker0600` and `_G.tech_priests_runtime_metric_0606`.

Current disposition: good architecture, but the global registry lookup is fragile. If `_G.TechPriestsRuntimeEventRegistry` is never assigned before broker install, the broker may silently become a direct nth-tick owner instead of a registry-owned service route.

### `scripts/core/efficiency_economy_0596.lua`

Classification: early raw nth-tick monkey-patch safety net.

This module is intentionally loaded before generated legacy fragments. It monkey-patches `script.on_nth_tick` so raw legacy nth-tick handlers are wrapped with a dormant-runtime gate. This is not the same as modern registry ownership. It is a compatibility firewall for old direct nth-tick users.

Important behavior observed:

- Stores the original `script.on_nth_tick` in `_G.tech_priests_original_on_nth_tick_0596`.
- Replaces `script.on_nth_tick` with a wrapper.
- When a handler is registered, the wrapper wraps that handler with `runtime_active_for_tick(...)`.
- If no Tech-Priest runtime entities exist yet, the wrapped handler is skipped.
- If the 0.1.595 dormant gate exists, it delegates wake/sleep decision to `_G.tech_priests_should_run_nth_tick_0595`.

Current disposition: intentional compatibility firewall. Keep until all raw direct nth-tick paths are inventoried and either migrated or proven safe. It is important but fragile because it monkey-patches the Factorio registration function itself.

## Modern registry-owned event feeder inspected

### `scripts/core/event_driven_work_feeder_0608.lua`

Classification: registry-owned event feeder.

This module is a good example of the modern pattern. It converts high-signal world events into work-queue submissions and telemetry counters. It does not execute priest work directly.

Important behavior observed:

- The comments state the boundary clearly:
  - Work Queue finds/records jobs.
  - Reservation claims jobs.
  - Order Queue executes jobs.
- On install, it assigns `_G.TechPriestsEventDrivenWorkFeeder0608 = M`.
- It tries to obtain the runtime event registry through `_G.TechPriestsRuntimeEventRegistry` or `require("scripts.core.runtime_event_registry")`.
- It registers `on_entity_damaged` through `R.on_event(...)`.
- It registers build/remove/destroy dirty events through `R.on_event(...)`.
- It registers dropped-item pickup through `R.on_event(...)`.
- It submits repair/construction/sanctify/pickup candidates to `work_queue_authority` rather than executing work itself.
- It wakes nearby pairs by using pair buckets and adaptive sleep wake hooks.

Current disposition: good modern pattern. Use this as the model when migrating older direct event registrations.

## Direct-registration exceptions confirmed so far

### `scripts/core/workstate_gui_radar_recovery_0465.lua`

Classification: mixed event ownership.

This module directly registers GUI events while using the runtime registry for a boot-display nth-tick service when available.

Why it exists:

The comments explain that Work State / BIOS boot could disappear when late raw GUI handlers replaced the GUI router dispatcher. This module deliberately loads late and becomes a small final GUI owner. It calls the router first, then explicitly calls Work State handlers.

Direct routes observed:

- `script.on_event(defines.events.on_gui_opened, ...)`
- `script.on_event(defines.events.on_gui_closed, ...)`
- `script.on_event(defines.events.on_gui_click, ...)`

Registry route observed:

- `R.on_nth_tick(30, service_workstate_only, ...)` when the registry is available.
- Direct `script.on_nth_tick(30, service_workstate_only)` fallback when the registry is unavailable.

Current disposition: Stage 2 migration target, but do not remove blindly. Any migration must preserve exact ordering: router first, Work State second. The historical reason for this file was previous GUI event ownership conflict.

### `scripts/core/bootstrap_runtime.lua` 0.1.348 / 0.1.351 blocks

Classification: direct selected-entity/capsule event owner.

Direct/global behavior observed:

- Wraps `_G.on_selected_entity_changed`.
- Directly registers `script.on_event(defines.events.on_selected_entity_changed, _G.on_selected_entity_changed)`.
- Directly registers `script.on_event(defines.events.on_player_used_capsule, on_used_capsule)`.

Current disposition: direct event override risk. Candidate for registry migration after handler order is documented. The selected-entity path should be migrated carefully because it intentionally wraps older global selection behavior.

### `scripts/core/bootstrap_runtime.lua` 0.1.409 consecration visibility watchdog block

Classification: direct build/remove/selection/nth-tick watchdog owner.

Why it exists:

The comments say the codebase had many historical append-style event wrappers, and this final wrapper re-registers the current build/remove/selection chain to reassert consecration registration after older handlers run.

Direct routes observed:

- Direct build-event registrations for:
  - `on_built_entity`
  - `on_robot_built_entity`
  - `script_raised_built`
  - `script_raised_revive`
- Direct remove-event registrations for:
  - `on_entity_died`
  - `on_pre_player_mined_item`
  - `on_robot_pre_mined`
  - `script_raised_destroy`
- Direct selected-entity registration:
  - `on_selected_entity_changed`
- Direct nth-tick watchdog:
  - `script.on_nth_tick(149, ...)`

Current disposition: direct event and nth-tick risk. Probably a legacy recovery workaround. Candidate for ordered registry migration, but only after confirming what older build/remove/selection handlers must still run before this block.

## Initial Stage 2 findings

1. The codebase has a real canonical event registry, and some newer modules use it correctly.

2. The codebase also still has direct event registrations in bootstrap/runtime recovery layers.

3. `runtime_tick_broker.lua` depends on `_G.TechPriestsRuntimeEventRegistry` for registry routing. If that global is absent, it falls back to direct `script.on_nth_tick`.

4. `runtime_event_registry.lua` returns the registry table, but the inspected file does not visibly assign itself to `_G.TechPriestsRuntimeEventRegistry`. This may be assigned elsewhere, but it must be verified.

5. The early 0.1.596 hook intentionally monkey-patches `script.on_nth_tick` before legacy fragments load. This is a compatibility safety net for raw direct nth-tick registration, not a replacement for registry migration.

6. GUI recovery and consecration recovery paths are the first obvious direct-registration migration candidates, but both exist because previous event ownership conflicts broke visible behavior. They should be migrated with ordering intact, not deleted.

## Current event/timing ownership categories

| Category | Meaning | Current examples |
|---|---|---|
| Canonical registry internals | The one place allowed to call `script.on_event`, `script.on_nth_tick`, `script.on_init`, or `script.on_configuration_changed` as part of central dispatch. | `runtime_event_registry.lua` |
| Canonical service broker | Budgeted recurring-service authority that should pulse through the event registry. | `runtime_tick_broker.lua` |
| Modern registry-owned modules | Modules that obtain the registry and register through `R.on_event` / `R.on_nth_tick`. | `event_driven_work_feeder_0608.lua` |
| Early monkey-patch firewall | Compatibility hook that wraps raw nth-tick registration before legacy fragments load. | `efficiency_economy_0596.lua` |
| Direct compatibility fallback | Direct registration used only if the registry is unavailable. | `runtime_tick_broker.lua` fallback, Work State boot-display fallback |
| Direct event owner / migration target | Direct registrations that bypass the registry even though the registry exists. | Work State GUI recovery, bootstrap selected/capsule/consecration watchdog routes |

## Recommended next actions inside Stage 2

1. Verify whether `_G.TechPriestsRuntimeEventRegistry` is ever assigned.

2. Inventory every remaining direct `script.on_event`, `script.on_nth_tick`, `script.on_init`, and `script.on_configuration_changed` in `tech-priests_src/`.

3. Classify each direct registration as:
   - registry internal,
   - early 0.1.596 monkey-patch,
   - compatibility fallback,
   - direct event override risk,
   - or migration target.

4. Migrate the least risky direct registrations first. The likely first candidate is `workstate_gui_radar_recovery_0465.lua`, because it already requires the registry and already uses `R.on_nth_tick` for part of its service.

5. Leave the 0.1.596 early hook alone until all raw direct nth-tick paths are known.

## Provisional first repair candidate

The smallest likely safe repair is not yet a behavior migration. It is a registry exposure check:

- If `_G.TechPriestsRuntimeEventRegistry` is never assigned, add that global assignment inside `runtime_event_registry.lua` or through a tiny install path before `runtime_tick_broker.lua` loads.
- This would reduce fallback direct nth-tick registration and make modules that look for the global registry behave consistently.
- This should be treated as a small infrastructure repair, not a behavior rewrite.

Do not apply this until the remaining direct-registration inventory confirms the global is truly missing and no module intentionally depends on the registry being require-only.
