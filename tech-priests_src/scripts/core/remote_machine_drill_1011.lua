-- Method I: request one REAL burner drill at a verified terminal ore patch.
-- The existing 0338 constructor alone owns item pickup, movement, debit and
-- entity creation. This module neither creates an entity nor credits ore.
-- Receiver construction, physical fuel delivery and drill-output return are
-- separate acceptance stages; a verified drill is not a completed mine.
local Chain=require("scripts.core.resource_station_chain_0820")
local M={version="0.1.674-dev.1012",item="burner-mining-drill",
  receiver_item="wooden-chest",fuel_item="coal",fuel_reserve=5}
local function valid(e) return e and e.valid==true end
local function distance_sq(a,b)
  if not(a and b) then return math.huge end
  return (a.x-b.x)^2+(a.y-b.y)^2
end
local function count(inv,name)
  if not valid(inv) then return nil end
  local ok,n=pcall(function() return inv.get_item_count(name) end)
  return ok and type(n)=="number" and n or nil
end
local function station_stock(pair)
  if not(valid(pair and pair.station) and defines
      and defines.inventory and defines.inventory.chest) then return nil end
  local ok,inv=pcall(function()
    return pair.station.get_inventory(defines.inventory.chest)
  end)
  return ok and valid(inv) and inv or nil
