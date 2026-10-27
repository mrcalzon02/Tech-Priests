-- 0911: after the original Senior is physically rebuilt, reserve exactly one
-- Intermediate construction ghost under that SAME surviving Senior priest.
-- This step creates a real ghost and a persistent 0256 writ, NOT a station
-- item, cargo transfer, completed station, or new priest. The protected
-- Intermediate item remains in its original Magos-anchored 0852 inventory.
local Depot=require("scripts.core.station_starvation_depot_0852")
local Relocation=require("scripts.core.station_relocation_0823")
local Cargo=require("scripts.core.station_cargo_0824")
local M={version="0.1.674-dev.0913"}
local ITEM="intermediate-cogitator-station"
local function valid(x) return x and x.valid end
local function dist2(a,b)
  if not(a and b) then return math.huge end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
local function domain(a,b)
  return a and b and (a==b or (type(a.index)=="number"
    and type(b.index)=="number" and a.index==b.index))
end
-- 0912: the engine can align a construction ghost to its prototype grid.
-- Verify the observed, not requested, location. A bounded 1.5-tile snap is
-- permissible ONLY if the actual ghost remains forward, inside the real
-- command radius, and independently discoverable by the same unit number.
-- Never retry or remove an unverified physical ghost: it may still exist.
local function verify_created_ghost_0912(senior,ghost,site,radius,target,observed)
  local actual=valid(ghost) and ghost.position or nil
  local observed_position=valid(observed) and observed.position or nil
  local origin=valid(senior and senior.station) and senior.station.position or nil
  local shift_sq=dist2(actual,site)
  local range_sq=dist2(actual,origin)
  local forward_sq=dist2(actual,target)
  local previous_sq=dist2(origin,target)
  local ok=valid(ghost) and valid(observed)
    and ghost.name=="entity-ghost" and ghost.ghost_name==ITEM
    and type(ghost.unit_number)=="number"
    and observed.unit_number==ghost.unit_number
    and observed.name=="entity-ghost" and observed.ghost_name==ITEM
    and valid(senior and senior.station)
    and domain(ghost.force,senior.station.force)
    and domain(ghost.surface,senior.station.surface)
    and domain(observed.force,senior.station.force)
    and domain(observed.surface,senior.station.surface)
    and type(radius)=="number" and radius>=4
    and actual and type(actual.x)=="number" and type(actual.y)=="number"
    and shift_sq<=2.25 and range_sq<=radius*radius
    and forward_sq<previous_sq
    and dist2(actual,observed_position)<0.01
  if ok then return true end
  return false,"created-ghost-actual-geometry-or-identity:"
    .."requested="..tostring(site and site.x)..","..tostring(site and site.y)
    ..":actual="..tostring(actual and actual.x)..","..tostring(actual and actual.y)
    ..":shift_sq="..tostring(shift_sq)
    ..":range_sq="..tostring(range_sq)
    ..":radius_sq="..tostring(type(radius)=="number" and radius*radius)
    ..":forward_sq="..tostring(forward_sq)
    ..":previous_sq="..tostring(previous_sq)
    ..":created_unit="..tostring(ghost and ghost.unit_number)
    ..":observed_unit="..tostring(observed and observed.unit_number)
