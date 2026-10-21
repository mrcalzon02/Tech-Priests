-- Lua 5.2: a machine's proven physical phase change may replace its own
-- recent waypoint. A mere target change, wrong phase, absent return custody,
-- or another family may not bypass movement debounce or priority.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=2000}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},
 distraction={none=0,by_enemy=1}}
_G.TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local Movement=require("scripts.core.movement_controller")
local function check(ok,why)
 if not ok then error("machine-logistics-phase-handoff: "..why,2)end
end
local surface={index=1}
local force={index=1}
local station={valid=true,unit_number=51,name="junior-cogitator-station",
 force=force,surface=surface,position={x=0,y=0}}
local priest={valid=true,unit_number=52,name="tech-priest",
 force=force,surface=surface,position={x=0,y=0},
 commandable={valid=true,set_command=function()end}}
local machine={valid=true,unit_number=53,name="stone-furnace",
 surface=surface,force=force,position={x=8,y=0}}
local pair={station=station,priest=priest,station_unit=51,radius=32,
 machine_logistics_0528={phase="move-to-station",
  action="supply-fuel",item="coal",machine=machine}}
storage.tech_priests.pairs_by_station[51]=pair
local owner="logistics_machine_fulfillment_0528"
local function move(x,reason,priority)
 return Movement.request(pair,{x=x,y=0},reason,
  {owner=owner,priority=priority or 740,ttl=480,radius=.15})
end
local accepted=move(1.5,"machine-logistics-collect-station-0528")
check(accepted==true,"initial station stock request failed")
local initial=pair.movement_request_0418
game.tick=2001
pair.machine_logistics_0528.phase="move-to-machine"
local changed=move(8,"machine-logistics-move-to-machine-0528")
check(changed==true and pair.movement_request_0418~=initial,
 "real station collection -> machine feed transition was held")
local machine_route=pair.movement_request_0418
check(machine_route.reason=="machine-logistics-move-to-machine-0528",
 "machine supply did not receive the actual destination")
local stats=storage.tech_priests.movement_controller_0419.stats
check((stats.machine_phase_route_handoffs or 0)==1,
 "real physical phase handoff was not counted")

game.tick=2002
local blocked,why=move(10,"machine-logistics-move-to-machine-0528")
check(blocked==false and why=="retarget-held",
 "arbitrary same-phase machine target changed despite active debounce")
check(pair.movement_request_0418==machine_route,
 "same-phase retarget discarded the active machine route")

-- A missing cargo record is not proof the priest can begin returning it.
pair.machine_logistics_0528.phase="return-custody-to-station"
game.tick=2003
blocked,why=move(1.5,"machine-logistics-return-custody-0528")
check(blocked==false and why=="retarget-held",
 "machine return phase bypassed the debounce without physical custody")
check((stats.machine_phase_route_handoffs or 0)==1,
 "unproven custody return was counted as a phase handoff")

local custody={item="iron-ore",count=3}
pair.machine_logistics_0528.custody=custody
pair.machine_logistics_custody_0528=custody
game.tick=2004
changed=move(1.5,"machine-logistics-return-custody-0528")
check(changed==true and pair.movement_request_0418~=machine_route,
 "physically collected output could not immediately begin return")
check(pair.machine_logistics_custody_0528==custody and custody.count==3,
 "return handoff lost physical output")
check((stats.machine_phase_route_handoffs or 0)==2,
 "cargo return phase transition was not measured")

-- Other movement families remain subordinate to a loaded machine return.
local returned=pair.movement_request_0418
local denied,reason=Movement.request(pair,{x=12,y=3},
 "direct-acquisition-travel-0513",
 {owner="direct-acquisition-0513",priority=650,ttl=600})
check(denied==false and reason=="higher-priority-movement-owned",
 "direct mining preempted machine output cargo")
check(pair.movement_request_0418==returned,
 "foreign lower-priority request replaced cargo return")
check((stats.lower_priority_retargets_denied or 0)==1,
 "real foreign priority denial disappeared from telemetry")

print("[machine-logistics-phase-handoff] PASS scenarios=5")
