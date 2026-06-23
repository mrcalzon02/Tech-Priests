# Physical Laboratory, Turret, and Proxy Logistics Status — 0.1.671

Scope: item-only service for the paired hidden proxy weapon, visible ammunition turrets, and visible laboratories. These families reuse station-bound physical custody without being treated as assemblers or furnaces.

## Current status

- Hidden proxy remote-ammunition teleport removed: **implemented**
- Exact home-local source selection: **implemented**
- Physical source visit before removal: **implemented**
- Persistent item custody: **implemented**
- Exact destination visit and insertion: **implemented**
- Partial insertion leftover return: **implemented**
- Orphaned custody recovery: **implemented**
- Visible turret target reservations: **implemented**
- Laboratory target reservations: **implemented**
- Connected inserter/loader automation exclusion: **implemented**
- Target-compatible ammunition selection: **implemented**
- Current-research science-pack selection: **implemented**
- Research-change cancellation/return: **implemented**
- Exact missing-item request handoff: **implemented**
- Concrete leaf truth and movement target: **implemented**
- Legacy proxy-ammo command removal: **implemented**
- Runtime Factorio validation: **pending**

---

## Physical transfer invariant

Every successful family transfer follows this sequence:

1. Identify one exact destination inventory.
2. Select one exact home-local station or stash inventory containing the required item.
3. Move the priest to that physical source entity.
4. Remove the exact item count from that exact inventory.
5. Record the count in `pair.item_family_custody_0702`.
6. Move the priest to the exact proxy, turret, or laboratory.
7. Insert the exact accepted count.
8. Return every unaccepted item to its original source or the Cogitator.
9. Clear custody only after complete insertion or complete return.

The executor performs no station removal while the priest is elsewhere and never deposits a copy before removing the source item.

---

## Home-local source rule

Family logistics uses only station-bound sources belonging to the pair's own Cogitator territory.

Sources are rejected when:

- they are on another surface,
- they belong to another force,
- they are outside the station service radius,
- authority-corridor metadata identifies a different source station,
- the inventory cannot physically provide the item,
- the destination inventory cannot accept the item.

Superior stations may still support sanctioned work through their existing authority-corridor doctrine, but this family executor does not remotely remove ammunition or science packs from them.

---

## Hidden proxy ammunition

The earlier proxy hardener could remove ammunition from station storage and insert it into the hidden weapon immediately, regardless of priest distance.

`item_family_logistics_0702.lua` replaces that load method with a physical task:

1. Ensure the paired proxy exists.
2. Confirm the proxy ammunition inventory is empty.
3. Select compatible ammunition from a home-local physical source.
4. Walk to and remove the ammunition from that source.
5. Deliver it to the proxy inventory.

Because the proxy is paired with the priest, delivery usually completes beside the priest after source pickup, but the destination insertion still occurs only after physical source removal and a live custody record.

An empty proxy remains the highest-priority family candidate. It may begin during combat, but it does not displace an existing direct-acquisition, construction, machine-custody, repair, consecration, or concrete leaf task.

---

## Visible ammunition turrets

The scanner considers only entities of type `ammo-turret` inside the Cogitator service area.

A turret is skipped when:

- it is the paired hidden proxy,
- an inserter or loader is actually connected to it,
- its ammunition inventory is unavailable,
- it already contains the configured target count,
- another pair holds the shared machine-logistics reservation.

Ammunition is selected by actual `can_insert` compatibility with that exact turret inventory. Preferred base magazines are uranium, piercing, and firearm magazines, followed by a deterministic scan of other compatible ammunition prototypes.

The integrity guard never changes the identity of carried ammunition. If a target becomes incompatible after pickup, the original ammunition is physically returned.

---

## Laboratory science packs

A visible laboratory is considered only when:

- it is inside the station service area,
- no inserter or loader is actually connected,
- the force has a current research technology,
- that technology exposes item research ingredients,
- the laboratory input inventory accepts the ingredient,
- the current count is below the configured five-cycle target,
- another pair does not hold its reservation.

The executor supplies one missing pack type per trip. Repeated trips can balance every required pack without treating a laboratory as a generic assembler.

The task records the current research name. If research changes before pickup, the stale task is cancelled and its reservation/request is released. If research changes after pickup, the carried packs are returned physically rather than inserted into the laboratory merely because the inventory might accept them.

---

## Missing-item handoff

When no home-local source contains the selected ammunition or science pack, the family task writes:

- exact item,
- exact requested count,
- family purpose,
- destination entity identity,
- source `item-family-logistics-0702`.

The existing chain may then:

1. Find a real known inventory through 0527.
2. Physically fetch the item into the Cogitator.
3. Fall through to acquisition or production if no known source exists.
4. Resume the family task by walking to the newly stocked physical source.

The destination reservation remains live while waiting and expires before the source timeout can become indefinite.

---

## Custody recovery

The persistent custody ledger stores:

- family,
- item and exact count,
- destination identity,
- original source entity and label,
- current reason/phase.

If the task table disappears while custody exists, a return-custody task is reconstructed automatically.

If the destination disappears or loses its inventory, custody returns to the original source. When that source is unavailable or full, the priest returns to the Cogitator and uses the exact role-aware storage authority.

No item is spilled as a normal recovery path.

---

## Admission and priority

Family work does not begin behind:

- active assembler/furnace machine logistics,
- machine custody,
- construction or fluid pipe construction,
- direct acquisition,
- repair,
- combat repair,
- consecration,
- another recent concrete leaf task.

