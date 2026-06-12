-- scripts/core/movement_intent_authority_0654.lua
-- Tech Priests 0.1.654
--
-- Commandless movement intent authority.
--
-- The 0.1.651 logs showed the exact fight: direct acquisition locked a real
-- resource entity, while the movement vector enforcer corrected toward an older
-- action-arbiter request.  This module makes the active work target the movement
-- truth.  If a priest is acquiring a physical resource, the movement request,
-- pair.target, and visible intent target all point at that resource.

local M = {}
M.version = "0.1.654"
M.storage_key = "movement_intent_authority_0654"
M.tick_interval = 5
M.max_pairs_per_pulse = 48
M.request_ttl = 60 * 8
M.request_radius = 0.75
M.command_refresh_ticks = 15
M.close_distance_sq = 2.25
M.log_interval = 300

local pre_request = nil
local pre_route = nil

local DIRECT_KINDS = { ["direct-mine-0273"] = true, ["direct-dirt-0273"] = true, ["direct-mine-0336"] = true, dirt = true }

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
local function same_pos(a, b, eps) return a and b and dist_sq(a, b) <= ((eps or 0.55) * (eps or 0.55)) end

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
  while #r.recent > 120 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.654] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function movement_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419 = storage.tech_priests.movement_controller_0419 or { requests = {}, active_request_ids = {}, stats = {} }
  local r = storage.tech_priests.movement_controller_0419
  r.requests = r.requests or {}; r.active_request_ids = r.active_request_ids or {}; r.stats = r.stats or {}
  return r
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
local function current_direct_task(pair)
  local Exec = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
  if Exec and type(Exec.current_direct_task) == "function" then local ok, task, cur, key = pcall(Exec.current_direct_task, pair); if ok then return task, cur, key end end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair and pair[key]; local cur = type(task) == "table" and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end
local function output_item(task, cur)
  return (cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item)) or (task and (task.output_item or task.item_name or task.wanted_item or task.requested_item))
end

local function lock_truth(pair)
  local lock = pair and pair.direct_acquisition_target_lock_0650 or nil
  if lock and valid(lock.entity) and lock.position and lock.position.x and lock.position.y then
    local phase = pair.dispatcher_direct_0513 and tostring(pair.dispatcher_direct_0513.phase or "") or ""
    if phase ~= "complete" and phase ~= "return-for-craft" and phase ~= "return-to-station" then
      return { entity = lock.entity, position = { x = lock.position.x, y = lock.position.y }, item = lock.item, name = lock.name or lock.entity.name, source = "direct-lock-0650" }
    end
  end
  local task, cur = current_direct_task(pair)
  if cur and DIRECT_KINDS[tostring(cur.kind or "")] then
    local e = target_entity(cur); local pos = target_position(cur)
    if valid(e) and pos then return { entity = e, position = { x = pos.x, y = pos.y }, item = output_item(task, cur), name = e.name, source = "direct-task" } end
  end
  return nil
end

local function request_points_to_truth(req, truth)
  return req and truth and truth.position and req.x and req.y and same_pos(req, truth.position, 0.55) and lower(req.owner):find("direct", 1, true)
end

local function make_request(pair, truth)
  local req = {
    x = truth.position.x,
    y = truth.position.y,
    radius = M.request_radius,
    reason = "direct-acquisition-intent-0654",
    owner = "direct-acquisition-intent-0654",
    priority = 990,
    distraction = defines and defines.distraction and defines.distraction.none or nil,
    issued_tick = now(),
    updated_tick = now(),
    expires_tick = now() + M.request_ttl,
    last_command_tick = 0,
    last_distance_sq = nil,
    target_name = truth.name,
    target_unit = valid(truth.entity) and truth.entity.unit_number or nil,
    item = truth.item,
    movement_truth_0654 = true,
  }
  return req
end

local function install_request(pair, truth, reason)
  local mr = movement_root(); local key = pair_key(pair)
  if not key then return nil end
  local old = pair.movement_request_0418 or mr.requests[key]
  if request_points_to_truth(old, truth) then
    old.updated_tick = now(); old.expires_tick = now() + M.request_ttl
    pair.movement_request_0418 = old; mr.requests[key] = old; mr.active_request_ids[key] = true
    return old, false, old.owner
  end
  local req = make_request(pair, truth)
  mr.requests[key] = req; mr.active_request_ids[key] = true
  pair.movement_request_0418 = req
  pair.movement_controller_owner_0418 = req.owner
  pair.movement_controller_reason_0418 = req.reason
  pair.movement_controller_clamp_0418 = nil
  pair.movement_controller_state_0418 = "direct-intent-authoritative-0654"
  pair.target = truth.entity
  pair.current_target = truth.entity
  pair.current_work_target_0654 = truth.entity
  pair.movement_intent_target_0654 = { tick = now(), source = truth.source, item = truth.item, name = truth.name, x = truth.position.x, y = truth.position.y, previous_owner = old and old.owner, previous_x = old and old.x, previous_y = old and old.y, reason = reason or "reconcile" }
  record("movement-intent-reconciled-0654", pair, "item=" .. safe(truth.item) .. " target=" .. safe(truth.name) .. " pos=" .. string.format("%.1f,%.1f", truth.position.x, truth.position.y) .. " old_owner=" .. safe(old and old.owner) .. " old=" .. safe(old and old.x and string.format("%.1f,%.1f", old.x, old.y) or "nil"), true)
  return req, true, old and old.owner
