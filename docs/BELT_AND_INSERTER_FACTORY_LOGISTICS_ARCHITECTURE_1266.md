# Tech-Priests — 1266 Arterial Belt and Inserter Logistics Architecture

Status: researched and specified; **NOT** autonomous runtime belt routing or constructed material delivery.
Authority: Factorio 2.0.77 native entities, prototypes, recipes, item inventories, transport lines, inserter state and real construction receipts.
Goal: turn a real, demand-driven, machine-to-machine recipe dependency graph into buildable and verifiably working local material transport without competing with existing acquisition, construction, machine logistics, steam/fluid, train or robot authorities.

## Existing code audit — what actually exists

1. scripts/core/arterial_planner.lua (0360) generates a bounded recipe outline and can create a disconnected demonstration belt ghost beside a machine and a pole. That is **not** a physical route, feed system, or license for autonomous ghost spam.
2. master_infrastructure_plan_0644.lua already has stages automation-inserters and automation-belts but its role check measures whether one inserter/belt is present anywhere, **not** whether a mining drill's real output can reach its required smelter or an assembler's input/output. Do not promote the stage to "transport complete" from that count.
3. infrastructure_first_governor_0640.lua, machine logistics 0528, science throughput 1133, component construction 1150 and factory-feed offer 1153 already own their demand and item flows. The belt planner should subscribe to a **need**, not replace these existing systems.
4. single_dispatcher_0510, construction_planner (0338), movement 0418, storage authority 0686, and work reservations 0601 own arbitration and **counted** physical work. Belt planning must publish one immutable, provenance-tagged construction candidate only when its owner grants a lease; it must never directly spawn live belts, wire power, transfer inventory, or steal another worker's cargo.
5. fluid planner 0689/0691/0696 owns fluids and their pipes. The belt graph is **item-only**. A mixed fluid/item recipe gets separate transport obligations.
6. doctrine_map.lua has the actual fourteen factory-style camps. It is currently personality/social metadata, not an engineering actuator. Do not use a priest's doctrinal opinion as permission to spend inventory or alter a player's factory.

## Technical research and Factorio 2.0 compatibility

- Engine placement: LuaSurface.can_place_entity, real force/surface, direction and native placement rules. Query before constructing; re-check before handoff. Existing entities are not cleared or replaced as an optimization.
- Physical belt lanes: LuaEntity.get_transport_line(index), get_max_transport_line_index where supported, and LuaTransportLine.get_item_count(item) or get_contents. Read the actual two-lane contents and changes; no aggregate phantom conveyor inventory. A stationary item on a disconnected belt does not prove delivery.
- Inserter geometry: real pickup_position and drop_position, physical pickup_target/drop_target where observable, prototype default vectors, direction, arm reach, power/fuel and filters. Do not change native vectors on prototypes without allow_custom_vectors; prefer rotating a legitimate inserter build candidate and reading its post-build geometry.
- Real output: mining drill drop_position and output receivers; furnace/assembler input/output inventories and recipe semantics. Do not place an inserter from a machine merely because its centers are adjacent.
- Belt physics: two lanes, turns, sideloading, backpressure and throughput. Ordinary yellow/red/blue belt capacities in vanilla are approximately 15/30/45 unstacked items/s per both lanes; **do not hardcode those as modded-capacity facts**. Use installed prototype speed and observed item motion where practical; Space Age's belt stacking and quality change the accounting.
- Underground belts are paired engine entities with actual orientation and max underground distance; splitter routing and priority/filter are later separate graph operators. A two-tile A* path does not represent underground input/output or a splitter's two lanes.
- Circuit-controlled sushi and quality sorting must reserve a verified filter/control circuit, avoid wrong-quality contamination, and detect blocked loops before material is admitted. Never automatically enable mixed-lane circulation by doctrine name alone.
- Native connection truth follows docs/FACTORIO_NATIVE_ENGINE_AUTHORITY.md. Planning can use predicted path and capacity, but only the engine can show physical arrival, machine intake, output and actual research/production.

References:
- https://lua-api.factorio.com/latest/classes/LuaEntity.html
- https://lua-api.factorio.com/latest/classes/LuaTransportLine.html
- https://lua-api.factorio.com/latest/classes/LuaSurface.html
- https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html
- https://wiki.factorio.com/Transport_belts/Physics
- https://wiki.factorio.com/Inserters

IMPORTANT: The hosted "latest" documentation currently describes Factorio 2.1.x. Before implementing an API not already verified by this repository, check method existence and exact semantics under the pinned Factorio **2.0.77** native test runner. A missing API is a diagnostic blocker, not permission to pretend a connection.

## Architectural boundaries and proposed modules

