-- scripts/core/direct_acquisition_movement_lock_0650.lua
-- Tech Priests 0.1.650
--
-- Direct acquisition target/movement lock.
--
-- The 0.1.649 live logs show the exact failure pattern: legacy nth-tick gather
-- keeps announcing "direct gather target station=X target=iron-ore" while the
-- dispatcher-owned 0513 executor is either walking toward a different resource,
-- being interrupted by assignment/idle state churn, or returning
-- movement-request-failed.  This module makes direct acquisition obey a simple
-- contract: once a station says it is acquiring a resource from a physical entity,
-- that entity remains the active target until it is reached, invalidated, or the
-- direct acquisition task completes.

local M = {}
M.version = "0.1.650"
M.storage_key = "direct_acquisition_movement_lock_0650"
M.tick_interval = 17
M.max_pairs_per_pulse = 32
M.log_interval = 480
M.close_distance_sq = 2.25

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  dirt = true,
  ["direct-mine-0336"] = true,
}

local RESOURCE_ITEMS = {
  ["iron-ore"] = true,
  ["copper-ore"] = true,
  coal = true,
  stone = true,
  ["uranium-ore"] = true,
  wood = true,
}

local pre_request_movement = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function same_pos(a, b, eps) return a and b and dist_sq(a, b) <= ((eps or 0.15) * (eps or 0.15)) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  return r
end

local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = root()
  stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 120 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.650] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function item_exists(name) return name and prototypes and prototypes.item and prototypes.item[name] ~= nil end

local function get_exec()
  local Exec = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
  if not Exec then local ok, mod = pcall(require, "scripts.core.direct_acquisition_executor_0513"); if ok then Exec = mod end end
  return Exec
end

local function current_direct_task(pair)
  local Exec = get_exec()
  if Exec and type(Exec.current_direct_task) == "function" then
    local ok, task, cur, key = pcall(Exec.current_direct_task, pair)
    if ok then return task, cur, key end
  end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair and pair[key]
    local cur = type(task) == "table" and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end

local function target_position(cur)
  local e = target_entity(cur)
  if e then return e.position end
  if cur and cur.position and cur.position.x and cur.position.y then return cur.position end
  return nil
end

local function output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item) or nil
  if item_exists(item) then return item end
  item = task and (task.output_item or task.item_name or task.wanted_item or task.requested_item) or nil
  if item_exists(item) then return item end
  local e = target_entity(cur)
  if valid(e) then
    if e.type == "resource" and item_exists(e.name) then return e.name end
    local n = lower(e.name)
    if n:find("tree", 1, true) and item_exists("wood") then return "wood" end
    if (n:find("rock", 1, true) or n:find("stone", 1, true)) and item_exists("stone") then return "stone" end
    if n:find("coal", 1, true) and item_exists("coal") then return "coal" end
    if n:find("iron", 1, true) and item_exists("iron-ore") then return "iron-ore" end
    if n:find("copper", 1, true) and item_exists("copper-ore") then return "copper-ore" end
  end
  return nil
end

local function target_label(e, pos)
  if valid(e) then return safe(e.name) .. "@" .. string.format("%.1f,%.1f", e.position.x or 0, e.position.y or 0) end
  if pos then return "pos@" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) end
  return "nil"
end

local function same_entity_or_position(a, lock)
  if not (valid(a) and lock) then return false end
  if valid(lock.entity) and a == lock.entity then return true end
  if lock.name and a.name ~= lock.name then return false end
  if lock.position and same_pos(a.position, lock.position, 0.25) then return true end
  return false
end

local function lock_current_target(pair, task, cur, reason)
  if not (valid_pair(pair) and cur) then return false end
  local e = target_entity(cur)
  if not valid(e) then return false end
  local item = output_item(task, cur)
  if item and not RESOURCE_ITEMS[item] then return false end
  local pos = { x = e.position.x, y = e.position.y }
  local existing = pair.direct_acquisition_target_lock_0650
  if existing and valid(existing.entity) and same_entity_or_position(e, existing) then
    existing.last_seen_tick = now()
    existing.item = item or existing.item
    return false
  end
  pair.direct_acquisition_target_lock_0650 = {
    version = M.version,
    tick = now(),
    last_seen_tick = now(),
    station = station_unit(pair),
    priest = priest_unit(pair),
    entity = e,
    name = e.name,
    item = item,
    position = pos,
    reason = reason or "lock",
  }
  record("direct-target-locked-0650", pair, "item=" .. safe(item) .. " target=" .. target_label(e), true)
  return true
end

local function clear_lock(pair, reason)
  if pair and pair.direct_acquisition_target_lock_0650 then
    record("direct-target-lock-cleared-0650", pair, tostring(reason or "clear"), false)
    pair.direct_acquisition_target_lock_0650 = nil
    return true
  end
  return false
end

