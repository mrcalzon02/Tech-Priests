# Stage 4 Decision — Recovery Wrapper Boundary 0506/0508

This checkpoint records the manual review of the two late recovery wrappers that likely sit at the final `ensure_pair_priest` / `respawn_pair_priest` ownership boundary:

```text
scripts/core/mobility_recovery_contract_0506.lua
scripts/core/movement_recovery_authority_0508.lua
```

This is documentation-only. No runtime behavior has been changed by this note.

## Plain-English result

The late recovery stack is intentionally protective. The main concern going into this pass was that recovery might still yank or replace valid working priests. The source review shows that 0506 and especially 0508 were written specifically to prevent that.

The current doctrine is:

```text
0503 reopens controlled recovery after the lifecycle seal.
0506 dampens that recovery so valid same-surface priests are allowed to travel.
0508 supersedes 0506 and becomes the final movement/recovery boundary.
0508 suppresses teleport/respawn for valid same-surface priests.
0508 lets previous recovery layers run only for missing or cross-surface priests.
```

## 0506 review — `mobility_recovery_contract_0506.lua`

### Intent

The file header states that 0.1.503–0.1.505 recovery proved too aggressive, so valid priests must be allowed to travel to work targets. It explicitly says recovery may rebind/respawn invalid or cross-surface priests, but must not teleport a valid same-surface priest merely because a legacy caller passed `force_recall` or `immediate`.

### Important behavior

0506 does the following:

- Repairs reverse station/priest maps for valid pairs.
- Clears recall pressure fields:
  - `recalling`
  - `pending_recall`
  - `force_recall`
  - `stuck_since`
  - `last_stuck_tick`
  - `stuck_recall_pending`
  - `recall_requested`
- Unpauses missing-priest orders when a valid priest exists.
- Wraps `ensure_pair_priest`.
- Wraps `respawn_pair_priest`.
- Suppresses recall/teleport/respawn for valid same-surface priests.
- Allows different-surface or invalid-priest cases to fall through to the previous recovery layer.
- Routes direct acquisition into physical movement travel instead of station-side remote mining.
- Uses broker/registry/direct fallback order for its service loop.

### Disposition

0506 is not the likely current vanish cause. It is a protective dampener. However, it is superseded by 0508 in the current recovered source.

## 0508 review — `movement_recovery_authority_0508.lua`

### Intent

The file header says recovery is no longer a movement owner. It states that 0.1.503 restored useful missing-priest rescue, but also restored recall teleports during ordinary movement and direct acquisition. 0508 makes the contract explicit:

```text
valid same-surface priests are passively validated only;
missing/cross-surface priests may still use the recovery chain;
direct acquisition requests a movement lease and waits for adjacency;
remote-mining blockers become diagnostics rather than an executor loop.
```

### Important behavior

0508 does the following:

- Repairs reverse maps for valid pairs.
- Keeps valid priests non-destructible and active.
- Clears recall/missing-priest pressure fields.
- Unpauses missing-priest orders.
- Defines `M.passive_valid_pair(pair, reason)` as the valid-priest path.
- Wraps `_G.ensure_pair_priest`.
- Wraps `_G.respawn_pair_priest`.
- For valid same-surface pairs:
  - does passive validation,
  - records suppressed teleport/respawn attempts,
  - returns true without calling replacement recovery.
- For invalid or cross-surface pairs:
  - calls the previous wrapper with forced recall/immediate suppressed where applicable.
- Wraps `TechPriestsPriestRecoverySafety0503` directly:
  - `rec.ensure_pair_priest` becomes passive for valid same-surface pairs,
  - `rec.service_pair` becomes passive for valid same-surface pairs,
  - `rec.service_all` runs through the passivized service pair.
- Disables 0506 through its root:
  - `r.enabled = false`, because 0508 supersedes 0506 in this branch.
- Registers its service through the runtime event registry when available, with direct fallback only if the registry is unavailable.

### Disposition

0508 is the likely final owner of `ensure_pair_priest` and `respawn_pair_priest`, and it appears to implement the desired boundary: valid same-surface priests should not be teleported or respawned by recovery.

## Direct answers to the Stage 4 recovery-wrapper questions

### 1. Does 0508 call previous wrappers, or replace them completely?

0508 wraps the previous globals and stores them in:

```text
TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST
TECH_PRIESTS_0508_PRE_RESPAWN_PAIR_PRIEST
```

