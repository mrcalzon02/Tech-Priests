# Stage 4 Checkpoint — Lifecycle Global Owner Chain

This checkpoint records the interpretation of the lifecycle global owner report and the follow-up load-order check through `bootstrap_runtime.lua` and `pair_lifecycle.lua`.

This is documentation-only. No runtime behavior has been changed by this note.

## Reports and files reviewed

Primary report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.md
```

Supporting source files:

```text
scripts/core/bootstrap_runtime.lua
scripts/core/pair_lifecycle.lua
scripts/core/station_pair_recovery.lua
scripts/core/priest_lifecycle_seal_0500.lua
scripts/core/priest_recovery_safety_0503.lua
control.lua
```

## Plain-English result

The lifecycle global owner chain is layered rather than single-owner simple.

The early legacy fragments define the original globals. Then bootstrap-era modules wrap pair creation, pair removal, and respawn/state repair. Then the 0.1.500+ lifecycle/recovery stack wraps or replaces the priest recovery globals again.

The likely active doctrine is:

```text
legacy definitions
  -> 0.1.363 station pair recovery wrappers
  -> 0.1.426 pair death/respawn wrappers
  -> 0.1.500 lifecycle seal wrappers
  -> 0.1.501 vanish guard wrappers
  -> 0.1.503 recovery safety wrappers
  -> 0.1.505/0.1.506/0.1.508 behavior/mobility/movement recovery wrappers
```

The final runtime owner for each global is therefore not always the module that first defined it. It is the last successful wrapper installed in load order.

## Lifecycle global report totals

From `CODEBASE_AUDIT_STAGE4_LIFECYCLE_GLOBAL_OWNERS.md`:

- Total lifecycle global hits: `103`

Counts by global:

| Global | Count |
|---|---:|
| `ensure_pair_priest` | 44 |
| `respawn_pair_priest` | 29 |
| `create_pair` | 10 |
| `tech_priests_destroy_priest_0500` | 10 |
| `sanity_recall_all_priests` | 5 |
| `remove_pair_for_entity` | 4 |
| `tech_priests_allow_priest_station_cleanup_0500` | 1 |

Counts by kind:

| Kind | Count |
|---|---:|
| `global_call` | 44 |
| `global_assignment` | 30 |
| `function_definition` | 22 |
| `_G_call` | 7 |

## Corrected load-order interpretation

The scanner showed some `?` load-order entries because those files are not required directly by `control.lua`.

Manual follow-up:

### `station_pair_recovery.lua`

`bootstrap_runtime.lua` installs it through the 0.1.363 installer:

```text
TECH_PRIESTS_0363_INSTALL_STATION_PAIR_RECOVERY()
  -> require("scripts.core.station_pair_recovery")
```

Therefore, `station_pair_recovery.lua` is an early bootstrap wrapper, loaded before the later 0.1.500+ lifecycle/recovery stack.

### `pair_death_and_respawn.lua`

`bootstrap_runtime.lua` installs the 0.1.426 pair lifecycle facade:

```text
TECH_PRIESTS_0426_INSTALL_PAIR_LIFECYCLE()
  -> require("scripts.core.pair_lifecycle")
```

`pair_lifecycle.lua` then requires:

```text
scripts.core.pair_spawn_positions
scripts.core.pair_naming
scripts.core.pair_death_and_respawn
```

Therefore, `pair_death_and_respawn.lua` is also a bootstrap-era wrapper, loaded before the later 0.1.500+ lifecycle/recovery stack.

## Global-by-global owner-chain interpretation

### `create_pair`

Observed candidate chain:

```text
legacy generated definitions
  -> station_pair_recovery.lua wrapper
  -> priest_lifecycle_seal_0500.lua wrapper
  -> portrait_assignment_0520.lua wrapper
  -> placeholder_audio_0533.lua wrapper
```

Interpretation:

`create_pair` remains a layered compatibility global. The lifecycle seal wraps it so created priests are preserved. Later portrait/audio wrappers should be cosmetic/reporting wrappers that call through the previous function.

Risk:

- If a later wrapper fails to call the previous function, pair lifecycle setup can be bypassed.
- If the scanner order misses bootstrap order, manual validation is still required.

Current disposition:

```text
Do not change yet. Verify wrapper call-through before any create_pair repair.
```

### `remove_pair_for_entity`

Observed candidate chain:

```text
legacy generated definition
  -> station/pair lifecycle wrappers
  -> priest_lifecycle_seal_0500.lua wrapper
  -> pair_death_and_respawn.lua wrapper
