-- scripts/core/order_orchestrator_0597.lua
-- Tech Priests 0.1.597
--
-- Strategic order orchestration / target reservation economy.
--
-- This module is deliberately not a new priest behavior controller.  It wraps
-- the existing resource doctrine and order queue at the authority boundary so
-- repeated "go get copper/iron/stone" decisions are coordinated before they
-- reach pathfinding.  The goal is to turn many identical local acquisition
-- demands into stable target assignments with short leases instead of allowing
-- every priest to scan, choose, and path to the same resource tile.

local M = {}
M.version = "0.1.597"
M.storage_key = "order_orchestrator_0597"
M.resource_lease_ticks = 60 * 4
M.source_cache_ticks = 60 * 8
M.cleanup_interval = 60 * 13
M.default_radius = 48
M.scan_limit = 512
M.max_candidate_scan = 512

local pre_submit_order = nil
local pre_doctrine_find_mineable_source = nil
local pre_doctrine_start_direct_task = nil
local pre_doctrine_handle_no_source = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function pos_key(pos)
  if not pos then return "nil" end
  return tostring(math.floor(((pos.x or pos[1] or 0) * 10) + 0.5)) .. ":" .. tostring(math.floor(((pos.y or pos[2] or 0) * 10) + 0.5))
end
local function surface_key(surface)
  if not surface then return "nil" end
  return tostring(surface.index or surface.name or "surface")
end
local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  return surface_key(entity.surface) .. ":" .. tostring(entity.name or entity.type or "?") .. ":" .. pos_key(entity.position)
end
local function station_unit(pair)
  return pair and (pair.station_unit or unit(pair.station)) or nil
end
local function priest_unit(pair)
  return pair and (pair.priest_unit or unit(pair.priest)) or nil
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function dist_sq(a,b)
  if not (a and b) then return nil end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx*dx + dy*dy
end

local function runtime_radius(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or nil
  if (not r) and type(_G.get_station_operating_radius) == "function" and valid(pair and pair.station) then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then r = tonumber(got) end
  end
  return r or M.default_radius
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item_name or v.output_item or v.wanted_item or v.item or v.name or v.kind
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      resource_orchestration = true,
      order_annotation = true,
      reservations = {},
      station_cache = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.resource_orchestration == nil then r.resource_orchestration = true end
  if r.order_annotation == nil then r.order_annotation = true end
  r.reservations = r.reservations or {}
  r.station_cache = r.station_cache or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n)
  local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1)
end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 96 do table.remove(r.recent,1) end
end

local function resource_family(item)
  item = lower(item)
  if item:find("copper",1,true) then return "copper" end
  if item:find("iron",1,true) then return "iron" end
  if item:find("coal",1,true) then return "coal" end
  if item:find("stone",1,true) then return "stone" end
  if item:find("uranium",1,true) then return "uranium" end
  return item ~= "" and item or "unknown"
end

local function reservation_surface_table(root, surface)
  local sk = surface_key(surface)
  root.reservations[sk] = root.reservations[sk] or {}
  return root.reservations[sk]
end

local function station_cache_key(pair, item)
  return surface_key(pair.station.surface) .. ":" .. safe(station_unit(pair)) .. ":" .. resource_family(item)
end

local function release_expired(root)
  local t = now()
  local removed = 0
  for sk, tbl in pairs(root.reservations or {}) do
    for key, rec in pairs(tbl or {}) do
      local ent = rec and rec.entity
      if not rec or (rec.expires_tick and rec.expires_tick < t) or (ent and not valid(ent)) then
        tbl[key] = nil
        removed = removed + 1
      end
    end
  end
  for key, rec in pairs(root.station_cache or {}) do
    if not rec or (rec.expires_tick and rec.expires_tick < t) or (rec.entity and not valid(rec.entity)) then
      root.station_cache[key] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then stat("cleanup_removed", removed) end
end

