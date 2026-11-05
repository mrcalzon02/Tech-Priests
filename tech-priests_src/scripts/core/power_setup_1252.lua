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
-- 1263: one shared Factorio-native electricity authority for both the
-- 1251 laboratory and 1252 generator planners. Geometric coverage proposes
-- a site; LuaEntity electric_network_id verifies a real installed connection.
local NativeElectric=require("scripts.core.native_electric_authority_1263")
local pole_supplies_entity=NativeElectric.coverage_at
local function near(pair,entity,item,r)
 -- Find real, engine-placeable sites inside this station's territory.
 -- Machines retain the bounded layout; 1256 broadens electric pole sites
 -- to the *native* supply square rather than eight easily obstructed axes.
 -- No pole, power, pipe or fluid is created by this read-only search.
 local best
 local function consider(p,direction)
  if legal(pair,item,p,direction,r)then
   local score=d2(p,pair.station.position)+d2(p,entity.position)*.01
   if not best or score<best.score then
    best={position=p,direction=direction,score=score}
   end
  end
 end
 if item=="small-electric-pole"then
  local prototype=prototypes and prototypes.entity
    and prototypes.entity["small-electric-pole"]
  local supply
  if prototype then
   pcall(function()supply=tonumber(prototype.supply_area_distance)end)
  end
  -- An unknown supply radius does NOT authorize an invented connection.
  if not(supply and supply>0 and supply<=64)then return nil end
  local box
  pcall(function()box=entity.bounding_box end)
  local left,right,top,bottom=entity.position.x,entity.position.x,
    entity.position.y,entity.position.y
  if box and box.left_top and box.right_bottom then
   left,right=box.left_top.x,box.right_bottom.x
   top,bottom=box.left_top.y,box.right_bottom.y
  end
  for x=math.floor(left-supply)-1,math.ceil(right+supply) do
   for y=math.floor(top-supply)-1,math.ceil(bottom+supply) do
    local p={x=x+.5,y=y+.5}
    if pole_supplies_entity(p,entity,supply)then consider(p,nil)end
   end
  end
 else
  local offsets={{4,0},{-4,0},{0,4},{0,-4},
   {5,2},{-5,2},{5,-2},{-5,-2},
   {0,6},{0,-6},{6,0},{-6,0},
   {7,3},{-7,3},{7,-3},{-7,-3}}
  for _,v in ipairs(offsets)do
   local p={x=math.floor(entity.position.x+v[1])+.5,
            y=math.floor(entity.position.y+v[2])+.5}
   for _,direction in ipairs(dirs())do consider(p,direction)end
  end
 end
 return best
end
local function pole_covering(pair,e,r)
 for _,pole in ipairs(find(pair,{"electric-pole"},r))do
  local connected=NativeElectric.real_pole_covers(pole,e)
  if connected then return pole end
 end
 return nil
end
-- Factorio's exact electricity network identity is authoritative. Geometric
-- overlap alone does not establish a functioning generator or lab connection.
local network_id=NativeElectric.network_id
local function pole_wire_reach(pole)
 local proto=valid(pole)and pole.prototype
 local dist=nil
 if proto then
  pcall(function()dist=tonumber(proto.maximum_wire_distance)end)
  if not dist then
   pcall(function()dist=tonumber(proto.get_max_wire_distance())end)
  end
 end
 if not dist then
  local v=prototypes and prototypes.entity
   and prototypes.entity["small-electric-pole"]
  if v then
   pcall(function()dist=tonumber(v.maximum_wire_distance)end)
   if not dist then
    pcall(function()dist=tonumber(v.get_max_wire_distance())end)
   end
  end
 end
 return type(dist)=="number"and dist>1 and dist or nil
