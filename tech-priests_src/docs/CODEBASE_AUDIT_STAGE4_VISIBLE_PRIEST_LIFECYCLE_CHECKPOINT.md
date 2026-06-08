# Stage 4 Checkpoint — Visible Priest Lifecycle Operation Sites

This checkpoint records the interpretation of the strict visible-priest lifecycle operation-site report.

This is documentation-only. No runtime behavior has been changed by this note.

## Reports reviewed

Broad lifecycle report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_LIFECYCLE_DESTRUCTION_REPORT.md
```

Second-pass visible-priest text report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE.md
```

Strict visible-priest operation-site report:

```text
tech-priests_src/docs/CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.md
```

## Plain-English result

The broad scanner was useful for recall but too noisy. The strict third-pass report is now good enough for Stage 4 triage.

The most important conclusion is:

```text
The active lifecycle doctrine is not simply "0500 blocks everything."
The real active doctrine is:

0500 blocks arbitrary priest destruction,
0501/0502 guard against vanish/direct-acquisition failures,
0503 deliberately reopens controlled recovery, teleport/recall, and authorized mobility replacement.
```

That means Stage 4 should not delete recovery modules blindly. It should verify whether the controlled recovery paths are safe and whether their windows can still create replacement churn, teleport yanks, or old-priest swap hazards.

## Strict operation-site totals

From `CODEBASE_AUDIT_STAGE4_VISIBLE_PRIEST_LIFECYCLE_SITES.md`:

- Visible-priest lifecycle operation sites: `256`

Counts by classification:

| Classification | Count |
|---|---:|
| `recall-respawn-operation-review` | 78 |
| `direct-visible-priest-destroy-review` | 55 |
| `canonical-lifecycle-seal-operation` | 25 |
| `pair-map-lifecycle-operation` | 21 |
| `recovery-visible-priest-operation` | 19 |
| `visible-priest-create-review` | 15 |
| `lifecycle-seal-api-reference` | 14 |
| `seal-blocked-recall-respawn-operation` | 11 |
| `seal-mediated-priest-destroy` | 10 |
| `recovery-visible-priest-create` | 4 |
| `station-cleanup-visible-priest-destroy-review` | 4 |

Counts by kind:

| Kind | Count |
|---|---:|
| `destroy_call` | 73 |
| `ensure_pair_priest` | 61 |
| `respawn_pair_priest` | 46 |
| `create_entity` | 19 |
| `create_pair` | 19 |
| `lifecycle_destroy_api` | 18 |
| `remove_pair_for_entity` | 10 |
| `sanity_recall_all_priests` | 7 |
| `lifecycle_allow_cleanup_api` | 3 |

## Important correction about destroy rows

The strict report still over-labels many destroy rows as `direct-visible-priest-destroy-review` because priest context appears nearby in the file. Manual review shows many of these are not visible-priest destroys. Examples include:

- GUI frame destroy calls.
- sprite/rendering object destroy calls.
- proxy turret destroy calls.
- ground item / item-on-ground destroy calls.
- requester/cache/sink cleanup calls.
- generic visual object cleanup helpers.

Current decision:

```text
Do not patch destroy calls merely because the scanner flagged them.
Prioritize destroy rows that explicitly destroy pair.priest, old_priest, priest, or tech-priest entities.
```

## Confirmed canonical lifecycle seal behavior

File:

```text
scripts/core/priest_lifecycle_seal_0500.lua
```

Confirmed behavior:

- Keeps visible priests non-destructible.
- Records lifecycle evidence.
- Blocks direct priest destruction except for station cleanup windows.
- Wraps `create_pair` so created priests are immediately preserved.
- Wraps `remove_pair_for_entity` so priest-triggered pair removal is blocked while station-triggered cleanup is allowed.
- Wraps `respawn_pair_priest`, `ensure_pair_priest`, and `sanity_recall_all_priests` to block respawn/replacement while vanish source is under audit.
- Observes priest removal events through the runtime event registry.
- Provides debug command `/tp-priest-lifecycle-0500`.

Disposition:

```text
Keep. This is the current hard protective seal.
```

## Confirmed recovery safety behavior

File:

```text
scripts/core/priest_recovery_safety_0503.lua
```

Confirmed behavior:

- Loaded after 0500/0501/0502.
- Restores watchdog roots.
- Restores missing-priest rescue and recall/teleport recovery.
- Rebinds a nearby orphan priest before creating a new priest.
- Creates a replacement priest if missing and no nearby priest can be rebound.
- Teleports valid far/recalling priests back to station.
- Restores `respawn_pair_priest`, `ensure_pair_priest`, and `sanity_recall_all_priests` globals to controlled recovery wrappers.
- Performs authorized belt-immunity mobility swaps by creating a new desired priest type and destroying the old priest through the lifecycle seal when possible.
- Directly registers `script.on_nth_tick(M.tick_interval, M.service_all)` rather than using the event registry/broker.

