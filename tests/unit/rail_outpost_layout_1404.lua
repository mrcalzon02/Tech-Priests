-- Outpost sizing is read-only and independent from rail/physical builders.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Layout=require("scripts.core.rail_outpost_layout_1404")
local function check(ok,msg)
  assert(ok,"[rail-outpost-layout-1404] "..msg)
end
local observation={
  item="iron-ore",item_type="item",
  demand_items_per_second=12,drill_items_per_second=2,
  ore_drill_sites=20,train_travel_seconds=160,
  loading_seconds=30,unloading_seconds=30,
  belt_items_per_second=15,inserter_items_per_second=20,
  item_stack_size=50,wagon_slots=40,chest_slots=48,
  max_wagons=8,train_direction_policy="reversible",
  max_train_vehicles=4,
}
local p,why=Layout.plan(observation)
check(p and why=="provisional-layout-computed","baseline capacity plan missing")
check(p.counts.cargo_wagons==2 and p.counts.locomotives==2
  and p.train_vehicle_count==4,"wrong physically sized train")
check(p.counts.drills==7 and p.counts.belt_trunk_lanes==1,
  "wrong feed capacity from measured drill/belt rate")
check(p.counts.loading_buffer_chests==8
  and p.counts.loading_inserters==8
  and p.counts.feed_inserters==8
  and p.counts.home_unloading_inserters==8,
  "per-wagon loading buffers/inserters incorrectly sized")
check(p.target_batch_items>2900 and p.target_batch_items<3000
  and p.full_train_capacity_items==4000,
  "train cycle and reserve factor incorrectly sized")
check(#p.cells==2 and #p.layers>=9 and #p.unresolved>0
  and p.ghosts_created==0 and p.read_only==true
  and p.construction_authorized==false and p.native_site_verified==false
  and p.physical_transport_verified==false,
  "sizing plan confused virtual proposal with built outpost")
check(observation.max_wagons==8 and not observation.counts,
  "optimizer changed supplied observations or invented inventory")

local cannot,reason=Layout.plan(setmetatable({
  max_wagons=1},{__index=observation}))
check(not cannot and reason=="no-feasible-train-and-loader-combination",
  "one undersized wagon accepted insufficient train carrying capacity")
cannot,reason=Layout.plan(setmetatable({
  max_train_vehicles=3},{__index=observation}))
check(not cannot and reason=="no-feasible-train-and-loader-combination",
  "locomotives and wagons exceeded actual platform vehicle cap")
local loop=Layout.plan(setmetatable({
  max_train_vehicles=3,train_direction_policy="turnaround-loop"},
  {__index=observation}))
check(loop and loop.counts.locomotives==1 and loop.counts.cargo_wagons==2,
  "turnaround-loop layout did not change counted locomotive requirements")
cannot,reason=Layout.plan(setmetatable({
  ore_drill_sites=3},{__index=observation}))
check(not cannot and reason=="drill-capacity-or-real-sites-insufficient",
  "planner fabricated mining sites")
cannot,reason=Layout.plan(setmetatable({
  max_wagons=2,loading_seconds=4},{__index=observation}))
check(not cannot and reason=="no-feasible-train-and-loader-combination",
  "impossibly fast train loading accepted")
cannot,reason=Layout.plan(setmetatable({
  train_direction_policy="unverified"},{__index=observation}))
check(not cannot and reason=="train-return-direction-not-specified",
  "train without a valid return policy accepted")
cannot,reason=Layout.plan(setmetatable({
  demand_items_per_second=0/0},{__index=observation}))
check(not cannot and reason=="missing-or-invalid-demand_items_per_second",
  "nonfinite throughput reached construction planning")
cannot,reason=Layout.plan(setmetatable({
  item_type="fluid"},{__index=observation}))
check(not cannot and reason=="item-only-outpost-required",
  "fluid wagon incorrectly modeled as cargo-wagon item inventory")
cannot,reason=Layout.plan(setmetatable({
  belt_items_per_second=0.01},{__index=observation}))
check(not cannot and reason=="belt-lane-budget-exceeded",
  "unbounded belt spam admitted")
-- Actual Tech Priests goal integration reads prototype capacities, not
-- hardcoded wagon inventory or constructed loading positions.
local previous={
  game=game,storage=storage,prototypes=prototypes,defines=defines,
}
local goals=require("scripts.core.remote_rail_outpost_0835")
local force={index=3}
local surface={index=4}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=301,position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=302,surface=surface,force=force}
local pair={station=station,priest=priest}
pair.remote_rail_outpost_0835={
  status="starvation-confirmed",root_station_unit=301,
  force_index=3,surface_index=4,
  target={x=512,y=0},item="iron-ore",
}
game={tick=9000}
storage={tech_priests={pairs_by_station={[301]=pair}}}
defines={inventory={chest=1,cargo_wagon=2}}
local created=0
surface.create_entity=function()created=created+1;error("ghost/entity created")end
prototypes={
  item={["iron-ore"]={stack_size=50}},
  entity={
    ["cargo-wagon"]={get_inventory_size=function(index)
      check(index==2,"wagon inventory index mismatched")
      return 40 end},
    ["steel-chest"]={get_inventory_size=function(index)
      check(index==1,"chest inventory index mismatched")
      return 48 end},
    ["transport-belt"]={type="transport-belt",belt_speed=0.03125},
  },
}
local plan,why=goals.propose_outpost_capacity_1404(pair,{
  demand_items_per_second=12,drill_items_per_second=2,
  ore_drill_sites=20,train_travel_seconds=160,
  loading_seconds=30,unloading_seconds=30,
  inserter_items_per_second=20,max_train_vehicles=4,
  train_direction_policy="reversible",
})
check(plan and why=="provisional-layout-computed"
  and plan.root_station_unit==301
  and plan.surface_index==4 and plan.force_index==3
  and plan.destination.x==512 and plan.counts.cargo_wagons==2
  and plan.counts.belt_trunk_lanes==1
  and plan.metric_authority=="supplied-capacity-estimates-native-prototypes-only"
  and pair.remote_rail_outpost_0835.outpost_layout_1404==plan
  and pair.construction_request==nil and created==0,
  "prototype-driven read-only integration made an invalid construction plan")
-- A mismatched force cannot inherit another original Magos outpost.
pair.remote_rail_outpost_0835.force_index=900
local denied,why=goals.propose_outpost_capacity_1404(pair,{})
check(not denied and why=="outpost-original-rail-mission-unavailable",
  "foreign mission claimed home station capacity")
pair.remote_rail_outpost_0835.force_index=3
prototypes.entity["cargo-wagon"].get_inventory_size=nil
denied,why=goals.propose_outpost_capacity_1404(pair,{})
check(not denied and why=="outpost-native-prototypes-unobservable",
  "missing native wagon capacity was silently fabricated")
check(created==0,"native outpost planner created ghosts or other entities")
storage.tech_priests.pairs_by_station[301]=nil
denied,why=goals.propose_outpost_capacity_1404(pair,{})
check(not denied and why=="outpost-magos-or-measurements-missing",
  "unregistered or orphaned Magos received outpost construction plan")
game,storage,prototypes,defines=previous.game,previous.storage,
  previous.prototypes,previous.defines
print("[rail-outpost-layout-1404] PASS wagon counts, ore/belt/inserter buffers, staged design, native prototype readback, no ghosts")
