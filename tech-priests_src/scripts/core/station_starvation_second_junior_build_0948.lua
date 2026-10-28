-- 0948: authorize native 0256 construction of the SECOND original Junior
-- only after the same physically carried 0824 item reaches its exact peer
-- ghost. The 0823 lifecycle lease preserves the original living priest.
local Transit=require("scripts.core.station_starvation_second_junior_0943")
local Cargo=require("scripts.core.station_cargo_0824")
local Relocation=require("scripts.core.station_relocation_0823")
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
  local ok,n=pcall(function() return inv.get_item_count(ITEM) end)
  return ok and type(n)=="number" and n or nil
end

-- Read-only authority check. Called on EVERY post-authorization 0256 tick,
-- including after reload and after native station creation. A nearby foreign
-- station, changed priest or ambiguous inventory never spends the cargo.
function M.verify(worker,child,api,ghost,built)
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
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local now=game and game.tick
  if not(tp and tp.pairs_by_station and tp.pairs_by_priest
      and tp.station_expansion_0256 and tp.station_expansion_by_worker_0256
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
      and child.status=="active" and child.station_item==ITEM
      and child.station_entity==ITEM
      and child.requester_rank==1 and child.required_worker_rank==1
      and child.worker_station_unit==worker.station.unit_number
      and child.requester_station_unit==worker.station.unit_number
      and tp.station_expansion_by_worker_0256[worker.station.unit_number]==child.id
      and stage and stage.id==follow.stage_id
      and stage.phase=="in-magos-depot" and stage.station_item==ITEM
      and stage.worker_priest_unit==worker.priest.unit_number
      and follow.original_priest==stage.leaf_priest_unit
      and follow.original_first_junior_priest==worker.priest.unit_number
      and first and first.reversal_stage_index==2
      and first.leaf_priest_unit==worker.priest.unit_number
      and first_step and first_step.status=="ghost-reserved"
      and first_child and first_child.status=="complete"
      and first_child.relocation_old_station_unit_0823==first.leaf_station_unit
      and dist2(first_child.ghost_position,worker.station.position)<0.01
      and tp.pairs_by_station[first.leaf_station_unit]==nil
      and tp.pairs_by_station[stage.leaf_station_unit]==nil
      and original and valid(original.priest)
      and original.priest.unit_number==stage.leaf_priest_unit
      and tp.pairs_by_priest[stage.leaf_priest_unit]==original
      and type(now)=="number"
      and type(follow.build_authorized_tick)=="number"
      and type(follow.arrived_tick)=="number"
      and type(follow.picked_tick)=="number"
      and type(follow.transit_started_tick)=="number"
      and type(follow.transit_last_command_tick)=="number"
      and follow.build_authorized_tick>=follow.arrived_tick+120
      and follow.arrived_tick>=follow.picked_tick+120
      and follow.arrived_tick>=follow.transit_last_command_tick
      and follow.transit_last_command_tick>=follow.transit_started_tick
      and now>=follow.build_authorized_tick
      and now-follow.transit_started_tick<=7200
      and follow.build_ghost_unit==child.ghost_unit
      and child.relocation_old_station_unit_0823==stage.leaf_station_unit
      and same(worker.station.force,magos.station.force)
      and same(worker.station.surface,magos.station.surface)
      and type(api)=="table" and type(api.rank)=="function"
      and type(api.radius)=="function" and api.rank(worker)==1
      and mission and mission.target) then
    return false,"second-junior-build-original-writ-priest-or-clock-invalid"
  end
  local radius=api.radius(worker)
  if not(type(radius)=="number" and radius>=4
      and dist2(child.ghost_position,worker.station.position)<=radius*radius
      and dist2(child.ghost_position,mission.target)
        <dist2(worker.station.position,mission.target)) then
    return false,"second-junior-build-peer-radius-or-natural-target-invalid"
  end
  local depots=tp.station_reversal_depot_0852
  local first_entry=depots and depots[first.id]
  local second_entry=depots and depots[stage.id]
  local cargo,why=Cargo.get(worker,child)
  if not(first_entry and first_entry.status=="outbound"
      and valid(first_entry.inventory) and count(first_entry.inventory)==0
      and second_entry and second_entry.status=="outbound"
      and second_entry.record_id==stage.id and second_entry.item==ITEM
      and second_entry.magos_station_unit==magos.station.unit_number
      and second_entry.magos_priest_unit==magos.priest.unit_number
      and valid(second_entry.inventory)
      and second_entry.inventory~=first_entry.inventory
      and count(second_entry.inventory)==0
      and cargo and valid(cargo.inventory)
      and cargo.inventory~=first_entry.inventory
      and cargo.inventory~=second_entry.inventory
      and ((cargo.status=="carrying" and count(cargo.inventory)==1)
        or (cargo.status=="building" and count(cargo.inventory)==0))) then
    return false,"second-junior-build-real-inventory-custody-invalid:"..tostring(why)
  end
  local same_built=valid(built) and built.name==ITEM
    and same(built.force,worker.station.force)
    and same(built.surface,worker.station.surface)
    and dist2(built.position,child.ghost_position)<0.01
  if valid(built) and not same_built then
    return false,"second-junior-build-foreign-constructed-station"
  end
  if not same_built and not(valid(ghost)
      and ghost.name=="entity-ghost" and ghost.ghost_name==ITEM
      and ghost.unit_number==child.ghost_unit
      and same(ghost.force,worker.station.force)
      and same(ghost.surface,worker.station.surface)
      and dist2(ghost.position,child.ghost_position)<0.01) then
    return false,"second-junior-build-original-peer-ghost-invalid"
  end
  local lease=Relocation.pending_for_record(child)
  if lease then
    if not(lease.status==(cargo.status=="building" and "building" or "mined")
        and lease.reversal_leaf_0851==true
        and lease.old_unit==stage.leaf_station_unit
        and lease.rec_id==child.id
        and lease.priest==original.priest and lease.pair==original
        and lease.priest_unit==stage.leaf_priest_unit
        and lease.worker_unit==worker.station.unit_number
        and lease.item==ITEM and not valid(lease.old_station)
        and dist2(lease.target,child.ghost_position)<0.01) then
      return false,"second-junior-build-original-priest-lease-invalid"
    end
  elseif not(same_built and cargo.status=="building"
      and original.station==built
      and tp.pairs_by_station[built.unit_number]==original) then
    return false,"second-junior-build-original-priest-not-reattached"
  end
  if cargo.status=="carrying" and same_built then
    return false,"second-junior-build-foreign-station-before-item-debit"
  end
  return true,"original-second-junior-native-build-custody-verified"
