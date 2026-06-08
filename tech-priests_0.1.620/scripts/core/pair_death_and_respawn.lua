-- scripts/core/pair_death_and_respawn.lua
-- Tech Priests 0.1.426 pair lifecycle extraction: death/re-imprint authority.
--
-- Doctrine:
--   * Station death may retire/kill the paired priest and remove the pair.
--   * Priest death must not destroy the Cogitator Station.
--   * Priest death enters station-bound re-imprinting and respawns through the
--     existing respawn path only after the timer expires.
--
-- This module does not choose work and does not move priests. It owns lifecycle
-- state transitions around death, missing priests, and respawn gates.

local M = {}
M.version = "0.1.426"
M.installed = false

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function safe_tostring(v)
  local ok, out = pcall(function() return tostring(v) end)
  if ok then return out end
  return "?"
end

local function registry()
  if _G.TechPriestsRuntimeEventRegistry then return _G.TechPriestsRuntimeEventRegistry end
  local ok, mod = pcall(require, "scripts.core.runtime_event_registry")
  if ok then return mod end
  return nil
end

local function debug_registry()
  if _G.TechPriestsDebugCommandRegistry then return _G.TechPriestsDebugCommandRegistry end
  local ok, mod = pcall(require, "scripts.core.debug.debug_command_registry")
  if ok then return mod end
  return nil
end

local function naming()
  if _G.TechPriestsPairNaming then return _G.TechPriestsPairNaming end
  local ok, mod = pcall(require, "scripts.core.pair_naming")
  if ok then return mod end
  return nil
end

function M.is_priest_entity(entity)
  if not valid(entity) then return false end
  if _G.is_priest then
    local ok, result = pcall(_G.is_priest, entity)
    if ok and result then return true end
  end
  local n = entity.name or ""
  return n == "junior-tech-priest" or n == "intermediate-tech-priest" or n == "senior-tech-priest"
end

function M.is_station_entity(entity)
  if not valid(entity) then return false end
  if _G.is_station then
    local ok, result = pcall(_G.is_station, entity)
    if ok and result then return true end
  end
  local n = entity.name or ""
  return n:find("cogitator%-station", 1, false) ~= nil or n:find("tech%-priest", 1, false) ~= nil and n:find("station", 1, true) ~= nil
end

function M.find_pair(entity)
  if not valid(entity) then return nil end
  if _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, entity)
    if ok and pair then return pair end
  end
  local tp = storage and storage.tech_priests
  if not (tp and entity.unit_number) then return nil end
  if tp.pairs_by_priest and tp.pairs_by_priest[entity.unit_number] then return tp.pairs_by_priest[entity.unit_number] end
  if tp.station_by_priest and tp.station_by_priest[entity.unit_number] and tp.pairs_by_station then
    return tp.pairs_by_station[tp.station_by_priest[entity.unit_number]]
  end
  if tp.pairs_by_station and tp.pairs_by_station[entity.unit_number] then return tp.pairs_by_station[entity.unit_number] end
  return nil
end

function M.is_reimprinting(pair)
  if _G.tech_priests_0298_pair_is_reimprinting then
    local ok, result = pcall(_G.tech_priests_0298_pair_is_reimprinting, pair)
    if ok then return result and true or false end
  end
  return pair and pair.reimprint_0298 and pair.reimprint_0298.active and now() < (pair.reimprint_0298.finish_tick or 0)
end

local function format_time(ticks)
  if _G.tech_priests_0298_format_time then
    local ok, text = pcall(_G.tech_priests_0298_format_time, ticks)
    if ok and text then return text end
  end
  ticks = math.max(0, math.floor(tonumber(ticks) or 0))
  local sec = math.ceil(ticks / 60)
  local m = math.floor(sec / 60)
  local s = sec % 60
  if m > 0 then return tostring(m) .. ":" .. string.format("%02d", s) end
  return tostring(s) .. "s"
end

local function duration_for_force(force)
  if _G.tech_priests_0298_reimprint_duration then
    local ok, ticks = pcall(_G.tech_priests_0298_reimprint_duration, force)
    if ok and tonumber(ticks) then return ticks end
  end
  return 60 * 90
end

local function clear_priest_reverse_maps(pair, priest)
  if not storage then return end
  storage.tech_priests = storage.tech_priests or {}
  local tp = storage.tech_priests
  local old_unit = (priest and priest.unit_number) or (pair and pair.priest_unit)
  if old_unit then
    if tp.station_by_priest then tp.station_by_priest[old_unit] = nil end
    if tp.pairs_by_priest then tp.pairs_by_priest[old_unit] = nil end
  end
  if pair then
    pair.priest = nil
    pair.priest_unit = nil
  end