Disposition:

```text
Intentional controlled recovery layer, but high-risk enough to require focused Stage 4/5 review.
```

## Load order finding

In `control.lua`, the lifecycle/recovery sequence is:

```text
0.1.499 priest_lifecycle_authority_0499
0.1.500 priest_lifecycle_seal_0500
0.1.501 priest_vanish_guard_0501
0.1.502/0.1.504 priest_vanish_guard_0502
0.1.503 priest_recovery_safety_0503
0.1.505 behavior_execution_doctrine_0505
0.1.506 mobility_recovery_contract_0506
0.1.508 movement_recovery_authority_0508
0.1.509 behavior_stack_cleanup_0509
0.1.510 single_dispatcher_0510
```

Interpretation:

`0503` is not an accidental duplicate loaded before the seal. It deliberately reopens recovery after the seal and vanish guards.

## Current real Stage 4 hotspots

The useful hotspot list is now:

```text
scripts/core/priest_lifecycle_seal_0500.lua
scripts/core/priest_recovery_safety_0503.lua
scripts/core/priest_vanish_guard_0501.lua
scripts/core/priest_vanish_guard_0502.lua
scripts/core/pair_death_and_respawn.lua
scripts/core/station_pair_recovery.lua
scripts/core/pair_link_hardening_0495.lua
scripts/core/mobility_recovery_contract_0506.lua
scripts/core/movement_recovery_authority_0508.lua
scripts/generated/control_legacy_part_001.lua
scripts/generated/control_legacy_part_002.lua
scripts/generated/control_legacy_part_006.lua
scripts/generated/control_legacy_part_011.lua
scripts/generated/control_legacy_part_020.lua
```

## Current risk questions

### 1. Can 0503 replacement create churn?

`0503` can create a new priest if `pair.priest` is invalid and nearby rebind fails. Need to verify:

- How often `pair.priest` can become invalid.
- Whether the same missing pair can create repeated replacements.
- Whether `next_allowed_priest_respawn_tick` or similar throttles are respected or cleared.
- Whether old invalid priests are ever left as orphans.

### 2. Can teleport recovery yank valid working priests?

`0503.ensure_pair_priest(...)` teleports valid priests if recall/immediate flags are set or distance exceeds `M.teleport_distance_sq`. Need to verify:

- Which callers pass `force_recall=true` or `immediate=true`.
- Whether valid far-away priests doing legitimate work are protected by 0506/0508 movement contracts.
- Whether stage order prevents recovery from fighting dispatcher movement.

### 3. Can authorized mobility swap bypass the seal?

`0503.safe_destroy_old_for_mobility(...)` uses `tech_priests_destroy_priest_0500` when available, otherwise falls back to direct `old_priest.destroy(...)`.

Need to verify:

- Whether the fallback direct destroy path can ever run in normal load order.
- Whether fallback should be kept for compatibility or hardened to fail closed if the seal API is absent.

### 4. Are legacy respawn definitions still reachable?

Generated legacy fragments still contain `respawn_pair_priest` and `ensure_pair_priest` definitions/calls. Later wrappers should replace or gate them, but Stage 4 needs to verify final global ownership after all installs.

Need to verify:

- Final owner of `_G.respawn_pair_priest`.
- Final owner of `_G.ensure_pair_priest`.
- Final owner of `_G.sanity_recall_all_priests`.
- Whether diagnostics expose that final owner clearly.

### 5. Are direct nth-tick recovery services bypassing broker diagnostics?

`0503.install()` directly calls:

```lua
script.on_nth_tick(M.tick_interval, M.service_all)
```

Need to verify whether this is intentional or should be converted to registry/broker discovery after Stage 4. This is not a behavior repair yet because changing recovery timing could affect vanish protection.

## Decision: no lifecycle repair yet

There is no tiny safe lifecycle repair yet. The next step is targeted ownership instrumentation/documentation, not changing recovery behavior.

Current decision:

```text
Do not alter 0500, 0501, 0502, 0503, 0506, or 0508 behavior yet.
Do not delete direct respawn/ensure/teleport logic yet.
Do not remove direct nth-tick from 0503 yet.
First determine final global owners and whether runtime diagnostics expose lifecycle/recovery state clearly enough for local testing.
```

## Recommended next step

Add a small read-only lifecycle owner scanner/report or diagnostic note that answers:

```text
Who finally owns _G.respawn_pair_priest?
Who finally owns _G.ensure_pair_priest?
Who finally owns _G.sanity_recall_all_priests?
Who finally owns _G.create_pair?
Who finally owns _G.remove_pair_for_entity?
Which modules patch each global, and in what load order?
```

After that, decide whether the next repair is:

1. documentation/diagnostics only,
2. require/registry discovery hardening for 0503's nth-tick route,
3. fail-closed hardening for 0503's mobility-swap fallback destroy path,
4. or Stage 5 dead-end state audit.
