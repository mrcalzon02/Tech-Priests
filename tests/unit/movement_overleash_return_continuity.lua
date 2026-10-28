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
-- 0886: Intermediate's assigned second-Junior recovery is a genuine
-- 180-tile outbound trip, not an illegal ordinary 56-tile excursion.
-- Preserve only the original priest and the exact 0853 controller route.
-- The earlier first-Junior station must already be in one real Magos depot.
Movement.stop(pair,"0886-first-stage-done")
stage.phase="in-magos-depot"
storage.tech_priests.station_cargo_0824[stage.id]=nil
storage.tech_priests.pairs_by_priest={
  [8]=pair
}
local first_inventory={valid=true}
first_inventory.get_item_count=function(item)
  check(item=="junior-cogitator-station","wrong first depot item")
  return 1
end
storage.tech_priests.station_reversal_depot_0852={
  [stage.id]={
    record_id=stage.id,item="junior-cogitator-station",status="stored",
    magos_station_unit=90,magos_priest_unit=91,
    worker_station_unit=7,worker_priest_unit=8,
    leaf_station_unit=9,leaf_priest_unit=99,
    force=force,surface=surface,inventory=first_inventory
  }
}
local middle_station={valid=true,unit_number=70,
  name="intermediate-cogitator-station",force=force,surface=surface,
  position={x=180,y=0}}
local middle_priest={valid=true,unit_number=71,force=force,surface=surface,
  position={x=300,y=0},commandable=commandable}
local middle={station=middle_station,priest=middle_priest,radius=38}
storage.tech_priests.pairs_by_station[70]=middle
local second_station={valid=true,unit_number=72,
  name="junior-cogitator-station",force=force,surface=surface,
  position={x=360,y=0}}
local second_priest={valid=true,unit_number=73,
  position={x=360,y=0},force=force,surface=surface}
storage.tech_priests.pairs_by_station[72]={
  station=second_station,priest=second_priest
}
storage.tech_priests.pairs_by_priest[71]=middle
local rec=storage.tech_priests.station_expansion_0256[22]
rec.reversal_plan_0850.stages[2]={
  item="junior-cogitator-station",station_unit=72,
  parent_station_unit=70
}
local second={
  id="reversal-ancestor:22:2:72",reversal_stage_index=2,
  station_item="junior-cogitator-station",phase="to-leaf",
  leaf_station_unit=72,leaf_priest_unit=73,
  worker_station_unit=70,worker_priest_unit=71,
  relocation_old_station_unit_0823=72
}
rec.reversal_stage_0853=second
game.tick=2700
check(Movement.request(middle,second_station.position,
  "station-recovery-leaf-0853",{
    owner="station-recovery-0853",priority=45,ttl=600,radius=2}),
  "legitimate 0853 outbound route refused by controller")
local outbound=middle.movement_request_0418
local allowed,allowed_why=Movement.enforce_pair(middle,"second-junior-outbound")
check(not allowed and allowed_why=="second-reversal-physical-leaf-owned"
  and middle.movement_request_0418==outbound,
  "ordinary 56-tile leash interrupted 180-tile verified second Junior approach")
Movement.stop(middle,"0886-safety-fixture")
check(Movement.request(middle,middle.station.position,
  "movement-enforcement-overleash-return-0566",{
    owner="movement-controller-enforcement-0566",
    priority=840,ttl=600,bounds_exempt=true}),
  "generic outbound safety fixture missing")
local released2,why2=Movement.enforce_pair(middle,"second-junior-safety-handoff")
check(released2 and why2=="second-reversal-safety-handoff"
  and middle.movement_request_0418==nil,
  "only exact real reversal may release an existing generic return")
-- Losing the first real depot must reinstate ordinary safety immediately.
first_inventory.valid=false
game.tick=2710
local denied,denied_why=Movement.enforce_pair(middle,"first-depot-lost")
check(denied and denied_why=="overleash-return"
  and middle.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "missing previous physical depot must prohibit 0853 leash exception")
