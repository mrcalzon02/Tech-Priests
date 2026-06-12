-- scripts/core/active_leaf_task_truth_0655.lua
-- Tech Priests 0.1.655
--
-- Commandless active leaf task truth authority.
--
-- Parent orders may say "make iron plate" or "consecrate this machine", but
-- the priest overhead and movement vector must describe and obey the concrete
-- leaf action currently underway: walk to this machine, fetch this item source,
-- mine this ore/rock, or perform this rite.  This module publishes that leaf
-- truth to pair.active_leaf_task_0655, overwrites stale movement requests that
-- point somewhere else, and patches the one-slot overhead status governor to
-- prefer the leaf task over broad parent-order text.

local M = {}
M.version = "0.1.655"
M.storage_key = "active_leaf_task_truth_0655"
M.tick_interval = 5
M.max_pairs_per_pulse = 56
M.ttl = 60 * 8
M.default_radius = 0.85
M.command_cooldown = 18
M.close_distance_sq = 2.25
M.log_interval = 300

local pre_request = nil
local pre_route = nil
local overhead_patched = false

local DIRECT_KINDS = { ["direct-mine-0273"] = true, ["direct-dirt-0273"] = true, ["direct-mine-0336"] = true, dirt = true }
local TERMINAL_PHASE = { none = true, complete = true, completed = true, done = true, idle = true, ["return-to-station"] = true, ["return-for-craft"] = true }

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
local function clean_item(name) name = tostring(name or ""); if name == "" or name == "nil" then return nil end return (name:gsub("%-", " ")) end
local function entity_label(e) if not valid(e) then return nil end return clean_item(e.name) or safe(e.name) end

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
  while #r.recent > 140 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.655] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function movement_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.movement_controller_0419 = storage.tech_priests.movement_controller_0419 or { requests = {}, active_request_ids = {}, stats = {} }
  local r = storage.tech_priests.movement_controller_0419
  r.requests = r.requests or {}; r.active_request_ids = r.active_request_ids or {}; r.stats = r.stats or {}
  return r
end
local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  local cur = v.current or v.request or v.task or v
  return cur.output_item or cur.item_name or cur.item or cur.name or cur.wanted_item or cur.requested_item or cur.target_item or cur.resource
end
local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return (q and q.current) or (pair and pair.active_order_0469) or nil
end
local function order_item(pair) return item_from(current_order(pair)) end
local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  if valid(cur) then return cur end
  return nil
end
local function target_position(cur)
  local e = target_entity(cur)
  if e then return e.position end
  if cur and cur.position and cur.position.x and cur.position.y then return cur.position end
  if cur and cur.x and cur.y then return cur end
  return nil
end
local function truth_from_entity(pair, family, phase, entity, item, label, opts)
  opts = opts or {}
  if not (valid_pair(pair) and valid(entity)) then return nil end
  local pos = entity.position
  return { family = family, phase = phase, entity = entity, position = { x = pos.x, y = pos.y }, item = item, parent_item = opts.parent_item or order_item(pair), label = label, owner = "leaf-task-truth-0655", priority = tonumber(opts.priority) or 965, radius = tonumber(opts.radius) or M.default_radius, color = opts.color, can_move = opts.can_move ~= false, source = opts.source }
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
local function direct_truth(pair)
  local lock = pair and pair.direct_acquisition_target_lock_0650 or nil
  if lock and valid(lock.entity) and lock.position and lock.position.x and lock.position.y then
    local item = lock.item or item_from(pair and pair.emergency_craft) or item_from(pair and pair.direct_acquisition_task_0336)
    local label = "Mining " .. (clean_item(item) or entity_label(lock.entity) or "field resource")
    return { family="acquisition", phase="mine-resource", entity=lock.entity, position={x=lock.position.x,y=lock.position.y}, item=item, parent_item=order_item(pair), label=label, owner="leaf-task-truth-0655", priority=990, radius=0.75, can_move=true, source="direct-lock-0650" }
  end
  local task, cur = current_direct_task(pair)
  local e = target_entity(cur); local pos = target_position(cur)
  if cur and DIRECT_KINDS[tostring(cur.kind or "")] and e and pos then
    local item = item_from(cur) or item_from(task)
    return truth_from_entity(pair, "acquisition", "mine-resource", e, item, "Mining " .. (clean_item(item) or entity_label(e) or "field resource"), { priority = 985, radius = 0.75, source = "direct-task" })
  end
  return nil
