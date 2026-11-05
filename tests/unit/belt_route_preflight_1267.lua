-- 1267: directed native-placement belt route preflight. Exactly observed
-- drill/inserter endpoints, no invented handoff, building or material custody.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
defines={direction={north=0,east=4,south=8,west=12}}
local M=require("scripts.core.belt_route_preflight_1267")
game={tick=25000}
local force={index=1};local enemy={index=2}
local surface={valid=true,index=1}
local other_surface={valid=true,index=2}
local station={valid=true,unit_number=11,position={x=0,y=0},
 force=force,surface=surface}
local priest={valid=true,unit_number=12,position={x=0,y=1},
 force=force,surface=surface}
local pair={station=station,priest=priest,radius=20}
local drill={valid=true,unit_number=15,type="mining-drill",name="burner-mining-drill",
 position={x=0.5,y=0.5},drop_position={x=1.5,y=0.5},
 force=force,surface=surface}
local furnace={valid=true,unit_number=16,type="furnace",name="stone-furnace",
 position={x=9.5,y=0.5},force=force,surface=surface}
local sink_arm={valid=true,unit_number=17,type="inserter",name="burner-inserter",
 position={x=7.5,y=0.5},pickup_position={x=6.5,y=0.5},
 drop_position={x=8.5,y=0.5},drop_target=furnace,
 force=force,surface=surface}
prototypes={item={
 ["iron-ore"]={name="iron-ore"},
 ["transport-belt"]={place_result={name="transport-belt"}}},
 entity={["transport-belt"]={type="transport-belt"}}}
local create_count,inventory_count,placement_count=0,0,0
local obstacle=false
local reject_all=false
local fail_engine=false
surface.can_place_entity=function(req)
 placement_count=placement_count+1
 assert(req.name=="transport-belt"and req.force==force)
 assert(req.direction==defines.direction.north
  or req.direction==defines.direction.east
  or req.direction==defines.direction.south
  or req.direction==defines.direction.west)
 if fail_engine then error("native-placement-surface-unavailable")end
 if reject_all then return false end
 if obstacle and req.position.x==3.5 and req.position.y==0.5 then
  return false
 end
 return true
end
surface.create_entity=function()create_count=create_count+1
 error("belt planner illegally spawned entity")end
local station_fields=0
for _ in pairs(pair)do station_fields=station_fields+1 end
local base_spec={source=drill,sink=furnace,sink_inserter=sink_arm,
 item="iron-ore",rate_per_min=120,doctrine_key="rush_bootstrap"}
local straight,why=M.plan(pair,base_spec)
local Arterial=require("scripts.core.arterial_planner")
local from_arterial,from_arterial_why=Arterial.preview_material_belt_route(pair,base_spec)
assert(from_arterial and not from_arterial_why
 and from_arterial.status=="native-sites-candidate-only"
 and #from_arterial.tiles==#straight.tiles
 and from_arterial.owner_station_unit==11
 and not from_arterial.physical_transport_verified,
 "arterial planner lost the read-only native material belt route integration")
assert(straight and not why and straight.status=="native-sites-candidate-only"
 and straight.belt_entity=="transport-belt"
 and straight.source_handoff=="native-mining-drill-drop"
 and straight.sink_handoff=="native-sink-inserter-pickup"
 and straight.source_unit==15 and straight.sink_unit==16
 and straight.source_inserter_unit==nil
 and straight.sink_inserter_unit==17
 and straight.doctrine_key=="rush_bootstrap"
 and #straight.tiles==6 and straight.required_belt_items==6
 and straight.tiles[1].position.x==1.5
 and straight.tiles[6].position.x==6.5,
 "legitimate physical handoffs could not produce a bounded direct path")
for i,t in ipairs(straight.tiles)do
 assert(t.position.x==i+.5 and t.position.y==.5
  and t.direction==defines.direction.east,
  "direct belt route created an incorrect direction or tile")
end
assert(placement_count>=6 and straight.native_placement_checks>=6
 and straight.read_only and not straight.physical_transport_verified
 and not straight.construction_authorized and not straight.custody_acquired,
 "read-only proposed path falsely claimed working material delivery")
