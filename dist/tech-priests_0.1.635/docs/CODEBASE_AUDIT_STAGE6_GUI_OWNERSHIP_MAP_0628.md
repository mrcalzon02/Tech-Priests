# Stage 6 GUI Ownership Map — 0.1.628 Source Baseline

This document begins the GUI ownership and containment audit from the corrected 0.1.628 source baseline.

This is documentation-only. No GUI behavior or layout has been changed by this note.

## Plain-English purpose

The visible GUI problems are not just style problems. The source currently has multiple GUI owners, mixed router/direct event paths, compatibility shims, late recovery handlers, and large nested decorative shells.

Before removing indented frames or fixing Machine-Spirit Ledger containment, we need to know:

- who owns GUI event routing,
- who builds each window,
- who refreshes each window,
- which modules still direct-register GUI events,
- which nested frames are intended decorative shells,
- and which native frames are likely accidental visual clutter.

## Confirmed central GUI authority

### `scripts/gui/gui_router.lua`

Classification: intended GUI event authority.

The router states that it is the runtime owner for GUI opened/closed/click dispatch, and that actual Factorio event registration is centralized through `runtime_event_registry.lua`.

Key behavior:

- Maintains handler lists for `opened`, `closed`, and `click`.
- `Router.register(kind, handler, label, opts)` records GUI routes.
- `Router.dispatch_opened`, `Router.dispatch_closed`, and `Router.dispatch_click` call registered routes in order.
- `Router.install()` registers the three GUI dispatchers through the runtime event registry.
- `/tp-gui-router-0427` reports installed route counts and error status.

Disposition: preserve. This should remain the GUI event authority.

Repair implication:

Do not add another top-level GUI dispatcher. Migrate older GUI owners onto this router or the `gui_bus` shim.

### `scripts/core/gui_bus.lua`

Classification: compatibility shim.

The bus explicitly says the old 0.1.327 GUI bus name is retained because modules still require it, but it delegates to `scripts/gui/gui_router.lua`.

Key behavior:

- `GuiBus.register(...)` delegates to `Router.register(...)`.
- `GuiBus.install_handlers()` installs the router and registers old Station Catalog globals if present.
- `GuiBus.install()` installs handlers and debug command support.

Disposition: preserve as compatibility bridge.

Repair implication:

Modules that already use `gui_bus.register(...)` are closer to the desired route than direct `script.on_event(...)` users.

## GUI ownership hotspots

### Work State Reliquary / Station Work Inventory

File: `scripts/core/station_work_inventory.lua`

Classification: major GUI builder and direct GUI event owner.

Purpose:

- Canonical station-bound work state/inventory/command inspection panel.
- Enforces the doctrine that Cogitator Station is inventory/memory/command/task owner and Tech-Priest is mobile actuator.
- Builds the Work-State Reliquary GUI.
- Owns BIOS boot display refresh.

Current event ownership:

- Directly registers `on_gui_opened`, `on_gui_closed`, and `on_gui_click`.
- Directly registers boot refresh with `script.on_nth_tick(M.boot_refresh_ticks, ...)`.
- Late recovery module also direct-registers the same GUI events and calls this module's handlers manually.

Current containment/layout concerns:

- `add_inner_screen_page_0565(...)` creates a native `frame` wrapping a scroll-pane.
- The frame is styled as a Cogitator display frame and appears intentionally decorative.
- However, this pattern contributes to visible nested/indented frame clutter if used too deeply or without clear shell/body separation.

Disposition: high-priority GUI owner. Do not blindly delete direct handlers until router/recovery order is defined.

Likely repair direction:

1. Register Work State handlers through `gui_router`/`gui_bus` exactly once.
2. Move boot refresh to registry/broker route if not already safely covered by recovery.
3. Remove or disable direct GUI event registration only after the late recovery module is no longer needed as a dispatcher repair.
4. Later, review native inner frames and convert accidental layout frames to flows/panes while preserving intended CRT shell frames.

### Work State GUI/Radar Recovery

File: `scripts/core/workstate_gui_radar_recovery_0465.lua`

Classification: late compatibility recovery owner.

Purpose:

The comments explain that Work State / BIOS boot could disappear when late raw GUI handlers replaced the GUI router dispatcher. This module deliberately loads late, calls router first, then explicitly calls Work State handlers.

Current event ownership:

- Directly registers `on_gui_opened`, `on_gui_closed`, and `on_gui_click`.
- Calls `Router.dispatch_*` first.
- Calls `Work.handle_gui_*` second.
- Uses runtime event registry for its Work State boot-display nth-tick service when available.

Disposition: compatibility workaround, not final architecture.

Repair implication:

This module should be retired or reduced only after router route order proves Work State survives without it. It should not be converted naively into a registry route while still calling `Router.dispatch_*`, or it can double-dispatch router handlers.

