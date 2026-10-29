-- 0907 physical outbound walk: source fixture, NOT engine acceptance.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local ITEM="senior-cogitator-station"
local force,surface={index=1},{index=2}
local station={valid=true,unit_number=100,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=101,position={x=0,y=0}}
local magos={station=station,priest=priest,radius=40,
  resource_expansion_0259={chain_0820={target={x=200,y=0}}}}
local original={valid=true,unit_number=201}
local stage={id="reversal-ancestor:9:4:200",phase="in-magos-depot",
  station_item=ITEM,reversal_stage_index=4,leaf_station_unit=200,
  leaf_priest_unit=201,worker_station_unit=100,worker_priest_unit=101}
local function inv(item,n)
  return {valid=true,get_item_count=function(which)
    assert(which==item);return n
  end}
end
local source,held=inv(ITEM,0),inv(ITEM,1)
local prior={inv("junior-cogitator-station",1),
  inv("junior-cogitator-station",1),inv("intermediate-cogitator-station",1)}
local entry={status="outbound",record_id=stage.id,item=ITEM,
  magos_station_unit=100,magos_priest_unit=101,leaf_station_unit=200,
  leaf_priest_unit=201,force=force,surface=surface,inventory=source}
local rec={id=9,status="active",station_item=ITEM,station_entity=ITEM,
  worker_station_unit=100,ghost_unit=778,ghost_position={x=24,y=0},
  reversal_stage_0855=stage,reversal_plan_0850={target={x=200,y=0}},
  reversal_stage_0851={station_item="junior-cogitator-station"},
  reversal_stage_0853={station_item="junior-cogitator-station"},
  reversal_stage_0854={station_item="intermediate-cogitator-station"},
  reversal_outbound_0895={phase="senior-carried",writ_id=9,stage_id=stage.id,
    magos_unit=100,magos_priest_unit=101,original_senior_unit=200,
    original_senior_priest=201,ghost_unit=778,ghost_position={x=24,y=0},
    target={x=200,y=0},audited_tick_0906=0,picked_tick=120}}
local state=rec.reversal_outbound_0895
storage={tech_priests={pairs_by_station={[100]=magos},
  pairs_by_priest={[201]={priest=original}},
  station_reversal_depot_0852={[stage.id]=entry}}}
local ghost={valid=true,name="entity-ghost",ghost_name=ITEM,
  unit_number=778,position={x=24,y=0},force=force,surface=surface}
local lease={status="staged",rec_id=stage.id,old_unit=200,
  priest_unit=201,worker_unit=100,reversal_ancestor_0855=true,
  old_station={valid=false},priest=original}
local cargo={status="carrying",inventory=held}
local observations=0
package.loaded["scripts.core.station_starvation_rebuild_0867"]={audit=function()
  return {stage_count=4} end}
package.loaded["scripts.core.station_starvation_depot_0852"]={
  get_staged=function(_,step)
    local k=step==rec.reversal_stage_0851 and 1
      or step==rec.reversal_stage_0853 and 2
      or step==rec.reversal_stage_0854 and 3
    return k and {inventory=prior[k]} or nil end}
package.loaded["scripts.core.station_relocation_0823"]={
  pending_for_record=function(step)
    if step==stage and lease.status=="staged" then return lease end
    if step==rec and rec.relocation_old_station_unit_0823==200
        and lease.status~="complete" then return lease end
    return nil
  end,
  arm_staged_rebuild=function(worker,record,st,g)
    assert(worker==magos and record==rec and st==stage and g==ghost
      and lease.status=="staged")
    lease.status="mined";lease.rec_id=rec.id;lease.item=ITEM
    lease.target={x=24,y=0};rec.relocation_old_station_unit_0823=200
    return true,"original-senior-lease-armed-for-physical-build"
  end}
package.loaded["scripts.core.station_cargo_0824"]={
  get=function()return cargo end,
  observe_carrier=function()
    observations=observations+1;return true,"carrier-position-observed" end}
game={tick=130}
defines={command={go_to_location=1},distraction={none=0}}
local Outbound=require("scripts.core.station_starvation_outbound_0895")
local commands=0
local function command(unit,order)
  assert(unit==priest and order.type==1 and order.destination==ghost.position
    and order.radius==2);commands=commands+1 end
local function service()
  return select(2,Outbound.service_outward_transit(magos,rec,command,ghost)) end
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and commands==1 and state.transit_started_tick==130)
game.tick=150
assert(service()=="reversal-senior-carrier-walking-to-ghost" and commands==1)
package.loaded["scripts.core.station_starvation_outbound_0895"]=nil
Outbound=require("scripts.core.station_starvation_outbound_0895")
game.tick=190
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and commands==2 and state.transit_started_tick==130)
priest.position={x=23,y=0};game.tick=191
assert(service()=="reversal-senior-real-item-arrived-at-ghost"
  and state.arrived_tick==191 and state.transit_status=="arrived"
  and commands==2 and observations==4)
assert(source.get_item_count(ITEM)==0 and held.get_item_count(ITEM)==1
  and lease.status=="staged" and original.valid
  and storage.tech_priests.pairs_by_station[200]==nil)
-- 0909: a real observer may see only the later walking/build-delay phase.
-- Persisted pickup/arrival receipts survive those transient phase changes,
-- but cannot be forged with an early escrow or missing arrival.
rec.phase="building-ghost"
assert(Outbound.milestone_receipt_0909(rec,"pickup"))
assert(Outbound.milestone_receipt_0909(rec,"arrival"))
state.picked_tick=119
assert(not Outbound.milestone_receipt_0909(rec,"pickup"))
assert(not Outbound.milestone_receipt_0909(rec,"arrival"))
state.picked_tick=120
state.arrived_tick=119
assert(not Outbound.milestone_receipt_0909(rec,"arrival"))
state.arrived_tick=191
state.transit_status="walking"
assert(not Outbound.milestone_receipt_0909(rec,"arrival"))
state.transit_status="arrived"
state.phase="senior-build-authorized"
assert(not Outbound.milestone_receipt_0909(rec,"pickup"))
assert(Outbound.milestone_receipt_0909(rec,"arrival"))
state.phase="senior-carried"
rec.status="complete"
assert(not Outbound.milestone_receipt_0909(rec,"arrival"))
rec.status="active"
assert(not Outbound.milestone_receipt_0909(rec,"invalid"))
rec.phase=nil
priest.position={x=0,y=0};game.tick=192
assert(service()=="reversal-senior-carrier-walking-to-ghost"
  and state.arrived_tick==nil and commands==2)
local function denied(reason,change,restore)
  change();game.tick=game.tick+1
  assert(service()==reason and commands==2 and held.get_item_count(ITEM)==1
    and source.get_item_count(ITEM)==0,reason)
  restore() end
denied("outbound-original-resource-ghost-unavailable",
  function()ghost.force={index=99} end,function()ghost.force=force end)
denied("outbound-natural-resource-target-changed",
  function()magos.resource_expansion_0259.chain_0820.target={x=201,y=0} end,
  function()magos.resource_expansion_0259.chain_0820.target={x=200,y=0} end)
denied("outbound-real-carrier-or-depot-unverified:nil",
  function()entry.status="stored" end,function()entry.status="outbound" end)
denied("outbound-four-depot-escrow-receipt-invalid",
  function()state.audited_tick_0906=100 end,
  function()state.audited_tick_0906=0 end)
denied("outbound-prior-depot-custody-lost:2",
  function()prior[2]=inv("junior-cogitator-station",0) end,
  function()prior[2]=inv("junior-cogitator-station",1) end)
local cargo_module=package.loaded["scripts.core.station_cargo_0824"]
local observe=cargo_module.observe_carrier
cargo_module.observe_carrier=function()return false,"injected-position-readback-refusal" end
game.tick=198
assert(service()=="outbound-carrier-position-unverified:injected-position-readback-refusal"
  and commands==2)
cargo_module.observe_carrier=observe
state.transit_started_tick=1;game.tick=7203
assert(service()=="outbound-physical-transit-timeout"
  and state.transit_status=="timed-out" and commands==2)
-- 0908: the same physical Senior item and original priest must survive
-- the transition into the existing 0256/0824 construction path.
state.transit_started_tick=130
state.transit_status="arrived";state.arrived_tick=201
priest.position={x=23,y=0};game.tick=201
local handled,reason=Outbound.arm_original_senior_rebuild(magos,rec,ghost,nil)
assert(handled and reason=="outbound-senior-build-arrival-not-certified"
  and lease.status=="staged" and held.get_item_count(ITEM)==1)
game.tick=202
handled,reason=Outbound.arm_original_senior_rebuild(magos,rec,ghost,
  {valid=true})
assert(handled and reason:match("^outbound%-senior%-build%-physical%-custody%-invalid")
  and lease.status=="staged")
handled,reason=Outbound.arm_original_senior_rebuild(magos,rec,ghost,nil)
assert(handled and reason=="reversal-senior-physical-build-authorized"
  and state.phase=="senior-build-authorized"
  and lease.status=="mined" and lease.rec_id==rec.id
  and rec.relocation_old_station_unit_0823==200
  and held.get_item_count(ITEM)==1 and source.get_item_count(ITEM)==0)
local verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,nil)
assert(verified,why)
prior[1]=inv("junior-cogitator-station",0)
verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,nil)
assert(not verified and why=="outbound-armed-prior-depot-custody-lost:1")
prior[1]=inv("junior-cogitator-station",1)
magos.resource_expansion_0259.chain_0820.target={x=201,y=0}
verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,nil)
assert(not verified and why=="outbound-armed-original-identity-or-target-changed")
magos.resource_expansion_0259.chain_0820.target={x=200,y=0}
local foreign={valid=true,unit_number=999,name=ITEM,
  position={x=24,y=0},force={index=99},surface=surface}
verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,foreign)
assert(not verified and why=="outbound-armed-built-station-identity-invalid")
local rebuilt={valid=true,unit_number=999,name=ITEM,
  position={x=24,y=0},force=force,surface=surface}
verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,rebuilt)
assert(not verified and why=="outbound-armed-foreign-build-before-debit")
cargo.status="building";cargo.inventory=inv(ITEM,0);lease.status="building"
verified,why=Outbound.verify_authorized_rebuild(magos,rec,ghost,nil)
assert(verified,why)
verified,why=Outbound.verify_authorized_rebuild(magos,rec,nil,rebuilt)
assert(verified,why)
local preserved=storage.tech_priests.pairs_by_priest[201]
preserved.station=rebuilt
storage.tech_priests.pairs_by_station[999]=preserved
lease.status="complete"
verified,why=Outbound.verify_authorized_rebuild(magos,rec,nil,rebuilt)
assert(verified,why)
print("[station-starvation-outbound-0909] PASS persistent pickup/arrival receipt across skipped transient phases, escrow, incomplete arrival and completed writ refusals")
print("[station-starvation-outbound-0908] PASS staged original priest, exact real-item build authorization, foreign build, reload custody and target refusals")
print("[station-starvation-outbound-transit-0907] PASS real carrier walk, reload, original priest, ghost, depot and timeout refusals")

-- 0910: exercise the REAL depot module after the Senior's actual station
-- was reconstructed. The Intermediate depot must remain verifiable despite
-- its original carrier's old Senior station unit having been retired.
-- A foreign replacement, forged completed writ, missing real item or broken
-- Magos->Senior edge must not inherit that protected inventory.
local tp=storage.tech_priests
local intermediate_priest={valid=true,unit_number=301}
local intermediate_stage={id="reversal-ancestor:9:3:300",
  phase="in-magos-depot",station_item="intermediate-cogitator-station",
  reversal_stage_index=3,worker_station_unit=200,worker_priest_unit=201,
  leaf_station_unit=300,leaf_priest_unit=301}
local intermediate_hold=inv("intermediate-cogitator-station",1)
local intermediate_entry={status="stored",record_id=intermediate_stage.id,
  item="intermediate-cogitator-station",magos_station_unit=100,
  magos_priest_unit=101,worker_station_unit=200,worker_priest_unit=201,
  leaf_station_unit=300,leaf_priest_unit=301,force=force,surface=surface,
  inventory=intermediate_hold}
local intermediate_lease={status="staged",rec_id=intermediate_stage.id,
  old_unit=300,priest_unit=301,worker_unit=200,
  reversal_ancestor_0854=true,old_station={valid=false},
  priest=intermediate_priest}
tp.station_reversal_depot_0852[intermediate_stage.id]=intermediate_entry
tp.station_expansion_0256={[rec.id]=rec}
tp.pairs_by_priest[301]={priest=intermediate_priest,station={valid=false},
  station_unit=300,relocation_pending_0823=true}
rec.reversal_stage_0854=intermediate_stage
rec.reversal_outbound_0895.phase="senior-build-authorized"
rec.status="complete"
rec.ghost_position={x=24,y=0}
rec.relocation_old_station_unit_0823=200
preserved.station=rebuilt
preserved.relocation_pending_0823=nil
preserved.station_unit=999
tp.pairs_by_station[999]=preserved
tp.pairs_by_station[200]=nil
entry.inventory=source
entry.status="outbound"
local relocation=package.loaded["scripts.core.station_relocation_0823"]
local prior_pending=relocation.pending_for_record
relocation.pending_for_record=function(step)
  if step==intermediate_stage then return intermediate_lease end
  if step==rec then return nil end
  return prior_pending(step)
end
local cargo_api=package.loaded["scripts.core.station_cargo_0824"]
cargo_api.has_record=function()return false end
local hierarchy_ok=true
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  is_direct_subordinate=function(parent,child)
    return hierarchy_ok and parent==magos and child==preserved end}
local Depot0910=dofile("tech-priests_src/scripts/core/station_starvation_depot_0852.lua")
local function staged()
  return Depot0910.get_staged(magos,intermediate_stage)
end
local got,reason=staged()
assert(got==intermediate_entry and reason=="depot-stored-physical-item-verified",
  "rebuilt original Senior must retain Intermediate's physically stored item")
local function reject(change,restore)
  change()
  local denied=staged()
  assert(denied==nil and intermediate_hold.get_item_count(
    "intermediate-cogitator-station")==1,
    "unverified rebuilt carrier must never inherit a protected depot")
  restore()
  assert(staged()==intermediate_entry)
end
reject(function()hierarchy_ok=false end,function()hierarchy_ok=true end)
reject(function()rec.status="active" end,function()rec.status="complete" end)
reject(function()rec.reversal_stage_0854={} end,
  function()rec.reversal_stage_0854=intermediate_stage end)
reject(function()rec.ghost_position={x=80,y=0} end,
  function()rec.ghost_position={x=24,y=0} end)
reject(function()entry.status="stored" end,function()entry.status="outbound" end)
reject(function()entry.inventory=inv(ITEM,1) end,
  function()entry.inventory=source end)
reject(function()preserved.station={valid=true,name=ITEM,
  unit_number=998,position={x=24,y=0}} end,
  function()preserved.station=rebuilt end)
-- Module reload must not require a transient old-station handle or
-- create another item; both original inventories remain unchanged.
Depot0910=dofile("tech-priests_src/scripts/core/station_starvation_depot_0852.lua")
assert(staged()==intermediate_entry
  and intermediate_hold.get_item_count("intermediate-cogitator-station")==1
  and source.get_item_count(ITEM)==0)
print("[station-starvation-depot-0910] PASS rebuilt original Senior carrier, original-writ hierarchy, protected Intermediate inventory, reload and forged-custody refusals")

