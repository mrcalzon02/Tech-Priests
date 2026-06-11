-- scripts/core/movement_target_reconciler_0652.lua
-- Tech Priests 0.1.652
--
-- Movement target reconciler.
--
-- 0.1.651 proved the hard vector enforcer works, but the live log exposed a
-- worse ownership mismatch: direct acquisition can lock a stone/ore entity while
-- a generic station/action-arbiter movement request still points at the station.
-- The vector enforcer then obediently snaps the priest toward the wrong target.
--
-- This module reconciles target truth before movement correction runs.  If direct
-- acquisition owns a physical target lock, pair.target and movement_request_0418
-- must point at that locked resource entity, not at the station, an idle scan
-- object, or an action-arbiter fallback point.

local M = {}
M.version = "0.1.652"
M.storage_key = "movement_target_reconciler_0652"
M.tick_interval = 5
M.max_pairs_per_pulse = 48
M.request_ttl = 60 * 6
M.request_radius = 0.75
M.log_interval = 300

local pre_request = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_key(pair) local su = station_unit(pair); if su then return tostring(su) end local pu = priest_unit(pair); if pu then return "p" .. tostring(pu) end return nil end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function same_pos(a, b, eps) return a and b and dist_sq(a, b) <= ((eps or 0.35) * (eps or 0.35)) end

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
  while #r.recent > 140 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.652] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function movement_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419 = storage.tech_priests.movement_controller_0419 or { requests = {}, active_request_ids = {}, stats = {} }
  local r = storage.tech_priests.movement_controller_0419
  r.requests = r.requests or {}
  r.active_request_ids = r.active_request_ids or {}
  r.stats = r.stats or {}
  return r
end

local function lock_active(pair)
  local lock = pair and pair.direct_acquisition_target_lock_0650 or nil
  if not (lock and valid(lock.entity) and lock.position and lock.position.x and lock.position.y) then return nil end
  local phase = pair.dispatcher_direct_0513 and tostring(pair.dispatcher_direct_0513.phase or "") or ""
  local mode = lower(pair.mode)
  if phase == "complete" or phase == "return-for-craft" or phase == "return-to-station" then return nil end
  if mode:find("direct", 1, true) or mode:find("acquisition", 1, true) or mode:find("travelling", 1, true) or mode:find("infrastructure", 1, true) then return lock end
  -- If a lock exists and has been seen recently, treat it as acquisition truth.
  if now() - (tonumber(lock.last_seen_tick or lock.tick or 0) or 0) < 60 * 4 then return lock end
  return nil
end

local function request_owner(req)
  return lower((req and (req.owner or req.reason)) or "")
end

local function request_is_direct(req)
  local s = request_owner(req)
  return s:find("direct%-acquisition", 1, false) or s:find("target%-reconciler", 1, false) or s:find("physical%-direct", 1, false) or s:find("direct%-target", 1, false)
end

local function request_points_to_lock(req, lock)
  return req and lock and lock.position and same_pos(req, lock.position, 0.55)
end

local function make_lock_request(pair, lock, reason)
  local req = {
    x = lock.position.x,
    y = lock.position.y,
    radius = M.request_radius,
    reason = reason or "direct-target-reconciler-0652",
    owner = "direct-target-reconciler-0652",
    priority = 940,
    distraction = defines and defines.distraction and defines.distraction.none or nil,
    issued_tick = now(),
    updated_tick = now(),
    expires_tick = now() + M.request_ttl,
    last_command_tick = 0,
    last_distance_sq = nil,
    direct_target_lock_0652 = true,
    target_name = lock.name or (valid(lock.entity) and lock.entity.name) or nil,
    target_unit = valid(lock.entity) and lock.entity.unit_number or nil,
    item = lock.item,
  }
  local mr = movement_root()
  local key = pair_key(pair)
  if key then
    mr.requests[key] = req
    mr.active_request_ids[key] = true
  end
  pair.movement_request_0418 = req
  pair.movement_controller_owner_0418 = req.owner
  pair.movement_controller_reason_0418 = req.reason
  pair.movement_controller_clamp_0418 = nil
  pair.movement_controller_state_0418 = "direct-target-reconciled-0652"
  return req
end

local function force_go_to(pair, req, reason)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  local command = { type = defines.command.go_to_location, destination = { x = req.x, y = req.y }, radius = tonumber(req.radius) or M.request_radius, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok_any = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok_any = true end end)
  pcall(function() if not ok_any and pair.priest.set_command then pair.priest.set_command(command); ok_any = true end end)
  if ok_any then
    req.last_command_tick = now()
    pair.movement_controller_state_0418 = "direct-target-commanded-0652"
    pair.direct_target_reconciler_0652_last_command = { tick = now(), x = req.x, y = req.y, reason = reason or "force" }
  end
  return ok_any
end

