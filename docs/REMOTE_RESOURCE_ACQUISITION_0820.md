# Tech Priests — Remote resource acquisition

Authority: the Planetary Magos chooses the resource deficit and target; physical
builders, inventory stewards, command hierarchy and Factorio remain authoritative
for all material consequences. A remote station ghost is NOT a completed station.

## Method I — ranked Cogitator relay (active implementation)

Rank sequence: Planetary Magos (4) → Senior (3) → Intermediate (2) →
Junior (1) → further Junior peer links (1). A parent builds its immediate
lower-rank child from a **real station item**; subsequent construction must be
performed by the now-paired successor. The child must be placed in the parent's
effective command area. Hierarchy direct limits (2/4/8) and Junior peer limits
(16) are never overridden.

The known resource's position, resource prototype, original Magos station unit,
current construction commander, step and active expansion record live in a
persistent chain objective. One outstanding child per objective. Existing
station-expansion mechanics own exact item acquisition, ghost creation, movement,
build delay, physical item removal and station creation. The chain can move on
only after the built entity has a valid priest pair and a confirmed hierarchy
edge to its parent; it checks that each new station makes actual progress toward
the resource. Arrival requires re-observing the **real** resource inside the
terminal station's radius through the shared scan router. No resource spawning,
free technology, synthetic mining, teleport or invented inventory.

Implementation (0820): source/unit tests pass; full engine relay construction,
terminal mining and material return are NOT yet verified. The older exploratory
station-ghost doctrine remains independent when no known patch is available.
Missions stop safely on missing stations, failed ghost construction, full
hierarchy capacity or exhausted bounded chain length.

### Relocating an existing lower-ranked station — 0825 source tested, engine pending

Recycling a staffed station must be a single auditable physical transaction,
not `entity.destroy()` or removal of the pair from a table. The 0822
preflight requires an actual lower-ranked direct subordinate / eligible
Junior peer with no descendants, active duty, inventory custody, facilities,
or helpers; nonempty stations are **not** yet eligible for relocation. The
0823 lifecycle lease intercepts the station's physical mine event to preserve
the original priest. A replacement must be physically built and rebound to
that priest, not assigned a newly spawned priest.

0825 now wires long-distance recovery into the live 0256 station-ghost
executor: the worker walks to the selected station (with a bounded travel
timeout), reserves a one-slot engine-owned cargo inventory, and physically
mines the old station directly into that inventory. The worker then carries
the recovered item to the requested ghost, consumes the real item to build,
and rebinds the surviving original priest. A refused mine leaves the original
station and priest intact; an ambiguous post-mine result retains a custody
error and blocks further automated spending. Cargo and priest leases persist
through reload. Source regression proves the executor's actual walk/mine/
carry/build/reattach sequence and the lease's save/reload/refusal behavior.

**Engine acceptance is NOT established.** Full Factorio 2.0.77 testing must
still verify real mine API behavior, callback ordering, interruption, true
save/reload, priest survival, inventory conservation and hierarchy ownership.
Do not mark the recovery gate complete from Lua fixtures alone.

### Physical station-item cargo (0824 — source validated, engine pending)

Cogitator priests are Factorio `unit` entities without character inventories.
The 0256 station-ghost executor therefore uses a one-slot **engine-owned**
`game.create_inventory(1)` hold, persisted in `storage` and bound to the
specific worker priest's unit number, home station, force, surface, and writ.
This is a real `LuaInventory` containing a physically debited item, **not** a
Lua counter, spawned item, or free station stock. The priest must walk within
five tiles of the source station before one item is removed from its actual
inventory and inserted into the hold. Only after walking to the ghost may the
item be removed from that hold to construct a real entity. Failed construction
refunds the same hold; completion destroys only an empty hold. If another
builder completes the ghost, the priest must walk home and return the unused
item to the source inventory. Callback exceptions use inventory readback
rather than blindly refunding items. A missing ghost with cargo is retained
or reconstructed instead of discarding the physical item.