| Module / authority | Inputs | Responsibilities | Explicit non-responsibilities |
| --- | --- | --- | --- |
| Existing arterial_planner_0360 | Recipe nodes, requested product, planning anchors | Publish demanded item-flow edges and factory-block proposals | Existing scatter ghost is not an accepted route |
| **New belt_logistics_contract_1266** | Explicit item, source/sink entities, force, surface, requested units/min, optional explicit doctrine key | Read-only native endpoint probe, do-not-act status, provenance; validate whether a flow has enough identity to plan | No world edits, inventory claims, implicit doctrine switching |
| Future item_flow_graph_1267 | Recipe graph, specific machine outputs, inventories and storage | Resolve producer/consumer ports and source availability, consolidate shared demand, account for coproduct/quality | No assumed item production |
| Future belt_route_search_1268 | Source/sink native geometry and destination transfer contract | Directed grid / lane / orientation search; candidate belts, inserters, undergrounds/splitters; reserve passage and power footprints | No synthetic pipe/rail/robot/copper connections |
| Future belt_route_dispatch_1269 | Validated candidate sites and 0601 reservations | Offer an owned immutable request to existing 0510/0338, one item at a time, after custody checks | No independent builder or free stock |
| Future belt_route_verify_1270 | Native installed entities, inserter pickup/drop, transport lines, consumer inputs and consumption | Confirm coherent orientation, connected path and *actual* counted delivery; monitor blockage and backpressure | No completion based on ghosts or proximity |
| Existing 0689/0691 fluids; 1076 roboports; rail systems | Cross-boundary outputs | Own independent native mechanics | Belt planner must not override them |

All planned route records saved in Factorio storage must use **serializable primitives** (unit numbers, surface index, force index, tile coordinates, item/quality, role, direction, status and tick), not raw LuaEntity/LuaTransportLine handles or closures. Re-resolve entities after load. Never assume a unit number on a different surface or force is interchangeable.

## Foundation 1266 contract

Public, read-only interface:
- doctrine_profile(key): only looks up an **explicit** key in doctrine_map.by_key, returns the official camp identity and the future topology family; unknown key remains unknown, not the secretly defaulted main bus.
- demand(pair, {item, rate_per_min, source, sink, doctrine_key, quality}): validates real endpoint identity and native surface/force, current positions and item name, then returns status="requires-route" plus primitive endpoint snapshot; or status="blocked" with a precise reason. This function **does not** discover, build, own, reserve or complete a route.
- inspect_belt(entity,item): only for a real belt-connectable instance with native read APIs; read lane item counts as **observations**, returning unknown when the engine cannot report a lane. It never inserts/removes an item. An observed quantity is NOT proof of upstream-to-downstream delivery.
- inspect_inserter(entity): read native pickup/drop positions and targets where visible. Does not set direction, targets, filters, burner fuel or power.
- architectural strategy from DoctrineMap is a descriptive hint only; the engineering policy remains owner-controlled and must be explicitly chosen before it can affect future scoring.

Sample flow edge: iron-ore from a particular built miner and its drop receiver -> physical smelting machine inlet, counted as 120/min, within the real Magos territory. A disconnected stored chest may be a *potential source* but is not a functioning belt supply until an actual inserter/drill egress is verified.

## Doctrinal layout research — using actual registered camp names

| Doctrine key / camp | Candidate topology to investigate | Special conditions / stage |
| --- | --- | --- |
| main_bus — Main Bus Orthodoxy | Parallel reserved lanes, centralized bus, predictable taps | Phase 2: lane allocation and growth corridor |
| mixed_spaghetti — Mixed Spaghetti Pragmatica | Short legal directed routes through dense existing machines | Phase 1 local bootstrap only, protect vital clearances |
| direct_insertion — Direct Insertion Conservatory | Machine-to-machine transfer before unnecessary belts | Phase 1: test exact inserter pickup/drop geometry |
| rush_bootstrap — Bootstrap Survival Rite | Minimal local furnace/drill/buffer/inserter/belt handoffs | Phase 1 first real ore-to-smelter-to-assembler |
| distributed_mini_factories — Distributed Shrine Network | Local manufacturing cells with small belts and intercell buffers | Phase 2 local-plus-trunk interface |
| city_block — City Block Administratum | Repeated bounded block-level mini-bus, rail/robot block borders | Phase 3 once rail/robots prove physical links |
| rail_megabase — Rail Megabase Logis | Belt-fed rail station buffers; train owns long-distance transport | Phase 3, native train logistics first |
| bot_mall — Logistic Bot Reliquary | Actual powered roboport logistics for flexible short-haul items | Phase 3, belts reserved for measured bulk |
| belt_balancer — Balancer Geometry Scholam | Counted lane/splitter balance and staged throughput expansion | Phase 3 after native lanes and splitters |
| sushi — Sushi Belt Mysticism | Deliberate circular mixed-item lanes with flow control | Phase 4: circuits, jam detection and conservation |
| circuit_control — Circuit Oracle Covenant | Circuit-limited inventory/belt injection with filters | Phase 4, never assume circuit wires/signal |
| beaconed_modules — Beaconed Module Ascendancy | High-rate parallel insertion lanes with native beacon footprints | Phase 3 measured speed, productivity and power |
| quality_sorting — Quality Reliquary Sorting Rite | Per-quality filter-separated lanes and destinations | Phase 4, Space Age/modded availability only |
| space_platform — Void Platform Axiomata | Compact closed-loop asteroid/product handling on platform surfaces | Phase 4 with native Space Age world rules |

