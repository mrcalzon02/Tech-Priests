-- Method I: mine a natural ore entity into an engine-owned courier inventory,
-- then physically carry its exact product to the immediate upstream station.
-- Every later hop must separately pick up and deliver the same real item.
-- Mining machinery and full engine acceptance remain separate gates.
local Chain=require("scripts.core.resource_station_chain_0820")
local M={version="0.1.674-dev.0841",reach_sq=25,interval=60}
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function dist2(a,b)
  if not (a and b) then return math.huge end
  local x,y=a.x-b.x,a.y-b.y
  return x*x+y*y
end
local function pair(id)
  local tp=storage and storage.tech_priests
  local pairs=tp and tp.pairs_by_station or {}
  return pairs[id] or pairs[tostring(id)]
end
local function count(inv,item)
  if not (valid(inv) and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and tonumber(n) or nil
end
local function blocked(state,reason)
  state.phase="custody-blocked"
  state.last_reason=reason
  state.updated_tick=now()
  return false,reason
end
local function move(priest,pos)
  if not (type(_G.issue_priest_command)=="function"
      and defines and defines.command and defines.distraction) then
    return false,"physical-movement-unavailable"
  end
  local ok=pcall(_G.issue_priest_command,priest,{
    type=defines.command.go_to_location,destination=pos,
    radius=2,distraction=defines.distraction.none})
  return ok,ok and "physical-movement-commanded" or "movement-command-refused"
end
local function ore_product_is_exact(ore,item)
  if not (valid(ore) and ore.type=="resource"
      and prototypes and prototypes.item and prototypes.item[item]) then
    return false
  end
  local ok,properties=pcall(function()
    return ore.prototype and ore.prototype.mineable_properties
  end)
  if not (ok and properties and properties.products) then return false end
  local found=false
  for _,product in pairs(properties.products) do
    if product.type=="fluid" or product.name~=item then return false end
    found=true
  end
  return found
end
local function natural_ore(source,mission)
  local scans=rawget(_G,"TechPriestsScanRouting0610")
  if not (scans and type(scans.find_entities)=="function") then
    return nil,"canonical-resource-scan-unavailable"
  end
  local pos=mission.target
  local filter={
    name=mission.resource_name,type="resource",
    area={{pos.x-4,pos.y-4},{pos.x+4,pos.y+4}},limit=8,
  }
  local radius=type(Chain.operating_radius)=="function"
    and Chain.operating_radius(source)
    or (tonumber(source.radius or source.base_radius) or 20)
  local last_reason="natural-ore-not-found"
  local function eligible(entities)
    for _,ore in ipairs(entities or {}) do
      if valid(ore) and ore.name==mission.resource_name
          and ore.surface==source.station.surface
          and tonumber(ore.amount) and ore.amount>0 then
        if dist2(source.station.position,ore.position)>radius*radius then
          last_reason="natural-ore-outside-station-radius"
        elseif not ore_product_is_exact(ore,mission.need) then
          last_reason="natural-ore-product-not-exact"
        else
          return ore
        end
      end
    end
    return nil
  end
  local ok,found=pcall(scans.find_entities,source.station.surface,filter,
    {category="resource",limit=8})
  if not ok then return nil,"resource-scan-failed" end
  local ore=eligible(found)
  if ore then return ore end
  -- The 0579 area index is an advisory cache, not physical ore custody.
  -- A remote patch generated after indexing can be absent from its cache.
  -- Verify the same bounded eight-tile target through Factorio itself before
  -- declaring a visible, genuinely mineable natural deposit missing.
  local surface=source.station.surface
  if type(surface.find_entities_filtered)=="function" then
    local direct_ok,direct=pcall(function()
      return surface.find_entities_filtered(filter)
    end)
    if direct_ok then
      ore=eligible(direct)
      if ore then return ore end
    end
  end
  return nil,last_reason
end
local function station_inventory(station)
  local get=rawget(_G,"get_station_inventory")
  if type(get)~="function" then return nil end
  local ok,inv=pcall(get,station)
  if ok and valid(inv) and type(inv.insert)=="function"
      and type(inv.get_insertable_count)=="function" then return inv end
end
local function available_for_courier(worker)
  -- A real 0647 recipe wait can leave the pair mode non-idle despite having
  -- no active executable work. The ore courier is meant to supply the very
  -- absent material; treating that *mode label alone* as a perpetual live
  -- duty deadlocks the remote resource objective. Preserve the complete
  -- recipe request for later resumption; never waive any active task or held
  -- physical custody (checked independently below).
  local pending=worker.infrastructure_recipe_request_0647
  local deferred_material=worker.mode=="infrastructure-material-acquisition-0647"
    and type(pending)=="table" and type(pending.missing)=="string"
    and #pending.missing>0
  if (worker.mode and worker.mode~="idle" and not deferred_material)
      or worker.active_task or worker.current_task
      or worker.emergency_craft or worker.active_acquisition_0333
      or worker.direct_acquisition_task_0336
      or worker.inventory_transfer_custody_0687
      or worker.construction_task_0338 or worker.construction_task_0340 then
    return false,"upstream-priest-has-existing-duty"
  end
  local expansion=worker.station_expansion_0256
  -- An old, successfully completed station expansion is history, not an
  -- active physical custody claim. An unfinished/failed/unknown expansion
  -- must still retain ownership until its station item is accounted for.
  if worker.direct_acquisition_custody_0513
      or worker.construction_custody_0338
      or worker.machine_logistics_custody_0528
      or worker.emergency_facility_feed_custody_0357
      or worker.repair_pack_custody_0516
      or worker.consecration_refund_custody_0515
      or (expansion and expansion.status~="complete") then
    return false,"upstream-priest-has-existing-custody"
  end
  return true
end
function M.worker_reserved(worker)
  if not (worker and valid(worker.station) and valid(worker.priest)) then return false end
  local assignment=worker.remote_resource_assignment_0820
  local magos=assignment and pair(assignment.root_station_unit)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local state=mission and mission.return_courier_0837
  if not (mission and mission.status=="reached-resource" and state) then
    return false
  end
  -- A waiting courier reserves only FUTURE scheduling. Existing tasks and
  -- physical custody must finish normally before the priest may move.
  if state.phase=="awaiting-terminal-duty"
      or (state.phase=="first-hop-delivered"
          and state.pending_upstream_station_unit) then
    local route=Chain.return_route(magos)
    if not route then return false end
    if state.phase=="awaiting-terminal-duty" then
      return route[1]==worker.station.unit_number
        and state.source_station_unit==worker.station.unit_number
        and state.carrier_priest_unit==worker.priest.unit_number
    end
    local hop=state.hop_index or 1
    return route[hop]==state.source_station_unit
      and route[hop+1]==worker.station.unit_number
      and state.pending_upstream_station_unit==worker.station.unit_number
      and state.pending_upstream_priest_unit==worker.priest.unit_number
  end
  return state.phase~="first-hop-delivered" and state.phase~="magos-delivered"
    and state.source_station_unit==worker.station.unit_number
    and state.carrier_priest_unit==worker.priest.unit_number
end
function M.service(magos)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  if not (mission and mission.status=="reached-resource"
      and valid(magos.station) and valid(magos.priest)
      and magos.station.unit_number==mission.root_station_unit) then
    return false,"resource-route-not-ready"
  end
  local route,why=Chain.return_route(magos)
  if not route then
    -- A pending reservation has no material custody; do not indefinitely
    -- block scheduling if the physical route disappears before dispatch.
    local pending=mission.return_courier_0837
    if pending and pending.phase=="awaiting-terminal-duty"
        and pending.inventory==nil then
      mission.return_courier_0837=nil
    end
    return false,why
  end
  if #route<2 then return false,"no-physical-upstream-hop" end
  local state=mission.return_courier_0837
  if not state then
    local terminal=pair(route[1])
    if not (terminal and valid(terminal.priest)
        and terminal.priest.unit_number) then
      return false,"terminal-priest-missing"
    end
    -- Persist a future-work reservation before waiting for an existing duty.
    -- The governor may stop assigning NEW work, but this code never cancels
    -- an active task, takes its inventory, or moves its priest.
    state={
      phase="awaiting-terminal-duty",source_station_unit=route[1],
      destination_station_unit=route[2],
      carrier_priest_unit=terminal.priest.unit_number,
      item=mission.need,quantity=0,
      started_tick=now(),updated_tick=now(),next_tick=now(),
    }
    mission.return_courier_0837=state
  end
  if state.phase=="awaiting-terminal-duty" then
    local terminal=pair(route[1])
    if not (terminal and valid(terminal.station) and valid(terminal.priest)
        and terminal.priest.unit_number==state.carrier_priest_unit
        and terminal.station.unit_number==state.source_station_unit) then
      -- No material was acquired; release this stale future-work lease.
      mission.return_courier_0837=nil
      return false,"terminal-priest-changed-before-courier"
    end
    local free,reason=available_for_courier(terminal)
    if not free then
      return false,reason=="upstream-priest-has-existing-duty"
        and "terminal-priest-has-existing-duty"
        or "terminal-priest-has-existing-custody"
    end
    state.phase="to-natural-ore"
    state.next_tick=now()
    state.updated_tick=now()
  end
  if state.phase=="magos-delivered" then
    return false,"natural-ore-already-delivered-to-magos"
  end
  if state.phase=="custody-blocked" then
    return false,state.last_reason or "custody-blocked"
  end
  local hop=state.hop_index or 1 -- prior first-hop saves
  if hop<1 or hop>=#route or hop~=math.floor(hop)
      or state.source_station_unit~=route[hop]
      or state.destination_station_unit~=route[hop+1]
      or state.item~=mission.need then
    return blocked(state,"return-route-changed-during-custody")
  end
  if state.phase=="first-hop-delivered" then
    -- A committed deposit cannot be debited twice. The next paired priest
    -- must take one real item from its own station, never from a remote child.
    if state.delivered_station_unit~=route[hop+1]
        or state.delivered_count~=1 or state.inventory~=nil then
      return blocked(state,"prior-upstream-delivery-not-verifiable")
    end
    local next_hop=hop+1
    if next_hop>=#route then
      return blocked(state,"delivered-phase-at-terminal-route")
    end
    local next_worker=pair(route[next_hop])
    if not (next_worker and valid(next_worker.station)
        and valid(next_worker.priest)
        and next_worker.priest.unit_number) then
      return false,"next-upstream-priest-unavailable"
    end
    -- Claim the next worker for FUTURE scheduling while its current duty
    -- completes. Never withdraw the ore or move the priest until idle.
    state.pending_upstream_station_unit=next_worker.station.unit_number
    state.pending_upstream_priest_unit=next_worker.priest.unit_number
    local free,reason=available_for_courier(next_worker)
    if not free then return false,reason end
    local source_inv=station_inventory(next_worker.station)
    if not source_inv or (count(source_inv,state.item) or 0)<1 then
      return false,"previously-delivered-ore-not-in-upstream-storage"
    end
    state.pending_upstream_station_unit=nil
    state.pending_upstream_priest_unit=nil
    state.hop_index=next_hop
    state.source_station_unit=route[next_hop]
    state.destination_station_unit=route[next_hop+1]
    state.carrier_priest_unit=next_worker.priest.unit_number
    state.phase="to-upstream-pickup"
    state.next_tick=now()
    state.updated_tick=now()
    state.last_reason="next-upstream-priest-reserved-for-local-pickup"
    return true,"next-physical-upstream-hop-reserved"
  end
  local source,dest=pair(state.source_station_unit),pair(state.destination_station_unit)
  if not (source and dest and valid(source.station) and valid(source.priest)
      and valid(dest.station) and valid(dest.priest)
      and source.priest.unit_number==state.carrier_priest_unit
      and source.station.surface==dest.station.surface
      and source.station.force==dest.station.force
      and source.station.unit_number==route[hop]
      and (hop~=1 or source.station.unit_number==mission.current_station_unit)) then
    return blocked(state,"physical-route-or-carrier-identity-changed")
  end
  if now()<(state.next_tick or 0) then return false,"courier-interval" end
  state.next_tick=now()+M.interval
  state.updated_tick=now()
  if state.phase=="to-upstream-pickup" then
    if dist2(source.priest.position,source.station.position)>M.reach_sq then
      local ok,movement=move(source.priest,source.station.position)
      return false,ok and "walking-to-upstream-pickup" or movement
    end
    local source_inv=station_inventory(source.station)
    if not source_inv then return false,"upstream-pickup-inventory-unavailable" end
    local before=count(source_inv,state.item)
    if not before or before<1 then
      return false,"previously-delivered-ore-not-in-upstream-storage"
    end
    if state.inventory~=nil then
      return blocked(state,"unexpected-prior-courier-inventory")
    end
    if not (game and type(game.create_inventory)=="function") then
      return false,"engine-courier-inventory-unavailable"
    end
    local ok,bag=pcall(function() return game.create_inventory(1) end)
    if not (ok and valid(bag) and count(bag,state.item)==0
        and count(bag)==0) then
      return false,"engine-courier-inventory-allocation-failed"
    end
    -- Persist the empty hold before mutating real station stock.
    state.inventory=bag
    state.pickup_source_before=before
    state.phase="upstream-pickup-debit"
  end
  if state.phase=="upstream-pickup-debit" then
    local source_inv=station_inventory(source.station)
    if not source_inv then return blocked(state,"upstream-pickup-source-lost") end
    local before=state.pickup_source_before
    local held,total=count(state.inventory,state.item),count(state.inventory)
    local current=count(source_inv,state.item)
    if not (before and held and total and current) then
      return blocked(state,"upstream-pickup-inventory-unobservable")
    end
    if held==0 and total==0 and current==before then
      pcall(function() source_inv.remove{name=state.item,count=1} end)
      current=count(source_inv,state.item)
    end
    if held==0 and total==0 and current==before-1 then
      pcall(function() state.inventory.insert{name=state.item,count=1} end)
      held,total=count(state.inventory,state.item),count(state.inventory)
    end
    if held~=1 or total~=1 or current~=before-1 then
      -- A partial or ambiguous physical debit is quarantined, not repeated.
      return blocked(state,"upstream-pickup-custody-ambiguous")
    end
    state.quantity=1
    state.phase="carrying"
    state.last_reason="one-physical-upstream-item-debited-into-courier-hold"
    return true,"physical-upstream-item-picked-up"
  end
  if state.phase=="to-natural-ore" or state.phase=="mining" then
    local ore,reason=natural_ore(source,mission)
    if not ore then return false,reason end
    if dist2(source.priest.position,ore.position)>M.reach_sq then
      local ok,movement=move(source.priest,ore.position)
      return false,ok and "walking-to-natural-ore" or movement
    end
    if not state.inventory then
      if not (game and type(game.create_inventory)=="function") then
        return false,"engine-courier-inventory-unavailable"
      end
      local ok,bag=pcall(function() return game.create_inventory(1) end)
      if not (ok and valid(bag) and count(bag,state.item)==0) then
        return false,"engine-courier-inventory-allocation-failed"
      end
      state.inventory=bag
      state.phase="mining"
      state.ore_unit=ore.unit_number
      state.ore_amount_before=ore.amount
    end
    if count(state.inventory,state.item)==0 then
      if state.ore_unit~=ore.unit_number
          or ore.amount~=state.ore_amount_before then
        return blocked(state,"ore-changed-before-physical-mine")
      end
      -- The actual LuaEntity.mine writes the product into persistent
      -- LuaInventory; no Lua quantity is used to fabricate ore.
      pcall(function() ore.mine{inventory=state.inventory} end)
    end
    local held,total=count(state.inventory,state.item),count(state.inventory)
    if not held or held<1 or total~=held then
      return blocked(state,"physical-ore-mine-produced-no-verifiable-item")
    end
    if held~=1 then return blocked(state,"first-hop-requires-single-item-stack") end
    if valid(ore) and not (ore.amount<state.ore_amount_before) then
      return blocked(state,"ore-source-did-not-decrement")
    end
    state.quantity=held
    state.phase="carrying"
    state.last_reason="one-real-ore-item-mined-into-engine-inventory"
    return true,"physical-ore-mined"
  end
  if state.phase~="carrying" then
    return blocked(state,"unknown-courier-phase")
  end
  if count(state.inventory,state.item)~=state.quantity
      or state.quantity~=1 then
    return blocked(state,"carried-ore-custody-count-changed")
  end
  if dist2(source.priest.position,dest.station.position)>M.reach_sq then
    local ok,movement=move(source.priest,dest.station.position)
    return false,ok and "walking-to-upstream-station" or movement
  end
  local dest_inv=station_inventory(dest.station)
  if not dest_inv then return false,"upstream-real-inventory-unavailable" end
  local ok_capacity,capacity=pcall(function()
    return dest_inv.get_insertable_count(state.item)
  end)
  if not ok_capacity or capacity<state.quantity then
    return false,"upstream-inventory-full"
  end
  local before=count(dest_inv,state.item)
  if before==nil then return false,"upstream-inventory-count-unavailable" end
  pcall(function()
    state.inventory.remove({name=state.item,count=state.quantity})
  end)
  if count(state.inventory,state.item)~=0 then
    return blocked(state,"carrier-physical-debit-unverifiable")
  end
  pcall(function()
    dest_inv.insert({name=state.item,count=state.quantity})
  end)
  if count(dest_inv,state.item)~=before+state.quantity then
    -- A refused insert is refunded to the original physical carrier hold.
    -- Ambiguous post-mutation callbacks are quarantined, never credited.
    pcall(function()
      state.inventory.insert({name=state.item,count=state.quantity})
    end)
    if count(state.inventory,state.item)==state.quantity
        and count(dest_inv,state.item)==before then
      return false,"upstream-insertion-refused-refunded-to-carrier"
    end
    return blocked(state,"upstream-transfer-custody-ambiguous")
  end
  if valid(state.inventory) then
    pcall(function() state.inventory.destroy() end)
  end
  state.inventory=nil
  state.delivered_count=state.quantity
  state.delivered_station_unit=dest.station.unit_number
  state.hops_completed=hop
  state.completed_tick=now()
  if hop==#route-1 then
    state.phase="magos-delivered"
    mission.delivered_to_magos_count=(mission.delivered_to_magos_count or 0)+1
    state.last_reason="one-natural-ore-item-physically-received-by-magos"
    return true,"counted-natural-ore-received-by-magos"
  end
  state.phase="first-hop-delivered"
  state.last_reason="one-real-ore-item-physically-delivered-to-upstream-station"
  return true,"first-physical-upstream-hop-delivered"
end
_G.TechPriestsResourceReturnCourier0837=M
return M
