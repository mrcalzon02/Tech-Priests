-- Lua 5.2: completed/aborted construction must release its own
-- priority-968 movement, without cancelling a different owner or cargo.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},distraction={none=0,by_enemy=1}}
_G.TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local Construction=require("scripts.core.construction_planner")
local Movement=require("scripts.core.movement_controller")
local function check(ok,why)
 if not ok then error("construction-terminal-movement: "..why,2)end
end
local surface={index=1}
local force={index=1}
local station={valid=true,name="junior-cogitator-station",unit_number=30,
 surface=surface,force=force,position={x=0,y=0}}
local commandable={valid=true,set_command=function()end}
local priest={valid=true,name="tech-priest",unit_number=31,
 surface=surface,force=force,position={x=0,y=0},commandable=commandable}
local pair={station=station,priest=priest,station_unit=30,radius=35}
storage.tech_priests.pairs_by_station[30]=pair
local other_owner="direct-acquisition-0513"
local current_owner="construction-planner-0338"
local stops=0
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
 request_status=function()return{active=true,owner=current_owner}end,
 stop=function(_,reason)
  check(reason=="construction-terminal-handoff-0338",
    "terminal attempted an unrelated stop reason")
  stops=stops+1
  return true
 end,
}
pair.construction_task_0338={phase="move-site",
 item_name="stone-furnace",entity_name="stone-furnace",
 position={x=5,y=0}}
local first=Construction.abort_pair(pair,"aborted-no-cargo")
check(first and pair.construction_task_0338==nil and stops==1,
 "terminal construction did not retire its own priority lease")
check((Construction.root().stats.terminal_movement_released or 0)==1,
 "successful terminal movement cleanup was not counted")
check(pair.construction_last_task_0338.phase=="aborted",
 "abort was not retained as the terminal result")

pair.construction_task_0338={phase="move-site",
 item_name="stone-furnace",entity_name="stone-furnace",
 position={x=5,y=0}}
current_owner=other_owner
Construction.abort_pair(pair,"aborted-foreign-route")
check(stops==1,"construction cleanup stopped direct acquisition")
check(pair.construction_task_0338==nil,
 "construction terminal cleanup failed with foreign route")

-- Real controller path: do not bypass an active construction worker.
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
pair.construction_task_0338={phase="move-site"}
game.tick=1500
check(Movement.request(pair,{x=7,y=0},"construction-site-0338",
 {owner="construction-planner-0338",priority=968,ttl=720})==true,
 "active construction did not acquire priority-968 movement")
local active=pair.movement_request_0418
local accepted=Movement.request(pair,{x=9,y=0},"direct-acquisition-travel-0513",
 {owner=other_owner,priority=650,ttl=600})
check(accepted==false and pair.movement_request_0418==active,
 "active construction route was unsafely overridden")

-- Simulate a pre-fix save: terminal task cleared, old route retained.
pair.construction_task_0338=nil
accepted=Movement.request(pair,{x=9,y=0},"direct-acquisition-travel-0513",
 {owner=other_owner,priority=650,ttl=600})
check(accepted==true and pair.movement_request_0418.owner==other_owner,
 "orphaned priority-968 movement prevented physical gathering")
local root=storage.tech_priests.movement_controller_0419
check((root.stats.orphaned_construction_routes_released or 0)==1,
 "orphaned construction recovery did not record its release")
Movement.stop(pair,"test-next")

-- Construction's physically removed item must still protect its route.
game.tick=2000
pair.construction_custody_0338={item_name="stone-furnace",count=1}
check(Movement.request(pair,{x=7,y=0},"construction-custody-source-return-0338",
 {owner="construction-planner-0338",priority=968,ttl=720})==true,
 "construction cargo route was not accepted")
local cargo_route=pair.movement_request_0418
accepted=Movement.request(pair,{x=9,y=0},"direct-acquisition-travel-0513",
 {owner=other_owner,priority=650,ttl=600})
check(accepted==false and pair.movement_request_0418==cargo_route
 and pair.construction_custody_0338.count==1,
 "construction cargo was preempted by lower-priority gathering")
Movement.stop(pair,"test-next")

print("[construction-terminal-movement] PASS scenarios=4")
