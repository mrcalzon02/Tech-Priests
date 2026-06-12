-- scripts/core/nearby_inventory_scavenge_authority_0658.lua
-- Tech Priests 0.1.658
--
-- Commandless nearby inventory scavenge authority.
--
-- Purpose: when the station needs an item, first look for a real nearby
-- inventory that already contains it, then physically send the priest to that
-- entity, remove the item from the exact inventory, and deposit it into the
-- Cogitator Station.  This covers wreck inventories, machine outputs, furnace
-- results, chests, vehicles, corpses, labs, drills, and other scavengable local
-- containers before raw mining or emergency fabrication are considered.

local M = {}
M.version = "0.1.658"
M.storage_key = "nearby_inventory_scavenge_authority_0658"
M.tick_interval = 7
M.max_pairs_per_pulse = 36
M.search_radius_default = 36
M.search_radius_max = 72
M.pickup_radius_sq = 2.56
M.max_fetch_per_trip = 50
M.ttl = 60 * 8
M.command_cooldown = 18
M.cooldown_ticks = 60 * 2
M.priority = 982

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_key(pair) local su=station_unit(pair); if su then return tostring(su) end local pu=priest_unit(pair); if pu then return "p"..tostring(pu) end return nil end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function clean_item(name) name=tostring(name or ""); if name=="" or name=="nil" then return nil end return (name:gsub("%-"," ")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, cooldowns={} }
  local r=storage.tech_priests[M.storage_key]
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.cooldowns=r.cooldowns or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(tonumber(r.stats[name]) or 0)+(n or 1) end
local function record(pair,event,detail)
  local r=root(); stat(event)
  r.recent[#r.recent+1]={tick=now(),event=tostring(event),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>140 do table.remove(r.recent,1) end
  if pair then pair.nearby_inventory_scavenge_0658_last={tick=now(),event=event,detail=detail} end
end

local function normalize_item(v)
  if type(v)=="string" then if v=="ammo" or v=="ammunition" or v=="magazine" then return "firearm-magazine" end; if v=="repair" then return "repair-pack" end; return v end
  if type(v)~="table" then return nil end
  local cur=v.current or v.request or v.task or v
  return normalize_item(cur.item or cur.item_name or cur.output_item or cur.requested_item or cur.wanted_item or cur.target_item or cur.name or cur.resource)
end
local function requested_count_from(v)
  if type(v)~="table" then return nil end
  local cur=v.current or v.request or v.task or v
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
  if item then return { item=item, count=requested_count_from(o) or parse_blocker_need(pair,item) or 1, source="order-queue" } end
  for _,field in ipairs({"active_supply_request","supply_request","logistic_requested_item","requested_item","scavenge","inventory_scan","emergency_craft","station_crafting_task_0337","direct_acquisition_task_0336","active_acquisition_0333"}) do
    item=normalize_item(pair[field])
    if item then return { item=item, count=requested_count_from(pair[field]) or parse_blocker_need(pair,item) or 1, source=field } end
  end
  local mode=lower(pair.mode or "")
  if mode:find("ammo",1,true) then return { item="firearm-magazine", count=parse_blocker_need(pair,"firearm-magazine") or 10, source="mode-ammo" } end
  if mode:find("repair",1,true) then return { item="repair-pack", count=parse_blocker_need(pair,"repair-pack") or 1, source="mode-repair" } end
  return nil
end
local function station_count(pair,item)
  if not (valid_pair(pair) and item) then return 0 end
  if type(_G.tech_priests_0358_station_item_count)=="function" then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,item); if ok then return tonumber(n) or 0 end end
  if defines and defines.inventory and pair.station.get_inventory then local inv=pair.station.get_inventory(defines.inventory.chest); if inv and inv.valid then local ok,n=pcall(function() return inv.get_item_count(item) end); if ok then return tonumber(n) or 0 end end end
  return 0
end
local function deposit(pair,item,count,reason)
  if not (valid_pair(pair) and item and count and count>0) then return 0 end
  if type(_G.tech_priests_safe_deposit_item)=="function" then local ok,did=pcall(_G.tech_priests_safe_deposit_item,pair,item,count,reason or "nearby-inventory-scavenge-0658"); if ok and did then return count end end
  if type(_G.tech_priests_0358_try_deposit_to_station)=="function" then local ok,inserted=pcall(_G.tech_priests_0358_try_deposit_to_station,pair,item,count,reason or "nearby-inventory-scavenge-0658"); if ok then return tonumber(inserted) or 0 end end
  if defines and defines.inventory and pair.station.get_inventory then local inv=pair.station.get_inventory(defines.inventory.chest); if inv and inv.valid then local ok,inserted=pcall(function() return inv.insert({name=item,count=count}) end); if ok then return tonumber(inserted) or 0 end end end
  return 0
