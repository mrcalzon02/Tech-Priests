-- scripts/core/movement_vector_enforcer_0651.lua
-- Tech Priests 0.1.651
--
-- Movement vector enforcer.
--
-- The movement controller submits go_to_location intent and periodically refreshes
-- commands, but Factorio unit movement can drift, circle, or wander away from
-- the intended target.  This module samples active movement requests and enforces
-- a hard contract: a ground Tech-Priest with an active movement target must be
-- reducing distance toward that target, or it is stopped/re-commanded.  If it
-- keeps moving the wrong way after correction, it is nudged a small bounded step
-- toward the target rather than being allowed to wander in the opposite direction.

local M = {}
M.version = "0.1.651"
M.storage_key = "movement_vector_enforcer_0651"
M.tick_interval = 7
M.max_pairs_per_pulse = 40
M.sample_ticks = 7
M.away_distance_epsilon = 0.18
M.sideways_dot_epsilon = -0.02
M.force_command_cooldown = 20
M.nudge_after_bad_samples = 3
M.nudge_step = 0.85
M.close_distance_sq = 2.25
M.log_interval = 360

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx = (a.x or 0) - (b.x or 0); local dy = (a.y or 0) - (b.y or 0); return dx * dx + dy * dy end
local function dist(a, b) return math.sqrt(dist_sq(a, b)) end
local function pair_key(pair) local su = station_unit(pair); if su then return tostring(su) end local pu = priest_unit(pair); if pu then return "p" .. tostring(pu) end return nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, audit_only = false, stats = {}, recent = {}, samples = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.audit_only == nil then r.audit_only = false end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.samples = r.samples or {}
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
    if log then log("[Tech-Priests 0.1.651] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function is_space_pair(pair)
  if type(_G.tech_priests_pair_on_space_platform_0204) == "function" then local ok, yes = pcall(_G.tech_priests_pair_on_space_platform_0204, pair); if ok and yes then return true end end
  return false
end

local function active_request(pair)
  if not valid_pair(pair) then return nil end
  local req = pair.movement_request_0418
  if req and req.x and req.y and (not req.expires_tick or req.expires_tick >= now()) then return req end
  local MC = rawget(_G, "TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
  local key = pair_key(pair)
  local r = storage and storage.tech_priests and storage.tech_priests.movement_controller_0419
  if key and r and r.requests and r.requests[key] and r.requests[key].x and r.requests[key].y and (not r.requests[key].expires_tick or r.requests[key].expires_tick >= now()) then return r.requests[key] end
  return nil
end

local function clamp_reason(pair)
  if not pair then return "invalid" end
  if pair.movement_controller_clamp_0418 and pair.movement_controller_clamp_0418 ~= "retarget-held" and pair.movement_controller_clamp_0418 ~= "task-transition-retarget-held" then return pair.movement_controller_clamp_0418 end
  if pair.mining_lock_0315 then return "mining-lock" end
  if pair.station_craft_lock_0337 then return "station-craft-lock" end
  if pair.crafting_lock_0418 then return "crafting-lock" end
  if pair.idle_conversation or pair.idle_conversation_listener_until and now() < pair.idle_conversation_listener_until then return "conversation" end
  return nil
end

local function direct_stop(pair, reason)
  if not valid_pair(pair) then return false end
  local ok_any = false
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command({ type = defines.command.stop }); ok_any = true end
  end)
  pcall(function() if pair.priest.set_command then pair.priest.set_command({ type = defines.command.stop }); ok_any = true end end)
  pcall(function() pair.priest.walking_state = { walking = false }; ok_any = true end)
  pair.movement_vector_enforcer_0651_last_stop = { tick = now(), reason = reason or "stop" }
  return ok_any
end

local function direct_go_to(pair, req, reason)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  local command = { type = defines.command.go_to_location, destination = { x = req.x, y = req.y }, radius = tonumber(req.radius) or 0.75, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok_any = false
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok_any = true end
  end)
  pcall(function() if not ok_any and pair.priest.set_command then pair.priest.set_command(command); ok_any = true end end)
  if ok_any then
    req.last_command_tick = now()
    pair.movement_controller_state_0418 = "vector-corrected-moving"
    pair.movement_controller_clamp_0418 = nil
    pair.movement_vector_enforcer_0651_last_command = { tick = now(), x = req.x, y = req.y, reason = reason or "correct" }
  end
  return ok_any
end

local function nudge_toward(pair, req, reason)
  if not (valid_pair(pair) and req and req.x and req.y and pair.priest.teleport) then return false end
  local pos = pair.priest.position
  local dx = (req.x or 0) - (pos.x or 0)
  local dy = (req.y or 0) - (pos.y or 0)
  local len = math.sqrt(dx * dx + dy * dy)
  if len <= 0.001 then return false end
  local step = math.min(M.nudge_step, math.max(0.2, len * 0.35))
  local new_pos = { x = pos.x + dx / len * step, y = pos.y + dy / len * step }
  local ok = false
  pcall(function() ok = pair.priest.teleport(new_pos) == true end)
  if ok then
    pair.movement_controller_state_0418 = "vector-nudged-toward-target"
    pair.movement_vector_enforcer_0651_last_nudge = { tick = now(), from = { x = pos.x, y = pos.y }, to = new_pos, target = { x = req.x, y = req.y }, reason = reason or "nudge" }
    record("movement-vector-nudged-0651", pair, "from=" .. string.format("%.1f,%.1f", pos.x, pos.y) .. " to=" .. string.format("%.1f,%.1f", new_pos.x, new_pos.y) .. " target=" .. string.format("%.1f,%.1f", req.x, req.y) .. " reason=" .. safe(reason), true)
    return true
  end
  return false
end

local function dot_progress(prev, cur, req)
  local mvx = (cur.x or 0) - (prev.x or 0)
  local mvy = (cur.y or 0) - (prev.y or 0)
  local tx = (req.x or 0) - (prev.x or 0)
  local ty = (req.y or 0) - (prev.y or 0)
  local mlen = math.sqrt(mvx * mvx + mvy * mvy)
  local tlen = math.sqrt(tx * tx + ty * ty)
  if mlen < 0.015 or tlen < 0.015 then return 0, mlen, tlen end
  return (mvx * tx + mvy * ty) / (mlen * tlen), mlen, tlen
end

local function should_enforce_request(req)
  if not req then return false end
  local owner = lower(req.owner or req.reason or "")
  -- Enforce all intentional movement, but be most aggressive for acquisition and
  -- construction. Return/home movement also benefits from not wandering away.
  return owner ~= "" or req.reason ~= nil
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) or is_space_pair(pair) then return false, "invalid-or-space" end
  local req = active_request(pair)
  local key = pair_key(pair)
  if not (key and req and should_enforce_request(req)) then
    r.samples[key or "?"] = nil
    return false, "no-active-request"
  end
  local close = dist_sq(pair.priest.position, req) <= M.close_distance_sq
  if close then
    r.samples[key] = { tick = now(), x = pair.priest.position.x, y = pair.priest.position.y, req_x = req.x, req_y = req.y, distance = dist(pair.priest.position, req), bad = 0 }
    return false, "close"
  end
  local clamp = clamp_reason(pair)
  if clamp then
    record("movement-vector-clamped-0651", pair, "clamp=" .. safe(clamp) .. " target=" .. string.format("%.1f,%.1f", req.x, req.y), false)
    return false, "clamped"
  end

  local pos = pair.priest.position
  local prev = r.samples[key]
  local current_distance = dist(pos, req)
  if not prev or prev.req_x ~= req.x or prev.req_y ~= req.y or now() - (tonumber(prev.tick) or 0) > 90 then
    r.samples[key] = { tick = now(), x = pos.x, y = pos.y, req_x = req.x, req_y = req.y, distance = current_distance, bad = 0 }
    return false, "sample-start"
  end
  local dt = now() - (tonumber(prev.tick) or now())
  if dt < M.sample_ticks then return false, "sample-wait" end

  local dot, moved, target_len = dot_progress(prev, pos, req)
  local delta_distance = current_distance - (tonumber(prev.distance) or current_distance)
  local moving_away = delta_distance > M.away_distance_epsilon
  local wrong_vector = moved > 0.04 and dot < M.sideways_dot_epsilon
  local bad = (moving_away or wrong_vector) and ((tonumber(prev.bad) or 0) + 1) or 0
  r.samples[key] = { tick = now(), x = pos.x, y = pos.y, req_x = req.x, req_y = req.y, distance = current_distance, bad = bad, dot = dot, moved = moved, delta = delta_distance }

  if bad <= 0 then return false, "progress-ok" end

  local detail = "target=" .. string.format("%.1f,%.1f", req.x, req.y)
    .. " dist=" .. string.format("%.2f", current_distance)
    .. " delta=" .. string.format("%.2f", delta_distance)
    .. " dot=" .. string.format("%.2f", dot)
    .. " moved=" .. string.format("%.2f", moved)
    .. " bad=" .. safe(bad)
    .. " owner=" .. safe(req.owner or req.reason)

  if r.audit_only == true then
    record("movement-vector-wrong-audit-0651", pair, detail, true)
    return false, "audit-only"
  end

  local cooldown_ok = (not pair.movement_vector_enforcer_0651_last_command) or now() - (tonumber(pair.movement_vector_enforcer_0651_last_command.tick) or 0) >= M.force_command_cooldown
  if cooldown_ok then
    direct_stop(pair, "wrong-vector-0651")
    if direct_go_to(pair, req, "wrong-vector-0651") then
      record("movement-vector-corrected-0651", pair, detail, true)
    else
      record("movement-vector-correction-failed-0651", pair, detail, true)
    end
  end
  if bad >= M.nudge_after_bad_samples then
    nudge_toward(pair, req, "persistent-wrong-vector-0651")
    r.samples[key].bad = 0
  end
  return true, "corrected"