end
M.verify_created_ghost_0912=verify_created_ghost_0912
local function count(inv,item)
  if not(valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and type(n)=="number" and n or nil
end
local function audit(magos,root,api,child)
  local tp=storage and storage.tech_priests
  local plan=root and root.reversal_outbound_0895
  local stage=root and root.reversal_stage_0854
  local senior_stage=root and root.reversal_stage_0855
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(tp and valid(magos and magos.station) and valid(magos.priest)
      and tp.pairs_by_station and tp.pairs_by_priest
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete"
      and root.worker_station_unit==magos.station.unit_number
      and root.reversal_outbound_0895
      and root.reversal_outbound_0895.phase=="senior-build-authorized"
      and root.station_item=="senior-cogitator-station"
      and root.relocation_old_station_unit_0823
      and type(root.id)=="number"
      and root.blocked_item and root.blocked_item:sub(1,9)=="resource:"
      and plan and plan.target and mission and mission.target
      and plan.target.x==mission.target.x and plan.target.y==mission.target.y
      and stage and stage.reversal_stage_index==3
      and stage.phase=="in-magos-depot" and stage.station_item==ITEM
      and stage.id=="reversal-ancestor:"..root.id..":3:"..
        tostring(stage.leaf_station_unit)
      and senior_stage and senior_stage.reversal_stage_index==4
      and senior_stage.leaf_station_unit==stage.worker_station_unit
      and senior_stage.leaf_priest_unit==stage.worker_priest_unit
      and root.reversal_stage_0854==stage
      and tp.pairs_by_station[stage.worker_station_unit]==nil
      and not tp.pairs_by_station[stage.leaf_station_unit]) then
    return nil,"intermediate-original-writ-or-target-invalid"
  end
  local senior=tp.pairs_by_priest[senior_stage.leaf_priest_unit]
  local original=tp.pairs_by_priest[stage.leaf_priest_unit]
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(senior and valid(senior.station) and valid(senior.priest)
      and senior.station.name=="senior-cogitator-station"
      and senior.station.unit_number~=stage.worker_station_unit
      and senior.priest.unit_number==stage.worker_priest_unit
      and tp.pairs_by_station[senior.station.unit_number]==senior
      and domain(senior.station.force,magos.station.force)
      and domain(senior.station.surface,magos.station.surface)
      and original and valid(original.priest)
      and original.priest.unit_number==stage.leaf_priest_unit
      and h and type(h.is_direct_subordinate)=="function"
      and h.is_direct_subordinate(magos,senior)==true
      and type(api.rank)=="function" and api.rank(senior)==3
      and dist2(senior.station.position,mission.target)
        <dist2(magos.station.position,mission.target)) then
    return nil,"intermediate-original-senior-priest-or-hierarchy-invalid"
  end
  local lease=Relocation.pending_for_record(stage)
  if not(lease and lease.status=="staged"
      and lease.reversal_ancestor_0854
      and lease.rec_id==stage.id
      and lease.old_unit==stage.leaf_station_unit
      and lease.priest_unit==stage.leaf_priest_unit
      and lease.priest==original.priest
      and not valid(lease.old_station)
      and lease.target==nil) then
    return nil,"intermediate-original-priest-lease-invalid"
  end
  local held,why=Depot.get_staged(magos,stage)
  local carried
  -- 0913: after a counted physical debit, the depot is intentionally empty.
  -- Reconcile only the exact active child writ and its engine-owned carrier;
  -- never mistake an empty inventory or a Lua phase for a delivered item.
  if not held and child then
    local follow=child.reversal_followup_0911
    local entry=tp.station_reversal_depot_0852
      and tp.station_reversal_depot_0852[stage.id]
    local cargo=Cargo.get(senior,child)
    if follow and root.reversal_next_0911
        and root.reversal_next_0911.child_writ_id==child.id
        and follow.root_writ_id==root.id and follow.stage_id==stage.id
        and follow.original_priest==stage.leaf_priest_unit
        and follow.magos_station_unit==magos.station.unit_number
        and follow.original_senior_priest==senior.priest.unit_number
        and child.status=="active" and child.station_item==ITEM
        and child.worker_station_unit==senior.station.unit_number
        and entry and (entry.status=="stored" or entry.status=="outbound")
        and entry.record_id==stage.id and entry.item==ITEM
        and entry.magos_station_unit==magos.station.unit_number
        and entry.magos_priest_unit==magos.priest.unit_number
        and entry.worker_station_unit==stage.worker_station_unit
        and entry.worker_priest_unit==stage.worker_priest_unit
        and entry.leaf_station_unit==stage.leaf_station_unit
        and entry.leaf_priest_unit==stage.leaf_priest_unit
        and domain(entry.force,magos.station.force)
        and domain(entry.surface,magos.station.surface)
        and cargo and cargo.status=="carrying"
        and valid(cargo.inventory) and cargo.inventory~=entry.inventory
        and count(entry.inventory,ITEM)==0
        and count(cargo.inventory,ITEM)==1 then
      held=entry
      carried=cargo
    end
  end
  if not(held and count(held.inventory,ITEM)==(carried and 0 or 1)) then
    return nil,"intermediate-protected-real-item-unverified:"..tostring(why)
  end
  local source=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[senior_stage.id]
  if not(source and source.status=="outbound"
      and source.record_id==senior_stage.id
      and source.inventory~=held.inventory
      and count(source.inventory,"senior-cogitator-station")==0) then
    return nil,"intermediate-original-senior-item-not-consumed"
  end
  local seen={[source.inventory]=true,[held.inventory]=true}
  for _,key in ipairs({"reversal_stage_0851","reversal_stage_0853"}) do
    local prior=root[key]
    local entry=prior and Depot.get_staged(magos,prior)
    if not(entry and valid(entry.inventory) and not seen[entry.inventory]
        and count(entry.inventory,"junior-cogitator-station")==1) then
      return nil,"intermediate-prior-junior-depot-unverified:"..key
    end
    seen[entry.inventory]=true
  end
  for _,cargo in pairs(tp.station_cargo_0824 or {}) do
    if cargo.priest_unit==senior.priest.unit_number and cargo~=carried then
      return nil,"intermediate-senior-has-other-real-cargo"
    end
  end
  return senior,stage,held,mission.target,carried
end
-- 0913: only this child writ may move the original Senior back to the
-- Magos's actual depot, physically debit one recovered Intermediate item,
-- and carry it in the existing 0824 engine inventory. The original staged
-- Intermediate priest remains untouched until a later build-authority gate.
function M.service_pickup(senior,child,api)
  local tp=storage and storage.tech_priests
  local follow=child and child.reversal_followup_0911
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local magos=follow and tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local next_step=root and root.reversal_next_0911
  if not(valid(senior and senior.station) and valid(senior.priest)
      and child and child.status=="active" and follow
      and root and magos and next_step
      and next_step.status=="ghost-reserved"
      and next_step.child_writ_id==child.id
      and next_step.ghost_unit==child.ghost_unit
      and child.worker_station_unit==senior.station.unit_number
      and child.requester_station_unit==senior.station.unit_number
      and child.station_item==ITEM and child.station_entity==ITEM
      and follow.original_senior_priest==senior.priest.unit_number
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[senior.station.unit_number]==child.id
      and type(api)=="table" and type(api.find_ghost)=="function") then
    return true,"intermediate-pickup-original-child-writ-invalid"
  end
  local ghost=api.find_ghost(senior,child)
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and ghost.unit_number==child.ghost_unit
      and domain(ghost.force,senior.station.force)
      and domain(ghost.surface,senior.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01) then
    return true,"intermediate-pickup-owned-ghost-unverifiable"
  end
  local worker,stage,entry,target,carried=audit(magos,root,api,child)
  if not(worker and worker==senior and stage
      and stage.id==follow.stage_id and entry and target) then
    return true,"intermediate-pickup-live-custody-invalid:"..tostring(stage)
  end
  if carried then
    local observed,why=Cargo.observe_carrier(senior,child)
    if not observed then
      return true,"intermediate-pickup-carrier-position-unverified:"..tostring(why)
    end
    entry.status="outbound"
    follow.picked_tick=follow.picked_tick or (game and game.tick)
    return true,"reversal-intermediate-real-item-carried-from-magos"
  end
  if Cargo.has_record(child) then
    return true,"intermediate-pickup-existing-cargo-ambiguous"
  end
  if type(game and game.tick)~="number" then
    return true,"intermediate-pickup-clock-unavailable"
  end
  local now=game.tick
  follow.pickup_started_tick=follow.pickup_started_tick or now
  if now<follow.pickup_started_tick then
    return true,"intermediate-pickup-clock-reversed"
  end
  if now-follow.pickup_started_tick>7200 then
    return true,"intermediate-pickup-physical-travel-timeout"
  end
  -- The Senior may still be finishing an ordinary direct-acquisition or
  -- emergency task assigned before the child writ. The 0850 reservation
  -- blocks NEW work; this gate never cancels or preempts existing duties.
  if senior.mode~="idle" or senior.dead or senior.recalling
      or senior.deploying then
    return true,"intermediate-pickup-awaiting-existing-duty"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if senior[key]~=nil and senior[key]~=false then
      return true,"intermediate-pickup-awaiting-existing-duty"
    end
  end
  -- Respect existing duties. The 0850 future-work reservation prevents
  -- *new* ordinary assignments but never cancels an active task or combat.
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)=="function" then
    local ok,status=pcall(probe,senior)
    if not ok or not(type(status)=="table"
        and (status.priority=="idle" or status.priority=="invalid")) then
      return true,"intermediate-pickup-awaiting-existing-duty"
    end
  end
  -- Preserve the stronger existing-duty and emergency-work checks above.
  -- Once idle, require the real Senior build and child ghost to stabilize
  -- before issuing a walk or debiting the protected Intermediate inventory.
  -- 0914: the Senior build and the next ghost can be registered during the
  -- SAME engine tick. Keep the recovered Intermediate item in its protected
  -- physical depot until the original Senior build has a persistent receipt
  -- and the next ghost has survived a 120-tick custody stabilization window.
  -- Existing cargo is reconciled above without a second debit.
  local built_tick=root.completed_tick
  local reserved_tick=next_step.created_tick
  if type(built_tick)~="number" or type(reserved_tick)~="number"
      or type(game and game.tick)~="number"
      or reserved_tick<built_tick or game.tick<reserved_tick
      or game.tick-reserved_tick<120 then
    return true,"intermediate-pickup-senior-build-escrow-pending"
  end
  if dist2(senior.priest.position,magos.station.position)>25 then
    if not(type(api.command)=="function" and defines and defines.command
        and defines.command.go_to_location and defines.distraction) then
      return true,"intermediate-pickup-movement-authority-unavailable"
    end
    if type(follow.last_pickup_command_tick)=="number"
        and now-follow.last_pickup_command_tick>=0
        and now-follow.last_pickup_command_tick<60 then
      return true,"reversal-intermediate-senior-walking-to-magos-depot"
    end
    local ok,result=pcall(api.command,senior.priest,{
      type=defines.command.go_to_location,
      destination=magos.station.position,radius=2,
      distraction=defines.distraction.none})
    if not ok or result==false then
      return true,"intermediate-pickup-physical-command-refused"
    end
    follow.last_pickup_command_tick=now
    return true,"reversal-intermediate-senior-walking-to-magos-depot"
  end
  -- 0824 is the only physical debit authority; its optional source station
  -- requires exact original-Magos identity and actual five-tile proximity.
  local picked,why=Cargo.pickup(senior,child,entry.inventory,magos.station)
  local rechecked,_,depot,_,real_cargo=audit(magos,root,api,child)
  if not(rechecked==senior and depot==entry and real_cargo
      and count(entry.inventory,ITEM)==0
      and count(real_cargo.inventory,ITEM)==1) then
    return true,"intermediate-pickup-physical-delta-unverified:"..tostring(why)
  end
  entry.status="outbound"
  follow.picked_tick=follow.picked_tick or now
  return true,"reversal-intermediate-real-item-carried-from-magos"
