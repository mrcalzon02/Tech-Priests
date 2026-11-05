-- 1266 belt/inserter integration preflight: absolutely read-only.
-- Native observations and arterial demand nodes never become construction
-- authority, material custody or an invented item-transfer receipt.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.doctrine_map")
local Belt=require("scripts.core.belt_logistics_contract_1266")
local Arterial=require("scripts.core.arterial_planner")
game={tick=5000}
local force={index=1,name="player"}
local enemy={index=2,name="enemy"}
local surface={index=9}
local far_surface={index=10}
local station={valid=true,unit_number=77,name="planetary-magos-cogitator-station",
 force=force,surface=surface,position={x=0,y=0}}
local priest={valid=true,unit_number=78,force=force,surface=surface,
 position={x=0,y=1}}
local pair={station=station,priest=priest}
local source={valid=true,unit_number=100,name="burner-mining-drill",
 type="mining-drill",force=force,surface=surface,position={x=6,y=3}}
local sink={valid=true,unit_number=101,name="stone-furnace",
 type="furnace",force=force,surface=surface,position={x=14,y=3}}
prototypes={item={["iron-ore"]={name="iron-ore"},
 ["iron-plate"]={name="iron-plate"}},
 fluid={water={name="water"}},
 quality={normal={name="normal"}}}
local world_edits=0
surface.can_place_entity=function()world_edits=world_edits+1
 error("read-only belt observer called construction")end
surface.create_entity=function()world_edits=world_edits+1
 error("read-only belt observer created an entity")end