-- 0911: the actual 0910 original-priest depot remains authoritative when the
-- rebuilt Senior reserves a real Intermediate ghost. A new 0256 writ must be
-- unique and must NOT debit any protected station item or claim a new priest.
local depot_module="scripts.core.station_starvation_depot_0852"
package.loaded[depot_module]={get_staged=function(m,step)
  if step==intermediate_stage then return Depot0910.get_staged(m,step) end
  if step==rec.reversal_stage_0851 then return {inventory=prior[1]} end
  if step==rec.reversal_stage_0853 then return {inventory=prior[2]} end
end}
local Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
rec.blocked_item="resource:iron-ore"
tp.station_expansion_next_id_0256=10
tp.station_expansion_by_worker_0256={}
local ghost_calls=0
local ghost_available=true
local next_ghost={valid=true,name="entity-ghost",
  ghost_name="intermediate-cogitator-station",unit_number=1001,
  position={x=45,y=0},force=force,surface=surface}
local api={
  rank=function(p)assert(p==preserved);return 3 end,
  radius=function(p)assert(p==preserved);return 40 end,
  find_site=function(p,item,target)
    assert(p==preserved and item=="intermediate-cogitator-station"
      and target.x==200);return {x=45,y=0} end,
  create_ghost=function(p,item,pos)
    assert(p==preserved and item=="intermediate-cogitator-station"
      and pos.x==45);ghost_calls=ghost_calls+1;return next_ghost end,
  find_ghost=function(p,child)
    assert(p==preserved and child.station_item=="intermediate-cogitator-station")
    return ghost_available and next_ghost or nil end}
-- 0912: actual Factorio ghost positions may be snapped to the prototype
-- grid. Verify a 1.25-tile shift without expanding the Senior's real reach.
local verify=Intermediate0911.verify_created_ghost_0912
next_ghost.position={x=46.25,y=0}
local site={x=45,y=0}
local target={x=200,y=0}
local accepted,detail=verify(preserved,next_ghost,site,40,target,next_ghost)
assert(accepted,detail)
local snapped=next_ghost.position
next_ghost.position={x=46.6,y=0}
assert(not verify(preserved,next_ghost,site,40,target,next_ghost),
  "unbounded grid displacement must not be accepted")
next_ghost.position={x=64.25,y=0}
assert(not verify(preserved,next_ghost,{x=63,y=0},40,target,next_ghost),
  "actual ghost outside command radius must be rejected")
next_ghost.position=snapped
assert(not verify(preserved,next_ghost,site,40,{x=0,y=0},next_ghost),
  "backward grid-aligned ghost must not be accepted")
next_ghost.force={index=99}
assert(not verify(preserved,next_ghost,site,40,target,next_ghost),
  "foreign-force ghost must not be adopted")
next_ghost.force=force
assert(not verify(preserved,next_ghost,site,40,target,nil),
  "unobserved ghost must not become a construction writ")
local competing={valid=true,name="entity-ghost",
  ghost_name="intermediate-cogitator-station",unit_number=1002,
  position=snapped,force=force,surface=surface}
assert(not verify(preserved,next_ghost,site,40,target,competing),
  "a different real ghost unit must not inherit the writ")
local function reserve()return Intermediate0911.service(magos,api) end
assert(reserve()==false and ghost_calls==0,
  "no completed-writ receipt means no new construction ghost")
tp.station_reversal_followup_0911={[100]=9}
local function denied(change,restore)
  change()
  local handled,why=reserve()
  assert(handled and ghost_calls==0 and not rec.reversal_next_0911
    and intermediate_hold.get_item_count("intermediate-cogitator-station")==1,
    "failed live custody must not create an Intermediate ghost: "..tostring(why))
  restore()
end
denied(function()hierarchy_ok=false end,function()hierarchy_ok=true end)
denied(function()magos.resource_expansion_0259.chain_0820.target={x=201,y=0} end,
  function()magos.resource_expansion_0259.chain_0820.target={x=200,y=0} end)
denied(function()intermediate_entry.inventory=inv("intermediate-cogitator-station",0) end,
  function()intermediate_entry.inventory=intermediate_hold end)
denied(function()tp.station_expansion_by_worker_0256[999]=88 end,
  function()tp.station_expansion_by_worker_0256[999]=nil end)
denied(function()intermediate_priest.valid=false end,
  function()intermediate_priest.valid=true end)
game.tick=350
-- 0926: real 0911 ghost creation must precede Junior certification.
local junior_probe_calls_0926=0
local junior_probe_0926={service=function()
  junior_probe_calls_0926=junior_probe_calls_0926+1
  return true,"junior-prerequisite-already-reserved"
end}
local handled,why=Intermediate0911.service_before_junior_0926(
  magos,api,junior_probe_0926)
assert(junior_probe_calls_0926==0,
  "Junior audit must not preempt missing Intermediate ghost")
assert(handled and why=="reversal-intermediate-real-ghost-reserved"
  and ghost_calls==1 and rec.reversal_next_0911.child_writ_id==10
  and tp.station_expansion_next_id_0256==11
  and tp.station_expansion_by_worker_0256[999]==10)
local child=tp.station_expansion_0256[10]
assert(child and child.worker_station_unit==999 and child.requester_rank==3
  and child.required_worker_rank==2
  and child.reversal_followup_0911.root_writ_id==9
  and child.reversal_followup_0911.original_priest==301
  and child.ghost_unit==1001 and child.status=="active"
  and child.ghost_position.x==46.25 and child.ghost_position.y==0
  and intermediate_hold.get_item_count("intermediate-cogitator-station")==1
  and prior[1].get_item_count("junior-cogitator-station")==1
  and prior[2].get_item_count("junior-cogitator-station")==1
  and source.get_item_count(ITEM)==0)
handled,why=Intermediate0911.service_before_junior_0926(
  magos,api,junior_probe_0926)
assert(handled and why=="junior-prerequisite-already-reserved"
  and junior_probe_calls_0926==1 and ghost_calls==1
  and tp.station_expansion_next_id_0256==11,
  "Junior audit may run only after the real Intermediate ghost exists")
handled,why=reserve()
assert(handled and why=="reversal-intermediate-ghost-reserved-awaiting-real-depot-pickup"
  and ghost_calls==1 and tp.station_expansion_next_id_0256==11)
ghost_available=false
handled,why=reserve()
assert(handled and why=="intermediate-reserved-ghost-or-writ-custody-unverifiable"
  and ghost_calls==1 and intermediate_hold.get_item_count(
    "intermediate-cogitator-station")==1)
ghost_available=true
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
handled,why=reserve()
assert(handled and why=="reversal-intermediate-ghost-reserved-awaiting-real-depot-pickup"
  and ghost_calls==1 and child.ghost_unit==1001)
local executor=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
local executor_source=executor:read("*a");executor:close()
assert(executor_source:find("StarvationIntermediate0911.service_before_junior_0926",1,true)
  and executor_source:find("rec.reversal_followup_0911 then",1,true)
  and executor_source:find("station_reversal_followup_0911[rec.worker_station_unit]=rec.id",1,true),
  "the actual 0256 scheduler must reserve the next ghost without ordinary stock acquisition")
print("[station-starvation-intermediate-0912] PASS grid-snapped real ghost position, exact re-observed unit, inward command radius, forward progress, protected Intermediate depot and negative ownership; no station-item debit")
print("[station-starvation-stage-order-0926] PASS real Intermediate ghost reserved before Junior certification and original broker routing")

-- 0913: exercise the ACTUAL 0824 physical inventory debit through the
-- production 0911 child-writ controller. This remains a Lua regression, not
-- Factorio engine acceptance. All four original depot items originated from
-- the existing 0907/0910 custody fixture; no item is conjured by a phase.
local realCargo=dofile("tech-priests_src/scripts/core/station_cargo_0824.lua")
package.loaded["scripts.core.station_cargo_0824"]=realCargo
local remaining=1
intermediate_hold.get_item_count=function(item)
  assert(item=="intermediate-cogitator-station");return remaining end
intermediate_hold.remove=function(stack)
  assert(stack.name=="intermediate-cogitator-station" and stack.count==1)
  if remaining==0 then return 0 end
  remaining=remaining-1;return 1 end
intermediate_hold.insert=function(stack)
  assert(stack.name=="intermediate-cogitator-station" and stack.count==1)
  if remaining==1 then return 0 end
  remaining=remaining+1;return 1 end
local allocated=0
game.create_inventory=function(slots)
  assert(slots==1);allocated=allocated+1
  local n=0
  local bag={valid=true}
  bag.get_item_count=function(item)
    assert(item=="intermediate-cogitator-station");return n end
  bag.insert=function(stack)
    assert(stack.name=="intermediate-cogitator-station" and stack.count==1)
    if n~=0 then return 0 end
    n=1;return 1 end
  bag.remove=function(stack)
    assert(stack.name=="intermediate-cogitator-station" and stack.count==1)
    if n~=1 then return 0 end
    n=0;return 1 end
  bag.destroy=function() assert(n==0);bag.valid=false end
  return bag
end
-- The original Senior rebuild completed before its child ghost was
-- registered; a missing or reversed receipt must fail closed.
rec.completed_tick=340
preserved.priest.position={x=24,y=0}
preserved.mode="idle"
local future=dofile("tech-priests_src/scripts/core/station_starvation_reversal_0850.lua")
local reserved,writ=future.future_worker_reserved(preserved)
assert(reserved and writ==child,"active original Intermediate child must reserve future ordinary work")
child.status="failed"
assert(not future.future_worker_reserved(preserved),
  "retired child writ must never reserve future work")
child.status="active"
local commands0913=0
local function command0913(unit,order)
  assert(unit==preserved.priest and order.type==defines.command.go_to_location
    and order.destination==magos.station.position and order.radius==2)
  commands0913=commands0913+1
end
local pickup_api={rank=api.rank,find_ghost=api.find_ghost,command=command0913}
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
local function pickup0913()
  return select(2,Intermediate0911.service_pickup(preserved,child,pickup_api))
end
local function denied0913(change,restore)
  change()
  local result=pickup0913()
  assert(result~="reversal-intermediate-real-item-carried-from-magos"
    and result~="reversal-intermediate-senior-walking-to-magos-depot"
    and remaining==1 and allocated==0,
    "invalid live custody must not issue a pickup or movement: "..tostring(result))
  restore()
end
denied0913(function()hierarchy_ok=false end,function()hierarchy_ok=true end)
denied0913(function()ghost_available=false end,function()ghost_available=true end)
denied0913(function()intermediate_priest.valid=false end,
  function()intermediate_priest.valid=true end)
preserved.mode="emergency-gathering"
assert(pickup0913()=="intermediate-pickup-awaiting-existing-duty"
  and remaining==1 and allocated==0 and commands0913==0)
preserved.mode="idle"
preserved.direct_acquisition_task_0336={item="iron-ore"}
assert(pickup0913()=="intermediate-pickup-awaiting-existing-duty"
  and remaining==1 and allocated==0 and commands0913==0)
preserved.direct_acquisition_task_0336=nil
local prior_probe=_G.tech_priests_0248_higher_priority_probe
_G.tech_priests_0248_higher_priority_probe=function()
  return {priority="existing-emergency-duty"} end
game.tick=400
assert(pickup0913()=="intermediate-pickup-awaiting-existing-duty"
  and commands0913==0 and remaining==1)
_G.tech_priests_0248_higher_priority_probe=function()
  return {priority="idle"} end
local wrong_source={valid=true,unit_number=444,position={x=0,y=0},
  force=force,surface=surface}
local allowed=realCargo.pickup(preserved,child,intermediate_hold,wrong_source)
assert(not allowed and remaining==1 and allocated==0,
  "arbitrary nearby station cannot authorize a remote recovered-item debit")
allowed=realCargo.pickup(preserved,child,intermediate_hold,magos.station)
assert(not allowed and remaining==1 and allocated==0,
  "remote stock cannot be debited while Senior remains physically distant")
-- 0914: even a Senior already standing at the Magos may not debit a
-- protected item on the build/ghost registration tick or after reload.
preserved.priest.position={x=1,y=0}
assert(pickup0913()=="intermediate-pickup-senior-build-escrow-pending"
  and remaining==1 and allocated==0 and commands0913==0)
game.tick=469
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
assert(pickup0913()=="intermediate-pickup-senior-build-escrow-pending"
  and remaining==1 and allocated==0 and commands0913==0)
rec.completed_tick=nil
game.tick=470
assert(pickup0913()=="intermediate-pickup-senior-build-escrow-pending"
  and remaining==1 and allocated==0)
rec.completed_tick=471
assert(pickup0913()=="intermediate-pickup-senior-build-escrow-pending"
  and remaining==1 and allocated==0)
rec.completed_tick=340
preserved.priest.position={x=24,y=0}
assert(pickup0913()=="reversal-intermediate-senior-walking-to-magos-depot"
  and commands0913==1 and remaining==1)
game.tick=490
assert(pickup0913()=="reversal-intermediate-senior-walking-to-magos-depot"
  and commands0913==1)
preserved.priest.position={x=1,y=0}
game.tick=510
assert(pickup0913()=="reversal-intermediate-real-item-carried-from-magos"
  and remaining==0 and allocated==1
  and intermediate_entry.status=="outbound"
  and child.reversal_followup_0911.picked_tick==510)
local realHeld=realCargo.get(preserved,child)
assert(realHeld and realHeld.status=="carrying"
  and realHeld.inventory.get_item_count("intermediate-cogitator-station")==1
  and prior[1].get_item_count("junior-cogitator-station")==1
  and prior[2].get_item_count("junior-cogitator-station")==1
  and source.get_item_count(ITEM)==0
  and intermediate_lease.status=="staged"
  and intermediate_priest.valid)
-- Reload both modules without resetting storage or creating a second item.
realCargo=dofile("tech-priests_src/scripts/core/station_cargo_0824.lua")
package.loaded["scripts.core.station_cargo_0824"]=realCargo
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
game.tick=570
assert(pickup0913()=="reversal-intermediate-real-item-carried-from-magos"
  and remaining==0 and allocated==1)
hierarchy_ok=false
assert(pickup0913():find("intermediate-pickup-live-custody-invalid",1,true)
  and remaining==0 and allocated==1)
hierarchy_ok=true
ghost_available=false
assert(pickup0913()=="intermediate-pickup-owned-ghost-unverifiable")
ghost_available=true
assert(pickup0913()=="reversal-intermediate-real-item-carried-from-magos")
_G.tech_priests_0248_higher_priority_probe=prior_probe
local executor0913=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
local code0913=executor0913:read("*a");executor0913:close()
assert(code0913:find("StarvationIntermediate0911.service_pickup",1,true)
  and code0913:find("command=issue_priest_command",1,true)
  and code0913:find("rec.reversal_followup_0911 then",1,true),
  "the live 0256 executor must use physical Senior-to-Magos pickup")
print("[station-starvation-intermediate-0914] PASS 120-tick post-build escrow, co-located no-debit, missing/reversed receipt refusal, reload, original Senior depot walk, exact 0824 debit 1->0, carrier 0->1, two protected Juniors and original priest")
-- 0915: this is the SAME engine-owned cargo, never a fresh station item.
local transit_commands=0
local transit_api={rank=api.rank,radius=api.radius,
  find_ghost=api.find_ghost,
  command=function(unit,order)
    assert(unit==preserved.priest
      and order.type==defines.command.go_to_location
      and order.destination==next_ghost.position and order.radius==2)
    transit_commands=transit_commands+1
  end}
local function transit0915()
  return select(2,Intermediate0911.service_outward_transit(
    preserved,child,transit_api))
