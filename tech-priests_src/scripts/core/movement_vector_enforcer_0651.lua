-- scripts/core/movement_vector_enforcer_0651.lua
-- Tech Priests 0.1.653
-- Commandless movement vector enforcer.

local M = {}
M.version = "0.1.653"
M.storage_key = "movement_vector_enforcer_0651"
M.tick_interval = 7
M.max_pairs_per_pulse = 40
M.sample_ticks = 7
M.away_distance_epsilon = 0.18
M.sideways_dot_epsilon = -0.02
M.command_cooldown = 20
M.close_distance_sq = 2.25
M.log_interval = 360

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a, b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a, b) return math.sqrt(dist_sq(a, b)) end
local function pair_key(pair) local su = station_unit(pair); if su then return tostring(su) end local pu = priest_unit(pair); if pu then return "p" .. tostring(pu) end return nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, samples = {}, last_log = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.samples = r.samples or {}; r.last_log = r.last_log or {}
  return r
end

local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = root(); stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 80 do table.remove(r.recent, 1) end
  local key = ev.action .. ":" .. ev.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.653] " .. ev.action .. " station=" .. ev.station .. " priest=" .. ev.priest .. " " .. safe(detail)) end
  end
end

local function active_request(pair)
  local req = pair and pair.movement_request_0418
  if req and req.x and req.y and (not req.expires_tick or req.expires_tick >= now()) then return req end
  local key = pair_key(pair)
  local r = storage and storage.tech_priests and storage.tech_priests.movement_controller_0419
  if key and r and r.requests and r.requests[key] and r.requests[key].x and r.requests[key].y and (not r.requests[key].expires_tick or r.requests[key].expires_tick >= now()) then return r.requests[key] end
  return nil
end

local function dot_progress(prev, cur, req)
  local mvx=(cur.x or 0)-(prev.x or 0); local mvy=(cur.y or 0)-(prev.y or 0)
  local tx=(req.x or 0)-(prev.x or 0); local ty=(req.y or 0)-(prev.y or 0)
  local mlen=math.sqrt(mvx*mvx+mvy*mvy); local tlen=math.sqrt(tx*tx+ty*ty)
  if mlen < 0.015 or tlen < 0.015 then return 0, mlen end
  return (mvx*tx+mvy*ty)/(mlen*tlen), mlen
end

local function issue_go_to(pair, req)
  if not (valid_pair(pair) and req and req.x and req.y and defines and defines.command) then return false end
  local command = { type = defines.command.go_to_location, destination = { x=req.x, y=req.y }, radius = tonumber(req.radius) or 0.75, distraction = req.distraction or (defines.distraction and defines.distraction.none) }
  local ok_any = false
  pcall(function() if pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command(command); ok_any = true end end)
  pcall(function() if not ok_any and pair.priest.set_command then pair.priest.set_command(command); ok_any = true end end)
  if ok_any then
    req.last_command_tick = now()
    pair.movement_controller_state_0418 = "vector-corrected-moving"
    pair.movement_controller_clamp_0418 = nil
    pair.movement_vector_enforcer_0651_last_command = { tick = now(), x = req.x, y = req.y }
  end
  return ok_any
end

function M.service_pair(pair, reason)
  if root().enabled == false or not valid_pair(pair) then return false end
  local req = active_request(pair); local key = pair_key(pair)
  if not (key and req and (req.owner or req.reason)) then root().samples[key or "?"] = nil; return false end
  if dist_sq(pair.priest.position, req) <= M.close_distance_sq then root().samples[key] = { tick=now(), x=pair.priest.position.x, y=pair.priest.position.y, req_x=req.x, req_y=req.y, distance=dist(pair.priest.position, req), bad=0 }; return false end
  local r = root(); local pos = pair.priest.position; local prev = r.samples[key]; local current_distance = dist(pos, req)
  if not prev or prev.req_x ~= req.x or prev.req_y ~= req.y or now() - (tonumber(prev.tick) or 0) > 90 then r.samples[key] = { tick=now(), x=pos.x, y=pos.y, req_x=req.x, req_y=req.y, distance=current_distance, bad=0 }; return false end
  if now() - (tonumber(prev.tick) or now()) < M.sample_ticks then return false end
  local dot, moved = dot_progress(prev, pos, req)
  local delta = current_distance - (tonumber(prev.distance) or current_distance)
  local bad = (delta > M.away_distance_epsilon or (moved > 0.04 and dot < M.sideways_dot_epsilon)) and ((tonumber(prev.bad) or 0) + 1) or 0
  r.samples[key] = { tick=now(), x=pos.x, y=pos.y, req_x=req.x, req_y=req.y, distance=current_distance, bad=bad, dot=dot, moved=moved, delta=delta }
  if bad <= 0 then return false end
  if (not pair.movement_vector_enforcer_0651_last_command) or now() - (tonumber(pair.movement_vector_enforcer_0651_last_command.tick) or 0) >= M.command_cooldown then
    if issue_go_to(pair, req) then record("movement-vector-corrected-0651", pair, "target=" .. string.format("%.1f,%.1f", req.x, req.y) .. " delta=" .. string.format("%.2f", delta) .. " dot=" .. string.format("%.2f", dot), true) end
  end
  return true
end

function M.service_all(reason)
  local n = 0
  for _, pair in pairs(pair_map()) do if n >= M.max_pairs_per_pulse then break end if valid_pair(pair) then local ok, acted = pcall(M.service_pair, pair, reason or "pulse"); if ok and acted then n = n + 1 end end end
  return n
end

function M.install()
  root(); _G.TechPriestsMovementVectorEnforcer0651 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then broker.register_service({ name="movement_vector_enforcer_0651", category="movement", interval=M.tick_interval, priority=38, budget=8, fn=function(event, budget) M.service_all("broker"); return true end, note="detect and correct priests moving away from active movement targets" })
  else local R = rawget(_G, "TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner="movement_vector_enforcer_0651", category="movement", priority="early" }) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] movement vector enforcer installed") end
  return true
end

return M
