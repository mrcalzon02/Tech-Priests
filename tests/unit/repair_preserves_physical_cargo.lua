package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={}}
local pair={station={valid=true},priest={valid=true},
 repair_0516={phase="walk-to-target",target={valid=true}},
 machine_logistics_0528={custody={item="grenade",count=5}},
 movement_request_0418={owner="repair_executor_0516"}}
local stopped=0
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={stop=function(p)
 stopped=stopped+1;p.movement_request_0418=nil;return true end}
local Repair=require("scripts.core.repair_executor_0516")
local task=pair.repair_0516;local cargo=pair.machine_logistics_0528.custody
local r=Repair.service_pair(pair,"broker")
assert(r.detail=="physical-cargo-owner-retained"and stopped==1,
 "independent repair pulse kept its movement lease over physical factory cargo")
assert(pair.repair_0516==task and pair.machine_logistics_0528.custody==cargo and cargo.count==5,
 "repair handoff discarded its pending repair or modified carried ingredients")
pair.movement_request_0418={owner="logistics_machine_fulfillment_0528"}
Repair.service_pair(pair,"broker")
assert(stopped==1 and pair.movement_request_0418.owner=="logistics_machine_fulfillment_0528",
 "repair stopped the actual cargo owner's movement")
print("PASS repair pulses preserve physical factory cargo and release only their own conflicting lease")
