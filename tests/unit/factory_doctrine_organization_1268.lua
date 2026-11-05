-- 1268: all registered doctrinal styles are explicit advisory policies.
-- Read-only factory graph organization and native prototype capacity cannot
-- create world state, presume built trunks or alter social alignments.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.doctrine_map")
local Organization=require("scripts.core.factory_doctrine_organization_1268")
local Arterial=require("scripts.core.arterial_planner")
game={tick=9000}
local force={index=1};local surface={index=1}
local station={valid=true,unit_number=99,name="planetary-magos-cogitator-station",
 force=force,surface=surface,position={x=0,y=0}}
local priest={valid=true,unit_number=100,force=force,surface=surface,
 position={x=0,y=1}}
local pair={station=station,priest=priest}
local before=0;for _ in pairs(pair)do before=before+1 end
local camps=Doctrine.camp_keys()
assert(#camps==14,"doctrine taxonomy changed silently")
for _,key in ipairs(camps)do
 local profile,why=Organization.policy(key)
 assert(profile and not why and profile.key==key
  and profile.name==Doctrine.by_key[key].display_name
  and type(profile.route)=="string"and type(profile.topology)=="string"
  and profile.phase:match("^P%d$")
  and profile.read_only and not profile.construction_authorized
  and profile.advanced_topology_verified==false,
  "doctrine became unverified physical build authority: "..key)
end
local neutral,neutral_why=Organization.policy(nil)
assert(neutral and not neutral_why and neutral.key==nil
 and neutral.route=="neutral-engine-native",
 "priest's social alignment secretly selected engineering layout")
local unknown,unknown_why=Organization.policy("nonexistent-doctrine")
assert(not unknown and unknown_why=="unknown-explicit-factory-doctrine",
 "unregistered doctrine was treated as a real planner profile")
local b,why=Organization.route_preference("main_bus",{x=0,y=0},
 {x=9,y=2},{preferred_axis="horizontal"})
assert(b and not why and b.preferred_axis=="horizontal"
 and b.topology=="shared-parallel-trunks"
 and b.active_scope=="native-legal-local-tie-break-only"
 and not b.construction_authorized,
 "main bus route styling implied a completed bus")
local bad_axis,axis_why=Organization.route_preference("main_bus",
 {x=0,y=0},{x=5,y=2},{preferred_axis="diagonal"})
assert(not bad_axis and axis_why=="invalid-explicit-corridor-axis",
 "unsupported route axis bypassed native cardinal geometry")
local noodle=Organization.route_preference("mixed_spaghetti",
 {x=0,y=0},{x=9,y=2})
local step={x=2,y=0,incoming=4}
local continuing={dx=1,dy=0,value=4}
local bent={dx=0,dy=1,value=8}
local goal={x=5,y=1}
local straight_score=Organization.next_step_score(b,step,continuing,goal)
local bend_score=Organization.next_step_score(b,step,bent,goal)
local noodle_bend=Organization.next_step_score(noodle,step,bent,goal)
local noodle_straight=Organization.next_step_score(noodle,step,continuing,goal)
assert(straight_score<bend_score
 and noodle_bend==noodle_straight
 and bend_score-straight_score>noodle_bend-noodle_straight,
 "main bus and spaghetti doctrines did not rank equal-distance routes differently")
local plan={owner_station_unit=99,nodes={
 {kind="recipe",recipe="gear",ingredients={
  {name="iron-plate",type="item",amount=12},
  {name="water",type="fluid",amount=5}}},
 {kind="recipe",recipe="circuit",ingredients={
  {name="iron-plate",type="item",amount=8},
  {name="copper-cable",type="item",amount=3}}},
 {kind="raw",item="iron-ore",amount=5},
}}
local organized,org_why=Organization.organize_requirements(pair,plan,"main_bus")
assert(organized and not org_why
 and organized.distinct_item_requirements==2
 and organized.shared_trunk_candidates==1
 and organized.batch_inputs[2].item=="iron-plate"
 and organized.batch_inputs[2].planned_batch_units==20
 and organized.batch_inputs[2].consumer_nodes==2
 and organized.delegated_fluid_edges==1
 and organized.status=="abstract-batch-demand-only"
 and organized.measured_spm==nil
 and organized.native_source_sink_links==0
 and not organized.construction_authorized
 and not organized.physical_transport_verified,
 "abstract recipe demand was promoted into working bus lanes or SPM")
local from_arterial=Arterial.material_transport_requirements(pair,plan,"main_bus")
assert(from_arterial and #from_arterial.demands==3,
 "arterial requirements handoff changed under doctrine analysis")
local foreign,foreign_why=Organization.organize_requirements(pair,
 {owner_station_unit=66,nodes=plan.nodes},"sushi")
assert(not foreign and foreign_why=="missing-or-foreign-arterial-plan",
 "foreign station's recipe demand was folded into local transport plans")
prototypes={entity={
 ["transport-belt"]={name="transport-belt",type="transport-belt",
  belt_speed=0.03125},
 ["fast-transport-belt"]={name="fast-transport-belt",
  type="transport-belt",belt_speed=0.0625},
 ["steam-engine"]={name="steam-engine",type="generator"},
}}
local basic,bwhy=Organization.capacity_preflight("transport-belt",600)
assert(basic and not bwhy
 and basic.unstacked_straight_belt_items_per_minute==900
 and basic.provisional_belts==1
 and basic.capacity_model=="native-prototype-unstacked-straight-two-lane"
 and not basic.actual_delivery_proven,
 "native yellow belt prototype speed incorrectly estimated")
local overload=Organization.capacity_preflight("transport-belt",1200)
assert(overload and overload.provisional_belts==2
 and overload.unstacked_straight_belt_items_per_minute==900
 and not overload.construction_authorized,
 "oversubscribed single belt silently gained capacity")
local fast=Organization.capacity_preflight("fast-transport-belt",1800)
assert(fast and fast.provisional_belts==1,
 "native red-belt prototype capacity was ignored")
local wrong,wrong_why=Organization.capacity_preflight("steam-engine",200)
assert(not wrong and wrong_why=="native-transport-belt-prototype-unavailable",
 "generator was mistaken for conveyor belt")
local unknown_speed=prototypes.entity["transport-belt"]
unknown_speed.belt_speed=nil
local unavailable,unavailable_why=
 Organization.capacity_preflight("transport-belt",200)
assert(not unavailable and unavailable_why=="native-belt-speed-unobservable",
 "missing native speed became hardcoded vanilla throughput")
local n=0;for _ in pairs(pair)do n=n+1 end
assert(n==before and pair.construction_request==nil
 and pair.construction_task_0338==nil
 and pair.machine_logistics_custody_0528==nil
 and pair.structure_construction_requested_item==nil,
 "read-only factory organization stole worker custody or mutated station")
print("[factory-doctrine-organization-1268] PASS 14 explicit styles, differing layout scores, shared batch inputs, native belt capacities and no construction")