end
preserved.priest.position={x=1,y=0}
game.tick=600
assert(transit0915()=="intermediate-transit-pickup-escrow-pending"
  and transit_commands==0 and allocated==1 and remaining==0)
game.tick=630
assert(transit0915()=="reversal-intermediate-senior-carrying-to-ghost"
  and transit_commands==1 and allocated==1)
game.tick=650
assert(transit0915()=="reversal-intermediate-senior-carrying-to-ghost"
  and transit_commands==1)
preserved.mode="emergency-gathering";game.tick=690
assert(transit0915()=="intermediate-transit-awaiting-existing-duty"
  and transit_commands==1)
preserved.mode="idle"
assert(transit0915()=="reversal-intermediate-senior-carrying-to-ghost"
  and transit_commands==2)
hierarchy_ok=false
assert(transit0915()=="intermediate-transit-live-item-custody-invalid"
  and transit_commands==2 and allocated==1)
hierarchy_ok=true
ghost_available=false
assert(transit0915()=="intermediate-transit-owned-ghost-unverifiable")
ghost_available=true
transit_api.radius=function()return 2 end
assert(transit0915()=="intermediate-transit-hierarchy-radius-or-direction-invalid")
transit_api.radius=api.radius
preserved.priest.position={x=46,y=0};game.tick=700
assert(transit0915()=="reversal-intermediate-real-item-arrived-at-ghost"
  and child.reversal_followup_0911.arrived_tick==700
  and child.reversal_followup_0911.transit_status=="arrived"
  and allocated==1 and remaining==0
  and intermediate_lease.status=="staged" and intermediate_priest.valid)
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
game.tick=701
assert(transit0915()=="reversal-intermediate-real-item-arrived-at-ghost"
  and child.reversal_followup_0911.arrived_tick==700
  and transit_commands==2 and allocated==1)
preserved.priest.position={x=1,y=0};game.tick=702
assert(transit0915()=="reversal-intermediate-senior-carrying-to-ghost"
  and child.reversal_followup_0911.arrived_tick==nil)
child.reversal_followup_0911.transit_started_tick=1
game.tick=7202
assert(transit0915()=="intermediate-transit-physical-travel-timeout"
  and transit_commands==2 and allocated==1 and remaining==0)
local executor0915=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
local code0915=executor0915:read("*a");executor0915:close()
assert(code0915:find("StarvationIntermediate0911.service_outward_transit",1,true),
  "live 0256 executor must drive original Senior's physical outward transit")
print("[station-starvation-intermediate-0915] PASS counted original Senior carrier, pickup escrow, physical outward walk, arrival, existing-duty refusal, hierarchy, ghost, radius, reload, timeout and original Intermediate priest conservation")


-- 0916: authorize REAL 0824 -> 0256 build using the SAME original
-- Intermediate item and its staged original priest. No proxy or synthetic
-- station is treated as a completed entity.
local originalIntermediate=tp.pairs_by_priest[301]
intermediate_lease.pair=originalIntermediate
intermediate_lease.item="intermediate-cogitator-station"
intermediate_lease.force=force
intermediate_lease.surface=surface
intermediate_lease.target=nil
tp.station_relocation_0823={[300]=intermediate_lease}
local Relocation0916=dofile("tech-priests_src/scripts/core/station_relocation_0823.lua")
local pending0916=Relocation0916.pending_for_record
Relocation0916.pending_for_record=function(record)
  if record==intermediate_stage then return intermediate_lease end
  return pending0916(record)
end
package.loaded["scripts.core.station_relocation_0823"]=Relocation0916
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
preserved.priest.position={x=46,y=0}
child.reversal_followup_0911.transit_started_tick=7205
child.reversal_followup_0911.transit_status="arrived"
child.reversal_followup_0911.arrived_tick=7300
game.tick=7350
local function arm0916()
  return select(2,Intermediate0911.arm_original_intermediate_rebuild(
    preserved,child,transit_api))
end
local initial_count=realHeld.inventory.get_item_count(
  "intermediate-cogitator-station")
-- 0918: a physically arrived carrier cannot immediately spend its
-- protected item or reassign the original priest. The persisted arrival
-- receipt must age 120 ticks while the live inventory stays conserved.
assert(arm0916()=="intermediate-build-arrival-or-clock-not-certified"
  and intermediate_lease.status=="staged" and allocated==1
  and remaining==0 and initial_count==1)
Intermediate0911=dofile("tech-priests_src/scripts/core/station_starvation_intermediate_0911.lua")
game.tick=7420
assert(initial_count==1 and intermediate_lease.status=="staged"
  and child.relocation_old_station_unit_0823==nil)
local original_ghost_unit=next_ghost.unit_number
next_ghost.unit_number=1002
assert(arm0916()=="intermediate-build-owned-ghost-or-reach-invalid"
  and child.relocation_old_station_unit_0823==nil and allocated==1)
next_ghost.unit_number=original_ghost_unit
hierarchy_ok=false
assert(arm0916()=="intermediate-build-physical-custody-or-hierarchy-invalid"
  and intermediate_lease.status=="staged")
hierarchy_ok=true
intermediate_priest.valid=false
assert(arm0916()=="intermediate-build-physical-custody-or-hierarchy-invalid"
  and intermediate_lease.status=="staged")
intermediate_priest.valid=true
child.reversal_followup_0911.arrived_tick=game.tick
assert(arm0916()=="intermediate-build-arrival-or-clock-not-certified"
  and intermediate_lease.status=="staged")
child.reversal_followup_0911.arrived_tick=7300
assert(arm0916()=="reversal-intermediate-physical-build-authorized"
  and intermediate_lease.status=="mined"
  and intermediate_lease.rec_id==child.id
  and intermediate_lease.worker_unit==preserved.station.unit_number
  and intermediate_lease.target.x==child.ghost_position.x
  and child.relocation_old_station_unit_0823==300
  and child.reversal_followup_0911.build_authorized_tick==7420
  and realHeld.inventory.get_item_count("intermediate-cogitator-station")==1
  and remaining==0 and allocated==1
  and intermediate_priest.valid and not originalIntermediate.station.valid)
local function verified0916(ghost,built)
  return Intermediate0911.verify_authorized_intermediate_rebuild(
    preserved,child,transit_api,ghost,built)
end
local ok0916,why0916=verified0916(next_ghost,nil)
assert(ok0916,why0916)
assert(arm0916()~="reversal-intermediate-physical-build-authorized"
  and allocated==1 and remaining==0,
  "cannot arm the same old priest or debit the same item twice")
hierarchy_ok=false
assert(not verified0916(next_ghost,nil),
  "lost Magos-Senior hierarchy must block item consumption")
hierarchy_ok=true
local saved_junior=prior[1]
prior[1]=inv("junior-cogitator-station",0)
assert(not verified0916(next_ghost,nil),
  "a missing protected Junior depot must block intermediate construction")
prior[1]=saved_junior
local foreign={valid=true,name="intermediate-cogitator-station",
  unit_number=7777,position={x=48,y=0},force=force,surface=surface}
assert(not verified0916(next_ghost,foreign),
  "a foreign completed station must not inherit the original priest")
local removed,reason=realCargo.begin_build(preserved,child)
assert(removed,reason)
assert(Relocation0916.begin_build(child,preserved),
  "original Intermediate priest lease must enter building with exact worker")
assert(intermediate_lease.status=="building"
  and realHeld.inventory.get_item_count("intermediate-cogitator-station")==0
  and remaining==0 and allocated==1)
ok0916,why0916=verified0916(next_ghost,nil)
assert(ok0916,why0916)
-- If the engine rejects building, 0824 refunds the exact debited item.
local refunded,refund_reason=realCargo.build_failed(preserved,child)
assert(refunded,refund_reason)
Relocation0916.build_failed(child)
assert(intermediate_lease.status=="mined"
  and realHeld.inventory.get_item_count("intermediate-cogitator-station")==1
  and remaining==0)
removed,reason=realCargo.begin_build(preserved,child)
assert(removed,reason)
assert(Relocation0916.begin_build(child,preserved))
local intermediate_built={valid=true,name="intermediate-cogitator-station",
  unit_number=1400,position={x=46.25,y=0},force=force,surface=surface}
assert(Relocation0916.claim(intermediate_built),
  "real on_built must reattach ORIGINAL Intermediate priest")
assert(originalIntermediate.station==intermediate_built
  and originalIntermediate.priest==intermediate_priest
  and originalIntermediate.priest.unit_number==301
  and tp.pairs_by_station[1400]==originalIntermediate
  and tp.pairs_by_station[300]==nil
  and tp.station_by_priest[301]==1400)
ok0916,why0916=verified0916(nil,intermediate_built)
assert(ok0916,why0916)
local complete,complete_reason=realCargo.complete(preserved,child)
assert(complete,complete_reason)
assert(remaining==0
  and prior[1].get_item_count("junior-cogitator-station")==1
  and prior[2].get_item_count("junior-cogitator-station")==1
  and source.get_item_count(ITEM)==0
  and not originalIntermediate.relocation_pending_0823)
local src0916=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
local code0916=src0916:read("*a");src0916:close()
assert(code0916:find("arm_original_intermediate_rebuild",1,true)
  and code0916:find("verify_authorized_intermediate_rebuild",1,true)
  and code0916:find("StationCargo0824.begin_build",1,true)
  and code0916:find("StationRelocation0823.claim",1,true),
  "0916 must flow through real canonical construction and original-priest claim")
print("[station-starvation-intermediate-0916] PASS original Intermediate staged priest lease, exact counted carrier debit, physical build, refund retry, original priest pairing and protected Junior depots")


-- 0917: after the ORIGINAL Intermediate physically replaces station #300,
-- its protected first-Junior item must remain at the original Magos depot.
-- The carrier's new station identity is accepted ONLY through the exact
-- completed child writ, both counted source debits and live two-edge rank
-- hierarchy; a mere matching prototype or priest is insufficient.
local junior_stage_0917={id="reversal-ancestor:9:2:400",
  phase="in-magos-depot",station_item="junior-cogitator-station",
  reversal_stage_index=2,leaf_station_unit=400,leaf_priest_unit=401,
  worker_station_unit=300,worker_priest_unit=301,
  relocation_old_station_unit_0823=400}
local junior_original_priest={valid=true,unit_number=401}
local junior_lease_0917={status="staged",rec_id=junior_stage_0917.id,
  old_unit=400,old_station={valid=false},priest=junior_original_priest,
  priest_unit=401,worker_unit=300,reversal_ancestor_0853=true}
tp.station_relocation_0823[400]=junior_lease_0917
local junior_entry_0917={status="stored",record_id=junior_stage_0917.id,
  item="junior-cogitator-station",magos_station_unit=100,
  magos_priest_unit=101,worker_station_unit=300,worker_priest_unit=301,
  leaf_station_unit=400,leaf_priest_unit=401,force=force,surface=surface,
  inventory=prior[2]}
tp.station_reversal_depot_0852[junior_stage_0917.id]=junior_entry_0917
rec.reversal_stage_0853=junior_stage_0917
child.status="complete"
child.completed_tick=7500
game.tick=7501
local old_hierarchy=_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  is_direct_subordinate=function(parent,dependent)
    return hierarchy_ok and ((parent==magos and dependent==preserved)
      or (parent==preserved and dependent==originalIntermediate))
  end}
local Depot0917=dofile("tech-priests_src/scripts/core/station_starvation_depot_0852.lua")
local function junior_staged_0917()
  return Depot0917.get_staged(magos,junior_stage_0917)
end
local found_0917,why_0917=junior_staged_0917()
assert(found_0917==junior_entry_0917
  and why_0917=="depot-stored-physical-item-verified"
  and junior_entry_0917.inventory.get_item_count("junior-cogitator-station")==1
  and intermediate_hold.get_item_count("intermediate-cogitator-station")==0
  and source.get_item_count(ITEM)==0,
  "original Intermediate rebuilt carrier must preserve counted first-Junior depot: "
    ..tostring(why_0917))
local function reject_0917(change,restore,label)
  change()
  local got=junior_staged_0917()
  assert(got==nil
    and junior_entry_0917.inventory.get_item_count("junior-cogitator-station")==1,
    "invalid Intermediate rebuild must not inherit Junior inventory: "..label)
  restore()
  assert(junior_staged_0917()==junior_entry_0917,
    "valid original custody must be restored: "..label)
end
reject_0917(function()child.status="active" end,
  function()child.status="complete" end,"incomplete physical construction")
reject_0917(function()child.reversal_followup_0911.original_priest=999 end,
  function()child.reversal_followup_0911.original_priest=301 end,
  "foreign priest lease")
reject_0917(function()hierarchy_ok=false end,
  function()hierarchy_ok=true end,"broken Senior-Intermediate edge")
reject_0917(function()remaining=1 end,
  function()remaining=0 end,"unconsumed Intermediate source item")
reject_0917(function()tp.pairs_by_station[300]=originalIntermediate end,
  function()tp.pairs_by_station[300]=nil end,"retired station still registered")
reject_0917(function()originalIntermediate.station={valid=true,
    name="intermediate-cogitator-station",unit_number=1401,
    position={x=46.25,y=0},force=force,surface=surface} end,
  function()originalIntermediate.station=intermediate_built end,
  "unregistered substitute station")
reject_0917(function()rec.reversal_next_0911.child_writ_id=999 end,
  function()rec.reversal_next_0911.child_writ_id=child.id end,
  "forged child writ")
reject_0917(function()junior_lease_0917.status="custody-error" end,
  function()junior_lease_0917.status="staged" end,
  "original Junior priest lease quarantined")
local old_has_record_0917=realCargo.has_record
realCargo.has_record=function(record)
  if record==child then return true end
  return old_has_record_0917(record)
end
assert(junior_staged_0917()==nil,
  "active Intermediate cargo must block protected Junior depot adoption")
realCargo.has_record=old_has_record_0917
Depot0917=dofile("tech-priests_src/scripts/core/station_starvation_depot_0852.lua")
assert(junior_staged_0917()==junior_entry_0917,
  "module reload must retain original Junior physical custody")
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=old_hierarchy
print("[station-starvation-depot-0917] PASS original rebuilt Intermediate priest and hierarchy, conserved Junior depot, two counted consumed ancestor items, foreign/incomplete/duplicate-cargo refusals and module reload")


-- 0919: the next physical action is ONLY the first Junior construction
-- ghost. No recovered Junior item is moved or consumed by this milestone.
-- Reuse the actual 0916 reconstructed Intermediate and the 0917 original
-- first-Junior depot; add the independently protected second-Junior stage.
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  is_direct_subordinate=function(parent,dependent)
    return hierarchy_ok and ((parent==magos and dependent==preserved)
      or (parent==preserved and dependent==originalIntermediate))
  end}
-- Match the actual 0850 leaf-stage constructor, including its absent
-- reversal_stage_index. Earlier fixtures accidentally invented an index and
-- a noncanonical extra ':1:' segment, hiding the real Factorio refusal.
local last_stage_0919={id="reversal-leaf:9:500",
  phase="in-magos-depot",station_item="junior-cogitator-station",
  worker_station_unit=400,worker_priest_unit=401,
  leaf_station_unit=500,leaf_priest_unit=501,
  relocation_old_station_unit_0823=500}
local last_priest_0919={valid=true,unit_number=501}
local last_lease_0919={status="staged",rec_id=last_stage_0919.id,
  old_unit=500,old_station={valid=false},priest=last_priest_0919,
  priest_unit=501,worker_unit=400,reversal_leaf_0851=true}
tp.station_relocation_0823[500]=last_lease_0919
tp.pairs_by_priest[401]={priest=junior_original_priest,
  station={valid=false},station_unit=400,relocation_pending_0823=true}
