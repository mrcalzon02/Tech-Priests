-- Tech Priests 0.1.663 centralized Cogitator operating-range authority.
-- Adds a flat five-tile base-range buff to every station while preserving the
-- existing technology and quality bonuses calculated by the legacy authority.
-- Direct-acquisition role caps remain intentionally separate.

local M = {
  version = "0.1.663",
  storage_key = "station_range_authority_0680",
  default_flat_bonus = 5,
  refresh_interval = 600,
}

local previous_get_radius
local previous_refresh_pair
local previous_radar_radius

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    flat_bonus = M.default_flat_bonus,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.flat_bonus == nil then r.flat_bonus = M.default_flat_bonus end
  r.flat_bonus = math.max(0, math.min(100, tonumber(r.flat_bonus) or M.default_flat_bonus))
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(action, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    detail = tostring(detail or ""),
  }
  while #r.recent > 80 do table.remove(r.recent, 1) end
end

local function station_config(station)
  if type(_G.get_station_config) == "function" then
    local ok, config = pcall(_G.get_station_config, station)
    if ok and config then return config end
  end
  local configs = rawget(_G, "TIER_CONFIGS")
  return configs and valid(station) and configs[station.name] or nil
end

local function unbuffed_radius(station)
  if type(previous_get_radius) == "function" then
    local ok, radius = pcall(previous_get_radius, station)
    if ok and tonumber(radius) then return tonumber(radius) end
  end
  local config = station_config(station)
  if config and tonumber(config.base_radius) then return tonumber(config.base_radius) end
  return 20
end

function M.flat_bonus()
  local r = root()
  return r.enabled and (tonumber(r.flat_bonus) or M.default_flat_bonus) or 0
end

function M.radius_for_station(station)
  return math.max(8, unbuffed_radius(station) + M.flat_bonus())
end

local function invalidate_catalog(pair)
  local tp = storage and storage.tech_priests
  local catalog = tp and (tp.station_catalog_0327 or tp.station_catalog_0326)
  local unit = station_unit(pair)
  if catalog and unit then
    catalog.next_scan = catalog.next_scan or {}
    catalog.next_scan[unit] = 0
    if catalog.stations and catalog.stations[unit] then
      catalog.stations[unit].range_authority_invalidated_0680 = now()
    end
  end
end

local function invalidate_visuals()
  local tp = storage and storage.tech_priests
  local legacy = tp and tp.alt_writ_visual_stability_0474
  if legacy then legacy.signature_by_player = {} end
  local fields = tp and tp.alt_resource_field_overlay_0679
  if fields then
    fields.signature_by_player = {}
    fields.field_cache = {}
  end
end

local function refresh_visuals()
  invalidate_visuals()
  local field_refresh = rawget(_G, "tech_priests_refresh_claimed_resource_fields_0679")
  if type(field_refresh) == "function" then pcall(field_refresh) end
  local stable_refresh = rawget(_G, "tech_priests_0474_refresh_stable_visuals")
  if type(stable_refresh) == "function" then pcall(stable_refresh) end
end

function M.refresh_pair(pair, force_invalidate)
  if not (pair and valid(pair.station)) then return false end
  local old = tonumber(pair.radius)
  local radius = M.radius_for_station(pair.station)
  pair.radius = radius
  pair.range_authority_0680 = {
    tick = now(),
    unbuffed = unbuffed_radius(pair.station),
    flat_bonus = M.flat_bonus(),
    effective = radius,
  }
  if force_invalidate or old ~= radius then
    invalidate_catalog(pair)
    stat("pair_radius_changed")
    return true
  end
  stat("pair_radius_confirmed")
  return false
end

function M.refresh_all(force_invalidate)
  local changed = 0
  local checked = 0
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      checked = checked + 1
      if M.refresh_pair(pair, force_invalidate) then changed = changed + 1 end
    end
  end
  if changed > 0 or force_invalidate then refresh_visuals() end
  local r = root()
  r.stats.last_refresh_tick = now()
  r.stats.last_checked = checked
  r.stats.last_changed = changed
  return changed, checked
end

function M.set_flat_bonus(value, reason)
  local r = root()
  local old = tonumber(r.flat_bonus) or M.default_flat_bonus
  local new_value = math.max(0, math.min(100, tonumber(value) or old))
  r.flat_bonus = new_value
  record("flat_bonus_changed", "old=" .. safe(old) .. " new=" .. safe(new_value) .. " reason=" .. safe(reason))
  M.refresh_all(true)
  return new_value