end

-- Arrival is escrowed a second time before the original 0851 priest lease
-- can be armed. No item is debited here; 0256/0824 perform the real build.
function M.arm(worker,child,api)
  local follow=type(child)=="table" and child.reversal_second_junior_0943
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
      and now-follow.transit_started_tick<=7200
      and type(api)=="table" and type(api.rank)=="function"
      and api.rank(worker)==1) then
    return true,"second-junior-build-arrival-or-clock-not-certified"
  end
  local _,reason=Transit.service_second_junior_outward_transit_0947(
    worker,child,api)
  if reason~="reversal-second-junior-real-item-arrived-at-ghost"
      or follow.arrived_tick>now-120 then
    return true,"second-junior-build-transit-custody-invalid:"..tostring(reason)
  end
  local tp=storage and storage.tech_priests
  local root=tp and tp.station_expansion_0256
    and tp.station_expansion_0256[follow.root_writ_id]
  local stage=root and root.reversal_stage_0851
  local ghost=type(api.find_ghost)=="function"
    and api.find_ghost(worker,child)
  if not(valid(ghost) and ghost.unit_number==child.ghost_unit
      and valid(worker and worker.priest)
      and dist2(ghost.position,worker.priest.position)<=25) then
    return true,"second-junior-build-exact-ghost-or-reach-invalid"
  end
  local armed,why=Relocation.arm_staged_second_junior_0948(
    worker,child,stage,ghost)
  if not armed then
    return true,"second-junior-build-original-priest-lease-refused:"..tostring(why)
  end
  follow.build_authorized_tick=now
  follow.build_ghost_unit=ghost.unit_number
  return true,"reversal-second-junior-physical-build-authorized"
end
return M
