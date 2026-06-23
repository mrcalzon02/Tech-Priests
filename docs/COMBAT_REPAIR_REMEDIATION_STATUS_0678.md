# Combat Repair Remediation Status — 0.1.662

Scope: defects and risks identified while mapping `combat_repair_doctrine_0517.lua` and its handoff to ordinary repair, reservations, ammunition, movement, the dispatcher, and the order queue.

Current implementation status:

- **20 of 20 detected combat-repair findings addressed or reclassified**
- **15 corrected through runtime hardening**
- **5 reclassified as intentional authority boundaries or low-risk design behavior**
- **0 of 10 runtime validation scenarios executed in Factorio for 0.1.662**
- Static source review completed; an external Lua parser and Factorio load test have not yet been executed for this build.

The coding phase for the detected combat-repair defects is complete. Release confidence remains below complete until the runtime scenarios at the end of this document have been exercised.

---

## Status Key

| Status | Meaning |
|---|---|
| Fixed | Corrective behavior was added in 0.1.662. |
| Reclassified | Further inspection showed the concern belongs to another authority, is intentional, or is not itself a defect. |
| Runtime verification pending | The implementation exists but still needs an in-game test and fresh diagnostics. |

---

## Detected Finding Catalog

| # | Detected finding | Status | Resolution |
|---:|---|---|---|
| 1 | Enemy detection treated any non-neutral differently named force as hostile. | Fixed | The integrity layer now prefers Factorio force diplomacy through enemy/friend/cease-fire APIs before falling back to force-name comparison. |
| 2 | Ammo, energy, or fluid alone could classify a disabled turret as cover. | Fixed | Turret cover now rejects disabled, control-disabled, unpowered, unfueled, inactive, and fluid-starved states before checking shooting target, ammunition, energy, or fluid readiness. |
| 3 | Other-priest cover did not verify combat capability. | Fixed | A nearby priest now counts as cover only when actively engaged and its hidden combat proxy has physical ammunition. |
| 4 | An active combat-repair state with an invalid target was not aborted. | Fixed | `recommend_action()` now aborts invalid active targets before any replacement target is selected. |
| 5 | Changing combat-repair targets left the previous cluster reservation behind. | Fixed | Target changes release the old cluster lease, cancel matching ordinary repair state/orders, and only then install the new target. |
| 6 | A no-target exit left old combat-repair state and reservations behind. | Fixed | No-safe-target exits now finalize the previous target, release cluster and exact-target claims, clear repair scheduling, and reset target mirrors. |
| 7 | The result of cluster reservation was not verified. | Fixed | After doctrine service, the integrity wrapper verifies that the expected cluster lease exists and belongs to the current station; missing or foreign ownership aborts the task. |
| 8 | Ordinary repair task submission was ignored. | Fixed | Combat repair now requires `submit_or_assign_repair_task()` to succeed and verifies a current, pending, or active matching repair task before proceeding. |
| 9 | Abort only partially cleared ordinary repair state. | Fixed | Abort now clears repair target identity, timers, packs, active repair tasks, matching current and pending orders, exact-target reservations, cluster leases, generic targets, and mode residue. |
| 10 | Completion left combat-repair mode and target mirrors behind. | Fixed | Completion now clears `pair.combat_repair_target_0517`, the generic wall target, repair state, task/order state, and returns the pair to combat or idle mode. |
| 11 | Completion did not verify ordinary repair cleanup. | Fixed | Combat completion explicitly performs ordinary repair scheduler and reservation cleanup even when the underlying repair executor already completed its own handoff. |
| 12 | Service events flooded combat-repair diagnostics. | Fixed | Repeated `service` entries are compacted to one per station within a sixty-tick window. |
| 13 | No-target scans flooded diagnostics. | Fixed | Repeated no-target entries are compacted and the integrity layer adds a separate `no_safe_target` counter. |
| 14 | `dispatcher_owned` existed but was not enforced. | Fixed | Dispatcher recommendation is disabled when `dispatcher_owned=false`, and dispatcher-originated service calls are rejected. |
| 15 | Search centered only on the priest and could miss defended station walls. | Fixed | Candidate discovery now uses the union of priest-centered and station-centered search areas, deduplicated by physical wall identity. |
| 16 | Cluster ownership compares station rather than priest. | Reclassified | Tech-Priests currently use one priest per Cogitator pair; cluster ownership by station is the intended tactical-spreading scope. Exact-target work reservations still identify the pair. |
| 17 | Invalid targets did not receive a target cooldown. | Reclassified | An invalid/destroyed entity cannot be physically reselected. The important requirement is releasing its reservations and stale state, which is now enforced. |
| 18 | `/tp-combat-repair-0517` violated the commandless runtime goal. | Fixed | The integrity wrapper removes the command during installation and removes it again if the original doctrine installer reruns. |
| 19 | The doctrine has no independent periodic service. | Reclassified | Combat repair is intentionally dispatcher-owned. Adding another periodic executor would create competing behavior ownership. |
| 20 | Personal-danger logic was largely redundant when cover was mandatory. | Reclassified | It remains useful when `require_cover` is disabled: uncovered repair is still refused near the priest unless the wall is critically damaged. |