first_inventory.valid=true
game.tick=2720
local released3,why3=Movement.enforce_pair(middle,"first-depot-restored")
check(released3 and why3=="second-reversal-safety-handoff",
  "restored genuine depot did not allow the original recovery journey")
-- A return to Magos is permitted only after a real 0823 mine and an
-- independently readable engine-owned 0824 cargo count of exactly one.
second.phase="to-magos"
second_station.valid=false
storage.tech_priests.pairs_by_station[72]=nil
storage.tech_priests.station_relocation_0823[72]={
  status="staged",reversal_ancestor_0853=true,
  old_unit=72,old_station=second_station,worker_unit=70,
  priest_unit=73,priest=second_priest
}
local second_inventory={valid=true,held=1}
second_inventory.get_item_count=function(item)
  check(item=="junior-cogitator-station","wrong loaded recovered station")
  return second_inventory.held
end
storage.tech_priests.station_cargo_0824[second.id]={
  record_id=second.id,station_unit=70,priest_unit=71,
  item="junior-cogitator-station",surface=surface,force=force,
  inventory=second_inventory,status="carrying"
}
middle_priest.position={x=360,y=0}
game.tick=2750
check(Movement.request(middle,magos_station.position,
  "station-recovery-return-0853",{
    owner="station-recovery-0853",priority=56,ttl=600,radius=2}),
  "real loaded 0853 return not admitted")
local inbound=middle.movement_request_0418
local in_ok,in_why=Movement.enforce_pair(middle,"second-junior-real-loaded-return")
check(not in_ok and in_why=="second-reversal-physical-return-owned"
  and middle.movement_request_0418==inbound
  and second_inventory.held==1,
  "generic leash overrode legitimate counted second Junior cargo")
second_inventory.held=0
game.tick=2790
local cargo_blocked,cargo_why=Movement.enforce_pair(middle,"second-cargo-lost")
check(cargo_blocked and cargo_why=="overleash-return"
  and middle.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "zero/unreadable second item must not grant long return authority")
second_inventory.held=1
game.tick=2800
local cargo_restored,restored_why=Movement.enforce_pair(middle,
  "second-cargo-restored")
check(cargo_restored and restored_why=="second-reversal-safety-handoff",
  "genuinely restored item must release only generic 0566 safety")

