-- scripts/core/logistics_fetch_executor_0527.lua
-- Tech Priests 0.1.659
--
-- Universal physical logistics fetch executor.
--
-- This is the canonical inventory scavenging/fetch system.  If the scheduler,
-- dispatcher, construction planner, emergency craft path, or order queue needs
-- an item and there is a real nearby inventory or loose ground stack containing
-- that item, the priest must physically go to that source, remove the item from
-- that exact source, and deposit it into the Cogitator Station before raw mining,
-- primitive fallback, or emergency crafting are considered.

local M = {}
M.version = "0.1.659"
M.storage_key = "logistics_fetch_executor_0527"
M.pickup_radius_sq = 2.56
M.max_fetch_per_trip = 50
M.fetch_priority = 982
M.fetch_ttl = 60 * 10
M.cooldown_ticks = 60 * 2
M.search_radius_default = 36
M.search_radius_max = 72

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function pair_key(pair) local su=station_unit(pair); if su then return tostring(su) end local pu=priest_unit(pair); if pu then return "p"..tostring(pu) end return nil end
local function clean_item(name) name=tostring(name or ""); if name=="" or name=="nil" then return nil end return (name:gsub("%-"," ")) end

local function routed_find(surface, filters, category, negative_key, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local ents = select(1, Scan.find_entities(surface, filters, { category = category or "pickup", negative_key = negative_key, negative_ttl = ttl or 60 * 4 }))
    return ents or {}
  end
  local ok, ents = pcall(function() return surface.find_entities_filtered(filters) end)
  return (ok and ents) or {}
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, dispatcher_priority_fetch=true, stats={}, recent={}, cooldowns={} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_priority_fetch == nil then r.dispatcher_priority_fetch = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.cooldowns = r.cooldowns or {}
  return r
end
local function stat(name,n) local r=M.root(); r.stats[name]=(tonumber(r.stats[name]) or 0)+(n or 1) end
local function record(pair,event,detail)
  local r=M.root(); stat(event)
  local rec={tick=now(),event=tostring(event or "event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent>160 do table.remove(r.recent,1) end
  if pair then pair.logistics_fetch_0527_last=rec; pair.logistics_fetch_0526_last=rec end
  return rec
end

local function normalize_item(v)
  if type(v)=="string" then
    if v=="ammo" or v=="ammunition" or v=="magazine" then return "firearm-magazine" end
    if v=="repair" then return "repair-pack" end
    return v
  end
  if type(v)~="table" then return nil end
  local cur=v.current or v.request or v.task or v
  return normalize_item(cur.item or cur.item_name or cur.output_item or cur.requested_item or cur.wanted_item or cur.target_item or cur.name or cur.resource)
end
local function requested_count_from_order(o,item)
  if type(o)~="table" then return nil end
  local cur=o.current or o.request or o.task or o
  for _,k in ipairs({"missing_count","needed_count","need_count","required_count","target_count","requested_count","amount","quantity","count"}) do local n=tonumber(cur[k]); if n and n>0 then return n end end
  return nil
end
local function parse_blocker_need(pair,item)
  if not (pair and item) then return nil end
  local escaped=item:gsub("%-","%%-")
  for _,field in ipairs({"blocker","last_blocker","emergency_blocker","priority_blocker","status","last_status"}) do
    local s=tostring(pair[field] or "")
    local have,need=s:match(escaped.."%s*%((%d+)%s*/%s*(%d+)%)")
    if need then return tonumber(need) end
    have,need=s:match("lacks%s+"..escaped.."%s*%((%d+)%s*/%s*(%d+)%)")
    if need then return tonumber(need) end
  end
  return nil
end
local function active_request(pair)
  if not pair then return nil end
  local q=pair.order_queue_0469
  local o=(q and q.current) or pair.active_order_0469
  local item=normalize_item(o)
  local kind=lower(type(o)=="table" and (o.kind or o.type or o.source or o.key) or "")
  if item and (kind=="" or kind:find("logistic",1,true) or kind:find("supply",1,true) or kind:find("gather",1,true) or kind:find("acqui",1,true) or kind:find("scavenge",1,true) or kind:find("emergency",1,true) or kind:find("construction",1,true) or kind:find("craft",1,true)) then
    return {item=item,count=requested_count_from_order(o,item) or parse_blocker_need(pair,item) or 1,source="order-queue"}
  end
  for _,field in ipairs({"active_supply_request","supply_request","logistic_requested_item","requested_item","scavenge","inventory_scan","emergency_craft","station_crafting_task_0337","direct_acquisition_task_0336","active_acquisition_0333"}) do
    item=normalize_item(pair[field])
    if item then return {item=item,count=requested_count_from_order(pair[field],item) or parse_blocker_need(pair,item) or 1,source=field} end
  end
  local mode=lower(pair.mode or "")
  if mode:find("ammo",1,true) or mode:find("survival%-ammo") then return {item="firearm-magazine",count=parse_blocker_need(pair,"firearm-magazine") or 10,source="mode-ammo"} end
  if mode:find("repair",1,true) then return {item="repair-pack",count=parse_blocker_need(pair,"repair-pack") or 1,source="mode-repair"} end
  local op=pair.independent_emergency_operation_0184 or pair.independent_emergency_operation or pair.emergency_operation
  item=normalize_item(op and (op.last_item or op.requested_item or op.item or op.item_name))
  if item then return {item=item,count=requested_count_from_order(op,item) or parse_blocker_need(pair,item) or 1,source="emergency-operation"} end
  return nil
end
local function active_requested_item(pair) local req=active_request(pair); return req and req.item or nil end

local function station_count(pair,item)
  if not (valid_pair(pair) and item) then return 0 end
  if type(_G.tech_priests_0358_station_item_count)=="function" then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,item); if ok then return tonumber(n) or 0 end end
  local inv=pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest)
  if inv and inv.valid then local ok,n=pcall(function() return inv.get_item_count(item) end); if ok then return tonumber(n) or 0 end end
  return 0
end
local function source_inventory(source,inv_id)
  if not valid(source) then return nil end
  if inv_id and source.get_inventory then local ok,inv=pcall(function() return source.get_inventory(inv_id) end); if ok and inv and inv.valid then return inv end end
  if not (defines and defines.inventory and source.get_inventory) then return nil end
  local d=defines.inventory
  local ids={d.chest,d.assembling_machine_output,d.assembling_machine_input,d.furnace_result,d.furnace_source,d.fuel,d.burnt_result,d.lab_input,d.rocket_silo_result,d.rocket_silo_output,d.car_trunk,d.spider_trunk,d.cargo_wagon,d.character_corpse,d.roboport_material,d.roboport_robot,d.turret_ammo,d.artillery_turret_ammo}
  for _,id in ipairs(ids) do if id then local ok,inv=pcall(function() return source.get_inventory(id) end); if ok and inv and inv.valid then return inv end end end
  return nil
end
local function inventory_count(inv,item) if not (inv and inv.valid and item) then return 0 end local ok,n=pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function deposit_to_station(pair,item,count)
  if not (valid_pair(pair) and item and count and count>0) then return 0 end
  if type(_G.tech_priests_safe_deposit_item)=="function" then local ok,did=pcall(_G.tech_priests_safe_deposit_item,pair,item,count,"logistics-fetch-0527"); if ok and did then return count end end
  if type(_G.tech_priests_0358_try_deposit_to_station)=="function" then local ok,inserted=pcall(_G.tech_priests_0358_try_deposit_to_station,pair,item,count,"logistics-fetch-0527"); if ok then return tonumber(inserted) or 0 end end
  local inv=pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest)
  if inv and inv.valid then local ok,inserted=pcall(function() return inv.insert({name=item,count=count}) end); if ok then return tonumber(inserted) or 0 end end
  return 0