local function products_match(entity, wanted)
  if not valid(entity) then return false, nil end
  wanted = tostring(wanted or "")
  local fam = resource_family(wanted)
  if entity.name and resource_family(entity.name) == fam then return true, entity.name end
  local proto = entity.prototype
  local products = proto and proto.mineable_properties and proto.mineable_properties.products
  if type(products) == "table" then
    for _, p in pairs(products) do
      local name = p and (p.name or p[1])
      if name and (name == wanted or resource_family(name) == fam) then return true, name end
    end
  end
  return false, nil
end

local function already_reserved(root, entity, pair, item)
  local key = entity_key(entity)
  if not key then return false, nil end
  local tbl = reservation_surface_table(root, entity.surface)
  local rec = tbl[key]
  if not rec then return false, nil end
  if rec.expires_tick and rec.expires_tick < now() then tbl[key] = nil; return false, nil end
  local same_priest = rec.priest_unit and rec.priest_unit == priest_unit(pair)
  -- Same station still counts as busy for different priests.  The whole point
  -- is to prevent same-station swarms from dogpiling one resource tile.  Only
  -- the original priest may keep refreshing its own reservation.
  if same_priest then return false, rec end
  return true, rec
end

function M.reserve_source(pair, source, wanted, reason)
  local r = M.root()
  if r.enabled == false or r.resource_orchestration == false or not (valid_pair(pair) and source) then return source end
  local entity = source.entity or source.source
  if not valid(entity) then return source end
  local key = entity_key(entity)
  if not key then return source end
  local tbl = reservation_surface_table(r, entity.surface)
  local item = item_from(source) or wanted
  tbl[key] = {
    tick = now(),
    expires_tick = now() + M.resource_lease_ticks,
    station_unit = station_unit(pair),
    priest_unit = priest_unit(pair),
    force_index = pair.station.force.index,
    item = item,
    wanted = wanted,
    reason = tostring(reason or "resource-reservation"),
    entity = entity,
    position = entity.position,
  }
  source.orchestrated_0597 = true
  source.reservation_key_0597 = key
  source.reserved_by_station_0597 = station_unit(pair)
  source.reserved_by_priest_0597 = priest_unit(pair)
  pair.order_orchestrator_0597 = pair.order_orchestrator_0597 or {}
  pair.order_orchestrator_0597.last_resource_reservation = {
    tick = now(), key = key, item = item, wanted = wanted, position = entity.position,
  }
  stat("resource_reserved")
  return source
end

function M.find_orchestrated_mineable_source(pair, wanted, recipe, allow_primitive)
  local r = M.root()
  if r.enabled == false or r.resource_orchestration == false or not valid_pair(pair) or not wanted then return nil end
  release_expired(r)
  local ckey = station_cache_key(pair, wanted)
  local cached = r.station_cache[ckey]
  if cached and cached.expires_tick and cached.expires_tick >= now() and valid(cached.entity) then
    local busy = already_reserved(r, cached.entity, pair, wanted)
    if not busy then
      local src = {
        kind = "direct-mine-0597",
        entity = cached.entity,
        item_name = cached.item or wanted,
        output_item = cached.item or wanted,
        wanted_item = wanted,
        count = 1,
        value = cached.value or 1000,
        station_distance_sq = dist_sq(cached.entity.position, pair.station.position) or 0,
        orchestrated_cache_hit_0597 = true,
      }
      stat("source_cache_hit")
      return M.reserve_source(pair, src, wanted, "source-cache-hit-0597")
    end
  end

  local station = pair.station
  local radius = runtime_radius(pair)
  local area = {{station.position.x - radius, station.position.y - radius}, {station.position.x + radius, station.position.y + radius}}
  local ents = nil
  local indexed = rawget(_G, "TechPriestsEfficiencyEconomy0579")
  if indexed and type(indexed.entities_for_area) == "function" then
    local ok, got = pcall(indexed.entities_for_area, station.surface, area)
    if ok and type(got) == "table" then ents = got; stat("used_cell_index") end
  end
  if not ents then
    local ok, got = pcall(function()
      return station.surface.find_entities_filtered({ area = area, type = {"resource","tree","simple-entity","simple-entity-with-owner"}, limit = M.scan_limit })
    end)
    if ok then ents = got end
    stat("fallback_source_scans")
  end
  if type(ents) ~= "table" then return nil end

  local best, best_score = nil, nil
  local considered = 0
  for _, ent in pairs(ents) do
    if valid(ent) and ent.surface == station.surface and considered < M.max_candidate_scan then
      considered = considered + 1
      local match, prod = products_match(ent, wanted)
      if match then
        local busy = already_reserved(r, ent, pair, wanted)
        if not busy then
          local d = dist_sq(ent.position, station.position) or 999999
          -- Prefer closest eligible tile/entity.  This is intentionally boring:
          -- boring target choice is cheap and predictable.
          local score = d
          if not best_score or score < best_score then
            best_score = score
            best = { kind="direct-mine-0597", entity=ent, item_name=prod or wanted, output_item=prod or wanted, wanted_item=wanted, count=1, value=1000, station_distance_sq=d }
          end
        else
          stat("candidate_reserved_skip")
        end
      end
    end
  end
  stat("resource_candidates_considered", considered)
  if best then
    r.station_cache[ckey] = { tick=now(), expires_tick=now()+M.source_cache_ticks, entity=best.entity, item=best.item_name, value=best.value }
    stat("source_cache_store")
    return M.reserve_source(pair, best, wanted, "resource-orchestrator-0597")
  end
  stat("source_not_found")
  return nil
