-- 0854: third leaf-first stage of no-spare-item reversal.
-- The Senior physically mines its now-childless Intermediate, carries the
-- actual station item to the original Magos and deposits it in a separate
-- engine-owned inventory. Never authorize Senior recovery or rebuilding here.
local Recovery=require("scripts.core.station_recycling_0822")
local Relocation=require("scripts.core.station_relocation_0823")
local Cargo=require("scripts.core.station_cargo_0824")
local Depot=require("scripts.core.station_starvation_depot_0852")
local M={version="0.1.674-dev.0854"}
local ITEM="intermediate-cogitator-station"
local function valid(p)
  return p and p.station and p.station.valid and p.priest and p.priest.valid
    and p.station.unit_number~=nil
end
local function near(a,b)
  return a and b and (a.x-b.x)^2+(a.y-b.y)^2<=25
end
local function idle(p)
  if not(valid(p) and p.mode=="idle" and not p.dead
      and not p.recalling and not p.deploying) then return false end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_expansion_0256",
      "station_expansion_op_0256","station_crafting_task_0337"}) do
    if p[key]~=nil and p[key]~=false then return false end
  end
  return true
end
local function preflight(magos,rec,plan)
  local tp=storage and storage.tech_priests
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local mission=magos.resource_expansion_0259 and magos.resource_expansion_0259.chain_0820
  if not(tp and tp.pairs_by_station and h and type(h.rank)=="function"
      and type(h.is_direct_subordinate)=="function"
      and type(plan)=="table" and plan.status=="leaf-first-preflight-only"
      and type(plan.stages)=="table" and #plan.stages==4
      and plan.root_station_unit==magos.station.unit_number
      and plan.required_item==rec.station_item
      and rec.station_item=="senior-cogitator-station"
      and mission and mission.target and plan.target
      and mission.target.x==plan.target.x and mission.target.y==plan.target.y) then
    return nil,nil,"reversal-intermediate-plan-or-target-changed"
  end
  local first,second,third,fourth=plan.stages[1],plan.stages[2],
    plan.stages[3],plan.stages[4]
  if not(first and second and third and fourth
      and first.item=="junior-cogitator-station"
      and second.item=="junior-cogitator-station"
      and third.item==ITEM and fourth.item=="senior-cogitator-station"
      and fourth.parent_station_unit==magos.station.unit_number
      and third.parent_station_unit==fourth.station_unit
      and second.parent_station_unit==third.station_unit
      and first.parent_station_unit==second.station_unit
      and tp.pairs_by_station[first.station_unit]==nil
      and tp.pairs_by_station[second.station_unit]==nil) then
    return nil,nil,"reversal-intermediate-dependency-not-cleared"
  end
  local senior=tp.pairs_by_station[third.parent_station_unit]
  local middle=tp.pairs_by_station[third.station_unit]
  for i,p in ipairs({magos,senior,middle}) do
    local names={"planetary-magos-cogitator-station",
      "senior-cogitator-station",ITEM}
    if not valid(p) or tp.pairs_by_station[p.station.unit_number]~=p
        or p.station.name~=names[i]
        or p.station.force~=magos.station.force
        or p.station.surface~=magos.station.surface then
      return nil,nil,"reversal-intermediate-live-pair-invalid:"..i
    end
    local ok,r=pcall(h.rank,p)
    if not ok or tonumber(r)~=(5-i) then
      return nil,nil,"reversal-intermediate-live-rank-invalid:"..i
    end
  end
  for _,link in ipairs({{magos,senior},{senior,middle}}) do
    local parent,child=link[1],link[2]
    local slate,child_slate=parent.command_hierarchy_0480,
      child.command_hierarchy_0480
    local ok,owned=pcall(h.is_direct_subordinate,parent,child)
    if not(slate and type(slate.direct_subordinate_units)=="table"
        and #slate.direct_subordinate_units==1
        and slate.direct_subordinate_units[1]==child.station.unit_number
        and child_slate and child_slate.superior_unit==parent.station.unit_number
        and ok and owned==true) then
      return nil,nil,"reversal-intermediate-hierarchy-changed"
    end
  end
  local slate=middle.command_hierarchy_0480
  if not(slate and type(slate.direct_subordinate_units)=="table"
      and #slate.direct_subordinate_units==0
      and type(slate.peer_units)=="table" and #slate.peer_units==0) then
    return nil,nil,"reversal-intermediate-still-has-dependents"
  end
  local safe,why=Recovery.check_candidate(senior,middle,ITEM)
  if not safe then return nil,nil,"reversal-intermediate-live-preflight:"..tostring(why) end
  return senior,middle
end
function M.service(magos,rec,plan,command)
  local stage=rec.reversal_stage_0854
  local tp=storage and storage.tech_priests
  if not(tp and tp.pairs_by_station and type(command)=="function"
      and defines and defines.command and defines.distraction) then
    return true,"reversal-intermediate-command-or-registry-unavailable"
  end
  local step=type(plan)=="table" and type(plan.stages)=="table" and plan.stages[3]
  if not(step and step.item==ITEM) then
    return true,"reversal-intermediate-stage-order-unavailable"
  end
  if stage then
    if not(stage.id==("reversal-ancestor:"..tostring(rec.id)..":3:"
          ..tostring(step.station_unit))
        and stage.reversal_stage_index==3
        and stage.station_item==ITEM
        and stage.leaf_station_unit==step.station_unit
        and stage.worker_station_unit==step.parent_station_unit) then
      return true,"reversal-intermediate-stage-identity-changed"
    end
    if stage.phase=="in-magos-depot" then
      local entry,why=Depot.get_staged(magos,stage)
      if not entry then
        return true,"reversal-intermediate-depot-unverified:"..tostring(why)
      end
      return true,"reversal-intermediate-item-stored-in-magos-depot"
    end
  end
  local worker=tp.pairs_by_station[step.parent_station_unit]
  local candidate=tp.pairs_by_station[step.station_unit]
  if not valid(worker) then return true,"reversal-intermediate-worker-unavailable" end
  if stage then
    if stage.worker_priest_unit~=worker.priest.unit_number then
      return true,"reversal-intermediate-worker-identity-changed"
    end
    if stage.phase=="to-leaf" and (not valid(candidate)
        or stage.leaf_priest_unit~=candidate.priest.unit_number) then
      return true,"reversal-intermediate-priest-identity-changed"
    end
  else
    local parent,child,why=preflight(magos,rec,plan)
    if not parent then return true,why end
    if not idle(worker) then return true,"reversal-intermediate-worker-busy" end
    stage={
      id="reversal-ancestor:"..tostring(rec.id)..":3:"
        ..tostring(candidate.station.unit_number),
      reversal_stage_index=3,station_item=ITEM,
      leaf_station_unit=candidate.station.unit_number,
      leaf_priest_unit=candidate.priest.unit_number,
      worker_station_unit=worker.station.unit_number,
      worker_priest_unit=worker.priest.unit_number,
      phase="to-leaf",started_tick=game and game.tick or 0
    }
    rec.reversal_stage_0854=stage
  end
  if stage.phase=="to-leaf" then
    local parent,child,why=preflight(magos,rec,plan)
    if not parent then return true,why end
    if not idle(worker) then return true,"reversal-intermediate-worker-busy" end
    if not near(worker.priest.position,child.station.position) then
      local ok,accepted=pcall(command,worker.priest,{
        type=defines.command.go_to_location,destination=child.station.position,
        radius=2,distraction=defines.distraction.none})
      return true,(ok and accepted~=false)
        and "reversal-intermediate-walking-to-station"
        or "reversal-intermediate-movement-refused"
    end
    local mined,why=Relocation.try_stage_leaf(worker,child,stage)
    if not mined then
      return true,"reversal-intermediate-mine-blocked:"..tostring(why)
    end
    stage.phase="to-magos"
    stage.mined_tick=game and game.tick or 0
  end
  if stage.phase=="to-magos" or stage.phase=="at-magos-with-carried-item" then
    local lease=Relocation.pending_for_record(stage)
    local cargo=Cargo.get(worker,stage)
    if not(lease and lease.status=="staged" and lease.reversal_ancestor_0854
        and lease.old_unit==stage.leaf_station_unit
        and lease.priest_unit==stage.leaf_priest_unit
        and lease.priest and lease.priest.valid
        and not(lease.old_station and lease.old_station.valid)
        and cargo and cargo.status=="carrying"
        and cargo.inventory.get_item_count(ITEM)==1) then
      return true,"reversal-intermediate-physical-custody-unverified"
    end
    Cargo.observe_carrier(worker,stage)
    if not near(worker.priest.position,magos.station.position) then
      if not idle(worker) then return true,"reversal-intermediate-carrier-busy" end
      local ok,accepted=pcall(command,worker.priest,{
        type=defines.command.go_to_location,
        destination=magos.station.position,radius=2,
        distraction=defines.distraction.none})
      return true,(ok and accepted~=false)
        and "reversal-intermediate-carrying-item-to-magos"
        or "reversal-intermediate-return-movement-refused"
    end
    stage.phase="at-magos-with-carried-item"
    local stored,why=Depot.handoff(magos,worker,stage)
    if not stored then
      return true,"reversal-intermediate-depot-handoff-blocked:"..tostring(why)
    end
    stage.phase="in-magos-depot"
    stage.deposited_tick=game and game.tick or 0
    return true,"reversal-intermediate-item-stored-in-magos-depot"
  end
  return true,"reversal-intermediate-unknown-phase"
end
return M
