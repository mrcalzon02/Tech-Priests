# Station Storage-Role Remediation Status — 0.1.665

Scope: the canonical station-bound inventory steward, filtered stone caches, machine-logistics waste/retention destinations, stash creation, exact deposit accounting, and accidental priest-cargo evacuation.

## Current status

- Canonical `tech_priests_safe_deposit_item` located and replaced: **implemented**
- Exact all-or-nothing deposit planning: **implemented**
- Partial-insert rollback: **implemented**
- Filtered-cache item enforcement without ground spills: **implemented**
- Waste and retention role exclusivity: **implemented**
- General overflow stashes separated from specialized roles: **implemented**
- Machine-logistics destination priming: **implemented**
- Safe stash construction with material refund: **implemented**
- Remove-first priest cargo evacuation: **implemented**
- Waste inventories hidden from ordinary station-source lists: **implemented**
- Legacy steward/cache debug commands removed: **implemented**
- Runtime Factorio validation: **pending**

---

## Canonical storage roles

| Role | Accepted contents | Intended use |
|---|---|---|
| Station | Any valid item | Home inventory and first ordinary deposit destination |
| `filtered:<item>` | Exactly the declared item | Named stone caches such as iron ore, coal, plates, cable, gears, and sticks |
| Waste | `mechanical-detritus` and `scrap` only | Machine-maintenance waste |
| Retention | Any non-waste item | Manual machine output awaiting later use |
| General | Any valid item | Ordinary overflow and station-bound stash capacity |

A physical container may have only one specialized role. A general or previously unassigned container may be promoted to waste or retention, but a waste container cannot later become retention and vice versa.

---

## Exact atomic deposit behavior

The old inventory steward treated a deposit as successful only when one inventory could accept the entire requested stack. It could overlook valid combined capacity across several station inventories and stashes.

The replacement authority now:

1. Enumerates distinct station inventories.
2. Enumerates role-compatible nearby containers and remembered stashes.
3. Rejects filtered caches whose declared item does not match.
4. Rejects waste/retention role conflicts.
5. Calculates exact insertable capacity by bounded binary search.
6. Builds a complete deposit plan before inserting anything.
7. Creates a safe role-appropriate stash only when total existing capacity is insufficient.
8. Executes the plan only when total capacity covers the entire requested count.
9. Rolls back every insertion if any destination accepts less than planned.
10. Returns `(success, reason, exact_inserted_count)` while preserving the historical boolean first result.

This preserves compatibility with older callers that generate an output only after a true return value and prevents partial success from becoming duplication on retry.

---

## Safe stash construction

The old steward could remove a chest item or construction materials before confirming that a non-colliding placement position existed. A failed placement could therefore consume physical materials without creating storage.

The new stash builder:

1. Confirms a valid entity prototype.
2. Confirms either a physical chest item or exact construction materials are present.
3. Finds a valid placement position before removing anything.
4. Removes exact materials.
5. Creates the chest.
6. Refunds every removed material if creation fails.
7. Registers the chest with the station steward.
8. Assigns its final storage role.

Refund failure is treated as a critical diagnostic event rather than silently ignored.

---

## Filtered stone-cache remediation

The previous `stone_cache_filter_0534` steward ejected every wrong stack onto the ground and then cleared the cache slot.

The replacement path never calls `spill_item_stack`.

For each wrong stack:

1. Resolve the owning or nearest same-force Cogitator pair.
2. Remove the exact wrong-item count from the filtered cache.
3. Attempt an exact role-aware deposit elsewhere, excluding the source cache.
4. If the complete count is accepted, record the reroute.
5. If no valid capacity exists, restore the complete count to the original cache.
6. Report the blocked correction automatically.

The wrong stack may remain temporarily inside the filtered cache when no safe destination exists, but it is never deleted, duplicated, or dumped on the ground.

Full-surface cache discovery is reduced to an hourly fallback. Built-event registration and tracked-cache sweeps remain active, avoiding a complete all-surface search every 89 ticks.

---

## Machine-logistics role integration

The original 0528 module kept separate `waste_boxes` and `retention_boxes` tables but did not prevent the same container from appearing in both.

The storage-role authority now:

- synchronizes both bucket sets against the canonical role ledger,
- removes invalid and conflicting bucket entries,
- assigns one role to each selected container,
- primes a compatible remembered box before 0528 performs its local lookup,
- creates a new role-specific stash when needed,
- removes the same entity from the opposite role bucket,
- routes custody back to the Cogitator if no specialized box can safely accept it.

This preserves 0682's custody guarantees and prevents machine output from being deposited into a filtered cache or waste from becoming ordinary retained production stock.

---

## Priest cargo transfer correction

The old steward evacuation sequence was:

1. Deposit a copy of the entire priest stack into station storage.
2. Remove the stack from the priest.

A failed or partial second step could duplicate cargo.

`inventory_transfer_integrity_0687.lua` reverses that order:

1. Remove the exact physical count from the priest inventory.
2. Submit that exact count to the atomic storage authority.
3. On complete success, finalize the move.
4. On failure, restore the exact count to the same priest inventory.
5. Report any impossible restore shortfall as critical.

