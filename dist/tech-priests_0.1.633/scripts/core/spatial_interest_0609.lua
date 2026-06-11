-- scripts/core/spatial_interest_0609.lua
-- Tech Priests 0.1.609
-- Future Efficiency Candidate A/F bounded pass:
-- spatial-interest telemetry and theater gating for nonessential visuals/audio.
--
-- This module is not a scheduler, cache, queue, reservation, or sleep authority.
-- It classifies pair/player proximity for existing presentation authorities so
-- offscreen periodic theater can become cheap without changing simulation work.

local M = {}
M.version = "0.1.609"
M.storage_key = "spatial_interest_0609"
M.near_radius = 96
M.far_radius = 192
M.report_sample_limit = 10000

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function metric(k, n) local fn = rawget(_G, "tech_priests_runtime_metric_0606"); if fn then pcall(fn, k, n or 1) end end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version = M.version, enabled = true, stats = {}, last_counts = {}, recent = {} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.last_counts = r.last_counts or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
  metric("spatial_interest_" .. tostring(k), n or 1)
end

local function remember(action, detail)
  local r = M.root()
  r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), detail = tostring(detail or "") }
  while #r.recent > 24 do table.remove(r.recent, 1) end
end

local function distance_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function player_iter()
  if game and game.connected_players then return pairs(game.connected_players) end
  return function() return nil end
end

local function selected_matches(player, pair)
  if not (player and player.valid and pair) then return false end
  local sel = player.selected
  if not valid(sel) then return false end
  return (valid(pair.station) and sel == pair.station) or (valid(pair.priest) and sel == pair.priest)
end

local function pair_position(pair)
  if valid(pair and pair.priest) then return pair.priest.position, pair.priest.surface end
  if valid(pair and pair.station) then return pair.station.position, pair.station.surface end
  return nil, nil
end

function M.players_near_position(surface, position, radius)
  if not (surface and position) then return false end
  local r2 = (tonumber(radius or M.near_radius) or M.near_radius) ^ 2
  for _, player in player_iter() do
    if player and player.valid and player.connected ~= false and player.surface == surface then
      local d2 = distance_sq(player.position, position)
      if d2 and d2 <= r2 then return true, player end
    end
  end
  return false, nil
end

function M.entity_observed(entity, radius)
  if not valid(entity) then return false end
  return M.players_near_position(entity.surface, entity.position, radius or M.near_radius)
end

function M.pair_observed(pair, radius)
  if not pair then return false end
  for _, player in player_iter() do
    if selected_matches(player, pair) then return true, player, "selected" end
  end
  local pos, surface = pair_position(pair)
  local near, player = M.players_near_position(surface, pos, radius or M.near_radius)
  if near then return true, player, "near-player" end
  return false, nil, "remote"
end

local function has_active_work(pair)
  if not pair then return false end
  if pair.repair_0516 and pair.repair_0516.phase and pair.repair_0516.phase ~= "none" and pair.repair_0516.phase ~= "complete" and pair.repair_0516.phase ~= "no-target" then return true end
  if pair.order_queue_0469 and pair.order_queue_0469.current then return true end
  if pair.active_order_0469 or pair.active_task or pair.active_task_0285 then return true end
  local mode = tostring(pair.mode or pair.state or pair.activity_mode or "")
  if mode ~= "" and mode ~= "idle" and mode ~= "none" then return true end
  return false
end

function M.classify_pair(pair)
  local observed = M.pair_observed(pair, M.near_radius)
  if observed then return "observed" end
  if has_active_work(pair) then return "active-remote" end
  local pos, surface = pair_position(pair)
  local far = M.players_near_position(surface, pos, M.far_radius)
  if far then return "nearby-remote" end
  return "low-detail"
end

function M.allow_theater_for_pair(pair, channel)
  local r = M.root()
  if r.enabled == false then return true, "disabled" end
  local tier = M.classify_pair(pair)
  if tier == "observed" or tier == "nearby-remote" then
    stat("theater_allowed")
    return true, tier
  end
  stat("theater_suppressed")
  stat("theater_suppressed_" .. tostring(channel or "unknown"))
  return false, tier
end

function M.allow_theater_for_entity(entity, channel)
  local r = M.root()
  if r.enabled == false then return true, "disabled" end
  if not valid(entity) then return false, "invalid" end
  local observed = M.entity_observed(entity, M.near_radius)
  if observed then stat("theater_allowed"); return true, "observed" end
  stat("theater_suppressed")
  stat("theater_suppressed_" .. tostring(channel or "unknown"))
  return false, "low-detail"
end

function M.count_tiers()
  local counts = { observed = 0, ["active-remote"] = 0, ["nearby-remote"] = 0, ["low-detail"] = 0, invalid = 0 }
  local pair_map = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  local sampled = 0
  for _, pair in pairs(pair_map) do
    sampled = sampled + 1
    if valid(pair and pair.station) and valid(pair and pair.priest) then
      local tier = M.classify_pair(pair)
      counts[tier] = (counts[tier] or 0) + 1
    else
      counts.invalid = counts.invalid + 1
    end
    if sampled >= M.report_sample_limit then break end
  end
  counts.sampled = sampled
  local r = M.root()
  r.last_counts = counts
  r.last_count_tick = now()
  return counts
end

function M.report_lines()
  local r = M.root()
  local c = M.count_tiers()
  return {
    "[tp-runtime-report] spatial-interest-0609 enabled=" .. safe(r.enabled)
      .. " observed=" .. safe(c.observed or 0)
      .. " active_remote=" .. safe(c["active-remote"] or 0)
      .. " nearby_remote=" .. safe(c["nearby-remote"] or 0)
      .. " low_detail=" .. safe(c["low-detail"] or 0)
      .. " invalid=" .. safe(c.invalid or 0)
      .. " theater_allowed=" .. safe(r.stats.theater_allowed or 0)
      .. " theater_suppressed=" .. safe(r.stats.theater_suppressed or 0)
      .. " overhead_suppressed=" .. safe(r.stats.theater_suppressed_overhead or 0)
      .. " audio_suppressed=" .. safe(r.stats.theater_suppressed_audio or 0)
  }
end

function M.install()
  M.root()
  _G.TechPriestsSpatialInterest0609 = M
  _G.tech_priests_pair_observed_0609 = function(pair, radius) return M.pair_observed(pair, radius) end
  _G.tech_priests_allow_theater_for_pair_0609 = function(pair, channel) return M.allow_theater_for_pair(pair, channel) end
  _G.tech_priests_allow_theater_for_entity_0609 = function(entity, channel) return M.allow_theater_for_entity(entity, channel) end
  remember("install", "spatial interest telemetry/theater gate installed")
  return true
end

return M
