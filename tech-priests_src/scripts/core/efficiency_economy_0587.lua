-- scripts/core/efficiency_economy_0587.lua
-- Tech Priests 0.1.587
--
-- Logistics/supply economy pass.  This is a cache governor around the existing
-- inventory steward / station work inventory / authority corridor logistics
-- surfaces.  It does not choose work, move priests, craft, mine, or deposit
-- outputs. Legacy supply answers keep their short TTLs; physical source
-- membership is retained and maintained by events, independently of item stock.

local M = {}
M.version = "0.1.587"
M.storage_key = "efficiency_economy_0587"
M.source_ttl = 45
M.container_source_limit = 256
-- Events update known membership immediately. Unobserved vehicle movement
-- still needs a bounded, demand-driven discovery of newly arriving sources.
M.candidate_ttl = 60 * 30
M.count_ttl_positive = 45
M.count_ttl_zero = 20
M.authority_ttl = 90
M.cleanup_interval = 60 * 19
M.max_cache_entries = 2048

local originals = {}
local container_events_installed = false

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

local function candidate_cache_key(pair, domain, force_policy)
  local unit = station_unit(pair)
  if not unit then return nil end
  -- These candidates are local physical containers, not a superior-chain
  -- stock entitlement. Order changes do not change the spatial search.
  return "source-candidates:" .. tostring(domain) .. ":" .. force_policy
    .. ":" .. surface_key(pair) .. ":" .. force_key(pair)
    .. ":home=" .. tostring(unit)
end

local function inside_candidate_area(record, position)
  return position.x >= record.x - record.radius
    and position.x <= record.x + record.radius
    and position.y >= record.y - record.radius
    and position.y <= record.y + record.radius
end

local function member_matches(record, entity)
  if not valid(entity) or not record.types[entity.type]
      or entity.surface ~= record.surface
      or not inside_candidate_area(record, entity.position) then return false end
  return true
end

local function source_matches(record, entity)
  if not member_matches(record, entity) then return false end
  local force = entity.force
  return force == record.force or (record.force_policy == "same-or-neutral"
    and (not force or force.name == "neutral"))
end

local function source_types_match(record, types)
  if #record.type_names ~= #types then return false end
  for index, name in ipairs(types) do
    if record.type_names[index] ~= name then return false end
  end
  return true
end

local function candidate_view(record, limit)
  local list = record.list
  local size, read, write, accepted = #list, 1, 1, 0
  local view = {}
  while read <= size and (not limit or accepted < limit) do
    local entity = list[read]
    -- Eligibility remains live, but a known moving or force-changed entity
    -- must not be forgotten merely because it is temporarily out of range.
    if valid(entity) and record.types[entity.type] then
      list[write] = entity
      write = write + 1
      if source_matches(record, entity) then
        accepted = accepted + 1
        view[accepted] = entity
      end
    end
    read = read + 1
  end
  if write < read then
    -- Keep the unvisited overflow so a removed visible source promotes the
    -- next already-known entity without another spatial search.
    for index = read, size do list[write] = list[index]; write = write + 1 end
    for index = write, size do list[index] = nil end
  end
  return view
end

local function retained_candidates(pair, radius, domain, types, force_policy, discover, limit)
  if type(discover) ~= "function" then return nil end
  local r = M.root()
  if not valid_pair(pair) then return discover() end
  local cacheable = r.enabled ~= false and r.cache_sources ~= false
    and container_events_installed
  local key = cacheable and candidate_cache_key(pair, domain, force_policy) or nil
  local station = pair.station
  local position = station.position
  local cached = key and r.source_cache[key]
  if cached and cached.retained_candidates == 1 and cached.complete == true
      and now() < (tonumber(cached.expires_tick) or 0)
      and cached.station == station and cached.surface == station.surface
      and cached.force == station.force and cached.radius == radius
      and cached.x == position.x and cached.y == position.y
      and source_types_match(cached, types) then
    stat("retained_source_cache_hits")
    return candidate_view(cached, limit)
  end
  if key then r.source_cache[key] = nil end
  stat("retained_source_initial_discoveries")
  local list = discover()
  if type(list) == "table" then
    local record = { retained_candidates = 1, complete = true, list = list,
      domain = domain, force_policy = force_policy, types = {}, type_names = {},
      station = station, surface = station.surface, force = station.force,
      surface_index = station.surface.index, radius = radius,
      x = position.x, y = position.y, tick = now(),
      expires_tick = now() + M.candidate_ttl }
    for index, name in ipairs(types) do
      record.types[name], record.type_names[index] = true, name
    end
    if key then r.source_cache[key] = record end
    return candidate_view(record, limit)
  end
  return list
end

-- discover() must return a COMPLETE typed area result, independent of the
-- requested item. The existing source_cache owns this retained membership;
-- callers still recheck inventories, wire permissions, roles and live stock.
function M.source_candidates(pair, radius, domain, types, force_policy, discover)
  return retained_candidates(pair, radius, domain, types, force_policy, discover)
end

local container_types = { "container", "logistic-container", "car", "spider-vehicle" }
function M.container_candidates(pair, radius, discover)
  return retained_candidates(pair, radius, "generic-storage-0686", container_types,
    "same-force", discover, M.container_source_limit)
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

