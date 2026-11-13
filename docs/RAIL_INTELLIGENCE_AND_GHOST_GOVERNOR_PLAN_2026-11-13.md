# Tech Priests — rail intelligence integration and ghost-admission governor

**Status:** Proposed engineering plan; inspection and source audit only, NOT runtime implementation, NOT native Factorio acceptance.  
**Date:** 2026-11-13.  
**Authority:** Remote resource goal [#6](https://github.com/mrcalzon02/Tech-Priests/issues/6); preserve existing hierarchy, original physical inventory accounting, construction ownership, and release gates.  
**Baseline inspected:** `main` at `038498c2a8b7533db016fb6f4a3de89c819980c0` (the head may advance independently while this plan is reviewed).

## 1. Problem statement and confirmed existing limits

The railway code already physically requests one original rail at a time, authenticates native rail identities and connections, and uses the existing 0510 dispatcher and 0338 physical builder. However, `rail_track_frontier_0836.lua` plans a straight **eastbound** `straight-rail` corridor, with two-tile increments and six-tile target lateral tolerance; `remote_rail_outpost_0835.lua` restricts natural-ore searches to that corridor. These are deliberate first-implementation limitations, not general route planning. The original priest's boarding attempt explicitly refuses a `unit` as a native character-only driver; later physical outward-and-return train travel has not been proven.

The live ghost protections are **local**:

| Authority | Current behavior | What it does **not** guarantee |
| --- | --- | --- |
| `construction_bootstrap_ghost_planner_0645.lua` | One active bootstrap planning ghost **per station**; skips additional ghosts while one is active; retries a missing record after 600 ticks; retires ghosts after specific completion, overlap and supersession conditions | No force/surface aggregate ceiling; a broker visit budget is not a cap on accumulated ghosts |
| `magos_station_expansion.lua` | `TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256 = 3`; one active remote-resource ghost per writ; a builder is selected before new ghost creation; physical-identity checks and some restoration cleanup | No shared force/surface total, and active records are not necessarily equivalent to all physical ghost entities |
| `construction_planner.lua` Method II | One `robot_network_task_0338` per station request; creates a single ghost after powered-network/robot/stock and site-reservation preflight; waits for native robot event, stock delta, hierarchy pairing | No aggregate quota across multiple parent stations; a never-completing native task may leave a ghost indefinitely |
| `rail_track_frontier_0836.lua` | One pending `construction_request` and one physical rail segment per mission, completed by 0338 with item debit and native graph audit | No nontrivial turns/terrain route, train safety certification, or global ghost quota |
| `runtime_tick_broker` | Bootstrap service registers at 83 ticks with broker budget 6; separate service has max 16 station inspections per pulse | **Inspection throughput** is not a persistent count of ghosts on the map |

**Verdict:** The important localized limiter exists. A shared, lifetime-aware **Ghost Admission Governor** that applies to bootstrap, hierarchy expansion, robot stations, and future robot rail construction has not been established in inspected production paths. Do not equate `max_pairs_per_pulse` or `max_ghosts_per_requester` with a global limit.

The plan must not remove project ghosts merely because they are old: genuine long-distance original builder travel and real material custody can outlast a simple timer.

## 2. Integration principle: think far ahead, build only nearby

The planning system may retain and score a long *virtual* railway, but **must not project the whole route into Factorio as entity ghosts**. Store primitive route intent, segments and check results, not hundreds of in-world entities. Separate:

1. `proposed`: read-only strategic target and ranked route alternatives; zero ghosts, zero items.
2. `approved-plan`: bounded, deterministic, save-safe geometry and material estimate; zero ghosts, zero items.
3. `admitted-step`: single verified next physical candidate, owned by exactly one canonical construction request.
4. `in-progress`: existing 0510 → 0338 dispatcher/builder moves, debits exactly one real rail item, places entity and verifies native identity/connectivity. No separate rail constructor.
5. `verified`: advance route cursor only on original 0338 real-item receipt, surviving native rail identity, connecting edge, and movement path.
6. `finished`: physical rolling stock, stop, fuel, signals and native outbound **and return** train path verification; only then expedition/mine/return phases.

**Default rail policy:** zero rail ghosts for priest-placed rails, and **one outstanding physical rail construction request per mission**. Robot construction may later turn a single admitted step into one construction ghost, subject to a shared governor. Visual route previews should use temporary rendering, not entity ghosts.

## 3. External projects and transferable components

| Reference | Reuse policy | Exactly what transfers |
| --- | --- | --- |
| [Factorio 2.1.24 API — LuaRailEnd](https://lua-api.factorio.com/latest/classes/LuaRailEnd.html), [RailExtensionData](https://lua-api.factorio.com/latest/concepts/RailExtensionData.html) | Native API; **primary source of rail geometry authority** | `get_rail_extensions("rail")` gives valid prototype, position, direction and goal for each extension of a **built** rail end; still check live collision, force, unlocks and stock. Prototype-specific additional rail planners must be discovered rather than assumed. |
| [Envian/factorio-dual-rail-planner](https://github.com/Envian/factorio-dual-rail-planner) | MIT; preserve copyright and license if adapting code | Rail pointers/turns, segment alignment, parallel track offsets, ramp/layer constraints, signal spacing. Its `scripts/algorithms/pathfind.lua` solves geometric alignment of opposite paths, **not** general terrain A*. Adapt narrow geometry utilities only. |
| [LeonSkills/RailSignalPlanner](https://github.com/LeonSkills/FactorioMods/tree/master/mods/RailSignalPlanner) | Root repo LICENSE is LGPL-3.0; clarify component terms before source-copying | Rail graph/block walks, detecting entries/exits, directional conflict checks, chain-vs-regular signal placement. May design independent in-house algorithm based on Factorio semantics without copying code. |
| [Tsyklop/factorio-llm-use](https://github.com/Tsyklop/factorio-llm-use) | MIT; **isolated optional test harness**, no required runtime AI service | Inspect native rail graph, train schedule, world state, blueprint/ghost appearance during runner-based validation. Do not grant the external AI runtime material mutation or priest-identity authority. |
| [Auto Train Track](https://mods.factorio.com/mod/auto-train-track) | GPLv3 code not imported; linked GitHub at previous audit held license only | Behavioral goals: bounded path search, real obstacle handling, crossing rules and meaningful failure reporting. |
| [YPetremann/rail-layer](https://github.com/YPetremann/rail-layer) | Custom “MIT NON-AI” license, **not** standard MIT; no code transfer without review | Observe native rail extensions, train cargo and ghost-revival concepts. Avoid making this mod a dependency. |

Never import wholesale train control, material creation, blueprint placement, scheduling or global polling code from a separate AI mod. Any copied MIT source must retain the license notice in the project's third-party notices.

## 4. Proposed railway module boundary

- New pure planner `scripts/core/rail_route_intent_14xx.lua`: input (Magos station anchor, real charted natural ore target, unlocked rails, stock snapshot, permitted survey budget), output (ranked, capped, **non-mutating** virtual route, candidate sequences and blocker reasons). Owns no `LuaEntity.create_entity`, ghosts, inventory, priest movement or task dispatch.
- New geometry adapter `scripts/core/rail_native_geometry_14xx.lua`: only derives legal next positions from the **actual** native rail front end using `LuaRailEnd.get_rail_extensions`; use deterministic ordering by cost, distance, turn penalty, obstacle and stock. Existing eastbound path remains the fallback/protected baseline. For projected future unbuilt rails, plan against a disconnected virtual rail-topology graph **only if** verified against legal native geometry; do not invent valid turns from Euclidean offsets.
- Existing `remote_rail_outpost_0835.lua`: strategic admission extends from eastbound patch-only to charted reachable candidates after costed route preflight; do not select merely closest impossible deposit.
- Existing `rail_track_frontier_0836.lua`: retains one segment cursor, paid build receipts, connection audits and blocked-site stop states; no remote-build shortcut. Introduce route-step types (name, position, direction and expected native connection), preserving old straight-east tests unchanged.
- Existing `single_dispatcher_0510.lua` and `construction_planner.lua`: remain **sole physical** dispatcher and item owner. New route plan only offers next construction writ.
- Signal/station planning: use canonical `construction_site_planner.lua`, site reservations, and native topology checks to place **paid** stop/signals, with a minimal single-train railway first. Before train departure verify an actual return-capable layout (loop or genuinely reversible rolling stock) rather than assuming a single-ended locomotive can run backward automatically.
- Existing `service_first_train_board_0836` has an independent hard refusal for Cogitator `unit` passengers. Design and native-test a **physically present, identity-preserving carriage/occupant solution** before claiming a complete Magos expedition. No teleport, dummy character credited as Magos, or synthetic arrival.

## 5. Proposed Ghost Admission Governor

New authority `scripts/core/ghost_admission_governor_14xx.lua`. It is a **bounded ticketing and reconciliation service**, not another construction or robot executor.

**Initial conservative tuning for native evaluation** (proposals, not existing values):

- `max_outstanding_per_force_surface = 24` project-owned persistent entity ghosts; configurable and subject to load tests.
- `max_outstanding_per_requesting_station = 3` across ALL ghost-producing systems together; existing three-expansion-ghost limit remains an additional local maximum.
- `max_outstanding_per_mission = 1` for outward resource and rail missions unless an explicitly tested train/robot batch requires otherwise.
- `max_new_ghosts_per_governor_pulse = 2` across registered owners; preserve existing broker fairness; virtual plans are never charged.
- No automated free passes. Emergency defense / critical power gets priority to **new admission** but cannot destroy an existing physically committed ghost or its cargo.

**Ticket model:**

`ticket = {owner, requester_station_unit, mission_id, force_index, surface_index, entity_name, position, direction, admitted_tick, ghost_unit, status, custody_owner, last_reconciled_tick}`.

`admit(owner, request)` requires a valid live pair, exact plan state, bounded queue capacity and surface/force domain, no duplicate ticket/ghost/site reservation, and canonical physical-builder state. A reservation must be established **before** ghost creation; on refused create, release the ticket only after confirming no real ghost was created. On success bind exact ghost unit and native identity to the ticket. A pending admission that exceeds budget is queued rather than spawning its ghost.

`reconcile(ticket, native_readback)` is called on completion, explicit cancellation, obstruction, robot build event, deleted entity, changed ownership, reload, migration and bounded maintenance pulses. Verify the **exact owned** physical ghost by unit, prototype, position, force and surface before retiring it. Never treat an arbitrary ghost at the same coordinates as our own. Never touch player/other-mod ghosts. An unidentifiable created ghost or uncertain prior mutation **quarantines** the ticket until original ownership is proven; it does not authorize a replacement. Guard tickets survive save/reload and are reconciled from live engine state with no whole-surface sweeps.

`release(ticket, reason)` is allowed only after original owner has safely terminated its task and inventory/robot/worker custody. Existing long-distance station ghosts are **not** timed out while carrying an original item or while the worker is on an authorized route. A bounded no-progress alert and manual diagnostics are safer than blindly deleting live work.

**Required integration call sites, in order:**

1. Bootstrap `create_planning_ghost` in `construction_bootstrap_ghost_planner_0645.lua` (one local ghost remains maximum).
2. `create_station_ghost` and restore/replacement in `magos_station_expansion.lua`; replacement must reserve a transition slot and retire **only the exact original** without creating two enduring live ghosts. Recovery with an already-owned ghost must reuse its ticket.
3. `service_robot_network_pair_0338` in `construction_planner.lua` before `entity-ghost`; preserve robot network checks, native event and real stock delta.
4. Any future robot-powered railway ghost admission; priest-placed rail remains at **zero ghosts**.

**Telemetry** per force/surface and requester: admitted, physically-live, queued, quarantined, unknown/foreign ignored, oldest age, new per pulse, success/failure, blocked by cap, original stock counts. Show concise counters in existing diagnostics. Keep scans budgeted through `scan_routing_0610`. Limit counts must be computed from persisted tickets cross-checked against native entities, **not** just the count of recently visited stations.

## 6. Execution stages and acceptance

| Stage | Deliverable | Must prove before advancing |
| --- | --- | --- |
| G0 | Audit every actual `entity-ghost` creation/retirement path and ownership source; establish baseline live ghost count | No untracked producer and no third-party ghost counted or deleted |
| G1 | Admission governor with tickets, queues, fairness, identity, save/reload reconciliation; disable/observe mode before enforcing | Unit tests for 100 requests, 24-slot global bound, requester bound, orphan/refund, no cargo loss, foreign ghosts, stuck robot and hierarchy producer contention |
| G2 | Wire three existing ghost producers one at a time, with rollback flag and per-producer unit tests | **No** regression in original station/cargo/robot gates; no duplicate or missing ghosts after reload |
| R1 | Native rail extensions + virtual route planning, no new ghosts | Curves, diagonal target, fixed obstacles, ambiguous rails, unreachable terrain and exact item cost; existing straight-east cases still pass |
| R2 | One-step route execution through original 0510 → 0338 | Native 2.1.24: counted rails including turns, physical item delta, correct native connection, partial failure/refund and reload |
| R3 | Signals/stops and native outward AND return-path certificate | Real train, stop and signal identities; pathfinding on built track, no phantom track credit |
| R4 | Original Magos occupant solution; fully physical mission | Genuine trip, physical outpost, natural ore acquisition, counted cargo to origin, arrival and return, blocked/dead-end/fuel/track break and save/reload |
| R5 | Release regression | Existing source/unit and 2.1.24 runtime/benchmark jobs; no loss of baseline science, combat, hierarchy, UPS or multiplayer persistence |

**Critical negative acceptance cases**:

- 1000 virtual rail steps produce **zero** construction ghosts.
- 100 queued physical projects cannot exceed 24 persistent *project-owned* ghosts per force/surface in proposed test configuration.
- An already-owned station ghost + paid carried item persists through a governor saturation event and save/reload.
- Ghost disappearance with ambiguous construction/robot receipt does not generate or refund an item.
- Three competing ghost producers share the cap; one station cannot bypass it by switching planners.
- A foreign ghost at matching coordinates is not adopted as ours, deleted or included in the project cap.
- Two actual consecutively paid curved rails are connected by native Factorio graph, not just at nearby coordinates.
- Native train path is checked in both directions **after** real track exists.
- A blocked rail site causes a bounded planning refusal/replan, never hundreds of ghosts.

## 7. Constraints on execution

- **Single `main` branch**, small surgical changes. Commit and read back each implemented increment; report exact commit SHA and test run URLs.
- No new always-on GitHub Actions workflows. Use existing unit/native Factorio runner entrypoints and manual dispatch as available.
- Avoid direct porting of GPL/custom-licensed code. In-house algorithm over native Factorio API plus MIT-licensed geometry reference is the intended route.
- Current documentation is a **design artifact**. Do not claim the governor, turning rail construction, native train return or Magos boarding is integrated from publication of this document alone.
- Keep #6 open until actual counted physical resource return and all three autonomous methods meet its acceptance requirements.

## 8. Implementation checkpoint — 2026-11-13

**Implemented on main in this integration pass (source readback verified, native engine NOT yet proven):**

- `rail_track_frontier_0836.lua`: new `authorized_paid_rail_transit_0836` checks the original registered Magos pair, live original 0338 construction task, one pending item-paid rail mission, exact source identity and available rail stock for the homeward supply leg, exact carried original rail debit for the build-site leg, genuine nearby unit-numbered native rail and predecessor connection, bounded straight-corridor proximity, movement ownership and (if present) TTL. Refuses creative or foreign claims. No general assigned-area override.
- `movement_controller.lua`: the canonical 0418/0566 controller preserves an eligible rail task through hard-leash enforcement while traveling **between** physically paid track and the builder's confirmed goal, rather than only inside three tiles of the final site. Verified future waypoint goals are scoped through the same predicate; safety returns resume when the predicate fails.
- `rail_track_frontier_0836.lua`: `inspect_native_rail_extensions_0836` obtains real `LuaRailEnd.get_rail_extensions("rail")` candidates from an *already paid/identity-verified* frontier, checks native placement, deduplicates, ranks by target distance and stores up to three primitive read-only options once per credited segment. It does **not** dispatch curves, spend an item, place ghosts or convert future track into existing track.
- `tests/unit/rail_expedition_transit_1401.lua` is added and invoked from the existing `tests/unit/movement_overleash_return_continuity.lua` entrypoint. It tests mid-route site and source ownership, no-stock refusal, wrong force/owner, revoked original writ, missing physical rail, default safety restoration, per-segment native preview, and zero ghost/entity creation. **These are committed tests, NOT a claim that they have run successfully.**

**Still open:** actual Lua/Factorio 2.1.24 test execution, native curved-rail construction through counted 0338 debits, additional rail directions, multi-tile obstruction routing, train-stop/signal and return-path acceptance, Cogitator `unit` boarding/physical travel, ore return, delegated non-Magos rail-crew writs, and the shared cross-producer ghost admission governor. The previously established per-station ghost limits remain unchanged.

**Acceptance before broadening the exemption:** only permit a delegated priest to depart its station once it holds a distinct, persistent and hierarchically authenticated railway task, proven physical carriage/route and a bounded travel right. Never authorize off-leash wandering by job-name matching, a ghost, a virtual route or a foreign actor. Method III and issue #6 remain OPEN.

---

