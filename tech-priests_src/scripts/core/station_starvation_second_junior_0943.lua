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
return M