tp.pairs_by_priest[501]={priest=last_priest_0919,
  station={valid=false},station_unit=500,relocation_pending_0823=true}
rec.reversal_stage_0851=last_stage_0919
local last_entry_0919={status="stored",record_id=last_stage_0919.id,
  item="junior-cogitator-station",magos_station_unit=100,
  magos_priest_unit=101,worker_station_unit=400,worker_priest_unit=401,
  leaf_station_unit=500,leaf_priest_unit=501,force=force,surface=surface,
  inventory=prior[1]}
tp.station_reversal_depot_0852[last_stage_0919.id]=last_entry_0919
package.loaded["scripts.core.station_starvation_depot_0852"]=Depot0917
package.loaded["scripts.core.station_relocation_0823"]=Relocation0916
package.loaded["scripts.core.station_cargo_0824"]=realCargo
tp.station_expansion_next_id_0256=12
tp.station_expansion_by_worker_0256[1400]=nil
local Junior0919=dofile("tech-priests_src/scripts/core/station_starvation_junior_0919.lua")
local junior_ghost_0919={valid=true,name="entity-ghost",
  ghost_name="junior-cogitator-station",unit_number=1500,
  position={x=70.5,y=0},force=force,surface=surface}
local junior_ghost_present_0919=true
local junior_ghost_calls_0919=0
local junior_api_0919={
  rank=function(p)assert(p==originalIntermediate);return 2 end,
  radius=function(p)assert(p==originalIntermediate);return 40 end,
  find_site=function(p,item,target)
    assert(p==originalIntermediate and item=="junior-cogitator-station"
      and target.x==200);return {x=70,y=0} end,
  create_ghost=function(p,item,site)
    assert(p==originalIntermediate and item=="junior-cogitator-station"
      and site.x==70)
    junior_ghost_calls_0919=junior_ghost_calls_0919+1
    return junior_ghost_0919 end,
  find_ghost=function(p,record)
    assert(p==originalIntermediate
      and record.station_item=="junior-cogitator-station")
    return junior_ghost_present_0919 and junior_ghost_0919 or nil end}
local function reserve_junior_0919()
  return select(2,Junior0919.service(magos,junior_api_0919))
end
game.tick=7590
assert(reserve_junior_0919()=="junior-original-intermediate-build-not-certified"
  and junior_ghost_calls_0919==0)
game.tick=7620
local function deny_junior_0919(change,restore,label,expected)
  change()
  local reason=reserve_junior_0919()
  assert((not expected or reason==expected)
    and reason~="reversal-first-junior-real-ghost-reserved"
    and junior_ghost_calls_0919==0
    and prior[1].get_item_count("junior-cogitator-station")==1
    and prior[2].get_item_count("junior-cogitator-station")==1,
    "unverified first-Junior ghost must not be created: "..label.." "..tostring(reason))
  restore()
end
assert(last_stage_0919.reversal_stage_index==nil
  and last_stage_0919.id=="reversal-leaf:9:500",
  "test must model the exact 0850 production leaf record")
deny_junior_0919(function()last_stage_0919.id="reversal-leaf:9:1:500" end,
  function()last_stage_0919.id="reversal-leaf:9:500" end,
  "forged leaf writ identity","junior-cert:second-junior-stage")
deny_junior_0919(function()last_stage_0919.worker_station_unit=999 end,
  function()last_stage_0919.worker_station_unit=400 end,
  "wrong original Junior worker","junior-cert:second-junior-stage")
deny_junior_0919(function()last_stage_0919.worker_priest_unit=999 end,
  function()last_stage_0919.worker_priest_unit=401 end,
  "wrong original Junior worker priest","junior-cert:second-junior-stage")
deny_junior_0919(function()last_stage_0919.reversal_stage_index=3 end,
  function()last_stage_0919.reversal_stage_index=nil end,
  "forged leaf stage index","junior-cert:second-junior-stage")
deny_junior_0919(function()hierarchy_ok=false end,
  function()hierarchy_ok=true end,"hierarchy")
deny_junior_0919(function()child.status="active" end,
  function()child.status="complete" end,"incomplete Intermediate")
deny_junior_0919(function()junior_original_priest.valid=false end,
  function()junior_original_priest.valid=true end,"lost original Junior priest")
deny_junior_0919(function()last_lease_0919.status="custody-error" end,
  function()last_lease_0919.status="staged" end,"second Junior lease")
deny_junior_0919(function()last_entry_0919.inventory=inv(
    "junior-cogitator-station",0) end,
  function()last_entry_0919.inventory=prior[1] end,"missing second Junior item")
deny_junior_0919(function()remaining=1 end,
  function()remaining=0 end,"unconsumed Intermediate item")
deny_junior_0919(function()rec.reversal_next_0911.status="complete" end,
  function()rec.reversal_next_0911.status="ghost-reserved" end,
  "Intermediate step receipt","junior-cert:intermediate-step-status")
deny_junior_0919(function()child.reversal_followup_0911.original_priest=999 end,
  function()child.reversal_followup_0911.original_priest=301 end,
  "Intermediate original-priest custody","junior-cert:intermediate-ghost-or-priest-custody")
deny_junior_0919(function()rec.reversal_outbound_0895.phase="incomplete" end,
  function()rec.reversal_outbound_0895.phase="senior-build-authorized" end,
  "outbound authority","junior-cert:outbound-phase-or-natural-target")
-- 0920: the original Intermediate pair must schedule the Junior ghost
-- without relying on the Magos receiving another idle scheduler pulse.
-- The exact root/child pointer is persisted by finish_record only after
-- physical Intermediate construction and original-priest reattachment.
local follow_0920={root_writ_id=rec.id,child_writ_id=child.id,
  magos_station_unit=magos.station.unit_number,
  original_priest=originalIntermediate.priest.unit_number,
  original_station_unit=300}
local function dispatch_0920()
  return Junior0919.service_from_intermediate(
    originalIntermediate,junior_api_0919)
end
local absent_0920,absent_reason_0920=dispatch_0920()
assert(absent_0920==false and absent_reason_0920=="not-reversal-intermediate"
  and junior_ghost_calls_0919==0)
originalIntermediate.reversal_junior_followup_0920=follow_0920
follow_0920.root_writ_id=999
assert(select(2,dispatch_0920())=="junior-followup-original-writ-invalid"
  and junior_ghost_calls_0919==0,"foreign root cannot reserve Junior ghost")
follow_0920.root_writ_id=rec.id
follow_0920.original_priest=999
assert(select(2,dispatch_0920())=="junior-followup-original-writ-invalid"
  and junior_ghost_calls_0919==0,"foreign priest cannot reserve Junior ghost")
follow_0920.original_priest=301
game.tick=7590
assert(select(2,dispatch_0920())=="junior-original-intermediate-build-not-certified"
  and junior_ghost_calls_0919==0,"120-tick build escrow remains mandatory")
game.tick=7620
-- 0927: exercise the actual Junior service with the filtered 0256 lookup
-- returning nil while the real ghost is independently visible on its surface.
-- A same-prototype foreign unit or a same-unit foreign force is NOT custody.
local prior_lookup_0927=junior_api_0919.find_ghost
local prior_surface_scan_0927=surface.find_entity
junior_api_0919.find_ghost=function() return nil end
local scan_results_0927={junior_ghost_0919}
surface.find_entity=function(name,position)
  assert(name=="entity-ghost"
    and position.x==junior_ghost_0919.position.x
    and position.y==junior_ghost_0919.position.y,
    "independent readback must query exact real ghost coordinate")
  return scan_results_0927[1]
end
local observed_0927,route_0927=Junior0919.reobserve_created_ghost_0927(
  originalIntermediate,junior_ghost_0919,"junior-cogitator-station",
  junior_api_0919)
assert(observed_0927==junior_ghost_0919
  and route_0927=="independent-exact-engine-unit")
scan_results_0927={{valid=true,name="entity-ghost",
  ghost_name="junior-cogitator-station",unit_number=1501,
  position=junior_ghost_0919.position,force=force,surface=surface}}
assert(select(1,Junior0919.reobserve_created_ghost_0927(
  originalIntermediate,junior_ghost_0919,"junior-cogitator-station",
  junior_api_0919))==nil,"nearby foreign writ must not be adopted")
scan_results_0927={{valid=true,name="entity-ghost",
  ghost_name="junior-cogitator-station",unit_number=1500,
  position=junior_ghost_0919.position,force={index=99},surface=surface}}
assert(select(1,Junior0919.reobserve_created_ghost_0927(
  originalIntermediate,junior_ghost_0919,"junior-cogitator-station",
  junior_api_0919))==nil,"foreign force must not be adopted")
scan_results_0927={junior_ghost_0919}
local first_junior_reason_0919=select(2,dispatch_0920())
junior_api_0919.find_ghost=prior_lookup_0927
surface.find_entity=prior_surface_scan_0927
assert(rec.reversal_junior_0920_last_reason==first_junior_reason_0919
  and rec.reversal_junior_0920_last_tick==game.tick,
  "live follow-up must persist the actual scheduling result")
assert(first_junior_reason_0919=="reversal-first-junior-real-ghost-reserved"
  and junior_ghost_calls_0919==1,
  "first Junior ghost refusal: "..tostring(first_junior_reason_0919))
local junior_child_0919=tp.station_expansion_0256[12]
assert(junior_child_0919 and junior_child_0919.status=="active"
  and junior_child_0919.worker_station_unit==1400
  and junior_child_0919.requester_rank==2
  and junior_child_0919.required_worker_rank==1
  and junior_child_0919.station_item=="junior-cogitator-station"
  and junior_child_0919.reversal_junior_0919.root_writ_id==9
  and junior_child_0919.reversal_junior_0919.stage_id==junior_stage_0917.id
  and junior_child_0919.reversal_junior_0919.original_priest==401
  and rec.reversal_junior_0919.child_writ_id==12
  and tp.station_expansion_by_worker_0256[1400]==12
  and prior[1].get_item_count("junior-cogitator-station")==1
  and prior[2].get_item_count("junior-cogitator-station")==1)
assert(reserve_junior_0919()=="reversal-first-junior-ghost-awaiting-physical-depot-pickup"
  and junior_ghost_calls_0919==1)
assert(select(2,dispatch_0920())=="reversal-first-junior-ghost-awaiting-physical-depot-pickup"
  and junior_ghost_calls_0919==1,"Intermediate scheduler must not duplicate the ghost")
Junior0919=dofile("tech-priests_src/scripts/core/station_starvation_junior_0919.lua")
assert(reserve_junior_0919()=="reversal-first-junior-ghost-awaiting-physical-depot-pickup"
  and junior_ghost_calls_0919==1,"reload must not duplicate Junior ghost")
junior_ghost_present_0919=false
assert(reserve_junior_0919()=="junior-reserved-ghost-or-writ-custody-unverifiable"
  and junior_ghost_calls_0919==1)
junior_ghost_present_0919=true
junior_child_0919.reversal_junior_0919.original_priest=999
assert(reserve_junior_0919()=="junior-reserved-ghost-or-writ-custody-unverifiable")
junior_child_0919.reversal_junior_0919.original_priest=401

-- 0928: the existing 0256 worker service now invokes genuine 0824 inventory
-- pickup after independent first-Junior ghost certification. The first Junior
-- must physically walk back; no ghost or priest becomes a station by fiat.
local junior_remaining_0928=1
local junior_source_0928=junior_entry_0917.inventory
junior_source_0928.get_item_count=function(item)
  assert(item=="junior-cogitator-station");return junior_remaining_0928
end
junior_source_0928.remove=function(stack)
  assert(stack.name=="junior-cogitator-station" and stack.count==1)
  if junior_remaining_0928~=1 then return 0 end
  junior_remaining_0928=0;return 1
end
junior_source_0928.insert=function(stack)
  assert(stack.name=="junior-cogitator-station" and stack.count==1)
  if junior_remaining_0928~=0 then return 0 end
  junior_remaining_0928=1;return 1
end
local allocated_junior_0928=0
game.create_inventory=function(slots)
  assert(slots==1)
  allocated_junior_0928=allocated_junior_0928+1
  local n=0
  return {valid=true,
    get_item_count=function(item)
      assert(item=="junior-cogitator-station");return n end,
    insert=function(stack)
      assert(stack.name=="junior-cogitator-station" and stack.count==1)
      if n~=0 then return 0 end n=1;return 1 end,
    remove=function(stack)
      assert(stack.name=="junior-cogitator-station" and stack.count==1)
      if n~=1 then return 0 end n=0;return 1 end,
    destroy=function()assert(n==0)end}
end
local junior_commands_0928=0
local junior_pickup_api_0928={
  rank=junior_api_0919.rank,
  radius=junior_api_0919.radius,
  find_ghost=junior_api_0919.find_ghost,
  command=function(priest,order)
    assert(priest==originalIntermediate.priest
      and order.type==defines.command.go_to_location
      and order.destination==magos.station.position)
    junior_commands_0928=junior_commands_0928+1
    return true
  end}
-- 0939: the first-Junior depot leg must request the real 0418
-- station-recovery route, never a legacy priority-45 work-radius command.
junior_pickup_api_0928.request=function(pair,destination,reason,opts)
  assert(pair==originalIntermediate and destination==magos.station.position
    and reason=="station-recovery-first-junior-depot-0939"
    and opts.owner=="station-recovery-first-junior-0939"
    and opts.priority==70 and opts.ttl==600 and opts.long_action==true
    and opts.radius==2 and opts.distraction==defines.distraction.none)
  if junior_pickup_api_0928.reject_route_0939 then
    return false,"higher-priority-movement-owned"
  end
  junior_commands_0928=junior_commands_0928+1
  return true,"owned-physical-route"
end
local function pickup_0928()
  return select(2,Junior0919.service_first_junior_pickup_0928(
    originalIntermediate,junior_child_0919,junior_pickup_api_0928))
end
local first_source_saved_0928=junior_source_0928
local second_source_0928=prior[1]
assert(junior_entry_0917.inventory==first_source_saved_0928
  and last_entry_0919.inventory==second_source_0928)
originalIntermediate.mode="idle"
originalIntermediate.priest.position={x=46.25,y=0}
game.tick=7630
local escrow_why_0928=pickup_0928()
assert(escrow_why_0928=="junior-pickup-ghost-escrow-pending"
  and allocated_junior_0928==0,
  "original Junior escrow refused: "..tostring(escrow_why_0928))
game.tick=7750
local wrong_depot_0928=realCargo.pickup(
  originalIntermediate,junior_child_0919,second_source_0928,magos.station)
assert(not wrong_depot_0928 and allocated_junior_0928==0
  and junior_remaining_0928==1,
  "first Junior may never debit the second Junior's inventory")
local wrong_site_0928={valid=true,unit_number=888,
  position={x=46.25,y=0},force=force,surface=surface}
assert(not realCargo.pickup(
  originalIntermediate,junior_child_0919,first_source_saved_0928,wrong_site_0928),
  "foreign source station cannot authorize protected Junior custody")
junior_child_0919.reversal_junior_0919.original_intermediate_priest=999
assert(pickup_0928()=="junior-pickup-original-writ-or-priest-invalid"
  and allocated_junior_0928==0)
junior_child_0919.reversal_junior_0919.original_intermediate_priest=301
originalIntermediate.mode="emergency-gathering"
assert(pickup_0928()=="junior-pickup-awaiting-existing-duty")
originalIntermediate.mode="idle"
local prev_probe_0928=_G.tech_priests_0248_higher_priority_probe
_G.tech_priests_0248_higher_priority_probe=function()
  return {priority="urgent"} end
