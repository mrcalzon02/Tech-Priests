# Repair Executor Remediation Status — 0.1.661

Scope: defects and risks identified while mapping `repair_executor_0516.lua` and its connected scheduling, reservation, movement, inventory, and queue authorities.

Current implementation status:

- **21 of 21 detected repair findings addressed or reclassified**
- **15 corrected through runtime hardening**
- **6 reclassified after inspecting the shared authorities**
- **0 of 8 runtime validation scenarios executed in Factorio for 0.1.661**
- Static Lua parse of the final `repair_executor_integrity_0673.lua`: **passed**

The coding phase for the detected ordinary-repair defects is complete. Release confidence remains below complete until the runtime scenarios at the end of this document have been exercised.

---

## Status Key

| Status | Meaning |
|---|---|
| Fixed | Corrective runtime behavior was added in 0.1.660–0.1.661. |
| Reclassified | Further inspection showed the original concern was already handled by a connected authority or was expected scheduler timing rather than a defect. |
| Runtime verification pending | The implementation exists but still needs an in-game test and fresh diagnostics. |

---

## Detected Finding Catalog

| # | Detected finding | Status | Resolution |
|---:|---|---|---|
| 1 | Repair executor appeared to have no direct surface-scan fallback. | Reclassified | `work_queue_authority.discover_repair_near()` already falls through scan routing, the efficiency index, and finally a direct surface scan. The executor correctly delegates discovery rather than duplicating it. |
| 2 | Work-queue claim followed by repair reservation appeared to be conflicting double ownership. | Reclassified | Both paths use `work_reservations`. A second claim from the same pair renews the lease rather than conflicting with itself. |
| 3 | Local target cooldown was bypassed because executor eligibility calls used `allow_reserved=true`. | Fixed | The integrity wrapper checks the executor cooldown table before invoking the original service and terminates stale/cooldown repair orders cleanly. |
| 4 | Local reservation filtering was bypassed during eligibility. | Reclassified | Candidate exclusion is enforced by `work_queue_authority.claim_nearest()` through shared `work_reservations`; final ownership is enforced again by `reserve_target()`. The integrity wrapper now guarantees release on blocked exits. |
| 5 | Invalid or replaced targets could retain old reservations. | Fixed | The integrity wrapper releases shared and fallback reservations before clearing invalid state. It can also release by stored target unit when the LuaEntity reference is already invalid. |
| 6 | A target remained reserved when the station had no repair pack after selection. | Fixed | `no-repair-pack` exits now release the target, clear target/timer residue, and clear the generic pair target. |
| 7 | A target remained reserved when repair-pack consumption failed. | Fixed | `consume-failed` exits now release the reservation and clear the repair state. |
| 8 | A successful `pcall(move_priest_to)` could be treated as movement success even when the function returned false. | Fixed | Reported walk success is accepted only when the active movement request points at the physical repair target and is owned by repair or leaf truth. |
| 9 | The already-full completion path left `state.target`, timers, and pack counters behind. | Fixed | Completion now clears the complete target identity, timers, pack count, damage values, and active repair task fields. |
| 10 | Failure paths retained stale targets and due ticks. | Fixed | Terminal and blocked exits clear target identity, timing, distance, health, and per-target integrity fields. A target change also resets its timer before service. |
| 11 | Repair-pack consumption could be counted even if writing target health failed. | Fixed | The wrapper compares health and pack count across the service call. When a pack was charged without health increasing, it refunds through station steward inventories or physically spills the pack beside the station. |
| 12 | `full_repair` was configured but unused. | Fixed | `full_repair=false` now ends the assignment after one successfully applied repair pack and applies normal cleanup/cooldown/order handoff. |
| 13 | `score_target()` was unused in the executor. | Reclassified | Target scoring is owned by `work_queue_authority.repair_priority()`, which implements the same damage ratio, missing health, class urgency, and distance policy before the executor claims work. |
| 14 | Blocked phases remained active indefinitely. | Fixed | The hardened `M.active()` recognizes only real walk/repair work or an actual repair order. Cooldown, no-target, need-item, invalid, reserved, movement-failed, health-write-failed, and executor-error phases are terminal/inactive. |
| 15 | Completing a repair order bypassed queue history and immediate promotion. | Fixed | Completion appends a bounded order history record, clears the matching order, removes active repair tasks, and immediately calls the order queue tick to promote the next order. |
| 16 | Scheduler assignment and queue-submission results were ignored. | Fixed | Submission now verifies that a current order, pending order, or active repair task actually exists. Missing state is reconstructed and logged as a submission recovery. |
| 17 | Walk, progress, no-target, and supply events could flood the recent-history buffer. | Fixed | Repeated noisy entries for the same station/action are compacted to one entry per sixty-tick window. A compaction counter is included in automatic diagnostics. |
| 18 | Fallback repair-pack access used one arbitrary station inventory. | Fixed | Repair-pack count, removal, and refund now aggregate `tech_priests_inventory_steward_sources_for_pair()` inventories, with the legacy station inventory retained only as a deduplicated fallback source. |
| 19 | A 29-tick service cadence could not apply a pack at exactly the 45-tick timer. | Reclassified | The timer is a minimum work duration. The next scheduled service applies the pack after the deadline; exact-frame application is not required for simulation correctness. Dispatcher calls may also service the pair between bucket pulses. |
| 20 | There was no direct `script.on_nth_tick` fallback in the executor installer. | Reclassified | Runtime broker and runtime event registry are the established scheduling authorities. A direct script fallback inside this executor would create another competing scheduler path. |
| 21 | `/tp-repair-executor-0516` violated the commandless runtime goal. | Fixed | The integrity hardener removes the command during installation and removes it again whenever the original executor installer reruns. |