function M.reconcile_pair(pair, reason)
  if root().enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local lock = lock_active(pair)
  if not lock then return false, "no-active-lock" end

  local current = pair.movement_request_0418
  local current_owner = request_owner(current)
  local current_target = current and current.x and current.y and (string.format("%.1f,%.1f", current.x, current.y)) or "nil"
  local lock_target = string.format("%.1f,%.1f", lock.position.x or 0, lock.position.y or 0)

  pair.target = lock.entity
  pair.acquisition_target_0652 = lock.entity
  pair.direct_target_reconciler_0652 = {
    tick = now(),
    item = lock.item,
    target = lock.name or lock.entity.name,
    x = lock.position.x,
    y = lock.position.y,
    previous_request_owner = current_owner,
    previous_request = current_target,
    reason = reason or "reconcile",
  }

  if request_points_to_lock(current, lock) and request_is_direct(current) then
    current.updated_tick = now()
    current.expires_tick = now() + M.request_ttl
    return false, "already-direct-lock-request"
  end

  local req = make_lock_request(pair, lock, "direct-target-reconciler-0652")
  local commanded = force_go_to(pair, req, reason or "reconcile")
  record("movement-target-reconciled-0652", pair, "item=" .. safe(lock.item) .. " target=" .. safe(lock.name or lock.entity.name) .. " lock=" .. lock_target .. " previous=" .. current_target .. " owner=" .. safe(current_owner) .. " commanded=" .. safe(commanded), true)
  return true, "reconciled"
end

local function wrap_movement_request()
  if pre_request or type(rawget(_G, "tech_priests_request_movement_0418")) ~= "function" then return false end
  pre_request = rawget(_G, "tech_priests_request_movement_0418")
  _G.TECH_PRIESTS_0652_PRE_REQUEST_MOVEMENT_0418 = pre_request
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts, ...)
    local lock = root().enabled ~= false and lock_active(pair) or nil
    if lock and not request_points_to_lock(destination, lock) then
      local s = lower(reason) .. " " .. lower(opts and opts.owner or "")
      local directish = s:find("direct%-acquisition", 1, false) or s:find("physical%-direct", 1, false) or s:find("direct%-target", 1, false)
      local exempt = s:find("combat", 1, true) or s:find("death", 1, true) or s:find("respawn", 1, true) or s:find("void", 1, true)
      if not exempt and not directish then
        M.reconcile_pair(pair, "request-wrapper-redirect-0652")
        return true, pair and pair.movement_request_0418 or nil
      end
    end
    return pre_request(pair, destination, reason, opts, ...)
  end
  return true
end

function M.service_all(reason)
  wrap_movement_request()
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      local ok, acted = pcall(M.reconcile_pair, pair, reason or "pulse")
      if ok and acted then n = n + 1 end
    end
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
  pcall(function() if commands.remove_command then commands.remove_command("tp-target-reconcile-0652") end end)
  commands.add_command("tp-target-reconcile-0652", "Tech Priests 0.1.652: reconcile movement/visual target to active direct acquisition lock. Params: status/kick/all/on/off/recent", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "kick" and pair then M.reconcile_pair(pair, "command-kick") end
    local lines = { "[tp-target-reconcile-0652] enabled=" .. safe(r.enabled) .. " reconciled=" .. safe(r.stats["movement-target-reconciled-0652"] or 0) }
    if pair then
      local lock = lock_active(pair)
      local req = pair.movement_request_0418
      lines[#lines + 1] = "  station=" .. safe(station_unit(pair)) .. " mode=" .. safe(pair.mode) .. " pair_target=" .. safe(pair.target and pair.target.valid and pair.target.name or "none") .. " lock=" .. safe(lock and ((lock.name or lock.entity.name) .. "@" .. string.format("%.1f,%.1f", lock.position.x, lock.position.y)) or "none") .. " req=" .. safe(req and (safe(req.owner) .. "@" .. string.format("%.1f,%.1f", req.x or 0, req.y or 0)) or "none")
    else lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest" end
    if p == "recent" or p == "kick" then for i = math.max(1, #r.recent - 10), #r.recent do local ev = r.recent[i]; if ev then lines[#lines + 1] = "  [" .. safe(ev.tick) .. "] " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail) end end end
    if player and player.valid then for _, line in ipairs(lines) do player.print(line) end elseif game and game.print then for _, line in ipairs(lines) do game.print(line) end end
  end)
end

function M.install()
  root()
  wrap_movement_request()
  install_command()
  _G.TechPriestsMovementTargetReconciler0652 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "movement_target_reconciler_0652", category = "movement", interval = M.tick_interval, priority = 34, budget = 8, fn = function(event, budget) M.service_all("broker") return true end, note = "make active direct acquisition target override stale station/arbiter movement requests" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "movement_target_reconciler_0652", category = "movement", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.652] movement target reconciler installed; direct acquisition locks now override stale station/arbiter movement targets") end
  return true
end

return M