assert(pickup_0928()=="junior-pickup-awaiting-existing-duty"
  and junior_commands_0928==0 and allocated_junior_0928==0)
_G.tech_priests_0248_higher_priority_probe=function()
  return {priority="idle"} end
junior_pickup_api_0928.reject_route_0939=true
assert(pickup_0928()=="junior-pickup-physical-command-refused"
  and junior_child_0919.reversal_junior_0919.pickup_command_refusal_0939
    =="higher-priority-movement-owned"
  and junior_commands_0928==0 and junior_remaining_0928==1
  and not junior_child_0919.reversal_junior_0919.last_pickup_command_tick,
  "rejected 0418 route cannot fake departure, item debit or movement")
junior_pickup_api_0928.reject_route_0939=false
assert(pickup_0928()=="reversal-first-junior-intermediate-walking-to-magos"
  and junior_commands_0928==1 and junior_remaining_0928==1
  and junior_child_0919.reversal_junior_0919.pickup_command_refusal_0939==nil)
originalIntermediate.priest.position={x=1,y=0}
assert(pickup_0928()=="reversal-first-junior-real-item-carried-from-magos"
  and allocated_junior_0928==1
  and junior_remaining_0928==0
  and junior_entry_0917.status=="outbound"
  and second_source_0928.get_item_count("junior-cogitator-station")==1)
local junior_cargo_0928=realCargo.get(originalIntermediate,junior_child_0919)
assert(junior_cargo_0928 and junior_cargo_0928.status=="carrying"
  and junior_cargo_0928.inventory.get_item_count("junior-cogitator-station")==1
  and not junior_child_0919.relocation_old_station_unit_0823
  and junior_lease_0917.status=="staged"
  and last_lease_0919.status=="staged"
  and originalIntermediate.priest.unit_number==301
  and tp.pairs_by_priest[401].priest.unit_number==401)
Junior0919=dofile("tech-priests_src/scripts/core/station_starvation_junior_0919.lua")
assert(pickup_0928()=="reversal-first-junior-real-item-carried-from-magos"
  and allocated_junior_0928==1
  and junior_remaining_0928==0
  and second_source_0928.get_item_count("junior-cogitator-station")==1,
  "same cargo survives source reload without a second debit")
_G.tech_priests_0248_higher_priority_probe=prev_probe_0928
print("[station-starvation-junior-pickup-0928] PASS original Intermediate physical walk, exact first-Junior Magos inventory debit into real 0824 carrier, second depot conserved, 120-tick escrow, existing-duty priority, forged source refusal, persisted cargo and no phantom Junior build")

do
-- 0930: the original Intermediate carries the counted first Junior station
-- item outward under the SAME child, with an independent 120-tick pickup
-- escrow. A second Junior item and both original staged priest leases remain
-- untouched; reaching the ghost does NOT authorize a build.
local outbound_calls_0930=0
junior_pickup_api_0928.command=function(priest,order)
  assert(priest==originalIntermediate.priest
    and order.type==defines.command.go_to_location
    and order.destination==junior_ghost_0919.position
    and order.radius==2)
  outbound_calls_0930=outbound_calls_0930+1
  return true
end
local function outward_0930()
  return select(2,Junior0919.service_first_junior_outward_transit_0930(
    originalIntermediate,junior_child_0919,junior_pickup_api_0928))
end
game.tick=7810
assert(outward_0930()=="junior-transit-pickup-escrow-pending"
  and outbound_calls_0930==0)
game.tick=7870
originalIntermediate.mode="emergency-gathering"
assert(outward_0930()=="junior-transit-awaiting-existing-duty"
  and outbound_calls_0930==0)
originalIntermediate.mode="idle"
junior_ghost_present_0919=false
assert(outward_0930()=="junior-transit-exact-ghost-or-forward-radius-invalid"
  and outbound_calls_0930==0)
junior_ghost_present_0919=true
last_lease_0919.status="custody-error"
assert(outward_0930()=="junior-transit-original-writ-or-priest-invalid"
  and outbound_calls_0930==0,
  "second Junior staged priest must retain exclusive original lease")
last_lease_0919.status="staged"
junior_lease_0917.status="custody-error"
assert(outward_0930()=="junior-transit-original-writ-or-priest-invalid"
  and outbound_calls_0930==0)
junior_lease_0917.status="staged"
local saved_second_0930=last_entry_0919.inventory
last_entry_0919.inventory=junior_source_0928
assert(outward_0930():find("junior-transit-physical-custody-invalid:",1,true)==1
  and outbound_calls_0930==0,"distinct second Junior inventory is mandatory")
last_entry_0919.inventory=saved_second_0930
-- 0931: an engine-position observation without a previously accepted real
-- movement command must not become an original-priest build receipt.
originalIntermediate.priest.position={x=junior_ghost_0919.position.x,
  y=junior_ghost_0919.position.y}
assert(outward_0930()=="junior-transit-no-physical-departure-receipt"
  and outbound_calls_0930==0
  and not junior_child_0919.reversal_junior_0919.arrived_tick)
originalIntermediate.priest.position={x=1,y=0}
assert(outward_0930()=="reversal-first-junior-intermediate-carrying-to-ghost"
  and outbound_calls_0930==1
  and junior_child_0919.reversal_junior_0919.transit_status=="walking")
assert(outward_0930()=="reversal-first-junior-intermediate-carrying-to-ghost"
  and outbound_calls_0930==1,"no repeated command within 60 ticks")
originalIntermediate.priest.position={x=junior_ghost_0919.position.x,y=junior_ghost_0919.position.y}
game.tick=7930
assert(outward_0930()=="reversal-first-junior-real-item-arrived-at-ghost"
  and junior_child_0919.reversal_junior_0919.transit_status=="arrived"
  and junior_child_0919.reversal_junior_0919.arrived_tick==7930)
Junior0919=dofile("tech-priests_src/scripts/core/station_starvation_junior_0919.lua")
junior_child_0919.reversal_junior_0919.transit_status="timed-out"
assert(outward_0930()=="junior-transit-physical-travel-timeout",
  "timeout is terminal even if the carrier later appears beside the ghost")
junior_child_0919.reversal_junior_0919.transit_status="arrived"
junior_child_0919.reversal_junior_0919.transit_started_tick=game.tick+1
assert(outward_0930()=="junior-transit-clock-reversed",
  "save/reload clock rollback must not certify physical arrival")
junior_child_0919.reversal_junior_0919.transit_started_tick=7870
junior_child_0919.reversal_junior_0919.transit_last_command_tick=nil
assert(outward_0930()=="junior-transit-no-physical-departure-receipt",
  "missing engine movement command must not certify arrival")
junior_child_0919.reversal_junior_0919.transit_last_command_tick=7870
assert(outward_0930()=="reversal-first-junior-real-item-arrived-at-ghost"
  and outbound_calls_0930==1 and allocated_junior_0928==1
  and junior_remaining_0928==0
  and saved_second_0930.get_item_count("junior-cogitator-station")==1
  and not junior_child_0919.relocation_old_station_unit_0823
  and junior_lease_0917.status=="staged"
  and last_lease_0919.status=="staged"
  and realCargo.get(originalIntermediate,junior_child_0919).status=="carrying",
  "engine cargo and both original priest leases must survive transit/reload")
-- 0932: a second full 120-tick physical arrival escrow gates the
-- ORIGINAL Junior priest/lease, never new priest or a conjured station item.
local arm_api_0932={
  rank=junior_pickup_api_0928.rank,
  radius=junior_pickup_api_0928.radius,
  find_ghost=junior_pickup_api_0928.find_ghost,
  command=junior_pickup_api_0928.command}
local function arm_0932()
  return select(2,Junior0919.arm_original_first_junior_rebuild_0932(
    originalIntermediate,junior_child_0919,arm_api_0932))
end
local function verify_0932(ghost,built)
  return Junior0919.verify_authorized_first_junior_rebuild_0932(
    originalIntermediate,junior_child_0919,arm_api_0932,ghost,built)
end
local initial_0932=junior_child_0919.reversal_junior_0919
game.tick=8049
assert(arm_0932()=="first-junior-build-arrival-or-clock-not-certified"
  and junior_lease_0917.status=="staged" and not initial_0932.build_authorized_tick)
-- Match real 0853 engine lease data established during physical leaf mining:
-- the original preserved priest and detached original pair remain authoritative.
junior_lease_0917.pair=tp.pairs_by_priest[401]
junior_lease_0917.item="junior-cogitator-station"
junior_lease_0917.force=force
junior_lease_0917.surface=surface
junior_lease_0917.target=nil
assert(junior_lease_0917.pair.priest==junior_original_priest)
game.tick=8050
junior_ghost_present_0919=false
assert(arm_0932():find("first-junior-build-transit-custody-invalid:",1,true)==1
  and junior_lease_0917.status=="staged",
  "lost real ghost never arms original Junior priest")
junior_ghost_present_0919=true
junior_lease_0917.priest_unit=999
assert(arm_0932():find("first-junior-build-original-priest-lease-refused:",1,true)==1
  and junior_lease_0917.status=="staged")
junior_lease_0917.priest_unit=401
assert(arm_0932()=="reversal-first-junior-physical-build-authorized"
  and junior_lease_0917.status=="mined"
  and junior_lease_0917.rec_id==junior_child_0919.id
  and junior_lease_0917.worker_unit==1400
  and junior_child_0919.relocation_old_station_unit_0823==400
  and initial_0932.build_authorized_tick==8050
  and initial_0932.build_ghost_unit==1500
  and last_lease_0919.status=="staged"
  and junior_remaining_0928==0
  and saved_second_0930.get_item_count("junior-cogitator-station")==1)
assert(verify_0932(junior_ghost_0919,nil),
  "exact staged original Junior priest + counted cargo must authorize real 0256")
junior_child_0919.reversal_junior_0919.build_ghost_unit=999
assert(not verify_0932(junior_ghost_0919,nil),
  "forged ghost identity must block native build")
junior_child_0919.reversal_junior_0919.build_ghost_unit=1500
last_entry_0919.inventory=junior_source_0928
assert(not verify_0932(junior_ghost_0919,nil),
  "spent or aliased second Junior depot must veto build")
last_entry_0919.inventory=saved_second_0930
junior_lease_0917.status="custody-error"
assert(not verify_0932(junior_ghost_0919,nil),
  "lost original priest lease must block build")
junior_lease_0917.status="mined"
assert(verify_0932(junior_ghost_0919,nil))
Junior0919=dofile("tech-priests_src/scripts/core/station_starvation_junior_0919.lua")
assert(verify_0932(junior_ghost_0919,nil)
  and not junior_child_0919.build_due_tick
  and allocated_junior_0928==1
  and junior_lease_0917.status=="mined"
  and last_lease_0919.status=="staged",
  "source reload never invents a built station or spends second Junior")
print("[station-starvation-first-junior-build-0932] PASS exact original 0853 priest lease armed only after independent arrival escrow, per-tick 0256 authorization, real 0824 carried item and untouched second Junior depot")
-- 0933: execute the same 0824 debit / 0823 begin-build / original
-- priest claim lifecycle as 0256, then prove original second Junior depot
-- remains accessible both before and after first child completion.
local first_original_pair_0933=tp.pairs_by_priest[401]
local original_h_0933=_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  is_direct_subordinate=function(parent,dependent)
    return hierarchy_ok and ((parent==magos and dependent==preserved)
      or (parent==preserved and dependent==originalIntermediate)
      or (parent==originalIntermediate
        and dependent==first_original_pair_0933))
  end}
local before_build_second_0933=Depot0917.get_staged(magos,last_stage_0919)
assert(before_build_second_0933==last_entry_0919
  and realCargo.get(originalIntermediate,junior_child_0919).status=="carrying")
local debit_0933,debited_why_0933=realCargo.begin_build(
  originalIntermediate,junior_child_0919)
assert(debit_0933,debited_why_0933)
assert(Relocation0916.begin_build(junior_child_0919,originalIntermediate)
  and junior_lease_0917.status=="building"
  and realCargo.get(originalIntermediate,junior_child_0919).status=="building"
  and realCargo.get(originalIntermediate,junior_child_0919).inventory
    .get_item_count("junior-cogitator-station")==0)
local first_built_0933={valid=true,name="junior-cogitator-station",
  unit_number=1600,position={x=70.5,y=0},force=force,surface=surface}
assert(Relocation0916.claim(first_built_0933),
  "engine on_built must pair the ORIGINAL first Junior priest")
assert(first_original_pair_0933.station==first_built_0933
  and first_original_pair_0933.priest==junior_original_priest
  and tp.pairs_by_station[1600]==first_original_pair_0933
  and tp.pairs_by_station[400]==nil
  and tp.station_by_priest[401]==1600
  and tp.station_relocation_0823[400]==nil
  and last_lease_0919.status=="staged")
local dep_inflight_0933=Depot0917.get_staged(magos,last_stage_0919)
assert(dep_inflight_0933==last_entry_0919,
  "after real first Junior built but before completion, second depot must not vanish")
assert(verify_0932(nil,first_built_0933),
  "0256 must accept physically built original Junior while 0824 is building")
assert(realCargo.complete(originalIntermediate,junior_child_0919),
  "no extra station item may be created on completion")
junior_child_0919.status="complete"
junior_child_0919.completed_tick=game.tick
local dep_done_0933=Depot0917.get_staged(magos,last_stage_0919)
assert(dep_done_0933==last_entry_0919
  and saved_second_0930.get_item_count("junior-cogitator-station")==1
  and junior_remaining_0928==0
  and first_original_pair_0933.station==first_built_0933
  and first_original_pair_0933.priest==junior_original_priest
  and last_lease_0919.status=="staged",
  "completed native first-Junior rebuild must conserve second original depot")
first_original_pair_0933.priest.unit_number=999
assert(Depot0917.get_staged(magos,last_stage_0919)==nil,
  "forged rebuilt priest must never adopt second Junior source")
first_original_pair_0933.priest.unit_number=401
assert(Depot0917.get_staged(magos,last_stage_0919)==last_entry_0919)
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=original_h_0933
print("[station-starvation-second-junior-depot-0933] PASS counted first Junior item build and original #401 priest claim, stable second Junior depot during active 0824 building and after completion, forged priest refusal and no second item debit")


local planner0930=assert(io.open(
  "tech-priests_src/scripts/magos_station_expansion.lua","r")):read("*a")
assert(planner0930:find("service_first_junior_outward_transit_0930",1,true)
  and planner0930:find("reversal-first-junior-real-item-carried-from-magos",1,true)
  and planner0930:find("find_ghost=find_ghost_for_record",1,true)
  and planner0930:find("arm_original_first_junior_rebuild_0932",1,true)
  and planner0930:find("verify_authorized_first_junior_rebuild_0932",1,true),
  "production 0256 must route real first Junior carry into outward transit")
print("[station-starvation-first-junior-transit-0930] PASS physical original Intermediate carrier to exact Junior ghost, post-pickup escrow, existing duties, unique second depot, original leases, reload persistence, no duplicate inventory debit and no premature build")
print("[station-starvation-transit-receipt-0931] PASS reject forged ghost proximity without real command, persisted terminal timeout, clock rollback and missing departure receipt; preserve counted cargo and second Junior")
end -- scoped 0930 regression; Lua 5.2 chunks have a 200-local limit

