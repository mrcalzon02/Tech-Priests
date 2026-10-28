-- 0943: reserve the second original Junior peer's real Factorio ghost only
-- after the first Junior is physically built and paired to its original priest.
-- No inventory transfer, ghost completion, station creation or priest claim.
local Depot=require("scripts.core.station_starvation_depot_0852")
local Cargo=require("scripts.core.station_cargo_0824")
local Junior=require("scripts.core.station_starvation_junior_0919")
local M={}
local ITEM="junior-cogitator-station"
local function valid(e) return e and e.valid end
local function dist2(a,b)
  if not(a and b) then return math.huge end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
local function same(a,b)
  return a and b and (a==b or (type(a.index)=="number"
    and type(b.index)=="number" and a.index==b.index))
end
local function count(inv)
  if not(valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function()return inv.get_item_count(ITEM) end)
  return ok and type(n)=="number" and n or nil
end
function M.service(magos,root,worker,api)
  local tp=storage and storage.tech_priests
  local first=type(root)=="table" and root.reversal_stage_0853
  local second=type(root)=="table" and root.reversal_stage_0851
  local step=type(root)=="table" and root.reversal_junior_0919
  local child=step and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[step.child_writ_id]
  local intermediate=first and tp and tp.pairs_by_priest
    and tp.pairs_by_priest[first.worker_priest_unit]
  local original=second and tp and tp.pairs_by_priest
    and tp.pairs_by_priest[second.leaf_priest_unit]
  local lease=second and tp and tp.station_relocation_0823
    and tp.station_relocation_0823[second.leaf_station_unit]
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local reserved=type(root)=="table" and root.reversal_second_junior_0943
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and tp.station_expansion_0256 and tp.station_expansion_by_worker_0256
      and valid(magos and magos.station) and valid(magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete"
      and root.worker_station_unit==magos.station.unit_number
      and type(root.blocked_item)=="string"
      and root.blocked_item:sub(1,9)=="resource:"
      and first and first.reversal_stage_index==2
      and first.phase=="in-magos-depot" and first.station_item==ITEM
      and second and (second.reversal_stage_index==nil
        or second.reversal_stage_index==1)
      and second.id=="reversal-leaf:"..tostring(root.id)..":"
        ..tostring(second.leaf_station_unit)
      and second.phase=="in-magos-depot" and second.station_item==ITEM
      and second.worker_station_unit==first.leaf_station_unit
      and second.worker_priest_unit==first.leaf_priest_unit
      and second.leaf_station_unit~=first.leaf_station_unit
      and step and step.status=="ghost-reserved"
      and child and child.status=="complete"
      and child.reversal_junior_0919
      and child.reversal_junior_0919.root_writ_id==root.id
      and child.reversal_junior_0919.stage_id==first.id
      and child.reversal_junior_0919.original_priest==first.leaf_priest_unit
      and child.relocation_old_station_unit_0823==first.leaf_station_unit
      and child.ghost_unit==step.ghost_unit
      and type(child.completed_tick)=="number"
      and type(game and game.tick)=="number"
      and game.tick>=child.completed_tick+120
      and valid(worker and worker.station) and valid(worker.priest)
      and worker.station.name==ITEM
      and worker.station.unit_number~=first.leaf_station_unit
      and worker.priest.unit_number==first.leaf_priest_unit
      and tp.pairs_by_station[worker.station.unit_number]==worker
      and tp.pairs_by_priest[first.leaf_priest_unit]==worker
      and tp.pairs_by_station[first.leaf_station_unit]==nil
      and tp.pairs_by_station[second.leaf_station_unit]==nil
      and tp.station_by_priest
      and tp.station_by_priest[first.leaf_priest_unit]
        ==worker.station.unit_number
      and dist2(worker.station.position,child.ghost_position)<0.01
      and intermediate and valid(intermediate.station)
      and valid(intermediate.priest)
      and intermediate.priest.unit_number==first.worker_priest_unit
      and child.worker_station_unit==intermediate.station.unit_number
      and h and type(h.is_direct_subordinate)=="function"
      and h.is_direct_subordinate(intermediate,worker)==true
      and original and valid(original.priest)
      and original.priest.unit_number==second.leaf_priest_unit
      and lease and lease.status=="staged"
      and lease.old_unit==second.leaf_station_unit
      and lease.priest_unit==second.leaf_priest_unit
      and lease.priest==original.priest
      and not worker.relocation_pending_0823
      and not Cargo.has_record(child)
      and (not tp.station_expansion_by_worker_0256[worker.station.unit_number]
        or (reserved and reserved.child_writ_id
          ==tp.station_expansion_by_worker_0256[worker.station.unit_number]))
      and same(worker.station.force,magos.station.force)
      and same(worker.station.surface,magos.station.surface)
      and mission and mission.target
      and type(api)=="table" and type(api.rank)=="function"
      and type(api.radius)=="function" and api.rank(worker)==1) then
    return false,"second-junior-original-physical-chain-not-certified"
  end
  local first_entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first.id]
  local second_entry,second_why=Depot.get_staged(magos,second)
  if not(first_entry and first_entry.status=="outbound"
      and valid(first_entry.inventory) and count(first_entry.inventory)==0
      and second_entry and valid(second_entry.inventory)
      and second_entry.inventory~=first_entry.inventory
      and count(second_entry.inventory)==1) then
    return true,"second-junior-independent-physical-depot-invalid:"
      ..tostring(second_why)
  end
  if reserved then
    local rec=tp.station_expansion_0256[reserved.child_writ_id]
    local ghost=rec and type(api.find_ghost)=="function"
      and api.find_ghost(worker,rec)
    if reserved.status=="ghost-reserved" and rec and rec.status=="active"
        and rec.reversal_second_junior_0943
        and rec.reversal_second_junior_0943.root_writ_id==root.id
        and rec.reversal_second_junior_0943.stage_id==second.id
        and rec.worker_station_unit==worker.station.unit_number
        and rec.requester_station_unit==worker.station.unit_number
        and rec.ghost_unit==reserved.ghost_unit
        and rec.station_item==ITEM and rec.station_entity==ITEM
        and valid(ghost) and ghost.unit_number==rec.ghost_unit
        and ghost.name=="entity-ghost" and ghost.ghost_name==ITEM
        and same(ghost.force,worker.station.force)
        and same(ghost.surface,worker.station.surface)
        and dist2(ghost.position,rec.ghost_position)<0.01 then
      return true,"second-junior-original-real-ghost-still-reserved"
    end
    return true,"second-junior-reserved-ghost-quarantined"
  end
  if not(type(api.find_site)=="function"
      and type(api.create_ghost)=="function"
      and type(api.find_ghost)=="function") then
    return true,"second-junior-physical-placement-api-unavailable"
  end
  local radius=api.radius(worker)
  local site=api.find_site(worker,ITEM,mission.target)
  if not(type(radius)=="number" and radius>=4 and site
      and dist2(site,worker.station.position)<=radius*radius
      and dist2(site,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return true,"second-junior-no-forward-buildable-site"
  end
  local ghost,why=api.create_ghost(worker,ITEM,site)
  if not valid(ghost) then
    return true,"second-junior-physical-ghost-refused:"..tostring(why)
  end
  local observed,route=Junior.reobserve_created_ghost_0927(
    worker,ghost,ITEM,api)
  local actual=ghost.position
  if not(valid(observed) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and type(ghost.unit_number)=="number"
      and observed.unit_number==ghost.unit_number
      and same(ghost.force,worker.station.force)
      and same(ghost.surface,worker.station.surface)
      and dist2(actual,site)<=2.25
      and dist2(actual,observed.position)<0.01
      and dist2(actual,worker.station.position)<=radius*radius
      and dist2(actual,mission.target)
        <dist2(worker.station.position,mission.target)) then
    root.reversal_second_junior_0943={status="quarantined",
      ghost_unit=ghost.unit_number,reason="second-ghost-identity:"..tostring(route)}
    return true,"second-junior-created-ghost-quarantined"
  end
  local id=tp.station_expansion_next_id_0256
  if not(type(id)=="number" and not tp.station_expansion_0256[id]) then
    root.reversal_second_junior_0943={status="quarantined",
      ghost_unit=ghost.unit_number,reason="second-child-writ-id-unavailable"}
    return true,"second-junior-child-writ-quarantined"
  end
  local rec={id=id,status="active",
    requester_station_unit=worker.station.unit_number,requester_rank=1,
    required_worker_rank=1,worker_station_unit=worker.station.unit_number,
    commander_bootstrap=true,station_item=ITEM,station_entity=ITEM,
    blocked_item=root.blocked_item,ghost_unit=ghost.unit_number,
    ghost_position={x=actual.x,y=actual.y},
    phase="reversal-second-junior-awaiting-physical-depot-pickup",
    created_tick=game.tick,updated_tick=game.tick,
    reversal_second_junior_0943={root_writ_id=root.id,stage_id=second.id,
      original_priest=second.leaf_priest_unit,
      original_first_junior_priest=worker.priest.unit_number,
      magos_station_unit=magos.station.unit_number}}
  tp.station_expansion_next_id_0256=id+1
  tp.station_expansion_0256[id]=rec
  tp.station_expansion_by_worker_0256[worker.station.unit_number]=id
  worker.station_expansion_0256=rec
  root.reversal_second_junior_0943={status="ghost-reserved",
    child_writ_id=id,ghost_unit=ghost.unit_number,created_tick=game.tick}
  return true,"reversal-second-junior-real-ghost-reserved"
end

-- 0944: the original first Junior walks to the original Magos and
-- physically withdraws only the independent second-Junior 0851 item.
-- The same engine-owned 0824 cargo is retained across reload. No build,
-- transit completion, priest claim, or inventory credit is authorized here.
function M.service_pickup_0944(worker,child,api)
  local tp=storage and storage.tech_priests
  local follow=type(child)=="table" and child.reversal_second_junior_0943
  local root=follow and tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local step=root and root.reversal_second_junior_0943
  local stage=root and root.reversal_stage_0851
  local first=root and root.reversal_stage_0853
  local first_step=root and root.reversal_junior_0919
  local first_child=first_step and tp.station_expansion_0256
    and tp.station_expansion_0256[first_step.child_writ_id]
  local magos=follow and tp.pairs_by_station
    and tp.pairs_by_station[follow.magos_station_unit]
  local original=stage and tp.pairs_by_priest
    and tp.pairs_by_priest[stage.leaf_priest_unit]
  local lease=stage and tp.station_relocation_0823
    and tp.station_relocation_0823[stage.leaf_station_unit]
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and valid(worker and worker.station) and valid(worker.priest)
      and worker.station.name==ITEM
      and tp.pairs_by_station[worker.station.unit_number]==worker
      and tp.pairs_by_priest[worker.priest.unit_number]==worker
      and valid(magos and magos.station) and valid(magos.priest)
      and tp.pairs_by_station[magos.station.unit_number]==magos
      and root and root.status=="complete"
      and root.worker_station_unit==magos.station.unit_number
      and type(root.blocked_item)=="string"
      and root.blocked_item:sub(1,9)=="resource:"
      and step and step.status=="ghost-reserved"
      and step.child_writ_id==child.id and step.ghost_unit==child.ghost_unit
      and child.status=="active"
      and child.station_item==ITEM and child.station_entity==ITEM
      and child.worker_station_unit==worker.station.unit_number
      and child.requester_station_unit==worker.station.unit_number
      and tp.station_expansion_by_worker_0256
      and tp.station_expansion_by_worker_0256[worker.station.unit_number]==child.id
      and follow.stage_id==stage.id
      and follow.original_priest==stage.leaf_priest_unit
      and follow.original_first_junior_priest==worker.priest.unit_number
      and stage.id=="reversal-leaf:"..tostring(root.id)..":"
        ..tostring(stage.leaf_station_unit)
      and stage.phase=="in-magos-depot" and stage.station_item==ITEM
      and stage.worker_priest_unit==worker.priest.unit_number
      and stage.worker_station_unit~=worker.station.unit_number
      and first and first.reversal_stage_index==2
      and first.leaf_priest_unit==worker.priest.unit_number
      and first_step and first_step.status=="ghost-reserved"
      and first_child and first_child.status=="complete"
      and first_child.relocation_old_station_unit_0823==first.leaf_station_unit
      and first_child.ghost_position
      and dist2(first_child.ghost_position,worker.station.position)<0.01
      and tp.pairs_by_station[first.leaf_station_unit]==nil
      and tp.pairs_by_station[stage.leaf_station_unit]==nil
      and original and valid(original.priest)
      and original.priest.unit_number==stage.leaf_priest_unit
      and lease and lease.status=="staged"
      and lease.priest==original.priest
      and lease.old_unit==stage.leaf_station_unit
      and lease.priest_unit==stage.leaf_priest_unit
      and same(worker.station.force,magos.station.force)
      and same(worker.station.surface,magos.station.surface)
      and type(api)=="table" and type(api.find_ghost)=="function"
      and type(api.radius)=="function" and type(api.rank)=="function"
      and api.rank(worker)==1) then
    return true,"second-junior-pickup-original-writ-or-priest-invalid"
  end
  local ghost=api.find_ghost(worker,child)
  local radius=api.radius(worker)
  local mission=magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not(valid(ghost) and ghost.name=="entity-ghost"
      and ghost.ghost_name==ITEM and ghost.unit_number==child.ghost_unit
      and same(ghost.force,worker.station.force)
      and same(ghost.surface,worker.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01
      and type(radius)=="number" and radius>=4
      and dist2(ghost.position,worker.station.position)<=radius*radius
      and mission and mission.target
      and dist2(ghost.position,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return true,"second-junior-pickup-original-ghost-or-direction-invalid"
  end
  local first_entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[first.id]
  local second_entry=tp.station_reversal_depot_0852
    and tp.station_reversal_depot_0852[stage.id]
  if not(first_entry and first_entry.status=="outbound"
      and valid(first_entry.inventory)
      and count(first_entry.inventory)==0
      and second_entry and valid(second_entry.inventory)
      and second_entry.inventory~=first_entry.inventory
      and second_entry.record_id==stage.id
      and second_entry.item==ITEM
      and second_entry.magos_station_unit==magos.station.unit_number
      and second_entry.magos_priest_unit==magos.priest.unit_number) then
    return true,"second-junior-pickup-independent-depots-invalid"
  end
  if Cargo.has_record(child) then
    local carried,why=Cargo.get(worker,child)
    if not(carried and carried.status=="carrying"
        and second_entry.status=="outbound"
        and valid(carried.inventory)
        and carried.inventory~=first_entry.inventory
        and carried.inventory~=second_entry.inventory
        and count(second_entry.inventory)==0
        and count(carried.inventory)==1) then
      return true,"second-junior-pickup-existing-cargo-quarantined:"..tostring(why)
    end
    local seen,reason=Cargo.observe_carrier(worker,child)
    if not seen then
      return true,"second-junior-pickup-carrier-unobservable:"..tostring(reason)
    end
    return true,"reversal-second-junior-real-item-carried-from-magos"
  end
  local staged,why=Depot.get_staged(magos,stage)
  if not(staged==second_entry and second_entry.status=="stored"
      and count(second_entry.inventory)==1) then
    return true,"second-junior-pickup-pre-debit-custody-invalid:"..tostring(why)
  end
  local now=game and game.tick
  if not(type(now)=="number" and type(step.created_tick)=="number"
      and now>=step.created_tick+120) then
    return true,"second-junior-pickup-ghost-escrow-pending"
  end
  follow.pickup_started_tick=follow.pickup_started_tick or now
  if now<follow.pickup_started_tick
      or now-follow.pickup_started_tick>7200 then
    return true,"second-junior-pickup-clock-or-physical-travel-timeout"
  end
  if worker.mode~="idle" or worker.dead or worker.recalling
      or worker.deploying then
    return true,"second-junior-pickup-awaiting-existing-duty"
  end
  for _,key in ipairs({"active_task","current_task","construction_task",
      "build_task","repair_target","combat_target","consecration_target",
      "direct_acquisition_task_0336","active_acquisition_0333",
      "inventory_transfer_custody_0687","station_crafting_task_0337"}) do
    if worker[key]~=nil and worker[key]~=false then
      return true,"second-junior-pickup-awaiting-existing-duty"
    end
  end
  local probe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  if type(probe)=="function" then
    local ok,status=pcall(probe,worker)
    if not ok or not(type(status)=="table"
        and (status.priority=="idle" or status.priority=="invalid")) then
      return true,"second-junior-pickup-awaiting-existing-duty"
    end
  end
  if dist2(worker.priest.position,magos.station.position)>25 then
    if not(type(api.request)=="function" and defines
        and defines.distraction) then
      return true,"second-junior-pickup-movement-authority-unavailable"
    end
    if type(follow.last_pickup_command_tick)=="number"
        and now-follow.last_pickup_command_tick>=0
        and now-follow.last_pickup_command_tick<60 then
      return true,"reversal-second-junior-first-priest-walking-to-magos"
    end
    local ok,accepted,reason=pcall(api.request,worker,magos.station.position,
      "station-recovery-second-junior-depot-0944",{
        owner="station-recovery-second-junior-0944",
        priority=70,ttl=600,long_action=true,radius=2,
        distraction=defines.distraction.none})
    if not ok or accepted~=true then
      follow.pickup_command_refusal_0944=tostring(ok and reason or accepted)
      return true,"second-junior-pickup-physical-command-refused"
    end
    follow.pickup_command_refusal_0944=nil
    follow.last_pickup_command_tick=now
    return true,"reversal-second-junior-first-priest-walking-to-magos"
  end
  local picked,pickup_why=Cargo.pickup(
    worker,child,second_entry.inventory,magos.station)
  local carried,carry_why=Cargo.get(worker,child)
  if not(picked and carried and carried.status=="carrying"
      and count(first_entry.inventory)==0
      and count(second_entry.inventory)==0
      and count(carried.inventory)==1) then
    return true,"second-junior-pickup-physical-delta-unverified:"
      ..tostring(pickup_why)..":"..tostring(carry_why)
  end
  second_entry.status="outbound"
  follow.picked_tick=now
  return true,"reversal-second-junior-real-item-carried-from-magos"
end
return M