end

local function annotate_order(pair, order)
  if not (pair and order) then return end
  local r = M.root()
  if r.enabled == false or r.order_annotation == false then return end
  local k = lower(order.kind)
  if k ~= "acquisition" and k ~= "direct_mine" and k ~= "gather" and k ~= "logistics" and k ~= "emergency_craft" then return end
  local item = item_from(order)
  if not item then return end
  order.orchestrated_0597 = true
  order.orchestrator_family_0597 = resource_family(item)
  order.orchestrator_station_0597 = station_unit(pair)
  order.orchestrator_priest_0597 = priest_unit(pair)
  order.orchestrator_tick_0597 = now()
  if order.target and valid(order.target) then
    local key = entity_key(order.target)
    order.reservation_key_0597 = key
  end
  stat("orders_annotated")
end

local function wrap_order_submit()
  if type(_G.tech_priests_0469_submit_order) ~= "function" or pre_submit_order then return false end
  pre_submit_order = _G.tech_priests_0469_submit_order
  _G.TECH_PRIESTS_0597_PRE_SUBMIT_ORDER = pre_submit_order
  _G.tech_priests_0469_submit_order = function(pair, order, opts, ...)
    annotate_order(pair, order)
    return pre_submit_order(pair, order, opts, ...)
  end
  return true
end

