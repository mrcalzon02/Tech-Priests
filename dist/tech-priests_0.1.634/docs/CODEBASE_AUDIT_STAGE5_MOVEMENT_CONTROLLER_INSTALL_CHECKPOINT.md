# Stage 5 Checkpoint — Movement Controller Install Path

This checkpoint records the Stage 5 install-surface review for:

```text
scripts/core/movement_controller.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Reports and files reviewed

Generated scanner output:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_MOVEMENT_CONTROLLER_INSTALL_SURFACES.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_MOVEMENT_CONTROLLER_INSTALL_SURFACES.json
```

Scanner:

```text
tools/audit_movement_controller_install_surfaces.py
```

Manual source review:

```text
scripts/generated/control_legacy_part_022.lua
scripts/core/bootstrap_runtime.lua
scripts/core/movement_controller.lua
scripts/core/movement_bounds_contract_0511.lua
scripts/core/movement_cadence_contract_0518.lua
```

## Plain-English result

The movement controller **does have a real install path**.

It is not installed directly by the later top-level authority block in `control.lua`. Instead, it is installed through the generated legacy bootstrap spine:

```text
control.lua
  -> scripts.generated.control_legacy_part_022
    -> scripts.core.bootstrap_runtime.install()
      -> TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
        -> require("scripts.core.movement_controller")
        -> movement_controller.install()
```

This resolves the prior uncertainty from the install/load-order checkpoint.

The movement controller is not merely required/tuned by `movement_cadence_contract_0518.lua`. It is installed earlier through `bootstrap_runtime.lua`.

## Evidence from scanner

The install surface scanner found:

```text
Total hits: 750
movement-controller-install-call-candidate: 2
movement-controller-require: 2
movement-controller-install-definition: 3
movement-controller-patch-globals-call: 3
```

The important install candidate is:

```text
scripts/core/bootstrap_runtime.lua:808
if movement_controller and movement_controller.install then movement_controller.install() end
```

The important require candidate is:

```text
scripts/core/bootstrap_runtime.lua:807
local movement_controller = require("scripts.core.movement_controller")
```

## Bootstrap path

`control_legacy_part_022.lua` delegates the 0.1.321+ patch/install chain to `bootstrap_runtime.lua`:

```text
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")
if TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 and TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install then
  TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install()
end
```

Inside `bootstrap_runtime.lua`, the 0.1.418 movement controller installer is explicit:

```text
function TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
  local movement_controller = require("scripts.core.movement_controller")
  if movement_controller and movement_controller.install then movement_controller.install() end
  if log then log("[Tech-Priests 0.1.418] unified movement controller pass loaded") end
end

TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER()
TECH_PRIESTS_0418_INSTALL_MOVEMENT_CONTROLLER = nil
```

Disposition:

```text
Movement controller install path confirmed.
```

## Export path

`movement_controller.lua` exports movement globals from `M.patch_globals()`, which is called by `M.install()`:

```text
_G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
  return M.request(pair, destination, reason, opts)
end

_G.tech_priests_stop_movement_0418 = function(pair, reason)
  return M.stop(pair, reason)
end

_G.tech_priests_route_ground_command_0429 = function(priest, command, owner, opts)
  return M.route_command(priest, command, owner, opts)
end
```

`M.install()` also registers the broker/registry services for movement request servicing and sampling.

Disposition:

```text
Movement request globals should exist before later wrapper layers such as 0511 and 0518 try to wrap them.
```

## Load-order implication

Because `control.lua` loads generated legacy fragments first, and `control_legacy_part_022.lua` invokes the bootstrap runtime at the end of the generated fragment chain, the movement controller is installed before the post-legacy authority block reaches:

```text
0509 behavior_stack_cleanup
0510 single_dispatcher
0511 movement_bounds_contract
0518 movement_cadence_contract
0527 logistics_fetch_executor
0528 logistics_machine_fulfillment
0566 movement_enforcement
```

This is favorable.

It means:

```text
0511 wrap_movement_request() should usually see _G.tech_priests_request_movement_0418.
0518 wrap_request() should usually see _G.tech_priests_request_movement_0418.
Modern executors should usually be submitting through the canonical movement request API before falling back.
```

## Corrected interpretation

The earlier concern was:

```text
Maybe movement_controller is only required/tuned but never installed.
```

This pass corrects that:

```text
movement_controller is installed through bootstrap_runtime.lua.
```

Therefore, the broad Stage 5 movement issue is not primarily a missing install problem.

The issue remains the one already identified:

```text
movement request submission is an intent contract, not a completion contract.
Callers may still report moving/walking/returning after failed movement request submission or after a request expires/replaces/clamps without a task-owner terminal state.
```

## Remaining watch items

### 1. Bootstrap order is unusual

The movement controller install path lives in generated legacy part 022 rather than the visible post-legacy authority block in `control.lua`.

This is valid but easy to miss during audits.

Future documentation/cleanup option:

```text
Add a comment in control.lua near the generated-fragment loader explaining that 0.1.418 movement_controller is installed by bootstrap_runtime from control_legacy_part_022.
```

Not a behavior repair.

### 2. Duplicate/late wrappers still need caution

Since 0511 and 0518 wrap `_G.tech_priests_request_movement_0418`, any future movement-controller reinstall or patch-global call after those wrappers could overwrite wrapper layers.

This pass did not find a later explicit movement_controller.install call after 0518, but runtime/manual reload behavior should still be tested.

Current disposition:

```text
Watch only. No repair.
```

### 3. Request API remains boolean/intent-only

Install confirmation does not solve the completion-contract problem. It only confirms the canonical API exists.

The top repair family remains:

```text
movement contract diagnostics + caller failure/timeout handling
```

## Current Stage 5 decision

No code repair from this pass.

The high-priority unresolved install question is resolved:

```text
movement_controller install path is confirmed.
```

Updated priority ranking:

```text
1. 0527/0528 machine logistics / known-source fetch stale-state cleanup.
2. 0513 direct acquisition deposit/gathered_units correctness.
3. Movement completion/status contract across movement-dependent executors.
4. Movement request failure handling in callers that report moving after false.
5. 0514 emergency production returning/deposit-block diagnostics.
6. 0516 repair movement failure/reservation release refinement.
7. 0515 consecration movement failure/cooldown-claim refinement.
8. 0517 low-priority direct-call abort symmetry and cluster-release refinement.
9. construction movement failure/timeout and optional site reservation refinement.
10. generated legacy direct command reachability only after wrapper/load-order coverage is verified.
```

## Recommended next audit target

Return to Stage 5 dead-end state planning with the install uncertainty removed.

Most useful next audit step:

```text
Summarize Stage 5 findings into a repair backlog checkpoint.
```

That backlog should divide findings into:

```text
safe small repair candidates
coordinated repair families
diagnostic-only watch items
lower-priority cleanup/refinement
```

No version bump until a repair batch is ready for packaging/testing.