end
local function consecration_truth(pair)
  local state = pair and pair.consecration_0515
  local phase = lower(state and state.phase or "")
  local target = valid(state and state.target) and state.target or nil
  if not target and lower(pair and pair.mode):find("consecr", 1, true) and valid(pair and pair.target) then target = pair.target end
  if not target then return nil end
  if TERMINAL_PHASE[phase] then return nil end
  local item = (state and state.item) or "consecration rite"
  local reach = tonumber(rawget(_G, "PRIEST_CONSECRATION_REACH_DISTANCE_SQ")) or 16
  local d2 = valid_pair(pair) and dist_sq(pair.priest.position, target.position) or 999999
  local walking = d2 > reach
  local label = (walking and "Walking to consecrate " or "Consecrating ") .. (entity_label(target) or "machine")
  return truth_from_entity(pair, "consecration", walking and "walk-to-target" or "perform-rite", target, item, label, { priority = 970, radius = 1.25, color = { r = 0.60, g = 1.0, b = 0.95, a = 0.95 }, source = "consecration_0515" })
end
local function logistics_truth(pair)
  local f = pair and (pair.logistics_fetch_0527 or pair.logistics_fetch_0526)
  if type(f) ~= "table" or f.phase ~= "moving-to-source" or not valid(f.source) then return nil end
  local item = f.item or f.item_name or order_item(pair)
  local label = "Fetching " .. (clean_item(item) or "supplies") .. " from " .. (entity_label(f.source) or "known source")
  return truth_from_entity(pair, "logistics", "fetch-source", f.source, item, label, { priority = 955, radius = 1.15, color = { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, source = "logistics_fetch_0527" })
end
local function emergency_truth(pair)
  local task = pair and pair.emergency_craft
  local cur = type(task) == "table" and (task.current or task) or nil
  local e = target_entity(cur); local item = item_from(cur) or item_from(task)
  if e then
    local kind = tostring(cur.kind or "")
    local action = DIRECT_KINDS[kind] and "Mining " or "Working on "
    return truth_from_entity(pair, "emergency", kind ~= "" and kind or "work", e, item, action .. (clean_item(item) or entity_label(e) or "materials"), { priority = 945, radius = 0.85, source = "emergency_craft" })
  end
  return nil
end

function M.truth(pair)
  if not valid_pair(pair) then return nil end
  return direct_truth(pair) or consecration_truth(pair) or logistics_truth(pair) or emergency_truth(pair)
end
local function request_matches(req, truth) return req and truth and req.x and req.y and same_pos(req, truth.position, 0.55) and tonumber(req.priority or 0) >= tonumber(truth.priority or 0) - 5 end
local function publish(pair, truth, changed)
  pair.active_leaf_task_0655 = { version = M.version, tick = now(), family = truth.family, phase = truth.phase, item = truth.item, parent_item = truth.parent_item, label = truth.label, target_name = valid(truth.entity) and truth.entity.name or nil, target_unit = valid(truth.entity) and truth.entity.unit_number or nil, x = truth.position.x, y = truth.position.y, source = truth.source, changed = changed == true }
  pair.actual_task_status_0655 = pair.active_leaf_task_0655
  pair.current_work_target_0655 = truth.entity
  pair.target = truth.entity
end
local function install_request(pair, truth, reason)
  if not (truth and truth.can_move ~= false) then return nil, false end
  local key = pair_key(pair); if not key then return nil, false end
  local mr = movement_root(); local old = pair.movement_request_0418 or mr.requests[key]
  if request_matches(old, truth) then
    old.updated_tick = now(); old.expires_tick = now() + M.ttl; old.owner = old.owner or truth.owner; old.reason = old.reason or truth.family
    pair.movement_request_0418 = old; mr.requests[key] = old; mr.active_request_ids[key] = true; publish(pair, truth, false); return old, false
  end
  local req = { x = truth.position.x, y = truth.position.y, radius = truth.radius or M.default_radius, reason = truth.family .. "-leaf-task-0655", owner = truth.owner, priority = truth.priority or 965, distraction = defines and defines.distraction and defines.distraction.none or nil, issued_tick = now(), updated_tick = now(), expires_tick = now() + M.ttl, last_command_tick = 0, last_distance_sq = nil, item = truth.item, target_name = valid(truth.entity) and truth.entity.name or nil, target_unit = valid(truth.entity) and truth.entity.unit_number or nil, leaf_task_truth_0655 = true }
  mr.requests[key] = req; mr.active_request_ids[key] = true
  pair.movement_request_0418 = req; pair.movement_controller_owner_0418 = req.owner; pair.movement_controller_reason_0418 = req.reason; pair.movement_controller_clamp_0418 = nil; pair.movement_controller_state_0418 = "leaf-task-authoritative-0655"
  publish(pair, truth, true)
  record("leaf-task-movement-reconciled-0655", pair, "label=" .. safe(truth.label) .. " target=" .. safe(req.target_name) .. " pos=" .. string.format("%.1f,%.1f", req.x, req.y) .. " old_owner=" .. safe(old and old.owner), true)
  return req, true
end
local function issue_command(pair, req, reason)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  if dist_sq(pair.priest.position, req) <= M.close_distance_sq then return false end
  local last = pair.leaf_task_truth_0655_last_command
  if last and now() - (tonumber(last.tick) or 0) < M.command_cooldown then return false end
  local command = { type = defines.command.go_to_location, destination = { x = req.x, y = req.y }, radius = req.radius or M.default_radius, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok = true end end)
  pcall(function() if not ok and pair.priest.set_command then pair.priest.set_command(command); ok = true end end)
  if ok then req.last_command_tick = now(); pair.leaf_task_truth_0655_last_command = { tick = now(), x = req.x, y = req.y, reason = reason or "leaf-task" } end
  return ok
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  local truth = M.truth(pair)
  if not truth then return false end
  local req, changed = install_request(pair, truth, reason or "service")
  if req then issue_command(pair, req, reason or "service") end
  return changed == true
end
local function destination_points_to_truth(destination, truth)
  if not (destination and truth and truth.position) then return false end
  if valid(destination) and destination.position then return same_pos(destination.position, truth.position, 0.55) end
  if destination.position then return same_pos(destination.position, truth.position, 0.55) end
  if destination.x and destination.y then return same_pos(destination, truth.position, 0.55) end
  return false
end
local function exempt(reason, opts)
  local s = lower(reason) .. " " .. lower(opts and opts.owner or "")
  return s:find("combat", 1, true) or s:find("death", 1, true) or s:find("respawn", 1, true) or s:find("void", 1, true) or s:find("return%-to%-station", 1, false)
end
local function wrap_request()
  if pre_request or type(rawget(_G, "tech_priests_request_movement_0418")) ~= "function" then return false end
  pre_request = rawget(_G, "tech_priests_request_movement_0418")
  _G.TECH_PRIESTS_0655_PRE_REQUEST_MOVEMENT_0418 = pre_request
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts, ...)
    local truth = root().enabled ~= false and M.truth(pair) or nil
    if truth and truth.can_move ~= false and not destination_points_to_truth(destination, truth) and not exempt(reason, opts) then
      local req = install_request(pair, truth, "request-redirect-0655")
      if req then issue_command(pair, req, "request-redirect-0655") end
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
  MC.TECH_PRIESTS_0655_PRE_ROUTE_COMMAND = pre_route
  MC.route_command = function(priest, command, owner, opts, ...)
    local pair = opts and opts.pair or nil
    if not pair and priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then pair = storage.tech_priests.pairs_by_priest[priest.unit_number] end
    local truth = root().enabled ~= false and M.truth(pair) or nil
    if truth and command and defines and command.type == defines.command.go_to_location and command.destination and not destination_points_to_truth(command.destination, truth) and not exempt(owner, opts) then
      local req = install_request(pair, truth, "route-redirect-0655")
      if req then issue_command(pair, req, "route-redirect-0655") end
      return true
    end
    return pre_route(priest, command, owner, opts, ...)
  end
  return true
