-- 0853: recover the next Junior only after its terminal peer's real item
-- is safely stored at the Magos. This stage does NOT mine Intermediate/Senior.
local Recovery=require("scripts.core.station_recycling_0822")
local Relocation=require("scripts.core.station_relocation_0823")
local Cargo=require("scripts.core.station_cargo_0824")
local Depot=require("scripts.core.station_starvation_depot_0852")
local Intermediate=require("scripts.core.station_starvation_intermediate_0854")
local M={version="0.1.674-dev.0853"}
local ITEM="junior-cogitator-station"
local function valid(p)
  return p and p.station and p.station.valid and p.priest and p.priest.valid
    and p.station.unit_number~=nil
end
local function near(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
-- 0874: the Intermediate's second-Junior recovery is a physical journey,
-- not an ordinary short-range work order. Submit both legs to canonical 0418,
-- and preserve its active chunked final-goal route instead of re-targeting
-- a moving waypoint every service tick. A controller refusal is authoritative.
-- The existing command fallback is retained only when 0418 is not installed
-- (legacy unit harness); a present controller is never bypassed.
function M.request_recovery_walk(worker,destination,leg,command)
  if leg~="leaf" and leg~="return" then return false,"invalid-recovery-leg" end
  if not (valid(worker) and type(destination)=="table"
      and type(destination.x)=="number" and type(destination.y)=="number"
      and destination.x==destination.x and destination.y==destination.y
      and math.abs(destination.x)<math.huge
      and math.abs(destination.y)<math.huge) then
    return false,"invalid-recovery-worker-or-goal"
  end
  local owner="station-recovery-0853"
  local reason="station-recovery-"..leg.."-0853"
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
        return true,"canonical-ancestor-route-in-progress"
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
local function idle(p)
  if not (valid(p) and p.mode=="idle" and not p.dead and not p.recalling
      and not p.deploying) then return false end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_expansion_0256",
      "station_expansion_op_0256","station_crafting_task_0337"}) do
    if p[key]~=nil and p[key]~=false then return false end
  end
  return true
