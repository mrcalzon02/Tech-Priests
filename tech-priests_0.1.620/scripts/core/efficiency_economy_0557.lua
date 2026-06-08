-- scripts/core/efficiency_economy_0557.lua
-- Tech Priests 0.1.557
--
-- Second economy pass.  This module remains a governor/wrapper over existing
-- authorities.  It does not create a new behavior owner.  It memoizes radar
-- detections so routine sweep visuals/task refreshes only fire when an object is
-- first seen or after a long recheck interval, and it deduplicates resource
-- expansion station ghosts across nearby/overlapping Magos networks.

local M = {}
M.version = "0.1.557"
M.storage_key = "efficiency_economy_0557"
M.radar_detection_recheck_ticks = 60 * 60 * 8
M.radar_priest_reaudit_ticks = 60 * 15
M.resource_expansion_shared_radius_multiplier = 2.25
M.resource_expansion_retry_ticks = 60 * 60 * 3
M.resource_expansion_max_per_pass = 1

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function distance_sq(a,b)
  if not (a and b) then return 999999999 end
  local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy
end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function station_radius(pair)
  local ok,r=pcall(function() if refresh_pair_radius then return refresh_pair_radius(pair) end return pair.radius or pair.base_radius or 30 end)
  r = (ok and tonumber(r)) or tonumber(pair and (pair.radius or pair.base_radius)) or 30
  return math.max(8, r)
end
local function entity_key(entity)
  if not (entity and entity.valid) then return nil end
  if entity.unit_number then return tostring(entity.unit_number) end
  local p=entity.position or {}; return tostring(entity.name)..":"..string.format("%.1f,%.1f", tonumber(p.x) or 0, tonumber(p.y) or 0)
end
local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    radar_seen = {},
    expansion_seen = {},
    stats = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.radar_seen = r.radar_seen or {}
  r.expansion_seen = r.expansion_seen or {}
  r.stats = r.stats or {}
  return r
end

local function radar_seen_key(pair, entity, kind)
  return safe(station_unit(pair)) .. ":" .. safe(kind) .. ":" .. safe(entity_key(entity))
end

local function radar_detection_is_new_enough(pair, entity, info, bucket)
  local r=M.root()
  if r.enabled == false then return true end
  if not (valid_pair(pair) and entity and entity.valid and info and info.kind) then return true end
  local key = safe(bucket or "task") .. ":" .. radar_seen_key(pair, entity, info.kind)
  local last = tonumber(r.radar_seen[key] or 0) or 0
  if last > 0 and now() - last < M.radar_detection_recheck_ticks then
    stat("radar_repeat_skipped")
    return false
  end
  r.radar_seen[key] = now()
  stat("radar_first_or_recheck")
  return true
end

local function wrap_radar_detection_refresh()
  if type(_G.tech_priests_radar_refresh_detected_task_0282)=="function" and not rawget(_G,"TECH_PRIESTS_0557_PRE_RADAR_REFRESH_DETECTED") then
    local prev = _G.tech_priests_radar_refresh_detected_task_0282
    _G.TECH_PRIESTS_0557_PRE_RADAR_REFRESH_DETECTED = prev
    _G.tech_priests_radar_refresh_detected_task_0282 = function(pair, entity, info, ...)
      if not radar_detection_is_new_enough(pair, entity, info, "task") then return false end
      return prev(pair, entity, info, ...)
    end
  end

  if type(_G.tech_priests_radar_flash_entity_icon_0278)=="function" and not rawget(_G,"TECH_PRIESTS_0557_PRE_RADAR_FLASH") then
    local prev = _G.tech_priests_radar_flash_entity_icon_0278
    _G.TECH_PRIESTS_0557_PRE_RADAR_FLASH = prev
    _G.tech_priests_radar_flash_entity_icon_0278 = function(player, entity, info, ...)
      local pair = nil
      if player and type(_G.tech_priests_radar_get_hover_pair_0278)=="function" then
        local ok,p=pcall(function() return _G.tech_priests_radar_get_hover_pair_0278(player) end); if ok then pair=p end
      end
      if pair and not radar_detection_is_new_enough(pair, entity, info, "flash") then return nil end
      return prev(player, entity, info, ...)
    end
  end

  if type(_G.tech_priests_radar_hard_reaudit_pair_0283)=="function" and not rawget(_G,"TECH_PRIESTS_0557_PRE_RADAR_HARD_REAUDIT") then
    local prev = _G.tech_priests_radar_hard_reaudit_pair_0283
    _G.TECH_PRIESTS_0557_PRE_RADAR_HARD_REAUDIT = prev
    _G.tech_priests_radar_hard_reaudit_pair_0283 = function(pair, reason, ...)
      local r=M.root()
      if r.enabled ~= false and valid_pair(pair) then
        local key = safe(station_unit(pair)) .. ":" .. safe(reason or "radar-priest-scan")
        local until_tick = tonumber(r.radar_seen["reaudit:"..key] or 0) or 0
        if now() < until_tick then stat("radar_reaudit_skipped"); return false end
        r.radar_seen["reaudit:"..key] = now() + M.radar_priest_reaudit_ticks
      end
      return prev(pair, reason, ...)
    end
  end
end