-- 0929: actual Factorio run 40571134092 snapped the first Junior ghost
-- from (-9.5,91.5) to (-9,92); exact ghost #911 was real and inside radius,
-- but its distance to ore INCREASED (188.5 -> 194.5 squared). The placement
-- planner must reject marginally forward requests before touching the world.
local Snap0929=dofile("tech-priests_src/scripts/core/station_starvation_snap_geometry_0929.lua")
local origin_0929={x=0,y=0}
local ore_0929={x=10,y=0}
local marginal_0929={x=0.25,y=0}
local reversed_0929={x=-0.25,y=0}
assert((marginal_0929.x-ore_0929.x)^2
    <(origin_0929.x-ore_0929.x)^2,
  "recreate naive pre-snap selection that appears forward")
assert((reversed_0929.x-ore_0929.x)^2
    >(origin_0929.x-ore_0929.x)^2,
  "recreate real grid snap that reverses target progress")
assert(not Snap0929.forward_after_snap(
  origin_0929,marginal_0929,ore_0929,1.5),
  "barely forward requested ghost is unsafe under legal Factorio snap")
assert(Snap0929.forward_after_snap(
  origin_0929,{x=6,y=0},ore_0929,1.5),
  "robust forward site remains legal after full 1.5-tile snap")
assert(not Snap0929.forward_after_snap(
  origin_0929,{x=1.5,y=0},ore_0929,2.5),
  "larger snap uncertainty must reject borderline geometry")
assert(not Snap0929.forward_after_snap(
  origin_0929,{x=6,y=0},nil,1.5),
  "missing ore target must fail closed")
local planner_code_0929=assert(io.open(
  "tech-priests_src/scripts/magos_station_expansion.lua","r")):read("*a")
assert(planner_code_0929:find("SnapGeometry0929.forward_after_snap",1,true)
  and planner_code_0929:find("station.position,pos,required_target,1.5",1,true),
  "actual 0256 candidate selector must enforce snap-safe progress")
print("[station-starvation-snap-geometry-0929] PASS marginal forward site rejected, full bounded snap preserves progress, strict missing-target refusal and actual planner integration")

local src0919=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
local executor0919=src0919:read("*a");src0919:close()
assert(executor0919:find("StarvationJunior0919.service",1,true)
  and executor0919:find("StarvationJunior0919.service_from_intermediate",1,true)
  and executor0919:find("original.reversal_junior_followup_0920=",1,true)
  and executor0919:find("service_first_junior_pickup_0928",1,true)
  and executor0919:find("if rec.reversal_junior_0919 then",1,true)
  and executor0919:find("return true",executor0919:find(
    "if rec.reversal_junior_0919 then",1,true),true),
  "production scheduler must reserve Junior ghost but forbid remote stock debit")
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=old_hierarchy
print("[station-starvation-junior-dispatch-0920] PASS original Intermediate scheduler continuation, 120-tick escrow, forged root/priest rejection, idempotent ghost, persistent diagnostic and no item debit")
print("[station-starvation-junior-ghost-readback-0927] PASS exact-unit independent surface readback, foreign writ/force refusal and live first-Junior reservation without filtered lookup")
print("[station-starvation-first-junior-0919] PASS original Intermediate build escrow, exact two conserved Junior depots, original priests, hierarchy, real ghost identity, one persistent child writ, no premature debit, reload and negative custody")

-- 0921: the live 2.0.77 engine had the exact Intermediate continuation pointer
-- but no 0920 scheduling receipt after 15,000 ticks. The 0264/0277 priority
-- stack can return before the 0256 inner tick hook, and 0599 may sleep an idle
-- rebuilt pair. Exercise the actual late wrapper and sleep governor together.
do
  local saved={
    game=_G.game,storage=_G.storage,script=_G.script,
    commands=_G.commands,defines=_G.defines,tick_pair=_G.tick_pair,
    expansion=_G.TECH_PRIESTS_STATION_EXPANSION_0256,
    prior_sleep=_G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599,
    prior_junior=_G.TECH_PRIESTS_TICK_PAIR_BEFORE_JUNIOR_0921,
    sleep_api=_G.TechPriestsEfficiencyEconomy0599,
    wake=_G.tech_priests_efficiency_0599_wake_pair
  }
  _G.game={tick=0,connected_players={}}
  _G.storage={tech_priests={}}
  _G.script=nil;_G.commands=nil;_G.defines=nil
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599=nil
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_JUNIOR_0921=nil
  local ordinary,followups=0,0
  _G.tick_pair=function()
    ordinary=ordinary+1
    return "priority-already-handled"
  end
  _G.TECH_PRIESTS_STATION_EXPANSION_0256={
    service_reversal_junior_followup_0921=function(pair)
      assert(type(pair.reversal_junior_followup_0920)=="table")
      followups=followups+1
      return true,"reversal-first-junior-real-ghost-reserved"
    end
  }
  local Sleep0599=dofile("tech-priests_src/scripts/core/efficiency_economy_0599.lua")
  Sleep0599.install()
  local JuniorTick0921=dofile(
    "tech-priests_src/scripts/core/station_starvation_junior_dispatch_0921.lua")
  assert(JuniorTick0921.install()==true and JuniorTick0921.install()==true,
    "late per-pair hook must install once")
  local surface={index=1};local force={index=1}
  local station={valid=true,unit_number=19021,
    position={x=0,y=0},surface=surface,force=force}
  local priest={valid=true,unit_number=19022,
    position={x=0,y=0},surface=surface,force=force}
  local pair={station=station,priest=priest,mode="idle"}
  assert(tick_pair(pair)=="priority-already-handled"
    and ordinary==1 and followups==0,
    "ordinary priority result must remain unchanged without a follow-up")
  game.tick=10
  assert(tick_pair(pair)==nil and ordinary==1 and followups==0,
    "unassigned idle pairs must retain the existing sleep economy")
  pair.reversal_junior_followup_0920={root_writ_id=9}
  game.tick=20
  assert(tick_pair(pair)=="priority-already-handled"
    and ordinary==2 and followups==1,
    "original Intermediate must wake and dispatch after an earlier priority return")
  game.tick=30
  assert(tick_pair(pair)=="priority-already-handled"
    and ordinary==3 and followups==2,
    "pending continuation must remain scheduled without duplicate tick hooks")
  pair.reversal_junior_followup_0920="forged-non-table"
  game.tick=40
  tick_pair(pair)
  assert(followups==2,"malformed continuation cannot dispatch a ghost")
  -- 0922: a real engine run retained the original Intermediate pointer but
  -- never invoked the 0921 per-pair wrapper. Exercise the separate canonical
  -- 0600 broker service with a rotating original-reversal index; no new
  -- event registration, material mutation or unverified ghost construction.
  local prior_broker=_G.TechPriestsRuntimeTickBroker0600
  local registered,registered_intermediate
  _G.TechPriestsRuntimeTickBroker0600={
    register_service=function(spec)
      assert(spec.category=="construction" and spec.interval==30
        and spec.dynamic_budget==false and spec.budget==4)
      if spec.name=="station-starvation-first-junior-0922" then
        registered=spec
      elseif spec.name=="station-starvation-intermediate-0924" then
        registered_intermediate=spec
      else
        error("unexpected broker service: "..tostring(spec.name))
      end
      return spec
    end
  }
  assert(JuniorTick0921.install_broker_0922()==true
    and type(registered.fn)=="function",
    "Junior continuation must register with the existing 0600 broker")
  pair.reversal_junior_followup_0920={root_writ_id=9}
  local pair2={station={valid=true,unit_number=19023},
    priest={valid=true,unit_number=19024},
    reversal_junior_followup_0920={root_writ_id=10}}
  local tp=_G.storage.tech_priests
  tp.station_reversal_followup_0911={[100]=9,[200]=10}
  tp.station_expansion_0256={
    [9]={reversal_stage_0854={leaf_priest_unit=19022}},
    [10]={reversal_stage_0854={leaf_priest_unit=19024}}}
  tp.pairs_by_priest={[19022]=pair,[19024]=pair2}
  local first=registered.fn({tick=50},1)
  assert(first.processed==1 and first.acted==1 and followups==3
    and tp.station_junior_broker_cursor_0922==100,
    "broker must dispatch original first root without a pair tick")
  local second=registered.fn({tick=80},1)
  assert(second.processed==1 and second.acted==1 and followups==4
    and tp.station_junior_broker_cursor_0922==200,
    "broker must rotate to next root rather than starving it")
  pair.reversal_junior_followup_0920="forged"
  local third=registered.fn({tick=110},1)
  assert(third.acted==0 and followups==4,
    "malformed pointer must never reach construction authority")
  tp.station_reversal_followup_0911[200]=999
  local fourth=registered.fn({tick=140},1)
  assert(fourth.acted==0 and followups==4,
    "unresolvable root must not dispatch any station ghost")
  tp.station_reversal_followup_0911={}
  local empty=registered.fn({tick=170},1)
  assert(empty.processed==0 and empty.acted==nil,
    "no active roots must cause no broker work")
  -- 0937: actual 2.0.77 runs 40588670150/40589519063 created the
  -- first-Junior ghost but never dispatched its original Intermediate's
  -- physical 0256 pickup; the depot stayed at 1 until the 7200-tick
  -- terminal timeout. The SAME 0922 broker must now service the exact
  -- active child without waiting for a legacy pair tick.
  do -- 0938: bound 0937 regression locals under Lua 5.2's 200-local limit.
  local prior_probe=_G.tech_priests_0248_higher_priority_probe
  _G.tech_priests_0248_higher_priority_probe=function()
    return {priority="idle"}
  end
  local physical_calls=0
  local physical_child={id=901,status="active",ghost_unit=902,
    station_item="junior-cogitator-station",
    worker_station_unit=19021,requester_station_unit=19021,
    phase="junior-pickup-ghost-escrow-pending",
    reversal_junior_0919={root_writ_id=9,stage_id="first-9",
      original_intermediate_priest=19022,magos_station_unit=100}}
  local physical_root={id=9,status="complete",worker_station_unit=100,
    reversal_stage_0854={leaf_priest_unit=19022},
    reversal_stage_0853={id="first-9"},
    reversal_junior_0919={status="ghost-reserved",
      child_writ_id=901,ghost_unit=902}}
  pair.station.name="intermediate-cogitator-station"
  pair.reversal_junior_followup_0920={root_writ_id=9}
  tp.station_reversal_followup_0911={[100]=9}
  tp.station_expansion_0256={[9]=physical_root,[901]=physical_child}
  tp.station_expansion_by_worker_0256={[19021]=901}
  tp.pairs_by_station={[19021]=pair,[100]={station={valid=true,unit_number=100}}}
  tp.pairs_by_priest={[19022]=pair}
  -- 0967: the newly rebuilt original Intermediate must be reserved BEFORE
  -- its first Junior ghost exists. Otherwise 0640 can install a fresh
  -- emergency-smelter ingredient plan in the small post-rebind gap.
  -- The reservation is only scheduling: it neither changes inventory nor
  -- grants station construction authority.
  (function()
    local prior_root_stage=physical_root.reversal_stage_0854
    local prior_next=physical_root.reversal_next_0911
    local prior_first=physical_root.reversal_stage_0853
    local prior_second=physical_root.reversal_stage_0851
    local prior_plan=physical_root.reversal_outbound_0895
    local prior_item=physical_root.station_item
    local prior_junior=physical_root.reversal_junior_0919
    local prior_worker=tp.station_expansion_by_worker_0256[19021]
    local prior_magos=tp.pairs_by_station[100]
    local original_name=pair.station.name
    local magos_station={valid=true,unit_number=100,
      position={x=-13,y=-7},force=force,surface=surface}
    local magos={station=magos_station,
      priest={valid=true,unit_number=101,force=force,surface=surface},
      resource_expansion_0259={chain_0820={target={x=30,y=200}}}}
    local intermediate_child={id=900,status="complete",
      station_item="intermediate-cogitator-station",
      ghost_unit=905,ghost_position={x=0,y=0},
      relocation_old_station_unit_0823=500,
      reversal_followup_0911={root_writ_id=9,
        stage_id="original-intermediate-9",original_priest=19022}}
    physical_root.reversal_junior_0919=nil
    physical_root.reversal_next_0911={
      status="ghost-reserved",child_writ_id=900,ghost_unit=905}
    physical_root.reversal_stage_0854={id="original-intermediate-9",
      leaf_station_unit=500,leaf_priest_unit=19022,phase="in-magos-depot"}
    physical_root.reversal_stage_0853={id="first-9",phase="in-magos-depot"}
    physical_root.reversal_stage_0851={phase="in-magos-depot"}
    physical_root.reversal_outbound_0895={
      phase="senior-build-authorized",target={x=30,y=200}}
    physical_root.station_item="senior-cogitator-station"
    tp.pairs_by_station[100]=magos
    tp.station_expansion_0256[900]=intermediate_child
    tp.station_expansion_by_worker_0256[19021]=nil
    pair.station.name="intermediate-cogitator-station"
    local reserved,writ=future.future_worker_reserved(pair)
    assert(reserved and writ==physical_root,
      "completed Intermediate rebind must reserve FUTURE 0647 work before ghost")
    intermediate_child.ghost_unit=999
    assert(not future.future_worker_reserved(pair),
      "wrong physical Intermediate ghost must not reserve new work")
    intermediate_child.ghost_unit=905
    magos.resource_expansion_0259.chain_0820.target.x=31
    assert(not future.future_worker_reserved(pair),
      "changed natural ore target must release preghost reservation")
    magos.resource_expansion_0259.chain_0820.target.x=30
    physical_root.reversal_junior_0919={status="ghost-reserved"}
    assert(not future.future_worker_reserved(pair),
      "preghost reservation must expire when a child ghost appears")
    physical_root.reversal_junior_0919=prior_junior
    physical_root.reversal_stage_0854=prior_root_stage
    physical_root.reversal_next_0911=prior_next
    physical_root.reversal_stage_0853=prior_first
    physical_root.reversal_stage_0851=prior_second
    physical_root.reversal_outbound_0895=prior_plan
    physical_root.station_item=prior_item
    tp.station_expansion_by_worker_0256[19021]=prior_worker
    tp.station_expansion_0256[900]=nil
    tp.pairs_by_station[100]=prior_magos
    pair.station.name=original_name
  end)()
  -- 0938: exact original first-Junior writ reserves FUTURE 0647 work.
  local old_reservation=tp.station_reversal_followup_0911[100]
  local reserved_0938,rec_0938=future.future_worker_reserved(pair)
  assert(reserved_0938 and rec_0938==physical_child,
    "original first-Junior child must reserve future 0647 planning")
  tp.station_reversal_followup_0911[100]=999
  assert(not future.future_worker_reserved(pair),
    "foreign Magos reversal index must not reserve worker")
  tp.station_reversal_followup_0911[100]=old_reservation
  physical_child.ghost_unit=999
  assert(not future.future_worker_reserved(pair),
    "foreign first-Junior ghost must not reserve worker")
  physical_child.ghost_unit=902
  _G.TECH_PRIESTS_STATION_EXPANSION_0256
    .service_station_expansion_assignment=function(worker)
      assert(worker==pair and physical_child.status=="active")
      physical_calls=physical_calls+1
      physical_child.phase="reversal-first-junior-intermediate-walking-to-magos"
      return true,physical_child.phase
    end
  -- The owner must be asked to yield ONLY uncommitted 0647 planning.
  local old_governor=_G.TechPriestsInfrastructureFirstGovernor0640
  local handoffs=0
  _G.TechPriestsInfrastructureFirstGovernor0640={
    yield_uncommitted_recipe_to_reversal_0938=function(worker,child)
      assert(worker==pair and child==physical_child)
      handoffs=handoffs+1
      worker.mode="idle"
      return true,"junior-recipe-handoff-uncommitted-plan-retired"
    end}
  pair.mode="infrastructure-material-acquisition-0647"
  game.tick=180
  local pickup=registered.fn({tick=180},1)
  assert(handoffs==1 and pair.mode=="idle",
    "broker must request 0647-owned planning-only handoff before pickup")
  assert(pickup.processed==1 and physical_calls==1
    and physical_root.reversal_junior_0937_last_tick==180
    and physical_root.reversal_junior_0937_last_reason
      =="reversal-first-junior-intermediate-walking-to-magos",
    "canonical broker must reach original 0256 physical pickup executor")
  pair.active_task={kind="combat"}
  game.tick=210
  registered.fn({tick=210},1)
  assert(physical_calls==1 and physical_root.reversal_junior_0937_last_reason
      =="junior-broker-priority-deferred",
    "active combat must not be preempted by broker pickup")
  pair.active_task=nil
  _G.tech_priests_0248_higher_priority_probe=function()
    return {priority="combat"}
  end
  game.tick=240
  registered.fn({tick=240},1)
  assert(physical_calls==1,
    "higher-priority combat probe must defer physical pickup")
  _G.tech_priests_0248_higher_priority_probe=function()
    return {priority="idle"}
  end
  tp.station_expansion_by_worker_0256[19021]=999
  game.tick=270
  registered.fn({tick=270},1)
  assert(physical_calls==1,
    "foreign worker reservation must never reach physical 0256 executor")
  tp.station_expansion_by_worker_0256[19021]=901
  physical_child.reversal_junior_0919.stage_id="forged"
  game.tick=300
  registered.fn({tick=300},1)
  assert(physical_calls==1,
    "forged original Junior stage must not dispatch cargo pickup")
  physical_child.reversal_junior_0919.stage_id="first-9"
  physical_root.reversal_stage_0853=nil
  game.tick=330
  assert(pcall(registered.fn,{tick=330},1) and physical_calls==1,
    "missing original stage must fail closed without nil indexing")
  physical_root.reversal_stage_0853={id="first-9"}
  physical_child.reversal_junior_0919="forged-string"
  game.tick=345
  assert(pcall(registered.fn,{tick=345},1) and physical_calls==1,
    "malformed active-child follow-up must fail closed")
  physical_child.reversal_junior_0919={root_writ_id=9,stage_id="first-9",
    original_intermediate_priest=19022,magos_station_unit=100}
  physical_root.reversal_stage_0853="forged-string"
  game.tick=350
  assert(pcall(registered.fn,{tick=350},1) and physical_calls==1,
    "malformed original Junior stage must fail closed")
  physical_root.reversal_stage_0853={id="first-9"}
  pair.mode="combat"
  game.tick=360
  registered.fn({tick=360},1)
  assert(physical_calls==1,
    "busy original Intermediate must not be preempted")
  pair.mode="idle"
  game.tick=390
  registered.fn({tick=390},1)
  assert(physical_calls==2,
    "same original active child must resume after priority clears")
  physical_child.status="complete"
  game.tick=420
  registered.fn({tick=420},1)
  assert(physical_calls==2,
    "completed child cannot be serviced again by the broker")
  -- 0967: a worker may be idle while its old 0647 ingredient plan remains.
  -- The canonical broker must ask 0640 to retire only that uncommitted plan
  -- before dispatching physical 0256 pickup; active work stays protected.
  physical_child.status="active"
  pair.mode="idle"
  pair.infrastructure_recipe_request_0647={
    item="tech-priests-emergency-smelter",missing="stone"}
  game.tick=450
  registered.fn({tick=450},1)
  assert(handoffs==2 and physical_calls==3
    and physical_root.reversal_junior_0967_handoff
    and physical_root.reversal_junior_0967_handoff.accepted==true,
    "idle stale 0647 request must reach its owner before real pickup")
  pair.infrastructure_recipe_request_0647=nil
  physical_child.status="complete"
  _G.tech_priests_0248_higher_priority_probe=prior_probe
  _G.TechPriestsInfrastructureFirstGovernor0640=old_governor
  end -- 0937/0938 scoped test locals
  -- 0924: the 2.0.77 engine can finish the Senior rebuild without
  -- scheduling its next Intermediate ghost. The canonical broker must retry
  -- that exact original root, rotate fairly, and never reissue an owned ghost.
  assert(JuniorTick0921.install_intermediate_broker_0924()==true
    and registered_intermediate
    and type(registered_intermediate.fn)=="function")
  local intermediate_calls=0
  local magos_a={station={valid=true,unit_number=100}}
  local magos_b={station={valid=true,unit_number=200}}
  tp.pairs_by_station={[100]=magos_a,[200]=magos_b}
  tp.station_reversal_followup_0911={[100]=9,[200]=10}
  local root_a={status="complete",worker_station_unit=100,
    reversal_outbound_0895={phase="senior-build-authorized"},
    reversal_stage_0854={leaf_priest_unit=19022}}
  local root_b={status="complete",worker_station_unit=200,
    reversal_outbound_0895={phase="senior-build-authorized"},
    reversal_stage_0854={leaf_priest_unit=19024}}
  tp.station_expansion_0256={[9]=root_a,[10]=root_b}
  _G.TECH_PRIESTS_STATION_EXPANSION_0256
    .service_reversal_intermediate_0911=function(magos)
      intermediate_calls=intermediate_calls+1
      assert(magos==magos_a or magos==magos_b)
      return true,"reversal-intermediate-real-ghost-reserved"
    end
  game.tick=200
  local i1=registered_intermediate.fn({tick=200},1)
  assert(i1.processed==1 and i1.acted==1 and intermediate_calls==1
    and tp.station_intermediate_broker_cursor_0924==100
    and root_a.reversal_intermediate_0924_last_tick==200
    and root_a.reversal_intermediate_0924_last_reason
      =="reversal-intermediate-real-ghost-reserved",
    "Intermediate broker must retry exact completed Magos root")
  root_a.reversal_next_0911={status="ghost-reserved",child_writ_id=42}
  game.tick=230
  local i2=registered_intermediate.fn({tick=230},1)
  assert(i2.acted==1 and intermediate_calls==2
    and tp.station_intermediate_broker_cursor_0924==200,
    "Intermediate broker must rotate to next original Magos root")
  root_b.status="active"
  game.tick=260
  assert(registered_intermediate.fn({tick=260},2).acted==0
    and intermediate_calls==2,
    "reserved ghost and incomplete roots must never be reissued")
  root_a.reversal_next_0911=nil
  root_a.reversal_outbound_0895.phase="not-authorized"
  game.tick=290
  assert(registered_intermediate.fn({tick=290},2).acted==0
    and intermediate_calls==2,
    "unapproved Senior rebuild must not dispatch ghost authority")
  root_a.reversal_outbound_0895.phase="senior-build-authorized"
  tp.pairs_by_station[100]={station={valid=true,unit_number=999}}
  game.tick=320
  assert(registered_intermediate.fn({tick=320},2).acted==0
    and intermediate_calls==2,
    "forged Magos station identity must not dispatch ghost authority")
  tp.station_reversal_followup_0911={}
  assert(registered_intermediate.fn({tick=350},2).processed==0,
    "empty reversal index must not schedule Intermediate construction")
  _G.TechPriestsRuntimeTickBroker0600=nil
  assert(not pcall(JuniorTick0921.install_broker_0922),
    "missing canonical broker must fail closed, not silently drop follow-up")
  assert(not pcall(JuniorTick0921.install_intermediate_broker_0924),
    "missing canonical broker must also reject Intermediate registration")
  _G.TechPriestsRuntimeTickBroker0600=prior_broker
  local src=assert(io.open("tech-priests_src/control.lua","r"))
  local control=src:read("*a");src:close()
  local executor=assert(io.open("tech-priests_src/scripts/magos_station_expansion.lua","r"))
  local source=executor:read("*a");executor:close()
  assert(control:find("JuniorTick0921.install()",1,true)
    and control:find("efficiency_economy_0599",1,true)
    and control:find("JuniorTick0921.install_broker_0922()",1,true)
    and control:find("JuniorTick0921.install_intermediate_broker_0924()",1,true)
    and source:find("function M.service_reversal_junior_followup_0921",1,true)
    and source:find("StarvationJunior0919.service_from_intermediate",1,true),
    "late hook must route to original strict physical ghost authority")
  _G.game=saved.game;_G.storage=saved.storage;_G.script=saved.script
  _G.commands=saved.commands;_G.defines=saved.defines
  _G.tick_pair=saved.tick_pair
  _G.TECH_PRIESTS_STATION_EXPANSION_0256=saved.expansion
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_0599=saved.prior_sleep
  _G.TECH_PRIESTS_TICK_PAIR_BEFORE_JUNIOR_0921=saved.prior_junior
  _G.TechPriestsEfficiencyEconomy0599=saved.sleep_api
  _G.tech_priests_efficiency_0599_wake_pair=saved.wake