Visible turret and laboratory work also defer to combat. Proxy ammunition is the only family allowed to begin while a combat target exists, because the proxy is the priest's own weapon.

An already-carried visible-turret or lab task suspends during combat without losing custody.

---

## Leaf truth

Family travel publishes:

- `collect-family-item`,
- `deliver-family-item`,
- `return-family-custody`.

The overhead label, movement destination, visual line, and `pair.target` therefore identify the exact physical source or destination rather than the broad parent goal.

Existing higher-priority direct acquisition, consecration, or 0527 fetch truth remains authoritative when present.

---

## Files added

| File | Role |
|---|---|
| `tech-priests_src/scripts/core/item_family_logistics_0702.lua` | Physical candidate selection, source visit, custody, delivery, return, reservations, item requests, proxy-loader replacement, leaf truth, diagnostics |
| `tech-priests_src/scripts/core/item_family_integrity_0703.lua` | Exact target-compatible ammunition, stale research handling, incompatible carried-ammo return, legacy command removal |

## Loader order

`planning_constraints_0646.lua` installs 0702 and 0703 after fluid-route integrity and before final movement-vector enforcement.

The proxy hardener remains the authority that creates and preserves the hidden proxy. Its loading method is replaced, not duplicated. Family logistics has one broker service and uses the existing movement, reservation, fetch, production, storage, and leaf-truth authorities.

---

## Automatic diagnostics

### `PAIR-DUMP-0468 ITEM-FAMILY-LOGISTICS-0702`

Reports:

- exact missing-item requests,
- physical pickups,
- delivered item count,
- orphaned custody recovery,
- per-pair family, phase, item, destination, and custody,
- `remote_station_removals=0`,
- `deposit_first_transfers=0`.

### `PAIR-DUMP-0468 ITEM-FAMILY-INTEGRITY-0703`

Reports:

- corrected ammunition requests,
- incompatible carried ammunition returned,
- stale laboratory custody returned,
- stale uncarried family tasks cancelled.

---

## Runtime validation scenarios still pending

1. Empty proxy with firearm magazines in the Cogitator requires a source visit.
2. Empty proxy with ammunition in a nearby home stash uses that exact stash.
3. Proxy ammunition is not removed remotely during combat.
4. Proxy source disappears before pickup and task waits safely.
5. Proxy receives target-compatible modded ammunition.
6. No compatible proxy ammunition produces no invalid request.
7. Empty visible gun turret is reserved and supplied physically.
8. Two stations discover the same turret; only one reserves it.
9. Inserter-fed turret is skipped.
10. Nearby but unconnected inserter does not hide a turret.
11. Turret accepts uranium ammunition preference when available.
12. Turret rejects incompatible magazine request and chooses a compatible prototype.
13. Turret destroyed after pickup returns custody.
14. Turret fills before delivery and leftovers return.
15. Combat blocks a new visible-turret trip.
16. Combat suspends a carried visible-turret trip without loss.
17. Current research with one science pack creates one lab supply task.
18. Multi-pack research supplies the lowest-stock required pack first.
19. Inserter-fed lab is skipped.
20. Nearby unrelated belt/inserter does not hide a lab.
21. No current research creates no lab task.
22. Research changes before pickup and task cancels.
23. Research changes after pickup and packs return.
24. Lab destroyed after pickup returns packs.
25. Lab fills before delivery and leftovers return.
26. Missing science packs create exact item requests.
27. 0527 physically fetches science packs and family delivery resumes.
28. Production fallback creates science packs and delivery resumes.
29. Missing ammunition follows the same request chain.
30. Save/load resumes source travel.
31. Save/load resumes carried custody.
32. Lost task table reconstructs return custody.
33. Original source full causes return to Cogitator storage.
34. No item spill occurs during recovery.
35. Family leaf label and movement target agree.
36. Existing direct/0527 leaf remains higher priority.
37. Old proxy-ammo command is absent.
38. No remote station removal occurs during extended operation.
39. No deposit-first transfer occurs during extended operation.
40. Modded turret and laboratory inventories are handled conservatively.

---

## Explicit exclusions

The following are not folded into 0702:

- boilers,
- reactors,
- generators,
- rocket silos,
- fluid turrets,
- artillery turrets and artillery wagons,
- roboports,
- burner-generator fuel doctrine,
- heat-network management.

Each requires family-specific operating conditions, inventories, or fluid/heat semantics.

---

## Completion estimate

- Proxy ammunition physical accounting: **100% implemented**
- Visible ammo-turret supply: **100% implemented**
- Current-research laboratory supply: **100% implemented**
- Target compatibility and stale-goal integrity: **100% implemented**
- Static source review: completed
- External Lua parser: pending
- Factorio load test: pending
- Runtime scenarios: **0 of 40 executed**

**Overall confidence: approximately 73%.**

---

## Next sequential development target

Audit burner and heat families separately:

1. Boilers and burner generators: physical fuel inventory, water/steam network prerequisites, output connection state, and actual operating demand.
2. Reactors: fuel and burnt-result custody, heat-network connectivity, neighboring-reactor considerations, and safe minimum stock.
3. Generators: read-only steam/fluid and electrical-output diagnosis; no item supply unless the prototype exposes a legitimate item inventory.
4. Never treat these entities as generic assemblers or infer operation merely from an empty fuel slot.