end

local function effective_base_lines()
  local configs = rawget(_G, "TIER_CONFIGS") or {}
  local rows = {}
  for name, config in pairs(configs) do
    rows[#rows + 1] = tostring(name)
      .. "=" .. tostring((tonumber(config.base_radius) or 20) + M.flat_bonus())
  end
  table.sort(rows)
  return table.concat(rows, ",")
end

local function patch_globals()
  if not previous_get_radius then
    previous_get_radius = rawget(_G, "TECH_PRIESTS_0680_PRE_GET_STATION_OPERATING_RADIUS")
      or rawget(_G, "get_station_operating_radius")
    _G.TECH_PRIESTS_0680_PRE_GET_STATION_OPERATING_RADIUS = previous_get_radius
  end
  if not previous_refresh_pair then
    previous_refresh_pair = rawget(_G, "TECH_PRIESTS_0680_PRE_REFRESH_PAIR_RADIUS")
      or rawget(_G, "refresh_pair_radius")
    _G.TECH_PRIESTS_0680_PRE_REFRESH_PAIR_RADIUS = previous_refresh_pair
  end
  if not previous_radar_radius then
    previous_radar_radius = rawget(_G, "TECH_PRIESTS_0680_PRE_RADAR_RADIUS")
      or rawget(_G, "tech_priests_radar_operating_radius_0280")
    _G.TECH_PRIESTS_0680_PRE_RADAR_RADIUS = previous_radar_radius
  end

  _G.get_station_operating_radius = function(station)
    return M.radius_for_station(station)
  end

  _G.refresh_pair_radius = function(pair)
    if pair and valid(pair.station) then
      M.refresh_pair(pair, false)
      return pair.radius
    end
    if type(previous_refresh_pair) == "function" then
      local ok, value = pcall(previous_refresh_pair, pair)
      if ok and tonumber(value) then return tonumber(value) end
    end
    return 20 + M.flat_bonus()
  end

  _G.tech_priests_radar_operating_radius_0280 = function(pair, ...)
    if pair and valid(pair.station) then return M.radius_for_station(pair.station) end
    if type(previous_radar_radius) == "function" then
      local ok, value = pcall(previous_radar_radius, pair, ...)
      if ok and tonumber(value) then return tonumber(value) + M.flat_bonus() end
    end
    return 20 + M.flat_bonus()
  end

  _G.tech_priests_0680_station_radius = M.radius_for_station
  _G.tech_priests_0680_set_station_range_bonus = M.set_flat_bonus
  _G.TechPriestsStationRangeAuthority0680 = M
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.station_range_authority_0680_wrapped
  then
    return
  end

  local previous = diagnostics.pair_dump_lines
  diagnostics.station_range_authority_0680_wrapped = true
  diagnostics.pair_dump_lines = function()
    local lines = previous()
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 STATION-RANGE-0680 enabled="
      .. safe(r.enabled)
      .. " flat_bonus=" .. safe(r.flat_bonus)
      .. " bases={" .. effective_base_lines() .. "}"
      .. " checked=" .. safe(r.stats.last_checked or 0)
      .. " changed=" .. safe(r.stats.last_changed or 0)
      .. " direct_bounds_unchanged=true"
    return lines
  end
end

local function register_refresh_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "station_range_authority_0680_refresh",
      category = "runtime-cleanup",
      interval = M.refresh_interval,
      priority = 74,
      budget = 12,
      note = "refresh effective Cogitator ranges after research, quality, or policy changes",
      fn = function()
        local changed, checked = M.refresh_all(false)
        return changed > 0, "changed=" .. safe(changed) .. " checked=" .. safe(checked)
      end,
    })
    return
  end

  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(M.refresh_interval, function() M.refresh_all(false) end, {
      owner = "station_range_authority_0680",
      category = "runtime-cleanup",
      priority = "late",
    })
  end
end

function M.install()
  root()
  patch_globals()
  patch_diagnostics()
  M.refresh_all(true)
  register_refresh_service()
  if log then
    log("[Tech-Priests 0.1.663] station range authority installed; +5 flat operating radius applied to all Cogitators")
  end
  return true
end

return M
