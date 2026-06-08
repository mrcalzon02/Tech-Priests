-- scripts/core/pair_link_hardening_0495.lua
-- Tech Priests 0.1.495
--
-- Reinforces station/priest pair identity so a stale table or vanished priest
-- does not leave the station with a nil mobile body.  This module does not own
-- ordinary movement.  It repairs reverse maps, records last valid priest signal,
-- rebinds nearby orphaned priests before spawning replacements, and only then
-- uses the existing lifecycle respawn path as a controlled rescue.

local M = {}
M.version = "0.1.495"
M.storage_key = "pair_link_hardening_0495"
M.tick_interval = 41
M.rebind_radius = 96
M.rescue_cooldown = 240

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, delta)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (delta or 1)
end

local function record(action, pair, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = action,
    station = pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil,
    priest = pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil,
    detail = tostring(detail or "")
  }
  while #r.recent > 20 do table.remove(r.recent, 1) end
end

local function rank_from_pair(pair)
  local name = valid(pair and pair.station) and tostring(pair.station.name or "") or tostring(pair and pair.station_name or "")
  if name:find("planetary%-magos", 1, false) then return "planetary-magos" end
  if name:find("senior", 1, false) then return "senior" end
  if name:find("intermediate", 1, false) then return "intermediate" end
  if name:find("junior", 1, false) then return "junior" end
  local tier = tostring(pair and (pair.tier or pair.rank) or "")
  if tier ~= "" then return tier end
  return "junior"
end

local function priest_name_for_rank(rank)
  if rank == "planetary-magos" then return "planetary-magos-tech-priest" end
  if rank == "senior" then return "senior-tech-priest" end
  if rank == "intermediate" then return "intermediate-tech-priest" end
  return "junior-tech-priest"
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function repair_reverse_maps(pair, reason)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  storage.tech_priests = storage.tech_priests or {}
  local tp = storage.tech_priests
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  local su = pair.station.unit_number
  local pu = pair.priest.unit_number
  pair.station_unit = su
  pair.priest_unit = pu
  pair.priest_name_0495 = pair.priest.name
  pair.station_name_0495 = pair.station.name
  tp.pairs_by_station[su] = pair
  tp.pairs_by_priest[pu] = pair
  tp.station_by_priest[pu] = su
  pair.link_0495 = pair.link_0495 or {}
  pair.link_0495.last_valid_tick = now()
  pair.link_0495.last_priest_unit = pu
  pair.link_0495.last_priest_name = pair.priest.name
  pair.link_0495.last_priest_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.link_0495.last_repair_reason = reason or "reverse-map-service"
  return true
end

local function priest_is_bound_elsewhere(entity, own_pair)
  if not valid(entity) then return false end
  local tp = storage and storage.tech_priests or nil
  local other = tp and tp.pairs_by_priest and tp.pairs_by_priest[entity.unit_number] or nil
  return other ~= nil and other ~= own_pair
end

local function rebind_orphan(pair)
  if not (pair and valid(pair.station)) then return false end
  local surface = pair.station.surface
  if not (surface and surface.valid) then return false end
  local pname = priest_name_for_rank(rank_from_pair(pair))
  local area = {
    { pair.station.position.x - M.rebind_radius, pair.station.position.y - M.rebind_radius },
    { pair.station.position.x + M.rebind_radius, pair.station.position.y + M.rebind_radius }
  }
  local ok, found = pcall(function() return surface.find_entities_filtered{ area = area, name = pname, force = pair.station.force } end)
  if not ok or type(found) ~= "table" then return false end
  local best, best_dist = nil, nil
  for _, e in pairs(found) do
    if valid(e) and not priest_is_bound_elsewhere(e, pair) then
      local dx = e.position.x - pair.station.position.x
      local dy = e.position.y - pair.station.position.y
      local d = dx * dx + dy * dy
      if not best_dist or d < best_dist then best, best_dist = e, d end
    end
  end
  if best then
    pair.priest = best
    pair.priest_unit = best.unit_number
    pair.lost_priest_0490 = nil
    pair.link_0495 = pair.link_0495 or {}
    pair.link_0495.rebound_tick = now()
    pair.link_0495.rebound_distance_sq = best_dist
    repair_reverse_maps(pair, "orphan-rebound-0495")
    record("rebound-orphan-priest", pair, "name=" .. tostring(best.name) .. " distance_sq=" .. tostring(best_dist))
    return true
  end
  return false
end

local function clear_volatile_execution(pair)
  if not pair then return end
  pair.target = nil
  pair.combat_target = nil
  pair.active_task = nil
  pair.active_task_0285 = nil
  pair.current_task = nil
  pair.scavenge = nil
  pair.inventory_scan = nil
  pair.direct_acquisition_task_0336 = nil
  pair.emergency_craft = nil
  pair.movement_request_0418 = nil
end

