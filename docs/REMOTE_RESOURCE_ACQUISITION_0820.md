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

### Interrupted physical cargo transactions (0827 — source-tested, engine pending)

The live 0256 station-ghost executor now reconciles a persisted `building`
cargo record when the station does not physically exist. A process interruption
after removing the real station item, but before entity creation, previously
left an empty `LuaInventory` stuck in `building`. The next service now
observes the site, refunds the existing debited item to the same engine-owned
cargo hold, resets the pending construction delay, and retries without creating
another item. If a station actually exists, the completed-entity path consumes
the debit rather than refunding it. A refused refund retains the transaction
for later retry; an unobservable count is quarantined.

Cargo pickup, build debit, build refund and unused-item return now reconcile
actual source/hold inventory counts even if a Factorio callback throws AFTER
the physical mutation. Source regressions exercise both pre- and post-mutation
exceptions, retries, exact item counts and the actual 0256 executor's
interrupted-build recovery. This is NOT a claim that a real Factorio
save/reload, death/re-imprint or distant ore-delivery scenario has passed.


### Resource-starved chain reversal — required Method I acceptance scenario (2026-10-24)

Start with an existing Magos → Senior → Intermediate → Junior → Junior physical station chain extending away from a naturally generated needed ore patch. The Magos cannot directly command the patch; the network has no spare station items and lacks resources to manufacture replacements. The existing chain is the only source of station items. The Magos must identify the deficit and ore location, choose a viable new direction, and recover the minimum necessary stations by authorized leaf-first deconstruction. Each mined station must yield exactly one actual station item held in real carrier inventory; all inventory, helper, priest identity, hierarchy and command-radius constraints remain binding. Rebuild in the new direction using those same recovered items, verifying each physical ghost completion and priest pairing before extending further. Do not dismantle the final necessary command/carry authority or strand an item carrier. Then mine natural ore and deliver counted physical items upstream to the originating Magos. Test no-spare-item starvation, unsafe-dependent rejection, interruption, save/reload, rank and item conservation, and actual Factorio engine end-to-end return. Planning, ghosts or unit fixtures alone do not satisfy this gate.


### Five-station starvation reversal — 0850 preflight (2026-10-25)

