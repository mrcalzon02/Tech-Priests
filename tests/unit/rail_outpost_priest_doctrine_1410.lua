-- Active Magos doctrine must govern only the NEXT real-outpost component.
-- All six native placements are bounded; no rail ghosts/stock debits.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Outpost=require("scripts.core.remote_rail_outpost_0835")
game={tick=1000}
local force={index=9},surface={index=7,valid=true}
local build_calls=0
surface.can_place_entity=function(spec)
  build_calls=build_calls+1
  return spec.force==force and spec.name~=nil
end
local native_entity=nil
surface.find_entities_filtered=function(spec)
  if native_entity and native_entity.name==spec.name
    and spec.position and native_entity.position.x==spec.position.x
    and native_entity.position.y==spec.position.y then
    return {native_entity}
  end
  return {}
end
surface.create_entity=function()
  error("doctrine planner illegally created an entity or a ghost")
end
local station={valid=true,name="planetary-magos-cogitator-station",
 unit_number=99,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=100,force=force,surface=surface}
local pair={station=station,priest=priest}
local mission={
 status="rail-track-established",root_station_unit=99,
 force_index=9,surface_index=7,target={x=200,y=0},
 outpost_layout_1404={
  read_only=true,construction_authorized=false,
  counts={loading_train_stops=1,remote_cogitator_stations=1}},
}
pair.remote_rail_outpost_0835=mission
storage={tech_priests={pairs_by_station={[99]=pair},
 doctrine_argument_0370={by_station={
  ["99"]={current_camp="main_bus"}}}}}
prototypes={item={
 ["train-stop"]={place_result={name="train-stop"}},
 ["senior-cogitator-station"]={
  place_result={name="senior-cogitator-station"}}}}
_G.TechPriestsStorageRoleAuthority0686={
 generic_item_count=function(_,name)
  return name=="train-stop"or name=="senior-cogitator-station"
    and 1 or 0
 end}
local function check(ok,reason)
  assert(ok,"[rail-outpost-priest-doctrine-1410] "..reason)
end
local function pos(x,y)return{x=x,y=y}end
local stops={
 {role="outpost-stop",entity_name="train-stop",item_name="train-stop",
  position=pos(210,0),direction=4},
 {role="outpost-stop",entity_name="train-stop",item_name="train-stop",
  position=pos(203,4),direction=4},
}
local chosen,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates=stops})
check(chosen and why=="one-virtual-object-proposed"
 and chosen.position.x==210 and chosen.position.y==0
 and chosen.doctrine_key=="main_bus"
 and chosen.doctrine_source=="live-priest-alignment-0370"
 and chosen.planning_priest_unit==100
 and chosen.construction_ghosts==0
 and chosen.physical_build_authorized==false,
 "original Magos main-bus alignment did not choose one aligned stop")
check(build_calls==2,"one planning turn inspected more than two legal sites")
storage.tech_priests.doctrine_argument_0370.by_station["99"].current_camp=
 "mixed_spaghetti"
game.tick=1001
local held,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates={stops[2]}})
check(not held and why=="awaiting-one-original-object"
 and build_calls==2 and mission.outpost_jit_1405.ticket==chosen
 and chosen.doctrine_key=="main_bus",
 "active outpost ticket was replaced after social-doctrine argument")
local rail={valid=true,force=force,surface=surface}
native_entity={valid=true,name="train-stop",unit_number=505,
 position=pos(203,4),force=force,surface=surface,
 connected_rail=rail}
game.tick=1002
local adopted,why=Outpost.propose_next_outpost_object_1405(pair,{
 native_entity=native_entity})
check(not adopted and why=="native-object-accepted-rethink-after-interval"
 and not mission.outpost_jit_1405.ticket
 and mission.outpost_jit_1405.last_native_unit==505,
 "original Magos did not adopt player's live connected train stop")
game.tick=1003
local advanced,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates=stops})
check(not advanced and why=="stage-finished-reinspect-next-interval"
 and mission.outpost_jit_1405.stage==2
 and build_calls==2,
 "outpost planner planned future station before finishing stop")
game.tick=1004
local command={
 {role="command-anchor",entity_name="senior-cogitator-station",
  position=pos(210,0),item_name="senior-cogitator-station"},
 {role="command-anchor",entity_name="senior-cogitator-station",
  position=pos(203,4),item_name="senior-cogitator-station"},
}
local cooling,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates=command})
check(not cooling and why=="planning-interval-not-due"
 and build_calls==2,
 "future stage ran costly native placement checks before cooldown")
game.tick=1063
local after,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates=command})
check(after and why=="one-virtual-object-proposed"
 and after.role=="command-anchor"
 and after.position.x==203 and after.position.y==4
 and after.doctrine_key=="mixed_spaghetti",
 "new stage ignored new live Magos doctrine after player construction")
local n=build_calls
pair.construction_task_0338={phase="move-source"}
game.tick=1064
local forced,why=Outpost.propose_next_outpost_object_1405(pair,{
 candidates=command})
check(not forced and why=="physical-item-custody-preserved"
 and build_calls==n and mission.outpost_jit_1405.ticket==after,
 "active 0338 physical custody was replaced by doctrine replanning")
pair.construction_task_0338=nil
check(pair.construction_request==nil
 and mission.outpost_jit_1405.ticket.physical_build_authorized==false,
 "doctrine advisor issued real physical construction or stole a source")
print("[rail-outpost-priest-doctrine-1410] PASS original live Magos doctrine, 2 bounded native sites, player stop adopted, cooldown, custody, no ghosts")
