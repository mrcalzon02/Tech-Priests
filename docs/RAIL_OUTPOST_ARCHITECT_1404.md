# Tech Priests — Rail Outpost Architect 1404

Status: **Read-only capacity optimizer implemented; native multi-car construction and acceptance remain OPEN.**  
Goal: [Remote-resource acquisition #6](https://github.com/mrcalzon02/Tech-Priests/issues/6).  
Related: [Railway/ghost governor](RAIL_INTELLIGENCE_AND_GHOST_GOVERNOR_PLAN_2026-11-13.md), [belt/inserter logistics](BELT_AND_INSERTER_FACTORY_LOGISTICS_ARCHITECTURE_1266.md).

## Ownership and distinction

| Authority | Responsibility | Physical execution |
| --- | --- | --- |
| `master_infrastructure_plan_0644` / `magos_station_expansion` | Cogitator command stations, local workforce, rank, territorial coverage | Original station/0338 construction, physical item accounting |
| `rail_track_frontier_0836` / `rail_route_choice_1403` | Charted rail target, actual rail-end geometry, one paid rail segment, connectivity and eventually trains | Existing `0510 → 0338` only |
| `rail_outpost_layout_1404` | Outpost design: train size, drills, belts, buffers, inserters, station/cell layers | **None**: no objects, ghosts, requests or inventory mutation |
| `belt_logistics_contract_1266` / `factory_doctrine_organization_1268` | Actual/source/sink item flow obligations, native belt and inserter checks | Existing audited physical owners only |

A **Cogitator station** is a Tech Priest command anchor. A **train stop** is a physical rail entity. A **mining outpost** combines both, plus drills, power, rail, loaders, buffered ore storage and a home unloading destination. Never conflate the three.

## Implemented interfaces

- Pure `scripts/core/rail_outpost_layout_1404.lua: plan(observations)`. Searches up to 8 wagon counts and returns a deterministic minimum *modeled* material/space cost candidate meeting requested throughput, train capacity, loader capacity, buffer and drill-placement constraints.
- `remote_rail_outpost_0835.propose_outpost_capacity_1404(pair,measurements)` binds the existing original Magos mission and obtains native Factorio `item.stack_size`, `LuaEntityPrototype.get_inventory_size` for cargo-wagon/chest inventories, and the selected transport-belt prototype `belt_speed`. No guessed 40-slot/50-stack defaults. Stores only primitive proposal `mission.outpost_layout_1404`.
- Newly discovered goals say `outpost_layout_status_1404 = "awaiting-native-throughput-and-site-observations"` until enough credible measurements are supplied. Successful plans are marked `provisional-capacity-layout`, **never** complete.

Required measurements (not magically known from a charted ore entity): source/consumer item demand in items/s, conservative real drill output, count of viable drill locations, train travel-only seconds, target load and unload seconds, observed per-inserter transfer items/s, and return policy (`reversible` = 2 locomotives or `turnaround-loop` = 1). Optional constraints cap car count, actual platform vehicle capacity, loader/chest positions per wagon, reserve factor, and efficiency loss.

## Deterministic sizing

`design_rate = demand_items_per_second × reserve_factor` (default 1.1).  
`drills = ceil(design_rate / drill_items_per_second)`; fail when more than viable real drill sites.  
`train_cycle = travel + load_dwell + unload_dwell`; `trip_batch = design_rate × train_cycle`.  
For each candidate 1–8 cargo wagons, require `wagons × stack_size × wagon_slots >= trip_batch`.  
Per-wagon loaders/unloaders must move `trip_batch/wagons` in the respective dwell windows at the conservatively adjusted inserter rate. Buffers must cover both the volume and physical one-chest-per-loader positions. Belt trunk/spur lane counts are sized for required throughput and bounded. Select the lowest construction-cost **proxy** among feasible candidates; do not claim a global terrain optimum.

Results include locomotives, cargo wagons, drills, buffer chests, feeder/loading/home-unloading inserters, belt trunk/branch lanes, minimum splitters, a remote Cogitator, outpost/home train stops, per-wagon loading cells and throughput/cycle budgets. Train return direction is mandatory.

## Construction layers — plans, NOT ghosts

| Stage | Prerequisites and required native proof |
| --- | --- |
| Survey | Charted natural ore; available drill sites; actual station/track/signal footprint |
| Rails/stops | Paid and connected rails; train platform of sufficient length; correct stop side; actual return route |
| Command/power | Original hierarchy/rank; powered electrical network; authorized outside-station railway task |
| Extraction | Real mining drill construction and counted ore output |
| Belt trunks | Directed native source-to-buffer paths, splitters, real belt throughput |
| Buffer boxes | Native wagon-adjacent clearance and real chest inventory |
| Feeder/loader inserters | Native pickup/drop positions and actual material movement |
| Locomotives/wagons | Exact 0338 paid item receipts, native rolling stock coupling, fuel |
| Home unloading | Real home receiver inventories, belts/inserters and train stop |
| Commissioning | Outbound **and return** train movement; counted natural ore delivery; reload/recovery |

Proposed track, estimated platform length, buffer math or virtual cells **never** count as installed infrastructure. The planner cannot choose precise rail/belt tile positions before the native site/geometry preflight. No blueprint-wide ghost flood is allowed; admitted construction must remain bounded and physically accounted for.

## Testing and acceptance

`tests/unit/rail_outpost_layout_1404.lua` is chained to the existing remote railway unit entrypoint. Source cases cover train sizing, 2-locomotive reversible vs 1-locomotive loop, drill/site insufficiency, short dwell failures, invalid throughput/fluid inputs, belt lane limits, actual Factorio prototypes, foreign mission refusal and **zero create_entity calls**.

**Not yet accepted:** The legacy 0836 constructor still builds one locomotive, one wagon and its initial stop. This new optimizer does not silently extend or override it. A native 2.1.24 test must establish the available item stack/wagon inventory APIs, physical wagon couplings, legally placed rail/stop, per-wagon loading/unloading, measured throughput, true Magos travel both ways and counted ore delivery before expanding the original builder to multiple wagons.

Next: run Lua regression and native smoke, implement **budgeted native observation collection** for ore viability/travel/loading rate and train clearance, then admit only the next fully validated physical layer through the existing 0510/0338 executor. Shared Ghost Admission Governor remains a separate pending global guard.