```

Interpretation:

This path is especially important because station removal is the one authorized visible-priest cleanup path, while priest-triggered removal should be blocked or redirected by the lifecycle seal.

Risk:

- If a late wrapper bypasses the 0500 seal, visible-priest-triggered removal could still tear down a pair.
- If a station-cleanup window is too broad, authorized cleanup could be abused by non-station paths.

Current disposition:

```text
High-priority Stage 4 manual review. Do not patch blindly.
```

### `respawn_pair_priest`

Observed candidate chain from the report:

```text
legacy generated definitions
  -> pair_death_and_respawn.lua wrapper
  -> station_pair_recovery.lua wrapper
  -> priest_lifecycle_seal_0500.lua blocks replacement
  -> priest_vanish_guard_0501.lua wrapper
  -> priest_recovery_safety_0503.lua controlled recovery wrapper
  -> mobility_recovery_contract_0506.lua wrapper
  -> movement_recovery_authority_0508.lua wrapper
```

Likely final owner:

```text
movement_recovery_authority_0508.lua
```

The exact runtime call chain should still be tested, but by `control.lua` load order 0508 loads after 0506, 0503, and 0500.

Risk:

- Final owner may pass through to 0503 or previous wrappers, but this must be confirmed.
- Respawn/replacement is a vanish-risk path.

Current disposition:

```text
No repair yet. Inspect 0508 wrapper behavior before changing 0503 or legacy respawn.
```

### `ensure_pair_priest`

Observed candidate chain from the report:

```text
legacy generated definitions
  -> pair_death_and_respawn.lua wrapper
  -> priest_lifecycle_seal_0500.lua blocks recall/replacement
  -> priest_vanish_guard_0501.lua wrapper
  -> priest_recovery_safety_0503.lua controlled recovery wrapper
  -> behavior_execution_doctrine_0505.lua wrapper
  -> mobility_recovery_contract_0506.lua wrapper
  -> movement_recovery_authority_0508.lua wrapper
```

Likely final owner:

```text
movement_recovery_authority_0508.lua
```

Risk:

- `ensure_pair_priest` is the main surface where recall flags, missing-priest rescue, valid-priest validation, teleport recovery, and movement contracts can fight each other.
- This is a major Stage 5 dead-end/state audit input.

Current disposition:

```text
No repair yet. Inspect 0508 and 0506 wrapper behavior next.
```

### `sanity_recall_all_priests`

Observed candidate chain:

```text
legacy generated definitions
  -> priest_lifecycle_seal_0500.lua blocked wrapper
  -> priest_recovery_safety_0503.lua controlled recovery wrapper
```

Likely final owner:

```text
priest_recovery_safety_0503.lua
```

Risk:

- Debug/command-triggered recall can call `M.ensure_pair_priest(pair, force_recall ~= false, true, "sanity-recall")` for every pair.
- This can become a teleport-yank surface if valid working priests are far from station and movement contracts do not suppress recovery.

Current disposition:

```text
Audit-only. Do not remove until 0506/0508 interaction is understood.
```

### `tech_priests_destroy_priest_0500`

Observed owner:

```text
priest_lifecycle_seal_0500.lua
```

Interpretation:

This is the canonical mediated visible-priest destroy API.

Current disposition:

```text
Preserve. Any visible-priest destroy should use this API or fail closed.
```

### `tech_priests_allow_priest_station_cleanup_0500`

Observed owner:

```text
priest_lifecycle_seal_0500.lua
```

Interpretation:

This is the canonical station-cleanup authorization API.

Current disposition:

```text
Preserve. Review station cleanup windows for excessive breadth later.
```

## Current Stage 4 conclusion

Stage 4 now has enough evidence to stop treating lifecycle as a mystery blob.

The lifecycle global chain is layered, but not random:

```text
create/remove pair: legacy + bootstrap wrappers + lifecycle seal + cosmetic/reporting wrappers
respawn/ensure: legacy + seal + vanish/recovery/mobility/movement wrappers
sanity recall: legacy + seal + 0503 recovery wrapper
priest destroy/cleanup APIs: 0500 seal authority
```

The next useful audit step is not a code repair. The next useful step is a focused read of:

```text
scripts/core/mobility_recovery_contract_0506.lua
scripts/core/movement_recovery_authority_0508.lua
```

Those two likely sit at the final `ensure_pair_priest` / `respawn_pair_priest` ownership boundary and determine whether valid working priests are allowed to keep moving or are yanked back by recovery.

## Recommended next action

Inspect 0506 and 0508 manually, then record a Stage 4 recovery-wrapper decision checkpoint answering:

1. Does 0508 call previous wrappers, or replace them completely?
2. Does 0508 suppress recall for valid same-surface working priests?
3. Does 0506 protect valid travel/work from being treated as missing-priest recovery?
4. Can 0503 still create replacement priests underneath 0508?
5. Is there any obvious tiny safe repair, such as fail-closed destroy fallback hardening, or should Stage 5 begin first?
