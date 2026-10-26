-- 0855: fourth leaf-first recovery stage. The original Planetary Magos
-- physically mines its now-childless Senior into a fourth independent engine
-- inventory and returns home. No replacement station is built here.
local Recovery=require("scripts.core.station_recycling_0822")
local Relocation=require("scripts.core.station_relocation_0823")
local Cargo=require("scripts.core.station_cargo_0824")
local Depot=require("scripts.core.station_starvation_depot_0852")
local RebuildAudit=require("scripts.core.station_starvation_rebuild_0867")
local M={version="0.1.674-dev.0855"}
local ITEM="senior-cogitator-station"
local function valid(p)
  return p and p.station and p.station.valid and p.priest and p.priest.valid
    and p.station.unit_number~=nil
end
-- 0875: canonical recoverable-station movement, also used by 0854.
function M.request_recovery_walk(worker,destination,leg,command,suffix)
  suffix=suffix or "0855"
  if suffix~="0854" and suffix~="0855" then return false,"invalid-stage" end
  if leg~="leaf" and leg~="return" then return false,"invalid-recovery-leg" end
  if not (valid(worker) and type(destination)=="table"
      and type(destination.x)=="number" and type(destination.y)=="number"
      and destination.x==destination.x and destination.y==destination.y
      and math.abs(destination.x)<math.huge
      and math.abs(destination.y)<math.huge) then
    return false,"invalid-recovery-worker-or-goal"
  end
  -- A damaged command API must never turn a physical recovery mission
  -- into an unhandled tick exception after inventory/priest custody exists.
  if not (defines and defines.command and defines.command.go_to_location
      and defines.distraction and defines.distraction.none) then
    return false,"recovery-command-api-unavailable"
  end
  local owner="station-recovery-"..suffix
  local reason="station-recovery-"..leg.."-"..suffix
  local priority=leg=="return" and 56 or 45
  local route=rawget(_G,"tech_priests_request_movement_0418")
  if type(route)=="function" then
    local status_fn=rawget(_G,"tech_priests_movement_status_0418")
    local req=worker.movement_request_0418
    if type(status_fn)=="function" and type(req)=="table"
        and req.owner==owner and req.reason==reason
        and req.priority==priority then
      local ok_status,status=pcall(status_fn,worker,owner)
      local goal=req.ground_route_final_destination or req
      if ok_status and type(status)=="table"
          and status.active==true and status.owner_match==true
          and status.reason==reason and status.expires_tick==req.expires_tick
          and (status.status=="active" or status.status=="arrived")
          and type(goal)=="table" and type(goal.x)=="number"
          and type(goal.y)=="number"
          and (goal.x-destination.x)^2+(goal.y-destination.y)^2<=0.04 then
        return true,"canonical-recovery-route-in-progress"
      end
    end
    local ok,accepted,why=pcall(route,worker,destination,reason,{
      owner=owner,priority=priority,ttl=600,radius=2,
      distraction=defines.distraction.none
    })
    if not ok then return false,"route-exception:"..tostring(accepted) end
    if accepted==true then return true,"canonical-ancestor-route-accepted" end
    return false,tostring(why or "route-refused")
  end
  if type(command)~="function" then return false,"movement-controller-unavailable" end
  local ok,accepted=pcall(command,worker.priest,{
    type=defines.command.go_to_location,destination=destination,
    radius=2,distraction=defines.distraction.none
  })
  return ok and accepted~=false,ok and accepted~=false
    and "legacy-harness-walk-accepted" or "legacy-harness-walk-refused"
end

