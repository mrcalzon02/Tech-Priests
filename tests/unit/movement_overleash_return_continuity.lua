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
  and request.ground_route_final_destination
  and request.ground_route_final_destination.x==0
  and request.x==122 and request.y==0,
  "headless safety return was not split into a real short waypoint")
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
local rejected,why=Movement.request(pair,{x=0,y=20},
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
  and pair.movement_request_0418.ground_route_final_destination.x==6,
  "relocated station final target not adopted")
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
Movement.stop(pair,"test-reset")
priest.position={x=108,y=0}
game.tick=1800
ok,reason=Movement.enforce_pair(pair,"headless-recovery")
check(ok and reason=="overleash-return","long safety return not admitted")
local route=pair.movement_request_0418
check(route and route.ground_route_chunked
  and route.ground_route_final_destination.x==6 and route.x==90,
  "long return has no persistent headless waypoint plan")
local hops=0
while hops<8 do
  local x,y=route.x,route.y
  Movement.service({},10)
  priest.position={x=x,y=y}
  game.tick=game.tick+20
  Movement.service({},10)
  hops=hops+1
  if math.abs(route.x-6)<0.01 then break end
  check(route.x<x,"waypoint did not advance toward the final station")
end
check(route.x==6 and hops>=5,"short waypoints failed to reach final destination")
check(route.ground_route_final_destination.x==6,
  "intermediate hops overwrote final destination identity")
-- The test harness must advance the mocked priest onto the final point;
-- assigning that waypoint is not itself physical arrival.
priest.position={x=route.x,y=route.y}
game.tick=game.tick+10
Movement.service({},10)
check(pair.movement_controller_state_0418=="loitering",
  "arrival at final waypoint did not finish navigation")
-- 0873: the real 0851 Junior carrier needs to deliver a counted mined item
-- over 200 tiles to its Magos, not be continuously forced back to its own
-- Junior station by generic 0566 overleash enforcement.
Movement.stop(pair,"0873-setup")
local force={name="player"}
station.force=force
priest.force=force
local magos_station={valid=true,unit_number=90,
  name="planetary-magos-cogitator-station",
  position={x=-240,y=0},surface=surface,force=force}
local magos_priest={valid=true,unit_number=91,position={x=-240,y=0},
  surface=surface,force=force}
storage.tech_priests.pairs_by_station[90]={
  station=magos_station,priest=magos_priest}
local stage={
  id="reversal-leaf:22:9",phase="to-magos",
  station_item="junior-cogitator-station",
  leaf_station_unit=9,leaf_priest_unit=99,
  worker_station_unit=7,worker_priest_unit=8,
  relocation_old_station_unit_0823=9}
storage.tech_priests.station_expansion_0256={
  [22]={id=22,status="active",station_item="senior-cogitator-station",
    worker_station_unit=90,reversal_stage_0851=stage,
    reversal_plan_0850={status="leaf-first-preflight-only",
      root_station_unit=90,
      stages={{item="junior-cogitator-station",
        station_unit=9,parent_station_unit=7}}}}
}
local old_station={valid=false}
storage.tech_priests.station_relocation_0823={
  [9]={status="staged",reversal_leaf_0851=true,
    old_unit=9,old_station=old_station,worker_unit=7,
    priest_unit=99,priest={valid=true,unit_number=99}}}
local physical={valid=true,held=1}
physical.get_item_count=function(item)
  assert(item=="junior-cogitator-station")
  return physical.held
end
storage.tech_priests.station_cargo_0824={
  [stage.id]={record_id=stage.id,station_unit=7,priest_unit=8,
    item="junior-cogitator-station",surface=surface,force=force,
    inventory=physical,status="carrying"}}
priest.position={x=-120,y=0}
game.tick=2100
check(Movement.request(pair,magos_station.position,
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=600,radius=2}),
  "physical Junior carrier return must enter normal movement controller")
local recovery_route=pair.movement_request_0418
local blocked,why=Movement.enforce_pair(pair,"reversal-physical-custody")
check(not blocked and why=="reversal-physical-cargo-return-owned"
  and pair.movement_request_0418==recovery_route,
  "generic overleash cannot override one real station-item return")
check((storage.tech_priests.station_cargo_0824[stage.id].inventory.held)==1,
  "movement arbitration cannot debit protected physical station item")
-- A generic high-priority safety route may be released ONLY after the
-- independent lease and physical inventory are revalidated.
Movement.stop(pair,"0873-safety-injection")
check(Movement.request(pair,station.position,
  "movement-enforcement-overleash-return-0566",
  {owner="movement-controller-enforcement-0566",priority=840,
    ttl=600,bounds_exempt=true}),
  "ordinary safety route fixture missing")
local released,released_why=Movement.enforce_pair(pair,"verified-cargo")
check(released and released_why=="reversal-cargo-safety-handoff"
  and pair.movement_request_0418==nil,
  "revalidated item may release only generic overleash safety path")
-- No item -> no exception: the real 0566 emergency return must prevail.
physical.held=0
game.tick=2200
local imposed,imposed_why=Movement.enforce_pair(pair,"lost-real-cargo")
check(imposed and imposed_why=="overleash-return"
  and pair.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "missing station item must restore genuine 0566 safety enforcement")
-- A false or foreign priest lease must never confer movement authority.
physical.held=1
storage.tech_priests.station_relocation_0823[9].priest_unit=1234
game.tick=2289
local held,held_why=Movement.enforce_pair(pair,"wrong-original-priest")
check(not held and held_why=="overleash-return-in-progress",
  "forged original-priest lease must not displace existing safety path")
-- A failed engine-inventory readback cannot crash enforcement or exempt
-- the physical carrier from its ordinary high-priority safety return.
storage.tech_priests.station_relocation_0823[9].priest_unit=99
Movement.stop(pair,"0873-unreadable-inventory-test")
physical.get_item_count=function() error("inventory became unreadable") end
game.tick=2380
local safety,safety_reason=Movement.enforce_pair(pair,"unreadable-inventory")
check(safety and safety_reason=="overleash-return"
  and pair.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "unreadable physical inventory must fail closed without Lua tick exception")
print("[movement-overleash-regression] PASS scenarios=18 including verified mined-Junior return, lost item and unreadable engine inventory")