local function wrap_resource_doctrine()
  local ok, Doctrine = pcall(require, "scripts.core.resource_doctrine")
  if not (ok and Doctrine) then return false end
  local wrapped = 0
  if type(Doctrine.find_mineable_source) == "function" and not pre_doctrine_find_mineable_source then
    pre_doctrine_find_mineable_source = Doctrine.find_mineable_source
    Doctrine.TECH_PRIESTS_0597_PRE_FIND_MINEABLE_SOURCE = pre_doctrine_find_mineable_source
    Doctrine.find_mineable_source = function(pair, wanted, recipe, allow_primitive, ...)
      local src = M.find_orchestrated_mineable_source(pair, wanted, recipe, allow_primitive)
      if src then return src end
      local fallback = pre_doctrine_find_mineable_source(pair, wanted, recipe, allow_primitive, ...)
      if fallback then fallback.orchestrator_fallback_0597 = true; return M.reserve_source(pair, fallback, wanted, "legacy-fallback-0597") end
      return nil
    end
    wrapped = wrapped + 1
  end
  if type(Doctrine.start_direct_task) == "function" and not pre_doctrine_start_direct_task then
    pre_doctrine_start_direct_task = Doctrine.start_direct_task
    Doctrine.TECH_PRIESTS_0597_PRE_START_DIRECT_TASK = pre_doctrine_start_direct_task
    Doctrine.start_direct_task = function(pair, source, wanted, reason, ...)
      if source then source = M.reserve_source(pair, source, wanted, reason or "start-direct-0597") end
      return pre_doctrine_start_direct_task(pair, source, wanted, reason, ...)
    end
    wrapped = wrapped + 1
  end
  if type(Doctrine.handle_no_source) == "function" and not pre_doctrine_handle_no_source then
    pre_doctrine_handle_no_source = Doctrine.handle_no_source
    Doctrine.TECH_PRIESTS_0597_PRE_HANDLE_NO_SOURCE = pre_doctrine_handle_no_source
    Doctrine.handle_no_source = function(pair, wanted, recipe, reason, ...)
      -- A single station/item cooldown means a hundred priests asking for the
      -- same missing source do not all rewalk the world in the same moment.
      local r = M.root()
      if r.enabled ~= false and valid_pair(pair) and wanted then
        local key = station_cache_key(pair, wanted) .. ":miss"
        local miss = r.station_cache[key]
        if miss and miss.expires_tick and miss.expires_tick >= now() then
          stat("no_source_cooldown_hit")
          return false
        end
        local ok2, did = pcall(pre_doctrine_handle_no_source, pair, wanted, recipe, reason, ...)
        if ok2 and did then return did end
        r.station_cache[key] = { tick=now(), expires_tick=now()+60*3, miss=true }
        stat("no_source_cooldown_store")
        return false
      end
      return pre_doctrine_handle_no_source(pair, wanted, recipe, reason, ...)
    end
    wrapped = wrapped + 1
  end
  return wrapped > 0
end

function M.release_pair(pair, reason)
  local r = M.root()
  if not pair then return 0 end
  local pu = priest_unit(pair)
  local su = station_unit(pair)
  local removed = 0
  for sk, tbl in pairs(r.reservations or {}) do
    for key, rec in pairs(tbl or {}) do
      if rec and ((pu and rec.priest_unit == pu) or (su and rec.station_unit == su and reason == "station")) then
        tbl[key] = nil
        removed = removed + 1
      end
    end
  end
  if removed > 0 then stat("released_pair_reservations", removed) end
  return removed
end

local function install_cleanup()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local fn = function() release_expired(M.root()) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.cleanup_interval, fn, { owner="order_orchestrator_0597", category="economy", priority="last", note="expire resource reservations and source cache" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.cleanup_interval, fn)
  end
end

local function install_command()
  if not commands then return end
  commands.add_command("tp-order-orchestrator-0597", "Show Tech-Priests order orchestration/reservation economy counters.", function(cmd)
    local r = M.root()
    local reservations = 0
    for _,tbl in pairs(r.reservations or {}) do for _ in pairs(tbl or {}) do reservations = reservations + 1 end end
    local cache = 0
    for _ in pairs(r.station_cache or {}) do cache = cache + 1 end
    local msg = "[tp-order-orchestrator-0597] enabled="..safe(r.enabled)
      .." reservations="..safe(reservations).." cache="..safe(cache)
      .." reserved="..safe(r.stats.resource_reserved or 0)
      .." cache_hit="..safe(r.stats.source_cache_hit or 0)
      .." fallback_scans="..safe(r.stats.fallback_source_scans or 0)
      .." reserved_skips="..safe(r.stats.candidate_reserved_skip or 0)
      .." no_source_hits="..safe(r.stats.no_source_cooldown_hit or 0)
    local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  local a = wrap_order_submit()
  local b = wrap_resource_doctrine()
  install_cleanup()
  install_command()
  _G.TechPriestsOrderOrchestrator0597 = M
  _G.tech_priests_0597_reserve_source = M.reserve_source
  _G.tech_priests_0597_find_orchestrated_mineable_source = M.find_orchestrated_mineable_source
  remember("install", "wrapped_submit="..safe(a).." wrapped_resource_doctrine="..safe(b))
  if log then log("[Tech-Priests 0.1.597] order orchestrator installed; resource tile reservations and station/item source caching active") end
  return true
end

return M