local original_pair_keys=0
for _ in pairs(pair)do original_pair_keys=original_pair_keys+1 end
local expected_keys=Doctrine.camp_keys()
assert(#expected_keys==14,"doctrine taxonomy unexpectedly lost factory styles")
for _,key in ipairs(expected_keys)do
 local profile,why=Belt.doctrine_profile(key)
 assert(profile and not why and profile.key==key
  and profile.physical_authority==false
  and profile.role=="advisory-planning-classification-only",
  "doctrine was promoted from social data to physical construction authority")
end
local implicit,implicit_why=Belt.doctrine_profile(nil)
assert(not implicit and implicit_why=="no-explicit-engineering-doctrine",
 "priest social personality selected an implicit engineering layout")
local unknown,unknown_why=Belt.doctrine_profile("player-unknown-style")
assert(not unknown and unknown_why=="unknown-engineering-doctrine",
 "unknown doctrine became a guessed main bus")
local plan={
 owner_station_unit=77,
 nodes={
  {kind="recipe",recipe="iron-plate",ingredients={
    {name="iron-ore",type="item",amount=12}}},
  {kind="recipe",recipe="modded-gear",ingredients={
    {name="iron-plate",type="item",amount=8},
    {name="water",type="fluid",amount=15}}},
  {kind="raw",item="copper-ore",amount=20}
 }
}
local requirements,req_why=Arterial.material_transport_requirements(pair,plan,"main_bus")
assert(requirements and not req_why and requirements.status=="requirements-only"
 and requirements.read_only and not requirements.physical_transport_verified
 and requirements.doctrine_key=="main_bus"
 and #requirements.demands==2
 and requirements.fluid_requirements_delegated==1
 and requirements.demands[1].item=="iron-ore"
 and requirements.demands[1].required_amount==12
 and requirements.demands[1].consumer_recipe=="iron-plate"
 and requirements.demands[2].item=="iron-plate"
 and requirements.demands[2].consumer_recipe=="modded-gear"
 and requirements.demands[1].status=="physical-source-and-sink-unresolved",
 "arterial recipe requirements fabricated physical factory transport")
local no_plan,no_plan_why=Arterial.material_transport_requirements(pair,nil)
assert(not no_plan and no_plan_why=="explicit-arterial-plan-required",
 "missing arterial graph became a speculative belt plan")
local other_plan,other_plan_why=Belt.recipe_requirements(pair,
 {owner_station_unit=99,nodes=plan.nodes})
assert(not other_plan and other_plan_why=="missing-or-foreign-arterial-plan",
 "foreign station's recipe graph stole our material flow obligation")
local demand,why=Belt.demand(pair,{item="iron-ore",rate_per_min=120,
 source=source,sink=sink,doctrine_key="direct_insertion",quality="normal"})
assert(demand and not why
 and demand.status=="requires-native-route-preflight"
 and demand.owner_station_unit==77
 and demand.source.unit==100 and demand.sink.unit==101
 and demand.rate_per_min==120 and demand.item=="iron-ore"
 and demand.doctrine_key=="direct_insertion"
 and demand.read_only and not demand.physical_transport_verified
 and not demand.custody_acquired and not demand.construction_authorized,
 "valid actual producer/consumer became a completed or authorized route")
assert(demand.source.position.x==6
 and demand.source.position~=source.position,
 "stored proposal retained mutable native position table")
local missing_source,missing_source_why=Belt.demand(pair,{
 item="iron-ore",rate_per_min=100,sink=sink})
assert(not missing_source and
 missing_source_why=="physical-source-or-sink-unresolved",
 "unbuilt source machine was silently invented")
local zero_rate,zero_why=Belt.demand(pair,{item="iron-ore",
 rate_per_min=0,source=source,sink=sink})
assert(not zero_rate and zero_why=="positive-material-rate-required",
 "zero transport requirement became actionable")
local no_item,no_item_why=Belt.demand(pair,{item="never-registered",
 rate_per_min=60,source=source,sink=sink})
assert(not no_item and no_item_why=="native-item-prototype-unavailable",
 "unknown modded item created a buildable route")
local fluid,fluid_why=Belt.demand(pair,{item="water",
 rate_per_min=60,source=source,sink=sink})
assert(not fluid and fluid_why=="fluid-requires-existing-fluid-planner",
 "item belt planner stole native fluid planner scope")
local no_quality,no_quality_why=Belt.demand(pair,{item="iron-ore",
 rate_per_min=60,quality="mythic",source=source,sink=sink})
assert(not no_quality and no_quality_why=="quality-prototype-unavailable",
 "unknown quality tier became a synthetic item filter")
sink.force=enemy
local foreign,foreign_why=Belt.demand(pair,{item="iron-ore",
 rate_per_min=60,source=source,sink=sink})
assert(not foreign and foreign_why=="foreign-surface-or-force",
 "foreign force accepted as a legitimate downstream consumer")
sink.force=force;sink.surface=far_surface
local wrong_surface,wrong_surface_why=Belt.demand(pair,{item="iron-ore",
 rate_per_min=60,source=source,sink=sink})
assert(not wrong_surface and wrong_surface_why=="foreign-surface-or-force",
 "cross-surface belt transfer silently teleported a material flow")
sink.surface=surface
local same,same_why=Belt.demand(pair,{item="iron-ore",
 rate_per_min=60,source=source,sink=source})
assert(not same and same_why=="identical-transport-endpoints",
 "an entity was allowed to feed its own unconnected belt phantom")
local reads=0
local lines={
 {get_item_count=function(item)reads=reads+1
   assert(item=="iron-ore");return 3 end},
 {get_item_count=function(item)reads=reads+1
   assert(item=="iron-ore");return 2 end},
}
local belt={valid=true,unit_number=130,name="transport-belt",
 type="transport-belt",force=force,surface=surface,
 position={x=10,y=3},
 get_max_transport_line_index=function()return 2 end,
 get_transport_line=function(i)return lines[i]end}
local observation,observation_why=Belt.inspect_belt(belt,"iron-ore")
assert(observation and not observation_why
 and observation.item_count==5 and reads==2
 and observation.lines[1]==3 and observation.lines[2]==2
 and observation.status=="native-belt-items-observed"
 and not observation.physical_transport_verified,
 "native belt lane counts were treated as proven movement/consumption")
belt.get_transport_line=function()error("native API unavailable")end
local api_loss,api_loss_why=Belt.inspect_belt(belt,"iron-ore")
assert(not api_loss and api_loss_why=="native-transport-line-unobservable:1",
 "native transport-line error created a fictitious conveyor count")
belt.get_max_transport_line_index=nil
local no_lines,no_lines_why=Belt.inspect_belt(belt,"iron-ore")
assert(not no_lines and no_lines_why=="native-transport-line-query-unavailable",
 "missing native belt API was replaced with a guessed 2-lane result")
local inserter={valid=true,unit_number=131,name="inserter",
 type="inserter",force=force,surface=surface,position={x=10,y=1},
 pickup_position={x=10,y=2},drop_position={x=10,y=0},
 pickup_target=source,drop_target=sink}
local arm,arm_why=Belt.inspect_inserter(inserter)
assert(arm and not arm_why
 and arm.status=="native-inserter-geometry-observed"
 and arm.pickup_position.y==2 and arm.drop_position.y==0
 and arm.pickup_target.unit==100 and arm.drop_target.unit==101
 and not arm.physical_transport_verified,
 "real inserter geometry was guessed or transfer completion invented")
inserter.drop_position=nil
local broken,broken_why=Belt.inspect_inserter(inserter)
assert(not broken and broken_why=="native-inserter-geometry-unobservable",
 "inserter with unknown native output was approved")
local count=0;for _ in pairs(pair)do count=count+1 end
assert(count==original_pair_keys and world_edits==0
 and pair.construction_request==nil and pair.active_order_0469==nil
 and pair.construction_task_0338==nil and pair.machine_logistics_custody_0528==nil,
 "read-only belt planning illegally mutated state or claimed construction")
print("[belt-logistics-contract-1266] PASS 14 real doctrine names, native item endpoints, source/force/quality gates, belt lane counts, inserter geometry and zero world writes")