The earlier executor consumed a station item from a **remote** station
inventory while the priest was already standing at the ghost. That was
remote withdrawal, not carried construction, and is no longer the intended
path. Unit tests cover local pickup, exact source/hold deltas, ownership,
failed builds, refund, competing builds, and reload of the persistent
engine-owned inventory reference. Actual Factorio 2.0.77 save/reload and
end-to-end engine delivery are still required.

The 0823 local-only home-station recovery path remains available as a
conservative legacy transaction. The new 0825 remote path instead mines
directly into the 0824 engine-owned worker cargo at the source station and
never teleports an item into the home inventory. Source validation on
`897da77d20e452c3938ca2c5dcd64db776af7682` passed, including both
physical executor and relocation/reload regressions. Cargo death-site salvage is now source-tested (0826), but a visible
world-item drop and full Factorio engine/save-load evidence remain pending.

### Fallen carrier item custody (0826 — source validated; engine pending)

When a priest carrying a real station item dies, canonical 0499 re-imprint
marks its existing 0824 engine-owned inventory as **stranded** at the observed
death location. The actual inventory remains in persistent storage: no item
is refunded, spawned, destroyed, or remotely credited. A replacement priest
from the same station, force, surface and expansion writ must physically
travel to that location before taking custody of the original inventory
and resuming the station ghost construction. Last-observed positions protect
missing-priest events when the death callback is unavailable. Ambiguous
empty recovery holds, already-debited build items and unobservable custody
are quarantined rather than synthetically refunded.

This is **script-inventory death-site salvage**, not yet a visible Factorio
item-on-ground drop. Source tests prove death, idempotence, denied remote
pickup, physical recovery, reload, refund, uncertain mining and the live
0256 executor's movement and successful station construction. Source
validation on implementation/test commit
`7e50f022812009886cc751b08532b5f5a902ba89` passed:
https://github.com/mrcalzon02/Tech-Priests/actions/runs/40055369148 .
A purpose-built Factorio 2.0.77 death/re-imprint/save-reload test and a
real-world visible drop/restitution design remain acceptance gates.

### Moving material back upstream — pending

Reaching ore is not delivery. The terminal Cogitator must physically assign a
miner or mining drill and construct a counted outbound supply path to the
upstream link. Each successive parent accepts real items into real storage
before credited supply can propagate toward the Magos. Define throughput and
starvation tests; do not increase a parent inventory by planning alone.

## Method II — distributed construction-robot expansion (planned)

A Magos may authorize a remote station ghost only inside the **actual active
construction area** of an already-powered roboport network with construction
robots, buildable items and valid delivery logistics. Expand power and robot
coverage in verified steps, build the next roboport/network anchor physically,
then allow farther remote station ghosts. Command radius and robot construction
coverage are different authorities. Ghost placement is not credited as a
construction success. Ownership, inventories and material transit remain
explicit. Test disconnected roboports, lost power, missing robots and full
logistic storage; all must fail closed.

## Method III — rail expedition (experimental)

Plan a traversable railway toward a discovered resource, build each rail/bridge
segment from physical items, produce and fuel real rolling stock, and validate
signals/path availability. The Magos travels as an actual occupant/driver to
the site, builds or assigns a legal station, and returns by a real route.
A path must be safe and reversible before departure; the mission requires
failure handling for dead engines, no fuel, destroyed rails, train congestion,
out-of-reach work and loss of Magos identity. No scripted teleport, spawned
train or ghost-completed railway qualifies.

## Progressive evidence gates

1. Source: ranks 4→3→2→1→1, real construction item custody, no duplicate
   ghosts, hierarchy ownership/capacity, save-safe mission data, bounded scans.
2. Engine: Magos with NO initial subordinate builds and pairs the first Senior;
   that Senior builds the next station in actual command range.
3. Engine: continued lower ranks reach a naturally generated out-of-range
   patch, mine actual ore, and return a counted batch to the original network.
4. Recycling: inventory-safe subordinate decommission/redeployment under
   existing lifecycle authority, save/reload and blocked-case evidence.
5. Drone: ghosts fulfilled by powered, supplied construction robots only.
6. Rail: genuine outward travel, remote build and safely completed return.

Do not claim completed resource acquisition based only on a placed ghost, an
in-range station, a passing Lua unit test or an unexplained inventory increase.
