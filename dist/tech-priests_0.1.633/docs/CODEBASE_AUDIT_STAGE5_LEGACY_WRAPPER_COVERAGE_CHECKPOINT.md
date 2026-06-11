# Stage 5 Checkpoint — Legacy Wrapper Coverage

This checkpoint records the Stage 5 audit of legacy/generated direct-command coverage.

This is documentation-only. No runtime behavior has been changed by this note.

## Files reviewed

```text
scripts/core/behavior_stack_cleanup_0509.lua
scripts/generated/control_legacy_part_012.lua
```

This checkpoint also relies on earlier Stage 5 reviews of:

```text
scripts/core/single_dispatcher_0510.lua
scripts/core/movement_controller.lua
scripts/core/combat_safety.lua
scripts/core/movement_enforcement_0566.lua
scripts/core/combat_magos_movement_authority_0472.lua
```

## Plain-English result

The legacy/generated direct command surfaces are not all freely active behavior owners.

A meaningful amount of legacy behavior is covered by modern wrappers and authorities:

```text
single_dispatcher_0510 owns modern behavior selection.
movement_controller.lua owns canonical ground go-to/stop routing.
combat_safety.lua blocks unsafe attack commands.
combat_magos_movement_authority_0472 prevents visible-priest attack AI from becoming a second combat owner.
movement_enforcement_0566 rejects stale/far targets and returns overleashed priests home.
behavior_stack_cleanup_0509 decommissions the old 0502 station-side executor and wraps direct acquisition paths back into physical movement.
```

Therefore, the correct repair strategy is still:

```text
Do not mass-edit generated legacy files.
Patch modern authority wrappers and caller contracts first.
```

## `behavior_stack_cleanup_0509.lua` finding

This file is doing exactly what a late authority cleanup layer should do.

Its header says it exists because valid-priest recall was mostly suppressed, but live logs still showed native units becoming invalid during movement and old station-side quarantine still depositing resources from afar.

It specifically intends to:

```text
decommission 0502 quarantine as an executor;
route direct acquisition through physical executor again;
debounce debug/overview order refreshes;
prevent UI/mouse-over refreshes from resetting active work.
```

Manual review confirms those functions exist.

### 0502 station-side executor is decommissioned

`decommission_0502()` disables 0502 station-side work settings:

```text
station_side_direct_acquisition = false
suppress_far_acquisition_movement = false
tether_visible_priest = false
log_station_side_working = false
log_movement_suppression = false
```

Then it wraps 0502 service so it only acts for missing-priest diagnostics/recovery, not valid-priest movement or station-side resource deposit.

Disposition:

```text
Healthy legacy suppression.
```

### Legacy direct acquisition globals are wrapped

`wrap_direct_globals()` wraps:

```text
tech_priests_0273_service_direct_current
tech_priests_0312_service_direct_current
tech_priests_0315_service_direct_current
handle_emergency_desperation_craft
```

Before those legacy functions run, the wrapper calls:

```text
M.hold_or_route_direct(pair, task, name)
```

If the priest is not adjacent to the direct-acquisition target, 0509 routes movement physically and returns true, blocking station-side remote work.

Disposition:

```text
Healthy legacy direct-acquisition coverage.
```

### Older acquisition executor is wrapped

`wrap_acquisition_executor()` wraps:

```text
scripts.core.acquisition_executor.service_pair
```

so it also goes through `M.hold_or_route_direct(...)` first.

Disposition:

```text
Healthy coverage of the older 0336/0340 acquisition executor.
```

### Passive order refreshes are debounced

`wrap_order_refresh()` suppresses passive refresh sources such as:

```text
mouse-over
radar-priest-scan
overview-ui
overview*
```

when the pair already has active work.

Disposition:

```text
Healthy protection against UI/debug churn resetting active work.
```

### Behavior cleanup is itself periodically serviced

`M.install()` registers a periodic service through the runtime event registry when available:

```text
registry.on_nth_tick(53, function() M.service_all() end, ...)
```

Disposition:

```text
The cleanup wrapper is not just installed once; it continues refreshing maps and routing active direct work.
```

## `control_legacy_part_012.lua` finding

This generated legacy file contains direct command surfaces, but the reviewed section is not ordinary ground movement. It is mostly space-platform guarded walking.

Examples:

```text
tech_priests_platform_command_walk_0212(...)
tech_priests_stop_platform_priest_0206(...)
```