local function update_source_membership(record, event, change)
  local entity = event and (event.destination or event.created_entity or event.entity
    or event.vehicle or event.corpse)
  if not entity then
    if event and event.surface_index == record.surface_index then
      if change == "surface-deleted" then return "discard" end
      if change == "surface-cleared" then record.list = {}; return "updated" end
    end
    return nil
  end
  if entity == record.station then
    -- A changed station domain needs one initial population at its new area.
    if change == "removed" or not valid(entity)
        or entity.surface ~= record.surface or entity.force ~= record.force
        or entity.position.x ~= record.x or entity.position.y ~= record.y then
      return "discard"
    end
  end
  -- Belt/machine construction and combat deaths are irrelevant to these
  -- typed inventory lists. Reject before walking any retained candidates.
  if valid(entity) and not record.types[entity.type] then return nil end
  -- Keep physical membership independent of force policy. Factorio has no
  -- per-entity force-change event; eligibility is checked against the live
  -- force on every read, including an enemy/neutral source becoming friendly.
  local belongs = change ~= "removed" and member_matches(record, entity)
  local list, found, changed = record.list, false, false
  local write, size = 1, #record.list
  for index = 1, size do
    local candidate = list[index]
    if candidate == entity then
      found = true
      if belongs then list[write] = candidate; write = write + 1
      else changed = true end
    else
      list[write] = candidate
      write = write + 1
    end
  end
  for index = write, size do list[index] = nil end
  if belongs and not found then list[#list + 1] = entity; changed = true end
  if changed then return "updated" end
  return nil
end

function M.invalidate_entity_sources(event, change)
  local r = M.root()
  local invalidated, updated = 0, 0
  for key, record in pairs(r.source_cache) do
    -- Legacy count/source answers retain their invalidation semantics. The
    -- existing physical source lists change membership directly, without a
    -- full search at the next item question or visual radar refresh.
    if type(record) == "table" and record.retained_candidates == 1 then
      local result = update_source_membership(record, event, change or "built")
      if result == "discard" then r.source_cache[key] = nil; invalidated = invalidated + 1
      elseif result == "updated" then updated = updated + 1 end
    else
      r.source_cache[key] = nil
      invalidated = invalidated + 1
    end
  end
  r.count_cache, r.authority_cache = {}, {}
  if invalidated > 0 then stat("source_cache_invalidated", invalidated) end
  if updated > 0 then stat("source_membership_updates", updated) end
  stat("entity_source_invalidation_events")
  return invalidated + updated
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

local function source_event(event, change)
  if change == "player-moved" then
    local player = event and event.player_index and game and game.get_player
      and game.get_player(event.player_index) or nil
    local vehicle = player and player.valid and player.vehicle or nil
    if valid(vehicle) then return M.invalidate_entity_sources({ entity = vehicle }, "moved") end
    return 0
  elseif change == "train-moved" then
    local train = event and event.train
    if not (train and train.valid) then return 0 end
    local changed = 0
    for _, entity in pairs(train.carriages or {}) do
      if valid(entity) and entity.type == "cargo-wagon" then
        changed = changed + M.invalidate_entity_sources({ entity = entity }, "moved")
      end
    end
    return changed
  elseif change == "corpses-created" then
    local changed = 0
    for _, entity in pairs(event and event.corpses or {}) do
      if valid(entity) and entity.type == "character-corpse" then
        changed = changed + M.invalidate_entity_sources({ entity = entity }, "built")
      end
    end
    return changed
  end
  return M.invalidate_entity_sources(event, change)
end

local function install_event_invalidation()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    or package.loaded["scripts.core.runtime_event_registry"]
  if not R then local ok, found = pcall(require, "scripts.core.runtime_event_registry"); if ok then R = found end end
  if not (R and R.on_event) then return false end
  local events = {}
  local d = defines and defines.events or {}
  for _, spec in ipairs({
      { "on_built_entity", "built" }, { "on_robot_built_entity", "built" },
      { "script_raised_built", "built" }, { "script_raised_revive", "built" },
      { "on_space_platform_built_entity", "built" },
      { "on_player_mined_entity", "removed" }, { "on_robot_mined_entity", "removed" },
      { "on_space_platform_mined_entity", "removed" },
      { "on_entity_died", "removed" }, { "script_raised_destroy", "removed" },
      { "on_entity_cloned", "built" }, { "script_raised_teleported", "moved" },
      { "on_player_driving_changed_state", "moved" },
      { "on_player_changed_position", "player-moved" },
      { "on_player_changed_surface", "player-moved" },
      { "on_spider_command_completed", "moved" },
      { "on_train_changed_state", "train-moved" }, { "on_train_created", "train-moved" },
      { "on_post_entity_died", "corpses-created" },
      { "on_character_corpse_expired", "removed" },
      { "on_surface_cleared", "surface-cleared" },
      { "on_surface_deleted", "surface-deleted" } }) do
    if d[spec[1]] then events[#events + 1] = { id = d[spec[1]], change = spec[2] } end
  end
  if #events == 0 then return false end
  for _, event in ipairs(events) do
    local change = event.change
    local route = R.on_event(event.id,
      function(payload) return source_event(payload, change) end, nil,
      { owner="efficiency_economy_0587", category="economy", priority=-100001,
        note="maintain logistics source membership before topology consumers" })
    if not route then return false end
  end
  return true
end

function M.cleanup()
  local r=M.root(); local t=now(); local removed=0
  local function prune(tab)
    for k,rec in pairs(tab or {}) do
      local retained = type(rec) == "table" and rec.retained_candidates == 1
      local expired = retained and (not valid(rec.station)
          or rec.station.surface ~= rec.surface or rec.station.force ~= rec.force
          or rec.station.position.x ~= rec.x or rec.station.position.y ~= rec.y)
        or not retained and (type(rec) ~= "table" or t > (tonumber(rec.expires_tick or 0) or 0))
      if expired then tab[k]=nil; removed=removed+1 end
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
  container_events_installed = install_event_invalidation()
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