-- 0941: the real 0939 depot pickup is a bounded, empty-handed physical
-- journey. The 0940 exception must preserve ONLY that original movement
-- owner, release ONLY a generic 0566 safety return, and fail closed on
-- corrupted saved records without a Factorio tick exception.
do
  local tp=storage.tech_priests
  local Depot=require("scripts.core.station_starvation_depot_0852")
  local original_get_staged=Depot.get_staged
  local first_stage={id="reversal-ancestor:22:2:72",
    reversal_stage_index=2,station_item="junior-cogitator-station",
    phase="in-magos-depot",worker_priest_unit=71,leaf_priest_unit=73}
  local second_stage={id="reversal-leaf:22:72",
    station_item="junior-cogitator-station",phase="in-magos-depot",
    worker_priest_unit=73}
  local first_hold={valid=true,held=1}
  local second_hold={valid=true,held=1}
  function first_hold.get_item_count(item)
    check(item=="junior-cogitator-station","wrong first Junior item")
    return first_hold.held
  end
  function second_hold.get_item_count(item)
    check(item=="junior-cogitator-station","wrong second Junior item")
    return second_hold.held
  end
  local first_entry={status="stored",inventory=first_hold}
  local second_entry={status="stored",inventory=second_hold}
  Depot.get_staged=function(magos,stage)
    if magos~=tp.pairs_by_station[90] then return nil end
    if stage==first_stage then return first_entry end
    if stage==second_stage then return second_entry end
    return nil
  end
  -- This test isolates movement arbitration. The real 0852 depot
  -- ownership/lease and physical 0824 debit are tested separately.
  rec.status="complete"
  rec.worker_station_unit=90
  rec.station_item="senior-cogitator-station"
  rec.reversal_stage_0853=first_stage
  rec.reversal_stage_0851=second_stage
  rec.reversal_stage_0854={leaf_priest_unit=71}
  rec.reversal_junior_0919={status="ghost-reserved",
    child_writ_id=23,ghost_unit=902,created_tick=2800}
  local child={id=23,status="active",
    station_item="junior-cogitator-station",
    station_entity="junior-cogitator-station",
    worker_station_unit=70,requester_station_unit=70,
    ghost_unit=902,
    reversal_junior_0919={root_writ_id=22,stage_id=first_stage.id,
      original_priest=73,original_intermediate_priest=71,
      magos_station_unit=90,pickup_started_tick=2820}}
  tp.station_expansion_0256[23]=child
  tp.station_expansion_by_worker_0256={[70]=23}
  tp.station_reversal_followup_0911={[90]=22}
  tp.station_cargo_0824[23]=nil
  middle.reversal_junior_followup_0920={root_writ_id=22}
  middle.mode="idle"
  middle_priest.position={x=300,y=0}
  game.tick=3000
  Movement.stop(middle,"0941-setup")
  check(Movement.request(middle,magos_station.position,
    "station-recovery-first-junior-depot-0939",
    {owner="station-recovery-first-junior-0939",
      priority=70,ttl=600,radius=2}),
    "original physical first-Junior pickup route refused")
  local pickup_route=middle.movement_request_0418
  local ok_pickup,why_pickup=Movement.enforce_pair(middle,"0941-original-pickup")
  check(not ok_pickup and why_pickup=="first-junior-pickup-physical-route-owned"
    and middle.movement_request_0418==pickup_route,
    "generic overleash displaced original audited pickup")
  check(first_hold.held==1 and second_hold.held==1
    and middle_priest.position.x==300,
    "movement exception fabricated pickup, changed inventory or teleported")
  Movement.stop(middle,"0941-inject-safety")
  check(Movement.request(middle,middle_station.position,
    "movement-enforcement-overleash-return-0566",
    {owner="movement-controller-enforcement-0566",
      priority=840,ttl=600,bounds_exempt=true}),
    "generic safety return fixture not established")
  local handed,handed_reason=Movement.enforce_pair(middle,"0941-handoff")
  check(handed and handed_reason=="first-junior-pickup-safety-handoff"
    and middle.movement_request_0418==nil,
    "only genuine original Junior pickup may retire generic safety return")
  check(first_hold.held==1 and second_hold.held==1,
    "safety handoff changed protected inventory")
  -- Every negative case starts without an incumbent route; it must
  -- install ordinary safety enforcement rather than accept the exception.
  local function rejected(label,change,restore)
    Movement.stop(middle,"0941-negative-"..label)
    change()
    local safe,reason=pcall(Movement.enforce_pair,middle,label)
    check(safe,"malformed persisted "..label.." crashed enforcement")
    local request=middle.movement_request_0418
    check(request and request.owner=="movement-controller-enforcement-0566",
      label.." improperly exempted ordinary overleash safety")
    restore()
  end
  rejected("first-item-lost",function() first_hold.held=0 end,
    function() first_hold.held=1 end)
  rejected("second-item-lost",function() second_hold.held=0 end,
    function() second_hold.held=1 end)
  rejected("foreign-worker",function() child.worker_station_unit=999 end,
    function() child.worker_station_unit=70 end)
  rejected("stale-pickup",function()
      child.reversal_junior_0919.pickup_started_tick=game.tick-7201
    end,function() child.reversal_junior_0919.pickup_started_tick=2820 end)
  rejected("malformed-step",function() rec.reversal_junior_0919="forged" end,
    function() rec.reversal_junior_0919={status="ghost-reserved",
      child_writ_id=23,ghost_unit=902,created_tick=2800} end)
  rejected("malformed-first-stage",function() rec.reversal_stage_0853="forged" end,
    function() rec.reversal_stage_0853=first_stage end)
  rejected("malformed-child",function() tp.station_expansion_0256[23]="forged" end,
    function() tp.station_expansion_0256[23]=child end)
  rejected("malformed-root",function() tp.station_expansion_0256[22]="forged" end,
    function() tp.station_expansion_0256[22]=rec end)
  rejected("missing-priest-registry",function() tp.pairs_by_priest=nil end,
    function() tp.pairs_by_priest={[71]=middle} end)
  Depot.get_staged=original_get_staged
  Movement.stop(middle,"0941-done")