end

local function clear_work_state(pair)
  if not pair then return end
  pair.mode = "re-imprinting"
  pair.target = nil
  pair.combat_target = nil
  pair.active_task = nil
  pair.active_task_0285 = nil
  pair.current_task = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.retreat_0294 = nil
  pair.pinned_no_ammo_0295 = nil
  pair.movement_request_0418 = nil
  pair.movement_lockdown_0416 = nil
  pair.movement_stabilizer_0417 = nil
end

function M.enter_reimprint(pair, dead_priest, reason)
  if not (pair and valid(pair.station)) then return false end
  if M.is_reimprinting(pair) then return true end

  if _G.spawn_priest_smoke_for_entity and dead_priest then pcall(_G.spawn_priest_smoke_for_entity, dead_priest, true) end

  -- Prefer the historical 0.1.298 implementation because it owns the visible
  -- countdown render and existing tech-based duration calculation. This module
  -- wraps/authorizes it rather than duplicating every visual detail.
  if _G.tech_priests_0298_enter_reimprint then
    local ok, result = pcall(_G.tech_priests_0298_enter_reimprint, pair, dead_priest, reason or "pair-lifecycle-0426")
    if ok and result then
      pair.lifecycle_0426 = pair.lifecycle_0426 or {}
      pair.lifecycle_0426.last_event = { tick = now(), action = "enter-reimprint", reason = reason or "pair-lifecycle-0426" }
      return true
    end
  end

  clear_priest_reverse_maps(pair, dead_priest)
  clear_work_state(pair)
  local duration = duration_for_force(pair.station.force)
  pair.reimprint_0298 = pair.reimprint_0298 or {}
  pair.reimprint_0298.active = true
  pair.reimprint_0298.started_tick = now()
  pair.reimprint_0298.finish_tick = now() + duration
  pair.reimprint_0298.duration = duration
  pair.reimprint_0298.reason = reason or "pair-lifecycle-fallback-0426"
  pair.reimprint_0298.station_unit = pair.station_unit or pair.station.unit_number
  pair.next_allowed_priest_respawn_tick = pair.reimprint_0298.finish_tick
  pair.lifecycle_0426 = pair.lifecycle_0426 or {}
  pair.lifecycle_0426.last_event = { tick = now(), action = "fallback-enter-reimprint", reason = reason or "pair-lifecycle-0426" }
  if pair.station.force and pair.station.force.valid then
    local name = naming() and naming().station_name(pair) or "Cogitator Station"
    pair.station.force.print("[Tech Priests] " .. safe_tostring(name) .. " has begun Tech-Priest re-imprinting: " .. format_time(duration) .. ".")
  end
  return true
end

function M.handle_removed(event)
  local entity = event and event.entity
  if event and event.name == defines.events.on_entity_died and M.is_priest_entity(entity) then
    local pair = M.find_pair(entity)
    if pair and valid(pair.station) then
      return M.enter_reimprint(pair, entity, "priest-death-0426")
    end
  end
  return false
end

function M.patch_remove_pair_for_entity()
  if _G.TECH_PRIESTS_0426_PRE_REMOVE_PAIR_FOR_ENTITY or type(_G.remove_pair_for_entity) ~= "function" then return false end
  _G.TECH_PRIESTS_0426_PRE_REMOVE_PAIR_FOR_ENTITY = _G.remove_pair_for_entity
  _G.remove_pair_for_entity = function(entity, source_event)
    if source_event and source_event.name == defines.events.on_entity_died and M.is_priest_entity(entity) then
      local pair = M.find_pair(entity)
      if pair and valid(pair.station) then
        return M.enter_reimprint(pair, entity, "remove-pair-priest-death-0426")
      end
    end
    return _G.TECH_PRIESTS_0426_PRE_REMOVE_PAIR_FOR_ENTITY(entity, source_event)
  end
  return true
end

function M.patch_on_removed()
  if _G.TECH_PRIESTS_0426_PRE_ON_REMOVED or type(_G.on_removed) ~= "function" then return false end
  _G.TECH_PRIESTS_0426_PRE_ON_REMOVED = _G.on_removed
  _G.on_removed = function(event)
    if M.handle_removed(event) then return true end
    return _G.TECH_PRIESTS_0426_PRE_ON_REMOVED(event)
  end
  return true
