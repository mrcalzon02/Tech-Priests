# Machine Logistics Remediation Status — 0.1.664

Scope: the dispatcher-owned machine logistics family introduced by `logistics_machine_fulfillment_0528.lua`, its dependency on `logistics_fetch_executor_0527.lua`, its interaction with the dispatcher/action stack, and the physical custody of fuel, ingredients, machine outputs, and leftovers.

## Current status

- Physical Cogitator pickup before machine supply: **implemented**
- Exact station-to-priest-to-machine custody: **implemented**
- Partial machine-insert leftover return: **implemented**
- Orphaned output/supply custody recovery: **implemented**
- Machine target reservations: **implemented**
- Concrete leaf-task admission gate: **implemented**
- 0527 known-source handoff preserved: **implemented**
- Raw acquisition/crafting fallback preserved: **implemented**
- Machine logistics leaf truth and movement target alignment: **implemented**
- False automation proximity recovery: **implemented**
- Original no-task cooldown preserved around recovery scans: **implemented**
- Legacy machine-logistics command removed: **implemented**
- Runtime Factorio validation: **pending**

---

## Root architecture

Machine logistics remains a dispatcher wrapper rather than a free-running scheduler.

The intended chain is now:

1. A machine inside Cogitator territory is discovered as needing output removal, fuel, or an item ingredient.
2. The machine target is reserved to one station/priest pair.
3. If the needed item is already in the Cogitator, the priest first travels to the station.
4. The exact item count is physically removed from station inventory and recorded in a custody ledger.
5. The priest travels to the target machine.
6. The item is physically inserted into the machine inventory.
7. Any amount the machine cannot accept remains in custody and is physically returned to the Cogitator.
8. If the item is not in the station, 0528 expresses an exact supply request.
9. 0527 searches real known inventories or loose ground stacks and physically fetches the requested item into the Cogitator.
10. If no known physical source exists, the dispatcher may continue into raw acquisition or production.
11. Once station stock exists, the physical station-pickup and delivery chain resumes.

Machine output clearing remains:

1. Walk to the machine.
2. Remove the exact output from the machine inventory.
3. Record the item in the custody ledger.
4. Walk to retention or waste storage.
5. Insert the exact item into the destination inventory.
6. Recover the custody to storage or the Cogitator if the source machine vanishes or the task state is interrupted.

---

## Defect catalog and disposition