local function restore_locked_target(pair, task, cur, reason)
  if root().enabled == false then return false end
  local lock = pair and pair.direct_acquisition_target_lock_0650
  if not (lock and cur) then return false end
  if not valid(lock.entity) then clear_lock(pair, "locked entity invalid"); return false end
  local phase = pair.dispatcher_direct_0513 and tostring(pair.dispatcher_direct_0513.phase or "") or ""
  local active = phase == "walk-to-target" or phase == "work-target" or phase == "movement-request-failed" or phase == "target-invalid" or phase == ""
  if not active then return false end
  local current = target_entity(cur)
  if current and same_entity_or_position(current, lock) then return false end
  local old = target_label(current, target_position(cur))
  cur.entity = lock.entity
  cur.target = lock.entity
  cur.source = lock.entity
  cur.position = { x = lock.position.x, y = lock.position.y }
  if lock.item then
    cur.output_item = lock.item
    cur.item_name = cur.item_name or lock.item
  end
  pair.target = lock.entity
  pair.mode = "travelling-to-direct-acquisition"
  if pair.dispatcher_direct_0513 then
    pair.dispatcher_direct_0513.target = target_label(lock.entity)
    pair.dispatcher_direct_0513.item = lock.item
    pair.dispatcher_direct_0513.phase = "walk-to-target"
    pair.dispatcher_direct_0513.detail = "target lock restored after churn"
  end
  record("direct-target-churn-suppressed-0650", pair, "old=" .. safe(old) .. " locked=" .. target_label(lock.entity) .. " reason=" .. safe(reason), true)
  return true
end

local function is_direct_move(reason, opts)
  local s = lower(reason) .. " " .. lower(opts and opts.owner or "")
  return s:find("direct%-acquisition", 1, false) ~= nil or s:find("physical%-direct", 1, false) ~= nil
end

local function force_direct_command(pair, pos, reason)
  if not (valid_pair(pair) and pos and defines and defines.command) then return false end
  local command = { type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction and defines.distraction.none or nil }
  local ok, moved = pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command(command)
      return true
    elseif pair.priest.set_command then
      pair.priest.set_command(command)
      return true
    end
    return false
  end)
  if ok and moved then
    pair.mode = "travelling-to-direct-acquisition"
    pair.movement_controller_reason_0418 = "direct-acquisition-0650-forced-command"
    pair.direct_acquisition_force_move_0650 = { tick = now(), x = pos.x, y = pos.y, reason = reason or "force" }
    record("direct-movement-forced-0650", pair, "pos=" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) .. " reason=" .. safe(reason), true)
    return true
  end
  return false
end

local function wrap_movement_request()
  if pre_request_movement or type(rawget(_G, "tech_priests_request_movement_0418")) ~= "function" then return false end
  pre_request_movement = rawget(_G, "tech_priests_request_movement_0418")
  _G.TECH_PRIESTS_0650_PRE_REQUEST_MOVEMENT_0418 = pre_request_movement
  _G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts, ...)
    local ok = pre_request_movement(pair, pos, reason, opts, ...)
    if ok ~= false or root().enabled == false or not is_direct_move(reason, opts) then return ok end
    if force_direct_command(pair, pos, reason or (opts and opts.owner) or "direct-acquisition-0650") then return true end
    return ok
  end
  return true
end

local function wrap_executor()
  local Exec = get_exec()
  if not (Exec and type(Exec.service_pair) == "function") or Exec.direct_movement_lock_0650_wrapped then return false end
  Exec.direct_movement_lock_0650_wrapped = true
  Exec.TECH_PRIESTS_0650_PRE_SERVICE_PAIR = Exec.service_pair
  Exec.service_pair = function(pair, reason, ...)
    if root().enabled == false then return Exec.TECH_PRIESTS_0650_PRE_SERVICE_PAIR(pair, reason, ...) end
    local task, cur = current_direct_task(pair)
    if not (task and cur) then clear_lock(pair, "no-direct-task"); return Exec.TECH_PRIESTS_0650_PRE_SERVICE_PAIR(pair, reason, ...) end
    restore_locked_target(pair, task, cur, reason or "pre-service")
    local ok, why = Exec.TECH_PRIESTS_0650_PRE_SERVICE_PAIR(pair, reason, ...)
    task, cur = current_direct_task(pair)
    local phase = pair and pair.dispatcher_direct_0513 and tostring(pair.dispatcher_direct_0513.phase or "") or ""
    if task and cur and (phase == "walk-to-target" or phase == "work-target" or why == "walking" or why == "working") then
      lock_current_target(pair, task, cur, reason or why or "service")
    elseif not task or phase == "complete" or phase == "none" or phase == "return-for-craft" or phase == "return-to-station" then
      clear_lock(pair, phase ~= "" and phase or "inactive")
    end
    if phase == "movement-request-failed" then
      local lock = pair and pair.direct_acquisition_target_lock_0650
      if lock and valid(lock.entity) then force_direct_command(pair, lock.position, "0513 movement-request-failed fallback") end
    end
    return ok, why
  end
  return true
