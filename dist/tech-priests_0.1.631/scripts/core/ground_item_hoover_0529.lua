-- scripts/core/ground_item_hoover_0529.lua
-- Tech Priests 0.1.529
--
-- Dispatcher-owned loose-ground item cleanup. Tech-Priests detest matter left in
-- unsanctified piles on the ground. This executor physically walks to loose item
-- stacks inside station range, picks them up, and routes them to station storage,
-- a remembered retention box, or a station-adjacent chest that the priest places
-- from available stock. It does not dump overflow back to the ground.

local M = {}
M.version = "0.1.610"
M.storage_key = "ground_item_hoover_0529"
M.enabled_default = true
M.dispatcher_priority = 710
M.move_priority = 88
M.move_ttl = 60 * 4
M.pickup_radius_sq = 2.10 * 2.10
M.station_radius_default = 32
M.max_pickup_per_trip = 200
M.cooldown_ticks = 45
M.max_recent = 180
M.storage_box_items = {
  { item="wooden-chest", entity="wooden-chest" },
  { item="iron-chest", entity="iron-chest" },
  { item="steel-chest", entity="steel-chest" },
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function routed_scan(surface, filters, category, negative_key, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local ents = select(1, Scan.find_entities(surface, filters, { category = category or "pickup", negative_key = negative_key, negative_ttl = ttl or 60 * 4 }))
    if ents then return ents end
  end
  local ok, ents = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and ents or {}
end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(p) return type(p)=="table" and valid(p.station) and valid(p.priest) end
local function station_unit(p) return p and (p.station_unit or (valid(p.station) and p.station.unit_number)) or nil end
local function priest_unit(p) return p and (p.priest_unit or (valid(p.priest) and p.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=M.enabled_default, stats={}, recent={}, cooldowns={}, retention_boxes={} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = M.enabled_default end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.cooldowns = r.cooldowns or {}
  r.retention_boxes = r.retention_boxes or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, event, detail)
  local r=M.root(); stat(event)
  local rec={tick=now(),event=tostring(event or "event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent>M.max_recent do table.remove(r.recent,1) end
  if pair then pair.ground_hoover_0529_last=rec end
  return rec
end

local function inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end
local function station_inv(pair) return inventory(pair and pair.station, defines and defines.inventory and defines.inventory.chest) end
local function count_inv(inv,item) if not (inv and inv.valid and item) then return 0 end; local ok,n=pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function insert_inv(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end; local ok,n=pcall(function() return inv.insert({name=item,count=count}) end); return ok and (tonumber(n) or 0) end
local function remove_inv(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end; local ok,n=pcall(function() return inv.remove({name=item,count=count}) end); return ok and (tonumber(n) or 0) or 0 end
local function can_insert(inv,item,count) if not (inv and inv.valid and item) then return false end; local ok,res=pcall(function() return inv.can_insert({name=item,count=math.max(1,tonumber(count) or 1)}) end); return ok and res == true end
local function entity_inv(e)
  return inventory(e, defines.inventory.chest) or inventory(e, defines.inventory.car_trunk) or inventory(e, defines.inventory.spider_trunk)
end

local function is_container_like(e)
  return valid(e) and (e.type == "container" or e.type == "logistic-container" or e.type == "car" or e.type == "spider-vehicle")
end

local function has_adjacent_automation(e)
  if not valid(e) then return false end
  local s=e.surface; local p=e.position
  local area={{p.x-1.6,p.y-1.6},{p.x+1.6,p.y+1.6}}
  local ents={}
  pcall(function() ents=s.find_entities_filtered({ area=area, force=e.force, type={"inserter","loader","loader-1x1","transport-belt","underground-belt","splitter"}, limit=12 }) or {} end)
  return #ents > 0
end

local function station_radius(pair)
  local r=tonumber(pair and pair.radius) or nil
  if not r and _G.get_station_operating_radius and pair and valid(pair.station) then local ok,n=pcall(_G.get_station_operating_radius,pair.station); if ok then r=tonumber(n) end end
  return math.max(8, r or M.station_radius_default)
end

local function ground_items(pair)
  if not valid_pair(pair) then return {} end
  local r=station_radius(pair)
  local p=pair.station.position
  local area={{p.x-r,p.y-r},{p.x+r,p.y+r}}
  local ents={}
  ents = routed_scan(pair.station.surface, { area=area, type="item-entity", limit=160 }, "pickup", "pickup:" .. safe(pair.station.surface.index) .. ":" .. safe(pair.station.force.index) .. ":" .. safe(pair.station.unit_number), 60 * 3)
  return ents
end

local function best_ground_item(pair)
  local best, score = nil, nil
  for _,e in pairs(ground_items(pair)) do
    if valid(e) and e.stack and e.stack.valid_for_read and e.stack.name and e.stack.count and e.stack.count > 0 then
      local dpr=dist_sq(pair.priest.position,e.position)
      local dst=dist_sq(pair.station.position,e.position)
      local sc=100000 - math.sqrt(dpr) - math.sqrt(dst)*0.25 + math.min(50, tonumber(e.stack.count) or 1)
      if not score or sc > score then best, score = e, sc end
    end
  end
  return best
end

local function source_key(e)
  if not valid(e) then return nil end
  return tostring(e.unit_number or (e.name .. ":" .. tostring(math.floor(e.position.x*10)) .. ":" .. tostring(math.floor(e.position.y*10))))
end

local function remember_box(pair, e, reason)
  local r=M.root(); local su=tostring(station_unit(pair) or "?")
  r.retention_boxes[su]=r.retention_boxes[su] or {}
  local k=source_key(e)
  if k then r.retention_boxes[su][k]={ entity=e, unit=e.unit_number, name=e.name, x=e.position.x, y=e.position.y, tick=now(), reason=tostring(reason or "retention") } end
end

local function find_retention_box(pair, item, count)
  if not valid_pair(pair) then return nil,nil,"invalid" end
  local r=M.root(); local su=tostring(station_unit(pair) or "?")
  local bucket=r.retention_boxes[su] or {}
  for k,rec in pairs(bucket) do
    local e=rec and rec.entity
    if valid(e) then
      local inv=entity_inv(e)
      if inv and can_insert(inv,item,count) then return e,inv,"remembered" end
    else bucket[k]=nil end
  end
  local radius=station_radius(pair)
  local ents={}
  ents = routed_scan(pair.station.surface, { position=pair.station.position, radius=radius, force=pair.station.force, type={"container","logistic-container","car","spider-vehicle"}, limit=96 }, "pickup", "retention:" .. safe(pair.station.surface.index) .. ":" .. safe(pair.station.force.index) .. ":" .. safe(pair.station.unit_number), 60 * 6)
  local best,best_inv,best_d=nil,nil,nil
  for _,e in pairs(ents) do
    if is_container_like(e) and e ~= pair.station and not has_adjacent_automation(e) then
      local inv=entity_inv(e)
      if inv and can_insert(inv,item,count) then
        local d=dist_sq(e.position,pair.station.position)
        if not best_d or d < best_d then best,best_inv,best_d=e,inv,d end
      end
    end
  end
  if best then remember_box(pair,best,"auto-retention-0529"); return best,best_inv,"auto" end
  return nil,nil,"none"
end

local function free_station_space(pair, item, count)
  local inv=station_inv(pair)
  return inv and can_insert(inv,item,count), inv
end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if game and game.item_prototypes and game.item_prototypes[name] then return true end
  return false
end

local function entity_exists(name)
  if not name then return false end
  if prototypes and prototypes.entity and prototypes.entity[name] then return true end
  if game and game.entity_prototypes and game.entity_prototypes[name] then return true end
  return false
end

local function place_storage_box_near_station(pair)
  if not valid_pair(pair) then return nil,nil,"invalid" end
  local inv=station_inv(pair)
  if not (inv and inv.valid) then return nil,nil,"no-station-inv" end
  local choice=nil
  for _,c in ipairs(M.storage_box_items) do
    if item_exists(c.item) and entity_exists(c.entity) and count_inv(inv,c.item) > 0 then choice=c; break end
  end
  if not choice then return nil,nil,"no-storage-item" end
  local s=pair.station.surface
  local base=pair.station.position
  local candidates={}
  for dx=-3,3 do for dy=-3,3 do
    if math.abs(dx)==3 or math.abs(dy)==3 then candidates[#candidates+1]={x=base.x+dx,y=base.y+dy} end
  end end
  table.sort(candidates,function(a,b) return dist_sq(a,pair.priest.position)<dist_sq(b,pair.priest.position) end)
  for _,pos in ipairs(candidates) do
    local can=false
    pcall(function() can=s.can_place_entity({ name=choice.entity, position=pos, force=pair.station.force }) end)
    if can then
      local removed=remove_inv(inv,choice.item,1)
      if removed > 0 then
        local ok,e=pcall(function() return s.create_entity({ name=choice.entity, position=pos, force=pair.station.force, raise_built=true }) end)
        if ok and valid(e) then
          remember_box(pair,e,"placed-retention-0529")
          return e,entity_inv(e),"placed-"..choice.entity
        end
        insert_inv(inv,choice.item,1)
      end
    end
  end
  return nil,nil,"no-place-position"
end

local function request_move(pair, entity, reason, radius)
  if not (valid_pair(pair) and valid(entity)) then return false end
  if type(_G.tech_priests_request_movement_0418)=="function" then
    local ok,res=pcall(_G.tech_priests_request_movement_0418,pair,entity.position,reason or "ground-hoover-0529",{owner="ground-hoover-0529",priority=M.move_priority,ttl=M.move_ttl,radius=radius or 1.1,distraction=defines and defines.distraction and defines.distraction.none or nil})
    if ok and res ~= false then return true end
  end
  return false
end

local function begin_task(pair, item_entity)
  if not (valid_pair(pair) and valid(item_entity) and item_entity.stack and item_entity.stack.valid_for_read) then return false,"invalid-ground-item" end
  pair.ground_hoover_0529 = { phase="move-to-item", source=item_entity, source_unit=item_entity.unit_number, item=item_entity.stack.name, count=math.min(M.max_pickup_per_trip, tonumber(item_entity.stack.count) or 1), x=item_entity.position.x, y=item_entity.position.y, tick=now() }
  pair.mode="ground-item-hoover"
  record(pair,"begin-hoover",tostring(item_entity.stack.name).." x"..tostring(item_entity.stack.count or 1).." at ground#"..tostring(item_entity.unit_number or "?"))
  return true,"began-ground-hoover"
end

local function deposit_carried(pair, task)
  local item=task and task.item; local count=tonumber(task and task.carried_count) or 0
  if not (item and count>0) then pair.ground_hoover_0529=nil; return false,"no-carried" end
  local ok, inv = free_station_space(pair,item,count)
  if ok and inv then
    local inserted=insert_inv(inv,item,count)
    if inserted>0 then
      task.carried_count=count-inserted
      record(pair,"station-deposit",tostring(item).." x"..tostring(inserted))
      if task.carried_count<=0 then pair.ground_hoover_0529={phase="complete",item=item,count=count,tick=now()}; return true,"ground-hoover-deposited" end
    end
  end
  local box,binv,why=find_retention_box(pair,item,count)
  if not (valid(box) and binv) then
    box,binv,why=place_storage_box_near_station(pair)
  end
  if not (valid(box) and binv) then
    task.phase="blocked-no-storage"
    task.blocked_reason=why
    record(pair,"blocked-no-storage",tostring(item).." x"..tostring(count).." reason="..tostring(why))
    return false,"blocked-no-storage"
  end
  if dist_sq(pair.priest.position,box.position) > M.pickup_radius_sq then
    task.phase="move-to-storage"
    task.storage=box
    local moved=request_move(pair,box,"ground-hoover-storage-0529",1.2)
    if not moved then
      record(pair,"movement-request-failed-0529",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
      return false,"movement-request-failed"
    end
    record(pair,"move-to-storage",tostring(item).." x"..tostring(count).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
    return true,"moving-to-storage"
  end
  local inserted=insert_inv(binv,item,count)
  if inserted>0 then
    task.carried_count=count-inserted
    record(pair,"retention-deposit",tostring(item).." x"..tostring(inserted).." -> "..tostring(box.name).."#"..tostring(box.unit_number or "?"))
    if task.carried_count<=0 then pair.ground_hoover_0529={phase="complete",item=item,count=inserted,tick=now()}; return true,"ground-hoover-retained" end
  end
  return false,"storage-insert-failed"
end

local function continue_task(pair)
  local task=pair and pair.ground_hoover_0529 or nil
  if type(task)~="table" then return false,"no-active-hoover" end
  if task.phase=="complete" then pair.ground_hoover_0529=nil; return false,"complete-cleared" end
  if task.phase=="blocked-no-storage" then return false,"blocked-no-storage" end
  if task.phase=="move-to-storage" then return deposit_carried(pair,task) end
  if task.phase=="move-to-item" then
    local src=task.source
    if not valid(src) then pair.ground_hoover_0529=nil; return false,"source-invalid" end
    if dist_sq(pair.priest.position,src.position) > M.pickup_radius_sq then
      local moved=request_move(pair,src,"ground-hoover-pickup-0529",1.05)
      if not moved then
        record(pair,"movement-request-failed-0529",tostring(task.item).." from ground#"..tostring(src.unit_number or "?"))
        return false,"movement-request-failed"
      end
      return true,"moving-to-ground-item"
    end
    local stack=src.stack
    if not (stack and stack.valid_for_read and stack.name==task.item) then pair.ground_hoover_0529=nil; return false,"stack-invalid" end
    local have=tonumber(stack.count) or 0
    local take=math.max(1,math.min(M.max_pickup_per_trip,tonumber(task.count) or have,have))
    if take<=0 then pair.ground_hoover_0529=nil; return false,"empty-stack" end
    if have<=take then pcall(function() src.destroy() end) else pcall(function() stack.count=have-take end) end
    task.carried_count=take
    task.phase="deposit-carried"
    record(pair,"picked-ground-item",tostring(task.item).." x"..tostring(take))
    return deposit_carried(pair,task)
  end
  if task.phase=="deposit-carried" then return deposit_carried(pair,task) end
  return false,"unknown-phase"
end

function M.service_pair(pair, reason)
  local r=M.root()
  if r.enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  if valid(pair.combat_target) then return false,"combat-priority" end
  if type(pair.ground_hoover_0529)=="table" and pair.ground_hoover_0529.phase and pair.ground_hoover_0529.phase~="complete" then return continue_task(pair) end
  local key=tostring(station_unit(pair) or "?")
  if (r.cooldowns[key] or 0)>now() then return false,"cooldown" end
  local item_entity=best_ground_item(pair)
  if not item_entity then r.cooldowns[key]=now()+M.cooldown_ticks; return false,"no-ground-items" end
  return begin_task(pair,item_entity)
end

local function patch_dispatcher()
  local okD,D=pcall(require,"scripts.core.single_dispatcher_0510")
  if not (okD and D and type(D.service_pair)=="function") or D.TECH_PRIESTS_0529_GROUND_HOOVER_WRAPPED then return false end
  D.TECH_PRIESTS_0529_GROUND_HOOVER_WRAPPED=true
  D.TECH_PRIESTS_0529_PRE_GROUND_HOOVER=D.service_pair
  D.service_pair=function(pair, reason, ...)
    local r=M.root()
    if r.enabled~=false and valid_pair(pair) then
      local acted,why=M.service_pair(pair, reason or "dispatcher-0529")
      if acted then
        pair.dispatcher_0510=pair.dispatcher_0510 or {}
        pair.dispatcher_0510.tick=now(); pair.dispatcher_0510.action="ground-hoover"; pair.dispatcher_0510.family="logistics"; pair.dispatcher_0510.reason=tostring(why or "ground-hoover-0529"); pair.dispatcher_0510.acted=true; pair.dispatcher_0510.result=tostring(why or "ground-hoover-0529")
        if type(_G.tech_priests_0507_action_claim)=="function" then pcall(_G.tech_priests_0507_action_claim,pair,"ground-hoover","ground_item_hoover_0529",why or "ground-hoover") end
        return true,why
      end
    end
    return D.TECH_PRIESTS_0529_PRE_GROUND_HOOVER(pair, reason, ...)
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected=player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp=storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local t=pair.ground_hoover_0529 or {}
  local candidate=best_ground_item(pair)
  return "enabled="..tostring(M.root().enabled).." phase="..tostring(t.phase or "none").." item="..tostring(t.item or "none").." carried="..tostring(t.carried_count or 0).." candidate="..tostring(candidate and (candidate.stack and candidate.stack.name .. "#" .. tostring(candidate.unit_number or "?")) or "none")
end

local function install_command()
  if not commands then return end
  pcall(function() commands.remove_command("tp-ground-hoover-0529") end)
  commands.add_command("tp-ground-hoover-0529","Tech Priests 0.1.529: loose ground item hoover/storage diagnostics. Params: all/on/off",function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local param=lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true end
    if param=="off" then r.enabled=false end
    if param=="all" then for _,pair in pairs(pair_map()) do if valid_pair(pair) then pcall(M.service_pair,pair,"manual-all") end end end
    local pair=player and selected_pair(player) or nil
    local msg="[tp-ground-hoover-0529] enabled="..tostring(r.enabled).." picked="..safe(r.stats["picked-ground-item"] or 0).." station="..safe(r.stats["station-deposit"] or 0).." retained="..safe(r.stats["retention-deposit"] or 0).." blocked="..safe(r.stats["blocked-no-storage"] or 0)
    if pair then msg=msg.."\n"..M.describe_pair(pair) end
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.ground_hoover_0529_wrapped then return false end
  local prev=diag.pair_dump_lines; diag.ground_hoover_0529_wrapped=true
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}
    local r=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 GROUND-HOOVER-0529 BEGIN enabled="..safe(r.enabled).." picked="..safe(r.stats["picked-ground-item"] or 0).." station="..safe(r.stats["station-deposit"] or 0).." retained="..safe(r.stats["retention-deposit"] or 0).." blocked="..safe(r.stats["blocked-no-storage"] or 0)
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then lines[#lines+1]="PAIR-DUMP-0468 ground-hoover["..safe(station_unit(pair)).."] "..M.describe_pair(pair) end end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 ground-hoover.recent["..tostring(i).."] tick="..safe(ev.tick).." event="..safe(ev.event).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail) end end
    lines[#lines+1]="PAIR-DUMP-0468 GROUND-HOOVER-0529 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  patch_dispatcher()
  wrap_diagnostics()
  install_command()
  _G.TECH_PRIESTS_GROUND_ITEM_HOOVER_0529 = M
  if log then log("[Tech-Priests 0.1.529] loose ground item hoover/storage doctrine loaded; priests physically collect dropped items and avoid dumping overflow") end
  return true
end

return M