end

local function inv_ids()
  local d=defines and defines.inventory or {}
  return { d.chest, d.assembling_machine_output, d.assembling_machine_input, d.furnace_result, d.furnace_source, d.fuel, d.burnt_result, d.lab_input, d.rocket_silo_result, d.rocket_silo_output, d.car_trunk, d.spider_trunk, d.cargo_wagon, d.character_corpse, d.roboport_material, d.roboport_robot, d.turret_ammo, d.artillery_turret_ammo }
end
local function source_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok,inv=pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end
local function inventory_count(inv,item) if not (inv and inv.valid and item) then return 0 end local ok,n=pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function remove_items(inv,item,count)
  if not (inv and inv.valid and item and count and count>0) then return 0 end
  local ok,removed=pcall(function() return inv.remove({name=item,count=count}) end)
  return ok and (tonumber(removed) or 0) or 0
end
local function radius_for(pair)
  local r=tonumber(pair and pair.radius) or M.search_radius_default
  if valid_pair(pair) and type(_G.get_station_operating_radius)=="function" then local ok,rr=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(rr) then r=tonumber(rr) end end
  return math.max(8, math.min(M.search_radius_max, tonumber(r) or M.search_radius_default))
end
local function entity_allowed(e,pair)
  if not (valid(e) and valid_pair(pair)) then return false end
  if e==pair.station or e==pair.priest then return false end
  if e.force and pair.station.force and e.force~=pair.station.force and e.force.name~="neutral" then return false end
  if e.type=="resource" or e.type=="tree" then return false end
  return true
end
local function scan_inventory_source(pair,item)
  if not (valid_pair(pair) and item) then return nil end
  local r=root(); local radius=radius_for(pair); local p=pair.station.position
  local ok,ents=pcall(function() return pair.station.surface.find_entities_filtered({ area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}}, limit=512 }) end)
  if not (ok and ents) then return nil end
  local best=nil
  for _,e in pairs(ents) do
    if entity_allowed(e,pair) and dist_sq(e.position,pair.station.position)<=radius*radius then
      for _,id in ipairs(inv_ids()) do
        local inv=source_inventory(e,id)
        local n=inventory_count(inv,item)
        if n>0 then
          local d_station=dist_sq(e.position,pair.station.position)
          local d_priest=dist_sq(e.position,pair.priest.position)
          local score=d_priest + d_station*0.10
          if not best or score<best.score then best={source=e,inventory=inv,inventory_id=id,item=item,count=n,score=score,distance_sq=d_station} end
        end
      end
    end
  end
  if best then stat("source-found") else stat("source-miss") end
  return best
end
local function movement_root()
  storage.tech_priests=storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419=storage.tech_priests.movement_controller_0419 or {requests={},active_request_ids={},stats={}}
  local r=storage.tech_priests.movement_controller_0419; r.requests=r.requests or {}; r.active_request_ids=r.active_request_ids or {}; return r
end
local function publish_leaf(pair,src,phase)
  local label=(phase=="moving" and "Scavenging " or "Looting ")..(clean_item(src.item) or safe(src.item)).." from "..safe(src.source.name)
  pair.active_leaf_task_0655={version=M.version,tick=now(),family="logistics",phase=phase or "scavenge-inventory",item=src.item,label=label,target_name=src.source.name,target_unit=src.source.unit_number,x=src.source.position.x,y=src.source.position.y,source="nearby_inventory_scavenge_authority_0658"}
  pair.actual_task_status_0655=pair.active_leaf_task_0655
  pair.current_work_target_0655=src.source
  pair.target=src.source