end
print("[movement-first-junior-pickup-0941] PASS original 0939 route, 0566 handoff, counted independent depots, malformed save refusal, no teleport")


-- 0946: the second original Junior pickup needs the same bounded 0566
-- movement arbitration as the first pickup, but ONLY after native first-Junior
-- reconstruction and with a different, still-unspent physical depot item.
do
  local tp=storage.tech_priests
  local junior_station={valid=true,unit_number=74,
    name="junior-cogitator-station",force=force,surface=surface,
    position={x=215,y=0}}
  local junior_priest={valid=true,unit_number=73,
    force=force,surface=surface,position={x=330,y=0},
    commandable=commandable}
  local junior={station=junior_station,priest=junior_priest,
    radius=30,mode="idle"}
  local original_priest={valid=true,unit_number=99,
    force=force,surface=surface,position={x=360,y=0}}
  local original={priest=original_priest}
  local first={id="reversal-ancestor:22:2:72",
    reversal_stage_index=2,station_item="junior-cogitator-station",
    phase="in-magos-depot",leaf_station_unit=72,leaf_priest_unit=73}
  local second={id="reversal-leaf:22:9",
    station_item="junior-cogitator-station",phase="in-magos-depot",
    leaf_station_unit=9,leaf_priest_unit=99,worker_priest_unit=73}
  local first_inv={valid=true,held=0}
  local second_inv={valid=true,held=1}
  function first_inv.get_item_count(item)
    check(item=="junior-cogitator-station","first depot item name")
    return first_inv.held
  end
  function second_inv.get_item_count(item)
    check(item=="junior-cogitator-station","second depot item name")
    return second_inv.held
  end
  local first_entry={status="outbound",record_id=first.id,
    item="junior-cogitator-station",inventory=first_inv}
  local second_entry={status="stored",record_id=second.id,
    item="junior-cogitator-station",inventory=second_inv,
    magos_station_unit=90,magos_priest_unit=91}
  local first_child={id=23,status="complete",
    relocation_old_station_unit_0823=72,
    ghost_position={x=215,y=0}}
  local child={id=24,status="active",
    station_item="junior-cogitator-station",
    station_entity="junior-cogitator-station",
    worker_station_unit=74,requester_station_unit=74,
    ghost_unit=903,reversal_second_junior_0943={
      root_writ_id=22,stage_id=second.id,
      original_priest=99,original_first_junior_priest=73,
      magos_station_unit=90,pickup_started_tick=3100}}
  rec.status="complete"
  rec.worker_station_unit=90
  rec.blocked_item="resource:iron-ore"
  rec.reversal_stage_0853=first
  rec.reversal_stage_0851=second
  rec.reversal_junior_0919={status="ghost-reserved",
    child_writ_id=23}
  rec.reversal_second_junior_0943={status="ghost-reserved",
    child_writ_id=24,ghost_unit=903,created_tick=3000}
  tp.station_expansion_0256[23]=first_child
  tp.station_expansion_0256[24]=child
  tp.station_expansion_by_worker_0256={[74]=24}
  tp.pairs_by_station[74]=junior
  tp.pairs_by_priest={[71]=middle,[73]=junior,[99]=original}
  tp.station_reversal_depot_0852={
    [first.id]=first_entry,[second.id]=second_entry}
  tp.station_relocation_0823[9]={
    status="staged",old_unit=9,priest_unit=99,priest=original_priest}
  tp.station_cargo_0824[24]=nil
  game.tick=3200
  Movement.stop(junior,"0946-setup")
  check(Movement.request(junior,magos_station.position,
    "station-recovery-second-junior-depot-0944",{
      owner="station-recovery-second-junior-0944",
      priority=70,ttl=600,long_action=true,radius=2}),
    "legitimate original second-Junior depot journey rejected")
  local route=junior.movement_request_0418
  local ok,why=Movement.enforce_pair(junior,"0946-real-route")
  check(not ok and why=="second-junior-pickup-physical-route-owned"
    and junior.movement_request_0418==route,
    "generic 0566 leash stole the original second-Junior pickup")
  check(first_inv.held==0 and second_inv.held==1
    and junior_priest.position.x==330,
    "arbitration changed physical inventory or teleported priest")
  Movement.stop(junior,"0946-inject-generic")
  check(Movement.request(junior,junior_station.position,
    "movement-enforcement-overleash-return-0566",{
      owner="movement-controller-enforcement-0566",
      priority=840,ttl=600,bounds_exempt=true}),
    "generic 0566 safety fixture missing")
  local released,release_why=Movement.enforce_pair(junior,"0946-handoff")
  check(released and release_why=="second-junior-pickup-safety-handoff"
    and junior.movement_request_0418==nil,
    "only audited second-Junior journey may retire generic safety return")
  local function refused(label,change,restore)
    Movement.stop(junior,"0946-negative-"..label)
    change()
    local safe=pcall(Movement.enforce_pair,junior,label)
    check(safe,"malformed "..label.." crashed movement enforcement")
    check(junior.movement_request_0418
      and junior.movement_request_0418.owner
        =="movement-controller-enforcement-0566",
      label.." incorrectly exempted ordinary leash")
    restore()
  end
  refused("missing-second-item",function() second_inv.held=0 end,
    function() second_inv.held=1 end)
  refused("duplicate-first-item",function() first_inv.held=1 end,
    function() first_inv.held=0 end)
  refused("wrong-original-priest",function()
      tp.station_relocation_0823[9].priest_unit=101
    end,function() tp.station_relocation_0823[9].priest_unit=99 end)
  refused("stale-pickup",function()
      child.reversal_second_junior_0943.pickup_started_tick=game.tick-7201
    end,function()
      child.reversal_second_junior_0943.pickup_started_tick=3100 end)
  refused("foreign-worker",function() child.worker_station_unit=70 end,
    function() child.worker_station_unit=74 end)
  refused("combat",function() junior.combat_target={} end,
    function() junior.combat_target=nil end)
  refused("malformed-child",function() tp.station_expansion_0256[24]="bad" end,
    function() tp.station_expansion_0256[24]=child end)
  refused("malformed-stage",function() rec.reversal_stage_0851="bad" end,
    function() rec.reversal_stage_0851=second end)
  refused("missing-depot",function() tp.station_reversal_depot_0852=nil end,
    function() tp.station_reversal_depot_0852={
      [first.id]=first_entry,[second.id]=second_entry} end)
  refused("unreadable-inventory",function()
      second_inv.get_item_count=function() error("unreadable") end
    end,function()
      second_inv.get_item_count=function() return second_inv.held end end)
  Movement.stop(junior,"0946-done")
  check(first_inv.held==0 and second_inv.held==1,
    "negative tests modified real station-item counts")
end
print("[movement-second-junior-pickup-0946] PASS original rebuilt first Junior, physical depot 0/1, priority-70 route, 0566 handoff, combat and malformed custody refusal, no synthetic items")

print("[movement-overleash-regression] PASS scenarios=26 including verified mined-Junior return, lost item and unreadable engine inventory")