end
-- 0915: after counted pickup, the SAME engine-owned Intermediate item must
-- physically travel from Magos to the exact original Senior-owned ghost.
-- The pickup escrow allows independent engine observation before departure.
function M.service_outward_transit(senior,child,api)
  local tp=storage and storage.tech_priests
  local follow=child and child.reversal_followup_0911
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local magos=follow and tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local next_step=root and root.reversal_next_0911
  if not(valid(senior and senior.station) and valid(senior.priest)
      and root and magos and child.status=="active"
      and next_step and next_step.status=="ghost-reserved"
      and next_step.child_writ_id==child.id
      and next_step.ghost_unit==child.ghost_unit
      and child.worker_station_unit==senior.station.unit_number
      and child.requester_station_unit==senior.station.unit_number
      and follow.original_senior_priest==senior.priest.unit_number
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[senior.station.unit_number]==child.id
      and type(api)=="table" and type(api.find_ghost)=="function"
      and type(api.radius)=="function") then
    return true,"intermediate-transit-original-writ-invalid"
  end
  local ghost=api.find_ghost(senior,child)
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and ghost.unit_number==child.ghost_unit
      and domain(ghost.force,senior.station.force)
      and domain(ghost.surface,senior.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01) then
    return true,"intermediate-transit-owned-ghost-unverifiable"
  end
  local worker,stage,entry,target,carried=audit(magos,root,api,child)
  if not(worker==senior and stage and stage.id==follow.stage_id
      and entry and entry.status=="outbound" and carried
      and carried.status=="carrying" and count(entry.inventory,ITEM)==0
      and count(carried.inventory,ITEM)==1) then
    return true,"intermediate-transit-live-item-custody-invalid"
  end
  local radius=api.radius(senior)
  if not(type(radius)=="number" and radius>=4
      and dist2(ghost.position,senior.station.position)<=radius*radius
      and dist2(ghost.position,target)<dist2(senior.station.position,target)) then
    return true,"intermediate-transit-hierarchy-radius-or-direction-invalid"
  end
  local observed,why=Cargo.observe_carrier(senior,child)
  if not observed then
    return true,"intermediate-transit-carrier-unobservable:"..tostring(why)
  end
  local now=game and game.tick
  if not(type(now)=="number" and type(follow.picked_tick)=="number"
      and now>=follow.picked_tick) then
    return true,"intermediate-transit-pickup-clock-invalid"
  end
  if now-follow.picked_tick<120 then
    return true,"intermediate-transit-pickup-escrow-pending"
  end
  if dist2(senior.priest.position,ghost.position)<=25 then
    follow.transit_status="arrived"
    follow.arrived_tick=follow.arrived_tick or now
    return true,"reversal-intermediate-real-item-arrived-at-ghost"
  end
  if follow.transit_status=="arrived" then follow.arrived_tick=nil end
  follow.transit_status="walking"
  follow.transit_started_tick=follow.transit_started_tick or now
  if now<follow.transit_started_tick then
    return true,"intermediate-transit-clock-reversed"
  end
  if now-follow.transit_started_tick>7200 then
    follow.transit_status="timed-out"
    return true,"intermediate-transit-physical-travel-timeout"
  end
  if senior.mode~="idle" or senior.dead or senior.recalling
      or senior.deploying then
    return true,"intermediate-transit-awaiting-existing-duty"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if senior[key]~=nil and senior[key]~=false then
      return true,"intermediate-transit-awaiting-existing-duty"
    end
  end
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)=="function" then
    local ok,status=pcall(probe,senior)
    if not ok or not(type(status)=="table"
        and (status.priority=="idle" or status.priority=="invalid")) then
      return true,"intermediate-transit-awaiting-existing-duty"
    end
  end
  if not(type(api.command)=="function" and defines and defines.command
      and defines.command.go_to_location and defines.distraction) then
    return true,"intermediate-transit-movement-authority-unavailable"
  end
  if type(follow.transit_last_command_tick)=="number"
      and now-follow.transit_last_command_tick>=0
      and now-follow.transit_last_command_tick<60 then
    return true,"reversal-intermediate-senior-carrying-to-ghost"
  end
  local ok,result=pcall(api.command,senior.priest,{
    type=defines.command.go_to_location,
    destination=ghost.position,radius=2,
    distraction=defines.distraction.none})
  if not ok or result==false then
    return true,"intermediate-transit-physical-command-refused"
  end
  follow.transit_last_command_tick=now
  return true,"reversal-intermediate-senior-carrying-to-ghost"