Social doctrine can express preferences; **no automatic personality-driven retasking**. The original 1268/1269 manual-preview interfaces still accept an explicit engineering style. The 1410 opt-in/current-object workflow now reads the **actual registered planning priest's current Conclave doctrine** as a *soft site-ranking preference only* (see [Priest-Doctrinal JIT 1410](PRIEST_DOCTRINAL_FACTORY_JIT_1410.md)); it NEVER issues construction, reassigns workers, overrides the player's native structures, changes social scores, or replans an unfinished object. These are distinct boundaries. Future full factory style detection may use explicit engineering settings or observed player infrastructure, not involuntary ideology-based physical construction.

## Route correctness rules and acceptance state machine

1. **demand-observed:** Actual enabled force recipe, machine input need and/or factory SPM gap; validate item vs fluid, source/sink ownership and machine accessibility.
2. **endpoints-resolved:** Both are real entities on the intended surface/force. Machine ports and exact drill output/inserter pickup/drop positions observed. No synthetic source.
3. **native-candidate-valid:** Directed path and orientation with each placement approved by Factorio. Account for two lanes, turns, mixed items, supply/demand, inserter reach, boundaries, underground pairing, and reserves for future expansion.
4. **reserved-and-dispatched:** Existing 0601/0510/0338 authority granted construction, one physical belt/inserter at a time; all item withdrawals are counted; preemption is forbidden.
5. **physically-built:** Every route entity observed by native object name/direction/position after the 0338 receipt. A ghost or one belt near a furnace is explicitly incomplete.
6. **transport-observed:** Verify route orientation, actual native inserter source and sink, item appears downstream and leaves source without double counting; demand consumed by correct machine. Detect deadlocks, belt backups and false-positive cycling.
7. **sustained:** For a bounded engine test interval track supply rate, consumer use, SPM, stalled/idle fraction and conservation with real production plus actual machine energy/fuel. Splitter or loops require extra proof.

A route is not "connected" because every tile has a belt, because a stationary item rests on a lane, or because the target item is coincidentally present in a stock chest.

## Phased implementation and blocking tests

**P0 — this iteration:** Audit legacy 0360/0644/0510/0338 and 14 doctrine camps; document native runtime API assumptions; commit a read-only, nonregistered contract and unit tests. Existing engine CI must remain unchanged in behavior. Legacy manual 0360 ghost demo stays visible as a demo, not silently counted as a route.

**P1 — first physical transport vertical slice:** Mine iron -> actual drill output receiver -> 1-2 inserters -> 4-12 correctly oriented belts -> real furnace inlet. Test direct insertion alternative, missing fuel, invalid build site, foreign surface/force, source shortage, reserve denial, save/reload, inventory conservation. No unrelated science chains.

**P2 — factory graph:** Actual furnace output -> science assembler input -> downstream inserter -> belt -> lab; recipe topology (modded outputs/quality), item types and real SPM demand. Demonstrate 5 SPM each automation/logistic/military with native supplied labs and power on original 216k test. Prefer stocked construction materials over emergency manufacturing.

**P3 — real routing expansion:** Underground, splitters, merging, lane assignment, main bus, local cell, roboport/rail boundaries, throughput analysis. Negatives: reversed belt, underground mismatched pair, crossing collisions, blocked machine output, mixed-item jam, inaccessible inserter, no native electricity, destroyed segments and save/reload.

**P4 — advanced doctrine strategies:** Sushi/circuits, balancers, quality, beacon optimization, Space Age where installed. Guard modded recipes and special surfaces. Regression performance budget: bound graph/routing nodes, scans, ghost count and dispatcher claims; never scan whole maps every tick.

**Release acceptance:** (a) authoritative source tests pass; (b) Factorio 2.0.77 native construction/transport/consumption and count conservation pass; (c) existing science/power tests still run; (d) interrupted route reopens safely after save/reload; (e) no pre-existing construction worker, cargo, robot, rail, defense or boiler duties stolen. Missing end-to-end evidence remains an explicit development blocker.

### Design decisions postponed pending empirical evidence

- Whether source selection should be inventory-first, output-entity-first or a weighted hybrid under existing machine logistics.
- Exact lane-separation/sideload rules for mixed quality and modded belt stacking.
- Which native 2.0.77 transport line/inserter reads are always available on modded prototypes.
- Whether a destination needs short-term chest buffering or direct inserter first, based on measured stall rates and source/consumer balance.
- How to preserve existing manual 0360 ghost demo while preventing any autonomous scheduler from treating it as functional connectivity.
