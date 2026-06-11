-- scripts/core/logistics_fetch_executor_0526.lua
-- Tech Priests 0.1.526
--
-- Physical logistics fetch executor.  The station catalog may know that a
-- nearby container/machine/ground source contains ammunition or other requested
-- stock, but the item must not become station inventory until the priest has
-- physically gone to the source and taken it.  This pass runs before raw direct
-- acquisition so "go get ammo from the starting vessel" wins over "go mine the
-- resource chain for ammunition" when the known storage source exists.

local M = {}
M.version = "0.1.526"
M.storage_key = "logistics_fetch_executor_0526"
M.pickup_radius_sq = 2.25
M.max_fetch_per_trip = 10
M.fetch_priority = 775
M.fetch_ttl = 60 * 10
M.cooldown_ticks = 60 * 2

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok,o = pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_priority_fetch = true,
    stats = {},
    recent = {},
    cooldowns = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_priority_fetch == nil then r.dispatcher_priority_fetch = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.cooldowns = r.cooldowns or {}
  return r
end

local function stat(name, n) local r=M.root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair, event, detail)
  local r = M.root(); stat(event)
  local rec = { tick=now(), event=tostring(event or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "") }
  r.recent[#r.recent+1] = rec
  while #r.recent > 160 do table.remove(r.recent, 1) end
  if pair then pair.logistics_fetch_0526_last = rec end
  return rec
end

local function normalize_item(v)
  if type(v) == "string" then
    if v == "ammo" or v == "ammunition" or v == "magazine" then return "firearm-magazine" end
    if v == "repair" then return "repair-pack" end
    return v
  end
  if type(v) ~= "table" then return nil end
  return normalize_item(v.item or v.item_name or v.output_item or v.requested_item or v.wanted_item or v.name)
end

local function active_requested_item(pair)
  if not pair then return nil end
  local q = pair.order_queue_0469
  local o = (q and q.current) or pair.active_order_0469
  local item = normalize_item(o)
  local kind = lower(type(o) == "table" and (o.kind or o.type or o.source or o.key) or "")
  if item and (kind == "" or kind:find("logistic",1,true) or kind:find("supply",1,true) or kind:find("gather",1,true) or kind:find("acqui",1,true) or kind:find("scavenge",1,true) or kind:find("emergency",1,true)) then return item end
  item = normalize_item(pair.active_supply_request)
  if item then return item end
  item = normalize_item(pair.logistic_requested_item)
  if item then return item end
  item = normalize_item(pair.scavenge)
  if item then return item end
  item = normalize_item(pair.inventory_scan)
  if item then return item end
  local mode = lower(pair.mode or "")
  if mode:find("ammo",1,true) or mode:find("survival%-ammo") then return "firearm-magazine" end
  if mode:find("repair",1,true) then return "repair-pack" end
  local op = pair.independent_emergency_operation_0184 or pair.independent_emergency_operation or pair.emergency_operation
  item = normalize_item(op and (op.last_item or op.requested_item or op.item or op.item_name))
  if item then return item end
  return nil
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  if _G.tech_priests_0358_station_item_count then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,item); if ok then return tonumber(n) or 0 end end
  local inv = pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest)
  if inv and inv.valid then local ok,n=pcall(function() return inv.get_item_count(item) end); if ok then return tonumber(n) or 0 end end
  return 0
end

local function source_inventory(source, inv_id)
  if not valid(source) then return nil end
  if inv_id and source.get_inventory then
    local ok, inv = pcall(function() return source.get_inventory(inv_id) end)
    if ok and inv and inv.valid then return inv end
  end
  if not (defines and defines.inventory and source.get_inventory) then return nil end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_output,
    defines.inventory.assembling_machine_input,
    defines.inventory.furnace_result,
    defines.inventory.furnace_source,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.cargo_wagon,
    defines.inventory.rocket_silo_result,
  }
  for _, id in ipairs(ids) do
    if id then local ok, inv = pcall(function() return source.get_inventory(id) end); if ok and inv and inv.valid then return inv end end
  end
  return nil
end

local function deposit_to_station(pair, item, count)
  if not (valid_pair(pair) and item and count and count > 0) then return 0 end
  if type(_G.tech_priests_safe_deposit_item) == "function" then
    local ok, did, why = pcall(_G.tech_priests_safe_deposit_item, pair, item, count, "logistics-fetch-0526")
    if ok and did then return count end
  end
  if type(_G.tech_priests_0358_try_deposit_to_station) == "function" then
    local ok, inserted = pcall(_G.tech_priests_0358_try_deposit_to_station, pair, item, count, "logistics-fetch-0526")
    if ok then return tonumber(inserted) or 0 end
  end
  local inv = pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest)
  if inv and inv.valid then local ok, inserted = pcall(function() return inv.insert({ name=item, count=count }) end); if ok then return tonumber(inserted) or 0 end end
  return 0
