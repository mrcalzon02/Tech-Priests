-- scripts/core/efficiency_economy_0575.lua
-- Tech Priests 0.1.575 corridor cache and phased path-economy pass.
--
-- This is an efficiency governor only.  It does not select work, complete work,
-- mine, consecrate, repair, or override dispatcher authority.  It reduces the
-- cost of the 0.1.573/0.1.574 authority-corridor model by caching short-lived
-- corridor authorization results, processing corridor audits in buckets, and
-- cleaning expired writ/corridor state so old orders do not remain hot forever.

local M = {}
M.version = "0.1.575"
M.storage_key = "efficiency_economy_0575"

M.auth_cache_ticks = 180          -- 3 seconds; enough to avoid repeated same-tick/same-target corridor walks.
M.negative_cache_ticks = 90       -- shorter for rejected targets so new orders can recover quickly.
M.service_interval = 127          -- prime-ish stagger against other service cadences.
M.service_budget = 6              -- max pairs to audit per pulse.
M.cleanup_interval = 60 * 20
M.max_recent = 96
M.log_interval = 60 * 15

local pre = {}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function pos_key(pos)
  if type(pos) ~= "table" then return safe(pos) end
  -- bucket to half tiles; this keeps tiny float jitter from defeating the cache.
  local x = math.floor(((tonumber(pos.x) or 0) * 2) + 0.5) / 2
  local y = math.floor(((tonumber(pos.y) or 0) * 2) + 0.5) / 2
  local surf = pos.surface and (pos.surface.index or pos.surface.name) or "home"
  return safe(surf)..":"..string.format("%.1f:%.1f", x, y)
