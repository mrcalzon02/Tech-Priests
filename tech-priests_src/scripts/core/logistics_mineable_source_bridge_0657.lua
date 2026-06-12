-- scripts/core/logistics_mineable_source_bridge_0657.lua
-- Tech Priests 0.1.657
--
-- Commandless logistics mineable-source bridge.
--
-- Crash wrecks and similar mineable entities can be catalogued as known sources
-- for plates/components even when they do not expose a normal inventory.  The
-- logistics fetch executor then walks to the wreck, asks for an inventory, gets
-- none, and the priest appears to stare at it.  This bridge treats adjacent
-- mineable known sources as salvage targets and mines them into the station work
-- inventory only after the priest is physically at the source.

local M = {}
M.version = "0.1.657"
M.storage_key = "logistics_mineable_source_bridge_0657"
M.tick_interval = 11
M.max_pairs_per_pulse = 32
M.pickup_radius_sq = 2.56
M.cooldown_ticks = 60 * 3

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, cooldowns = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.cooldowns = r.cooldowns or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(tonumber(r.stats[name]) or 0)+(n or 1) end
local function record(pair,event,detail)
  local r=root(); stat(event)
  r.recent[#r.recent+1]={tick=now(),event=tostring(event),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>100 do table.remove(r.recent,1) end
  if log then log("[Tech-Priests 0.1.657] "..tostring(event).." station="..safe(station_unit(pair)).." priest="..safe(priest_unit(pair)).." "..safe(detail)) end
end

local function station_count(pair,item)
  if not (valid_pair(pair) and item) then return 0 end
  if type(_G.tech_priests_0358_station_item_count)=="function" then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,item); if ok then return tonumber(n) or 0 end end
  if defines and defines.inventory and pair.station.get_inventory then local inv=pair.station.get_inventory(defines.inventory.chest); if inv and inv.valid then local ok,n=pcall(function() return inv.get_item_count(item) end); if ok then return tonumber(n) or 0 end end end
  return 0
end
local function station_inventory(pair)
  if not (valid_pair(pair) and defines and defines.inventory and pair.station.get_inventory) then return nil end
  local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
  if ok and inv and inv.valid then return inv end
  return nil
end
local function deposit(pair,item,count,reason)
  if not (valid_pair(pair) and item and count and count>0) then return 0 end
  if type(_G.tech_priests_safe_deposit_item)=="function" then local ok,did=pcall(_G.tech_priests_safe_deposit_item,pair,item,count,reason or "mineable-source-0657"); if ok and did then return count end end
  if type(_G.tech_priests_0358_try_deposit_to_station)=="function" then local ok,inserted=pcall(_G.tech_priests_0358_try_deposit_to_station,pair,item,count,reason or "mineable-source-0657"); if ok then return tonumber(inserted) or 0 end end
  local inv=station_inventory(pair); if inv then local ok,inserted=pcall(function() return inv.insert({name=item,count=count}) end); if ok then return tonumber(inserted) or 0 end end
  return 0
end
local function source_inventory(source)
  if not (valid(source) and defines and defines.inventory and source.get_inventory) then return nil end
  for _,id in ipairs({defines.inventory.chest,defines.inventory.assembling_machine_output,defines.inventory.furnace_result,defines.inventory.car_trunk,defines.inventory.spider_trunk,defines.inventory.character_corpse}) do
    if id then local ok,inv=pcall(function() return source.get_inventory(id) end); if ok and inv and inv.valid then return inv end end
  end
  return nil
end
local function mineable_has_item(entity,item)
  if not (valid(entity) and item) then return false end
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if not (ok and props) then return false end
  if props.products then
    for _,p in pairs(props.products) do local n=p.name or p[1]; if n==item then return true end end
  end
  return false
end
local function mining_output_count(entity,item)
  local ok, props = pcall(function() return entity.prototype and entity.prototype.mineable_properties end)
  if not (ok and props and props.products) then return 1 end
  for _,p in pairs(props.products) do
    local n=p.name or p[1]
    if n==item then return math.max(1, tonumber(p.amount or p.amount_min or p[2] or 1) or 1) end
  end
  return 1
end
local function active_fetch(pair)
  local f = pair and (pair.logistics_fetch_0527 or pair.logistics_fetch_0526)
  if type(f)=="table" and f.item and valid(f.source) and (f.phase=="moving-to-source" or f.phase=="source-adjacent" or f.phase=="mineable-source") then return f end
  return nil
end

function M.service_pair(pair,reason)
  local r=root(); if r.enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  local f=active_fetch(pair); if not f then return false,"no-active-fetch" end
  local item=f.item; local source=f.source
  if source_inventory(source) then return false,"source-has-inventory" end
  if not mineable_has_item(source,item) then return false,"not-mineable-for-item" end
  local key=safe(station_unit(pair))..":"..safe(source.unit_number or source.name)..":"..safe(item)
  if (r.cooldowns[key] or 0)>now() then return false,"cooldown" end
  if dist_sq(pair.priest.position, source.position)>M.pickup_radius_sq then return false,"not-adjacent" end
  local before=station_count(pair,item)
  local inv=station_inventory(pair)
  local mined=false
  if inv and source.mine then
    local ok,res=pcall(function() return source.mine({inventory=inv, force=pair.station.force, raise_destroyed=true, ignore_minable=false}) end)
    mined = ok and res == true
  end
  local after=station_count(pair,item)
  local gained=math.max(0, after-before)
  if gained <= 0 and valid(source) then
    local amount = mining_output_count(source,item)
    gained = deposit(pair,item,amount,"mineable-source-0657-manual")
    if gained > 0 then pcall(function() source.destroy({raise_destroy=true}) end) end
  end
  if gained > 0 then
    pair.logistics_fetch_0527={phase="deposited",item=item,count=gained,source_name=source.name,source_unit=source.unit_number,source_kind="mineable-source-0657",tick=now()}
    pair.logistics_fetch_0526=pair.logistics_fetch_0527
    pair.scavenge=nil; pair.inventory_scan=nil; pair.logistic_requested_item=nil
    pair.active_leaf_task_0655={version=M.version,tick=now(),family="logistics",phase="salvaged-source",item=item,label="Salvaged "..safe(item).." from "..safe(source.name),source="logistics_mineable_source_bridge_0657"}
    record(pair,"mineable-source-salvaged-0657","item="..safe(item).." gained="..safe(gained).." source="..safe(source.name).." mined="..safe(mined))
    return true,"salvaged"
  end
  r.cooldowns[key]=now()+M.cooldown_ticks
  record(pair,"mineable-source-failed-0657","item="..safe(item).." source="..safe(source.name))
  return false,"mine-failed"
end

function M.service_all(reason)
  local n=0
  for _,pair in pairs(pair_map()) do if n>=M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok,acted=pcall(M.service_pair,pair,reason or "pulse"); if ok and acted then n=n+1 end end end
  return n
end

function M.install()
  root(); _G.TechPriestsLogisticsMineableSourceBridge0657=M
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="logistics_mineable_source_bridge_0657",category="logistics",interval=M.tick_interval,priority=33,budget=6,fn=function(event,budget) M.service_all("broker"); return true end,note="salvage adjacent mineable crash wrecks used as known logistics sources"})
  else local R=rawget(_G,"TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end,{owner="logistics_mineable_source_bridge_0657",category="logistics",priority="early"}) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.657] logistics mineable source bridge installed; adjacent crash wrecks can satisfy known-source fetches") end
  return true
end

return M