---

## Files Implementing the Combat-Repair Remediation

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/combat_repair_integrity_0676.lua` | Strict diplomacy and cover checks, safe target discovery, verified task handoff, cluster ownership, full abort/completion cleanup, history compaction, dispatcher ownership, diagnostics, and command removal. |
| `tech-priests_src/scripts/core/combat_repair_terminal_cleanup_0677.lua` | Final narrow cleanup for invalid stored-unit reservations and unconditional stale mirror removal after terminal states. |
| `tech-priests_src/scripts/core/planning_constraints_0646.lua` | Installs both tactical repair hardeners after ordinary repair integrity and before final movement-vector enforcement. |
| `tech-priests_src/info.json` | Advances the mod to 0.1.662 and records tactical repair integrity. |

---

## Automatic Diagnostic Counters Added

`PAIR-DUMP-0468 COMBAT-REPAIR-INTEGRITY-0676` now reports:

- `completed`
- `aborted`
- `cluster_released`
- `submit_failed`
- `target_changed`
- `history_compacted`
- `no_safe_target`

These counters provide automatic evidence without requiring the removed combat-repair slash command.

---

## Runtime Validation Scenarios Still Pending

1. **Defended wall repair** — damage a wall under enemy pressure with an armed allied turret covering it and confirm combat repair starts.
2. **Disabled turret rejection** — disable or control-disable the only turret and confirm the priest remains in combat rather than kneeling to repair.
3. **Allied-force diplomacy** — place units from a friendly differently named force near the wall and confirm they are not counted as enemies.
4. **Other-priest cover** — confirm a nearby combat-ready priest with loaded proxy ammunition counts as cover, while an unarmed priest does not.
5. **Cover loss during repair** — remove ammunition, power, or the covering priest and confirm tactical repair aborts immediately and ordinary repair cannot continue independently.
6. **Target destroyed during repair** — destroy the wall and confirm cluster/exact reservations, repair state, orders, targets, and mode are cleared.
7. **Target change** — create two eligible wall clusters and change tactical priority; confirm the old cluster lease and repair order are removed before the new target is installed.
8. **Two-station cluster contention** — allow two stations to reach the same wall cluster and confirm only one owns that cluster while the other selects different work.
9. **Successful completion handoff** — fully repair the wall and confirm target cooldown, order history, pending-order promotion, target clearing, and return to combat/idle.
10. **Commandless runtime** — confirm `/tp-combat-repair-0517` is absent while automatic pair-dump counters remain present.

---

## Completion Estimate

### Detected combat-repair defects

- **Implementation:** 100% — 20/20 addressed or reclassified.
- **Source review:** complete.
- **External Lua parser validation:** pending.
- **Factorio load/runtime validation:** 0% — 0/10 scenarios executed against 0.1.662.

### Overall combat-repair remediation confidence

**Approximately 78% complete.**

The remaining work is runtime loading, scenario execution, fresh diagnostic/log review, and correction of any new defects exposed by those tests. No additional known combat-repair coding defect remains open in the present catalog.

---

## Next Sequential Development Target

With the directly dispatcher-owned families now mapped and hardened, the next sequential branch is:

1. `machine_logistics_0528` modules and their relationship to the action arbiter’s broad `acquisition` family.
2. Inventory steward and station catalog authority.
3. Emergency facility doctrine internals.
4. Legacy combat behavior.
5. Idle and conversation behavior.
