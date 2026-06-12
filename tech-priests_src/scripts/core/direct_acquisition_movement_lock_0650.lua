-- scripts/core/direct_acquisition_movement_lock_0650.lua
-- Tech Priests 0.1.653
-- Commandless direct acquisition target/movement lock.

local M = {}
M.version = "0.1.653"
M.storage_key = "direct_acquisition_movement_lock_0650"
M.tick_interval = 17
M.max_pairs_per_pulse = 32
M.close_distance_sq = 2.25
M.log_interval = 480

local DIRECT_KINDS = { ["direct-mine-0273"] = true, ["direct-dirt-0273"] = true, dirt = true, ["direct-mine-0336"] = true }
local RESOURCE_ITEMS = { ["iron-ore"] = true, ["copper-ore"] = true, coal = true, stone = true, ["uranium-ore"] = true, wood = true }
local pre_request_movement = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}
  return r
end

local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = root(); stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 100 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.653] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function get_exec()
  local Exec = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
  if not Exec then local ok, mod = pcall(require, "scripts.core.direct_acquisition_executor_0513"); if ok then Exec = mod end end
  return Exec
end

local function current_direct_task(pair)
  local Exec = get_exec()
  if Exec and type(Exec.current_direct_task) == "function" then local ok, task, cur, key = pcall(Exec.current_direct_task, pair); if ok then return task, cur, key end end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair and pair[key]; local cur = type(task) == "table" and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end

local function target_entity(cur) if cur and valid(cur.entity) then return cur.entity end if cur and valid(cur.target) then return cur.target end if cur and valid(cur.source) then return cur.source end return nil end
local function target_position(cur) local e = target_entity(cur); if e then return e.position end if cur and cur.position and cur.position.x and cur.position.y then return cur.position end return nil end
local function output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item) or nil
  if item then return item end
  return task and (task.output_item or task.item_name or task.wanted_item or task.requested_item) or nil
end

local function target_label(e, pos)
  if valid(e) then return safe(e.name) .. "@" .. string.format("%.1f,%.1f", e.position.x or 0, e.position.y or 0) end
  if pos then return "pos@" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) end
  return "nil"
end

local function lock_current_target(pair, task, cur, reason)
  local e = target_entity(cur)
  if not (valid_pair(pair) and valid(e)) then return false end
  local item = output_item(task, cur)
  if item and not RESOURCE_ITEMS[item] then return false end
  local existing = pair.direct_acquisition_target_lock_0650
  if existing and valid(existing.entity) and existing.entity == e then existing.last_seen_tick = now(); return false end
  pair.direct_acquisition_target_lock_0650 = { version = M.version, tick = now(), last_seen_tick = now(), station = station_unit(pair), priest = priest_unit(pair), entity = e, name = e.name, item = item, position = { x = e.position.x, y = e.position.y }, reason = reason or "lock" }
  record("direct-target-locked-0650", pair, "item=" .. safe(item) .. " target=" .. target_label(e), true)
  return true
end

local function clear_lock(pair, reason)
  if pair and pair.direct_acquisition_target_lock_0650 then pair.direct_acquisition_target_lock_0650 = nil; record("direct-target-lock-cleared-0650", pair, tostring(reason or "clear"), false); return true end
  return false
end

local function restore_locked_target(pair, task, cur, reason)
  local lock = pair and pair.direct_acquisition_target_lock_0650
  if not (lock and cur) then return false end
  if not valid(lock.entity) then clear_lock(pair, "locked entity invalid"); return false end
  local current = target_entity(cur)
  if current == lock.entity then return false end
  cur.entity = lock.entity; cur.target = lock.entity; cur.source = lock.entity; cur.position = { x = lock.position.x, y = lock.position.y }
  if lock.item then cur.output_item = lock.item; cur.item_name = cur.item_name or lock.item end
  pair.target = lock.entity; pair.mode = "travelling-to-direct-acquisition"
  pair.dispatcher_direct_0513 = pair.dispatcher_direct_0513 or {}; pair.dispatcher_direct_0513.phase = "walk-to-target"; pair.dispatcher_direct_0513.target = target_label(lock.entity); pair.dispatcher_direct_0513.item = lock.item
  record("direct-target-churn-suppressed-0650", pair, "locked=" .. target_label(lock.entity) .. " reason=" .. safe(reason), true)
  return true
end

local function force_direct_command(pair, pos, reason)
  if not (valid_pair(pair) and pos and defines and defines.command) then return false end
  local command = { type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction and defines.distraction.none or nil }
  local ok = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok = true elseif pair.priest.set_command then pair.priest.set_command(command); ok = true end end)
  if ok then pair.mode = "travelling-to-direct-acquisition"; pair.movement_controller_reason_0418 = "direct-acquisition-0650-forced-command"; pair.direct_acquisition_force_move_0650 = { tick = now(), x = pos.x, y = pos.y, reason = reason or "force" }; record("direct-movement-forced-0650", pair, "pos=" .. string.format("%.1f,%.1f", pos.x or 0,pos.y or 0), true) end
  return ok
end

local function wrap_movement_request()
  if pre_request_movement or type(rawget(_G, "tech_priests_request_movement_0418")) ~= "function" then return false end
  pre_request_movement = rawget(_G, "tech_priests_request_movement_0418")
  _G.TECH_PRIESTS_0650_PRE_REQUEST_MOVEMENT_0418 = pre_request_movement
  _G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts, ...)
    local ok = pre_request_movement(pair, pos, reason, opts, ...)
    local s = lower(reason) .. " " .. lower(opts and opts.owner or "")
    if ok == false and s:find("direct%-acquisition", 1, false) then if force_direct_command(pair, pos, reason) then return true end end
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
    if task and cur and (phase == "walk-to-target" or phase == "work-target" or why == "walking" or why == "working") then lock_current_target(pair, task, cur, reason or why or "service") elseif not task or phase == "complete" or phase == "return-for-craft" or phase == "return-to-station" then clear_lock(pair, phase ~= "" and phase or "inactive") end
    if phase == "movement-request-failed" then local lock = pair and pair.direct_acquisition_target_lock_0650; if lock and valid(lock.entity) then force_direct_command(pair, lock.position, "0513 movement-request-failed fallback") end end
    return ok, why
  end
  return true
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  local task, cur = current_direct_task(pair)
  if not (task and cur) then clear_lock(pair, "service-no-task"); return false end
  restore_locked_target(pair, task, cur, reason or "service")
  local lock = pair.direct_acquisition_target_lock_0650
  if lock and valid(lock.entity) and dist_sq(pair.priest.position, lock.position) > M.close_distance_sq then
    local stale = (not pair.direct_acquisition_force_move_0650) or now() - (tonumber(pair.direct_acquisition_force_move_0650.tick) or 0) > 90
    if stale then force_direct_command(pair, lock.position, reason or "lock-service"); return true end
  elseif target_entity(cur) then lock_current_target(pair, task, cur, reason or "service") end
  return false
end

function M.service_all(reason)
  wrap_movement_request(); wrap_executor()
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end end
  return n
end

function M.install()
  root(); wrap_movement_request(); wrap_executor(); _G.TechPriestsDirectAcquisitionMovementLock0650 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "direct_acquisition_movement_lock_0650", category = "acquisition", interval = M.tick_interval, priority = 51, budget = 6, fn = function(event, budget) M.service_all("broker"); return true end, note = "hold direct resource target and force movement fallback if route request fails" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "direct_acquisition_movement_lock_0650", category = "acquisition", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] direct acquisition movement lock installed") end
  return true
end

return M