### Station Catalog / Cogitator Auspex Ledger

File: `scripts/core/station_catalog.lua`

Classification: catalog authority plus GUI owner.

Purpose:

- Station radar catalog / known-resource map.
- Maintains station snapshots of resources, mineable products, nearby entities, storage contents, and subordinate stations.
- Builds `Cogitator Auspex Ledger` GUI.

Current event ownership:

- Exposes catalog GUI handlers as globals for `gui_bus` compatibility:
  - `_G.tech_priests_0327_catalog_gui_opened`
  - `_G.tech_priests_0327_catalog_gui_closed`
  - `_G.tech_priests_0327_catalog_gui_click`
- Still directly registers `on_gui_opened`, `on_gui_closed`, and `on_gui_click`.
- Still directly registers a scan-period nth-tick.
- Directly registers destroy/mined events for catalog cleanup.

Current containment/layout concerns:

- Builds a comparatively simple top-level frame with labels and sections.
- Less likely to be the source of the worst nested-frame visual issue, but still part of event ownership conflict.

Disposition: double-route candidate.

Likely repair direction:

1. Ensure `gui_bus.install_handlers()` runs after Station Catalog exposes its globals.
2. Move Station Catalog GUI handlers onto router/bus once.
3. Keep catalog destroy/mined cleanup separate from GUI cleanup.
4. Do not change catalog scan/event behavior in the same batch as GUI visual containment.

### Consecration History / Machine-Spirit State Ledger

File: `scripts/core/consecration/history_gui.lua`

Classification: Machine-Spirit Ledger GUI owner.

Purpose:

- Maintains operation-by-operation sanctification history per machine.
- Displays Machine-Spirit State Ledger when machine GUI opens.
- Displays machine-spirit name/caste/traits/flaws/history.

Current event ownership:

- Registers opened/closed/click through `gui_bus` when available.
- Falls back to direct GUI event registration if `gui_bus` is unavailable.
- Also tries to register opened/closed/click through `TechPriestsRuntimeEventRegistry` if that global exists.
- Directly registers refresh nth-tick `121` for open ledger refresh.

Current containment/layout concerns:

This is the primary Machine-Spirit Ledger containment hotspot.

The current frame stack is roughly:

```text
Factorio top-level frame: Machine-Spirit State Ledger
  -> sliced decorative outer shell flows
    -> inner bezel shell flows
      -> native frame body: tech_priests_machine_spirit_gui_body_0567
        -> header flow
        -> native frame: tech_priests_machine_spirit_inner_screen_0565
          -> tabbed-pane
            -> summary scroll-pane
            -> marks scroll-pane
              -> native frame: Machine-Spirit Character Ledger
                -> native frames for trait/flaw/neutral tables
            -> history native frame
              -> scroll-pane/table
```

Some of this is intentional sliced art. The problematic native frame indentation likely comes from using native `frame` containers inside the decorative shell and inside tab pages where a `flow` or styled scroll-pane would suffice.

Disposition: highest-priority visual containment target.

Likely repair direction:

1. Keep the top-level Factorio frame and decorative sliced shell.
2. Keep the tabbed-pane.
3. Convert accidental interior native frames to flows or style-neutral containers where possible:
   - `tech_priests_machine_spirit_gui_body_0567` may be decorative and should be reviewed carefully.
   - `tech_priests_machine_spirit_inner_screen_0565` is likely intended CRT screen containment but may need style flattening.
   - `Machine-Spirit Character Ledger` wrapper frame likely creates visible extra indentation and may be convertible to a flow with a heading label.
   - Trait/flaw/neutral section frames likely create repeated indented boxes and are strong candidates for conversion to heading labels plus tables/flows.
   - The history tab page native frame may be flattenable if the tabbed-pane already provides containment.
4. Do not change event routing and visual frame flattening in the same commit unless the patch is tiny and easily reversible.

### Conclave Center / Command Overview integration

File: `scripts/core/conclave_center_0558.lua`

Classification: governance GUI plus event-owned world/research routes.

Purpose:

- GUI/research governance layer only.
- Gates remote Shift+Y access behind placed Conclave Center.
- Opens management overview from physical console.
- Maintains doctrine vote/loyalty ledgers.
- Explicitly does not move priests, create work, or bypass dispatcher/order/action authority.

Current event ownership:

- Uses `TechPriestsRuntimeEventRegistry` for build/remove/open/research/nth-tick routes when available.
- GUI opened route opens Conclave GUI when the physical Conclave entity is opened.
- Uses bare `TechPriestsGuiRouter` global for click registration if available.
- Also registers script-trigger effect through registry if available, direct fallback otherwise.

Current concern:

`gui_router.lua` returns `Router`; it does not visibly assign `TechPriestsGuiRouter`. If no other loader assigns that global, the Conclave click route may not be registered through the router. This should be confirmed before changing Conclave GUI code.

Disposition: GUI/event discovery check, not immediate containment target.

### Task Auspex

File: `scripts/core/task_auspex_0622.lua`

Classification: UI/telemetry-only attachment to Command Overview.

Purpose:

- Adds a diegetic Task Auspex / Debug Readout tab.
- Reads existing telemetry from broker, queues, reservations, buckets, sleep/dirty/cache authorities, movement controller, and event feeder.
- Explicitly does not own scheduling, tasks, queues, reservations, sleep states, movement, or cache invalidation.

Current event ownership:

- Does not directly own Factorio GUI events.
- Wraps the Command Overview build function to attach a tab.
- Handles clicks for its own refresh/section buttons through its module handler, depending on surrounding Command Overview routing.

Current containment/layout concerns:

- Adds a very wide `1040` pixel scroll-pane inside the Command Overview tab.
- Likely not the source of Machine-Spirit Ledger indentation, but should be checked if Command Overview overflows or stretches too wide.

Disposition: Stage 6 containment/reflow review, not event-authority migration target.

## Current ownership diagnosis

### Intended event stack

```text
runtime_event_registry
  -> gui_router
    -> gui_bus compatibility shim
      -> GUI modules register opened/closed/click handlers
```

### Actual mixed stack

```text
runtime_event_registry -> gui_router
legacy gui_bus -> gui_router
station_work_inventory -> direct on_gui_* handlers
station_catalog -> direct on_gui_* handlers and gui_bus globals
consecration/history_gui -> gui_bus + possible registry + direct fallback
workstate_gui_radar_recovery -> direct on_gui_* recovery wrapper that manually calls router + Work State
conclave_center -> registry open route + possible bare TechPriestsGuiRouter click route
Task Auspex -> command overview wrapper/tab attachment
```

## Immediate repair order recommendation

### GUI Repair 0 — Do not touch behavior-critical timing routes

This remains out of scope until Stage 3/4.

### GUI Repair 1 — Router/global discovery audit

Before moving handlers:

- Confirm whether `TechPriestsGuiRouter` is ever assigned.
- If not, either:
  - update Conclave to `pcall(require, "scripts.gui.gui_router")`, or
  - assign a router global through an explicit, safe router install step if Factorio permits and the project wants that compatibility name.

Prefer require-first discovery, matching the broker repair philosophy.

### GUI Repair 2 — Work State route consolidation

Goal: one path for Work State opened/closed/click.

Candidate shape:

- Register `station_work_inventory` handlers through `gui_router` or `gui_bus` with labels.
- Keep `workstate_gui_radar_recovery_0465` temporarily, but reduce duplicate direct handler risk only after live test confirms Work State opens and boot display persists.
- Do not let recovery call `Router.dispatch_*` if it is itself registered through the router.

### GUI Repair 3 — Station Catalog route consolidation

Goal: eliminate direct GUI event registration while preserving catalog scan and destroy cleanup.

Candidate shape:

- Keep `_G.tech_priests_0327_catalog_gui_*` compatibility exports if needed.
- Ensure `gui_bus.install_handlers()` sees and registers them.
- Remove direct `on_gui_*` registration only after router summary confirms catalog routes are present.

### GUI Repair 4 — Machine-Spirit Ledger containment flattening

Goal: remove accidental interior native frames while preserving decorative sliced shell and top-level window containment.

Candidate first visual patch:

- Convert the `Machine-Spirit Character Ledger` wrapper frame into a flow with a heading label.
- Convert trait/flaw/neutral section frames into flows with heading labels and tables.
- Review the history tab native frame as a possible flow conversion.
- Keep top-level frame, sliced shell, tabbed-pane, and styled scroll-panes.

Expected effect:

- Fewer visible nested grey/indented native frames inside the Machine-Spirit Ledger.
- Ledger remains contained to its right-docked top-level window.

### GUI Repair 5 — Task Auspex width review

Only after the main ledger is stable:

- Check whether the `1040` pixel Task Auspex scroll-pane causes Command Overview overflow.
- If needed, make width adaptive or reduce hard width.

## Live-test targets after future patches

Commands:

```text
/tp-gui-router-0427
/tp-workstate-gui-0465
/tp-consecration-history-0422
/tp-consecration-history-0453
/tp-task-auspex
/tp-runtime-report
```

Expected observations:

- GUI router reports opened/closed/click handlers.
- Work State Reliquary opens from selected station/priest and does not disappear.
- Machine-Spirit Ledger opens on consecrated machines and stays inside its right-docked window.
- The ledger has fewer nested native frame boxes after visual flattening.
- Task Auspex tab still attaches to Command Overview.
- Runtime report still shows broker/registry routes and no startup errors.