end
-- 0942: exercise the exact harness depot-readback block rather than a
-- hand-written approximation. Lua's 'and' expression loses return value #2;
-- a real second-Junior depot with one item was falsely failed as reason=nil.
do
  local file=assert(io.open(
    "tests/scenarios/all-ground-ranks/ground_rank_harness.lua","r"))
  local harness=file:read("*a");file:close()
  assert(not harness:find("second,second_why=second_stage and",1,true),
    "no engine acceptance gate may discard the depot's second return value")
  local snippet=table.concat({
    "  local second,second_why",
    "  if second_stage then",
    "    second,second_why=REVERSAL_DEPOT_0852.get_staged(magos,second_stage)",
    "  end"
  },"\n")
  local count,at=0,1
  while true do
    local i=harness:find(snippet,at,true)
    if not i then break end
    count=count+1;at=i+#snippet
  end
  assert(count==3,
    "pickup, transit and build gates must each retain both depot returns")
  local factory=assert(load("return function(second_stage,magos,REVERSAL_DEPOT_0852)\n"
    ..snippet.."\nreturn second,second_why\nend"))()
  local stage,magos={},{}
  local depot_entry={inventory={valid=true}}
  local get_calls=0
  local depot={get_staged=function(m,s)
    assert(m==magos and s==stage)
    get_calls=get_calls+1
    return depot_entry,"depot-stored-physical-item-verified"
  end}
  local entry,reason=factory(stage,magos,depot)
  assert(entry==depot_entry
    and reason=="depot-stored-physical-item-verified"
    and get_calls==1,
    "real second-Junior inventory and custody reason must both survive")
  local absent,absent_reason=factory(nil,magos,depot)
  assert(absent==nil and absent_reason==nil and get_calls==1,
    "missing second-Junior stage must not be audited as present")
end
print("[station-starvation-second-junior-depot-return-0942] PASS all three live harness gates preserve both real depot custody return values")
print("[station-starvation-junior-tick-0921] PASS late priority-safe scheduler, 0599 wake, idempotent installation, malformed-pointer refusal and unchanged original task result")
print("[station-starvation-junior-broker-0922] PASS canonical broker original-root rotation, no per-pair dependency, invalid-pointer refusal and missing-broker fail-closed")
print("[station-starvation-intermediate-broker-0924] PASS canonical broker retry, original Magos/root identity, fair rotation, no duplicate ghost, missing authority fail-closed")
print("[station-starvation-junior-future-reservation-0938] PASS exact first-Junior child blocks future 0647 work; forged Magos and ghost rejected; owner-only planning handoff")
print("[station-starvation-junior-physical-broker-0937] PASS original active child reaches canonical 0256, combat deferral, forged custody refusal, missing-stage fail-closed, reload-safe retry and completed-child suppression")