local function near(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
-- The Magos owns the 0256 writ invoking this stage. Only that exact writ
-- is exempt from ordinary duty exclusion; competing work is not preempted.
local function available(magos,rec)
  if not (valid(magos) and magos.mode=="idle" and not magos.dead
      and not magos.recalling and not magos.deploying
      and (magos.station_expansion_0256==nil
        or magos.station_expansion_0256==rec)
      and not magos.station_expansion_op_0256) then return false end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if magos[key]~=nil and magos[key]~=false then return false end
  end
  local tp=storage and storage.tech_priests
  if not tp then return false end
  local assigned=tp.station_expansion_by_worker_0256
    and tp.station_expansion_by_worker_0256[magos.station.unit_number]
  if assigned~=nil and assigned~=rec.id then return false end
  for _,other in pairs(tp.station_expansion_0256 or {}) do
    if other~=rec and other.status=="active"
        and other.worker_station_unit==magos.station.unit_number then
      return false
    end
  end
  return true
end
local function prior_depots(magos,rec,plan)
  -- A saved writ may be damaged or superseded. Never dereference its
  -- predecessors before validating each descriptor and physical custody.
  if not(type(plan)=="table" and type(plan.stages)=="table") then
    return false,"reversal-senior-prior-stage-plan-invalid"
  end
  local expected={
    "junior-cogitator-station","junior-cogitator-station",
    "intermediate-cogitator-station"
  }
  for i=1,3 do
    local step=plan.stages[i]
    if not(type(step)=="table" and step.item==expected[i]
        and type(step.station_unit)=="number"
        and type(step.parent_station_unit)=="number"
        and step.station_unit~=step.parent_station_unit) then
      return false,"reversal-senior-prior-stage-plan-invalid:"..i
    end
  end
  if #plan.stages~=4 then
    return false,"reversal-senior-prior-stage-count-invalid"
  end
  local prior={
    {rec.reversal_stage_0851,plan.stages[1],1},
    {rec.reversal_stage_0853,plan.stages[2],2},
    {rec.reversal_stage_0854,plan.stages[3],3}
  }
  local seen={}
  for i,spec in ipairs(prior) do
    local stage,step,index=spec[1],spec[2],spec[3]
    local id=index==1
      and ("reversal-leaf:"..tostring(rec.id)..":"..tostring(step.station_unit))
      or ("reversal-ancestor:"..tostring(rec.id)..":"..index..":"
        ..tostring(step.station_unit))
    if not(stage and stage.id==id and stage.phase=="in-magos-depot"
        and stage.station_item==step.item
        and stage.leaf_station_unit==step.station_unit
        and stage.worker_station_unit==step.parent_station_unit) then
      return false,"reversal-senior-prior-stage-identity:"..i
    end
    local depot,why=Depot.get_staged(magos,stage)
    if not depot then
      return false,"reversal-senior-prior-depot:"..i..":"..tostring(why)
    end
    if seen[depot.inventory] then
      return false,"reversal-senior-depot-inventory-aliased"
    end
    seen[depot.inventory]=true
  end
  return true
end
local function preflight(magos,rec,plan)
  local tp=storage and storage.tech_priests
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(tp and tp.pairs_by_station and h
      and type(h.rank)=="function"
      and type(h.is_direct_subordinate)=="function"
      and type(plan)=="table" and plan.status=="leaf-first-preflight-only"
      and type(plan.stages)=="table" and #plan.stages==4
      and plan.root_station_unit==magos.station.unit_number
      and plan.required_item==ITEM and rec.station_item==ITEM
      and rec.worker_station_unit==magos.station.unit_number
      and rec.status=="active"
      and mission and mission.target and plan.target
      and mission.target.x==plan.target.x
      and mission.target.y==plan.target.y) then
    return nil,"reversal-senior-plan-or-target-changed"
  end
  local a,b,c,d=plan.stages[1],plan.stages[2],
    plan.stages[3],plan.stages[4]
  if not(a and b and c and d
      and a.item=="junior-cogitator-station"
      and b.item=="junior-cogitator-station"
      and c.item=="intermediate-cogitator-station"
      and d.item==ITEM
      and d.parent_station_unit==magos.station.unit_number
      and c.parent_station_unit==d.station_unit
      and b.parent_station_unit==c.station_unit
      and a.parent_station_unit==b.station_unit
      and tp.pairs_by_station[a.station_unit]==nil
      and tp.pairs_by_station[b.station_unit]==nil
      and tp.pairs_by_station[c.station_unit]==nil) then
    return nil,"reversal-senior-dependency-not-cleared"
  end
  local senior=tp.pairs_by_station[d.station_unit]
  if not(valid(magos) and valid(senior)
      and magos.station.name=="planetary-magos-cogitator-station"
      and senior.station.name==ITEM
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and senior.station.force==magos.station.force
      and senior.station.surface==magos.station.surface) then
    return nil,"reversal-senior-live-pair-invalid"
  end
  local ok_root,root_rank=pcall(h.rank,magos)
  local ok_child,child_rank=pcall(h.rank,senior)
  if not(ok_root and tonumber(root_rank)==4
      and ok_child and tonumber(child_rank)==3) then
    return nil,"reversal-senior-live-rank-invalid"
  end
  local slate,child_slate=magos.command_hierarchy_0480,
    senior.command_hierarchy_0480
  local observed,linked=pcall(h.is_direct_subordinate,magos,senior)
  if not(slate and type(slate.direct_subordinate_units)=="table"
      and #slate.direct_subordinate_units==1
      and slate.direct_subordinate_units[1]==senior.station.unit_number
      and child_slate and child_slate.superior_unit==magos.station.unit_number
      and type(child_slate.direct_subordinate_units)=="table"
      and #child_slate.direct_subordinate_units==0
      and type(child_slate.peer_units)=="table"
      and #child_slate.peer_units==0
      and observed and linked==true) then
    return nil,"reversal-senior-hierarchy-or-dependents-changed"
  end
  local ready,why=prior_depots(magos,rec,plan)
  if not ready then return nil,why end
  local safe,reason=Recovery.check_candidate(magos,senior,ITEM)
  if not safe then
    return nil,"reversal-senior-live-preflight:"..tostring(reason)
  end
  return senior
end
function M.service(magos,rec,plan,command)
  local tp=storage and storage.tech_priests
  if not(valid(magos) and tp and tp.pairs_by_station
      and type(command)=="function"
      and defines and defines.command and defines.distraction) then
    return true,"reversal-senior-command-or-root-unavailable"
  end
  local step=type(plan)=="table" and type(plan.stages)=="table"
    and plan.stages[4]
  if not(type(step)=="table" and step.item==ITEM
      and step.parent_station_unit==magos.station.unit_number) then
    return true,"reversal-senior-stage-order-unavailable"
  end
  local stage=rec.reversal_stage_0855
  if stage~=nil and type(stage)~="table" then
    return true,"reversal-senior-stage-identity-changed"
  end
  if stage then
    if not(stage.id==("reversal-ancestor:"..tostring(rec.id)..":4:"
          ..tostring(step.station_unit))
        and stage.reversal_stage_index==4 and stage.station_item==ITEM
        and stage.leaf_station_unit==step.station_unit
        and stage.worker_station_unit==magos.station.unit_number
        and stage.worker_priest_unit==magos.priest.unit_number) then
      return true,"reversal-senior-stage-identity-changed"
    end
  end
  local ready,why=prior_depots(magos,rec,plan)
  if not ready then return true,why end
  if stage and stage.phase=="in-magos-depot" then
    local entry,reason=Depot.get_staged(magos,stage)
    if not entry then
      return true,"reversal-senior-depot-unverified:"..tostring(reason)
    end
    local proof,audit_reason=RebuildAudit.audit(magos,rec)
    if not(proof and proof.stage_count==4) then
      return true,"reversal-four-depot-custody-audit-blocked:"..
        tostring(audit_reason)
    end
    -- This observation is not a build order or a debit. A later outward
    -- construction owner must check all four receipts again at spend time.
    return true,"reversal-senior-item-stored-in-magos-depot"
  end
  if not stage then
    local candidate,reason=preflight(magos,rec,plan)
    if not candidate then return true,reason end
    if not available(magos,rec) then
      return true,"reversal-senior-magos-busy"
    end
    stage={
      id="reversal-ancestor:"..tostring(rec.id)..":4:"
        ..tostring(candidate.station.unit_number),
      reversal_stage_index=4,station_item=ITEM,
      leaf_station_unit=candidate.station.unit_number,
      leaf_priest_unit=candidate.priest.unit_number,
      worker_station_unit=magos.station.unit_number,
      worker_priest_unit=magos.priest.unit_number,
      phase="to-leaf",started_tick=game and game.tick or 0
    }
    rec.reversal_stage_0855=stage
  end
  if stage.phase=="to-leaf" then
    local candidate,reason=preflight(magos,rec,plan)
    if not candidate then return true,reason end
    if stage.leaf_priest_unit~=candidate.priest.unit_number then
      return true,"reversal-senior-priest-identity-changed"
    end
    if not available(magos,rec) then
      return true,"reversal-senior-magos-busy"
    end
    if not near(magos.priest.position,candidate.station.position) then
      local accepted,why=M.request_recovery_walk(magos,candidate.station.position,"leaf",command)
      rec.reversal_senior_route_denial_0875=not accepted and tostring(why):sub(1,160) or nil
      return true,accepted and "reversal-senior-magos-walking-to-station"
        or "reversal-senior-magos-movement-refused"
    end
    local mined,reason=Relocation.try_stage_leaf(magos,candidate,stage)
    if not mined then
      return true,"reversal-senior-mine-blocked:"..tostring(reason)
    end
    stage.phase="to-magos"
    stage.mined_tick=game and game.tick or 0
  end
  if stage.phase=="to-magos" or stage.phase=="at-magos-with-carried-item" then
    local lease=Relocation.pending_for_record(stage)
    local cargo=Cargo.get(magos,stage)
    if not(lease and lease.status=="staged"
        and lease.reversal_ancestor_0855
        and lease.old_unit==stage.leaf_station_unit
        and lease.priest_unit==stage.leaf_priest_unit
        and lease.priest and lease.priest.valid
        and not(lease.old_station and lease.old_station.valid)
        and cargo and cargo.status=="carrying"
        and cargo.inventory.get_item_count(ITEM)==1) then
      return true,"reversal-senior-physical-custody-unverified"
    end
    Cargo.observe_carrier(magos,stage)
    if not near(magos.priest.position,magos.station.position) then
      if not available(magos,rec) then
        return true,"reversal-senior-magos-busy"
      end
      local accepted,why=M.request_recovery_walk(magos,magos.station.position,"return",command)
      rec.reversal_senior_route_denial_0875=not accepted and tostring(why):sub(1,160) or nil
      return true,accepted and "reversal-senior-magos-carrying-item-home"
        or "reversal-senior-magos-return-refused"
    end
    stage.phase="at-magos-with-carried-item"
    local stored,reason=Depot.handoff(magos,magos,stage)
    if not stored then
      return true,"reversal-senior-depot-handoff-blocked:"..tostring(reason)
    end
    stage.phase="in-magos-depot"
    stage.deposited_tick=game and game.tick or 0
    return true,"reversal-senior-item-stored-in-magos-depot"
  end
  return true,"reversal-senior-unknown-phase"
end
return M
