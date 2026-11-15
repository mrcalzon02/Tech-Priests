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
pair.machine_logistics_0528={phase="move-to-machine",machine={valid=true}}
pair.canonical_action_0744={owner="single_dispatcher_0510",family="machine-logistics"}
pair.movement_request_0418={owner="repair_executor_0516"}
local route=Repair.service_pair(pair,"selected-original-carrier")
assert(route.detail=="physical-route-owner-retained"and stopped==2
 and not pair.movement_request_0418 and pair.repair_0516==task,
 "stale repair lease kept blocking an already-selected unladen machine carrier")
local force,surface={index=1},{index=1}
local packs=1
local empty={valid=true,get_item_count=function()return 0 end}
local stock={valid=true,get_item_count=function(item)return item=="repair-pack"and packs or 0 end,
 remove=function(spec)assert(spec.name=="repair-pack"and spec.count==1);packs=packs-1;return 1 end}
local foreign={valid=true,force={},surface=surface}
local cache={valid=true,force=force,surface=surface}
local target={valid=true,unit_number=30,name="assembling-machine-1",position={x=1,y=0},
 force=force,surface=surface,health=50,max_health=100}
local worker={station={valid=true,unit_number=10,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=11,position={x=1,y=0}},radius=40,
 movement_request_0418={owner="repair_executor_0516"}}
get_station_inventory=function()return empty end
TechPriestsStorageRoleAuthority0686={generic_storage_sources=function()
 return{{entity=foreign,inv={valid=true,get_item_count=function()error("foreign repair stock read")end}},
  {entity=cache,inv=stock},{entity=cache,inv=stock}}end}
TechPriestsWorkReservations0601={claim=function()return true end,release=function()end}
Repair.service_pair(worker,"canonical-pack",target)
game.tick=game.tick+Repair.pack_interval_ticks+1
Repair.service_pair(worker,"canonical-pack-due",target)
assert(packs==0 and target.health==100 and not worker.repair_pack_custody_0516
 and not worker.movement_request_0418,
 "canonical nearby pack did not debit once and physically repair the real target")
print("PASS canonical repair inventory excludes foreign sources, deduplicates stock and pays for actual health")
