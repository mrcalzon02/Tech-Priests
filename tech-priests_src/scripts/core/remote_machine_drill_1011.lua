-- Method I: request one REAL burner drill at a verified terminal ore patch.
-- The existing 0338 constructor alone owns item pickup, movement, debit and
-- entity creation. This module neither creates an entity nor credits ore.
-- Receiver construction, physical fuel delivery and drill-output return are
-- separate acceptance stages; a verified drill is not a completed mine.
local Chain=require("scripts.core.resource_station_chain_0820")
local M={version="0.1.674-dev.1011",item="burner-mining-drill",
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
local function construction_busy(pair)
  return pair.construction_request~=nil
    or pair.construction_task_0338~=nil
    or pair.construction_custody_0338~=nil
    or pair.construction_candidate_0338~=nil
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
    if state.phase=="drill-verified" then
      local drill=actual_drill(terminal,state.position,state.direction)
      if drill and drill.unit_number==state.drill_unit then
        return false,"physical-drill-present-receiver-pending"
      end
      state.phase="blocked"
      state.last_reason="verified-physical-drill-lost"
      return false,state.last_reason
    end
    if state.phase=="blocked" then return false,state.last_reason end
    if state.phase~="drill-requested" then
      return false,"remote-drill-phase-invalid"
    end
    if construction_busy(terminal) then
      return true,"waiting-for-native-0338-drill-builder"
    end
    local completed=terminal.construction_last_task_0338
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
  if construction_busy(terminal) then
    return false,"terminal-has-existing-construction"
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
  terminal.construction_request=request
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