end

function M.service_all(reason)
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if valid_pair(pair) then
      local ok, acted = pcall(M.service_pair, pair, reason or "pulse")
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
  pcall(function() if commands.remove_command then commands.remove_command("tp-movement-vector-0651") end end)
  commands.add_command("tp-movement-vector-0651", "Tech Priests 0.1.651: enforce movement direction toward active target. Params: status/kick/all/on/off/audit-on/audit-off/recent", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "audit-on" then r.audit_only = true elseif p == "audit-off" then r.audit_only = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "kick" and pair then M.service_pair(pair, "command-kick") end
    local lines = { "[tp-movement-vector-0651] enabled=" .. safe(r.enabled) .. " audit=" .. safe(r.audit_only) .. " corrected=" .. safe(r.stats["movement-vector-corrected-0651"] or 0) .. " nudged=" .. safe(r.stats["movement-vector-nudged-0651"] or 0) .. " failed=" .. safe(r.stats["movement-vector-correction-failed-0651"] or 0) }
    if pair then
      local req = active_request(pair)
      local key = pair_key(pair)
      local s = key and r.samples[key] or nil
      lines[#lines + 1] = "  station=" .. safe(station_unit(pair)) .. " mode=" .. safe(pair.mode) .. " state=" .. safe(pair.movement_controller_state_0418) .. " target=" .. safe(req and (string.format("%.1f,%.1f", req.x, req.y)) or "none") .. " sample_delta=" .. safe(s and s.delta) .. " dot=" .. safe(s and s.dot) .. " bad=" .. safe(s and s.bad)
    else lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest" end
    if p == "recent" or p == "kick" then for i = math.max(1, #r.recent - 10), #r.recent do local ev = r.recent[i]; if ev then lines[#lines + 1] = "  [" .. safe(ev.tick) .. "] " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " " .. safe(ev.detail) end end end
    if player and player.valid then for _, line in ipairs(lines) do player.print(line) end elseif game and game.print then for _, line in ipairs(lines) do game.print(line) end end
  end)
end

function M.install()
  root()
  install_command()
  _G.TechPriestsMovementVectorEnforcer0651 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "movement_vector_enforcer_0651", category = "movement", interval = M.tick_interval, priority = 38, budget = 8, fn = function(event, budget) M.service_all("broker") return true end, note = "detect and correct priests moving away from active movement targets" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "movement_vector_enforcer_0651", category = "movement", priority = "early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.651] movement vector enforcer installed; active movement targets require positive progress or correction/nudge") end
  return true
end

return M
