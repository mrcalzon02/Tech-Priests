-- Lua 5.2: a cached empty clearance scan cannot authorize a site after
-- another priest has physically placed a machine in that footprint.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=9000}
storage={tech_priests={}}
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
local pos,why=Planner.plan_spiral(pair,"tech-priests-emergency-assembler","assembler")
assert(pos and pos.x==-1 and pos.y==-3,
  "cached pre-miner clearance accepted overlapping x=0 instead of moving to x=-1: "
    ..tostring(pos and pos.x)..","..tostring(pos and pos.y))
assert(calls>=2,
  "no authoritative live scans performed for candidate and replacement sites")
assert(machine.valid,"site search modified existing emergency mining equipment")
print("[construction-spiral-live-clearance] PASS scenarios=3")
