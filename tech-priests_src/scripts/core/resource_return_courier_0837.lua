-- Method I: mine a natural ore entity into an engine-owned courier inventory,
-- then physically carry its exact product to the immediate upstream station.
-- First-hop proof only: further hops and mining machinery remain separate gates.
local Chain=require("scripts.core.resource_station_chain_0820")
local M={version="0.1.674-dev.0837",reach_sq=25,interval=60}
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
  local ok,found=pcall(scans.find_entities,source.station.surface,{
    name=mission.resource_name,type="resource",
    area={{pos.x-4,pos.y-4},{pos.x+4,pos.y+4}},limit=8},
    {category="resource",limit=8})
  if not ok then return nil,"resource-scan-failed" end
  for _,ore in ipairs(found or {}) do
    if valid(ore) and ore.name==mission.resource_name
        and ore.surface==source.station.surface
        and tonumber(ore.amount) and ore.amount>0
        and dist2(source.station.position,ore.position)
          <=(tonumber(source.radius or source.base_radius) or 20)^2
        and ore_product_is_exact(ore,mission.need) then
      return ore
    end
  end
  return nil,"natural-ore-not-mineable-or-out-of-range"
end
local function station_inventory(station)
  local get=rawget(_G,"get_station_inventory")
  if type(get)~="function" then return nil end
  local ok,inv=pcall(get,station)
  if ok and valid(inv) and type(inv.insert)=="function"
      and type(inv.get_insertable_count)=="function" then return inv end
end
function M.worker_reserved(worker)
  if not (worker and valid(worker.station) and valid(worker.priest)) then return false end
  local assignment=worker.remote_resource_assignment_0820
  local magos=assignment and pair(assignment.root_station_unit)
  local mission=magos and magos.resource_expansion_0259
    and magos.resource_expansion_0259.chain_0820
  local state=mission and mission.return_courier_0837
  return mission and mission.status=="reached-resource" and state
    and state.phase~="first-hop-delivered"
    and state.source_station_unit==worker.station.unit_number
    and state.carrier_priest_unit==worker.priest.unit_number or false
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
  if not route then return false,why end
  if #route<2 then return false,"no-physical-upstream-hop" end
  local state=mission.return_courier_0837
  if not state then
    local terminal=pair(route[1])
    if not (terminal and valid(terminal.priest)
        and terminal.priest.unit_number) then
      return false,"terminal-priest-missing"
    end
    if terminal.direct_acquisition_custody_0513
        or terminal.construction_custody_0338
        or terminal.station_expansion_0256 then
      return false,"terminal-priest-has-existing-custody"
    end
    state={
      phase="to-natural-ore",source_station_unit=route[1],
      destination_station_unit=route[2],
      carrier_priest_unit=terminal.priest.unit_number,
      item=mission.need,quantity=0,
      started_tick=now(),updated_tick=now(),next_tick=now(),
    }
    mission.return_courier_0837=state
  end
  if state.phase=="first-hop-delivered" then
    return false,"first-upstream-hop-already-delivered"
  end
  if state.phase=="custody-blocked" then
    return false,state.last_reason or "custody-blocked"
  end
  if state.source_station_unit~=route[1]
      or state.destination_station_unit~=route[2]
      or state.item~=mission.need then
    return blocked(state,"return-route-changed-during-custody")
  end
  local source,dest=pair(state.source_station_unit),pair(state.destination_station_unit)
  if not (source and dest and valid(source.station) and valid(source.priest)
      and valid(dest.station) and valid(dest.priest)
      and source.priest.unit_number==state.carrier_priest_unit
      and source.station.surface==dest.station.surface
      and source.station.force==dest.station.force
      and source.station.unit_number==mission.current_station_unit) then
    return blocked(state,"physical-route-or-carrier-identity-changed")
  end
  if now()<(state.next_tick or 0) then return false,"courier-interval" end
  state.next_tick=now()+M.interval
  state.updated_tick=now()
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
      pcall(function() ore.mine{inventory=state.inventory,force=source.station.force} end)
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
  state.phase="first-hop-delivered"
  state.delivered_count=state.quantity
  state.delivered_station_unit=dest.station.unit_number
  state.completed_tick=now()
  state.last_reason="one-real-ore-item-physically-delivered-to-upstream-station"
  return true,"first-physical-upstream-hop-delivered"
end
_G.TechPriestsResourceReturnCourier0837=M
return M