Those functions use direct `go_to_location`/`stop` commands for platform movement and platform safety. The file comments describe it as:

```text
Space-platform guarded walking restoration pass.
Platform priests can periodically path to nearby valid platform work objects/inspection points.
Existing guard returns them to exact locus if path becomes stale, unsafe, or complete.
```

Disposition:

```text
Do not treat these as ordinary ground movement bypasses.
```

This matters because the movement-controller doctrine already says:

```text
Space-platform hover/pathing is outside this controller.
```

Therefore, some generated direct commands are expected platform exceptions. They should not be blindly migrated into the ground movement contract.

## Current coverage assessment

### Covered or partially covered

```text
old 0502 station-side executor
legacy direct acquisition globals
older acquisition_executor service_pair
passive/debug order refresh churn
friendly-fire unsafe attack commands
visible-priest attack command ownership
far/out-of-radius movement requests
ground go-to/attack/stop route wrapper when movement_controller is loaded
```

### Not fully proven covered

```text
all generated control_legacy_part_*.lua direct command sites
all platform-specific direct commands
all direct stop/home safety commands
manual/command-driven legacy paths
all load-order edge cases where wrappers install before the functions they expect to wrap
```

Important nuance:

```text
Not fully proven covered does not mean broken.
It means no mass edit should happen until a narrower scanner/checkpoint proves which direct-command surfaces are still reachable at runtime.
```

## Remaining watch items

### 1. Load-order wrapper timing

Many wrappers only wrap functions that exist at install time. If a generated legacy function is defined after a wrapper installs, the wrapper may miss it unless another later install/service pass wraps it.

`behavior_stack_cleanup_0509` mitigates some of this by periodically calling `wrap_acquisition_executor()` in `service_all()`, but `wrap_direct_globals()` appears to run only during install.

Current disposition:

```text
Watch item. Needs load-order/install-order audit before patching.
```

Future audit shape:

```text
Review bootstrap/control module install order and confirm behavior_stack_cleanup_0509 installs after generated legacy globals exist.
```

### 2. Platform movement exception boundary

Generated platform walking uses direct commands intentionally. This is probably correct, but it needs a clearly documented boundary:

```text
ground movement -> movement_controller.lua
space/platform guarded walking -> platform guard/pathing code
```

Current disposition:

```text
Documentation/architecture watch item, not behavior repair.
```

### 3. Failure semantics still repeat

Even when wrappers route legacy behavior into physical movement, they often still share the same semantic weakness:

```text
movement request failed, but behavior may still report travel/held/moving.
```

Current disposition:

```text
Belongs to movement contract repair family.
```

## Current Stage 5 decision

No code repair from this pass.

This checkpoint reinforces the previous conclusion:

```text
Do not broadly remove direct commands.
Do not mass-edit generated legacy files.
Preserve safety/platform exceptions.
Repair movement semantics in modern owner layers first.
```

Updated priority ranking:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. Movement request failure handling in callers that report moving after false.
5. Load-order/install-order audit for wrappers that cover generated legacy globals.
6. 0514 emergency production returning/deposit-block diagnostics.
7. 0516 repair movement failure/reservation release refinement.
8. 0515 consecration movement failure/cooldown-claim refinement.
9. 0517 low-priority direct-call abort symmetry and cluster-release refinement.
10. construction movement failure/timeout and optional site reservation refinement.
11. generated legacy direct command reachability only after wrapper/load-order coverage is verified.
```

## Recommended next audit target

Continue with install/load-order audit:

```text
Find where generated legacy parts are loaded.
Find where core authority modules install.
Verify behavior_stack_cleanup_0509 installs after the direct legacy globals it wraps, or has a later service pass that catches missed wrappers.
Verify movement_controller/combat_safety/combat_magos/movement_enforcement install order relative to legacy command surfaces.
```

This is the correct next step before any source repair touching wrappers or generated files.

## Live diagnostics after packaging

Use:

```text
/tp-behavior-cleanup-0509
/tp-movement-0429
/tp-combat-stage-0472
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- 0502 station-side executor reappearing as active behavior;
- direct acquisition travel routed through `physical-direct-travel-0509`;
- passive UI refreshes resetting active work;
- platform direct walk commands only on platform pairs;
- generated legacy direct commands firing for ordinary ground movement after modern wrappers should own them.