end
local function terminal_for(root,mission)
  local route,reason=Chain.return_route(root)
  if not(route and #route>=2
      and route[#route]==root.station.unit_number) then
    return nil,"physical-return-route-unavailable:"..tostring(reason)
  end
  local tp=storage and storage.tech_priests
  local pair=tp and tp.pairs_by_station and tp.pairs_by_station[route[1]]
  if not(valid(pair and pair.station) and valid(pair.priest)
      and pair.station.force==root.station.force
      and pair.station.surface==root.station.surface
      and mission.current_station_unit==pair.station.unit_number
      and pair.remote_resource_assignment_0820
      and pair.remote_resource_assignment_0820.root_station_unit
        ==root.station.unit_number) then
    return nil,"physical-terminal-identity-invalid"
  end
  return pair
end
-- Routine requests remain queued; only active 0338 tasks/custody can
-- delay a separate remote-resource construction intent.
local function construction_busy(pair)
  return pair.construction_task_0338~=nil
    or pair.construction_custody_0338~=nil
end
local function actual_drill(pair,site,direction)
  local scan=rawget(_G,"TechPriestsScanRouting0610")
  if not(scan and type(scan.find_entities)=="function") then
    return nil,"canonical-construction-scan-unavailable"
  end
  local ok,entities=pcall(scan.find_entities,pair.station.surface,{
    name=M.item,position=site,radius=0.25,
    force=pair.station.force,limit=4},
    {category="construction",limit=4,require_fresh=true})
  if not(ok and type(entities)=="table") then
    return nil,"physical-drill-scan-unavailable"
  end
  for _,e in ipairs(entities) do
    if valid(e) and e.name==M.item and e.type=="mining-drill"
        and e.force==pair.station.force
        and e.surface==pair.station.surface
        and e.direction==direction
        and distance_sq(e.position,site)<0.0625 then
      return e
    end
  end
  return nil,"physical-drill-not-observed"
end

-- The drill's output coordinate is not necessarily the center of a tile.
-- Use the real Factorio drop position, snapped to the vanilla 1x1 chest tile.
local function receiver_site(drill)
  local ok,drop=pcall(function() return drill.drop_position end)
  if not(ok and drop and type(drop.x)=="number"
      and type(drop.y)=="number") then return nil end
  return {x=math.floor(drop.x)+0.5,y=math.floor(drop.y)+0.5}
end
local function actual_receiver(pair,site)
  local scan=rawget(_G,"TechPriestsScanRouting0610")
  if not(scan and type(scan.find_entities)=="function") then
    return nil,"canonical-receiver-scan-unavailable"
  end
  local ok,entities=pcall(scan.find_entities,pair.station.surface,{
    name=M.receiver_item,position=site,radius=0.25,
    force=pair.station.force,limit=4},
    {category="construction",limit=4,require_fresh=true})
  if not(ok and type(entities)=="table") then
    return nil,"physical-receiver-scan-unavailable"
  end
  for _,e in ipairs(entities) do
    if valid(e) and e.name==M.receiver_item and e.type=="container"
        and e.force==pair.station.force and e.surface==pair.station.surface
        and distance_sq(e.position,site)<0.0625 then
      local ok_inv,inv=pcall(function()
        return e.get_inventory(defines.inventory.chest)
      end)
      if ok_inv and valid(inv) then return e end
    end
  end
  return nil,"physical-receiver-not-observed"
end
local function receiver_connected(drill,receiver,site)
  local actual_site=receiver_site(drill)
  if not(actual_site and distance_sq(actual_site,site)==0) then
    return false,"drill-output-site-changed"
  end
  if not(valid(receiver) and receiver.position
      and distance_sq(receiver.position,site)<0.0625
      and receiver.force==drill.force and receiver.surface==drill.surface) then
    return false,"physical-drill-output-not-connected-to-exact-receiver"
  end
  local ok,target=pcall(function() return drill.drop_target end)
  if not ok then return false,"physical-drill-drop-target-unreadable" end
  if valid(target) then
    if target.unit_number==receiver.unit_number
        and target.force==receiver.force and target.surface==receiver.surface then
      return true,"exact-engine-drop-target"
    end
    -- A real target pointing elsewhere overrides geometric proximity.
    return false,"physical-drill-output-not-connected-to-exact-receiver"
  end
  -- Factorio's unpowered burner drills may have no resolved drop_target.
  -- The canonical 0528 physical receiver authority already recognizes the
  -- drop coordinate within 0.51 squared tiles of an actual chest center.
  -- Require that same geometric proof for this EXACT built receiver, not
  -- merely a nearby or substituted chest. This proves output alignment,
  -- NOT that any ore was mined or delivered.
  local read,drop=pcall(function() return drill.drop_position end)
  if read and drop and type(drop.x)=="number" and type(drop.y)=="number"
      and distance_sq(drop,receiver.position)<=0.51 then
    return true,"engine-drop-position-inside-exact-receiver"
  end
  return false,"physical-drill-output-not-connected-to-exact-receiver"
end
function M.service_pair(root)
  local mission=root and root.resource_expansion_0259
    and root.resource_expansion_0259.chain_0820
  if not(valid(root and root.station) and valid(root.priest)
      and mission and mission.status=="reached-resource"
      and mission.root_station_unit==root.station.unit_number
      and mission.need==mission.resource_name
      and (mission.need=="iron-ore" or mission.need=="copper-ore"
        or mission.need=="stone" or mission.need=="coal")) then
    return false,"no-supported-physical-ore-objective"
  end
  local terminal,why=terminal_for(root,mission)
  if not terminal then return false,why end
  local state=mission.remote_drill_1011
  if state then
    if state.root_unit~=root.station.unit_number
        or state.terminal_unit~=terminal.station.unit_number
        or state.resource_name~=mission.resource_name
        or not(state.target and mission.target
          and distance_sq(state.target,mission.target)==0) then
      return false,"remote-drill-persisted-identity-mismatch"
    end
    if state.phase=="blocked" then return false,state.last_reason end
    if state.phase=="drill-verified" then
      local drill=actual_drill(terminal,state.position,state.direction)
      if not(drill and drill.unit_number==state.drill_unit) then
        state.phase="blocked"
        state.last_reason="verified-physical-drill-lost"
        return false,state.last_reason
      end
      if terminal.remote_drill_request_1011 then
        return false,"terminal-has-existing-remote-drill-request"
      end
      local stock=station_stock(terminal)
      if not(stock and (count(stock,M.receiver_item) or 0)>=1) then
        return false,"physical-receiver-stock-missing"
      end
      local position=receiver_site(drill)
      if not position then return false,"physical-drill-drop-position-unavailable" end
      if distance_sq(position,terminal.station.position)>
          Chain.operating_radius(terminal)^2 then
        return false,"receiver-outside-terminal-command-range"
      end
      if not(prototypes and prototypes.item
          and prototypes.item[M.receiver_item]
          and prototypes.entity and prototypes.entity[M.receiver_item]) then
        return false,"real-receiver-prototype-unavailable"
      end
      local ok,allowed=pcall(function()
        return terminal.station.surface.can_place_entity{
          name=M.receiver_item,position=position,
          force=terminal.station.force}
      end)
      if not(ok and allowed==true) then
        return false,"real-receiver-drop-site-blocked"
      end
      local request={item_name=M.receiver_item,entity_name=M.receiver_item,
        category="storage",position=position,
        site_reason="remote-drill-exact-output-receiver-1012",
        remote_drill_root_1011=root.station.unit_number,
        remote_drill_terminal_1011=terminal.station.unit_number,
        remote_drill_unit_1012=state.drill_unit}
      terminal.remote_drill_request_1011=request
      state.receiver_request=request
      state.receiver_position=position
      state.phase="receiver-requested"
      state.receiver_requested_tick=game and game.tick or 0
      return true,"physical-receiver-requested-from-real-terminal-stock"
    end
    if state.phase=="receiver-requested" or state.phase=="receiver-built"
        or state.phase=="receiver-verified" or state.phase=="fuel-verified" then
      local drill=actual_drill(terminal,state.position,state.direction)
      if not(drill and drill.unit_number==state.drill_unit) then
        state.phase="blocked"
        state.last_reason="verified-physical-drill-lost"
        return false,state.last_reason
      end
      local site=receiver_site(drill)
      if not(site and state.receiver_position
          and distance_sq(site,state.receiver_position)==0) then
        state.phase="blocked"
        state.last_reason="drill-output-site-changed"
        return false,state.last_reason
      end
      if state.phase=="receiver-requested" then
        if terminal.remote_drill_request_1011
            and terminal.remote_drill_request_1011~=state.receiver_request then
          state.phase="blocked"
          state.last_reason="native-receiver-request-replaced-by-other-work"
          return false,state.last_reason
        end
        local completed=terminal.construction_last_task_0338
        -- 0338 deliberately retains a failed request for diagnosis/retry.
        -- Its request field can remain populated after abort, so inspect
        -- the exact failed receipt BEFORE treating that field as busy.
        if completed and completed.request_value==state.receiver_request
            and completed.phase=="aborted"
            and not terminal.construction_task_0338
            and not terminal.construction_custody_0338 then
          state.phase="blocked"
          state.last_reason="native-receiver-builder-aborted:"
            ..tostring(completed.result)
          return false,state.last_reason
        end
        if construction_busy(terminal)
            or terminal.remote_drill_request_1011==state.receiver_request then
          return true,"waiting-for-native-0338-receiver-builder"
        end
        if not(completed and completed.request_value==state.receiver_request
            and completed.phase=="complete"
            and valid(completed.built_entity)
            and completed.built_entity.name==M.receiver_item
            and distance_sq(completed.built_entity.position,site)<0.0625) then
          if completed and completed.request_value==state.receiver_request
              and completed.phase=="aborted" then
            state.phase="blocked"
            state.last_reason="native-receiver-builder-aborted:"
              ..tostring(completed.result)
            return false,state.last_reason
          end
          return true,"awaiting-exact-native-receiver-build-proof"
        end
        local receiver,reason=actual_receiver(terminal,site)
        if not(receiver and receiver==completed.built_entity
            and receiver.unit_number) then
          state.phase="blocked"
          state.last_reason="native-receiver-build-not-physically-verified:"
            ..tostring(reason)
          return false,state.last_reason
        end
        state.receiver_unit=receiver.unit_number
        state.receiver_built_tick=game and game.tick or 0
        state.phase="receiver-built"
        return true,"counted-0338-receiver-built-connection-pending"
      end
      local receiver=actual_receiver(terminal,site)
      if not(receiver and receiver.unit_number==state.receiver_unit) then
        state.phase="blocked"
        state.last_reason="verified-physical-receiver-lost"
        return false,state.last_reason
      end
      local connected,why=receiver_connected(drill,receiver,site)
      if not connected then
        if state.phase=="receiver-verified" then
          state.phase="blocked"
          state.last_reason=why
          return false,state.last_reason
        end
        -- The unpowered drill may not expose its drop target yet. Do not
        -- permanently quarantine a counted receiver before the separate
        -- fuel-delivery stage, or monopolize the natural-ore courier.
        return false,"waiting-for-physical-drill-receiver-connection"
      end
      if state.phase=="receiver-built" then
        state.phase="receiver-verified"
        state.receiver_verified_tick=game and game.tick or 0
        state.receiver_connection_1015=why
        return true,"physical-drill-receiver-connected-fuel-pending"
      end
      if state.phase=="fuel-verified" then
        return false,"counted-fuel-delivered-awaiting-real-machine-ore-output"
      end
      -- 1013: the existing 0528 logistics executor alone physically carries
      -- coal from canonical storage into the drill's REAL fuel inventory.
      -- A planned supply task, inventory counter or unrelated fuel receipt
      -- cannot complete this stage. Burner energy may replace inventory stock
      -- after the engine has consumed an inserted fuel item.
      local fuel
      local ok_fuel=pcall(function()
        fuel=drill.get_inventory(defines.inventory.fuel)
      end)
      if not(ok_fuel and valid(fuel)) then
        return false,"physical-drill-fuel-inventory-unavailable"
      end
      local fuel_count=count(fuel,M.fuel_item) or 0
      local burning=0
      pcall(function()
        burning=tonumber(drill.burner and drill.burner.remaining_burning_fuel) or 0
      end)
      if fuel_count<1 and burning<=0 then
        return false,"waiting-for-real-drill-fuel-or-burner-energy"
      end
      for _,proof in ipairs(terminal.machine_fuel_receipts_1013 or {}) do
        if type(proof)=="table" and proof.authority=="physical-machine-fuel-0528"
            and proof.item==M.fuel_item
            and type(proof.count)=="number" and proof.count>=1
            and proof.count==math.floor(proof.count)
            and proof.station_unit==terminal.station.unit_number
            and proof.priest_unit==terminal.priest.unit_number
            and proof.machine_unit==state.drill_unit
            and type(proof.source_before)=="number"
            and proof.source_before>=proof.count
            and proof.source_after==proof.source_before-proof.count
            and type(proof.destination_before)=="number"
            and proof.destination_before>=0
            and proof.destination_after==proof.destination_before+proof.count
            and type(proof.tick)=="number" and proof.tick<=game.tick
            and proof.tick>=state.verified_tick then
          state.fuel_receipt_tick=proof.tick
          state.fuel_count=proof.count
          state.phase="fuel-verified"
          return true,"counted-0528-coal-delivered-to-real-drill"
        end
      end
      return false,"waiting-for-exact-counted-0528-fuel-receipt"
    end
    if state.phase~="drill-requested" then
      return false,"remote-drill-phase-invalid"
    end
    -- A saved writ is not permission to monopolize another constructor.
    -- The native 0338 owner may replace or refuse the request; a different
    -- live request must never be mistaken for progress on this drill.
    if terminal.remote_drill_request_1011
        and terminal.remote_drill_request_1011~=state.request then
      state.phase="blocked"
      state.last_reason="native-drill-request-replaced-by-other-work"
      return false,state.last_reason
    end
    local completed=terminal.construction_last_task_0338
    if completed and completed.request_value==state.request
        and completed.phase=="aborted"
        and not terminal.construction_task_0338
        and not terminal.construction_custody_0338 then
      state.phase="blocked"
      state.last_reason="native-drill-builder-aborted:"..tostring(completed.result)
      return false,state.last_reason
    end
    if construction_busy(terminal)
        or terminal.remote_drill_request_1011==state.request then
      return true,"waiting-for-native-0338-drill-builder"
    end
    if not(completed and completed.request_value==state.request
        and completed.phase=="complete"
        and valid(completed.built_entity)
        and completed.built_entity.name==M.item
        and completed.built_entity.direction==state.direction
        and distance_sq(completed.built_entity.position,state.position)<0.0625) then
      if completed and completed.request_value==state.request
          and completed.phase=="aborted" then
        state.phase="blocked"
        state.last_reason="native-drill-builder-aborted:"..tostring(completed.result)
        return false,state.last_reason
      end
      return true,"awaiting-exact-native-drill-build-proof"
    end
    local drill,reason=actual_drill(terminal,state.position,state.direction)
    if not(drill and drill==completed.built_entity
        and drill.unit_number) then
      state.phase="blocked"
      state.last_reason="native-drill-build-not-physically-verified:"..tostring(reason)
      return false,state.last_reason
    end
    state.phase="drill-verified"
    state.drill_unit=drill.unit_number
    state.verified_tick=game and game.tick or 0
    state.last_reason="counted-0338-drill-built-receiver-and-fuel-pending"
    return true,state.last_reason
  end
  local courier=mission.return_courier_0837
  if courier and courier.phase~="magos-delivered" then
    return false,"existing-ore-courier-custody-active"
  end
  if terminal.remote_drill_request_1011 then
    return false,"terminal-has-existing-remote-drill-request"
  end
  local stock=station_stock(terminal)
  if not(stock and (count(stock,M.item) or 0)>=1
      and (count(stock,M.receiver_item) or 0)>=1
      and (count(stock,M.fuel_item) or 0)>=M.fuel_reserve) then
    return false,"physical-drill-receiver-or-fuel-stock-missing"
  end
  if not(prototypes and prototypes.item
      and prototypes.item[M.item] and prototypes.item[M.receiver_item]
      and prototypes.entity and prototypes.entity[M.item]
      and defines and defines.direction
      and type(defines.direction.north)=="number") then
    return false,"real-drill-prototypes-unavailable"
  end
  local scan=rawget(_G,"TechPriestsScanRouting0610")
  if not(scan and type(scan.find_entities)=="function") then
    return false,"canonical-resource-scan-unavailable"
  end
  local target=mission.target
  if not(target and type(target.x)=="number"
      and type(target.y)=="number") then
    return false,"ore-target-invalid"
  end
  local ok,ores=pcall(scan.find_entities,terminal.station.surface,{
    name=mission.resource_name,type="resource",
    area={{target.x-4,target.y-4},{target.x+4,target.y+4}},
    limit=8},{category="resource",limit=8,require_fresh=true})
  if not(ok and type(ores)=="table") then
    return false,"natural-ore-scan-unavailable"
  end
  local radius=Chain.operating_radius(terminal)
  local direction=defines.direction.north
  local position=nil
  for _,ore in ipairs(ores) do
    if valid(ore) and ore.type=="resource"
        and ore.name==mission.resource_name
        and ore.surface==terminal.station.surface
        and (tonumber(ore.amount) or 0)>0
        and distance_sq(ore.position,terminal.station.position)<=radius^2 then
      local candidate={x=math.floor(ore.position.x),
        y=math.floor(ore.position.y)}
      local allowed,can=pcall(function()
        return terminal.station.surface.can_place_entity{
          name=M.item,position=candidate,direction=direction,
          force=terminal.station.force}
      end)
      if allowed and can==true
          and distance_sq(candidate,terminal.station.position)<=radius^2 then
        position=candidate
        break
      end
    end
  end
  if not position then return false,"no-physical-drill-site-on-natural-ore" end
  local request={item_name=M.item,entity_name=M.item,
    category="mining",position=position,direction=direction,
    site_reason="remote-ore-physical-drill-1011",
    remote_drill_root_1011=root.station.unit_number,
    remote_drill_terminal_1011=terminal.station.unit_number}
  terminal.remote_drill_request_1011=request
  mission.remote_drill_1011={
    phase="drill-requested",root_unit=root.station.unit_number,
    terminal_unit=terminal.station.unit_number,
    resource_name=mission.resource_name,
    target={x=target.x,y=target.y},position=position,
    direction=direction,request=request,
    requested_tick=game and game.tick or 0}
  return true,"physical-drill-requested-from-real-terminal-stock"
end
return M
