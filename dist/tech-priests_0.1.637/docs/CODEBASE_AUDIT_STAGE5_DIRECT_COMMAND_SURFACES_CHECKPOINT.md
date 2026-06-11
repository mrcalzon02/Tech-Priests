# Stage 5 Checkpoint — Direct Command Surfaces and Ordinary Combat Ownership

This checkpoint records the Stage 5 audit of direct command surfaces and ordinary combat ownership.

This is documentation-only. No runtime behavior has been changed by this note.

## Reports and files reviewed

Generated report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DIRECT_COMMAND_SURFACES.md
tech-priests_src/docs/CODEBASE_AUDIT_STAGE5_DIRECT_COMMAND_SURFACES.json
```

Scanner:

```text
tools/audit_direct_command_surfaces.py
```

Manual source review:

```text
scripts/core/movement_controller.lua
scripts/core/acquisition_executor.lua
scripts/core/movement_enforcement_0566.lua
scripts/core/combat_safety.lua
scripts/core/combat_magos_movement_authority_0472.lua
```

## Plain-English result

The direct command report is broad and useful, but the raw count is not automatically a bug count.

The report found:

```text
363 command-related hits
187 direct-command-surface hits
127 movement-helper-call hits
25 canonical movement-controller hits
24 legacy-move-helper-call hits
```

The important interpretation is:

```text
Modern movement has a canonical owner: movement_controller.lua.
Many newer modules call movement helpers but still have direct fallback paths.
Some safety modules intentionally issue stop/home commands.
Legacy/generated modules still contain old direct command surfaces.
Ordinary combat increasingly routes through safety/proxy ownership rather than visible-priest direct attack ownership.
```

No immediate source repair is recommended from this pass. The direct-command report should be used as a prioritization map for later movement-contract repairs.

## Report counts

From `CODEBASE_AUDIT_STAGE5_DIRECT_COMMAND_SURFACES.md`:

| Kind | Count |
|---|---:|
| `direct-command-surface` | 187 |
| `movement-helper-call` | 127 |
| `canonical-movement-controller` | 25 |
| `legacy-move-helper-call` | 24 |

Top files by count:

| File | Count |
|---|---:|
| `scripts/core/movement_controller.lua` | 25 |
| `scripts/core/direct_acquisition_executor_0513.lua` | 24 |
| `scripts/core/acquisition_executor.lua` | 15 |
| `scripts/core/movement_enforcement_0566.lua` | 15 |
| `scripts/generated/control_legacy_part_012.lua` | 14 |
| `scripts/generated/control_legacy_part_016.lua` | 12 |
| `scripts/core/movement_bounds_contract_0511.lua` | 11 |
| `scripts/generated/control_legacy_part_008.lua` | 11 |
| `scripts/generated/control_legacy_part_011.lua` | 11 |
| `scripts/core/authority_corridor_pathing_0574.lua` | 9 |
| `scripts/core/behavior_execution_doctrine_0505.lua` | 9 |
| `scripts/core/behavior_stack_cleanup_0509.lua` | 9 |
| `scripts/core/emergency_production_executor_0514.lua` | 9 |

Pattern counts:

| Pattern | Count |
|---|---:|
| `tech_priests_request_movement_0418` | 93 |
| `set_command` | 85 |
| `defines.command.go_to_location` | 47 |
| `defines.command.stop` | 36 |
| `commandable.set_command` | 32 |
| `tech_priests_route_ground_command_0429` | 32 |
| `move_priest_to` | 28 |
| `defines.command.attack` | 10 |

## Canonical movement controller finding

`movement_controller.lua` owns the canonical direct engine-command boundary.

Its direct command usage is expected because it is the movement command authority. It:

- issues stop commands;
- issues go-to-location commands;
- routes ground go-to commands into movement requests;
- converts ground attack commands into combat intent/proxy-owned damage;
- allows space/platform/non-ground exceptions to fall back where needed;
- wraps `move_priest_to` so legacy move calls become movement requests.

Disposition:

```text
Do not treat movement_controller.lua direct commands as bypasses.
```

## Acquisition executor finding

`acquisition_executor.lua` is older than `direct_acquisition_executor_0513.lua`, but it has already been partially routed through modern movement helpers.

Its direct command helper `set_command_to(...)` first tries:

```text
tech_priests_request_movement_0418
```

Then fallback route:

```text
tech_priests_route_ground_command_0429
```

Then direct visible-priest command if helpers are unavailable.

Disposition:

```text
Not a pure bypass in normal loaded order.
```

Watch item:

```text
It still reports moving even if set_command_to(...) fails.
```

This is the same movement-contract issue seen across 0513/0514/0515/0516/0527/0528/construction.

## Movement enforcement finding

`movement_enforcement_0566.lua` intentionally owns a safety layer, not ordinary work behavior.

It:

- wraps movement request authority;
- rejects non-return movement outside the operating envelope;
- clears stale targets/leases;
- issues stop when rejecting bad movement;
- sends overleashed priests home through the movement request path when available;
- uses direct go-to/stop fallback only when the movement request path is unavailable or immediate stop is needed.

Disposition:

```text
Not a normal behavior bypass. Treat as safety/governor exception.
```

Watch item:

```text
Direct stop/home fallback should remain until movement contract repairs are stable.
```

## Ordinary combat ownership finding

Ordinary combat is increasingly proxy-owned and safety-gated rather than visible-character-command-owned.

### `combat_safety.lua`

This module is the friendly-fire safety gate. It blocks same-force/allied/cease-fire/neutral combat targets and wraps `issue_priest_command(...)` so unsafe attack commands are rejected.

If a blocked attack is detected, it prefers:

```text
tech_priests_route_ground_command_0429(... stop ...)
```

and only falls back to direct stop if needed.

Disposition:

```text
Healthy safety wrapper. Direct stop fallback is acceptable.
```

### `combat_magos_movement_authority_0472.lua`

This module handles Magos subordinate-area authority and point-blank combat/proxy throttling.

Its important combat command behavior is explicit:

```text
Do not let the visible character AI become a second attack/pathing owner.
The hidden proxy turret and movement controller own combat.
```

When `issue_priest_command(...)` receives a visible attack command against a valid hostile target, 0472:

- records `pair.combat_target` and `pair.target`;
- sustains/targets the proxy turret;
- returns true instead of letting visible priest AI become the attack owner.

Disposition:

```text
Ordinary combat ownership is not a raw visible-priest attack loop in this path.
```

## Remaining direct-command risk classes

### 1. Legacy/generated control parts

The generated `control_legacy_part_*.lua` files still contain direct command surfaces. They are likely partially gated/wrapped by later movement, dispatcher, combat, and safety modules.

Current disposition:

```text
Do not mass-edit generated legacy files during audit.
Use wrappers/owners to suppress or route them.
```

### 2. Older fallback executors

Files such as `acquisition_executor.lua`, `action_state_arbiter_0488.lua`, `construction_planner.lua`, and several repair/consecration/emergency modules contain fallback direct command paths.

Most now try movement helpers first. The remaining issue is not pure bypass; it is failure semantics:

```text
request failed but caller still reports moving/returning/walking.
```

Current disposition:

```text
Movement-contract repair family, not a direct-command purge.
```

### 3. Safety stop/home governors

Some direct stop/home commands are intentional safety mechanisms:

- movement enforcement;
- friendly-fire attack block;
- work clamps;
- overleash returns;
- stale target rejection.

Current disposition:

```text
Preserve until replacement contract is proven.
```

## Current Stage 5 decision

No code repair from this pass.

This audit changes the repair framing:

```text
Do not attempt a broad direct-command removal.
The safer repair is still movement-contract semantics and caller failure handling.
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
10. legacy/generated direct command surfaces after wrapper coverage is verified.
```

## Recommended next audit target

Continue Stage 5 with a narrow legacy-wrapper coverage review:

```text
Are generated legacy direct command paths actually gated by:
  single_dispatcher_0510
  movement_controller.lua route wrapper
  combat_safety.lua
  behavior_stack_cleanup_0509
  movement_enforcement_0566
```

This should avoid mass-editing generated files and instead confirm that later authority modules suppress or route the old behavior.

## Live diagnostics after packaging

Use:

```text
/tp-movement-0429
/tp-dispatcher-0510
/tp-combat-stage-0472
/tp-runtime-report
/tp-task-auspex
```

Watch for:

- visible priest direct attack/pathing ownership during combat;
- movement request absent while old executor says moving;
- far/out-of-radius movement rejected by 0566;
- repeated legacy move commands after dispatcher gate should suppress them;
- friendly-fire blocked attacks turning into stop commands.