end

function M.service(magos,api)
  local tp=storage and storage.tech_priests
  local index=tp and tp.station_reversal_followup_0911
  local root_id=index and valid(magos and magos.station)
    and index[magos.station.unit_number]
  if not root_id then return false end
  local root=tp.station_expansion_0256 and tp.station_expansion_0256[root_id]
  if not root then return true,"intermediate-original-writ-missing-quarantined" end
  local next_step=root.reversal_next_0911
  local existing_child=next_step and tp.station_expansion_0256
    and tp.station_expansion_0256[next_step.child_writ_id]
  local senior,stage,held,target,carried=audit(magos,root,api,existing_child)
  if not senior then return true,stage end
  if next_step then
    if next_step.status=="quarantined" then
      return true,"intermediate-ghost-quarantined:"..tostring(next_step.reason)
    end
    local child=tp.station_expansion_0256[next_step.child_writ_id]
    local ghost=child and api.find_ghost(senior,child)
    if not(child and child.status=="active"
        and child.reversal_followup_0911
        and child.reversal_followup_0911.root_writ_id==root.id
        and child.reversal_followup_0911.stage_id==stage.id
        and child.reversal_followup_0911.original_priest==stage.leaf_priest_unit
        and child.worker_station_unit==senior.station.unit_number
        and child.requester_station_unit==senior.station.unit_number
        and child.station_item==ITEM and child.station_entity==ITEM
        and child.ghost_unit==next_step.ghost_unit
        and tp.station_expansion_by_worker_0256[senior.station.unit_number]
          ==child.id
        and valid(ghost) and ghost.unit_number==child.ghost_unit
        and ghost.ghost_name==ITEM
        and domain(ghost.force,senior.station.force)
        and domain(ghost.surface,senior.station.surface)
        and dist2(ghost.position,child.ghost_position)<0.01) then
      return true,"intermediate-reserved-ghost-or-writ-custody-unverifiable"
    end
    return true,carried
      and "reversal-intermediate-real-item-carried-from-magos"
      or "reversal-intermediate-ghost-reserved-awaiting-real-depot-pickup"
  end
  if tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[senior.station.unit_number] then
    return true,"intermediate-original-senior-has-existing-expansion"
  end
  if not(type(api.find_site)=="function"
      and type(api.create_ghost)=="function"
      and type(api.radius)=="function") then
    return true,"intermediate-physical-placement-authority-unavailable"
  end
  local site=api.find_site(senior,ITEM,target)
  local radius=api.radius(senior)
  if not(site and type(radius)=="number" and radius>=4
      and dist2(site,senior.station.position)<=radius*radius
      and dist2(site,target)<dist2(senior.station.position,target)) then
    return true,"intermediate-no-forward-buildable-site"
  end
  local ghost,reason=api.create_ghost(senior,ITEM,site)
  if not valid(ghost) then
    if reason~="physical-ghost-creation-refused"
        and reason~="physical-site-ghost-occupied" then
      root.reversal_next_0911={status="quarantined",
        reason=tostring(reason or "unverified-ghost-creation")}
    end
    return true,"intermediate-physical-ghost-refused:"..tostring(reason)
  end
  -- Re-observe the real engine ghost by its exact unit before registering a
  -- construction writ. A failed readback is quarantined, not re-created.
  local actual=ghost.position
  local observed=actual and type(api.find_ghost)=="function"
    and api.find_ghost(senior,{station_item=ITEM,station_entity=ITEM,
      ghost_unit=ghost.unit_number,
      ghost_position={x=actual.x,y=actual.y}})
  local verified,detail=verify_created_ghost_0912(
    senior,ghost,site,radius,target,observed)
  if not verified then
    root.reversal_next_0911={status="quarantined",
      ghost_unit=ghost.unit_number,reason=detail,
      requested_position={x=site.x,y=site.y},
      actual_position=actual and {x=actual.x,y=actual.y} or nil}
    return true,"intermediate-created-ghost-quarantined:"..detail
  end
  local id=tp.station_expansion_next_id_0256
  if not(type(id)=="number" and not tp.station_expansion_0256[id]) then
    root.reversal_next_0911={status="quarantined",ghost_unit=ghost.unit_number,
      reason="child-writ-id-unavailable"}
    return true,"intermediate-child-writ-id-quarantined"
  end
  local child={id=id,status="active",requester_station_unit=senior.station.unit_number,
    requester_rank=3,required_worker_rank=2,
    worker_station_unit=senior.station.unit_number,commander_bootstrap=true,
    station_item=ITEM,station_entity=ITEM,blocked_item=root.blocked_item,
    ghost_unit=ghost.unit_number,
    ghost_position={x=ghost.position.x,y=ghost.position.y},
    phase="reversal-intermediate-awaiting-physical-depot-pickup",
    created_tick=game.tick,updated_tick=game.tick,
    reversal_followup_0911={root_writ_id=root.id,stage_id=stage.id,
      original_priest=stage.leaf_priest_unit,
      magos_station_unit=magos.station.unit_number,
      original_senior_priest=senior.priest.unit_number}}
  tp.station_expansion_next_id_0256=id+1
  tp.station_expansion_0256[id]=child
  tp.station_expansion_by_worker_0256[senior.station.unit_number]=id
  senior.station_expansion_0256=child
  root.reversal_next_0911={status="ghost-reserved",child_writ_id=id,
    ghost_unit=ghost.unit_number,created_tick=game.tick}
  return true,"reversal-intermediate-real-ghost-reserved"
end
return M
