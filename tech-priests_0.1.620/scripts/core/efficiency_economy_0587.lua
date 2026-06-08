-- scripts/core/efficiency_economy_0587.lua
-- Tech Priests 0.1.587
--
-- Logistics/supply economy pass.  This is a cache governor around the existing
-- inventory steward / station work inventory / authority corridor logistics
-- surfaces.  It does not choose work, move priests, craft, mine, or deposit
-- outputs.  It only reuses very short-lived answers for repeated same-priest /
-- same-item supply questions so large priest populations do not all rediscover
-- the same station-source lists and counts in the same few ticks.

local M = {}
M.version = "0.1.587"
M.storage_key = "efficiency_economy_0587"
M.source_ttl = 45
M.count_ttl_positive = 45
M.count_ttl_zero = 20
M.authority_ttl = 90
M.cleanup_interval = 60 * 19
M.max_cache_entries = 2048

local originals = {}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function surface_key(pair) return pair and valid(pair.station) and tostring(pair.station.surface.index or pair.station.surface.name or "surface") or "nil" end
local function force_key(pair) return pair and valid(pair.station) and tostring(pair.station.force.index or pair.station.force.name or "force") or "nil" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

local function order_signature(pair)
  local q = pair and pair.order_queue_0469
  local o = q and q.current or pair and pair.active_order_0469 or nil
  if type(o) ~= "table" then
    return tostring(pair and pair.mode or "idle") .. ":" .. tostring(pair and pair.active_task or "")
  end
  return tostring(o.key or o.id or o.kind or o.type or "order") .. ":" .. tostring(o.status or "") .. ":" .. tostring(o.item or o.item_name or "") .. ":" .. tostring(o.expires_tick or "")
end