end

local function catalog_storage_source(pair,item)
  if not (valid_pair(pair) and item) then return nil end
  local okCat,Catalog=pcall(require,"scripts.core.station_catalog")
  if okCat and Catalog and type(Catalog.find_known_source)=="function" then local ok,src=pcall(Catalog.find_known_source,pair,item); if ok and src and src.kind=="known-storage-0327" and valid(src.source) and src.source~=pair.station then return src end end
  local cat=nil
  if type(_G.tech_priests_0327_scan_station_catalog)=="function" then local ok,c=pcall(_G.tech_priests_0327_scan_station_catalog,pair); if ok then cat=c end end
  if (not cat) and type(_G.tech_priests_0327_get_station_catalog)=="function" then local ok,c=pcall(_G.tech_priests_0327_get_station_catalog,pair); if ok then cat=c end end
  local rec=cat and cat.storage_items and cat.storage_items[item]
  if rec then
    local best=nil
    for _,inst in ipairs(rec.instances or {}) do if inst and valid(inst.entity) and inst.entity~=pair.station then if (not best) or ((inst.distance_sq or 999999999)<(best.distance_sq or 999999999)) then best=inst end end end
    if best then return {kind="known-storage-0327",source=best.entity,inventory_id=best.inventory_id,item_name=item,count=best.count or 1,station_distance_sq=best.distance_sq or 0} end
    if valid(rec.entity) and rec.entity~=pair.station then return {kind="known-storage-0327",source=rec.entity,inventory_id=rec.inventory_id,item_name=item,count=rec.count or 1,station_distance_sq=rec.distance_sq or 0} end
  end
  return nil
