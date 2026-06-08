-- scripts/core/behavior_execution_doctrine_0505.lua
-- Tech Priests 0.1.505
--
-- Behavior execution doctrine clamp.
--
-- This pass does not attempt to finish the larger behavior-tree rewrite. It
-- converts the lessons from 0.1.502-0.1.504 into hard runtime rules:
--   * no world mining smoke/damage/deposit unless the visible priest is
--     physically beside the world target;
--   * emergency machine/facility doctrine is preferred before ordinary
--     desperation hand-crafting;
--   * station-side vanish quarantine may keep the priest safe, but it may not
--     secretly mine far rocks/ore patches from the station;
--   * recovery teleports are throttled so failed collision teleports do not
--     become their own task storm.

local M = {}
M.version = "0.1.505"
M.storage_key = "behavior_execution_doctrine_0505"
M.close_distance_sq = 7.84 -- 2.8 tiles; generous for large sprites/rocks.
M.station_local_sq = 196 -- 14 tiles; local station-side visual work only.
M.block_log_interval = 180
M.facility_wait_ticks = 60 * 20
M.min_hand_craft_ticks = 60 * 3
M.teleport_retry_ticks = 60 * 5
M.max_per_pulse = 10

local EMERGENCY_DEVICE_ITEMS = {
  ["tech-priests-emergency-miner"] = true,
  ["tech-priests-emergency-smelter"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-power-grid"] = true,
  ["tech-priests-emergency-assembler"] = true,
  ["tech-priests-emergency-laboratorium"] = true,
}

local FACILITY_PREFERRED_ITEMS = {
  ["iron-plate"] = "smelter",
  ["copper-plate"] = "smelter",
  ["stone-brick"] = "smelter",
  ["iron-gear-wheel"] = "assembler",
  ["repair-pack"] = "assembler",
  ["firearm-magazine"] = "assembler",
  ["automation-science-pack"] = "assembler",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function M.root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {}, last_block = {}, last_teleport = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.block_remote_world_mining == nil then r.block_remote_world_mining = true end
  if r.prefer_facilities == nil then r.prefer_facilities = true end
  if r.allow_desperation_hand_craft == nil then r.allow_desperation_hand_craft = false end
  if r.throttle_failed_teleports == nil then r.throttle_failed_teleports = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.last_block = r.last_block or {}
  r.last_teleport = r.last_teleport or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail, force)
  local r = M.root()
  action = tostring(action or "event")
  stat(action)
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 80 do table.remove(r.recent, 1) end
  local key = action .. ":" .. safe(rec.station)
  local last = r.last_log[key] or -1000000
  if force or now() - last >= M.block_log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.505] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
  end
end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if game and game.item_prototypes and game.item_prototypes[name] then return true end
  return false
end

local function recipe_exists(name)
  if not name then return false end
  if prototypes and prototypes.recipe and prototypes.recipe[name] then return true end
  if game and game.recipe_prototypes and game.recipe_prototypes[name] then return true end
  return false
end

local function direct_kind(kind)
  kind = tostring(kind or "")
  return kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336"
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  local task = pair.emergency_craft
  local cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  task = pair.direct_acquisition_task_0336
  cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  task = pair.active_acquisition_0333
  cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  return nil, nil
end

local function target_position(pair, cur)
  if cur and valid(cur.entity) then return cur.entity.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function target_name(cur)
  if cur and valid(cur.entity) then return cur.entity.name end
  return cur and (cur.item_name or cur.output_item or cur.kind) or "nil"
end

local function item_from_task(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item) or nil
  if item_exists(item) then return item end
  item = task and (task.output_item or task.item_name or task.item or task.requested_item) or nil
  if item_exists(item) then return item end
  if cur and valid(cur.entity) then
    if cur.entity.type == "resource" and item_exists(cur.entity.name) then return cur.entity.name end
    if cur.entity.type == "tree" and item_exists("wood") then return "wood" end
    if item_exists("stone") then return "stone" end
  end
  return nil
end

local function is_world_target(cur)
  if not (cur and valid(cur.entity)) then return false end
  local t = tostring(cur.entity.type or "")
  return t == "resource" or t == "tree" or t == "simple-entity" or t == "simple-entity-with-owner" or t == "rock"
end