local function record_matches_request(pair, rec, blocked_item, station_item)
  if not (valid_pair(pair) and type(rec)=="table" and rec.status=="active") then return false end
  if station_item and rec.station_entity and rec.station_entity ~= station_item then return false end
  if blocked_item and rec.blocked_item and tostring(rec.blocked_item) ~= tostring(blocked_item) then
    -- Treat all resource expansion ghosts in an overlapping network as shared
    -- only when both sides are resource-directed.  Ordinary construction range
    -- expansion keeps its own exact blocked-item identity.
    if not (tostring(blocked_item):find("resource:",1,true) and tostring(rec.blocked_item):find("resource:",1,true)) then return false end
  end
  local ghost_pos = rec.ghost_position
  if not ghost_pos then return false end
  local requester = storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[rec.requester_station_unit] or nil
  if requester and valid_pair(requester) then
    if requester.station.surface ~= pair.station.surface or requester.station.force ~= pair.station.force then return false end
  end
  local shared = math.max(station_radius(pair), requester and station_radius(requester) or station_radius(pair)) * M.resource_expansion_shared_radius_multiplier
  return distance_sq(pair.station.position, ghost_pos) <= shared * shared
end

local function wrap_station_expansion_dedupe()
  local ok, Exp = pcall(require, "scripts.magos_station_expansion")
  if not (ok and Exp and type(Exp.request_station_expansion)=="function") or Exp.efficiency_economy_0557_wrapped then return false end
  Exp.efficiency_economy_0557_wrapped = true
  Exp.TECH_PRIESTS_0557_PRE_REQUEST_EXPANSION = Exp.request_station_expansion
  Exp.request_station_expansion = function(requester_pair, blocked_item, op, note, preferred_angle, ...)
    local r=M.root()
    if r.enabled ~= false and valid_pair(requester_pair) then
      local station_item = type(Exp.allowed_station_item_for_pair)=="function" and Exp.allowed_station_item_for_pair(requester_pair) or nil
      local key = safe(station_unit(requester_pair)) .. ":" .. safe(blocked_item) .. ":" .. safe(station_item)
      local last = tonumber(r.expansion_seen[key] or 0) or 0
      if now() < last then stat("expansion_retry_skipped"); return true end
      local records = storage and storage.tech_priests and storage.tech_priests.station_expansion_0256 or {}
      for id, rec in pairs(records) do
        if record_matches_request(requester_pair, rec, blocked_item, station_item) then
          if op then
            op.station_expansion_request_0256 = id
            op.magos_planner_phase_0255 = "range-expansion-shared-ghost"
            op.magos_planner_item_0255 = rec.station_item or station_item
            op.next_tick = now() + M.resource_expansion_retry_ticks
            op.resource_expansion_shared_ghost_0557 = id
          end
          requester_pair.resource_expansion_shared_ghost_0557 = { tick=now(), id=id, blocked_item=blocked_item, ghost_position=rec.ghost_position }
          r.expansion_seen[key] = now() + M.resource_expansion_retry_ticks
          stat("expansion_shared_existing")
          return true
        end
      end
      r.expansion_seen[key] = now() + 60 * 20
    end
    local ok_result = Exp.TECH_PRIESTS_0557_PRE_REQUEST_EXPANSION(requester_pair, blocked_item, op, note, preferred_angle, ...)
    if ok_result and r.enabled ~= false and valid_pair(requester_pair) then
      local records = storage and storage.tech_priests and storage.tech_priests.station_expansion_0256 or {}
      for _, rec in pairs(records) do
        if rec and rec.status=="active" and rec.requester_station_unit == station_unit(requester_pair) then
          rec.purpose_0557 = tostring(blocked_item or "expansion")
          rec.note_0557 = tostring(note or "")
          rec.shared_expansion_plan_0557 = true
        end
      end
    end
    return ok_result
  end
  return true
end

local function tune_resource_expansion_constants()
  if rawget(_G,"TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259") then
    _G.TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259 = math.max(tonumber(_G.TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259) or 0, 60 * 90)
  end
  if rawget(_G,"TECH_PRIESTS_RESOURCE_EXPANSION_MAX_RESOURCES_PER_PASS_0259") then
    _G.TECH_PRIESTS_RESOURCE_EXPANSION_MAX_RESOURCES_PER_PASS_0259 = math.min(tonumber(_G.TECH_PRIESTS_RESOURCE_EXPANSION_MAX_RESOURCES_PER_PASS_0259) or 1, M.resource_expansion_max_per_pass)
  end
  if rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256") then
    _G.TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256 = math.min(tonumber(_G.TECH_PRIESTS_STATION_EXPANSION_MAX_GHOSTS_PER_REQUESTER_0256) or 1, 1)
  end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0557") end end)
  commands.add_command("tp-efficiency-economy-0557", "Tech Priests 0.1.557 efficiency economy review. Params: on/off/status", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p=lower(event and event.parameter or "status")
    local r=M.root()
    if p=="on" then r.enabled=true elseif p=="off" then r.enabled=false end
    local msg="[tp-efficiency-economy-0557] enabled="..safe(r.enabled)
      .." radar_repeat_skipped="..safe(r.stats.radar_repeat_skipped or 0)
      .." radar_reaudit_skipped="..safe(r.stats.radar_reaudit_skipped or 0)
      .." expansion_shared_existing="..safe(r.stats.expansion_shared_existing or 0)
      .." expansion_retry_skipped="..safe(r.stats.expansion_retry_skipped or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  tune_resource_expansion_constants()
  wrap_radar_detection_refresh()
  wrap_station_expansion_dedupe()
  install_command()
  _G.TechPriestsEfficiencyEconomy0557 = M
  if log then log("[Tech-Priests 0.1.557] efficiency economy review installed; radar detections are memoized and resource expansion ghosts are shared/deduplicated across nearby station networks") end
  return true
end

return M