| # | Detected defect or risk | Status | Resolution |
|---:|---|---|---|
| 1 | Fuel and ingredients were removed from the Cogitator only after the priest reached the machine, allowing items to jump from station to machine without a source visit. | Fixed | Supply states are converted to `move-to-station-for-supply`; station inventory is physically decremented only while the priest is adjacent to the Cogitator. |
| 2 | Supply work had no persistent custody between station removal and machine insertion. | Fixed | `pair.machine_logistics_custody_0682` records item, count, kind, source machine, storage destination, and reason until final insertion or return. |
| 3 | Partial machine insertion relied on a remote fallback deposit and could lose leftovers when the fallback failed or was partial. | Fixed | Leftovers remain in custody and create an explicit return-to-Cogitator movement phase. |
| 4 | A destroyed or invalid machine could clear the task while removed output was still represented only in Lua state. | Fixed | Carried output is converted into a custody-recovery task and routed to known storage or the Cogitator. |
| 5 | A lost task table could strand already removed items. | Fixed | An orphaned custody ledger reconstructs a return-custody task automatically. |
| 6 | Multiple stations could select the same manual machine simultaneously. | Fixed | A dedicated `machine-logistics` work-reservation category now claims and renews the physical machine target. |
| 7 | 0528 was an outer dispatcher wrapper and could attempt new machine work before construction, repair, consecration, direct acquisition, or another concrete leaf was evaluated. | Fixed | New machine work is blocked by active non-machine leaf truth, active combat/repair/consecration/direct states, construction states, and stronger unrelated movement leases. Existing custody chains may finish safely. |
| 8 | A live machine task could return `false` during movement or blocked deposit and allow another dispatcher family to begin behind it. | Fixed | Any nonterminal machine task now owns the dispatcher pulse except the intentional waiting-for-source phase that must fall through to 0527/raw acquisition. |
| 9 | 0527 handoff requests could remain after machine stock was acquired or a task completed, causing repeated refetching. | Fixed | Matching `active_supply_request` and `logistic_requested_item` records are cleared at station pickup, completion, timeout, reservation denial, and abort. |
| 10 | Machine logistics did not publish a concrete leaf target, allowing overhead text, movement, and visual intent to disagree. | Fixed | Station pickup, machine delivery, machine-output collection, storage deposit, and custody return now publish explicit logistics leaf truth. |
| 11 | Generic emergency-craft text could mask an active machine delivery even though the physical leaf was machine logistics. | Fixed | The final leaf authority replaces only the generic emergency placeholder with the concrete machine leaf; direct acquisition, consecration, and 0527 fetch truth remain higher. |
| 12 | The old automation test treated any nearby belt, pipe, pump, or splitter as proof that the machine was automated. | Fixed | Recovery scanning detects actual inserter pickup/drop targets or a directly attached loader. Ambient belts and pipes no longer hide otherwise manual machines. |
| 13 | The recovery scanner could bypass the original no-machine-task cooldown. | Fixed | The final authority suppresses recovery scans while the 0528 station cooldown is active. |
| 14 | `/tp-machine-logistics-0528` preserved a command-only control surface contrary to the commandless runtime goal. | Fixed | The command is removed after the original 0528 installer runs. Automatic pair-dump diagnostics remain. |
| 15 | Fluid ingredients are not supplied by priests. | Reclassified | Fluid logistics remains intentionally outside 0528. Pipes, pumps, and fluid routing require a separate doctrine rather than item teleportation. |
| 16 | 0528 services only assemblers and furnaces. | Reclassified | This pass preserves the original bounded scope. Labs, boilers, reactors, turrets, and other machine families require separate inventory semantics and should not be folded into this executor accidentally. |
| 17 | Custody is represented in persistent task state rather than a visible priest inventory. | Reclassified with guard | The system still performs exact source removal and exact destination insertion. The custody ledger prevents duplication/loss and is recoverable, but a future visual carrier representation may be added without changing physical accounting. |

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/machine_logistics_integrity_0682.lua` | Physical station pickup, exact custody, leftover return, orphan recovery, machine reservations, admission gating, leaf truth, stale request cleanup, and command removal. |
| `tech-priests_src/scripts/core/machine_logistics_candidate_recovery_0683.lua` | Connection-aware manual-machine scanner used only when the original 0528 scanner reports no work because of broad proximity-based automation exclusion. |
| `tech-priests_src/scripts/core/machine_logistics_final_authority_0684.lua` | Preserves cooldowns, gives concrete machine work precedence over generic emergency text, removes the command again after final wrapping, and reports accurate counters. |

## Loader changes

`planning_constraints_0646.lua` now arms the machine-logistics hardeners before the final movement-vector enforcer.

The load sequence is deliberately indirect because planning constraints load before 0528:

1. 0682 requires the 0528 module without installing it and wraps `MachineLogistics0528.install`.
2. 0683 wraps `Integrity0682.activate`.
3. 0684 wraps `CandidateRecovery0683.activate`.
4. Later, the normal control loader invokes `MachineLogistics0528.install`.
5. The original 0528 dispatcher wrapper and diagnostics install first.
6. 0682 activates around `service_pair`.
7. 0683 activates outside 0682.
8. 0684 activates outside 0683.

No secondary branch or parallel executor is created.

---

## Physical invariants

The remediation enforces these invariants:

- Machine supply may not decrement station inventory unless the priest is adjacent to the station.
- Machine supply may not increment machine inventory unless the priest is adjacent to the machine.
- Removed items remain represented by one custody record until inserted or returned.
- Partial insertion never silently discards the remainder.
- A machine disappearing cannot erase carried output or supply.
- A task table disappearing cannot erase carried output or supply.
- One machine target belongs to one pair at a time.
- A concrete non-machine leaf cannot be displaced by a newly discovered machine task.
- Waiting for a source may fall through to 0527 and raw acquisition, but an active custody chain may not fall through into unrelated work.

---

## Automatic diagnostics

### Existing 0528 diagnostics

The original `PAIR-DUMP-0468 MACHINE-LOGISTICS-0528` block remains available.

### Integrity block

`PAIR-DUMP-0468 MACHINE-LOGISTICS-INTEGRITY-0682` reports:

- station-pickup routing,
- station pickup count,
- machine insert count,
- custody recovery,
- blocked custody deposits,
- admission blocks,
- reservation denials,
- per-pair phase, item, machine, custody count, and admission blocker,
- recent integrity events.

### Candidate recovery

`PAIR-DUMP-0468 MACHINE-CANDIDATE-RECOVERY-0683` reports:

- recovered manual machines,
- recovery hits and misses,
- machines skipped because a real inserter/loader connection exists.

### Final authority

`PAIR-DUMP-0468 MACHINE-LOGISTICS-FINAL-0684` reports accurate counters using the actual hyphenated event keys, plus:

- cooldown-suppressed recovery scans,
- generic emergency leaves replaced by concrete machine leaves,
- final per-pair task and custody summaries.

---

## Runtime validation scenarios still pending

1. **Station pickup required** — place fuel in the Cogitator while the priest stands beside a manual furnace; confirm the priest returns to the station before fuel reaches the furnace.
2. **Ingredient pickup required** — repeat with assembler ingredients and confirm the same two-leg trip.
3. **Known external source** — keep the needed ingredient in a nearby chest; confirm 0527 physically moves it from that chest to the Cogitator, then 0682 moves it from the Cogitator to the machine.
4. **Raw acquisition fallback** — remove all known stock and confirm the exact machine request falls through to raw acquisition/production without losing the machine reservation.
5. **Partial machine capacity** — nearly fill the machine input/fuel inventory and confirm unused carried items return physically to the Cogitator.
6. **Machine destroyed during delivery** — destroy the target after station pickup and confirm all custody returns to the station.
7. **Machine destroyed after output removal** — destroy the machine while the priest carries output and confirm the output reaches storage or emergency station recovery.
8. **Task-state loss simulation** — clear the live machine task while custody exists and confirm the orphan recovery task reconstructs automatically.
9. **Two-station contention** — let two stations discover the same manual machine and confirm only one receives the reservation.
10. **Higher-priority leaf** — start repair, consecration, construction, direct mining, or an unrelated 0527 fetch and confirm new machine work does not displace it.
11. **Waiting-source fallthrough** — confirm a waiting machine request allows 0527/raw acquisition to act but blocks unrelated machine tasks.
12. **Unrelated belt nearby** — run a belt or pipe close to a manual assembler without connecting an inserter/loader and confirm the assembler is still serviced.
13. **Connected inserter** — connect an inserter to the same assembler and confirm it is skipped as automated.
14. **Loader connection** — connect a loader directly and confirm it is skipped while an unrelated loader farther away does not hide it.
15. **Waste and retention** — clear normal output and mechanical detritus and confirm exact physical removal/deposit counts.
16. **ALT/status truth** — confirm overhead text, movement target, and visual line show station pickup, machine delivery, and storage return phases correctly.
17. **Combat interruption** — create a combat target during machine custody and confirm machine work suspends without losing the carried item, then resumes afterward.
18. **Cooldown behavior** — leave no eligible manual machines and confirm candidate recovery does not rescan every dispatcher pulse during the original cooldown.
19. **Commandless runtime** — confirm `/tp-machine-logistics-0528` is absent while automatic diagnostics remain present.
20. **Save/load custody** — save while carrying an item between station and machine, reload, and confirm exact custody resumes without duplication or loss.

---

## Known follow-up risks

These were not silently folded into 0.1.664:

1. **Waste/retention box specialization** — the original 0528 box memory can still tag a generic unautomated container for one role and later consider it for another. A dedicated storage-role authority should make waste and retained production output mutually exclusive.
2. **Fluid logistics** — item logistics must not pretend to solve fluid delivery. A future pipe/fluid doctrine should inspect real fluidbox connections and throughput.
3. **Other machine families** — labs, boilers, reactors, turrets, generators, rocket silos, and modded machines need family-specific supply semantics.
4. **Visible carried-item presentation** — custody is physically honest but invisible. A future visual-only carrier icon could show what the priest is transporting without becoming inventory authority.
5. **Automated-machine introspection** — connection-aware inserter/loader detection is safer than proximity, but unusual modded loaders and hidden transfer entities need runtime evidence.

---

## Completion estimate

### Detected 0528 integrity defects

- Core physical-accounting implementation: **100%**
- Dispatcher and reservation integration: **100%**
- Manual-machine recovery: **100%**
- Automatic diagnostics: **100%**
- Static source review: completed
- External Lua parser: pending
- Factorio load test: pending
- Runtime scenarios: 0 of 20 executed

### Overall confidence

**Approximately 76% complete.**

The implementation addresses every high-priority defect found in the initial 0528 audit. Remaining uncertainty is runtime behavior, modded-machine compatibility, and the explicitly deferred storage-role/fluid/machine-family expansions.

---

## Next sequential development target

Continue with the station inventory steward and storage-role authorities:

1. Make waste and retention destinations mutually exclusive.
2. Audit filtered stone-cache interaction with production output.
3. Audit station overflow and no-spill guarantees.
4. Verify exact item-count semantics across all `tech_priests_safe_deposit_item` callers.
5. Then proceed into fluid logistics and additional machine families as separate doctrines.
