# Stage 5 Checkpoint — Install and Load Order

This checkpoint records the Stage 5 audit of runtime install/load order around generated legacy fragments and modern authority wrappers.

This is documentation-only. No runtime behavior has been changed by this note.

## Files reviewed

```text
control.lua
scripts/core/behavior_stack_cleanup_0509.lua
scripts/core/movement_bounds_contract_0511.lua
scripts/core/movement_cadence_contract_0518.lua
scripts/core/movement_controller.lua
```

## Plain-English result

The broad load order is mostly favorable for wrapper coverage:

```text
control.lua loads all generated legacy fragments first.
Then it installs later authority/wrapper modules in version order.
```

That means many late wrappers are installed after the old global functions exist, which is good for coverage.

However, this pass found one important unresolved movement-controller install question:

```text
movement_cadence_contract_0518.lua requires scripts.core.movement_controller and tunes it,
but requiring the module is not the same as calling Movement.install().
movement_controller.lua only exports _G.tech_priests_request_movement_0418 inside M.install().
If no earlier path calls Movement.install(), then later wrappers that expect _G.tech_priests_request_movement_0418 may not actually wrap anything.
```

This is not yet proven broken. It is a high-priority audit question for the next pass.

## Confirmed load order structure

`control.lua` begins with an early passive-service austerity hook, then loads generated legacy fragments:

```text
scripts.generated.control_legacy_part_001
...
scripts.generated.control_legacy_part_022
```

Only after those generated fragments does it install post-legacy authority modules.

Confirmed order examples:

```text
0466 behavior mutex
0469 order queue
0472 combat/magos movement authority
0488 action state arbiter
0490 direct mining safety
0498 task/pair audit
0499/0500 lifecycle authority/seal
0501/0502 vanish guards
0503 recovery safety
0505 behavior execution doctrine
0506 mobility recovery contract
0507 action stack contract
0508 movement recovery authority
0509 behavior stack cleanup
0510 single dispatcher
0511 movement bounds contract
0512 scheduler contract
0513 direct acquisition executor
0514 emergency production executor
0515 consecration executor
0516 repair executor
0517 combat repair doctrine
0518 movement cadence contract
0519 logistics/construction contract
0527 logistics fetch executor
0528 machine logistics fulfillment
0566 movement enforcement governor
0574 authority corridor pathing guard
0593/0594/0595/0596 runtime/economy governors
0600 runtime tick broker and pair buckets earlier in the post-legacy authority block
0601 work reservations/queues
0622 task auspex UI
```

## Positive finding 1 — generated legacy fragments load before wrappers

The legacy fragments are loaded before 0509/0511/0518 and later authority modules.

This strengthens wrapper coverage for functions that are defined by generated fragments, such as:

```text
tech_priests_0273_service_direct_current
tech_priests_0312_service_direct_current
tech_priests_0315_service_direct_current
handle_emergency_desperation_craft
tech_priests_0273_find_direct_target
```

Disposition:

```text
Good. Late wrappers should see these globals at install time.
```

## Positive finding 2 — 0509 installs after the legacy globals it wraps

`behavior_stack_cleanup_0509.lua` is installed after generated legacy fragments and after 0502/0508 recovery-movement layers.

Its install sequence includes:

```text
decommission_0502()
wrap_direct_globals()
wrap_acquisition_executor()
wrap_order_refresh()
wrap_cascade()
wrap_pair_dump()
```

This supports the earlier legacy-wrapper coverage finding:

```text
0509 is positioned to wrap legacy direct acquisition globals after they exist.
```

## Positive finding 3 — 0511 installs after dispatcher/0509 and continues servicing

`movement_bounds_contract_0511.lua` installs after `single_dispatcher_0510.lua` and `behavior_stack_cleanup_0509.lua`.

Its install sequence includes:

```text
wrap_target_finder()
wrap_movement_request()
wrap_acquisition_executor()
wrap_legacy_direct_functions()
decommission_legacy_direct_nth_guard()
```

It also registers a periodic service that reruns key wrapper/sanitizer work:

```text
registry.on_nth_tick(M.service_interval, function() M.service_all("nth-tick-0511") end, ...)
```

`service_all(...)` reruns:

```text
decommission_legacy_direct_nth_guard()
wrap_target_finder()
wrap_movement_request()
wrap_acquisition_executor()
wrap_legacy_direct_functions()
sanitize_direct_target(...)
return_to_station_if_overleashed(...)
```

Disposition:

```text
Good. 0511 can catch some missed wrappers later, not only at install time.
```

## Positive finding 4 — old 61-tick direct-gather guard is specifically decommissioned

`movement_bounds_contract_0511.lua` removes a specific generated legacy route:

```text
control_legacy_part_016.lua lines 820-850
```

The code comment identifies it as:

```text
the old 0.1.273 one-second hard direct-gather kick
```

Disposition:

```text
Good. This directly targets a known dispatcher-bypassing legacy pulse.
```

## Unresolved high-priority finding — movement_controller install path

`movement_cadence_contract_0518.lua` has:

```text
local ok, Movement = pcall(require, "scripts.core.movement_controller")
```

and then tunes controller fields:

```text
Movement.command_refresh_ticks = ...
Movement.retarget_hold_ticks = ...
Movement.minimum_retarget_distance_sq = ...
Movement.service_ticks = ...
```

But it does not visibly call:

```text
Movement.install()
```

In `movement_controller.lua`, the globals are exported inside:

```text
function M.patch_globals()
  _G.tech_priests_request_movement_0418 = function(...)
  _G.tech_priests_stop_movement_0418 = function(...)
  _G.tech_priests_route_ground_command_0429 = function(...)
end

function M.install()
  ensure_root()
  M.patch_globals()
  M.commands()
  register broker/registry services
end
```

Therefore, requiring `movement_controller` is not enough by itself unless the module has side effects elsewhere that were not visible in the reviewed bottom section.

Potential consequence if `Movement.install()` is not called before 0518:

```text
_G.tech_priests_request_movement_0418 may be nil.
0518 wrap_request() will do nothing.
0511 wrap_movement_request() will do nothing.
callers will fall back to route/direct command paths more often.
movement_controller broker services may not be registered.
```

Current disposition:

```text
High-priority unresolved audit item.
Do not patch yet.
Verify with a scanner or direct source search for Movement.install / movement_controller install references.
```

## Why this matters

A large part of Stage 5 has assumed this doctrine:

```text
movement_controller.lua is the canonical ground movement command authority.
```

That doctrine is correct at the module-design level. But install order must prove that the controller is actually installed and exporting globals before wrappers depend on it.

If it is not installed, many earlier symptoms make more sense:

```text
callers fall back to direct commands;
movement request wrappers do not wrap;
movement completion/status is weak;
old fire-and-forget movement remains common;
executor phases say moving while no canonical movement request exists.
```

Again: this is not proven yet. It is the next audit target.

## Current Stage 5 decision

No code repair from this pass.

The load-order result changes the immediate next step:

```text
Before more behavior review, confirm the movement_controller install path.
```

## Recommended next audit action

Create/run a read-only scanner that inventories:

```text
require("scripts.core.movement_controller")
Movement.install()
movement_controller.install
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418
tech_priests_request_movement_0418 assignment sites
tech_priests_request_movement_0418 wrapper sites
M.patch_globals()
```

The scanner should output:

```text
CODEBASE_AUDIT_STAGE5_MOVEMENT_CONTROLLER_INSTALL_SURFACES.md
CODEBASE_AUDIT_STAGE5_MOVEMENT_CONTROLLER_INSTALL_SURFACES.json
```

Then inspect whether there is a real install call or only require/tune/wrap calls.

## Updated priority ranking

```text
1. Confirm movement_controller install path and global export order.
2. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
3. 0513 direct acquisition deposit/gathered_units correctness.
4. Movement completion/status contract across movement-dependent executors.
5. Movement request failure handling in callers that report moving after false.
6. Load-order/install-order refinements for wrappers that depend on movement globals.
7. 0514 emergency production returning/deposit-block diagnostics.
8. 0516 repair movement failure/reservation release refinement.
9. 0515 consecration movement failure/cooldown-claim refinement.
10. 0517 low-priority direct-call abort symmetry and cluster-release refinement.
11. construction movement failure/timeout and optional site reservation refinement.
12. generated legacy direct command reachability only after wrapper/load-order coverage is verified.
```

## Live diagnostics after packaging

Use:

```text
/tp-movement-0429
/tp-movement-cadence-0518
/tp-movement-bounds-0511
/tp-behavior-cleanup-0509
/tp-runtime-report
```

Watch for:

- `/tp-movement-0429` command exists;
- movement-controller appears in `/tp-runtime-report`;
- movement request counts increase when executors ask to move;
- 0511/0518 show wrapper activity;
- executor phases report moving while `movement_request_0418` is nil.