end
local function live(magos,rec,plan)
  local tp=storage and storage.tech_priests
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local mission=magos.resource_expansion_0259 and magos.resource_expansion_0259.chain_0820
  if not (tp and tp.pairs_by_station and h
      and type(h.rank)=="function" and type(h.is_direct_subordinate)=="function"
      and type(plan)=="table" and plan.status=="leaf-first-preflight-only"
      and plan.root_station_unit==magos.station.unit_number
      and plan.required_item==rec.station_item
      and type(plan.stages)=="table" and #plan.stages==4
      and type(plan.stages[1])=="table" and type(plan.stages[2])=="table"
      and type(plan.stages[3])=="table" and type(plan.stages[4])=="table"
      and mission and mission.target and plan.target
      and mission.target.x==plan.target.x and mission.target.y==plan.target.y) then
    return nil,nil,"reversal-ancestor-plan-or-target-changed"
  end
  local senior=tp.pairs_by_station[plan.stages[4].station_unit]
  local intermediate=tp.pairs_by_station[plan.stages[3].station_unit]
  local junior=tp.pairs_by_station[plan.stages[2].station_unit]
  local chain={magos,senior,intermediate,junior}
  local ranks={4,3,2,1}
  local names={false,"senior-cogitator-station",
    "intermediate-cogitator-station",ITEM}
  for i=1,4 do
    local pair=chain[i]
    if not valid(pair) or tp.pairs_by_station[pair.station.unit_number]~=pair
        or pair.station.force~=magos.station.force
        or pair.station.surface~=magos.station.surface
        or (names[i] and pair.station.name~=names[i]) then
      return nil,nil,"reversal-ancestor-live-pair-invalid:"..i
    end
    local ok,r=pcall(h.rank,pair)
    if not ok or tonumber(r)~=ranks[i] then
      return nil,nil,"reversal-ancestor-live-rank-invalid:"..i
    end
    if i>1 then
      local parent=chain[i-1]
      local slate=parent.command_hierarchy_0480
      local child_slate=pair.command_hierarchy_0480
      local observed,linked=pcall(h.is_direct_subordinate,parent,pair)
      if not (slate and type(slate.direct_subordinate_units)=="table"
          and #slate.direct_subordinate_units==1
          and slate.direct_subordinate_units[1]==pair.station.unit_number
          and child_slate and child_slate.superior_unit==parent.station.unit_number
          and observed and linked==true) then
        return nil,nil,"reversal-ancestor-hierarchy-invalid:"..i
      end
    end
  end
  local first=plan.stages[1]
  if not (first and first.item==ITEM
      and first.parent_station_unit==junior.station.unit_number
      and plan.stages[2].parent_station_unit==intermediate.station.unit_number
      and plan.stages[2].item==ITEM
      and plan.stages[3].parent_station_unit==senior.station.unit_number
      and plan.stages[3].item=="intermediate-cogitator-station"
      and plan.stages[4].parent_station_unit==magos.station.unit_number
      and plan.stages[4].item=="senior-cogitator-station"
      and tp.pairs_by_station[first.station_unit]==nil) then
    return nil,nil,"reversal-ancestor-dependency-not-cleared"
  end
  local slate=junior.command_hierarchy_0480
  if not (slate and type(slate.direct_subordinate_units)=="table"
      and #slate.direct_subordinate_units==0
      and type(slate.peer_units)=="table" and #slate.peer_units==0) then
    return nil,nil,"reversal-ancestor-junior-still-has-dependents"
  end
  local ok,why=Recovery.check_candidate(intermediate,junior,ITEM)
  if not ok then return nil,nil,"reversal-ancestor-live-preflight:"..tostring(why) end
  return intermediate,junior
end
function M.service(magos,rec,plan,command)
  local tp=storage and storage.tech_priests
  local stage=rec.reversal_stage_0853
  if stage~=nil and type(stage)~="table" then
    return true,"reversal-ancestor-stage-identity-changed"
  end
  if not (tp and tp.pairs_by_station and type(command)=="function"
      and defines and defines.command and defines.distraction) then
    return true,"reversal-ancestor-command-or-registry-unavailable"
  end
  local next_stage=type(plan)=="table" and type(plan.stages)=="table"
    and plan.stages[2]
  if not (type(next_stage)=="table" and next_stage.item==ITEM) then
    return true,"reversal-ancestor-stage-order-unavailable"
  end
  if stage then
    if not (stage.id==("reversal-ancestor:"..tostring(rec.id)..":2:"
          ..tostring(next_stage.station_unit))
        and stage.reversal_stage_index==2 and stage.station_item==ITEM
        and stage.leaf_station_unit==next_stage.station_unit
        and stage.worker_station_unit==next_stage.parent_station_unit) then
      return true,"reversal-ancestor-stage-identity-changed"
    end
    if stage.phase=="in-magos-depot" then
      local entry,why=Depot.get_staged(magos,stage)
      if not entry then return true,"reversal-ancestor-depot-unverified:"..tostring(why) end
      return Intermediate.service(magos,rec,plan,command)
    end
  end
  local worker=tp.pairs_by_station[next_stage.parent_station_unit]
  local candidate=tp.pairs_by_station[next_stage.station_unit]
  if not valid(worker) then return true,"reversal-ancestor-worker-unavailable" end
  if stage then
    if stage.worker_priest_unit~=worker.priest.unit_number then
      return true,"reversal-ancestor-worker-identity-changed"
    end
    if stage.phase=="to-leaf" and (not valid(candidate)
        or stage.leaf_priest_unit~=candidate.priest.unit_number) then
      return true,"reversal-ancestor-junior-identity-changed"
    end
  else
    local parent,child,why=live(magos,rec,plan)
    if not parent then return true,why end
    if not idle(worker) then return true,"reversal-ancestor-worker-busy" end
    stage={
      id="reversal-ancestor:"..tostring(rec.id)..":2:"
        ..tostring(candidate.station.unit_number),
      reversal_stage_index=2,station_item=ITEM,
      leaf_station_unit=candidate.station.unit_number,
      leaf_priest_unit=candidate.priest.unit_number,
      worker_station_unit=worker.station.unit_number,
      worker_priest_unit=worker.priest.unit_number,
      phase="to-leaf",started_tick=game and game.tick or 0
    }
    rec.reversal_stage_0853=stage
  end
  if stage.phase=="to-leaf" then
    local parent,child,why=live(magos,rec,plan)
    if not parent then return true,why end
    if not idle(worker) then return true,"reversal-ancestor-worker-busy" end
    if not near(worker.priest.position,child.station.position) then
      local accepted,why=M.request_recovery_walk(
        worker,child.station.position,"leaf",command)
      rec.reversal_ancestor_route_denial_0874=
        not accepted and tostring(why):sub(1,160) or nil
      return true,accepted and "reversal-ancestor-walking-to-junior"
        or "reversal-ancestor-junior-movement-refused"
    end
    local mined,why=Relocation.try_stage_leaf(worker,child,stage)
    if not mined then return true,"reversal-ancestor-junior-mine-blocked:"..tostring(why) end
    stage.phase="to-magos"
    stage.mined_tick=game and game.tick or 0
  end
  if stage.phase=="to-magos" or stage.phase=="at-magos-with-carried-item" then
    local lease=Relocation.pending_for_record(stage)
    local cargo=Cargo.get(worker,stage)
    if not (lease and lease.status=="staged" and lease.reversal_ancestor_0853
        and lease.old_unit==stage.leaf_station_unit
        and lease.priest_unit==stage.leaf_priest_unit
        and lease.priest and lease.priest.valid
        and not (lease.old_station and lease.old_station.valid)
        and cargo and cargo.status=="carrying"
        and cargo.inventory.get_item_count(ITEM)==1) then
      return true,"reversal-ancestor-physical-custody-unverified"
    end
    Cargo.observe_carrier(worker,stage)
    if not near(worker.priest.position,magos.station.position) then
      if not idle(worker) then return true,"reversal-ancestor-carrier-busy" end
      local accepted,why=M.request_recovery_walk(
        worker,magos.station.position,"return",command)
      rec.reversal_ancestor_route_denial_0874=
        not accepted and tostring(why):sub(1,160) or nil
      return true,accepted and "reversal-ancestor-carrying-junior-item-to-magos"
        or "reversal-ancestor-return-movement-refused"
    end
    stage.phase="at-magos-with-carried-item"
    local stored,why=Depot.handoff(magos,worker,stage)
    if not stored then
      return true,"reversal-ancestor-depot-handoff-blocked:"..tostring(why)
    end
    stage.phase="in-magos-depot"
    stage.deposited_tick=game and game.tick or 0
    return true,"reversal-ancestor-junior-item-stored-in-magos-depot"
  end
  return true,"reversal-ancestor-unknown-phase"
end
return M
