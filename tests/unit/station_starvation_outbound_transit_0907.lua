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
local handled,why=reserve()
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
assert(executor_source:find("StarvationIntermediate0911.service",1,true)
  and executor_source:find("rec.reversal_followup_0911 then",1,true)
  and executor_source:find("station_reversal_followup_0911[rec.worker_station_unit]=rec.id",1,true),
  "the actual 0256 scheduler must reserve the next ghost without ordinary stock acquisition")
print("[station-starvation-intermediate-0912] PASS grid-snapped real ghost position, exact re-observed unit, inward command radius, forward progress, protected Intermediate depot and negative ownership; no station-item debit")
