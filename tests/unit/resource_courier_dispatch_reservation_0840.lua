-- Single-dispatcher regression for 0837: a pending physical ore courier
-- reserves FUTURE scheduling, never interrupts existing jobs or cargo.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Dispatcher=require("scripts.core.single_dispatcher_0510")
local original_order=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
local original_arbiter=rawget(_G,"TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
local original_courier=rawget(_G,"TechPriestsResourceReturnCourier0837")
local original_direct=rawget(_G,"TechPriestsDirectAcquisitionExecutor0513")
local original_repair=rawget(_G,"TechPriestsRepairExecutor0516")
local original_expansion=rawget(_G,"tech_priests_0259_resource_expansion_service")
local original_defense=rawget(_G,"TechPriestsDefensePerimeter0259")
local original_rail=rawget(_G,"TechPriestsRailTrackFrontier0836")
local original_track_observer=rawget(_G,"TechPriestsRemoteRailOutpost0835")
game={tick=1100}
local force={index=1}
local surface={index=1}
local magos={station={valid=true,unit_number=900,
    name="planetary-magos-cogitator-station",force=force,surface=surface,
    position={x=0,y=0}},
  priest={valid=true,unit_number=901,position={x=0,y=2}},
  resource_expansion_0259={chain_0820={
    status="reached-resource",root_station_unit=900,
    return_courier_0837={phase="awaiting-terminal-duty"}}},
  mode="idle"}
local worker={station={valid=true,unit_number=330,
    name="junior-cogitator-station",force=force,surface=surface,
    position={x=5,y=0}},
  priest={valid=true,unit_number=331,position={x=5,y=2}},
  mode="idle"}
storage={tech_priests={pairs_by_station={[330]=worker,[900]=magos}}}
local waiting_courier=true
local orders,repairs,deliveries=0,0,0
_G.TechPriestsResourceReturnCourier0837={
  worker_reserved=function(p)
    assert(p==worker or p==magos,"courier reservation checked wrong priest")
    return waiting_courier
  end,
}
_G.TechPriestsRemoteRailOutpost0835=nil
_G.TechPriestsRailTrackFrontier0836=nil
_G.TechPriestsDefensePerimeter0259=nil
_G.tech_priests_0259_resource_expansion_service=nil
_G.TECH_PRIESTS_ORDER_QUEUE_0469={
  tick_pair=function(p)
    assert(p==worker,"order owner changed during test")
    orders=orders+1
    return false
  end,
}
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488={
  action=function()return {kind="repair",reason="existing-machine-needs-repair"}end,
}
_G.TechPriestsRepairExecutor0516={
  service_pair=function(p)
    assert(p==worker and p.active_task
      and p.active_task.kind=="repair","active repair lost or preempted")
    repairs=repairs+1
    return {processed=1,waiting=1,detail="repair-in-progress"}
  end,
}
_G.TechPriestsDirectAcquisitionExecutor0513={
  service_pair=function(p)
    assert(p==worker and p.direct_acquisition_custody_0513
      and p.direct_acquisition_custody_0513.count==2,
      "new courier reservation confiscated physically carried supplies")
    deliveries=deliveries+1
    return {processed=1,waiting=1,detail="physical-cargo-return"}
  end,
}
local res=Dispatcher.service_pair(worker,"courier-reserved-idle")
assert(res.waiting==1 and res.detail=="physical-ore-courier-awaiting-owner-service"
  and orders==0 and repairs==0 and deliveries==0
  and worker.canonical_action_0744.source=="resource-return-courier-0837",
  "idle reserved priest was assigned fresh work before ore pickup")
-- 1129 native replay: this final receiving Magos is itself reserved, but
-- MUST still run its existing 0259->0837 mission owner. A future-item
-- reservation prevents NEW jobs; it cannot suppress courier progress.
local root_calls=0
_G.tech_priests_0259_resource_expansion_service=function(p)
  assert(p==magos,"foreign worker stole root-only resource mission")
  root_calls=root_calls+1
  -- No fixture ore transfer: this test verifies dispatcher handoff only.
  return root_calls==2
end
game.tick=1102
local root_first=Dispatcher.service_pair(magos,"root-courier-dormant-wait")
assert(root_calls==1 and root_first.waiting==1
  and root_first.detail=="reserved-magos-physical-courier-owner-serviced"
  and magos.resource_expansion_0259.chain_0820
      .return_courier_0837.phase=="awaiting-terminal-duty"
  and orders==0,
  "reserved Magos silently stopped servicing the real courier owner")
game.tick=1103
local root_next=Dispatcher.service_pair(magos,"root-courier-ready")
assert(root_calls==2 and root_next.acted==1 and orders==0,
  "Magos courier owner could not make progress under its own reservation")
-- A foreign/stale mission must not be dispatched through the privilege.
magos.resource_expansion_0259.chain_0820.root_station_unit=999
game.tick=1104
local foreign=Dispatcher.service_pair(magos,"foreign-root-denied")
assert(root_calls==2 and foreign.waiting==1
  and foreign.detail=="physical-ore-courier-awaiting-owner-service"
  and orders==0,
  "wrong-root resource mission bypassed ordinary reservation")
magos.resource_expansion_0259.chain_0820.root_station_unit=900
_G.tech_priests_0259_resource_expansion_service=nil

worker.active_task={kind="repair",target="damaged-machine"}
game.tick=1105
res=Dispatcher.service_pair(worker,"finish-incumbent-repair")
assert(res.waiting==1 and repairs==1 and orders==1
  and worker.active_task.kind=="repair" and deliveries==0
  and worker.canonical_action_0744.family=="repair",
  "pending ore courier preempted a pre-existing active repair duty")
worker.active_task=nil
game.tick=1110
res=Dispatcher.service_pair(worker,"after-repair")
assert(res.waiting==1 and orders==1 and repairs==1
  and res.detail=="physical-ore-courier-awaiting-owner-service",
  "freed priest was immediately assigned another job, starving courier")
worker.direct_acquisition_custody_0513={item="coal",count=2}
game.tick=1115
res=Dispatcher.service_pair(worker,"held-cargo-before-courier")
assert(res.waiting==1 and deliveries==1 and orders==1
  and worker.direct_acquisition_custody_0513.count==2
  and worker.canonical_action_0744.family=="direct-acquisition",
  "courier reservation stole existing actual cargo return")
worker.direct_acquisition_custody_0513=nil
waiting_courier=false
worker.active_task={kind="repair"}
game.tick=1120
res=Dispatcher.service_pair(worker,"reservation-cleared")
assert(orders==2 and repairs==2 and res.waiting==1,
  "released reservation continued blocking legitimate factory work")
_G.TECH_PRIESTS_ORDER_QUEUE_0469=original_order
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=original_arbiter
_G.TechPriestsResourceReturnCourier0837=original_courier
_G.TechPriestsDirectAcquisitionExecutor0513=original_direct
_G.TechPriestsRepairExecutor0516=original_repair
_G.tech_priests_0259_resource_expansion_service=original_expansion
_G.TechPriestsDefensePerimeter0259=original_defense
_G.TechPriestsRailTrackFrontier0836=original_rail
_G.TechPriestsRemoteRailOutpost0835=original_track_observer
print("[resource-courier-dispatch-reservation-0840] PASS reserved Magos services physical courier, ordinary priests remain idle, incumbent jobs and cargo preserved")
