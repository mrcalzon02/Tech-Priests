-- Lua 5.2: a priest with an unladen direct-mining task must not contest
-- active machine logistics movement, but must resume gathering immediately
-- after machine custody is delivered and the route is released.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},
  distraction={none=0,by_enemy=1}}
prototypes={item={["iron-ore"]={}}}
_G.TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local Movement=require("scripts.core.movement_controller")
local Direct=require("scripts.core.direct_acquisition_executor_0513")
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
local attempted=0
_G.tech_priests_request_movement_0418=function(pair,pos,reason,opts)
 attempted=attempted+1
 return Movement.request(pair,pos,reason,opts)
end
local function check(ok,why)
 if not ok then error("direct-machine-movement-ownership: "..why,2)end
end
local surface={index=1}
local force={index=1,name="player"}
local station={valid=true,unit_number=7,name="junior-cogitator-station",
 surface=surface,force=force,position={x=0,y=0}}
local priest={valid=true,unit_number=8,name="tech-priest",
 surface=surface,force=force,position={x=1,y=0},
 commandable={valid=true,set_command=function()end}}
local ore={valid=true,unit_number=9,name="iron-ore",type="resource",
 surface=surface,position={x=12,y=0},amount=50,
 force={index=2,name="neutral"}}
local task={output_item="iron-ore",required_count=1,
 current={kind="direct-mine-0336",entity=ore,output_item="iron-ore"}}
local pair={station=station,priest=priest,station_unit=7,radius=32,
 emergency_craft=task,mode="travelling-to-direct-acquisition"}
storage.tech_priests.pairs_by_station[7]=pair
local machine={valid=true,unit_number=10,name="tech-priests-emergency-miner",
 type="assembling-machine",position={x=5,y=0},surface=surface,force=force}
local custody={item="iron-ore",count=3,kind="retention"}
pair.machine_logistics_0528={phase="return-custody-to-station",
 action="clear-output",machine=machine,item="iron-ore",custody=custody}
pair.machine_logistics_custody_0528=custody
check(Movement.request(pair,{x=3,y=0},"machine-logistics-return-custody-0528",
 {owner="logistics_machine_fulfillment_0528",priority=740,ttl=480})==true,
 "machine logistics failed to acquire its legitimate route")
local incumbent=pair.movement_request_0418
local stats=storage.tech_priests.movement_controller_0419.stats
for i=1,30 do
 game.tick=game.tick+5
 local acted,why=Direct.service_pair(pair,"test-machine-busy")
 check(acted==false and why=="waiting-machine-logistics-route",
   "unladen direct executor did not report waiting instead of movement failure")
 check(pair.movement_request_0418==incumbent,
   "direct acquisition retargeted live machine movement")
 check(task.current and pair.emergency_craft==task,
   "unladen direct task was lost during machine custody delivery")
end
check((stats.lower_priority_retargets_denied or 0)==0,
 "direct executor still generated priority-740 movement denials")
check(attempted==0,
 "direct executor still submitted redundant movement requests")
check((Direct.root().stats["machine-route-yields-0513"] or 0)==30,
 "legitimate machine-route waits were not counted")
check(pair.machine_logistics_custody_0528==custody and custody.count==3,
 "direct acquisition destroyed machine output custody")
check(Direct.machine_route_has_movement(pair)==true,
 "machine custody active status was not recognized")

-- Cargo takes precedence. Never yield physical mined custody to the machine.
pair.direct_acquisition_custody_0513={item="iron-ore",count=2}
check(Direct.machine_route_has_movement(pair)==false,
 "direct cargo-return custody was incorrectly suppressed")
pair.direct_acquisition_custody_0513=nil

-- The task's terminal phase must not produce phantom routing ownership.
pair.machine_logistics_0528.phase="complete"
check(Direct.machine_route_has_movement(pair)==false,
 "terminal machine task continued blocking direct mining")
pair.machine_logistics_0528.phase="return-custody-to-station"
Movement.stop(pair,"machine-logistics-terminal-0528")
pair.machine_logistics_custody_0528=nil
pair.machine_logistics_0528.phase="complete"
game.tick=1250
local acted,why=Direct.service_pair(pair,"test-machine-released")
check(acted==true and why=="walking",
 "direct acquisition did not resume when physical machine route retired")
check(attempted==1 and pair.movement_request_0418
 and pair.movement_request_0418.owner=="direct-acquisition-0513",
 "restored mining did not acquire its own movement route")
check((stats.lower_priority_retargets_denied or 0)==0,
 "handoff generated a priority conflict even after release")

-- A valid foreign construction route must not be mislabeled machine custody.
Movement.stop(pair,"test-construction")
game.tick=1300
pair.machine_logistics_0528.phase="return-custody-to-station"
pair.machine_logistics_custody_0528=custody
check(Movement.request(pair,{x=4,y=0},"construction-site-0338",
 {owner="construction-planner-0338",priority=968,ttl=720})==true,
 "construction fixture route was denied")
check(Direct.machine_route_has_movement(pair)==false,
 "machine logistics falsely owned a construction path")
check(custody.count==3,"foreign route changed the machine cargo")
print("[direct-machine-movement-ownership] PASS scenarios=5")
