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

### Relocating an existing lower-ranked station — pending safety gate

Recycling a staffed station must be a single auditable physical transaction,
not `entity.destroy()` or removal of the pair from a table. First establish
strict ownership (direct subordinate / Junior peer), confirm the station has
no active production, movement, emergency, combat or inventory custody, and
ensure it has no subordinate descendants or outstanding item obligations.
Move remaining inventories to an authorized real destination **with exact
accounting**; retain the priest's identity and explicit lifecycle lease.
Only then may the engine mine the station into a valid receiving inventory,
with failed mining leaving the original entity and pair intact. A replacement
station must actually be built and paired before reassignment completes.
Do not enable this automatically until engine tests prove the full sequence,
including save/reload, no orphan priests and no item duplication/loss.

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