end

local function wrap_legacy_direct_function(name)
  local fn = rawget(_G, name)
  local key = "TECH_PRIESTS_0650_PRE_" .. string.upper(name)
  if type(fn) ~= "function" or rawget(_G, key) then return false end
  _G[key] = fn
  _G[name] = function(pair, task, ...)
    if root().enabled ~= false then
      local active_task, cur = current_direct_task(pair)
      restore_locked_target(pair, active_task, cur, name .. ":legacy-pre")
    end
    local result = fn(pair, task, ...)
    if root().enabled ~= false and valid_pair(pair) then
      local Exec = get_exec()
      if Exec and type(Exec.service_pair) == "function" then pcall(Exec.service_pair, pair, name .. ":legacy-transfer-0650") end
    end
    return result
  end
  return true
end

local function wrap_legacy_direct_functions()
  local n = 0
  for _, name in ipairs({ "tech_priests_0273_service_direct_current", "tech_priests_0312_service_direct_current", "tech_priests_0315_service_direct_current" }) do
    if wrap_legacy_direct_function(name) then n = n + 1 end
  end
  return n
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  local task, cur = current_direct_task(pair)
  if not (task and cur) then clear_lock(pair, "service-no-task"); return false end
  restore_locked_target(pair, task, cur, reason or "service")
  local lock = pair.direct_acquisition_target_lock_0650
  if lock and valid(lock.entity) and dist_sq(pair.priest.position, lock.position) > M.close_distance_sq then
    local phase = pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase or ""
    local stale = (not pair.direct_acquisition_force_move_0650) or now() - (tonumber(pair.direct_acquisition_force_move_0650.tick) or 0) > 90
    if (phase == "movement-request-failed" or phase == "walk-to-target" or phase == nil or phase == "") and stale then
      force_direct_command(pair, lock.position, reason or "lock-service")
      return true
    end
  elseif target_entity(cur) then
    lock_current_target(pair, task, cur, reason or "service")
  end
  return false
end

function M.service_all(reason)
  wrap_movement_request()
  wrap_executor()
  wrap_legacy_direct_functions()
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end
  end
  return n
end

local function selected_pair(player)
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local unit = selected.unit_number
    if unit and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[unit] then return storage.tech_priests.pairs_by_station[unit] end
    if unit and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[unit] then return storage.tech_priests.pairs_by_priest[unit] end
  end
  if selected and selected.valid and type(_G.find_pair_for_entity) == "function" then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok then return pair end end
  return nil
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-direct-lock-0650") end end)
  commands.add_command("tp-direct-lock-0650", "Tech Priests 0.1.650: direct acquisition target/movement lock. Params: status/kick/all/on/off/recent/clear", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "clear" and pair then clear_lock(pair, "command-clear") end
    if p == "kick" and pair then M.service_pair(pair, "command-kick") end
    local lines = { "[tp-direct-lock-0650] enabled=" .. safe(r.enabled) .. " locked=" .. safe(r.stats["direct-target-locked-0650"] or 0) .. " churn=" .. safe(r.stats["direct-target-churn-suppressed-0650"] or 0) .. " forced=" .. safe(r.stats["direct-movement-forced-0650"] or 0) }
    if pair then
      local task, cur, key = current_direct_task(pair)
      local lock = pair.direct_acquisition_target_lock_0650
      lines[#lines + 1] = "  station=" .. safe(station_unit(pair)) .. " mode=" .. safe(pair.mode) .. " phase=" .. safe(pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase) .. " key=" .. safe(key) .. " current=" .. target_label(target_entity(cur), target_position(cur)) .. " lock=" .. target_label(lock and lock.entity, lock and lock.position)
    else lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest" end
    if p == "recent" or p == "kick" then for i = math.max(1, #r.recent - 10), #r.recent do local ev = r.recent[i]; if ev then lines[#lines + 1] = "  [" .. safe(ev.tick) .. "] " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail) end end end
    if player and player.valid then for _, line in ipairs(lines) do player.print(line) end elseif game and game.print then for _, line in ipairs(lines) do game.print(line) end end
  end)
end

function M.install()
  root()
  wrap_movement_request()
  wrap_executor()
  wrap_legacy_direct_functions()
  install_command()
  _G.TechPriestsDirectAcquisitionMovementLock0650 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "direct_acquisition_movement_lock_0650", category = "acquisition", interval = M.tick_interval, priority = 51, budget = 6, fn = function(event, budget) M.service_all("broker") return true end, note = "hold direct resource target and force movement fallback if the route request fails" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "direct_acquisition_movement_lock_0650", category = "acquisition", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.650] direct acquisition movement lock installed; declared resource targets are held and movement fallback is forced when routing refuses") end
  return true
end

return M
