-- Remote rail outposts: first autonomous strategic gate (0835).
-- Detect physical local ore starvation, confirmed remote ore and real rail
-- supplies. This module only publishes a durable objective; it does not
-- synthesize rails, train movement, inventory or a station at the destination.
local M={version="0.1.676.0835",scan_interval=900,
  local_radius=64,remote_min=192,remote_max=1024,
  stock_floor=4,resource_item="iron-ore",
  storage_key="remote_rail_outpost_0835"}
local function tick() return game and game.tick or 0 end
local function valid(e) return e and e.valid==true end
local function dist2(a,b)
  local x=a.x-b.x;local y=a.y-b.y
  return x*x+y*y
end
local function stock(inv,item)
  if not(inv and inv.valid) then return 0 end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and math.max(0,tonumber(n) or 0) or 0
end
local function count(pair,item)
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if authority and type(authority.generic_item_count)=="function" then
    local ok,n=pcall(authority.generic_item_count,pair,item)
    if ok and type(n)=="number" and n>=0 then return n end
  end
  local ok,inv=pcall(function()
    return pair.station.get_inventory(defines.inventory.chest)
  end)
  return ok and stock(inv,item) or 0
end
local function charted(force,surface,pos)
  if not (force and force.is_chunk_charted) then return false end
  local ok,yes=pcall(function()
    return force.is_chunk_charted(surface,{
      x=math.floor(pos.x/32),y=math.floor(pos.y/32)})
  end)
  return ok and yes==true
end
-- The existing scan router is the only authoritative world reader.
-- Fail CLOSED if it is unavailable: never declare starvation from a missing
-- scan, or add new unbudgeted world-scan sites to the UPS-critical dispatcher.
local function scan_resources(surface,filters)
  local routing=rawget(_G,"TechPriestsScanRouting0610")
  if not (routing and type(routing.find_entities)=="function") then
    return nil,"canonical-scan-unavailable"
  end
  local ok,entities=pcall(routing.find_entities,surface,filters,{
    category="resource",limit=filters.limit,record_negative=false})
  if not ok or type(entities)~="table" then
    return nil,"canonical-resource-scan-failed"
  end
  return entities
end
local function ore_near(surface,item,pos,radius)
  local found,why=scan_resources(surface,{
    type="resource",name=item,position=pos,radius=radius,limit=1})
  if not found then return nil,why end
  local e=found[1]
  return e and e.valid and (tonumber(e.amount) or 0)>0 or false
end
local REQUIRED={
  rail=64,locomotive=1,["cargo-wagon"]=1,coal=20,
  ["burner-mining-drill"]=1,["train-stop"]=2
}
function M.assess(pair)
  if not(valid(pair and pair.station) and valid(pair.priest)
      and pair.station.name=="planetary-magos-cogitator-station") then
    return nil,"not-live-planetary-magos"
  end
  local surface,force=pair.station.surface,pair.station.force
  if not(surface and force and force.technologies
    and force.technologies["railway"]
    and force.technologies["railway"].researched
    and force.technologies["automated-rail-transportation"]
    and force.technologies["automated-rail-transportation"].researched) then
    return nil,"railway-technology-locked"
  end
  local item=M.resource_item
  local available=count(pair,item)
  if available>=M.stock_floor then return nil,"stock-available" end
  local nearby,scan_reason=ore_near(
    surface,item,pair.station.position,M.local_radius)
  if nearby==nil then return nil,scan_reason end
  if nearby then return nil,"local-patch-available" end
  for name,minimum in pairs(REQUIRED) do
    if count(pair,name)<minimum then
      return nil,"missing-physical-rail-supplies:"..name
    end
  end
  local at=pair.station.position
  local r=M.remote_max
  local resources,why=scan_resources(surface,{
    type="resource",name=item,
    area={{at.x-r,at.y-r},{at.x+r,at.y+r}},limit=512})
  if not resources then return nil,why end
  local best,best_distance
  for _,entity in pairs(resources) do
    if valid(entity) and (tonumber(entity.amount) or 0)>0
        and entity.surface==surface then
      local d=dist2(entity.position,at)
      if d>=M.remote_min*M.remote_min
          and d<=r*r
          and charted(force,surface,entity.position)
          and (not best_distance or d<best_distance) then
        best=entity;best_distance=d
      end
    end
  end
  if not best then return nil,"no-charted-remote-ore" end
  return {item=item,position={x=best.position.x,y=best.position.y},
    resource_unit=best.unit_number,resource_name=best.name,
    distance=math.sqrt(best_distance),
    station_unit=pair.station.unit_number,
    station_surface=surface.index,force_index=force.index,
    observed_stock=available},"starved-charted-patch"
end
function M.observe_pair(pair)
  if not(valid(pair and pair.station) and valid(pair.priest)) then
    return false,"invalid-pair"
  end
  if pair.station.name~="planetary-magos-cogitator-station" then
    return false,"not-root-rank"
  end
  local last=pair.remote_rail_outpost_probe_0835 or 0
  if tick()<last+M.scan_interval then return false,"interval" end
  pair.remote_rail_outpost_probe_0835=tick()
  local result,why=M.assess(pair)
  pair.remote_rail_outpost_diagnosis_0835={tick=tick(),reason=why,
    local_ore_stock=result and result.observed_stock}
  if not result then return false,why end
  local objective=pair.remote_rail_outpost_0835
  if objective and objective.status~="cancelled"
      and objective.status~="completed" then
    -- Do not reissue or redirect a live train/track mission every scan.
    objective.last_observed_tick=tick()
    return false,"mission-already-owned"
  end
  pair.remote_rail_outpost_0835={
    version=M.version,status="starvation-confirmed",
    stage="surveyed-remote-patch",item=result.item,
    target=result.position,resource_name=result.resource_name,
    resource_unit=result.resource_unit,
    distance=result.distance,root_station_unit=result.station_unit,
    surface_index=result.station_surface,force_index=result.force_index,
    initial_stock=result.observed_stock,created_tick=tick(),
    last_observed_tick=tick(),next_step="plan-physical-track-route",
    -- Deliberately no created buildings or cargo: independent executors
    -- must debit stocked rail before claiming a constructed track segment.
  }
  if log then log("[Tech-Priests rail-0835] resource-starved station="..
    tostring(result.station_unit).." item="..result.item..
    " charted_target="..result.position.x..","..result.position.y..
    " distance="..math.floor(result.distance)..
    " next=plan-physical-track-route") end
  return true,"starvation-objective-created"
end
_G.TechPriestsRemoteRailOutpost0835=M
return M