---

## Files Implementing the Repair Remediation

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/repair_executor_integrity_0673.lua` | Runtime integrity wrapper for repair state, physical inventory, movement truth, health verification, task submission, diagnostics compaction, and order completion. |
| `tech-priests_src/scripts/core/planning_constraints_0646.lua` | Installs the repair integrity hardener in the established late-hardener chain. |
| `tech-priests_src/info.json` | Advances the mod to 0.1.661 and records completed repair remediation. |

---

## Automatic Diagnostic Counters Added

`PAIR-DUMP-0468 REPAIR-INTEGRITY-0673` now reports:

- `completed`
- `released`
- `false_move`
- `health_fail`
- `submit_recovered`
- `steward_removed`
- `steward_refunded`
- `history_compacted`

These counters provide automatic evidence without requiring repair-specific slash commands.

---

## Runtime Validation Scenarios Still Pending

The implementation is complete, but the following eight scenarios should be tested in Factorio before the repair branch is considered release-verified:

1. **Primary station inventory repair** — put repair packs in the normal station inventory, damage a nearby machine, and confirm one pack is consumed per repair interval.
2. **Steward-only repair pack** — place repair packs only in a steward-managed cache or secondary station source and confirm the priest can discover and consume them.
3. **Two-priest contention** — give two priests access to the same damaged target and confirm only one walks toward and repairs it while the other selects separate work or remains available.
4. **Supply loss after reservation** — remove the last repair pack after the target is selected and confirm the target reservation is released immediately.
5. **Movement truth** — obstruct or reject movement and confirm the executor does not report `walk-to-target` without a matching repair movement request.
6. **Health-write accounting** — confirm every consumed pack produces a positive health increase; induce an invalid/destroyed-target edge case and verify pack refund or physical spill.
7. **Single-pack mode** — set persisted `full_repair=false` and confirm the assignment ends after one pack rather than continuing to full health.
8. **Queue handoff** — queue repair work behind another order and confirm repair completion immediately promotes the next pending order with history preserved.

---

## Completion Estimate

### Detected repair defects

- **Implementation:** 100% — 21/21 addressed or reclassified.
- **Static syntax validation:** 100% — final hardener parsed successfully.
- **Runtime validation:** 0% — 0/8 scenarios have been run against 0.1.661.

### Overall repair-remediation confidence

**Approximately 80% complete.**

The remaining twenty percent is not additional known code repair. It is runtime verification, log review, and correction of any new defects exposed by those eight tests.

Once all eight scenarios pass without new evidence, the ordinary repair branch can be marked complete and development can proceed to the combat-repair defect catalog.