end

local function issue_command(pair, req, reason)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  if dist_sq(pair.priest.position, req) <= M.close_distance_sq then return false end
  local last = pair.movement_intent_authority_0654_last_command
  if last and now() - (tonumber(last.tick) or 0) < M.command_refresh_ticks then return false end
  local command = { type = defines.command.go_to_location, destination = { x = req.x, y = req.y }, radius = req.radius or M.request_radius, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok = true end end)
  pcall(function() if not ok and pair.priest.set_command then pair.priest.set_command(command); ok = true end end)
  if ok then
    req.last_command_tick = now()
    pair.movement_controller_last_command_0418 = { tick = now(), x = req.x, y = req.y, reason = req.reason }
    pair.movement_intent_authority_0654_last_command = { tick = now(), x = req.x, y = req.y, reason = reason or "intent" }
    record("movement-intent-commanded-0654", pair, "target=" .. string.format("%.1f,%.1f", req.x, req.y) .. " reason=" .. safe(reason), false)
  end
  return ok
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  local truth = lock_truth(pair)
  if not truth then return false end
  local req, changed = install_request(pair, truth, reason or "service")
  if req then issue_command(pair, req, reason or "service") end
  return changed == true
end

local function request_exempt(reason, opts)
  local s = lower(reason) .. " " .. lower(opts and opts.owner or "")
  return s:find("combat", 1, true) or s:find("death", 1, true) or s:find("respawn", 1, true) or s:find("void", 1, true) or s:find("return%-to%-station", 1, false)
end
local function destination_points_to_truth(destination, truth)
  if not (destination and truth and truth.position) then return false end
  if valid(destination) and destination.position then return same_pos(destination.position, truth.position, 0.55) end
  if destination.position then return same_pos(destination.position, truth.position, 0.55) end
  if destination.x and destination.y then return same_pos(destination, truth.position, 0.55) end
  return false
end

local function wrap_request()
  if pre_request or type(rawget(_G, "tech_priests_request_movement_0418")) ~= "function" then return false end
  pre_request = rawget(_G, "tech_priests_request_movement_0418")
  _G.TECH_PRIESTS_0654_PRE_REQUEST_MOVEMENT_0418 = pre_request
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts, ...)
    local truth = root().enabled ~= false and lock_truth(pair) or nil
    if truth and not destination_points_to_truth(destination, truth) and not request_exempt(reason, opts) then
      local req = install_request(pair, truth, "request-redirect-0654")
      if req then issue_command(pair, req, "request-redirect-0654") end
      return true, req
    end
    return pre_request(pair, destination, reason, opts, ...)
  end
  return true
end

local function wrap_route()
  local MC = rawget(_G, "TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
  if not (MC and type(MC.route_command) == "function") or pre_route then return false end
  pre_route = MC.route_command
  MC.TECH_PRIESTS_0654_PRE_ROUTE_COMMAND = pre_route
  MC.route_command = function(priest, command, owner, opts, ...)
    local pair = opts and opts.pair or nil
    if not pair and priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then pair = storage.tech_priests.pairs_by_priest[priest.unit_number] end
    local truth = root().enabled ~= false and lock_truth(pair) or nil
    if truth and command and defines and command.type == defines.command.go_to_location and command.destination and not destination_points_to_truth(command.destination, truth) and not request_exempt(owner, opts) then
      local req = install_request(pair, truth, "route-redirect-0654")
      if req then issue_command(pair, req, "route-redirect-0654") end
      return true
    end
    return pre_route(priest, command, owner, opts, ...)
  end
  return true
end

function M.service_all(reason)
  wrap_request(); wrap_route()
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end
  end
  return n
end

function M.install()
  root(); wrap_request(); wrap_route(); _G.TechPriestsMovementIntentAuthority0654 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "movement_intent_authority_0654", category = "movement", interval = M.tick_interval, priority = 32, budget = 10, fn = function(event, budget) M.service_all("broker"); return true end, note = "make active work target the movement/debug-line truth before vector correction" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "movement_intent_authority_0654", category = "movement", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.654] movement intent authority installed; direct acquisition target now owns movement request and visible intent target") end
  return true
end

return M