local function rescue_missing(pair)
  if not (pair and valid(pair.station)) then return false end
  local re = pair.reimprint_0298
  if re and re.active then return false end
  pair.link_0495 = pair.link_0495 or {}
  if now() - tonumber(pair.link_0495.last_rescue_attempt_tick or 0) < M.rescue_cooldown then return false end
  pair.link_0495.last_rescue_attempt_tick = now()
  pair.link_0495.rescue_attempts = (pair.link_0495.rescue_attempts or 0) + 1
  clear_volatile_execution(pair)
  if rebind_orphan(pair) then return true end
  local ok = false
  if type(_G.ensure_pair_priest) == "function" then
    pcall(function() ok = _G.ensure_pair_priest(pair, true, true) end)
  end
  if (not ok) and type(_G.respawn_pair_priest) == "function" then
    pcall(function() ok = _G.respawn_pair_priest(pair, "pair-link-hardening-0495") end)
  end
  if ok and valid(pair.priest) then
    repair_reverse_maps(pair, "controlled-rescue-0495")
    record("controlled-rescue", pair, "attempt=" .. tostring(pair.link_0495.rescue_attempts))
    return true
  end
  record("rescue-failed", pair, "attempt=" .. tostring(pair.link_0495.rescue_attempts))
  return false
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then
    local su = station_unit(pair)
    if storage and storage.tech_priests then
      local tp = storage.tech_priests
      if not (tp.pairs_by_priest and tp.pairs_by_priest[pair.priest.unit_number] == pair and tp.station_by_priest and tp.station_by_priest[pair.priest.unit_number] == su) then
        record("reverse-map-repaired", pair, "priest=" .. tostring(pair.priest.unit_number))
      end
    end
    repair_reverse_maps(pair, "valid-service")
    pair.link_0495.missing_since = nil
    return true
  end
  pair.link_0495 = pair.link_0495 or {}
  pair.link_0495.missing_since = pair.link_0495.missing_since or now()
  record("missing-priest-observed", pair, "missing_for=" .. tostring(now() - pair.link_0495.missing_since))
  return rescue_missing(pair)
end

function M.service_all()
  local r = root()
  if r.enabled == false then return end
  for _, pair in pairs(pair_map()) do
    M.service_pair(pair)
  end
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.pair_link_hardening_wrapped_0495 then return false end
  local prev = diag.pair_dump_lines
  diag.pair_link_hardening_wrapped_0495 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "PAIR-DUMP-0468 PAIR-LINK-HARDENING-0495 BEGIN enabled=" .. tostring(r.enabled)
      .. " missing=" .. tostring(r.stats["missing-priest-observed"] or 0)
      .. " rebound=" .. tostring(r.stats["rebound-orphan-priest"] or 0)
      .. " rescued=" .. tostring(r.stats["controlled-rescue"] or 0)
      .. " failed=" .. tostring(r.stats["rescue-failed"] or 0)
    for i = math.max(1, #r.recent - 8), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 link0495[" .. tostring(i) .. "] tick=" .. tostring(ev.tick) .. " action=" .. tostring(ev.action) .. " station=" .. tostring(ev.station) .. " priest=" .. tostring(ev.priest) .. " " .. tostring(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 PAIR-LINK-HARDENING-0495 END"
    return lines
  end
  return true
end

function M.patch_respawn_wrappers()
  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0495_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0495_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      local result = _G.TECH_PRIESTS_0495_PRE_ENSURE_PAIR_PRIEST(pair, force_recall, immediate)
      if result and pair and valid(pair.priest) then repair_reverse_maps(pair, "ensure-pair-priest-wrapper") end
      return result
    end
  end
  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0495_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0495_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      local result = _G.TECH_PRIESTS_0495_PRE_RESPAWN_PAIR_PRIEST(pair, reason)
      if result and pair and valid(pair.priest) then repair_reverse_maps(pair, "respawn-pair-priest-wrapper") end
      return result
    end
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-pair-link-0495") end end)
  commands.add_command("tp-pair-link-0495", "Tech Priests: pair link hardening diagnostics. Usage: status|all|rescue|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "all" or p == "rescue" then M.service_all() end
    if player and player.valid then
      player.print("[tp-pair-link-0495] enabled=" .. tostring(r.enabled)
        .. " missing=" .. tostring(r.stats["missing-priest-observed"] or 0)
        .. " rebound=" .. tostring(r.stats["rebound-orphan-priest"] or 0)
        .. " rescued=" .. tostring(r.stats["controlled-rescue"] or 0)
        .. " failed=" .. tostring(r.stats["rescue-failed"] or 0))
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  _G.TechPriestsPairLinkHardening0495 = M
  M.patch_respawn_wrappers()
  M.wrap_pair_dump()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "pair_link_hardening_0495", category = "pair-lifecycle", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.495] pair link hardening installed; reverse maps repaired and vanished priests rebound before respawn") end
  return true
end

return M