end
local function request_move(pair,src)
  local key=pair_key(pair); if not key then return false end
  local mr=movement_root(); local pos=src.source.position
  local req={x=pos.x,y=pos.y,radius=1.10,reason="nearby-inventory-scavenge-0658",owner="nearby-inventory-scavenge-0658",priority=M.priority,distraction=defines and defines.distraction and defines.distraction.none or nil,issued_tick=now(),updated_tick=now(),expires_tick=now()+M.ttl,item=src.item,target_name=src.source.name,target_unit=src.source.unit_number,inventory_scavenge_0658=true}
  mr.requests[key]=req; mr.active_request_ids[key]=true; pair.movement_request_0418=req; pair.movement_controller_owner_0418=req.owner; pair.movement_controller_reason_0418=req.reason; pair.movement_controller_clamp_0418=nil; pair.movement_controller_state_0418="nearby-inventory-scavenge-0658"
  local last=pair.nearby_inventory_scavenge_0658_last_command
  if not last or now()-(tonumber(last.tick) or 0)>=M.command_cooldown then
    local command={type=defines.command.go_to_location,destination={x=pos.x,y=pos.y},radius=1.10,distraction=req.distraction}
    pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command) elseif pair.priest.set_command then pair.priest.set_command(command) end end)
    pair.nearby_inventory_scavenge_0658_last_command={tick=now(),x=pos.x,y=pos.y}
  end
  publish_leaf(pair,src,"moving")
  pair.nearby_inventory_scavenge_0658={phase="moving-to-source",item=src.item,source=src.source,inventory_id=src.inventory_id,count=src.count,x=pos.x,y=pos.y,tick=now()}
  pair.logistics_fetch_0527=pair.nearby_inventory_scavenge_0658
  pair.logistics_fetch_0526=pair.nearby_inventory_scavenge_0658
  return true
end
local function take_from_source(pair,src,need_remaining)
  local inv=source_inventory(src.source,src.inventory_id) or src.inventory
  if not (inv and inv.valid) then return false,"no-source-inventory" end
  local have=inventory_count(inv,src.item)
  if have<=0 then return false,"source-empty" end
  local want=math.max(1,math.min(M.max_fetch_per_trip,need_remaining or M.max_fetch_per_trip,have))
  local removed=remove_items(inv,src.item,want)
  if removed<=0 then return false,"remove-failed" end
  local inserted=deposit(pair,src.item,removed,"nearby-inventory-scavenge-0658")
  if inserted<removed then pcall(function() inv.insert({name=src.item,count=removed-inserted}) end) end
  publish_leaf(pair,src,"deposited")
  pair.nearby_inventory_scavenge_0658={phase="deposited",item=src.item,count=inserted,removed=removed,source=src.source,inventory_id=src.inventory_id,tick=now()}
  pair.logistics_fetch_0527=pair.nearby_inventory_scavenge_0658; pair.logistics_fetch_0526=pair.nearby_inventory_scavenge_0658
  if inserted>0 then pair.scavenge=nil; pair.inventory_scan=nil; pair.logistic_requested_item=nil; record(pair,"inventory-scavenged-0658","item="..safe(src.item).." x"..safe(inserted).." from="..safe(src.source.name).."#"..safe(src.source.unit_number).." inv="..safe(src.inventory_id)); return true,"scavenged" end
  return false,"deposit-failed"
end
function M.service_pair(pair,reason)
  local r=root(); if r.enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  if valid(pair.combat_target) then return false,"combat-has-priority" end
  local req=active_request(pair); local item=req and req.item or nil
  if not item then return false,"no-item-intent" end
  local need_total=math.max(1,tonumber(req.count) or 1); local have_station=station_count(pair,item)
  if have_station>=need_total then return false,"already-in-station" end
  local src=scan_inventory_source(pair,item)
  if not src then return false,"no-nearby-inventory-source" end
  local key=safe(station_unit(pair))..":"..safe(src.source.unit_number or src.source.name)..":"..safe(item)..":"..safe(src.inventory_id)
  if (r.cooldowns[key] or 0)>now() then return false,"cooldown" end
  local remaining=math.max(1,need_total-have_station)
  if dist_sq(pair.priest.position,src.source.position)>M.pickup_radius_sq then record(pair,"inventory-scavenge-moving-0658","item="..safe(item).." source="..safe(src.source.name).."#"..safe(src.source.unit_number)); return request_move(pair,src),"moving" end
  local ok,why=take_from_source(pair,src,remaining)
  if not ok then r.cooldowns[key]=now()+M.cooldown_ticks; record(pair,"inventory-scavenge-failed-0658","item="..safe(item).." source="..safe(src.source.name).." why="..safe(why)) end
  return ok,why
end
function M.service_all(reason)
  local n=0
  for _,pair in pairs(pair_map()) do if n>=M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok,acted=pcall(M.service_pair,pair,reason or "pulse"); if ok and acted then n=n+1 end end end
  return n
end
function M.install()
  root(); _G.TechPriestsNearbyInventoryScavengeAuthority0658=M
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="nearby_inventory_scavenge_authority_0658",category="logistics",interval=M.tick_interval,priority=32,budget=8,fn=function(event,budget) M.service_all("broker"); return true end,note="physically scavenge needed items from nearby real inventories before mining/fabrication"})
  else local R=rawget(_G,"TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end,{owner="nearby_inventory_scavenge_authority_0658",category="logistics",priority="early"}) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.658] nearby inventory scavenge authority installed; real adjacent inventories are looted into station storage") end
  return true
end

return M