end

local function known_storage_source(pair, item)
  if not (valid_pair(pair) and item) then return nil end
  local okCat, Catalog = pcall(require, "scripts.core.station_catalog")
  if okCat and Catalog and type(Catalog.find_known_source) == "function" then
    local ok, src = pcall(Catalog.find_known_source, pair, item)
    if ok and src and src.kind == "known-storage-0327" and valid(src.source) and src.source ~= pair.station then return src end
  end
  -- Direct catalog fallback to prefer the closest storage instance.
  local cat = nil
  if _G.tech_priests_0327_scan_station_catalog then local ok, c = pcall(_G.tech_priests_0327_scan_station_catalog, pair); if ok then cat = c end end
  if (not cat) and _G.tech_priests_0327_get_station_catalog then local ok, c = pcall(_G.tech_priests_0327_get_station_catalog, pair); if ok then cat = c end end
  local rec = cat and cat.storage_items and cat.storage_items[item]
  if rec then
    local best = nil
    for _, inst in ipairs(rec.instances or {}) do
      if inst and valid(inst.entity) and inst.entity ~= pair.station then
        if (not best) or ((inst.distance_sq or 999999999) < (best.distance_sq or 999999999)) then best = inst end
      end
    end
    if best then return { kind="known-storage-0327", source=best.entity, inventory_id=best.inventory_id, item_name=item, count=best.count or 1, station_distance_sq=best.distance_sq or 0 } end
    if valid(rec.entity) and rec.entity ~= pair.station then return { kind="known-storage-0327", source=rec.entity, inventory_id=rec.inventory_id, item_name=item, count=rec.count or 1, station_distance_sq=rec.distance_sq or 0 } end
  end
  return nil
end

local function request_move(pair, source, item)
  if not (valid_pair(pair) and valid(source)) then return false end
  local pos = source.position
  if _G.tech_priests_request_movement_0418 then
    local ok, res = pcall(_G.tech_priests_request_movement_0418, pair, pos, "known-storage-fetch-0526", { owner="logistics-fetch-0526", priority=M.fetch_priority, ttl=M.fetch_ttl, radius=1.15, distraction=defines and defines.distraction and defines.distraction.none or nil })
    if ok and res ~= false then
      pair.mode = "moving-to-known-storage"
      pair.logistics_fetch_0526 = { phase="moving-to-source", item=item, source=source, source_unit=source.unit_number, source_name=source.name, x=pos.x, y=pos.y, tick=now() }
      record(pair, "move-to-known-storage", tostring(item) .. " from " .. tostring(source.name) .. "#" .. tostring(source.unit_number or "?"))
      return true
    end
  end
  return false
end

function M.service_pair(pair, reason)
  local r = M.root(); if r.enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  if valid(pair.combat_target) then return false, "combat-has-priority" end
  local item = active_requested_item(pair)
  if not item then return false, "no-item-intent" end
  if station_count(pair, item) > 0 then return false, "already-in-station" end
  local src = known_storage_source(pair, item)
  if not (src and valid(src.source)) then return false, "no-known-storage-source" end
  local key = tostring(station_unit(pair)) .. ":" .. tostring(item) .. ":" .. tostring(src.source.unit_number or src.source.name)
  if (r.cooldowns[key] or 0) > now() then return false, "cooldown" end
  local d2 = dist_sq(pair.priest.position, src.source.position)
  if d2 > M.pickup_radius_sq then
    request_move(pair, src.source, item)
    return true, "moving-to-known-storage"
  end
  local inv = source_inventory(src.source, src.inventory_id)
  if not (inv and inv.valid) then r.cooldowns[key]=now()+M.cooldown_ticks; return false, "no-source-inventory" end
  local have = 0
  pcall(function() have = inv.get_item_count(item) end)
  have = tonumber(have) or 0
  if have <= 0 then r.cooldowns[key]=now()+M.cooldown_ticks; return false, "source-empty" end
  local want = math.max(1, math.min(M.max_fetch_per_trip, have))
  local removed = 0
  pcall(function() removed = inv.remove({ name=item, count=want }) end)
  removed = tonumber(removed) or 0
  if removed <= 0 then r.cooldowns[key]=now()+M.cooldown_ticks; return false, "remove-failed" end
  local inserted = deposit_to_station(pair, item, removed)
  if inserted < removed then
    pcall(function() inv.insert({ name=item, count=removed-inserted }) end)
  end
  pair.logistics_fetch_0526 = { phase="deposited", item=item, count=inserted, source_name=src.source.name, source_unit=src.source.unit_number, tick=now() }
  if inserted > 0 then
    pair.scavenge = nil
    pair.inventory_scan = nil
    pair.logistic_requested_item = nil
    record(pair, "fetched-known-storage", tostring(item) .. " x" .. tostring(inserted) .. " from " .. tostring(src.source.name) .. "#" .. tostring(src.source.unit_number or "?"))
    return true, "fetched-known-storage"
  end
  return false, "deposit-failed"
