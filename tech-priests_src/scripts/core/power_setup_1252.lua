-- Native 1252: electrical demand -> real stocked steam-plant construction.
-- Physically building is exclusively 0338's responsibility. The existing
-- 0689/0691 fluid system routes water/steam pipes after each machine is built;
-- 0705/0707 owns boiler fuel. No fabricated fluid, power or machine stock.
local M={version="1252",max_shore_tiles=120}
local function valid(e)return e and e.valid end
local function d2(a,b)
 local dx=a.x-b.x;local dy=a.y-b.y;return dx*dx+dy*dy
end
local function radius(pair)
 local r=tonumber(pair and pair.radius)or 36
 local f=rawget(_G,"get_station_operating_radius")
 if type(f)=="function"then
  local ok,v=pcall(f,pair.station)
  if ok and tonumber(v)then r=tonumber(v)end
 end
 return math.max(12,math.min(72,r))
end
local function find(pair,types,r)
 local ok,items=pcall(function()
  return pair.station.surface.find_entities_filtered{
   position=pair.station.position,radius=r,
   force=pair.station.force,type=types,limit=160}
 end)
 local out={}
 if ok and type(items)=="table"then
  for _,v in pairs(items)do
   if valid(v)and v.surface==pair.station.surface
     and v.force==pair.station.force and v.position
     and d2(v.position,pair.station.position)<=r*r then
    out[#out+1]=v
   end
  end
 end
 table.sort(out,function(a,b)
  local ad=d2(a.position,pair.station.position)
  local bd=d2(b.position,pair.station.position)
  if ad~=bd then return ad<bd end
  return(tonumber(a.unit_number)or 0)<(tonumber(b.unit_number)or 0)
 end)
 return out
end
local function item_ready(item)
 local p=prototypes and prototypes.item and prototypes.item[item]
 local entity=prototypes and prototypes.entity and prototypes.entity[item]
 if not(p and entity)then return false end
 local placed
 pcall(function()placed=p.place_result end)
 return placed and placed.name==item
end
local function stock(pair,item)
 local a=rawget(_G,"TechPriestsStorageRoleAuthority0686")
  or(package.loaded and package.loaded["scripts.core.storage_role_authority_0686"])
 if not(a and type(a.generic_item_count)=="function")then
  return nil,"physical-storage-authority-unavailable"
 end
 local ok,n=pcall(a.generic_item_count,pair,item)
 if not(ok and type(n)=="number")then return nil,"physical-stock-unobservable"end
 return math.max(0,n),"counted"
end
local dirs=function()
 local d=defines and defines.direction or{}
 return {d.north or 0,d.east or 4,d.south or 8,d.west or 12}
end
local function legal(pair,item,pos,direction,r)
 if d2(pos,pair.station.position)>(r-2)^2 then return false end
 local ok,clear=pcall(function()
  return pair.station.surface.can_place_entity{
   name=item,position=pos,direction=direction,force=pair.station.force}
 end)
 return ok and clear==true
end
local function shoreline(pair,r)
 local surface=pair.station.surface
 if type(surface.find_tiles_filtered)~="function"then
  return nil,"shoreline-tile-api-unavailable"
 end
 local ok,tiles=pcall(function()
  return surface.find_tiles_filtered{
   position=pair.station.position,radius=r,
   name={"water","deepwater","water-green","deepwater-green"},
   limit=M.max_shore_tiles}
 end)
 if not(ok and type(tiles)=="table")then
  return nil,"shoreline-water-scan-unavailable"
 end
 table.sort(tiles,function(a,b)
  return d2(a.position,pair.station.position)
       <d2(b.position,pair.station.position)
 end)
 local offsets={{0,0},{1,0},{-1,0},{0,1},{0,-1},
                {2,0},{-2,0},{0,2},{0,-2}}
 for _,tile in ipairs(tiles)do
  if tile.position then
   for _,offset in ipairs(offsets)do
    local pos={x=math.floor(tile.position.x)+offset[1]+.5,
               y=math.floor(tile.position.y)+offset[2]+.5}
    for _,direction in ipairs(dirs())do
     if legal(pair,"offshore-pump",pos,direction,r)then
      return{position=pos,direction=direction},"engine-approved-shoreline"
     end
    end
   end
  end
 end
 return nil,"no-engine-approved-offshore-pump-shoreline"
end
local function near(pair,entity,item,r)
 -- Search bounded sites in the actual local construction territory, not
 -- an imaginary global power plant. The 0689/0691 owners later connect
 -- existing physical fluid ports with distinct counted pipe requests.
 local offsets
 if item=="small-electric-pole"then
  -- The first generator pole must actually reach the native generator,
  -- not merely be "near" its construction site.
  offsets={{2,0},{-2,0},{0,2},{0,-2},
           {3,0},{-3,0},{0,3},{0,-3}}
 else
  offsets={{4,0},{-4,0},{0,4},{0,-4},
   {5,2},{-5,2},{5,-2},{-5,-2},
   {0,6},{0,-6},{6,0},{-6,0},
   {7,3},{-7,3},{7,-3},{-7,-3}}
 end
 local best
 for _,v in ipairs(offsets)do
  local p={x=math.floor(entity.position.x+v[1])+.5,
           y=math.floor(entity.position.y+v[2])+.5}
  for _,direction in ipairs(dirs())do
   if legal(pair,item,p,direction,r)then
    local score=d2(p,pair.station.position)+d2(p,entity.position)*.01
    if not best or score<best.score then
     best={position=p,direction=direction,score=score}
    end
   end
  end
 end
 return best
end
local function pole_covering(pair,e,r)
 for _,pole in ipairs(find(pair,{"electric-pole"},r))do
  local coverage=nil
  pcall(function()coverage=pole.prototype.supply_area_distance end)
  if type(coverage)=="number"and coverage>0
   and math.abs(pole.position.x-e.position.x)<=coverage+1
   and math.abs(pole.position.y-e.position.y)<=coverage+1 then
   return pole
  end
 end
 return nil
end
local function request(pair,stage,item,site,load,r)
 local current=pair.structure_construction_requested_item
 if current then
  if type(current)=="table"and current.owner=="power-setup-1252"then
   return true,"power-build-awaiting-original-0338:"..tostring(current.item_name)
  end
  return false,"other-physical-structure-request-owned"
 end
 -- The caller may request a NEW future job only. Never displace existing
 -- construction/machine cargo, robot work, frontier or recovery claims.
 if pair.construction_task_0338 or pair.construction_custody_0338
  or pair.construction_task_0340 or pair.robot_network_task_0338
  or pair.robot_network_request_0338 or pair.remote_drill_request_1011
  or pair.construction_request or pair.pending_construction
  or pair.build_request or pair.direct_acquisition_custody_0513
  or pair.machine_logistics_custody_0528 then
  return false,"physical-owner-busy"
 end
 if not item_ready(item)then return false,"placeable-unavailable:"..item end
 local count,why=stock(pair,item)
 if count==nil then return false,why end
 if count<1 then return false,"equipment-shortage:"..item end
 if not site then return false,"site-not-verified:"..item end
 pair.structure_construction_requested_item={
  item_name=item,entity_name=item,
  category= item=="small-electric-pole"and"emergency-power-pole"
     or "power-generation",
  position={x=site.position.x,y=site.position.y},
  direction=site.direction,
  site_reason="physical-steam-power-1252:"..stage,
  power_setup_stage_1252=stage,
  power_setup_load_unit_1252=load and load.unit_number or nil,
  owner="power-setup-1252",
 }
 return true,"physical-power-build-requested:"..stage..":"..item
end
local function update(pair,status,load)
 pair.power_setup_observation_1252={
  tick=game and game.tick or 0,reason=status,
  load_unit=load and load.unit_number,
  load_name=load and load.name,
  request=pair.structure_construction_requested_item
     and pair.structure_construction_requested_item.owner=="power-setup-1252"
     and pair.structure_construction_requested_item.item_name or nil}
 return status
end
function M.service_pair(pair)
 if not(pair and valid(pair.station)and valid(pair.priest))then
  return false,"invalid-pair"
 end
 local surface=pair.station.surface
 if not(surface and type(surface.find_entities_filtered)=="function"
  and type(surface.can_place_entity)=="function")then
  return false,"physical-engine-scan-unavailable"
 end
 local r=radius(pair)
 local loads=find(pair,{"lab","assembling-machine","mining-drill"},r)
 local load
 for _,e in ipairs(loads)do
  local electric=e.type=="lab"or
    (e.type=="mining-drill"and e.name=="electric-mining-drill")or
    (e.type=="assembling-machine"and e.name~="tech-priests-emergency-assembler")
  if electric then
   local energy=nil
   pcall(function()energy=tonumber(e.energy)end)
   if energy==nil or energy<=0 then
    if not load or e.type=="lab"then load=e end
   end
  end
 end
 if not load then return false,update(pair,"no-unpowered-native-load",nil)end
 local machines=find(pair,{"offshore-pump","boiler","generator"},r)
 local pump,boiler,engine
 for _,e in ipairs(machines)do
  if e.name=="offshore-pump"and not pump then pump=e
  elseif e.name=="boiler"and not boiler then boiler=e
  elseif e.name=="steam-engine"and not engine then engine=e end
 end
 local item,stage,site=nil,nil,nil
 if not pump then
  item="offshore-pump";stage="water-intake"
  -- Fail closed on unknown shore; never place a pump on imaginary water.
  if item_ready(item)then site=shoreline(pair,r)end
 elseif not boiler then
  item="boiler";stage="heat-water"
  if item_ready(item)then site=near(pair,pump,item,r)end
 elseif not engine then
  item="steam-engine";stage="generate-electricity"
  if item_ready(item)then site=near(pair,boiler,item,r)end
 elseif not pole_covering(pair,engine,r)then
  item="small-electric-pole";stage="generation-output-pole"
  if item_ready(item)then site=near(pair,engine,item,r)end
 else
  -- Existing 1251 builds the consumer's distribution pole. The 0689/0691
  -- owner now knows recipe-free steam port requirements and routes pipes.
  -- Existing 0705/0707 energy family owns actual boiler fuel.
  return false,update(pair,"steam-machinery-present-await-fluid-fuel-or-grid",load)
 end
 local granted,why=request(pair,stage,item,site,load,r)
 update(pair,why,load)
 return granted,why
end
return M