local function remote_direct_reason(pair)
  if M.root().block_remote_world_mining == false then return nil end
  if not valid_pair(pair) then return nil end
  local task, cur = current_direct_task(pair)
  if not (task and cur and is_world_target(cur)) then return nil end
  local pos = target_position(pair, cur)
  if not pos then return nil end
  local priest_d2 = dist_sq(pair.priest.position, pos) or 0
  if priest_d2 <= M.close_distance_sq then return nil end
  local station_d2 = dist_sq(pair.station.position, pos) or 0
  return "priest_not_adjacent priest_dist=" .. safe(string.format("%.1f", math.sqrt(priest_d2))) .. " station_dist=" .. safe(string.format("%.1f", math.sqrt(station_d2)))
end

local function station_inventory(pair)
  if not (pair and valid(pair.station) and pair.station.get_inventory) then return nil end
  local inv = nil
  pcall(function()
    inv = pair.station.get_inventory(defines.inventory.chest)
       or pair.station.get_inventory(defines.inventory.assembling_machine_input)
       or pair.station.get_inventory(defines.inventory.assembling_machine_output)
  end)
  if inv and inv.valid then return inv end
  return nil
end

local function inv_count(pair, item)
  local inv = station_inventory(pair)
  if not (inv and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function emit(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    pcall(_G.tech_priests_emit_overhead_status_0473, pair, text, { r = 1.0, g = 0.72, b = 0.2, a = 0.98 }, ttl or 60, 0.62, "behavior-execution-0505")
    return true
  end
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  return false
end

local function clear_direct_due(task, cur)
  if not task then return end
  task.direct_due_tick_0273 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0336 = nil
  task.direct_started_tick_0336 = nil
  task.direct_last_visual_tick_0336 = nil
  if cur then cur.station_side_0502 = nil end
end

local function stop_near_station(pair)
  if not valid_pair(pair) then return false end
  pair.target = pair.station
  pair.mining_lock_0315 = nil
  pair.direct_target_lease_0414 = nil
  pair.movement_request_0418 = nil
  pair.pathing_target_0418 = nil
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.stop })
    else
      pair.priest.set_command({ type = defines.command.stop })
    end
  end)
  return true
end

local function call_facility_doctrine(pair, item, reason)
  local Fac = rawget(_G, "TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0357")
    or rawget(_G, "TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0343")
    or rawget(_G, "TECH_PRIESTS_EMERGENCY_FACILITY_DOCTRINE_0340")
  if Fac and Fac.service_pair then
    local ok, did, why = pcall(Fac.service_pair, pair, reason or "behavior-0505")
    if ok then return did, why end
  end
  return false, "facility-doctrine-unavailable"
end

local function block_remote_direct(pair, reason)
  local why = remote_direct_reason(pair)
  if not why then return false end
  local task, cur = current_direct_task(pair)
  local item = item_from_task(task, cur) or "unknown"
  clear_direct_due(task, cur)
  stop_near_station(pair)
  pair.mode = "emergency-facility-doctrine"
  pair.remote_direct_blocked_0505 = { tick = now(), reason = tostring(reason or "remote-direct"), item = item, target = target_name(cur), why = why }
  if task then task.remote_direct_blocked_0505 = pair.remote_direct_blocked_0505 end
  local key = safe(station_unit(pair)) .. ":" .. safe(item) .. ":" .. safe(target_name(cur))
  local r = M.root()
  local last = r.last_block[key] or -1000000
  if now() - last >= 60 then
    r.last_block[key] = now()
    local did, fwhy = call_facility_doctrine(pair, item, "remote-direct-blocked-0505")
    emit(pair, "[item=" .. safe(item) .. "] remote world mining blocked; requesting Martian facility path", 75)
    record("remote-world-mining-blocked-0505", pair, "reason=" .. safe(reason) .. " item=" .. safe(item) .. " target=" .. safe(target_name(cur)) .. " " .. why .. " facility=" .. safe(did) .. ":" .. safe(fwhy))
  else
    stat("remote-world-mining-throttled-0505")
  end
  return true
end

local function recipe_energy_ticks(recipe_name, fallback)
  fallback = tonumber(fallback) or M.min_hand_craft_ticks
  local energy = nil
  if recipe_name and prototypes and prototypes.recipe and prototypes.recipe[recipe_name] then
    pcall(function() energy = prototypes.recipe[recipe_name].energy end)
  elseif recipe_name and game and game.recipe_prototypes and game.recipe_prototypes[recipe_name] then
    pcall(function() energy = game.recipe_prototypes[recipe_name].energy end)
  end
  local ticks = math.ceil((tonumber(energy) or (fallback / 60)) * 60 * 1.35)
  return math.max(M.min_hand_craft_ticks, ticks)
end

local function output_item(task)
  if not task then return nil end
  return task.output_item or task.item_name or task.item or task.requested_item
end