It calls previous wrappers only for cases that are not valid same-surface pairs. Valid same-surface pairs return through passive validation.

### 2. Does 0508 suppress recall for valid same-surface working priests?

Yes. Its `ensure_pair_priest` wrapper checks `same_surface(pair)` and returns after `M.passive_valid_pair(...)`. It records `valid-priest-teleport-suppressed-0508` when a caller tried `force_recall` or `immediate`.

### 3. Does 0506 protect valid travel/work from being treated as missing-priest recovery?

Yes. 0506 wraps `ensure_pair_priest` and `respawn_pair_priest` to suppress teleport/respawn for valid same-surface priests, clears recall pressure, and allows physical direct travel. In current source, 0508 then supersedes 0506.

### 4. Can 0503 still create replacement priests underneath 0508?

Only for missing or cross-surface cases, assuming 0508 is installed and enabled. 0508 directly wraps/passivizes `TechPriestsPriestRecoverySafety0503` so valid same-surface `0503` service calls become passive validation instead of create/teleport recovery.

### 5. Is there an obvious tiny safe lifecycle repair now?

No behavior repair yet.

The source is already arranged to avoid valid-priest recovery yanks. The remaining possible tiny hardening item is not a behavior-path migration; it is a safety hardening candidate:

```text
0503 mobility-swap fallback direct destroy should probably fail closed if tech_priests_destroy_priest_0500 is unavailable.
```

But even that should wait until Stage 4 live diagnostics confirm whether the seal API can ever be absent in normal load order.

## Remaining lifecycle risks

### Missing/cross-surface recovery

0508 intentionally allows previous recovery layers to act for invalid or cross-surface priests. This remains a legitimate recovery path, but it is also where replacement creation can happen.

Stage 5 should inspect:

- invalid priest but station valid,
- cross-surface priest,
- missing-priest pause fields,
- recovery-created replacement priests,
- old orphan visible priests near station,
- repeated missing-priest recovery loops.

### Direct movement command fallbacks

0506 and 0508 both prefer movement request/routing helpers, but still contain direct `set_command` fallback paths if those helpers are unavailable. These should not be removed before movement-state dead-end audit.

### 0503 mobility-swap direct destroy fallback

`priest_recovery_safety_0503.lua` uses `tech_priests_destroy_priest_0500` when available during authorized mobility swap. If that API is absent, it falls back to direct `old_priest.destroy(...)`.

This is probably unreachable in normal load order because 0500 loads before 0503. Still, it is a good future hardening candidate:

```text
If the lifecycle seal API is missing, refuse mobility-swap old-priest destruction instead of direct-destroying the old priest.
```

That candidate should be delayed until packaging/local testing because it touches visible-priest lifecycle.

## Current Stage 4 decision

Stage 4 has not found a safe behavior repair yet. It has found that the final wrapper boundary is intentional and mostly protective.

Current decision:

```text
Do not alter 0500/0501/0502/0503/0506/0508 behavior yet.
Do not remove direct recovery command fallbacks yet.
Do not migrate recovery timing yet.
Proceed to Stage 5 dead-end state audit, carrying the lifecycle findings forward.
```

## Stage 5 inputs from this review

The dead-end audit should prioritize state surfaces that can interact with lifecycle recovery:

```text
pair.recalling
pair.pending_recall
pair.force_recall
pair.stuck_since
pair.last_stuck_tick
pair.stuck_recall_pending
pair.recall_requested
pair.lost_priest_0490
pair.missing_priest_rescue_0490
pair.paused_by_missing_priest_0498
pair.paused_by_missing_priest_0500
pair.link_0495.missing_since
pair.order_queue_0469.current.status == "paused-missing-priest"
pair.active_order_0469.status == "paused-missing-priest"
pair.lifecycle_0503
pair.lifecycle_0506
pair.lifecycle_0508
pair.movement_request_0418
pair.mode == "travelling-to-direct-acquisition"
pair.mode == "travelling-to-dirt-scrape"
pair.direct_acquisition_task_0336
pair.active_acquisition_0333
pair.emergency_craft
```

## Recommended next action

Begin Stage 5 with a read-only state/dead-end scanner focused on:

- pair mode assignments,
- active task assignments and clears,
- missing-priest pause states,
- movement request fields,
- direct acquisition phases,
- order queue paused/current/pending status,
- lifecycle recall/stuck fields,
- reservation release/expiry paths.