end
local function bridge_site(pair,from,to,reach,r)
 local dx=to.position.x-from.position.x
 local dy=to.position.y-from.position.y
 local distance=math.sqrt(dx*dx+dy*dy)
 -- Even two physically close poles can inhabit distinct copper networks.
 -- A new real pole between them may let Factorio auto-connect both; proximity
 -- alone does not give us permission to declare them wired or powered.
 local nearby_split=distance<=reach
 if distance<0.5 then return nil,"coincident-poles-without-network-link"end
 -- Real pole wire reach comes from its Factorio prototype; leave margin
 -- so the new pole is strictly inside the existing pole's native range.
 local hop=nearby_split and distance*.5
    or math.min(distance-1.5,reach-1.25)
 if hop<1 and not nearby_split then return nil,"wire-hop-too-short"end
 local mid={x=from.position.x+dx*hop/distance,
            y=from.position.y+dy*hop/distance}
 local offsets={{0,0},{0,1},{0,-1},{1,0},{-1,0},
  {1,1},{-1,1},{1,-1},{-1,-1}}
 local best
 for _,off in ipairs(offsets)do
  local pos={x=math.floor(mid.x+off[1])+.5,
             y=math.floor(mid.y+off[2])+.5}
  if d2(pos,from.position)<=(reach-.25)^2
     and d2(pos,to.position)<d2(from.position,to.position)
     and (not nearby_split or d2(pos,to.position)<=(reach-.25)^2)
     and legal(pair,"small-electric-pole",pos,nil,r)then
   local score=d2(pos,to.position)
   if not best or score<best.score then
    best={position=pos,score=score,nearby_split=nearby_split}
   end
  end
 end
 return best,best and (nearby_split
    and"native-disconnected-near-pole-repair-site"
    or"native-wire-range-site")
    or"no-legal-physical-wire-bridge-site"
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
 if stage=="native-copper-network-bridge"then
  -- Persist the last physically authorized attempt. If 0338 builds it but
  -- Factorio still reports split networks, do not consume an endless series
  -- of stocked poles pretending that an actual copper connection occurred.
  pair.power_setup_last_bridge_1252={
   position={x=site.position.x,y=site.position.y},
   load_unit=load and load.unit_number,
   nearby_split=site.nearby_split==true,
  }
 end
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
function M.service_pair(pair,opts)
 if opts and opts.audit_only==true then
  return false,"power-setup-audit-only"
 end
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
  -- Generator, water pump and boiler are physically installed. The steam
  -- and coal feed are still separately owned by 0689/0691 and 0705/0707.
  -- A pole at the generator is NOT evidence that the consumer is on the
  -- same network. First request a true consumer pole where needed.
  local source=pole_covering(pair,engine,r)
  local sink=pole_covering(pair,load,r)
  if not sink then
   if load.type=="lab"then
    -- 1251 already selects a true native laboratory-covering pole.
    return false,update(pair,"steam-machinery-present-await-fluid-fuel-or-grid",load)
   end
   item="small-electric-pole";stage="consumer-electric-pole"
   if item_ready(item)then site=near(pair,load,item,r)end
  else
   local source_id,sink_id=network_id(source),network_id(sink)
   if source_id and sink_id and source_id==sink_id then
    return false,update(pair,
      "shared-native-electric-network-await-fuel-or-generation",load)
   end
   local reach=pole_wire_reach(source)
   if not(source_id and sink_id and reach)then
    return false,update(pair,
      "unobservable-electric-pole-copper-network-or-wire-reach",load)
   end
   local candidates=find(pair,{"electric-pole"},r)
   local previous=pair.power_setup_last_bridge_1252
   if type(previous)=="table" and previous.position
       and previous.load_unit==load.unit_number then
    for _,pole in ipairs(candidates)do
     if d2(pole.position,previous.position)<.10 then
      local built_id=network_id(pole)
      if not built_id then
       return false,update(pair,"physical-bridge-network-unobservable",load)
      elseif built_id~=source_id then
       return false,update(pair,"physical-bridge-not-attached-to-generator-network",load)
      elseif previous.nearby_split and built_id~=sink_id then
       return false,update(pair,
         "physical-adjacent-bridge-did-not-join-sink-network",load)
      end
      break
     end
    end
   end
   local from=source
   for _,pole in ipairs(candidates)do
    if network_id(pole)==source_id
     and d2(pole.position,sink.position)<d2(from.position,sink.position)then
     from=pole
    end
   end
   local limit=math.min(reach,pole_wire_reach(sink)or reach)
   local point,why=bridge_site(pair,from,sink,limit,r)
   if not point then return false,update(pair,why,load)end
   item="small-electric-pole";stage="native-copper-network-bridge"
   site=point
  end
 end
 local granted,why=request(pair,stage,item,site,load,r)
 update(pair,why,load)
 return granted,why
end
return M
