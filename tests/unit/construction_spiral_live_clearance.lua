-- Lua 5.2: a cached empty clearance scan cannot authorize a site after
-- another priest has physically placed a machine in that footprint.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
storage={tech_priests={pairs_by_station={}}}
prototypes={entity={
  ["tech-priests-emergency-assembler"]={
    name="tech-priests-emergency-assembler",type="assembling-machine",
    collision_box={{-0.35,-0.35},{0.35,0.35}}
  }
}}
local force={valid=true,index=1,name="player"}
local station={valid=true,unit_number=1,position={x=0,y=0},force=force}
local machine={valid=true,type="assembling-machine",
  name="tech-priests-emergency-miner",position={x=0.5,y=-2.5}}
local calls=0
local surface={index=1}
station.surface=surface
surface.can_place_entity=function(opts)
  local x,y=opts.position.x,opts.position.y
  return y==-3 and (x==0 or x==-1)
end
surface.find_entities_filtered=function(filters)
  calls=calls+1
  local area=filters.area
  local center_x=(area[1][1]+area[2][1])*0.5
  if center_x==0 then return {machine} end
  return {}
end
_G.TechPriestsScanRouting0610={
  find_entities=function()return {}, "cached-empty-before-miner-placement" end
}
_G.TechPriestsPlanningConstraints0646={
  interior_position_allowed=function()return true end
}
local Planner=require("scripts.core.construction_site_planner")
local pair={station=station,priest={valid=true,position={x=0,y=0}},radius=9}
storage.tech_priests.pairs_by_station[1]=pair
local Queue=require("scripts.core.force_planning_queue")
local pos,why,report,ticket=Planner.plan_spiral(pair,"tech-priests-emergency-assembler","assembler")
assert(not pos and Planner.is_pending(why),"caller advanced the queued spiral")
Queue.pulse({tick=game.tick},1)
pos,why,report,ticket=Planner.plan_spiral(pair,"tech-priests-emergency-assembler","assembler")
assert(pos and pos.x==0 and pos.y==-3,"the original first candidate was not preserved")
local allowed,pending=Planner.authorize(pair,ticket,pos)
assert(not allowed and pending=="placement-pending-live-obstruction",
  "cached pre-miner clearance bypassed live final authority")
game.tick=game.tick+1;Queue.pulse({tick=game.tick},1)
pos,why,report,ticket=Planner.plan_spiral(pair,"tech-priests-emergency-assembler","assembler")
assert(pos and pos.x==-1 and pos.y==-3,"resumption changed original search order")
assert(Planner.authorize(pair,ticket,pos),"replacement site was not live-authorized")
assert(calls>=2,"candidate and replacement sites were not checked live")
assert(machine.valid,"site search modified existing emergency mining equipment")
print("[construction-spiral-live-clearance] PASS scenarios=3")
