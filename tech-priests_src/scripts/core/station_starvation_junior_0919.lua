-- 0919: reserve the first recovered Junior's real construction ghost only
-- after the original Intermediate has physically been rebuilt and paired.
-- This module neither moves nor spends any station item. The two original
-- Junior items remain in independent Magos-anchored 0852 inventories.
local Depot=require("scripts.core.station_starvation_depot_0852")
local Cargo=require("scripts.core.station_cargo_0824")
local Relocation=require("scripts.core.station_relocation_0823")
local M={}
local ITEM="junior-cogitator-station"
local function valid(x) return x and x.valid end
local function dist2(a,b)
  if not(a and b) then return math.huge end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
local function domain(a,b)
  return a and b and (a==b or (type(a.index)=="number"
    and type(b.index)=="number" and a.index==b.index))
end
local function count(inv,item)
  if not(valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and type(n)=="number" and n or nil
end
-- 0927: Factorio can return a valid newly created entity-ghost before the
-- 0256 filtered lookup observes it. Re-read the actual surface at the exact coordinate without a
-- ghost_name filter, then require the SAME engine unit, prototype, position,
-- force and surface. Never adopt a nearby/foreign ghost or create a second.
local function reobserve_created_ghost_0927(worker,ghost,item,api)
  local actual=valid(ghost) and ghost.position or nil
  if not(actual and type(actual.x)=="number"
      and type(actual.y)=="number") then
    return nil,"created-position-unobservable"
  end
  local rec={station_item=item,station_entity=item,
    ghost_unit=ghost.unit_number,
    ghost_position={x=actual.x,y=actual.y}}
  local observed=type(api.find_ghost)=="function"
    and api.find_ghost(worker,rec) or nil
  if valid(observed) then return observed,"0256-filtered-exact-writ" end
  local station=valid(worker and worker.station) and worker.station
  local surface=station and station.surface
  -- Query the exact coordinate rather than adding a broad area scan to
  -- the high-frequency expansion controller (0743 UPS baseline).
  if not(surface and type(surface.find_entity)=="function") then
    return nil,"independent-surface-readback-unavailable"
  end
  local ok,candidate=pcall(function()
    return surface.find_entity("entity-ghost",actual)
  end)
  if not ok then return nil,"independent-surface-readback-failed" end
  if valid(candidate) and candidate.name=="entity-ghost"
      and candidate.ghost_name==item
      and type(ghost.unit_number)=="number"
      and candidate.unit_number==ghost.unit_number
      and domain(candidate.force,station.force)
      and domain(candidate.surface,station.surface)
      and dist2(candidate.position,actual)<0.01 then
    return candidate,"independent-exact-engine-unit"
  end
  return nil,"independent-exact-engine-unit-not-found"
end
M.reobserve_created_ghost_0927=reobserve_created_ghost_0927
local function ghost_failure_detail_0927(worker,ghost,observed,site,radius,target,route)
  local actual=valid(ghost) and ghost.position or nil
  local origin=valid(worker and worker.station) and worker.station.position or nil
  return "junior-created-ghost-geometry-or-identity-invalid"
    ..":readback="..tostring(route)
    ..":requested="..tostring(site and site.x)..","..tostring(site and site.y)
    ..":actual="..tostring(actual and actual.x)..","..tostring(actual and actual.y)
    ..":shift_sq="..tostring(dist2(actual,site))
    ..":range_sq="..tostring(dist2(actual,origin))
    ..":radius_sq="..tostring(type(radius)=="number" and radius*radius)
    ..":forward_sq="..tostring(dist2(actual,target))
    ..":previous_sq="..tostring(dist2(origin,target))
    ..":created_unit="..tostring(ghost and ghost.unit_number)
    ..":observed_unit="..tostring(observed and observed.unit_number)
    ..":observed_inner="..tostring(observed and observed.ghost_name)
end
local function audit(magos,api)
  local tp=storage and storage.tech_priests
  local index=tp and tp.station_reversal_followup_0911
  local root_id=index and valid(magos and magos.station)
    and index[magos.station.unit_number]
  if not root_id then return nil,"not-reversal-magos" end
  local root=tp.station_expansion_0256 and tp.station_expansion_0256[root_id]
  local intermediate_stage=root and root.reversal_stage_0854
  local senior_stage=root and root.reversal_stage_0855
  local first=root and root.reversal_stage_0853
  local second=root and root.reversal_stage_0851
  local step=root and root.reversal_next_0911
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local plan=root and root.reversal_outbound_0895
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  -- 0923: the real 2.0.77 broker reached this audit but reported only
  -- "not certified" after the independently verified Intermediate build.
  -- Keep the complete original fail-closed gate below; identify the FIRST
  -- missing physical receipt rather than guessing at its cause or bypassing it.
  local function certificate_failure()
    if not(tp and tp.pairs_by_station and tp.pairs_by_priest
        and valid(magos and magos.station) and valid(magos.priest)
        and tp.pairs_by_station[magos.station.unit_number]==magos) then
      return "junior-cert:original-magos-registry"
    end
    if not(root and root.status=="complete"
        and root.worker_station_unit==magos.station.unit_number
        and root.station_item=="senior-cogitator-station"
        and type(root.blocked_item)=="string"
        and root.blocked_item:sub(1,9)=="resource:") then
      return "junior-cert:original-root-writ"
    end
    if not(plan and plan.phase=="senior-build-authorized"
        and plan.target and mission and mission.target
        and mission.target.x==plan.target.x
        and mission.target.y==plan.target.y) then
      return "junior-cert:outbound-phase-or-natural-target"
    end
    if not(first and first.reversal_stage_index==2
        and first.station_item==ITEM and first.phase=="in-magos-depot") then
      return "junior-cert:first-junior-stage"
    end
    if not(second and (second.reversal_stage_index==nil
          or second.reversal_stage_index==1)
        and second.id=="reversal-leaf:"..tostring(root.id)..":"
          ..tostring(second.leaf_station_unit)
        and second.station_item==ITEM and second.phase=="in-magos-depot"
        and second.worker_station_unit==first.leaf_station_unit
        and second.worker_priest_unit==first.leaf_priest_unit
        and second.leaf_station_unit~=second.worker_station_unit) then
      return "junior-cert:second-junior-stage"
    end
    if not(intermediate_stage and senior_stage
        and first.worker_station_unit==intermediate_stage.leaf_station_unit
        and first.worker_priest_unit==intermediate_stage.leaf_priest_unit) then
      return "junior-cert:original-intermediate-worker"
    end
    if not(step and step.status=="ghost-reserved") then
      return "junior-cert:intermediate-step-status"
    end
    if not(child and child.status=="complete"
        and type(child.completed_tick)=="number"
        and child.station_item=="intermediate-cogitator-station") then
      return "junior-cert:intermediate-completion-receipt"
    end
    if not(child.relocation_old_station_unit_0823
          ==intermediate_stage.leaf_station_unit
        and child.reversal_followup_0911
        and child.reversal_followup_0911.root_writ_id==root.id
        and child.reversal_followup_0911.stage_id==intermediate_stage.id
        and child.reversal_followup_0911.original_priest
          ==intermediate_stage.leaf_priest_unit
        and child.ghost_unit==step.ghost_unit) then
      return "junior-cert:intermediate-ghost-or-priest-custody"
    end
    if not(type(game and game.tick)=="number"
        and game.tick>=child.completed_tick+120) then
      return "junior-original-intermediate-build-not-certified"
    end
    if not(type(api)=="table" and type(api.rank)=="function"
        and type(api.radius)=="function") then
      return "junior-cert:physical-placement-api"
    end
    return "junior-cert:unclassified-fail-closed"
  end
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(magos.station) and valid(magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete"
      and root.worker_station_unit==magos.station.unit_number
      and root.station_item=="senior-cogitator-station"
      and root.blocked_item and root.blocked_item:sub(1,9)=="resource:"
      and plan and plan.phase=="senior-build-authorized"
      and plan.target and mission and mission.target
      and mission.target.x==plan.target.x
      and mission.target.y==plan.target.y
      and first and first.reversal_stage_index==2
      and first.station_item==ITEM
      and first.phase=="in-magos-depot"
      -- The real 0850 terminal-leaf record has NO stage index. Its
      -- authoritative identity is reversal-leaf:<root>:<original leaf>.
      -- Require that canonical writ and the original Junior worker/priest
      -- chain rather than rejecting physically conserved legacy saves.
      and second and (second.reversal_stage_index==nil
        or second.reversal_stage_index==1)
      and second.id=="reversal-leaf:"..tostring(root.id)..":"
        ..tostring(second.leaf_station_unit)
      and second.station_item==ITEM
      and second.phase=="in-magos-depot"
      and second.worker_station_unit==first.leaf_station_unit
      and second.worker_priest_unit==first.leaf_priest_unit
      and second.leaf_station_unit~=second.worker_station_unit
      and intermediate_stage and senior_stage
      and first.worker_station_unit==intermediate_stage.leaf_station_unit
      and first.worker_priest_unit==intermediate_stage.leaf_priest_unit
      and step and step.status=="ghost-reserved"
      and child and child.status=="complete"
      and type(child.completed_tick)=="number"
      and child.station_item=="intermediate-cogitator-station"
      and child.relocation_old_station_unit_0823
        ==intermediate_stage.leaf_station_unit
      and child.reversal_followup_0911
      and child.reversal_followup_0911.root_writ_id==root.id
      and child.reversal_followup_0911.stage_id==intermediate_stage.id
      and child.reversal_followup_0911.original_priest
        ==intermediate_stage.leaf_priest_unit
      and child.ghost_unit==step.ghost_unit
      and type(game and game.tick)=="number"
      and game.tick>=child.completed_tick+120
      and type(api)=="table" and type(api.rank)=="function"
      and type(api.radius)=="function") then
    return nil,certificate_failure()
  end
  local intermediate=tp.pairs_by_priest[intermediate_stage.leaf_priest_unit]
  local senior=tp.pairs_by_priest[senior_stage.leaf_priest_unit]
  local original=tp.pairs_by_priest[first.leaf_priest_unit]
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(intermediate and valid(intermediate.station)
      and valid(intermediate.priest)
      and intermediate.station.name=="intermediate-cogitator-station"
      and intermediate.station.unit_number~=first.worker_station_unit
      and intermediate.priest.unit_number==first.worker_priest_unit
      and tp.pairs_by_station[intermediate.station.unit_number]==intermediate
      and tp.pairs_by_station[first.worker_station_unit]==nil
      and dist2(intermediate.station.position,child.ghost_position)<0.01
      and domain(intermediate.station.force,magos.station.force)
      and domain(intermediate.station.surface,magos.station.surface)
      and senior and valid(senior.station) and valid(senior.priest)
      and senior.station.name=="senior-cogitator-station"
      and senior.priest.unit_number==senior_stage.leaf_priest_unit
      and child.worker_station_unit==senior.station.unit_number
      and original and valid(original.priest)
      and original.priest.unit_number==first.leaf_priest_unit
      and h and type(h.is_direct_subordinate)=="function"
      and h.is_direct_subordinate(magos,senior)==true
      and h.is_direct_subordinate(senior,intermediate)==true
      and api.rank(intermediate)==2
      and dist2(intermediate.station.position,mission.target)
        <dist2(senior.station.position,mission.target)) then
    return nil,"junior-original-intermediate-priest-or-hierarchy-invalid"
  end
  local first_entry,first_why=Depot.get_staged(magos,first)
  local second_entry,second_why=Depot.get_staged(magos,second)
  local source=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[intermediate_stage.id]
  local senior_source=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[senior_stage.id]
  if not(first_entry and second_entry and first_entry~=second_entry
      and valid(first_entry.inventory) and valid(second_entry.inventory)
      and first_entry.inventory~=second_entry.inventory
      and count(first_entry.inventory,ITEM)==1
      and count(second_entry.inventory,ITEM)==1
      and source and source.status=="outbound"
      and valid(source.inventory) and source.inventory~=first_entry.inventory
      and source.inventory~=second_entry.inventory
      and count(source.inventory,"intermediate-cogitator-station")==0
      and senior_source and senior_source.status=="outbound"
      and valid(senior_source.inventory)
      and senior_source.inventory~=first_entry.inventory
      and senior_source.inventory~=second_entry.inventory
      and senior_source.inventory~=source.inventory
      and count(senior_source.inventory,"senior-cogitator-station")==0
      and not Cargo.has_record(child)
      and not Relocation.pending_for_record(child)) then
    return nil,"junior-protected-depots-or-ancestor-cargo-invalid:"
      ..tostring(first_why)..":"..tostring(second_why)
  end
  return {tp=tp,root=root,first=first,second=second,
    intermediate=intermediate,first_entry=first_entry,
    second_entry=second_entry,target=mission.target}
end
function M.service(magos,api)
  local ctx,why=audit(magos,api)
  if not ctx then
    if why=="not-reversal-magos" or
        why=="junior-original-intermediate-build-not-certified" then
      return false,why
    end
    return true,why
  end
  local tp,root,worker=ctx.tp,ctx.root,ctx.intermediate
  local next_step=root.reversal_junior_0919
  if next_step then
    if next_step.status=="quarantined" then
      return true,"junior-ghost-quarantined:"..tostring(next_step.reason)
    end
    local child=tp.station_expansion_0256[next_step.child_writ_id]
    local ghost=child and api.find_ghost(worker,child)
    if not(child and child.status=="active"
        and child.reversal_junior_0919
        and child.reversal_junior_0919.root_writ_id==root.id
        and child.reversal_junior_0919.stage_id==ctx.first.id
        and child.reversal_junior_0919.original_priest
          ==ctx.first.leaf_priest_unit
        and child.worker_station_unit==worker.station.unit_number
        and child.requester_station_unit==worker.station.unit_number
        and child.station_item==ITEM and child.station_entity==ITEM
        and child.ghost_unit==next_step.ghost_unit
        and tp.station_expansion_by_worker_0256[worker.station.unit_number]
          ==child.id
        and valid(ghost) and ghost.unit_number==child.ghost_unit
        and ghost.name=="entity-ghost" and ghost.ghost_name==ITEM
        and domain(ghost.force,worker.station.force)
        and domain(ghost.surface,worker.station.surface)
        and dist2(ghost.position,child.ghost_position)<0.01) then
      return true,"junior-reserved-ghost-or-writ-custody-unverifiable"
    end
    return true,"reversal-first-junior-ghost-awaiting-physical-depot-pickup"
  end
  if tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[worker.station.unit_number] then
    return true,"junior-original-intermediate-has-existing-expansion"
  end
  if not(type(api.find_site)=="function"
      and type(api.create_ghost)=="function"
      and type(api.find_ghost)=="function") then
    return true,"junior-physical-placement-authority-unavailable"
  end
  local site=api.find_site(worker,ITEM,ctx.target)
  local radius=api.radius(worker)
  if not(site and type(radius)=="number" and radius>=4
      and dist2(site,worker.station.position)<=radius*radius
      and dist2(site,ctx.target)<dist2(worker.station.position,ctx.target)) then
    return true,"junior-no-forward-buildable-site"
  end
  local ghost,reason=api.create_ghost(worker,ITEM,site)
  if not valid(ghost) then
    if reason~="physical-ghost-creation-refused"
        and reason~="physical-site-ghost-occupied" then
      root.reversal_junior_0919={status="quarantined",
        reason=tostring(reason or "unverified-ghost-creation")}
    end
    return true,"junior-physical-ghost-refused:"..tostring(reason)
  end
  local actual=ghost.position
  local observed,observation_route=reobserve_created_ghost_0927(
    worker,ghost,ITEM,api)
  if not(valid(observed) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and type(ghost.unit_number)=="number"
      and observed.unit_number==ghost.unit_number
      and observed.name=="entity-ghost" and observed.ghost_name==ITEM
      and domain(ghost.force,worker.station.force)
      and domain(ghost.surface,worker.station.surface)
      and domain(observed.force,worker.station.force)
      and domain(observed.surface,worker.station.surface)
      and dist2(actual,site)<=2.25
      and dist2(actual,observed.position)<0.01
      and dist2(actual,worker.station.position)<=radius*radius
      and dist2(actual,ctx.target)<dist2(worker.station.position,ctx.target)) then
    local detail=ghost_failure_detail_0927(
      worker,ghost,observed,site,radius,ctx.target,observation_route)
    root.reversal_junior_0919={status="quarantined",
      reason=detail,ghost_unit=ghost.unit_number,
      requested_position={x=site.x,y=site.y},
      actual_position=actual and {x=actual.x,y=actual.y} or nil}
    return true,"junior-created-ghost-quarantined:"..detail
  end
  local id=tp.station_expansion_next_id_0256
  if not(type(id)=="number" and not tp.station_expansion_0256[id]) then
    root.reversal_junior_0919={status="quarantined",
      reason="junior-child-writ-id-unavailable",ghost_unit=ghost.unit_number}
    return true,"junior-child-writ-id-quarantined"
  end
  local child={id=id,status="active",
    requester_station_unit=worker.station.unit_number,requester_rank=2,
    required_worker_rank=1,worker_station_unit=worker.station.unit_number,
    commander_bootstrap=true,station_item=ITEM,station_entity=ITEM,
    blocked_item=root.blocked_item,ghost_unit=ghost.unit_number,
    ghost_position={x=actual.x,y=actual.y},
    phase="reversal-first-junior-awaiting-physical-depot-pickup",
    created_tick=game.tick,updated_tick=game.tick,
    reversal_junior_0919={root_writ_id=root.id,stage_id=ctx.first.id,
      original_priest=ctx.first.leaf_priest_unit,
      magos_station_unit=magos.station.unit_number,
      original_intermediate_priest=worker.priest.unit_number}}
  tp.station_expansion_next_id_0256=id+1
  tp.station_expansion_0256[id]=child
  tp.station_expansion_by_worker_0256[worker.station.unit_number]=id
  worker.station_expansion_0256=child
  root.reversal_junior_0919={status="ghost-reserved",
    child_writ_id=id,ghost_unit=ghost.unit_number,created_tick=game.tick}
  return true,"reversal-first-junior-real-ghost-reserved"
end


-- 0928: the original rebuilt Intermediate can collect exactly one of the
-- four already recovered station items from its real Magos depot. This is a
-- physical pickup stage ONLY: no Junior build, item synthesis, teleport,
-- staged-priest claim or ghost success is inferred.
function M.service_first_junior_pickup_0928(worker,child,api)
  local tp=storage and storage.tech_priests
  local follow=child and child.reversal_junior_0919
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local magos=follow and tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local step=root and root.reversal_junior_0919
  local stage=root and root.reversal_stage_0853
  local second=root and root.reversal_stage_0851
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(worker and worker.station) and valid(worker.priest)
      and tp.pairs_by_station[worker.station.unit_number]==worker
      and tp.pairs_by_priest[worker.priest.unit_number]==worker
      and worker.station.name=="intermediate-cogitator-station"
      and valid(magos and magos.station) and valid(magos.priest)
      and root and root.status=="complete"
      and follow and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and follow.original_intermediate_priest==worker.priest.unit_number
      and follow.magos_station_unit==magos.station.unit_number
      and child.status=="active"
      and child.worker_station_unit==worker.station.unit_number
      and child.requester_station_unit==worker.station.unit_number
      and child.station_item==ITEM and child.station_entity==ITEM
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[worker.station.unit_number]==child.id
      and stage and stage.id==follow.stage_id
      and stage.station_item==ITEM and stage.reversal_stage_index==2
      and stage.leaf_priest_unit==follow.original_priest
      and stage.worker_priest_unit==worker.priest.unit_number
      and stage.phase=="in-magos-depot"
      and second and second.station_item==ITEM
      and domain(worker.station.force,magos.station.force)
      and domain(worker.station.surface,magos.station.surface)
      and type(api)=="table" and type(api.find_ghost)=="function"
      and type(api.radius)=="function") then
    return true,"junior-pickup-original-writ-or-priest-invalid"
  end
  local ghost=api.find_ghost(worker,child)
  local radius=api.radius(worker)
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and ghost.unit_number==child.ghost_unit
      and domain(ghost.force,worker.station.force)
      and domain(ghost.surface,worker.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01
      and type(radius)=="number" and radius>=4
      and dist2(ghost.position,worker.station.position)<=radius*radius
      and mission and mission.target
      and dist2(ghost.position,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return true,"junior-pickup-original-ghost-or-direction-invalid"
  end
  local second_entry,second_why=Depot.get_staged(magos,second)
  local first_entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  if not(second_entry and valid(second_entry.inventory)
      and count(second_entry.inventory,ITEM)==1
      and first_entry and valid(first_entry.inventory)
      and first_entry.inventory~=second_entry.inventory
      and first_entry.record_id==stage.id
      and first_entry.item==ITEM
      and first_entry.magos_station_unit==magos.station.unit_number
      and first_entry.magos_priest_unit==magos.priest.unit_number) then
    return true,"junior-pickup-independent-depots-invalid:"..tostring(second_why)
  end
  if Cargo.has_record(child) then
    local carried,why=Cargo.get(worker,child)
    if not(carried and carried.status=="carrying"
        and first_entry.status=="outbound"
        and valid(carried.inventory)
        and carried.inventory~=first_entry.inventory
        and carried.inventory~=second_entry.inventory
        and count(first_entry.inventory,ITEM)==0
        and count(carried.inventory,ITEM)==1) then
      return true,"junior-pickup-existing-cargo-quarantined:"..tostring(why)
    end
    local seen,reason=Cargo.observe_carrier(worker,child)
    if not seen then
      return true,"junior-pickup-carrier-unobservable:"..tostring(reason)
    end
    return true,"reversal-first-junior-real-item-carried-from-magos"
  end
  local ctx,why=audit(magos,api)
  if not(ctx and ctx.intermediate==worker and ctx.first==stage
      and ctx.first_entry==first_entry
      and first_entry.status=="stored"
      and count(first_entry.inventory,ITEM)==1) then
    return true,"junior-pickup-pre-debit-custody-invalid:"..tostring(why)
  end
  local now=game and game.tick
  if not(type(now)=="number" and type(step.created_tick)=="number"
      and now>=step.created_tick+120) then
    return true,"junior-pickup-ghost-escrow-pending"
  end
  follow.pickup_started_tick=follow.pickup_started_tick or now
  if now<follow.pickup_started_tick
      or now-follow.pickup_started_tick>7200 then
    return true,"junior-pickup-clock-or-physical-travel-timeout"
  end
  if worker.mode~="idle" or worker.dead or worker.recalling or worker.deploying then
    return true,"junior-pickup-awaiting-existing-duty"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if worker[key]~=nil and worker[key]~=false then
      return true,"junior-pickup-awaiting-existing-duty"
    end
  end
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)=="function" then
    local ok,result=pcall(probe,worker)
    if not ok or not(type(result)=="table"
        and (result.priority=="idle" or result.priority=="invalid")) then
      return true,"junior-pickup-awaiting-existing-duty"
    end
  end
  if dist2(worker.priest.position,magos.station.position)>25 then
    if not(type(api.command)=="function" and defines and defines.command
        and defines.command.go_to_location and defines.distraction) then
      return true,"junior-pickup-movement-authority-unavailable"
    end
    if type(follow.last_pickup_command_tick)=="number"
        and now-follow.last_pickup_command_tick>=0
        and now-follow.last_pickup_command_tick<60 then
      return true,"reversal-first-junior-intermediate-walking-to-magos"
    end
    local ok,result=pcall(api.command,worker.priest,{
      type=defines.command.go_to_location,
      destination=magos.station.position,radius=2,
      distraction=defines.distraction.none})
    if not ok or result==false then
      return true,"junior-pickup-physical-command-refused"
    end
    follow.last_pickup_command_tick=now
    return true,"reversal-first-junior-intermediate-walking-to-magos"
  end
  local picked,pickup_why=Cargo.pickup(
    worker,child,first_entry.inventory,magos.station)
  local carried,carry_why=Cargo.get(worker,child)
  if not(picked and carried and carried.status=="carrying"
      and count(first_entry.inventory,ITEM)==0
      and count(carried.inventory,ITEM)==1
      and count(second_entry.inventory,ITEM)==1) then
    return true,"junior-pickup-physical-delta-unverified:"
      ..tostring(pickup_why)..":"..tostring(carry_why)
  end
  first_entry.status="outbound"
  follow.picked_tick=now
  return true,"reversal-first-junior-real-item-carried-from-magos"
end

-- 0930: move the EXACT physically debited first-Junior station item from
-- the original Magos depot to its reserved ghost. This only certifies travel
-- and arrival; original-priest lease arming and construction are separate.
-- Keep the other Junior's original real depot and staged lease untouched.
function M.service_first_junior_outward_transit_0930(worker,child,api)
  local tp=storage and storage.tech_priests
  local follow=child and child.reversal_junior_0919
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local step=root and root.reversal_junior_0919
  local stage=root and root.reversal_stage_0853
  local second=root and root.reversal_stage_0851
  local magos=follow and tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local original=tp and tp.pairs_by_priest and follow
    and tp.pairs_by_priest[follow.original_priest]
  local lease=tp and tp.station_relocation_0823 and stage
    and tp.station_relocation_0823[stage.leaf_station_unit]
  local second_lease=tp and tp.station_relocation_0823 and second
    and tp.station_relocation_0823[second.leaf_station_unit]
  local second_original=tp and tp.pairs_by_priest and second
    and tp.pairs_by_priest[second.leaf_priest_unit]
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(worker and worker.station) and valid(worker.priest)
      and tp.pairs_by_station[worker.station.unit_number]==worker
      and tp.pairs_by_priest[worker.priest.unit_number]==worker
      and worker.station.name=="intermediate-cogitator-station"
      and valid(magos and magos.station) and valid(magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete" and follow and step
      and child.status=="active" and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and child.station_item==ITEM and child.station_entity==ITEM
      and child.requester_station_unit==worker.station.unit_number
      and child.worker_station_unit==worker.station.unit_number
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[worker.station.unit_number]==child.id
      and follow.original_intermediate_priest==worker.priest.unit_number
      and stage and stage.id==follow.stage_id and stage.station_item==ITEM
      and stage.reversal_stage_index==2 and stage.phase=="in-magos-depot"
      and stage.worker_priest_unit==worker.priest.unit_number
      and stage.leaf_priest_unit==follow.original_priest
      and second and second.station_item==ITEM
      and original and valid(original.priest)
      and original.priest.unit_number==follow.original_priest
      and lease and lease.status=="staged"
      and lease.priest==original.priest and lease.old_unit==stage.leaf_station_unit
      and second_lease and second_lease.status=="staged"
      and second_lease.old_unit==second.leaf_station_unit
      and second_lease.priest_unit==second.leaf_priest_unit
      and second_original and valid(second_original.priest)
      and second_lease.priest==second_original.priest
      and not child.relocation_old_station_unit_0823
      and not Relocation.pending_for_record(child)
      and domain(worker.station.force,magos.station.force)
      and domain(worker.station.surface,magos.station.surface)
      and type(api)=="table" and type(api.find_ghost)=="function"
      and type(api.radius)=="function") then
    return true,"junior-transit-original-writ-or-priest-invalid"
  end
  local ghost=api.find_ghost(worker,child)
  local radius=api.radius(worker)
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and ghost.unit_number==child.ghost_unit
      and domain(ghost.force,worker.station.force)
      and domain(ghost.surface,worker.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01
      and type(radius)=="number" and radius>=4
      and dist2(ghost.position,worker.station.position)<=radius*radius
      and mission and mission.target
      and dist2(ghost.position,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return true,"junior-transit-exact-ghost-or-forward-radius-invalid"
  end
  local first_entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local second_entry,second_why=Depot.get_staged(magos,second)
  local cargo,cargo_why=Cargo.get(worker,child)
  if not(first_entry and first_entry.record_id==stage.id
      and first_entry.status=="outbound" and valid(first_entry.inventory)
      and first_entry.magos_station_unit==magos.station.unit_number
      and first_entry.magos_priest_unit==magos.priest.unit_number
      and count(first_entry.inventory,ITEM)==0
      and second_entry and valid(second_entry.inventory)
      and second_entry.inventory~=first_entry.inventory
      and count(second_entry.inventory,ITEM)==1
      and cargo and cargo.status=="carrying" and valid(cargo.inventory)
      and cargo.inventory~=first_entry.inventory
      and cargo.inventory~=second_entry.inventory
      and count(cargo.inventory,ITEM)==1) then
    return true,"junior-transit-physical-custody-invalid:"
      ..tostring(second_why)..":"..tostring(cargo_why)
  end
  local observed,observe_why=Cargo.observe_carrier(worker,child)
  if not observed then
    return true,"junior-transit-carrier-unobservable:"..tostring(observe_why)
  end
  local now=game and game.tick
  if not(type(now)=="number" and type(follow.picked_tick)=="number"
      and now>=follow.picked_tick) then
    return true,"junior-transit-pickup-clock-invalid"
  end
  if now-follow.picked_tick<120 then
    return true,"junior-transit-pickup-escrow-pending"
  end
  -- 0931: proximity alone is not a transit receipt. A carried station item
  -- must have an observed physical movement command, a monotonic clock and
  -- a bounded journey before the original priest's build lease can be armed.
  -- A persisted timeout cannot be erased merely by a later position sample.
  if follow.transit_status=="timed-out" then
    return true,"junior-transit-physical-travel-timeout"
  end
  if type(follow.transit_started_tick)=="number" then
    if now<follow.transit_started_tick then
      return true,"junior-transit-clock-reversed"
    end
    if now-follow.transit_started_tick>7200 then
      follow.transit_status="timed-out"
      return true,"junior-transit-physical-travel-timeout"
    end
  end
  if dist2(worker.priest.position,ghost.position)<=25 then
    if not(type(follow.transit_started_tick)=="number"
        and type(follow.transit_last_command_tick)=="number"
        and follow.transit_last_command_tick>=follow.transit_started_tick
        and now>=follow.transit_last_command_tick
        and (follow.transit_status=="walking"
          or follow.transit_status=="arrived")) then
      return true,"junior-transit-no-physical-departure-receipt"
    end
    follow.transit_status="arrived"
    follow.arrived_tick=follow.arrived_tick or now
    return true,"reversal-first-junior-real-item-arrived-at-ghost"
  end
  if follow.transit_status=="arrived" then follow.arrived_tick=nil end
  follow.transit_status="walking"
  follow.transit_started_tick=follow.transit_started_tick or now
  if worker.mode~="idle" or worker.dead or worker.recalling
      or worker.deploying then
    return true,"junior-transit-awaiting-existing-duty"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if worker[key]~=nil and worker[key]~=false then
      return true,"junior-transit-awaiting-existing-duty"
    end
  end
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)=="function" then
    local ok,status=pcall(probe,worker)
    if not ok or not(type(status)=="table"
        and (status.priority=="idle" or status.priority=="invalid")) then
      return true,"junior-transit-awaiting-existing-duty"
    end
  end
  if not(type(api.command)=="function" and defines and defines.command
      and defines.command.go_to_location and defines.distraction) then
    return true,"junior-transit-movement-authority-unavailable"
  end
  if type(follow.transit_last_command_tick)=="number"
      and now-follow.transit_last_command_tick>=0
      and now-follow.transit_last_command_tick<60 then
    return true,"reversal-first-junior-intermediate-carrying-to-ghost"
  end
  local ok,result=pcall(api.command,worker.priest,{
    type=defines.command.go_to_location,
    destination=ghost.position,radius=2,
    distraction=defines.distraction.none})
  if not ok or result==false then
    return true,"junior-transit-physical-command-refused"
  end
  follow.transit_last_command_tick=now
  return true,"reversal-first-junior-intermediate-carrying-to-ghost"
end

-- 0932: arriving with a station item is not permission to instantiate
-- a Cogitator. After a second 120-tick physical-arrival observation, bind
-- only the original 0853 Junior priest lease; 0256/0824 perform the single
-- actual item debit and Factorio's real station construction later.
function M.arm_original_first_junior_rebuild_0932(worker,child,api)
  local follow=child and child.reversal_junior_0919
  local now=game and game.tick
  if not(follow and follow.transit_status=="arrived"
      and type(now)=="number"
      and type(follow.picked_tick)=="number"
      and type(follow.arrived_tick)=="number"
      and type(follow.transit_started_tick)=="number"
      and type(follow.transit_last_command_tick)=="number"
      and now>=follow.arrived_tick+120
      and follow.arrived_tick>=follow.picked_tick+120
      and follow.arrived_tick>=follow.transit_last_command_tick
      and follow.transit_last_command_tick>=follow.transit_started_tick
      and now>=follow.transit_started_tick
      and now-follow.transit_started_tick<=7200
      and type(api)=="table" and type(api.rank)=="function"
      and api.rank(worker)==2) then
    return true,"first-junior-build-arrival-or-clock-not-certified"
  end
  -- Revalidate ALL provenance, ghost, both original priest leases and
  -- actual cargo counts via the transit auditor, without reacquiring items.
  local _,reason=M.service_first_junior_outward_transit_0930(worker,child,api)
  if reason~="reversal-first-junior-real-item-arrived-at-ghost"
      or follow.arrived_tick>now-120 then
    return true,"first-junior-build-transit-custody-invalid:"..tostring(reason)
  end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local stage=root and root.reversal_stage_0853
  local ghost=api.find_ghost(worker,child)
  if not(valid(ghost) and ghost.unit_number==child.ghost_unit
      and dist2(ghost.position,worker.priest.position)<=25) then
    return true,"first-junior-build-exact-ghost-or-reach-invalid"
  end
  local armed,why=Relocation.arm_staged_first_junior_0932(
    worker,child,stage,ghost)
  if not armed then
    return true,"first-junior-build-original-priest-lease-refused:"..tostring(why)
  end
  follow.build_authorized_tick=now
  follow.build_ghost_unit=ghost.unit_number
  return true,"reversal-first-junior-physical-build-authorized"
end

-- Every post-authorization 0256 tick (including a save/reload or callback
-- after real station creation) must independently verify the original
-- priest, exact ghost/site, conserved second Junior item and single physical
-- 0824 carrier. A forged built entity cannot consume the original item.
function M.verify_authorized_first_junior_rebuild_0932(worker,child,api,ghost,built)
  local tp=storage and storage.tech_priests
  local follow=child and child.reversal_junior_0919
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local magos=follow and tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local stage=root and root.reversal_stage_0853
  local second=root and root.reversal_stage_0851
  local step=root and root.reversal_junior_0919
  local original=tp and tp.pairs_by_priest and follow
    and tp.pairs_by_priest[follow.original_priest]
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(worker and worker.station) and valid(worker.priest)
      and tp.pairs_by_station[worker.station.unit_number]==worker
      and tp.pairs_by_priest[worker.priest.unit_number]==worker
      and valid(magos and magos.station) and valid(magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete"
      and stage and second and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and child and child.status=="active"
      and stage.id==follow.stage_id and stage.station_item==ITEM
      and stage.reversal_stage_index==2 and stage.phase=="in-magos-depot"
      and follow.original_intermediate_priest==worker.priest.unit_number
      and follow.original_priest==stage.leaf_priest_unit
      and child.worker_station_unit==worker.station.unit_number
      and child.requester_station_unit==worker.station.unit_number
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[worker.station.unit_number]==child.id
      and child.station_item==ITEM and child.station_entity==ITEM
      and child.relocation_old_station_unit_0823==stage.leaf_station_unit
      and original and valid(original.priest)
      and original.priest.unit_number==stage.leaf_priest_unit
      and type(game and game.tick)=="number"
      and type(follow.build_authorized_tick)=="number"
      and type(follow.arrived_tick)=="number"
      and follow.build_authorized_tick>=follow.arrived_tick+120
      and game.tick>=follow.build_authorized_tick
      and follow.build_ghost_unit==child.ghost_unit
      and type(api)=="table" and type(api.rank)=="function"
      and type(api.radius)=="function" and api.rank(worker)==2
      and mission and mission.target) then
    return false,"first-junior-build-original-writ-or-hierarchy-invalid"
  end
  local radius=api.radius(worker)
  if not(type(radius)=="number" and radius>=4
      and dist2(child.ghost_position,worker.station.position)<=radius*radius
      and dist2(child.ghost_position,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return false,"first-junior-build-radius-or-natural-target-invalid"
  end
  local entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  local second_entry,second_why=Depot.get_staged(magos,second)
  local cargo,why=Cargo.get(worker,child)
  if not(entry and entry.record_id==stage.id and entry.item==ITEM
      and entry.status=="outbound" and valid(entry.inventory)
      and entry.magos_station_unit==magos.station.unit_number
      and entry.magos_priest_unit==magos.priest.unit_number
      and count(entry.inventory,ITEM)==0
      and second_entry and valid(second_entry.inventory)
      and second_entry.inventory~=entry.inventory
      and count(second_entry.inventory,ITEM)==1
      and cargo and valid(cargo.inventory)
      and cargo.inventory~=entry.inventory
      and cargo.inventory~=second_entry.inventory
      and ((cargo.status=="carrying" and count(cargo.inventory,ITEM)==1)
        or (cargo.status=="building" and count(cargo.inventory,ITEM)==0))) then
    return false,"first-junior-build-real-inventory-custody-invalid:"
      ..tostring(second_why)..":"..tostring(why)
  end
  local same_built=valid(built) and built.name==ITEM
    and domain(built.force,worker.station.force)
    and domain(built.surface,worker.station.surface)
    and dist2(built.position,child.ghost_position)<0.01
  if valid(built) and not same_built then
    return false,"first-junior-build-foreign-constructed-station"
  end
  if not same_built and not(valid(ghost)
      and ghost.name=="entity-ghost" and ghost.ghost_name==ITEM
      and ghost.unit_number==child.ghost_unit
      and domain(ghost.force,worker.station.force)
      and domain(ghost.surface,worker.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01) then
    return false,"first-junior-build-exact-original-ghost-invalid"
  end
  local lease=Relocation.pending_for_record(child)
  if lease then
    if not(lease.status==(cargo.status=="building" and "building" or "mined")
        and lease.old_unit==stage.leaf_station_unit
        and lease.rec_id==child.id and lease.priest==original.priest
        and lease.pair==original and lease.priest_unit==follow.original_priest
        and lease.worker_unit==worker.station.unit_number
        and lease.item==ITEM and not valid(lease.old_station)
        and dist2(lease.target,child.ghost_position)<0.01) then
      return false,"first-junior-build-original-priest-lease-invalid"
    end
  elseif not(same_built and cargo.status=="building"
      and original.station==built
      and tp.pairs_by_station[built.unit_number]==original) then
    return false,"first-junior-build-original-priest-not-reattached"
  end
  if cargo.status=="carrying" and same_built then
    return false,"first-junior-build-foreign-station-before-physical-debit"
  end
  return true,"original-first-junior-physical-build-and-priest-custody-verified"
end

-- 0920: the original Intermediate pair, not the distant Magos, is the
-- reliably scheduled executor after its physical reconstruction. Follow a
-- persistent, exact original-writ pointer back to the Magos for the next
-- ghost reservation. This does not move, debit, create or consume an item.
-- A stale/forged pointer reserves no ghost and cannot adopt another chain.
function M.service_from_intermediate(intermediate,api)
  local follow=intermediate and intermediate.reversal_junior_followup_0920
  if not follow then return false,"not-reversal-intermediate" end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local step=root and root.reversal_next_0911
  local child=step and tp.station_expansion_0256[step.child_writ_id]
  local stage=root and root.reversal_stage_0854
  local magos=tp and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(intermediate.station) and valid(intermediate.priest)
      and intermediate.station.name=="intermediate-cogitator-station"
      and tp.pairs_by_station[intermediate.station.unit_number]==intermediate
      and intermediate.priest.unit_number==follow.original_priest
      and tp.pairs_by_priest[follow.original_priest]==intermediate
      and intermediate.station.unit_number~=follow.original_station_unit
      and tp.pairs_by_station[follow.original_station_unit]==nil
      and root and root.status=="complete"
      and root.worker_station_unit==follow.magos_station_unit
      and stage and stage.leaf_priest_unit==follow.original_priest
      and stage.leaf_station_unit==follow.original_station_unit
      and step and step.child_writ_id==follow.child_writ_id
      and child and child.status=="complete"
      and child.station_item=="intermediate-cogitator-station"
      and child.relocation_old_station_unit_0823==follow.original_station_unit
      and child.reversal_followup_0911
      and child.reversal_followup_0911.root_writ_id==root.id
      and child.reversal_followup_0911.original_priest==follow.original_priest
      and child.reversal_followup_0911.magos_station_unit
        ==follow.magos_station_unit
      and valid(magos and magos.station) and valid(magos.priest)
      and tp.station_reversal_followup_0911
      and tp.station_reversal_followup_0911[follow.magos_station_unit]
        ==root.id
      and domain(intermediate.station.force,magos.station.force)
      and domain(intermediate.station.surface,magos.station.surface)) then
    return true,"junior-followup-original-writ-invalid"
  end
  local _,reason=M.service(magos,api)
  -- Persistent bounded diagnostics; no evidence or item is credited here.
  root.reversal_junior_0920_last_reason=reason
  root.reversal_junior_0920_last_tick=game and game.tick
  return true,reason
end
return M