end
local function dist_sq(a,b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      cache_authorization = true,
      bucket_corridor_service = true,
      cleanup_expired_writs = true,
      cursor = 1,
      next_cleanup = 0,
      auth_cache = {},
      auth_cache_by_station = {},
      stats = {},
      recent = {},
      last_log = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.cache_authorization == nil then r.cache_authorization = true end
  if r.bucket_corridor_service == nil then r.bucket_corridor_service = true end
  if r.cleanup_expired_writs == nil then r.cleanup_expired_writs = true end
  r.auth_cache = r.auth_cache or {}
  r.auth_cache_by_station = r.auth_cache_by_station or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.cursor = tonumber(r.cursor or 1) or 1
  r.next_cleanup = tonumber(r.next_cleanup or 0) or 0
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, detail, force)
  local r=M.root(); stat(action)
  local rec = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  r.recent[#r.recent+1] = rec
  while #r.recent > M.max_recent do table.remove(r.recent, 1) end
  local last = tonumber(r.last_log[action] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[action] = now()
    if log then log("[Tech-Priests 0.1.575] "..safe(action).." "..safe(detail)) end
  end
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return q and q.current or pair and pair.active_order_0469 or nil
end

local function order_fingerprint(order)
  if type(order) ~= "table" then return "no-order" end
  return safe(order.key or order.id or order.uid or (safe(order.kind)..":"..safe(order.item or order.item_name or order.requested_item or order.output_item))) ..
    ":" .. safe(order.status) .. ":" .. safe(order.expires_tick or order.expiry_tick or "")
end

local function cache_key(pair, pos, reason, opts)
  return safe(station_unit(pair)).."|"..safe(priest_unit(pair)).."|"..pos_key(pos).."|"..order_fingerprint(current_order(pair)).."|"..safe(opts and opts.owner or "").."|"..safe(reason or "")
end

local function remember_cache_station(r, su, key)
  su = safe(su)
  local list = r.auth_cache_by_station[su]
  if type(list) ~= "table" then list = {}; r.auth_cache_by_station[su] = list end
  list[#list+1] = key
  if #list > 128 then table.remove(list, 1) end
end

function M.invalidate_station(station_or_unit, reason)
  local r = M.root()
  local su = type(station_or_unit)=="table" and (station_or_unit.unit_number or station_or_unit.station_unit) or station_or_unit
  su = safe(su)
  local list = r.auth_cache_by_station[su]
  if type(list)=="table" then
    for _, key in ipairs(list) do r.auth_cache[key] = nil end
    r.auth_cache_by_station[su] = nil
    stat("station_cache_invalidated", #list)
  end
  record("station-cache-invalidated", "station="..su.." reason="..safe(reason))
end

function M.invalidate_pair(pair, reason)
  if not pair then return end
  M.invalidate_station(station_unit(pair), reason or "pair")
end

local function get_cached(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.cache_authorization == false then return nil end
  local key = cache_key(pair,pos,reason,opts)
  local rec = r.auth_cache[key]
  if type(rec)=="table" and (tonumber(rec.until_tick or 0) or 0) >= now() then
    stat(rec.allowed and "auth_cache_hit_allowed" or "auth_cache_hit_rejected")
    return rec.allowed, rec.auth_rec, rec.source, key
  end
  if rec then r.auth_cache[key] = nil end
  stat("auth_cache_miss")
  return nil, nil, nil, key
end

local function set_cached(pair, key, allowed, auth_rec, source)
  local r=M.root()
  if r.enabled == false or r.cache_authorization == false or not key then return end
  local ttl = allowed and M.auth_cache_ticks or M.negative_cache_ticks
  r.auth_cache[key] = { allowed = allowed and true or false, auth_rec = auth_rec, source = source, until_tick = now() + ttl }
  remember_cache_station(r, station_unit(pair), key)
  if auth_rec and auth_rec.station_unit then remember_cache_station(r, auth_rec.station_unit, key) end
  stat(allowed and "auth_cache_store_allowed" or "auth_cache_store_rejected")
end

local function wrap_corridor_authorization()
  local C = rawget(_G, "TECH_PRIESTS_AUTHORITY_CORRIDOR_PATHING_0574")
  if not (C and type(C.authorization_for_destination)=="function") or C.efficiency_economy_0575_wrapped then return false end
  C.efficiency_economy_0575_wrapped = true
  pre.authorization_for_destination = C.authorization_for_destination
  C.authorization_for_destination = function(pair, pos, reason, opts, ...)
    local cached_allowed, cached_rec, cached_source, key = get_cached(pair, pos, reason, opts)
    if cached_allowed ~= nil then return cached_allowed, cached_rec, cached_source end
    local allowed, auth_rec, source = pre.authorization_for_destination(pair, pos, reason, opts, ...)
    set_cached(pair, key, allowed, auth_rec, source)
    return allowed, auth_rec, source
  end
  _G.tech_priests_0574_authorization_for_destination = C.authorization_for_destination
  return true
end

local function order_expired(order)
  return type(order)=="table" and order.expires_tick and now() > tonumber(order.expires_tick or 0)
end

function M.cleanup_pair(pair)
  if not valid_pair(pair) then return false end
  local changed = false
  local order = current_order(pair)
  if order_expired(order) then
    pair.authority_corridor_writ_0573 = nil
    pair.authority_corridor_path_0574 = nil
    pair.authorized_superior_station_0574 = nil
    M.invalidate_pair(pair, "expired-order")
    stat("expired_writ_cleanup")
    changed = true
  end
  -- If the current movement destination is effectively already reached, clear
  -- stale route hints so later scans do not keep auditing the same micro-target.
  local req = pair.movement_request_0418 or pair.movement_lease_0518
  local pos = type(req)=="table" and (req.position or req.destination or req.target_position or req.move_target or req.pos) or pair.move_target
  if type(pos)=="table" and valid(pair.priest) and dist_sq(pair.priest.position, pos) and dist_sq(pair.priest.position, pos) < 1.0 then
    pair.authority_corridor_last_waypoint_0575 = nil
    stat("near_destination_hint_clear")
  end
  return changed
end

local function pair_list()
  local out = {}
  for _, pair in pairs(pair_map()) do if valid_pair(pair) then out[#out+1] = pair end end
  table.sort(out, function(a,b) return (station_unit(a) or 0) < (station_unit(b) or 0) end)
  return out
end

function M.service_some()
  local r=M.root()
  if r.enabled == false then return false end
  wrap_corridor_authorization()
  local list = pair_list()
  local n = #list
  if n <= 0 then return false end
  local budget = math.min(M.service_budget, n)
  local cursor = math.max(1, math.min(tonumber(r.cursor or 1) or 1, n))
  for i=1,budget do
    local pair = list[cursor]
    if pair then M.cleanup_pair(pair) end
    cursor = cursor + 1
    if cursor > n then cursor = 1 end
  end
  r.cursor = cursor
  stat("service_pairs", budget)
  if r.cleanup_expired_writs ~= false and now() >= (tonumber(r.next_cleanup or 0) or 0) then
    r.next_cleanup = now() + M.cleanup_interval
    local removed = 0
    for key, rec in pairs(r.auth_cache or {}) do
      if type(rec) ~= "table" or (tonumber(rec.until_tick or 0) or 0) < now() then r.auth_cache[key] = nil; removed = removed + 1 end
    end
    r.auth_cache_by_station = {}
    for key, rec in pairs(r.auth_cache or {}) do
      if type(rec)=="table" then
        -- Rebuild only home station index when possible from the cache key.
        local su = tostring(key):match("^([^|]+)|")
        if su then remember_cache_station(r, su, key) end
      end
    end
    if removed > 0 then record("auth-cache-pruned", "removed="..removed) end
  end
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0575") end end)
  commands.add_command("tp-efficiency-economy-0575", "Tech Priests 0.1.575 corridor cache economy. Params: on/off/status/clear", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false elseif param=="clear" then r.auth_cache={}; r.auth_cache_by_station={}; record("manual-cache-clear", "command", true) end
    local count=0 for _ in pairs(r.auth_cache or {}) do count=count+1 end
    local msg="[tp-efficiency-economy-0575] enabled="..safe(r.enabled).." cache="..count.." hit_allowed="..safe(r.stats.auth_cache_hit_allowed or 0).." hit_rejected="..safe(r.stats.auth_cache_hit_rejected or 0).." misses="..safe(r.stats.auth_cache_miss or 0).." pruned="..safe(r.stats["auth-cache-pruned"] or 0).." services="..safe(r.stats.service_pairs or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_corridor_authorization()
  _G.TECH_PRIESTS_EFFICIENCY_ECONOMY_0575 = M
  _G.tech_priests_0575_invalidate_corridor_cache_for_station = M.invalidate_station
  _G.tech_priests_0575_invalidate_corridor_cache_for_pair = M.invalidate_pair
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick)=="function" then
    registry.on_nth_tick(M.service_interval, function() M.service_some() end, { owner="efficiency_economy_0575", category="economy", priority="last", note="cached corridor authorization and phased writ cleanup" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_interval, function() M.service_some() end)
  end
  record("install", "corridor cache economy installed", true)
  if log then log("[Tech-Priests 0.1.575] corridor cache economy installed") end
  return true
end

return M
