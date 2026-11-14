# Priest-Doctrinal, Just-in-Time Factory Planning — 1410

**State (2026-11-13):** Source implementation and unit fixtures committed; native Factorio 2.1.24 and full Lua suite still require acceptance. The governor emits **one read-only immediate-object intent**. It does not construct factories, award stock, create ghosts, or validate material throughput.

## Doctrines now follow the **planning priest**

Previously, `factory_doctrine_organization_1268` only acted on an explicitly supplied doctrine key. A priest's actual changing Conclave alignment from `doctrine_argument_0370` was disconnected from factory site selection. The new `priest_factory_doctrine_1410.active_policy(pair)` reads **without mutating** this source of truth in order:

1. The registered, same-force, same-surface priest pair's exact `doctrine_argument_0370.by_station[tostring(station.unit_number)].current_camp`.
2. If no live alignment exists, the existing `station_work_state_memory_0366.by_station[station_unit].priest_profile_0367.doctrine_camp`, or its known Doctrine Map school.
3. If neither exists, a **neutral** safe-local style, not an invented random doctrine. Unknown/invalid recorded doctrine keys fail closed.

Doctrinal arguments and social orientation may continue changing normally. They may **influence a newly considered site**, but never interrupt one selected object while the original construction owner holds a task or material. This is how individual priest identity can affect architecture without making social metadata an authority to seize jobs.

The 14 existing philosophy names remain authoritative. Their native-inspection-aware preferences include Main Bus alignment, City Block grid bias, simple Spaghetti/bootstrap proximity, Direct Insertion's verified handoff geometry, Rail Megabase proximity to an actually confirmed train stop, local-pod distribution, belt balancing, verified robot coverage, and advanced beacon/circuit/quality/platform preferences **only if their own prerequisites are explicitly verified**. No such advanced topology becomes constructed merely because a priest favors it.

## The one-object planning rule

`priest_factory_doctrine_1410.select_immediate_site(pair, current_stage, candidates, options)` inspects **at most six already native-validated sites for the same current role**, scores their relative layout preference in O(6), and returns **one** primitive-only site preview. It does not run recipe-tree expansion, 640-node A*, whole-map scans, rail routing, train allocation, or construction. If no site is valid, it returns an explicit refusal.

`priest_factory_doctrine_1410.next_factory_object(pair,observation)` is exposed through `arterial_planner.preview_next_priest_factory_object`. It keeps a single `pair.factory_just_in_time_1410.ticket` until one of these happens:

- A **same-scope, same-name, exact native unit identity** is observed in the world and role-verified (including a player-built alternative). Only physical placement is accepted; working belt/ore flow is **not** credited without separate delivery evidence.
- A relevant local world revision invalidates the *uncommitted* virtual ticket, and the next evaluation is delayed by 60 ticks.
- A real 0338 construction task, carried item, 0528 machine-logistics custody or 0513 acquisition custody exists: preserve that task; do not recalculate or redirect the priest.
- No change: return the original pending objective immediately. A change of social doctrine by itself does **not** cancel the ticket or trigger replanning.

A different objective/recipe or stage cannot replace a pending ticket at unchanged world revision. Ticket snapshots include the original planning priest unit, doctrine key and source, one objective ID, native candidate position/direction, and explicit `construction_authorized=false`, `construction_ghosts=0`. On each *actual* completed object or changed geometry, the planner can reconsider the latest doctrine for **one** new object.

The old 0360 `place_plan_ghosts` is a separately invoked manual/demo path, not the automatic 1410 planner; it is not authorized as functional conveyor construction. The proposed global Ghost Admission Governor remains a separate outstanding item.

## Remote rail outpost integration

`remote_rail_outpost_0835.propose_next_outpost_object_1405` now accepts either the existing `observation.candidate` or a tightly bounded `observation.candidates` collection of **at most six positions for the current stage's one entity type**.

Candidates are revalidated against the actual installed item prototype, `LuaSurface.can_place_entity`, original force, role, and canonical **0686 real-stock inventory**. Repeated stock queries for a common item are cached **only within that immediate invocation**. A planner invocation is skipped entirely while a 1405 ticket exists, the original 0338 builder has custody, or a cooldown is running. Stage-local coordinates are ranked using the live Magos doctrine. The current ticket freezes that choice; after a player or priest physically completes an object, 1405's native observer accepts it and permits exactly one new decision after its cooldown. Later outpost layers are never preplanned.

Existing `1404` train/drill/buffer *capacity estimates* remain separate from object-position planning. Real physical track, direction, stock, power, belts, inserter pickup/drop and native train service require independent validation; the doctrine is not a permit to skip any of them.

## Performance and test criteria

Pure doctrine choice takes O(6) candidate comparisons and no new broker service. Outpost integration can call at most six native placement checks per actual active decision and one stock read per distinct item. No new periodic scanner, object-orientation sweep, blueprint-wide ghost burst or synchronized cold-station work was added.

Tests are committed to `tests/unit/priest_factory_doctrine_1410.lua` and `tests/unit/rail_outpost_priest_doctrine_1410.lua`, chained respectively into the existing 1268 factory doctrine and 1404 rail outpost tests. Cases include fourteen live camps, Main Bus versus Spaghetti site preference, foreign priest refusal, duplicate/invalid/unbounded choices, one-ticket persistence through changing doctrine, safe changed-world invalidation, exact player-built native adoption, cooldown, original item custody, outpost stage progression and zero new construction/ghost entities.

**Pending**: native 2.1.24 tests for actual site placement, source/stop adjacency, overloaded belt lanes, modded prototype differences, real item delivery, game reload and manual alternative player construction. General local-factory `world_revision` is an explicit event/observer input; it must be supplied by an existing physical observer and is not yet automatically installed as a factory-wide event route. Never pretend a virtual read-only ticket is a placed factory.
