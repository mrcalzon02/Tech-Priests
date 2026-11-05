-- 1269: rival factory styles must use the SAME real endpoint and
-- Factorio-native placement constraints, not switch priests by personality.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
defines={direction={north=0,east=4,south=8,west=12}}
local Compare=require("scripts.core.doctrinal_route_comparison_1269")
local Arterial=require("scripts.core.arterial_planner")
game={tick=30000}
local force={index=1};local enemy={index=2}
local surface={valid=true,index=1}
local station={valid=true,unit_number=1,position={x=0,y=0},
 surface=surface,force=force}
local priest={valid=true,unit_number=2,position={x=0,y=1},
 surface=surface,force=force}
local pair={station=station,priest=priest,radius=24}
local drill={valid=true,unit_number=3,name="burner-mining-drill",
 type="mining-drill",surface=surface,force=force,
 position={x=0.5,y=0.5},drop_position={x=1.5,y=0.5}}
local furnace={valid=true,unit_number=4,name="stone-furnace",
 type="furnace",surface=surface,force=force,
 position={x=7.5,y=0.5}}
local arm={valid=true,unit_number=5,name="burner-inserter",
 type="inserter",surface=surface,force=force,
 position={x=6.5,y=0.5},pickup_position={x=5.5,y=0.5},
 drop_position={x=7.5,y=0.5},drop_target=furnace}
prototypes={item={
 ["iron-ore"]={name="iron-ore"},
 ["transport-belt"]={place_result={name="transport-belt"}}},
 entity={["transport-belt"]={type="transport-belt",
 belt_speed=.03125}}}
local calls,world_edits=0,0
local permit=true
surface.can_place_entity=function(spec)
 calls=calls+1
 if not permit then return false end
 return spec.name=="transport-belt"and spec.force==force
end
surface.create_entity=function()
 world_edits=world_edits+1
 error("comparison attempted to build instead of planning")
end
local flow={item="iron-ore",rate_per_min=120,
 source=drill,sink=furnace,sink_inserter=arm}
local keys={"main_bus","mixed_spaghetti","direct_insertion",
 "rush_bootstrap"}
local result,why=Arterial.compare_material_belt_doctrines(pair,flow,keys)
assert(result and not why and result.compared==4
 and result.native_candidate_count==4
 and result.minimum_local_belt_tiles==5
 and result.status=="read-only-doctrine-comparison"
 and result.strategic_winner==nil
 and result.read_only and not result.construction_authorized
 and not result.physical_transport_verified,
 "rival local layouts were mistaken for an approved strategy or built plant")
for i,row in ipairs(result.comparisons)do
 assert(row.key==keys[i]and row.status=="candidate-only"
  and row.route and row.route.doctrine_key==row.key
  and row.route.required_belt_items==5
  and row.route.parallel_belts_indicated==1
  and not row.route.physical_transport_verified
  and not row.construction_authorized,
  "doctrinal comparison changed original physical demand or credited delivery")
end
assert(result.comparisons[1].topology_target=="shared-parallel-trunks"
 and result.comparisons[2].topology_target==
    "minimum-material-local-handoffs"
 and result.comparisons[3].topology_target=="short-machine-to-machine"
 and calls>=20,
 "different real philosophies collapsed into one unlabeled factory style")
local copy_input=true
for k in pairs(flow)do
 if k=="doctrine_key"then copy_input=false end
end
assert(copy_input,"comparison mutated the caller's requested doctrine")
local duplicate,dwhy=Compare.compare(pair,flow,
 {"main_bus","main_bus"})
assert(not duplicate and dwhy=="duplicate-or-implicit-doctrine",
 "same doctrine compared against itself")
local unknown,uwhy=Compare.compare(pair,flow,
 {"main_bus","fabricated-doctrine"})
assert(not unknown and uwhy=="unknown-explicit-factory-doctrine",
 "fictional doctrine affected proposed layout")
local too_many,mwhy=Compare.compare(pair,flow,
 {"main_bus","mixed_spaghetti","direct_insertion",
  "rush_bootstrap","sushi"})
assert(not too_many and mwhy=="compare-two-to-four-explicit-doctrines",
 "unbounded multi-doctrine searches escaped planning budget")
permit=false
local blocked,bwhy=Compare.compare(pair,flow,
 {"main_bus","mixed_spaghetti"})
assert(blocked and not bwhy and blocked.native_candidate_count==0
 and blocked.minimum_local_belt_tiles==nil
 and blocked.comparisons[1].status=="blocked"
 and blocked.comparisons[1].route==nil
 and not blocked.construction_authorized,
 "physically blocked factory site acquired fictional route")
permit=true
furnace.force=enemy
local foreign,fwhy=Compare.compare(pair,flow,
 {"main_bus","mixed_spaghetti"})
assert(foreign and not fwhy
 and foreign.native_candidate_count==0
 and foreign.comparisons[1].blocker=="foreign-surface-or-force",
 "unrelated force's factory became a connected input")
assert(world_edits==0 and pair.construction_task_0338==nil
 and pair.construction_request==nil
 and pair.structure_construction_requested_item==nil
 and pair.machine_logistics_custody_0528==nil,
 "doctrine comparison allocated materials, changed world, or stole custody")
print("[doctrinal-route-comparison-1269] PASS four rival layouts, equal native sites, blocked/foreign rejection, no fake winner or construction")
