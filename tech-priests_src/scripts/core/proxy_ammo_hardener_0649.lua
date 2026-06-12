-- scripts/core/proxy_ammo_hardener_0649.lua
-- Tech Priests 0.1.653
-- Commandless hidden proxy-gun ammo hardener.

local M = {}
M.version = "0.1.653"
M.storage_key = "proxy_ammo_hardener_0649"
M.tick_interval = 41
M.max_pairs_per_pulse = 24
M.load_batch = 10
M.log_interval = 600

local AMMO_ORDER = { "uranium-rounds-magazine", "piercing-rounds-magazine", "firearm-magazine" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}
  return r
end

local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = root(); stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 120 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then r.last_log[key] = now(); if log then log("[Tech-Priests 0.1.653] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end end
end

local function item_exists(name) return name and prototypes and prototypes.item and prototypes.item[name] ~= nil end
local function safe_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end
local function count(inv, item) if not (inv and inv.valid and item) then return 0 end local ok, n = pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function remove(inv, item, n) if not (inv and inv.valid and item and n and n > 0) then return 0 end local ok, got = pcall(function() return inv.remove({ name = item, count = n }) end); return ok and (tonumber(got) or 0) or 0 end
local function insert(inv, item, n) if not (inv and inv.valid and item and n and n > 0) then return 0 end local ok, got = pcall(function() return inv.insert({ name = item, count = n }) end); return ok and (tonumber(got) or 0) or 0 end

local function station_sources(pair)
  local out, seen = {}, {}
  local function add(inv, label) if inv and inv.valid and not seen[tostring(inv)] then out[#out + 1] = { inv = inv, label = label }; seen[tostring(inv)] = true end end
  if not valid_pair(pair) then return out end
  if type(rawget(_G, "tech_priests_inventory_steward_sources_for_pair")) == "function" then
    local ok, sources = pcall(rawget(_G, "tech_priests_inventory_steward_sources_for_pair"), pair)
    if ok and type(sources) == "table" then for _, src in ipairs(sources) do if src and src.inv and src.inv.valid then add(src.inv, src.source or "steward") end end end
  end
  if defines and defines.inventory then add(safe_inventory(pair.station, defines.inventory.chest), "station-chest") end
  return out
end

function M.station_ammo(pair)
  for _, item in ipairs(AMMO_ORDER) do
    if item_exists(item) then for _, src in ipairs(station_sources(pair)) do local n = count(src.inv, item); if n > 0 then return item, n, src end end end
  end
  if prototypes and prototypes.item then
    for item_name, proto in pairs(prototypes.item) do
      local typ = nil; pcall(function() typ = proto.type end)
      if typ == "ammo" then for _, src in ipairs(station_sources(pair)) do local n = count(src.inv, item_name); if n > 0 then return item_name, n, src end end end
    end
  end
  return nil, 0, nil
end

function M.station_has_ammo(pair) local item, n = M.station_ammo(pair); return item ~= nil and n > 0 end

function M.ensure_proxy(pair)
  if pair then for _, key in ipairs({ "proxy", "proxy_turret", "combat_proxy", "hidden_proxy_0293", "proxy_0293" }) do local e = pair[key]; if valid(e) then pair.proxy = e; return e end end end
  if type(rawget(_G, "ensure_proxy")) == "function" then local ok, proxy = pcall(rawget(_G, "ensure_proxy"), pair); if ok and valid(proxy) then pair.proxy = proxy; return proxy end end
  return nil
end

function M.proxy_ammo_inventory(pair)
  local proxy = M.ensure_proxy(pair)
  if not valid(proxy) or not defines or not defines.inventory then return nil, proxy end
  return safe_inventory(proxy, defines.inventory.turret_ammo), proxy
end

function M.proxy_has_ammo(pair)
  local inv = M.proxy_ammo_inventory(pair)
  if inv and inv.valid then
    for _, item in ipairs(AMMO_ORDER) do if item_exists(item) and count(inv, item) > 0 then return true end end
    if prototypes and prototypes.item then for item_name, proto in pairs(prototypes.item) do local typ=nil; pcall(function() typ=proto.type end); if typ == "ammo" and count(inv, item_name) > 0 then return true end end end
  end
  return false
end

function M.load_proxy_from_station(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  if M.proxy_has_ammo(pair) then pair.proxy_ammo_0649 = { tick = now(), status = "already-loaded", reason = reason or "load" }; return true end
  local inv, proxy = M.proxy_ammo_inventory(pair)
  if not (valid(proxy) and inv and inv.valid) then pair.proxy_ammo_0649 = { tick = now(), status = "no-proxy-ammo-inventory", reason = reason or "load" }; record("proxy-ammo-no-inventory-0649", pair, "reason=" .. safe(reason), true); return false end
  local item, available, src = M.station_ammo(pair)
  if not item then pair.proxy_ammo_0649 = { tick = now(), status = "station-ammo-missing", reason = reason or "load" }; record("proxy-ammo-station-empty-0649", pair, "reason=" .. safe(reason), false); return false end
  local want = math.max(1, math.min(M.load_batch, available))
  local removed = remove(src.inv, item, want)
  if removed <= 0 then pair.proxy_ammo_0649 = { tick = now(), status = "station-remove-failed", item = item }; return false end
  local loaded = insert(inv, item, removed)
  if loaded < removed and src and src.inv and src.inv.valid then insert(src.inv, item, removed - loaded) end
  pair.proxy_ammo_0649 = { tick = now(), status = loaded > 0 and "loaded" or "insert-failed", item = item, loaded = loaded, removed = removed, reason = reason or "load", source = src and src.label }
  record(loaded > 0 and "proxy-ammo-loaded-0649" or "proxy-ammo-insert-failed-0649", pair, "item=" .. safe(item) .. " loaded=" .. safe(loaded), true)
  return loaded > 0
end

local function wrap_ammo_functions()
  if not rawget(_G, "TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION") then
    _G.TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION = rawget(_G, "load_proxy_from_station") or false
    _G.load_proxy_from_station = function(pair, ...) if M.load_proxy_from_station(pair, "load_proxy_from_station-0649") then return true end local pre = rawget(_G, "TECH_PRIESTS_0649_PRE_LOAD_PROXY_FROM_STATION"); if type(pre) == "function" then local ok, did = pcall(pre, pair, ...); return ok and did == true end return false end
  end
  _G.tech_priests_0293_proxy_has_ammo = function(pair, ...) return M.proxy_has_ammo(pair) end
  _G.tech_priests_0293_station_has_ammo = function(pair, ...) return M.station_has_ammo(pair) end
  _G.tech_priests_0295_station_or_proxy_has_ammo = function(pair, ...) if M.proxy_has_ammo(pair) then return true end if M.station_has_ammo(pair) then return M.load_proxy_from_station(pair, "station-or-proxy-check-0649") and M.proxy_has_ammo(pair) end return false end
  return true
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  if M.proxy_has_ammo(pair) then return false end
  local item = M.station_ammo(pair)
  if not item then return false end
  local combatish = valid(pair.combat_target) or valid(pair.target) or lower(pair.mode):find("ammo", 1, true) or pair.need_ammunition or pair.no_ammo_0295 or pair.pinned_no_ammo_0295
  if combatish or pair.proxy then return M.load_proxy_from_station(pair, reason or "service") end
  return false
end

function M.service_all(reason)
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, did = pcall(M.service_pair, pair, reason or "pulse"); if ok and did then n = n + 1 end end end
  return n
end

function M.install()
  root(); wrap_ammo_functions(); _G.TechPriestsProxyAmmoHardener0649 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "proxy_ammo_hardener_0649", category = "combat", interval = M.tick_interval, priority = 54, budget = 6, fn = function(event, budget) wrap_ammo_functions(); M.service_all("broker"); return true end, note = "load station ammunition into hidden proxy gun before combat considers ammo satisfied" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() wrap_ammo_functions(); M.service_all("nth-tick") end, { owner = "proxy_ammo_hardener_0649", category = "combat", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() wrap_ammo_functions(); M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] proxy ammo hardener installed") end
  return true
end

return M
