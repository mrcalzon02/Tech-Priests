-- Reproduce the 1.0.4 sandbox symptom as injected position observations.
-- Native movement itself is independently tested in the engine.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000,connected_players={}}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},distraction={none=0,by_enemy=1}}
_G.TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local M=require("scripts.core.movement_controller")
local logs,teleports=0,0
log=function()logs=logs+1 end
local function pair_at(id,x)
 local surface={index=1,valid=true}
 local station={valid=true,unit_number=id,name="junior-cogitator-station",
   position={x=x,y=0},surface=surface}
 local commands={}
 local priest={valid=true,type="unit",unit_number=id+1000,name="junior-tech-priest-belt-immune",
   position={x=x,y=0},surface=surface,commandable={valid=true}}
 priest.commandable.set_command=function(cmd)commands[#commands+1]=cmd end
 priest.teleport=function()teleports=teleports+1;error("physical recovery may not teleport")end
 local pair={station=station,priest=priest,radius=30}
 storage.tech_priests.pairs_by_station[id]=pair
 return pair,commands
end
local pair,commands=pair_at(7,0)
pair.direct_acquisition_custody_0513={item="iron-ore",count=3}
assert(M.request(pair,{x=0,y=0},"direct-acquisition-return-0513",
 {owner="direct-acquisition-0513",radius=.2,priority=650,ttl=2000}))
pair.priest.position={x=18,y=0}
M.service(nil,24)
assert(commands[#commands].type==defines.command.go_to_location)
assert(commands[#commands].distraction==defines.distraction.none)
M.sample(nil,32)
local req=pair.movement_request_0418
game.tick=1005;pair.priest.position={x=30,y=0}
local result=M.sample(nil,32)
assert(result.processed==1 and result.acted==1)
assert(commands[#commands].type==defines.command.stop,"speed governor did not stop real native command")
assert(pair.movement_request_0418==req and req.last_command_tick==0,"stop dropped accepted route")
assert(pair.direct_acquisition_custody_0513.count==3 and pair.priest.unit_number==1007)
assert(M.request_status(pair).status=="clamped")
game.tick=1020;M.service(nil,24)
assert(commands[#commands].type==defines.command.go_to_location,"stopped native path did not resume")
M.sample(nil,32)
game.tick=1025;pair.priest.position={x=165,y=0}
M.sample(nil,32)
assert(commands[#commands].type==defines.command.stop)
local safety=assert(pair.movement_request_0418)
assert(safety.owner=="movement-controller-enforcement-0566")
assert(safety.ground_route_final_destination.x==0)
assert(pair.direct_acquisition_custody_0513.count==3 and teleports==0)
assert(logs<=1,"repeated snap flooded the log")
game.tick=1040;M.service(nil,24)
assert(commands[#commands].type==defines.command.go_to_location)
assert(commands[#commands].destination.x<165)
M.stop(pair,"fixture-reset")
pair.direct_acquisition_custody_0513=nil
pair.priest.position={x=0,y=0}
game.tick=2000
assert(M.request(pair,{x=15,y=0},"ordinary-work",{owner="ordinary",ttl=20}))
M.service(nil,24)
game.tick=2021;M.service(nil,24)
assert(commands[#commands].type==defines.command.stop and not pair.movement_request_0418,"expired lease left native movement active")
-- More active requests than either service's existing budget: every valid
-- original worker must receive a service and a sample over successive slices.
local rows={}
game.tick=3000
for i=1,100 do
 local p,c=pair_at(100+i,i*50);rows[i]={pair=p,commands=c}
 assert(M.request(p,{x=i*50+10,y=0},"ordinary-work",{owner="ordinary",ttl=1200}))
end
for i=1,8 do
 local step=M.service(nil,24);assert(step.processed<=24)
 local sample=M.sample(nil,32);assert(sample.processed<=32)
 game.tick=game.tick+10
end
local root=storage.tech_priests.movement_controller_0419
for _,row in ipairs(rows)do
 assert(#row.commands>0,"active worker starved behind fixed service prefix")
 assert(root.samples[tostring(row.pair.station.unit_number)],"active worker starved behind fixed sample prefix")
end
assert(root.stats.speed_violations==2 and root.stats.high_speed_suppressed==2)
assert(root.stats.maximum_sampled_jump_1510==135 and teleports==0)
print("[movement_native_displacement_1510] PASS native stop, preserved custody, home return, expiry stop, bounded fair service and sampling (100 active requests)")