end

local function patch_dispatcher()
  local okD, D = pcall(require, "scripts.core.single_dispatcher_0510")
  if not (okD and D and type(D.service_pair) == "function") or D.TECH_PRIESTS_0526_FETCH_WRAPPED then return false end
  D.TECH_PRIESTS_0526_FETCH_WRAPPED = true
  D.TECH_PRIESTS_0526_PRE_SERVICE_PAIR = D.service_pair
  D.service_pair = function(pair, reason, ...)
    local r = M.root()
    if r.enabled ~= false and r.dispatcher_priority_fetch ~= false and valid_pair(pair) then
      local acted, why = M.service_pair(pair, reason or "dispatcher-0526")
      if acted then
        pair.dispatcher_0510 = pair.dispatcher_0510 or {}
        pair.dispatcher_0510.tick = now()
        pair.dispatcher_0510.action = "logistics-fetch"
        pair.dispatcher_0510.family = "logistics"
        pair.dispatcher_0510.reason = tostring(why or "known-storage-fetch-0526")
        pair.dispatcher_0510.acted = true
        pair.dispatcher_0510.result = tostring(why or "known-storage-fetch-0526")
        if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "logistics-fetch", "logistics_fetch_executor_0526", why or "known-storage-fetch") end
        return true, why
      end
    end
    return D.TECH_PRIESTS_0526_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp = storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local item = active_requested_item(pair)
  local src = item and known_storage_source(pair, item) or nil
  local fetch = pair.logistics_fetch_0526 or {}
  return "enabled=" .. tostring(M.root().enabled) .. " item=" .. tostring(item or "none") .. " station_count=" .. tostring(item and station_count(pair,item) or 0) .. " source=" .. tostring(src and src.source and (src.source.name .. "#" .. tostring(src.source.unit_number or "?")) or "none") .. " fetch=" .. tostring(fetch.phase or "none")
end

local function install_command()
  if not commands then return end
  pcall(function() commands.remove_command("tp-logistics-fetch-0526") end)
  commands.add_command("tp-logistics-fetch-0526", "Tech Priests 0.1.526: physical known-storage fetch diagnostics. Params: all/on/off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = M.root()
    if param == "on" then r.enabled = true end
    if param == "off" then r.enabled = false end
    if param == "all" then for _,pair in pairs(pair_map()) do if valid_pair(pair) then pcall(M.service_pair, pair, "manual-all") end end end
    local pair = player and selected_pair(player) or nil
    local msg = "[tp-logistics-fetch-0526] enabled=" .. tostring(r.enabled) .. " fetched=" .. safe(r.stats["fetched-known-storage"] or 0) .. " moves=" .. safe(r.stats["move-to-known-storage"] or 0)
    if pair then msg = msg .. "\n" .. M.describe_pair(pair) end
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.logistics_fetch_0526_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.logistics_fetch_0526_wrapped = true
  diag.pair_dump_lines = function(...)
    local lines = prev(...)
    lines = type(lines) == "table" and lines or {}
    local r = M.root()
    lines[#lines+1] = "PAIR-DUMP-0468 LOGISTICS-FETCH-0526 BEGIN enabled=" .. tostring(r.enabled) .. " fetched=" .. safe(r.stats["fetched-known-storage"] or 0) .. " moves=" .. safe(r.stats["move-to-known-storage"] or 0)
    for _, pair in pairs(pair_map()) do if valid_pair(pair) then lines[#lines+1] = "PAIR-DUMP-0468 logistics-fetch[" .. safe(station_unit(pair)) .. "] " .. M.describe_pair(pair) end end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1] = "PAIR-DUMP-0468 logistics-fetch.recent[" .. tostring(i) .. "] tick=" .. safe(ev.tick) .. " event=" .. safe(ev.event) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end end
    lines[#lines+1] = "PAIR-DUMP-0468 LOGISTICS-FETCH-0526 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  patch_dispatcher()
  wrap_diagnostics()
  install_command()
  _G.TECH_PRIESTS_LOGISTICS_FETCH_EXECUTOR_0526 = M
  if log then log("[Tech-Priests 0.1.526] physical known-storage logistics fetch executor loaded; storage ammo precedes raw acquisition") end
  return true
end

return M