local function hierarchy_network_signature(pair)
  -- Network boundary: until the future intranetwork-link building exists, supply
  -- answers are cached only for this pair and its direct superior chain.  Two
  -- unrelated hierarchies on the same force/surface never share one logistics
  -- cache bucket.
  local bits = {}
  local seen = {}
  local function add(p)
    local u = station_unit(p)
    if u and not seen[u] then seen[u] = true; bits[#bits+1] = tostring(u) end
  end
  add(pair)
  local ok,H = pcall(require, "scripts.core.command_hierarchy_0480")
  local p = pair
  for _=1,5 do
    local nextp = nil
    if ok and H and H.superior then local ok2,out=pcall(H.superior,p); if ok2 then nextp=out end end
    if not nextp then
      local su = p and p.command_hierarchy_0480 and p.command_hierarchy_0480.superior_unit
      local map = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
      nextp = su and (map[su] or map[tostring(su)]) or nil
    end
    if not valid_pair(nextp) then break end
    add(nextp); p = nextp
  end
  return table.concat(bits, ">")
end

local function pair_key(pair)
  local u = station_unit(pair)
  if not u then return nil end
  return surface_key(pair) .. ":" .. force_key(pair) .. ":net=" .. hierarchy_network_signature(pair) .. ":home=" .. tostring(u)
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      cache_sources = true,
      cache_counts = true,
      cache_authority = true,
      source_cache = {},
      count_cache = {},
      authority_cache = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.cache_sources == nil then r.cache_sources = true end
  if r.cache_counts == nil then r.cache_counts = true end
  if r.cache_authority == nil then r.cache_authority = true end
  r.source_cache = r.source_cache or {}
  r.count_cache = r.count_cache or {}
  r.authority_cache = r.authority_cache or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 64 do table.remove(r.recent, 1) end
end

local function valid_source_list(list)
  if type(list) ~= "table" then return false end
  for _, src in ipairs(list) do
    if type(src) == "table" then
      local e = src.entity
      local inv = src.inv or src.inventory
      if e ~= nil and not valid(e) then return false end
      if inv ~= nil and inv.valid == false then return false end
    end
  end
  return true
end

local function source_cache_key(pair, label)
  local pk = pair_key(pair)
  if not pk then return nil end
  return tostring(label or "sources") .. ":" .. pk .. ":" .. order_signature(pair)
end

local function get_source_cache(pair, label)
  local r=M.root()
  if r.enabled == false or r.cache_sources == false then return nil end
  local key = source_cache_key(pair, label)
  local rec = key and r.source_cache[key]
  if rec and now() <= (rec.expires_tick or 0) and valid_source_list(rec.list) then
    stat("source_cache_hits")
    return rec.list
  end
  if key then r.source_cache[key] = nil end
  stat("source_cache_misses")
  return nil
end

local function put_source_cache(pair, label, list)
  local r=M.root()
  if r.enabled == false or r.cache_sources == false or not valid_source_list(list) then return list end
  local key = source_cache_key(pair, label)
  if key then r.source_cache[key] = { list = list, expires_tick = now() + M.source_ttl, tick = now() } end
  return list
end

local function count_cache_key(pair, item, label)
  local pk = pair_key(pair)
  if not (pk and item) then return nil end
  return tostring(label or "count") .. ":" .. pk .. ":" .. tostring(item) .. ":" .. order_signature(pair)
end

local function get_count_cache(pair, item, label)
  local r=M.root()
  if r.enabled == false or r.cache_counts == false then return nil end
  local key = count_cache_key(pair, item, label)
  local rec = key and r.count_cache[key]
  if rec and now() <= (rec.expires_tick or 0) then
    stat("count_cache_hits")
    return rec.value
  end
  if key then r.count_cache[key] = nil end
  stat("count_cache_misses")
  return nil
end

local function put_count_cache(pair, item, label, value)
  local r=M.root()
  if r.enabled == false or r.cache_counts == false then return value end
  local key = count_cache_key(pair, item, label)
  local ttl = (tonumber(value) or 0) > 0 and M.count_ttl_positive or M.count_ttl_zero
  if key then r.count_cache[key] = { value = tonumber(value) or 0, expires_tick = now() + ttl, tick = now() } end
  return value
end

local function invalidate_pair(pair, reason)
  local pk = pair_key(pair)
  if not pk then return end
  local r=M.root()
  for k,_ in pairs(r.source_cache or {}) do if k:find(pk, 1, true) then r.source_cache[k] = nil; stat("source_cache_invalidated") end end
  for k,_ in pairs(r.count_cache or {}) do if k:find(pk, 1, true) then r.count_cache[k] = nil; stat("count_cache_invalidated") end end
  for k,_ in pairs(r.authority_cache or {}) do if k:find(pk, 1, true) then r.authority_cache[k] = nil; stat("authority_cache_invalidated") end end
  if reason then remember("invalidate-pair", pk .. " " .. tostring(reason)) end
end

function M.invalidate_all(reason)
  local r=M.root()
  r.source_cache = {}; r.count_cache = {}; r.authority_cache = {}
  stat("invalidate_all")
  if reason then remember("invalidate-all", reason) end
end

local function wrap_source_func(name, label)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" or originals[name] then return false end
  originals[name] = fn
  _G[name] = function(pair, ...)
    if not valid_pair(pair) then return originals[name](pair, ...) end
    local cached = get_source_cache(pair, label or name)
    if cached then return cached end
    local list = originals[name](pair, ...)
    if type(list) == "table" then put_source_cache(pair, label or name, list) end
    return list
  end
  stat("wrapped_" .. name)
  return true
end

local function wrap_count_func(name, label)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" or originals[name] then return false end
  originals[name] = fn
  _G[name] = function(pair, item, ...)
    if not valid_pair(pair) or not item then return originals[name](pair, item, ...) end
    local c = get_count_cache(pair, item, label or name)
    if c ~= nil then return c end
    local value = originals[name](pair, item, ...)
    return put_count_cache(pair, item, label or name, value)
  end
  stat("wrapped_" .. name)
  return true
end

local function wrap_remove_func(name, label)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" or originals[name] then return false end
  originals[name] = fn
  _G[name] = function(pair, item, count, ...)
    local result = originals[name](pair, item, count, ...)
    if (tonumber(result) or 0) > 0 then invalidate_pair(pair, (label or name) .. ":remove") end
    return result
  end
  stat("wrapped_" .. name)
  return true
end

local function wrap_authority_pairs()
  local name = "tech_priests_0573_authorized_pairs"
  local fn = rawget(_G, name)
  if type(fn) ~= "function" or originals[name] then return false end
  originals[name] = fn
  _G[name] = function(pair, ...)
    local r=M.root()
    if r.enabled == false or r.cache_authority == false or not valid_pair(pair) then return originals[name](pair, ...) end
    local key = pair_key(pair)
    if key then key = "auth:" .. key .. ":" .. order_signature(pair) end
    local rec = key and r.authority_cache[key]
    if rec and now() <= (rec.expires_tick or 0) and type(rec.list) == "table" then
      stat("authority_cache_hits")
      return rec.list, rec.order, rec.source
    end
    local list, order, source = originals[name](pair, ...)
    if key and type(list) == "table" then
      r.authority_cache[key] = { list=list, order=order, source=source, expires_tick=now()+M.authority_ttl, tick=now() }
    end
    stat("authority_cache_misses")
    return list, order, source
  end
  stat("wrapped_authority_pairs")
  return true
end

local function install_event_invalidation()
  local ok, R = pcall(require, "scripts.core.runtime_event_registry")
  if not (ok and R and R.on_event) then return false end
  local events = {}
  local d = defines and defines.events or {}
  for _, ev in ipairs({ d.on_built_entity, d.on_robot_built_entity, d.script_raised_built, d.script_raised_revive, d.on_player_mined_entity, d.on_robot_mined_entity, d.on_entity_died, d.script_raised_destroy }) do
    if ev then events[#events+1] = ev end
  end
  if #events > 0 then
    R.on_event(events, function(event)
      -- Inventory topology and local source availability may change; clear the
      -- short caches.  This is deliberately broad and cheap because the caches
      -- are tiny and short-lived.
      M.invalidate_all("entity-event")
    end, nil, { owner="efficiency_economy_0587", category="economy", note="invalidate logistics source caches after entity topology changes" })
  end
  return true
end

function M.cleanup()
  local r=M.root(); local t=now(); local removed=0
  local function prune(tab)
    for k,rec in pairs(tab or {}) do
      if type(rec) ~= "table" or t > (tonumber(rec.expires_tick or 0) or 0) then tab[k]=nil; removed=removed+1 end
    end
  end
  prune(r.source_cache); prune(r.count_cache); prune(r.authority_cache)
  if removed > 0 then stat("cleanup_removed", removed) end
end

local function cache_size(tab) local n=0; for _ in pairs(tab or {}) do n=n+1 end; return n end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0587") end end)
  commands.add_command("tp-efficiency-economy-0587", "Tech Priests 0.1.587 logistics/supply cache economy. Params: on/off/sources-on/sources-off/counts-on/counts-off/auth-on/auth-off/clear/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r=M.root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false
    elseif p == "sources-on" then r.cache_sources = true elseif p == "sources-off" then r.cache_sources = false
    elseif p == "counts-on" then r.cache_counts = true elseif p == "counts-off" then r.cache_counts = false
    elseif p == "auth-on" then r.cache_authority = true elseif p == "auth-off" then r.cache_authority = false
    elseif p == "clear" then M.invalidate_all("command-clear") end
    local msg = "[tp-efficiency-economy-0587] enabled="..safe(r.enabled).." hierarchy_local=true sources="..safe(r.cache_sources).." counts="..safe(r.cache_counts).." auth="..safe(r.cache_authority)
      .." source_cache="..safe(cache_size(r.source_cache)).." count_cache="..safe(cache_size(r.count_cache)).." authority_cache="..safe(cache_size(r.authority_cache))
      .." source_hits="..safe(r.stats.source_cache_hits or 0).." count_hits="..safe(r.stats.count_cache_hits or 0).." auth_hits="..safe(r.stats.authority_cache_hits or 0)
      .." invalidated="..safe((r.stats.source_cache_invalidated or 0)+(r.stats.count_cache_invalidated or 0)+(r.stats.authority_cache_invalidated or 0))
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_authority_pairs()
  wrap_source_func("tech_priests_inventory_steward_sources_for_pair", "steward-sources")
  wrap_source_func("tech_priests_0358_station_sources_for_pair", "station-sources")
  wrap_count_func("tech_priests_0358_station_item_count", "station-count")
  wrap_count_func("tech_priests_0573_authorized_item_count", "authority-count")
  wrap_remove_func("tech_priests_0358_try_remove_from_station", "station-remove")
  wrap_remove_func("tech_priests_0573_authorized_remove", "authority-remove")
  install_event_invalidation()
  local ok,R=pcall(require,"scripts.core.runtime_event_registry")
  if ok and R and R.on_nth_tick then R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0587", category="economy", priority="last", note="prune logistics cache entries" }) end
  _G.TechPriestsEfficiencyEconomy0587 = M
  _G.tech_priests_0587_invalidate_logistics_cache = M.invalidate_all
  install_command()
  remember("install", "logistics/supply cache economy installed")
  if log then log("[Tech-Priests 0.1.587] logistics/supply cache economy loaded") end
  return true
end

return M