Factorio 2.0.77 [run 40198757895](https://github.com/mrcalzon02/Tech-Priests/actions/runs/40198757895) completed successfully. Its actual runtime job log reports four separate Factorio processes, three CRC-verified saves, a naturally mined item preserved in an engine-owned carrier across process reload, and three physical upstream inventory hops. This **does not** complete the separate no-spare-item five-station reversal or powered-mining gates.

0850 adds a production-integrated, **non-destructive** starvation preflight for the exact Magos (4) → Senior (3) → Intermediate (2) → Junior (1) → Junior peer (1) chain. When the first Senior ghost has no available item and direct Senior recycling is blocked by dependents, the live 0256 executor records a primitive-ID, four-stage leaf-first order (terminal Junior peer, parent Junior, Intermediate, Senior). It checks actual registered pairs, rank, hierarchy edges, exclusive peer topology, domain, a genuinely opposed target direction, and the existing 0822 leaf mining/custody preflight. It rejects branches, missing links, cargo, active duties and ambiguous ownership. The existing item-acquisition fallback remains available; **0850 never mines, detaches a priest, moves stock or credits a station item**. The plan is only an auditable prerequisite for a later physical staging transaction; every stage must be rechecked against live Factorio custody. The executor now periodically revalidates persisted plans against live hierarchy, target, parent/leaf IDs, recipe-item authority and leaf custody; a changed plan is discarded without mining. The preflight also rejects sideways (perpendicular) chains that were previously mistaken for opposed targets by distance alone. Next blocker: implement safe physical leaf staging and counted transport/storage before permitting any ancestor to be mined, then re-deploy in the new direction with the original priests. Do not mark the reversal complete from this preflight.

### Moving material back upstream — first-hop implementation 0837

The terminal's real paired priest now has a narrowly scoped first-hop courier:
after the authoritative 0820 return route verifies the entire physical
hierarchy, it walks within five tiles of the actual natural ore entity,
uses Factorio `LuaEntity.mine{inventory=...}` without force-mining into a
persistent engine-created `LuaInventory`, and must observe both a real
item and resource depletion. It then physically walks to its immediate
upstream station and transfers exactly one mined item into that station's
actual inventory. Full storage, missing movement authority, changed priest
identity, broken hierarchy, missing ore and unverified inventory deltas
block without synthetic credit. The 0640 infrastructure governor and
ordinary pair tick reserve the carrier against new work during the journey.
A source regression exercises physical item counts, movement, full-storage
refusal, module reload, identity mismatch and failed mining.

**This is only one physical hop, source-tested.** It is not a claim that
Factorio 2.0.77 has run this new courier, that the Magos has received ore,
that a mining drill was built, or that the complete five-station reversal
works. Subsequent work must provide real engine/save-reload proof, repeat
custody-preserving transfers across each parent link, establish powered
mining machinery and the resource-starved chain reversal. No ghost, route
plan or source fixture counts as remote-resource acquisition.

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

### Multi-hop counted return — 0838 source regression, engine pending

After the terminal physically mines and deposits one real ore item, each
successive paired upstream priest must be idle and physically pick up one
item from its own station inventory into a new engine-owned hold. It walks
to its immediate parent and verifies the parent's actual inventory delta
before releasing the hold. Every hop persists exact station IDs, carrier
identity and its index in the revalidated 0820 route. Busy priests, full
storage, broken routes and ambiguous custody cannot skip ranks or create
items. Only the final real Magos inventory receipt increments the mission's
delivered count, once. Source regression exercises three hops, reload,
full-storage refusal and changed-route quarantine. This is NOT Factorio
2.0.77 engine/save-reload evidence; that acceptance gate remains open.

### Non-preemptive ore-courier reservation — 0839 (source regression; engine pending)

The 2.0.77 ore-return engine fixture successfully isolated a naturally generated
iron patch and independently proved real station relocation, but the terminal
priest remained occupied by a pre-existing duty until the ore-return timeout.
The previous courier returned `terminal-priest-has-existing-duty` without
claiming future scheduling, allowing the infrastructure governor to continue
assigning work ahead of the waiting physical courier.

0839 persists a **future-work-only** terminal reservation before waiting for
the priest's existing task/custody to finish. The same reservation is extended
to a busy upstream priest after a physically deposited hop. The 0640 governor
observes the reservation and refuses **new** infrastructure assignments; the
courier does not cancel, clear, overwrite, move or debit a busy priest's
existing task or inventory. It starts only after the full duty/custody
availability gate passes. Pending reservations survive module reload, are
bound to exact station/priest identities and a revalidated physical return
route, and are released when the route disappears before any item custody.
The Factorio runtime harness now asserts that an occupied terminal priest
has this non-preemptive reservation rather than merely timing out silently.

This is a scheduling fairness repair, **not** engine proof of natural mining,
Magos receipt or save/reload ore custody. A legitimate duty that never finishes
may still block dispatch and requires diagnosis at its actual authoritative
scheduler rather than a test-only cancellation or bypass.

### Relay ore custody reservation — 0846 (source-tested; engine pending)

Factorio 2.0.77 run 40185499859 mined natural iron ore (534 to 533),
reloaded an actual carried item and physically completed hops 427→426→425.
The third hop failed: a Senior's existing stone duty delayed pickup, and
the deposited ore disappeared from station 425 before pickup. This is not
a completed ore-return acceptance.

0846 reserves exactly one real, already deposited item at the receiving
station until its next priest physically debits it into an engine-owned
courier inventory. Canonical generic-storage spending, station-work debits
and strict emergency crafting exclude that reserved item, but permit
unreserved excess and other storage. Save/reload retains the station custody
record. No ore is created, no busy priest is preempted, and blocked custody
fails closed. Source regressions exercise the actual generic-storage debit.
Real engine third-hop delivery and separate-process reload remain pending.

### Completed direct-miner return handoff — 0845 (source-tested; engine pending)

Factorio 2.0.77 runtime 40182642923 mined real natural iron ore and physically
delivered one counted item through two hops (427→426→425), but the Senior at
station 425 remained in `returning` mode after its existing direct-mining task
and inventory custody finished. The legacy 0340 executor incorrectly called
`return_to_station(pair)`; the authoritative helper requires
`return_to_station(priest, station)`. The 0510 future-work reservation also
suppressed normal legacy idle transitions, leaving the upstream courier waiting.

0845 corrects the actual priest/station return call, falls back to existing
0418 movement authority when that call refuses, and accepts a completed
`returning` duty only after the priest is physically within five tiles of
its own station and every active-task and custody gate passes. Regressions
reject remote pickup and unfinished duties. No item or ore is invented,
no hierarchy rank skipped and no live duty is preempted. The third physical
return hop, Magos receipt and independent carried-ore save/reload remain
Factorio engine acceptance gates.

### Legacy station outbound custody (0846 — engine verification pending)

The 2.0.77 run 40189754560 mined natural iron ore (534→533), carried it through
427→426 and 426→425, but the Senior's one-item station receipt disappeared
while its legitimate stone duty was completing. The legacy provider-cache
trash selector treats unrequested iron ore as junk and could export it without
consulting the courier's existing one-item station reservation. The 0846
repair caps legacy provider exports at physically spendable station stock,
rechecks immediately before removing inventory, and applies the same guard
to the older cram/eject/dump and paired-station inventory-raid paths. Ordinary
unpaired source inventories and stock above the reserved single item remain
spendable. The existing source workflow executes a regression that loads the
real generated legacy trash selector and exporter, verifying retained ore,
actual excess transfer, and module reload. **The engine's third hop, Magos
receipt, and independent carried-ore reload still require real logs.**

### Legacy station-consumption custody (0846 extension; engine pending)

The 2.0.77 run 40193970653 still lost the one-item Senior station receipt
before the third hop despite guarded provider exports. The older emergency
operation and task-force code retained direct station inventory removals:
0184 direct withdrawal, 0185 cooperative station donation, 0187 task-force
station transfer, and 0290 direct station recipe consumption. Each now uses
the same physical one-item 0846 reservation at both eligibility and actual
inventory debit, leaving unreserved excess spendable and retaining existing
physical transfer/refund behavior. The existing source workflow's 0846
regression executes the real generated functions and verifies refusal,
excess-stock movement/crafting, and module reload. This is not yet a claim
that the engine has completed the third hop, Magos receipt, or separate-process
carried-ore reload.

### First physical terminal-Junior staging — 0851 (2026-10-25; source validated)

The live 0256 station-expansion executor now advances a valid, no-spare-item
0850 reversal order into **one physical leaf stage**. It assigns the existing
Junior parent as carrier, waits for its current duties to clear, walks that
priest to the terminal Junior peer, and rechecks the complete live five-station
hierarchy and 0822 inventory/duty/peer preflight at the mine boundary. The
new 0823 staging lease protects the original Junior priest from destructive
station-removal cleanup while Factorio `LuaEntity.mine` deposits **exactly one**
real station item into a persistent, one-slot 0824 engine-owned inventory bound
to the walking parent. A callback exception after a real mine is reconciled by
engine inventory and entity readback; refused mines retain the original station
and priest. The parent then walks that exact carried item back to the Magos.

**The item remains in the original carrier inventory at the Magos**, not in
the Magos chest. This is intentionally *not* a storage transfer, nor permission
to recover the next ancestor. 0822 now rejects deconstruction of any station
whose priest still owns an 0824 engine cargo record. The preserved leaf priest
remains in the 0823 staging lease, with no replacement station claim authorized
until a later real ghost/build transaction. The executor blocks ordinary item
acquisition while staging custody exists, and cannot silently re-run the mine
after a module reload. Existing source tests execute the actual mine callback,
physical travel commands, inventory delta, lease identity, ancestor refusal
and reload behavior. A persisted 0851 physical stage now takes precedence over the Senior writ's
ordinary ghost-completion and station-item-acquisition paths, including when
its stored 0850 plan is missing or damaged. Such a record is quarantined with
its original engine-owned item and living priest, rather than accidentally
retired or mined again. New regressions cover lost-plan and corrupt-stage
identity without destroying either physical custody.

This is **not** an engine-verified five-station reversal.
Next gate: implement a counted, co-located handoff into a protected Magos depot
or other genuine receiving inventory, release the original Junior carrier only
after custody is verified, and then recover each ancestor with a fresh hierarchy
preflight. Factorio 2.0.77 save/reload, four physical station reuses, powered
mining and counted return remain acceptance requirements.

### Counted Magos depot staging — 0852 (source validation pending)

The first recovered Junior station item is carried to within five tiles of the original Planetary Magos before any handoff. A dedicated one-slot **Factorio engine-owned LuaInventory**, persistently anchored to the Magos station/priest, source Junior carrier and original terminal Junior priest/lease, is reserved **before** the carrier is debited. Both engine inventories are read back: only a carrier decrement of exactly one and depot increment of exactly one release the carrier. Refused depot inserts refund into the original real carrier; ambiguous, duplicate, invalid or unobservable custody is quarantined without synthetic items. The protected depot cannot be spent by ordinary station crafting or logistics. The original terminal Junior priest remains leased for later physical reconstruction. The source regression exercises failed allocation, refused insertion, post-mutation callback exceptions, counted handoff, idempotent reload, corrupt identity and loss of plan. This stage **does not** dismantle an ancestor, redeploy the chain, mine machinery-produced ore or establish actual Factorio 2.0.77 reversal acceptance. The next gate is serialized, live-preflight ancestor recovery and physical redeployment using the protected stock.


### 0853 — second physical Junior recovery (source validation; engine pending)

After the terminal Junior peer's real item is independently verified in the
protected 0852 Magos depot, the live 0256 station-expansion executor advances
to its parent Junior. The Intermediate priest walks to that Junior, rechecks
live ranks, exclusive hierarchy edges, cleared peer/dependent links, unchanged
ore target, and 0822 inventory/duty custody at the mine boundary. It uses the
existing 0823 physical mine and original-priest lifecycle lease and the 0824
one-slot engine-owned carrier. It physically returns to the Magos and hands
the recovered Junior item into a SECOND protected 0852 LuaInventory, with
exact carrier 1→0 and depot 0→1 accounting. Stored-depot verification uses
persistent original-priest identity and lifecycle leases even after the former
carrier's station has been physically mined. Missing or ambiguous custody
quarantines progression instead of creating station stock.

The extended existing 0822 regression exercises blocked ancestor inventory,
actual mine/carry/handoff calls, both independently counted depots, priest
survival and module reload. This is source/unit evidence, NOT Factorio engine
proof of the five-station reversal. Physical Intermediate/Senior recovery,
rebuilding toward the natural ore patch, mining machinery, independent engine
staging/save-reload, and Methods II/III remain outstanding. No new GitHub
Actions workflow was added.
