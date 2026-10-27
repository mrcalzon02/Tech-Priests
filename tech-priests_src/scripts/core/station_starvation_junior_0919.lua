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
  local observed=actual and api.find_ghost(worker,{
    station_item=ITEM,station_entity=ITEM,ghost_unit=ghost.unit_number,
    ghost_position={x=actual.x,y=actual.y}})
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
    root.reversal_junior_0919={status="quarantined",
      reason="junior-created-ghost-geometry-or-identity-invalid",
      ghost_unit=ghost.unit_number}
    return true,"junior-created-ghost-quarantined"
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