end

function M.patch_respawn_gates()
  if type(_G.ensure_pair_priest) == "function" and not _G.TECH_PRIESTS_0426_PRE_ENSURE_PAIR_PRIEST then
    _G.TECH_PRIESTS_0426_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      if M.is_reimprinting(pair) then return false end
      return _G.TECH_PRIESTS_0426_PRE_ENSURE_PAIR_PRIEST(pair, force_recall, immediate)
    end
  end
  if type(_G.respawn_pair_priest) == "function" and not _G.TECH_PRIESTS_0426_PRE_RESPAWN_PAIR_PRIEST then
    _G.TECH_PRIESTS_0426_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if M.is_reimprinting(pair) then return false end
      local ok = _G.TECH_PRIESTS_0426_PRE_RESPAWN_PAIR_PRIEST(pair, reason or "pair-lifecycle-respawn-0426")
      if ok and pair then
        pair.lifecycle_0426 = pair.lifecycle_0426 or {}
        pair.lifecycle_0426.last_event = { tick = now(), action = "respawn", reason = reason or "pair-lifecycle-respawn-0426" }
        local naming_mod = naming(); if naming_mod and naming_mod.refresh then pcall(naming_mod.refresh, pair, "respawn-0426") end
      end
      return ok
    end
  end
end

function M.service_reimprints(limit)
  if _G.tech_priests_0298_service_reimprints then
    local ok = pcall(_G.tech_priests_0298_service_reimprints, limit or 32)
    if ok then return true end
  end
  local tp = storage and storage.tech_priests
  if not (tp and tp.pairs_by_station) then return false end
  local n = 0
  for _, pair in pairs(tp.pairs_by_station) do
    if pair and pair.reimprint_0298 and pair.reimprint_0298.active and valid(pair.station) then
      n = n + 1
      if n > (limit or 32) then break end
      if now() >= (pair.reimprint_0298.finish_tick or 0) and type(_G.respawn_pair_priest) == "function" then
        pair.reimprint_0298.active = false
        _G.respawn_pair_priest(pair, "reimprint-complete-0426")
      elseif _G.tech_priests_0298_update_reimprint_render then
        pcall(_G.tech_priests_0298_update_reimprint_render, pair)
      end
    end
  end
  return true
end

function M.register_events()
  local R = registry()
  if not (R and defines and defines.events) then return false end
  R.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, function(event) return M.handle_removed(event) end, nil, {
    owner = "pair_death_and_respawn",
    category = "pair-lifecycle",
    priority = "first",
    stop_on_truthy = true,
    note = "priest death becomes station re-imprinting before legacy linked-death cleanup"
  })
  R.on_nth_tick(47, function() M.service_reimprints(32) end, {
    owner = "pair_death_and_respawn",
    category = "pair-lifecycle",
    priority = "first",
    note = "station-bound priest re-imprint service"
  })
  return true
end

function M.register_commands()
  local D = debug_registry()
  if not (D and D.add) then return false end
  D.add("tp-lifecycle-0426", "Tech Priests 0.1.426 pair lifecycle authority diagnostic for selected station/priest.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local pair = player.selected and M.find_pair(player.selected) or nil
    if not pair then player.print("[tp-lifecycle-0426] Select a Cogitator Station or Tech-Priest."); return end
    local r = pair.reimprint_0298
    local rem = r and r.active and math.max(0, (r.finish_tick or now()) - now()) or 0
    local life = pair.lifecycle_0426 and pair.lifecycle_0426.last_event or nil
    player.print("[tp-lifecycle-0426] station=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number) .. " priest=" .. tostring(pair.priest and pair.priest.valid and pair.priest.unit_number or "nil") .. " mode=" .. tostring(pair.mode))
    player.print("  reimprint=" .. tostring(r and r.active or false) .. " remaining=" .. format_time(rem) .. " reason=" .. tostring(r and r.reason or "nil"))
    if life then player.print("  last_lifecycle=" .. tostring(life.action) .. " tick=" .. tostring(life.tick) .. " reason=" .. tostring(life.reason)) end
  end)
  return true
end

function M.install()
  if M.installed then return true end
  M.installed = true
  _G.TechPriestsPairDeathAndRespawn = M
  M.patch_remove_pair_for_entity()
  M.patch_on_removed()
  M.patch_respawn_gates()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.426] pair death/respawn lifecycle authority installed") end
  return true
end

return M