-- 0943: the real second-Junior ghost authority must reject false first-
-- Junior completions and conserve both distinct physical depots. Exercise
-- the actual controller with original priest/registry/lease fixtures.
do
  local saved={game=game,storage=storage,
    hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")}
  local keys={"scripts.core.station_starvation_depot_0852",
    "scripts.core.station_cargo_0824",
    "scripts.core.station_starvation_junior_0919"}
  local old={}
  for _,key in ipairs(keys) do old[key]=package.loaded[key] end
  local force={index=1};local surface={index=1}
  local function entity(id,name,x)
    return {valid=true,unit_number=id,name=name,position={x=x,y=0},
      force=force,surface=surface}
  end
  local function inv(n)
    local bag={valid=true,amount=n}
    function bag.get_item_count(item)
      assert(item=="junior-cogitator-station");return bag.amount
    end
    function bag.remove(spec)
      assert(spec.name=="junior-cogitator-station")
      local taken=math.min(bag.amount,spec.count)
      bag.amount=bag.amount-taken;return taken
    end
    function bag.insert(spec)
      assert(spec.name=="junior-cogitator-station")
      bag.amount=bag.amount+spec.count;return spec.count
    end
    function bag.destroy()assert(bag.amount==0);bag.valid=false end
    return bag
  end
  local magos={station=entity(10,"planetary-magos-cogitator-station",0),
    priest=entity(11,"priest",0),
    resource_expansion_0259={chain_0820={target={x=200,y=0}}}}
  local intermediate={station=entity(30,"intermediate-cogitator-station",40),
    priest=entity(31,"priest",40)}
  local first={station=entity(60,"junior-cogitator-station",60),
    priest=entity(41,"priest",60)}
  local second={priest=entity(51,"priest",0)}
  local stage1={id="reversal-ancestor:1:2:40",reversal_stage_index=2,
    phase="in-magos-depot",station_item="junior-cogitator-station",
    leaf_station_unit=40,leaf_priest_unit=41,worker_priest_unit=31}
  local stage2={id="reversal-leaf:1:50",phase="in-magos-depot",
    station_item="junior-cogitator-station",worker_station_unit=40,
    worker_priest_unit=41,leaf_station_unit=50,leaf_priest_unit=51}
  local firstchild={id=17,status="complete",completed_tick=800,
    worker_station_unit=30,ghost_unit=700,ghost_position={x=60,y=0},
    relocation_old_station_unit_0823=40,
    reversal_junior_0919={root_writ_id=1,stage_id=stage1.id,
      original_priest=41}}
  local root={id=1,status="complete",worker_station_unit=10,
    blocked_item="resource:iron-ore",reversal_stage_0853=stage1,
    reversal_stage_0851=stage2,
    reversal_junior_0919={status="ghost-reserved",
      child_writ_id=17,ghost_unit=700}}
  local firstinv=inv(0);local secondinv=inv(1)
  local tp={pairs_by_station={[10]=magos,[30]=intermediate,[60]=first},
    pairs_by_priest={[11]=magos,[31]=intermediate,[41]=first,[51]=second},
    station_by_priest={[41]=60},
    station_relocation_0823={[50]={status="staged",old_unit=50,
      priest_unit=51,priest=second.priest}},
    station_reversal_depot_0852={[stage1.id]={status="outbound",
      inventory=firstinv},[stage2.id]={status="stored",inventory=secondinv,
      record_id=stage2.id,item="junior-cogitator-station",
      magos_station_unit=10,magos_priest_unit=11}},
    station_expansion_0256={[1]=root,[17]=firstchild},
    station_expansion_by_worker_0256={},
    station_expansion_next_id_0256=18}
  storage={tech_priests=tp};game={tick=1000}
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
    is_direct_subordinate=function(a,b)
      return a==intermediate and b==first
    end}
  package.loaded[keys[1]]={get_staged=function(m,stage)
    if m==magos and stage==stage2 then
      return tp.station_reversal_depot_0852[stage2.id],
        "depot-stored-physical-item-verified"
    end
  end}
  package.loaded[keys[2]]={has_record=function()return false end}
  package.loaded[keys[3]]={reobserve_created_ghost_0927=function(_,g)
    return g,"exact-engine-unit"
  end}
  local controller=dofile(
    "tech-priests_src/scripts/core/station_starvation_second_junior_0943.lua")
  local ghosts=0;local ghost
  local api={rank=function()return 1 end,radius=function()return 25 end,
    find_site=function()return {x=80,y=0} end,
    create_ghost=function(_,item,site)
      assert(item=="junior-cogitator-station")
      ghosts=ghosts+1
      ghost=entity(900,"entity-ghost",site.x)
      ghost.ghost_name=item
      return ghost
    end,
    find_ghost=function(_,rec)
      return rec.ghost_unit==900 and ghost or nil
    end}
  local function service()return controller.service(magos,root,first,api) end
  local handled,why=service()
  assert(handled and why=="reversal-second-junior-real-ghost-reserved"
    and ghosts==1 and tp.station_expansion_next_id_0256==19
    and root.reversal_second_junior_0943.child_writ_id==18
    and tp.station_expansion_0256[18].worker_station_unit==60
    and tp.station_expansion_0256[18].requester_rank==1
    and firstinv.get_item_count("junior-cogitator-station")==0
    and secondinv.get_item_count("junior-cogitator-station")==1
    and tp.station_relocation_0823[50].status=="staged")
  assert(select(2,service())=="second-junior-original-real-ghost-still-reserved"
    and ghosts==1 and tp.station_expansion_next_id_0256==19)
  local secondchild=tp.station_expansion_0256[18]
  local secondstep=root.reversal_second_junior_0943
  tp.station_expansion_by_worker_0256[60]=nil
  root.reversal_second_junior_0943=nil
  tp.station_expansion_0256[18]=nil
  first.priest.unit_number=999
  assert(select(2,service())=="second-junior-original-physical-chain-not-certified"
    and ghosts==1)
  first.priest.unit_number=41
  api.rank=function()return 2 end
  assert(select(2,service())=="second-junior-original-physical-chain-not-certified"
    and ghosts==1)
  api.rank=function()return 1 end
  tp.station_reversal_depot_0852[stage2.id]={status="stored",inventory=inv(0)}
  assert(select(2,service()):find("second-junior-independent-physical-depot-invalid",1,true)
    and ghosts==1)
  tp.station_reversal_depot_0852[stage2.id]={status="stored",inventory=secondinv,
    record_id=stage2.id,item="junior-cogitator-station",
    magos_station_unit=10,magos_priest_unit=11}
  firstchild.status="active"
  assert(select(2,service())=="second-junior-original-physical-chain-not-certified"
    and ghosts==1)
  firstchild.status="complete"
  -- 0944: a separate function scope preserves Lua 5.2's strict 200
  -- locals per chunk without removing any physical-custody regression.
  local function verify_second_pickup_0944()
  local oldDefines=defines
  local oldProbe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  root.reversal_second_junior_0943=secondstep
  tp.station_expansion_0256[18]=secondchild
  tp.station_expansion_by_worker_0256[60]=18
  first.mode="idle"
  defines={distraction={none=0}}
  game.create_inventory=function()return inv(0) end
  local realCargo=dofile("tech-priests_src/scripts/core/station_cargo_0824.lua")
  package.loaded[keys[2]]=realCargo
  local pickupController=dofile(
    "tech-priests_src/scripts/core/station_starvation_second_junior_0943.lua")
  local requests,accept=0,true
  local pickup_api={rank=api.rank,radius=api.radius,
    find_ghost=api.find_ghost,
    request=function(pair,pos,why,opts)
      requests=requests+1
      assert(pair==first and pos==magos.station.position
        and why=="station-recovery-second-junior-depot-0944"
        and opts.owner=="station-recovery-second-junior-0944"
        and opts.priority==70 and opts.ttl==600 and opts.long_action)
      return accept,"fixture-rejected"
    end}
  local function pickup()
    return pickupController.service_pickup_0944(first,secondchild,pickup_api)
  end
  game.tick=1050
  assert(select(2,pickup())=="second-junior-pickup-ghost-escrow-pending"
    and requests==0 and secondinv.amount==1)
  game.tick=1200
  first.mode="combat"
  assert(select(2,pickup())=="second-junior-pickup-awaiting-existing-duty"
    and requests==0 and secondinv.amount==1)
  first.mode="idle"
  first.priest.unit_number=999
  assert(select(2,pickup())=="second-junior-pickup-original-writ-or-priest-invalid"
    and secondinv.amount==1)
  first.priest.unit_number=41
  accept=false
  assert(select(2,pickup())=="second-junior-pickup-physical-command-refused"
    and requests==1 and secondinv.amount==1)
  accept=true
  game.tick=1230
  assert(select(2,pickup())=="reversal-second-junior-first-priest-walking-to-magos"
    and requests==2 and secondinv.amount==1)
  first.priest.position={x=0,y=0}
  game.tick=1260
  assert(select(2,pickup())=="reversal-second-junior-real-item-carried-from-magos"
    and firstinv.amount==0 and secondinv.amount==0
    and tp.station_reversal_depot_0852[stage2.id].status=="outbound")
  local pickup_proof=secondchild.reversal_second_junior_0943
  assert(pickup_proof.picked_tick==1260
    and pickup_proof.picked_distance_sq_0944==0
    and pickup_proof.picked_station_unit_0944==magos.station.unit_number
    and pickup_proof.picked_priest_unit_0944==first.priest.unit_number,
    "real debit must persist the exact in-range pickup proof")
  local hold=assert(realCargo.get(first,secondchild))
  assert(hold.status=="carrying" and hold.inventory.amount==1
    and hold.inventory~=firstinv and hold.inventory~=secondinv
    and tp.station_relocation_0823[50].status=="staged")
  -- The carrier can be outside five tiles by the next harness observation.
  -- That must not retroactively falsify a physically local depot pickup.
  first.priest.position={x=20,y=0}
  game.tick=1290
  assert(select(2,pickup())=="reversal-second-junior-real-item-carried-from-magos"
    and secondinv.amount==0 and hold.inventory.amount==1
    and pickup_proof.picked_distance_sq_0944==0
    and pickup_proof.picked_station_unit_0944==10
    and requests==2,"retry must retain original physical pickup proof")
  -- 0978: the engine acceptance gate must verify the recorded actual
  -- pickup coordinates and identities, not the later moving priest.
  local hf=assert(io.open(
    "tests/scenarios/all-ground-ranks/ground_rank_harness.lua","r"))
  local hs=hf:read("*a");hf:close()
  local begin=assert(hs:find(
    "local function reversal_engine_second_junior_pickup(state)",1,true))
  local finish=assert(hs:find(
    "local function reversal_engine_second_junior_transit(state)",begin,true))
  local gate=hs:sub(begin,finish)
  assert(gate:find("and pickup_d2<=25",1,true)
    and gate:find("and pickup.picked_station_unit_0944==magos.station.unit_number",1,true)
    and gate:find("and pickup.picked_priest_unit_0944==first.priest.unit_number",1,true)
    and not gate:find("and d2<=25",1,true),
    "acceptance must reject forged remote pickup, not post-pickup travel")
  -- 0979: a periodic observer can discover a real ghost AFTER its actual
  -- creation. Its observation tick cannot extend the production escrow.
  -- The engine must require the original ghost creation time and a
  -- synchronous, physically accounted pickup timestamp instead.
  assert(gate:find("pickup.picked_tick>=step.created_tick+120",1,true)
    and gate:find("pickup.picked_tick<=game.tick",1,true)
    and gate:find("step.created_tick<=test.second_junior_ghost_tick",1,true)
    and not gate:find(">=test.second_junior_ghost_tick+120",1,true)
    and gate:find("created_tick=",1,true)
    and gate:find("observed_ghost_tick=",1,true),
    "engine gate must use real ghost creation, not delayed observation")
  local real_created,observed_late,physically_picked=1000,1150,1260
  assert(physically_picked>=real_created+120
    and physically_picked<observed_late+120,
    "delayed observer fixture must expose the old false rejection")
  assert(not (real_created+119>=real_created+120),
    "escrow must still reject pickup before 120 real ticks")
  -- A forged original priest cannot authorize a fresh physical debit.
  tp.station_cargo_0824[18]=nil
  secondinv.amount=1
  tp.station_reversal_depot_0852[stage2.id].status="stored"
  stage2.worker_priest_unit=999
  assert(select(2,pickup())=="second-junior-pickup-original-writ-or-priest-invalid"
    and secondinv.amount==1)
  stage2.worker_priest_unit=41
  for _,key in ipairs(keys) do package.loaded[key]=old[key] end
  _G.TECH_PRIESTS_COMMAND_HIERARCHY_0480=saved.hierarchy
  _G.tech_priests_0248_higher_priority_probe=oldProbe
  game=saved.game;storage=saved.storage;defines=oldDefines
  end
  -- 0945: the real engine timed out after the peer ghost because 0647
  -- kept the ORIGINAL first Junior in recipe-only planning. Exercise the
  -- actual 0850 reservation, 0640 owner handoff and live 0922 broker.
  local function verify_second_planning_handoff_0945()
    local old_future=rawget(_G,"TechPriestsStationStarvationReversal0850")
    local old_governor=rawget(_G,"TechPriestsInfrastructureFirstGovernor0640")
    local old_expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
    local old_probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
    local future=dofile(
      "tech-priests_src/scripts/core/station_starvation_reversal_0850.lua")
    local governor=dofile(
      "tech-priests_src/scripts/core/infrastructure_first_governor_0640.lua")
    local broker=dofile(
      "tech-priests_src/scripts/core/station_starvation_junior_dispatch_0921.lua")
    _G.TechPriestsStationStarvationReversal0850=future
    _G.TechPriestsInfrastructureFirstGovernor0640=governor
    _G.tech_priests_0248_higher_priority_probe=function()
      return {priority="idle"} end
    tp.station_reversal_followup_0911={[10]=1}
    root.reversal_second_junior_0943=secondstep
    tp.station_expansion_0256[18]=secondchild
    tp.station_expansion_by_worker_0256[60]=18
    game.tick=1200
    local function plan()
      first.mode="infrastructure-material-acquisition-0647"
      first.infrastructure_recipe_request_0647={
        item="iron-gear-wheel",missing="iron-plate"}
      first.requested_item="iron-plate"
    end
    local reserved,writ=future.future_worker_reserved(first)
    assert(reserved and writ==secondchild,
      "exact original peer ghost must reserve future 0647 planning")
    secondchild.ghost_unit=999
    assert(not future.future_worker_reserved(first),
      "foreign peer ghost must never reserve the original carrier")
    secondchild.ghost_unit=secondstep.ghost_unit
    tp.station_reversal_followup_0911[10]=999
    assert(not future.future_worker_reserved(first),
      "foreign Magos index must not reserve the peer carrier")
    tp.station_reversal_followup_0911[10]=1
    tp.station_relocation_0823[50].status="forged"
    assert(not future.future_worker_reserved(first),
      "missing original second-priest lease must refuse scheduling")
    tp.station_relocation_0823[50].status="staged"
    second.priest.unit_number=999
    assert(not future.future_worker_reserved(first),
      "replaced second priest must never grant peer authority")
    second.priest.unit_number=51
    assert(future.future_worker_reserved(first),
      "valid original identity must restore future reservation")
    plan()
    first.active_task={kind="combat"}
    local allowed,reason=governor.yield_uncommitted_recipe_to_reversal_0938(
      first,secondchild)
    assert(not allowed and reason=="junior-recipe-handoff-active-duty:active_task"
      and first.mode=="infrastructure-material-acquisition-0647"
      and first.infrastructure_recipe_request_0647
      and first.requested_item=="iron-plate"
      and secondinv.amount==1,
      "0640 must not cancel physical combat or pending recipe on refusal")
    first.active_task=nil
    allowed,reason=governor.yield_uncommitted_recipe_to_reversal_0938(
      first,secondchild)
    assert(allowed and reason=="junior-recipe-handoff-uncommitted-plan-retired"
      and first.mode=="idle" and first.infrastructure_recipe_request_0647==nil
      and first.requested_item==nil
      and firstinv.amount==0 and secondinv.amount==1,
      "0640 owner may retire ONLY uncommitted plan, never physical inventory")
    local dispatches=0
    _G.TECH_PRIESTS_STATION_EXPANSION_0256={
      service_reversal_junior_followup_0921=function()
        error("peer continuation must not create first-Junior ghost") end,
      service_reversal_second_junior_0943=function(m,r,p)
        assert(m==magos and r==root and p==first)
        return true,"second-junior-original-real-ghost-still-reserved"
      end,
      service_station_expansion_assignment=function(p)
        assert(p==first and p.mode=="idle")
        dispatches=dispatches+1
        return true,"second-junior-pickup-ghost-escrow-pending"
      end}
    plan()
    local outcome=broker.service_broker_0922(nil,1)
    assert(outcome.processed==1 and dispatches==1
      and first.mode=="idle" and first.requested_item==nil
      and root.reversal_second_junior_0945_handoff_reason
        =="junior-recipe-handoff-uncommitted-plan-retired"
      and root.reversal_second_junior_0944_last_reason
        =="second-junior-pickup-ghost-escrow-pending"
      and secondinv.amount==1,
      "live 0922 broker must hand off 0647 plan before canonical pickup")
    plan()
    first.active_task={kind="combat"}
    broker.service_broker_0922(nil,1)
    assert(dispatches==1 and first.mode=="infrastructure-material-acquisition-0647"
      and root.reversal_second_junior_0945_handoff_reason
        =="junior-recipe-handoff-active-duty:active_task"
      and secondinv.amount==1,
      "broker must not dispatch peer pickup through active combat")
    first.active_task=nil
    secondchild.ghost_unit=999
    broker.service_broker_0922(nil,1)
    assert(dispatches==1 and first.mode=="infrastructure-material-acquisition-0647"
      and secondinv.amount==1,
      "forged peer ghost must not trigger a planning handoff or debit")
    secondchild.ghost_unit=secondstep.ghost_unit
    tp.station_expansion_by_worker_0256[60]=999
    broker.service_broker_0922(nil,1)
    assert(dispatches==1 and secondinv.amount==1,
      "foreign worker writ must not dispatch physical second-Junior pickup")
    tp.station_expansion_by_worker_0256[60]=18
    first.infrastructure_recipe_request_0647=nil
    first.requested_item=nil
    first.mode="idle"
    _G.TechPriestsStationStarvationReversal0850=old_future
    _G.TechPriestsInfrastructureFirstGovernor0640=old_governor
    _G.TECH_PRIESTS_STATION_EXPANSION_0256=old_expansion
    _G.tech_priests_0248_higher_priority_probe=old_probe
  end
  verify_second_planning_handoff_0945()
  verify_second_pickup_0944()
end
print("[station-starvation-second-junior-pickup-0944] PASS real 0824 Magos depot debit, original first Junior priest, movement refusal, escrow, independent inventory, original second lease and no duplicate pickup")
print("[station-starvation-second-junior-ghost-0943] PASS real ghost reservation, exact original priest, peer rank, distinct counted depot, no duplicate and no premature child")

print("[station-starvation-second-junior-planning-handoff-0945] PASS real 0850 peer reservation, 0640 uncommitted-only yield, 0922 dispatch, combat and forged identity refusal, unchanged depots")

-- 0947 regression is kept in its own Lua chunk to avoid Lua 5.2's 200-local limit.
dofile("tests/unit/station_starvation_second_junior_transit_0947.lua")
