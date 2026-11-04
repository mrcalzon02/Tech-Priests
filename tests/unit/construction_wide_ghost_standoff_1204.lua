-- 1204: Real 3x3 ghost geometry can require a priest to stand farther
-- than two tiles from the CENTER but still within two tiles of the EDGE.
-- The builder must reach a collision-clear physical contact before revival.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=5000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}}
prototypes={entity={["assembling-machine-1"]={
 collision_box={{-1.4,-1.4},{1.4,1.4}},type="assembling-machine"}}}
local force={valid=true,index=1,name="player"}
local surface={index=1}
local station={valid=true,unit_number=510,name="junior-cogitator-station",
 position={x=0,y=0},surface=surface,force=force}
local priest={valid=true,unit_number=511,name="junior-tech-priest",
 position={x=7.4,y=0},force=force,surface=surface}
local pair={station=station,priest=priest,station_unit=510}
storage.tech_priests.pairs_by_station[510]=pair
local ghost={valid=true,name="entity-ghost",ghost_name="assembling-machine-1",
 position={x=5,y=0},surface=surface,force=force,unit_number=512,
 selection_box={left_top={x=3.5,y=-1.5},
 right_bottom={x=6.5,y=1.5}}}
local revived={valid=true,unit_number=513,name="assembling-machine-1",
 type="assembling-machine",force=force,surface=surface,position={x=5,y=0}}
local revived_count=0
ghost.revive=function()
 assert(priest.position.x>ghost.selection_box.right_bottom.x+0.5,
  "ghost was revived while actual builder still overlapped its footprint")
 revived_count=revived_count+1
 ghost.valid=false
 return {},revived
end
surface.can_place_entity=function(args)
 return args.name=="junior-tech-priest"
end
local moves={}
_G.tech_priests_request_movement_0418=function(_,position,reason)
 moves[#moves+1]={position=position,reason=reason}
 return true
end
local Construction=require("scripts.core.construction_planner")
local task={phase="move-clear-site",started_tick=game.tick,
 active_started_tick_0338=game.tick,entity_name="assembling-machine-1",
 item_name="assembling-machine-1",position={x=5,y=0},ghost=ghost,
 build_standoff_0338={x=8,y=0},carried={
 item_name="assembling-machine-1",count=1}}
pair.construction_task_0338=task
pair.construction_custody_0338={item_name=task.item_name,count=1}
-- A 2.4-tile center distance formerly forced repeated ghost clearance
-- moves, despite 1.0 tile from the actual 3x3 collision-box edge.
local built=Construction.service_pair(pair,"wide-ghost-contact")
assert(built and built.acted==1 and revived_count==1
 and not pair.construction_task_0338 and not pair.construction_custody_0338
 and task.carried.count==0 and task.built_entity==revived
 and #moves==0,
 "physically clear wide-ghost contact was rejected by center-only reach"..
 " result="..tostring(built and built.detail)..
 " acted="..tostring(built and built.acted)..
 " phase="..tostring(task.phase)..
 " revives="..tostring(revived_count)..
 " custody="..tostring(pair.construction_custody_0338~=nil)..
 " moves="..tostring(#moves)..
 " carried="..tostring(task.carried.count))
-- Non-ghost placement must also select a viable exterior contact, rather
-- than send the builder into the future 3x3 machine's occupied footprint.
game.tick=game.tick+100
priest.position={x=0,y=0}
task={phase="move-site",started_tick=game.tick,
 active_started_tick_0338=game.tick,entity_name="assembling-machine-1",
 item_name="assembling-machine-1",position={x=5,y=0},
 carried={item_name="assembling-machine-1",count=1}}
pair.construction_task_0338=task
pair.construction_custody_0338={item_name=task.item_name,count=1}
local walking=Construction.service_pair(pair,"wide-nonghost-contact")
assert(walking and walking.waiting==1 and #moves==1
 and moves[1].reason=="construction-site-standoff-0338",
 "wide-assembler did not request physical standoff travel")
local contact=moves[1].position
assert(contact.x<3.6 and contact.x<5-2
 and task.build_standoff_0338.x==contact.x
 and task.carried.count==1 and revived.valid,
 "wide-assembler contact was not physically outside its collision footprint")
print("[construction-wide-ghost-standoff-1204] PASS 3x3 native geometry, edge-reach revival and exterior physical approach")