local function task_recipe_name(task)
  if not task then return nil end
  if type(task.recipe) == "string" then return task.recipe end
  if type(task.recipe) == "table" then return task.recipe.name or task.recipe.recipe or task.recipe.localised_name end
  local out = output_item(task)
  if recipe_exists(out) then return out end
  return nil
end

local function needed_units(task)
  local recipe = task and task.recipe or {}
  return math.max(1, tonumber(recipe.units) or tonumber(task and task.required_count) or tonumber(task and task.count) or 1)
end

local function ready_to_station_craft(task)
  if not task then return false end
  if task.current then return false end
  return (tonumber(task.gathered_units) or 0) >= needed_units(task)
end

local function at_station(pair)
  return valid_pair(pair) and (dist_sq(pair.priest.position, pair.station.position) or 999999) <= 9
end

local function request_station_return(pair)
  if not valid_pair(pair) then return false end
  if _G.tech_priests_request_movement_0418 then
    pcall(_G.tech_priests_request_movement_0418, pair, pair.station.position, "station-craft-0505", { radius = 1.2, owner = "behavior-execution-0505", priority = 70, distraction = defines.distraction.none })
  else
    pcall(function() pair.priest.set_command({ type = defines.command.go_to_location, destination = pair.station.position, radius = 1.2, distraction = defines.distraction.none }) end)
  end
  pair.mode = "returning-to-station-for-craft"
  return true
end

local function should_prefer_facility(task)
  local out = output_item(task)
  if not out then return false end
  if EMERGENCY_DEVICE_ITEMS[out] then return false end -- bootstrap equipment may be station-ritual-crafted.
  if FACILITY_PREFERRED_ITEMS[out] then return true end
  if task and task.recipe and not EMERGENCY_DEVICE_ITEMS[out] then return true end
  return false
end

local function guard_station_craft(pair, reason)
  local r = M.root(); if r.prefer_facilities == false then return false end
  if not valid_pair(pair) then return false end
  local task = pair.emergency_craft
  if not (task and ready_to_station_craft(task)) then return false end
  local out = output_item(task)
  if not out or inv_count(pair, out) > 0 then return false end

  if should_prefer_facility(task) and r.allow_desperation_hand_craft ~= true then
    task.facility_preference_started_0505 = task.facility_preference_started_0505 or now()
    task.facility_preference_item_0505 = out
    pair.mode = "emergency-facility-doctrine"
    pair.target = pair.station
    call_facility_doctrine(pair, out, "craft-preferred-facility-0505")
    emit(pair, "[item=" .. safe(out) .. "] routed to Martian emergency facilities before hand craft", 90)
    record("hand-craft-gated-for-facility-0505", pair, "item=" .. safe(out) .. " reason=" .. safe(reason))
    return true
  end

  -- Bootstrap / permitted desperation station craft: guarantee visible time.
  if not at_station(pair) then
    request_station_return(pair)
    emit(pair, "[item=" .. safe(out) .. "] returning to station for timed craft", 45)
    return true
  end
  local recipe_name = task_recipe_name(task)
  if not task.craft_due_tick_0505 then
    local ticks = recipe_energy_ticks(recipe_name, tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS) or M.min_hand_craft_ticks)
    task.craft_started_tick_0505 = now()
    task.craft_due_tick_0505 = now() + ticks
    pair.mode = "emergency-crafting"
    emit(pair, "[item=" .. safe(out) .. "] timed station craft started", 60)
    record("timed-station-craft-started-0505", pair, "item=" .. safe(out) .. " ticks=" .. safe(ticks) .. " recipe=" .. safe(recipe_name))
    return true
  end
  if now() < task.craft_due_tick_0505 then
    pair.mode = "emergency-crafting"
    local left = math.ceil((task.craft_due_tick_0505 - now()) / 60)
    emit(pair, "[item=" .. safe(out) .. "] station craft completing in " .. safe(left) .. "s", 30)
    return true
  end
  -- Due: let the existing legacy/crafting chain finish exactly once.
  task.craft_due_tick = math.min(tonumber(task.craft_due_tick) or now(), now())
  return false
end