obstacle=true
local rerouted,re_why=M.plan(pair,base_spec)
assert(rerouted and not re_why and #rerouted.tiles>6
 and rerouted.tiles[1].position.x==1.5
 and rerouted.tiles[#rerouted.tiles].position.x==6.5,
 "engine-blocked belt tile did not cause legal detour")
local seen={}
for i,t in ipairs(rerouted.tiles)do
 local tile=t.position
 local k=tile.x..":"..tile.y
 assert(not seen[k],"belt routing looped through an already allocated site")
 seen[k]=true
 assert(not(tile.x==3.5 and tile.y==.5),
  "native engine-refused tile was included in proposed route")
 if i<#rerouted.tiles then
  local next_tile=rerouted.tiles[i+1].position
  local dx,dy=next_tile.x-tile.x,next_tile.y-tile.y
  assert(math.abs(dx)+math.abs(dy)==1,
   "directed conveyor teleported across nonadjacent tiles")
  local direction=dx==1 and 4 or dx==-1 and 12
    or dy==1 and 8 or 0
  assert(t.direction==direction,
   "bend belt orientation disagrees with its physical next tile")
 end
end
local budget,budget_why=M.plan(pair,base_spec,{max_nodes=1})
assert(not budget and budget_why=="native-belt-search-budget-exhausted",
 "exhausted bounded route search returned a fictitious path")
obstacle=false
reject_all=true
local blocked,blocked_why=M.plan(pair,base_spec)
assert(not blocked and blocked_why=="no-native-placeable-belt-route",
 "all Factorio-rejected tiles yielded a supposed usable route")
reject_all=false;fail_engine=true
local no_api,no_api_why=M.plan(pair,base_spec)
assert(not no_api and no_api_why=="native-belt-placement-query-failed",
 "unavailable native placement API was bypassed")
fail_engine=false
sink_arm.drop_target=drill
local wrong_output,wrong_output_why=M.plan(pair,base_spec)
assert(not wrong_output and wrong_output_why=="sink-inserter-not-feeding-sink",
 "incorrect inserter output accepted as consumer connection")
sink_arm.drop_target=furnace
sink_arm.force=enemy
local foreign_arm,foreign_arm_why=M.plan(pair,base_spec)
assert(not foreign_arm
 and foreign_arm_why=="sink-inserter-not-native-or-foreign",
 "foreign factory inserter was adopted as our material sink")
sink_arm.force=force
sink_arm.surface=other_surface
local other_arm,other_arm_why=M.plan(pair,base_spec)
assert(not other_arm and other_arm_why=="sink-inserter-not-native-or-foreign",
 "cross-surface inserter was accepted")
sink_arm.surface=surface
sink_arm.pickup_position={x=1.5,y=.5}
local direct,direct_why=M.plan(pair,base_spec)
assert(not direct
 and direct_why=="same-tile-requires-direct-handoff-not-belt",
 "no-belt direct handoff was incorrectly inflated into a belt route")
sink_arm.pickup_position={x=6.5,y=.5}
local chest={valid=true,unit_number=20,type="container",name="steel-chest",
 position={x=0,y=3},surface=surface,force=force}
local no_source,no_source_why=M.plan(pair,{source=chest,sink=furnace,
 sink_inserter=sink_arm,item="iron-ore",rate_per_min=120})
assert(not no_source
 and no_source_why=="source-needs-observed-output-inserter",
 "a chest was incorrectly credited with a native automatic item drop")
local source_arm={valid=true,unit_number=21,type="inserter",
 name="burner-inserter",force=force,surface=surface,
 position={x=1,y=3},pickup_target=chest,
 drop_position={x=1.5,y=3.5}}
local chest_route,chest_why=M.plan(pair,{source=chest,
 source_inserter=source_arm,sink=furnace,sink_inserter=sink_arm,
 item="iron-ore",rate_per_min=120})
assert(chest_route and not chest_why and
 chest_route.source_handoff=="native-source-inserter-drop"
 and chest_route.source_inserter_unit==21
 and chest_route.tiles[1].position.x==1.5,
 "actual existing source inserter was not used for chest feed")
source_arm.pickup_target=drill
local invalid_source,invalid_why=M.plan(pair,{source=chest,
 source_inserter=source_arm,sink=furnace,sink_inserter=sink_arm,
 item="iron-ore",rate_per_min=120})
assert(not invalid_source
 and invalid_why=="source-inserter-not-picking-from-source",
 "unrelated source inserter was borrowed without actual pickup target")
local original=0;for _ in pairs(pair)do original=original+1 end
assert(original==station_fields and create_count==0 and inventory_count==0
 and pair.construction_request==nil and pair.construction_task_0338==nil
 and pair.structure_construction_requested_item==nil
 and pair.direct_acquisition_custody_0513==nil,
 "candidate belt route illegally acquired world, inventory, priest or construction ownership")
print("[belt-route-preflight-1267] PASS genuine drill/inserter endpoints, oriented direct/detour sites, bounded native collision queries, bad handoffs, no world writes")
