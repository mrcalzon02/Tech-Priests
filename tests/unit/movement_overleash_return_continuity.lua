-- Lua 5.2 regression: an overleash recovery path must survive enforcement
-- ticks, preserve high-priority ownership, and release on safe return.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={command={stop=1,go_to_location=2},distraction={none=0,by_enemy=1}}
_G.TechPriestsPairBucketRegistry0600={force_bucket=function() end}
local issued={}
local commandable={valid=true,set_command=function(cmd)
  issued[#issued+1]=cmd
end}
local surface={index=1}
local station={valid=true,unit_number=7,name="junior-cogitator-station",
  position={x=0,y=0},surface=surface}
local priest={valid=true,unit_number=8,position={x=140,y=0},
  surface=surface,commandable=commandable}
local pair={station=station,priest=priest,radius=30}
storage.tech_priests.pairs_by_station[7]=pair
local Movement=require("scripts.core.movement_controller")
local function check(ok,why)
  if not ok then error("movement-overleash regression: "..why,2) end
end
local function count(kind)
  local n=0
  for _,cmd in ipairs(issued) do if cmd.type==kind then n=n+1 end end
  return n
end
local ok,reason=Movement.enforce_pair(pair,"test")
check(ok and reason=="overleash-return","initial safety return not accepted")
local request=pair.movement_request_0418
check(request and request.owner=="movement-controller-enforcement-0566"
  and request.x==0 and request.y==0,"safety target/owner incorrect")
Movement.service({},10)
check(count(defines.command.go_to_location)==1,"initial path command absent")
local stopped=count(defines.command.stop)
game.tick=1089
ok,reason=Movement.enforce_pair(pair,"test")
check(not ok and reason=="overleash-return-in-progress",
  "repeated enforcement restarted active safety route")
check(pair.movement_request_0418==request,"active path identity replaced")
check(count(defines.command.stop)==stopped,"repeated enforcement stopped priest")
Movement.service({},10)
check(count(defines.command.go_to_location)==1,
  "engine navigation was restarted despite a live return request")
local accepted=Movement.request(pair,station.position,
  "machine-logistics-return-custody-0528",
  {owner="logistics-machine-fulfillment-0528",priority=610})
check(accepted and pair.movement_request_0418==request,
  "lower-priority same-target request displaced safety route")
check(request.reason=="movement-enforcement-overleash-return-0566",
  "lower-priority request renamed safety route")
local rejected,why=Movement.request(pair,{x=14,y=0},
  "machine-logistics-move-to-machine-0528",
  {owner="logistics-machine-fulfillment-0528",priority=610})
check(not rejected and why=="higher-priority-movement-owned",
  "lower-priority different waypoint stole the live emergency return")
check(pair.movement_request_0418==request,
  "rejected waypoint replaced safety route")
game.tick=1245
ok,reason=Movement.enforce_pair(pair,"test")
check(not ok and reason=="overleash-return-in-progress",
  "stalled safety return was restarted by enforcement")
Movement.service({},10)
check(count(defines.command.go_to_location)==2,
  "genuinely stalled path did not receive a bounded retry")
station.position={x=6,y=0}
game.tick=1260
ok,reason=Movement.enforce_pair(pair,"test")
check(ok and reason=="overleash-return","relocated station not rerouted")
check(pair.movement_request_0418~=request
  and pair.movement_request_0418.x==6,"relocated station target not adopted")
priest.position={x=8,y=0}
game.tick=1280
ok,reason=Movement.enforce_pair(pair,"test")
check(ok and reason=="overleash-return-released",
  "safety route not released inside work envelope")
check(pair.movement_request_0418==nil,"completed safety request still active")
check(Movement.request(pair,{x=20,y=0},"ordinary-work",
  {owner="ordinary-work",priority=50}),"ordinary work did not resume")
Movement.service({},10)
local moving_commands=count(defines.command.go_to_location)
check(moving_commands==3,"ordinary work did not start moving")
priest.position={x=10,y=0}
game.tick=1400
Movement.service({},10)
priest.position={x=12,y=0}
game.tick=1600
Movement.service({},10)
check(count(defines.command.go_to_location)==moving_commands,
  "moving priest's engine path was reset on fixed refresh cadence")
print("[movement-overleash-regression] PASS scenarios=9")