local function patch_direct_services()
  local function wrap_global(name)
    local key = "TECH_PRIESTS_0505_PRE_" .. string.upper(name)
    if type(_G[name]) == "function" and not rawget(_G, key) then
      _G[key] = _G[name]
      _G[name] = function(pair, task, ...)
        if M.root().enabled ~= false and block_remote_direct(pair, name) then return true end
        return _G[key](pair, task, ...)
      end
    end
  end
  wrap_global("tech_priests_0273_service_direct_current")
  wrap_global("tech_priests_0312_service_direct_current")
  wrap_global("tech_priests_0315_service_direct_current")

  local Guard0502 = rawget(_G, "TechPriestsPriestVanishGuard0502")
  if Guard0502 and type(Guard0502.service_pair) == "function" and not Guard0502.behavior_0505_wrapped then
    Guard0502.behavior_0505_wrapped = true
    Guard0502.TECH_PRIESTS_0505_PRE_SERVICE_PAIR = Guard0502.service_pair
    Guard0502.service_pair = function(pair, reason)
      if M.root().enabled ~= false and block_remote_direct(pair, reason or "guard0502") then return true end
      return Guard0502.TECH_PRIESTS_0505_PRE_SERVICE_PAIR(pair, reason)
    end
  end

  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok and Exec and type(Exec.service_pair) == "function" and not Exec.behavior_0505_wrapped then
    Exec.behavior_0505_wrapped = true
    Exec.TECH_PRIESTS_0505_PRE_SERVICE_PAIR = Exec.service_pair
    Exec.service_pair = function(pair, reason)
      if M.root().enabled ~= false and block_remote_direct(pair, reason or "acquisition-executor") then return true end
      return Exec.TECH_PRIESTS_0505_PRE_SERVICE_PAIR(pair, reason)
    end
  end
end

local function patch_smoke_and_scanline()
  if type(_G.spawn_emergency_craft_smoke) == "function" and not rawget(_G, "TECH_PRIESTS_0505_PRE_SPAWN_SMOKE") then
    _G.TECH_PRIESTS_0505_PRE_SPAWN_SMOKE = _G.spawn_emergency_craft_smoke
    _G.spawn_emergency_craft_smoke = function(pair, pos, strong, ...)
      if M.root().enabled ~= false and pair and pair.remote_direct_blocked_0505 and valid_pair(pair) and pos then
        local d2 = dist_sq(pair.priest.position, pos) or 0
        if d2 > M.close_distance_sq then stat("remote-smoke-suppressed-0505"); return false end
      end
      return _G.TECH_PRIESTS_0505_PRE_SPAWN_SMOKE(pair, pos, strong, ...)
    end
  end
  if type(_G.draw_emergency_craft_scan_line) == "function" and not rawget(_G, "TECH_PRIESTS_0505_PRE_SCAN_LINE") then
    _G.TECH_PRIESTS_0505_PRE_SCAN_LINE = _G.draw_emergency_craft_scan_line
    _G.draw_emergency_craft_scan_line = function(pair, target, ...)
      if M.root().enabled ~= false and pair and pair.remote_direct_blocked_0505 and valid_pair(pair) and valid(target) then
        local d2 = dist_sq(pair.priest.position, target.position) or 0
        if d2 > M.close_distance_sq then stat("remote-scanline-suppressed-0505"); return false end
      end
      return _G.TECH_PRIESTS_0505_PRE_SCAN_LINE(pair, target, ...)
    end
  end
end

local function patch_crafting()
  if type(_G.handle_emergency_desperation_craft) == "function" and not rawget(_G, "TECH_PRIESTS_0505_PRE_HANDLE_EMERGENCY_CRAFT") then
    _G.TECH_PRIESTS_0505_PRE_HANDLE_EMERGENCY_CRAFT = _G.handle_emergency_desperation_craft
    _G.handle_emergency_desperation_craft = function(pair, ...)
      if M.root().enabled ~= false then
        if block_remote_direct(pair, "handle-emergency-craft") then return true end
        if guard_station_craft(pair, "handle-emergency-craft") then return true end
      end
      return _G.TECH_PRIESTS_0505_PRE_HANDLE_EMERGENCY_CRAFT(pair, ...)
    end
  end

  -- Do not let older tuning shorten craft work below the visible minimum.
  _G.EMERGENCY_CRAFT_WORK_TICKS = math.max(tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS) or 0, M.min_hand_craft_ticks)
  _G.EMERGENCY_CRAFT_SCAN_TICKS = math.max(tonumber(_G.EMERGENCY_CRAFT_SCAN_TICKS) or 0, 60)
  _G.EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS = math.max(tonumber(_G.EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS) or 0, 45)
end

local function patch_recovery()
  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0505_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0505_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate, ...)
      local r = M.root()
      if r.enabled ~= false and r.throttle_failed_teleports ~= false and valid_pair(pair) and force_recall then
        local key = tostring(station_unit(pair) or "nil")
        local last = r.last_teleport[key] or -1000000
        if now() - last < M.teleport_retry_ticks then
          stat("recovery-teleport-throttled-0505")
          stop_near_station(pair)
          return true
        end
        r.last_teleport[key] = now()
      end
      return _G.TECH_PRIESTS_0505_PRE_ENSURE_PAIR_PRIEST(pair, force_recall, immediate, ...)
    end
  end