end

function M.leaf_status(pair)
  local leaf = pair and pair.active_leaf_task_0655
  if type(leaf) ~= "table" or not leaf.label or now() - (tonumber(leaf.tick) or 0) > 180 then return nil, nil end
  if leaf.family == "consecration" then return leaf.label, { r = 0.60, g = 1.0, b = 0.95, a = 0.95 } end
  if leaf.family == "acquisition" then return leaf.label, { r = 0.98, g = 0.72, b = 0.22, a = 0.95 } end
  if leaf.family == "logistics" then return leaf.label, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 } end
  return leaf.label, { r = 1.0, g = 0.74, b = 0.24, a = 0.95 }
end
local function patch_overhead()
  if overhead_patched then return true end
  local O = rawget(_G, "TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")
  if not (O and type(O.canonical_status) == "function") then return false end
  local prev = O.canonical_status
  O.TECH_PRIESTS_0655_PRE_CANONICAL_STATUS = prev
  O.canonical_status = function(pair, incoming_text, ...)
    local text, color = M.leaf_status(pair)
    if text then return text, color end
    return prev(pair, incoming_text, ...)
  end
  overhead_patched = true
  if log then log("[Tech-Priests 0.1.655] overhead status governor patched to prefer active leaf task truth") end
  return true
end

function M.service_all(reason)
  wrap_request(); wrap_route(); patch_overhead()
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end end
  return n
end

function M.install()
  root(); wrap_request(); wrap_route(); patch_overhead(); _G.TechPriestsActiveLeafTaskTruth0655 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name = "active_leaf_task_truth_0655", category = "movement", interval = M.tick_interval, priority = 31, budget = 12, fn = function(event, budget) M.service_all("broker"); return true end, note = "active leaf task owns movement request and overhead text" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "active_leaf_task_truth_0655", category = "movement", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.655] active leaf task truth authority installed") end
  return true
end

return M