All steward source enumeration and periodic evacuation calls use the patched function because they resolve the table method dynamically.

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/storage_role_authority_0686.lua` | Canonical role ledger, exact atomic deposits, safe stash construction, filtered-cache recovery, machine destination specialization, role sweeps, diagnostics, and command removal |
| `tech-priests_src/scripts/core/inventory_transfer_integrity_0687.lua` | Remove-first priest cargo evacuation with exact deposit and rollback |

## Loader changes

`planning_constraints_0646.lua` now loads 0686 and 0687 after machine-logistics final authority and before final movement-vector enforcement.

The storage authority patches already-installed inventory stewardship immediately, wraps the later stone-cache installer, and wraps the later machine-logistics activation chain. No second storage executor or branch was created.

---

## Automatic diagnostics

### `PAIR-DUMP-0468 STORAGE-ROLES-0686`

Reports:

- exact deposit transaction count,
- exact items deposited,
- blocked deposits,
- atomic rollbacks,
- general/waste/retention/filtered role counts,
- role conflicts,
- filtered-cache reroutes and blocked corrections,
- role sweep coverage,
- confirmation that the replacement makes zero spill calls.

### `PAIR-DUMP-0468 INVENTORY-TRANSFER-0687`

Reports:

- priest items evacuated,
- transfer rollbacks,
- removal failures,
- critical restore shortfalls,
- recent transfer events.

---

## Runtime validation scenarios still pending

1. **Combined station capacity** — split free space across several station inventories and confirm one exact deposit uses the combined capacity.
2. **Atomic block** — provide less total capacity than requested and confirm nothing is inserted.
3. **Forced partial anomaly** — use a modded inventory that accepts less than `can_insert` predicted and confirm the transaction rolls back.
4. **Matching filtered cache** — fill station storage, deposit iron ore, and confirm an iron-ore cache may accept it.
5. **Filtered mismatch** — attempt to deposit copper into an iron-ore cache and confirm it is rejected.
6. **Legacy wrong cache item** — place a wrong item in a filtered cache and confirm it is rerouted without ground spill.
7. **Blocked cache correction** — fill every safe destination and confirm the wrong stack remains conserved in the cache.
8. **Waste exclusivity** — assign a chest as waste and confirm ordinary output cannot use it.
9. **Retention exclusivity** — assign a chest as retention and confirm detritus/scrap cannot use it.
10. **Machine bucket conflict migration** — create a save where one chest appears in both old 0528 buckets and confirm one conflicting record is removed.
11. **Role-specific stash creation** — remove suitable boxes, provide construction materials, and confirm a new waste or retention chest is built only after a valid position is found.
12. **Placement failure refund** — obstruct every build position and confirm no chest item or material is consumed.
13. **Creation failure refund** — force `create_entity` failure and confirm exact material restoration.
14. **Priest cargo success** — place items in a priest inventory and confirm exact removal followed by exact station deposit.
15. **Priest cargo blocked** — fill storage and confirm removed cargo is restored to the priest.
16. **Save/load role persistence** — save with active waste, retention, and filtered roles and confirm they remain exclusive after reload.
17. **Machine output custody** — clear normal output and waste under 0682 and confirm each reaches only its compatible role.
18. **Authority-corridor source behavior** — confirm borrowed superior supplies remain source-only while deposits stay home-local.
19. **Commandless runtime** — confirm the steward and cache-filter debug commands are absent.
20. **Performance** — verify built-event tracking plus hourly full scan removes the former all-surface 89-tick scan cost.

---

## Known follow-up risks

1. Fluid logistics still requires an independent real-fluidbox doctrine.
2. Additional machine families still need family-specific inventory semantics.
3. Direct-mining executors retain older simulated extraction behavior that should be audited separately from storage accounting.
4. External players, robots, or mods may place incompatible items into specialized boxes between sweeps; those items are conserved and rerouted, but runtime compatibility must be tested.
5. Some modded containers may expose unusual inventory behavior that violates ordinary `can_insert` expectations; the atomic rollback path exists specifically for that case.

---

## Completion estimate

- Exact storage-accounting implementation: **100%**
- Storage-role exclusivity implementation: **100%**
- Filtered-cache no-spill implementation: **100%**
- Priest transfer ordering correction: **100%**
- Static source review: completed
- External Lua parser: pending
- Factorio load test: pending
- Runtime scenarios: 0 of 20 executed

**Overall confidence: approximately 78%.**

The requested implementation work is complete. Remaining uncertainty is runtime validation, unusual modded inventories, and the explicitly separate fluid/additional-machine doctrines.

---

## Next sequential development target

Proceed to real fluid logistics for manual machines:

1. Inspect actual machine fluidbox requirements and connected pipe networks.
2. Never synthesize fluid or teleport fluid through item custody.
3. Distinguish missing fluid from insufficient throughput and blocked output fluid.
4. Reserve the machine and any selected source interface.
5. Create movement only for physical valves, barrels, or maintenance actions that a priest can legitimately perform.
6. Keep ordinary automated pipe networks outside priest control.