end

function M.service_pair(pair)
  if M.root().enabled == false or not valid(pair and pair.station) then return false end
  if valid(pair.priest) then
    block_remote_direct(pair, "0505-pulse")
    guard_station_craft(pair, "0505-pulse")
    return true
  end
  return false
end

function M.service_all()
  if M.root().enabled == false then return false end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if M.service_pair(pair) then n = n + 1 end
    if n >= M.max_per_pulse then break end
  end
  return true
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.behavior_execution_0505_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.behavior_execution_0505_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-EXECUTION-0505 BEGIN enabled=" .. safe(r.enabled)
      .. " block_remote=" .. safe(r.block_remote_world_mining)
      .. " prefer_facilities=" .. safe(r.prefer_facilities)
      .. " allow_handcraft=" .. safe(r.allow_desperation_hand_craft)
      .. " remote_blocks=" .. safe(r.stats["remote-world-mining-blocked-0505"] or 0)
      .. " handcraft_gated=" .. safe(r.stats["hand-craft-gated-for-facility-0505"] or 0)
      .. " timed_crafts=" .. safe(r.stats["timed-station-craft-started-0505"] or 0)
      .. " tp_throttled=" .. safe(r.stats["recovery-teleport-throttled-0505"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local task, cur = current_direct_task(pair)
        local reason = pair.remote_direct_blocked_0505 and pair.remote_direct_blocked_0505.why or "nil"
        lines[#lines + 1] = "PAIR-DUMP-0468 be0505[" .. safe(pair.station.unit_number) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest))
          .. " mode=" .. safe(pair.mode)
          .. " direct=" .. safe(cur and cur.kind or "nil")
          .. " target=" .. safe(target_name(cur))
          .. " blocked=" .. safe(reason)
          .. " craft_due=" .. safe(pair.emergency_craft and pair.emergency_craft.craft_due_tick_0505 or "nil")
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-EXECUTION-0505 END"
    return lines
  end
  return true
end

local function commands_install()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-0505") end end)
  commands.add_command("tp-behavior-0505", "Tech Priests 0.1.505 behavior execution doctrine. status/all/remote-on/remote-off/facility-on/facility-off/handcraft-on/handcraft-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = M.root()
    if p == "enable" then r.enabled = true end
    if p == "disable" then r.enabled = false end
    if p == "remote-on" then r.block_remote_world_mining = true end
    if p == "remote-off" then r.block_remote_world_mining = false end
    if p == "facility-on" then r.prefer_facilities = true end
    if p == "facility-off" then r.prefer_facilities = false end
    if p == "handcraft-on" then r.allow_desperation_hand_craft = true end
    if p == "handcraft-off" then r.allow_desperation_hand_craft = false end
    if p == "all" then M.service_all() end
    local msg = "[Tech-Priests 0.1.505] enabled=" .. safe(r.enabled)
      .. " block_remote=" .. safe(r.block_remote_world_mining)
      .. " prefer_facilities=" .. safe(r.prefer_facilities)
      .. " allow_handcraft=" .. safe(r.allow_desperation_hand_craft)
      .. " remote_blocks=" .. safe(r.stats["remote-world-mining-blocked-0505"] or 0)
      .. " handcraft_gated=" .. safe(r.stats["hand-craft-gated-for-facility-0505"] or 0)
      .. " timed_crafts=" .. safe(r.stats["timed-station-craft-started-0505"] or 0)
      .. " tp_throttled=" .. safe(r.stats["recovery-teleport-throttled-0505"] or 0)
    if player then player.print(msg) elseif log then log(msg) end
  end)
end

function M.install()
  M.root()
  patch_direct_services()
  patch_smoke_and_scanline()
  patch_crafting()
  patch_recovery()
  wrap_pair_dump()
  commands_install()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "behavior_execution_doctrine_0505", category = "behavior", interval = 37, priority = 45, budget = 8, fn = function(event, budget) M.service_all("broker-0505") return true end, note = "0505 direct behavior execution doctrine migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(37, M.service_all, { owner = "behavior_execution_doctrine_0505", category = "behavior", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then script.on_nth_tick(37, M.service_all) end
  end
  _G.TechPriestsBehaviorExecutionDoctrine0505 = M
  if log then log("[Tech-Priests 0.1.505] behavior execution doctrine installed; remote world mining blocked unless priest is adjacent; emergency facilities preferred before hand craft") end
  return true
end

return M