end
local function loose_ground_source(pair,item)
  if not (valid_pair(pair) and item) then return nil end
  local r=tonumber(pair.radius) or 24
  if type(_G.get_station_operating_radius)=="function" then local ok,rr=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(rr) then r=tonumber(rr) end end
  r=math.max(8,math.min(M.search_radius_max,tonumber(r) or 24))
  local p=pair.station.position
  local ents=routed_find(pair.station.surface,{area={{p.x-r,p.y-r},{p.x+r,p.y+r}},type="item-entity",limit=128},"pickup","pickup:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..tostring(station_unit(pair) or "?")..":"..tostring(item),60*4)
  local best,bd=nil,nil
  for _,e in pairs(ents or {}) do if valid(e) and e.stack and e.stack.valid_for_read and e.stack.name==item then local d=dist_sq(e.position,pair.station.position); if not bd or d<bd then best,bd=e,d end end end
  if best then return {kind="loose-ground-item-0527",source=best,item_name=item,count=best.stack and best.stack.count or 1,station_distance_sq=bd or 0} end
  return nil
end
local function nearby_storage_source(pair,item)
  if not (valid_pair(pair) and item) then return nil end
  local r=tonumber(pair.radius) or M.search_radius_default
  if type(_G.get_station_operating_radius)=="function" then local ok,rr=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(rr) then r=tonumber(rr) end end
  r=math.max(8,math.min(M.search_radius_max,tonumber(r) or M.search_radius_default))
  local p=pair.station.position
  local types={"container","logistic-container","assembling-machine","furnace","mining-drill","lab","car","spider-vehicle","cargo-wagon","artillery-wagon","rocket-silo","roboport","ammo-turret","artillery-turret","character-corpse"}
  local ents=routed_find(pair.station.surface,{area={{p.x-r,p.y-r},{p.x+r,p.y+r}},type=types,limit=512},"logistics-fetch-storage","logistics-fetch-storage:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..tostring(station_unit(pair) or "?")..":"..tostring(item),60*2)
  local best,best_inv,best_inv_id,best_count,best_score,best_d=nil,nil,nil,nil,nil,nil
  local d=defines and defines.inventory or {}
  local ids={d.chest,d.assembling_machine_output,d.assembling_machine_input,d.furnace_result,d.furnace_source,d.fuel,d.burnt_result,d.lab_input,d.rocket_silo_result,d.rocket_silo_output,d.car_trunk,d.spider_trunk,d.cargo_wagon,d.character_corpse,d.roboport_material,d.roboport_robot,d.turret_ammo,d.artillery_turret_ammo}
  for _,e in pairs(ents or {}) do
    if valid(e) and e~=pair.station and e~=pair.priest and (not e.force or e.force==pair.station.force or e.force.name=="neutral") then
      local d_station=dist_sq(e.position,pair.station.position)
      if d_station<=r*r then
        for _,inv_id in ipairs(ids) do
          local inv=source_inventory(e,inv_id)
          local n=inventory_count(inv,item)
          if n>0 then
            local score=dist_sq(e.position,pair.priest.position)+(d_station*0.10)
            if not best_score or score<best_score then best,best_inv,best_inv_id,best_count,best_score,best_d=e,inv,inv_id,n,score,d_station end
          end
        end
      end
    end
  end
  if best then stat("nearby-storage-fallback-hit"); return {kind="nearby-storage-0659",source=best,inventory_id=best_inv_id,item_name=item,count=best_count or 1,station_distance_sq=best_d or 0} end
  stat("nearby-storage-fallback-miss"); return nil
end
local function known_fetch_source(pair,item) return catalog_storage_source(pair,item) or nearby_storage_source(pair,item) or loose_ground_source(pair,item) end

local function movement_root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419=storage.tech_priests.movement_controller_0419 or {requests={},active_request_ids={},stats={}}
  local r=storage.tech_priests.movement_controller_0419; r.requests=r.requests or {}; r.active_request_ids=r.active_request_ids or {}; return r
end
local function publish_leaf(pair,src,item,phase)
  local label
  if phase=="deposited" then label="Fetched "..safe(item).." from "..safe(src.source and src.source.name) else label="Fetching "..(clean_item(item) or safe(item)).." from "..safe(src.source and src.source.name) end
  pair.active_leaf_task_0655={version=M.version,tick=now(),family="logistics",phase=phase or "fetch-source",item=item,label=label,target_name=src.source and src.source.name,target_unit=src.source and src.source.unit_number,x=src.source and src.source.position.x,y=src.source and src.source.position.y,source="logistics_fetch_executor_0527"}
  pair.actual_task_status_0655=pair.active_leaf_task_0655
  pair.current_work_target_0655=src.source
  pair.target=src.source
end
local function request_move(pair,src,item)
  if not (valid_pair(pair) and src and valid(src.source)) then return false end
  local pos=src.source.position
  local key=pair_key(pair)
  if key then
    local mr=movement_root()
    local req={x=pos.x,y=pos.y,radius=1.15,reason="known-source-fetch-0527",owner="logistics-fetch-0527",priority=M.fetch_priority,distraction=defines and defines.distraction and defines.distraction.none or nil,issued_tick=now(),updated_tick=now(),expires_tick=now()+M.fetch_ttl,item=item,target_name=src.source.name,target_unit=src.source.unit_number,logistics_fetch_0527=true}
    mr.requests[key]=req; mr.active_request_ids[key]=true; pair.movement_request_0418=req; pair.movement_controller_owner_0418=req.owner; pair.movement_controller_reason_0418=req.reason; pair.movement_controller_clamp_0418=nil; pair.movement_controller_state_0418="logistics-fetch-0527"
  end
  local ok=false
  if _G.tech_priests_request_movement_0418 then local ok_call,res=pcall(_G.tech_priests_request_movement_0418,pair,pos,"known-source-fetch-0527",{owner="logistics-fetch-0527",priority=M.fetch_priority,ttl=M.fetch_ttl,radius=1.15,distraction=defines and defines.distraction and defines.distraction.none or nil}); ok=ok_call and res~=false end
  if not ok and defines and defines.command then pcall(function() local command={type=defines.command.go_to_location,destination={x=pos.x,y=pos.y},radius=1.15,distraction=defines.distraction and defines.distraction.none or nil}; if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok=true elseif pair.priest.set_command then pair.priest.set_command(command); ok=true end end) end
  if ok then
    pair.mode="moving-to-known-source"
    pair.logistics_fetch_0527={phase="moving-to-source",item=item,source=src.source,source_unit=src.source.unit_number,source_name=src.source.name,inventory_id=src.inventory_id,source_kind=src.kind,x=pos.x,y=pos.y,tick=now()}
    pair.logistics_fetch_0526=pair.logistics_fetch_0527
    publish_leaf(pair,src,item,"moving-to-source")
    record(pair,"move-to-known-source",tostring(item).." from "..tostring(src.source.name).."#"..tostring(src.source.unit_number or "?").." kind="..safe(src.kind))
    return true
  end
  return false
end

function M.service_pair(pair,reason)
  local r=M.root(); if r.enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  if valid(pair.combat_target) then return false,"combat-has-priority" end
  local req=active_request(pair); local item=req and req.item or nil
  if not item then return false,"no-item-intent" end
  local have_station=station_count(pair,item)
  local need_total=math.max(1,tonumber(req.count) or 1)
  local need_remaining=math.max(1,need_total-have_station)
  if have_station>=need_total then return false,"already-in-station" end
  local src=known_fetch_source(pair,item)
  if not (src and valid(src.source)) then return false,"no-known-fetch-source" end
  local key=tostring(station_unit(pair))..":"..tostring(item)..":"..tostring(src.source.unit_number or src.source.name)..":"..safe(src.inventory_id or src.kind)
  if (r.cooldowns[key] or 0)>now() then return false,"cooldown" end
  local d2=dist_sq(pair.priest.position,src.source.position)
  if d2>M.pickup_radius_sq then
    local moved=request_move(pair,src,item)
    if not moved then r.cooldowns[key]=now()+math.min(M.cooldown_ticks,60); record(pair,"movement-request-failed-0527",tostring(item).." from "..tostring(src.source.name).."#"..tostring(src.source.unit_number or "?")); return false,"movement-request-failed" end
    return true,"moving-to-known-source"
  end
  local removed=0; local inv=nil
  if src.kind=="loose-ground-item-0527" then
    local stack=src.source.stack
    local have=(stack and stack.valid_for_read and stack.name==item) and (tonumber(stack.count) or 0) or 0
    if have<=0 then r.cooldowns[key]=now()+M.cooldown_ticks; return false,"source-empty" end
    local want=math.max(1,math.min(M.max_fetch_per_trip,need_remaining,have)); removed=want
    local left=have-want
    if left<=0 then pcall(function() src.source.destroy() end) else pcall(function() stack.count=left end) end
  else
    inv=source_inventory(src.source,src.inventory_id)
    if not (inv and inv.valid) then r.cooldowns[key]=now()+M.cooldown_ticks; return false,"no-source-inventory" end
    local have=inventory_count(inv,item)
    if have<=0 then r.cooldowns[key]=now()+M.cooldown_ticks; return false,"source-empty" end
    local want=math.max(1,math.min(M.max_fetch_per_trip,need_remaining,have))
    pcall(function() removed=inv.remove({name=item,count=want}) end); removed=tonumber(removed) or 0
  end
  if removed<=0 then r.cooldowns[key]=now()+M.cooldown_ticks; return false,"remove-failed" end
  local inserted=deposit_to_station(pair,item,removed)
  if inserted<removed then if inv and inv.valid then pcall(function() inv.insert({name=item,count=removed-inserted}) end) else pcall(function() pair.station.surface.spill_item_stack{position=pair.priest.position,stack={name=item,count=removed-inserted},force=pair.station.force,allow_belts=false} end) end end
  pair.logistics_fetch_0527={phase="deposited",item=item,count=inserted,requested=need_total,remaining_after=math.max(0,need_total-station_count(pair,item)),source_name=src.source.name,source_unit=src.source.unit_number,source_kind=src.kind,inventory_id=src.inventory_id,tick=now()}
  pair.logistics_fetch_0526=pair.logistics_fetch_0527
  if inserted>0 then
    pair.scavenge=nil; pair.inventory_scan=nil; pair.logistic_requested_item=nil
    publish_leaf(pair,src,item,"deposited")
    record(pair,"fetched-known-source",tostring(item).." x"..tostring(inserted).." from "..tostring(src.source.name).."#"..tostring(src.source.unit_number or "?").." need="..tostring(need_total).." source="..tostring(req.source or "?").." kind="..safe(src.kind))
    return true,"fetched-known-source"
  end
  return false,"deposit-failed"
end

local function patch_dispatcher()
  local okD,D=pcall(require,"scripts.core.single_dispatcher_0510")
  if not (okD and D and type(D.service_pair)=="function") or D.TECH_PRIESTS_0527_FETCH_WRAPPED then return false end
  D.TECH_PRIESTS_0527_FETCH_WRAPPED=true
  D.TECH_PRIESTS_0527_PRE_SERVICE_PAIR=D.service_pair
  D.service_pair=function(pair,reason,...)
    local r=M.root()
    if r.enabled~=false and r.dispatcher_priority_fetch~=false and valid_pair(pair) then
      local acted,why=M.service_pair(pair,reason or "dispatcher-0527")
      if acted then
        pair.dispatcher_0510=pair.dispatcher_0510 or {}; pair.dispatcher_0510.tick=now(); pair.dispatcher_0510.action="logistics-fetch"; pair.dispatcher_0510.family="logistics"; pair.dispatcher_0510.reason=tostring(why or "known-source-fetch-0527"); pair.dispatcher_0510.acted=true; pair.dispatcher_0510.result=tostring(why or "known-source-fetch-0527")
        if type(_G.tech_priests_0507_action_claim)=="function" then pcall(_G.tech_priests_0507_action_claim,pair,"logistics-fetch","logistics_fetch_executor_0527",why or "known-source-fetch") end
        return true,why
      end
    end
    return D.TECH_PRIESTS_0527_PRE_SERVICE_PAIR(pair,reason,...)
  end
  return true
end
function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local item=active_requested_item(pair); local src=item and known_fetch_source(pair,item) or nil; local fetch=pair.logistics_fetch_0527 or pair.logistics_fetch_0526 or {}
  return "enabled="..tostring(M.root().enabled).." item="..tostring(item or "none").." station_count="..tostring(item and station_count(pair,item) or 0).." source="..tostring(src and src.source and (src.source.name.."#"..tostring(src.source.unit_number or "?")) or "none").." source_kind="..safe(src and src.kind).." fetch="..tostring(fetch.phase or "none")
end
local function wrap_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.logistics_fetch_0527_wrapped then return false end
  local prev=diag.pair_dump_lines; diag.logistics_fetch_0527_wrapped=true
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 LOGISTICS-FETCH-0527 BEGIN enabled="..tostring(r.enabled).." fetched="..safe(r.stats["fetched-known-source"] or 0).." moves="..safe(r.stats["move-to-known-source"] or 0)
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then lines[#lines+1]="PAIR-DUMP-0468 logistics-fetch["..safe(station_unit(pair)).."] "..M.describe_pair(pair) end end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 logistics-fetch.recent["..tostring(i).."] tick="..safe(ev.tick).." event="..safe(ev.event).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail) end end
    lines[#lines+1]="PAIR-DUMP-0468 LOGISTICS-FETCH-0527 END"; return lines
  end
  return true
end
function M.install()
  M.root(); patch_dispatcher(); wrap_diagnostics(); _G.TECH_PRIESTS_LOGISTICS_FETCH_EXECUTOR_0527=M
  if log then log("[Tech-Priests 0.1.659] universal physical logistics fetch executor loaded; broadened nearby inventory scavenging replaces duplicate 0658") end
  return true
end
return M
