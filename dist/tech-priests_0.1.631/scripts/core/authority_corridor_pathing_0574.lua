-- scripts/core/authority_corridor_pathing_0574.lua
-- Tech Priests 0.1.574 Cogitator Corridor Pathing Guard.
--
-- Movement half of the authority-corridor model.  This module does not choose
-- work and does not complete work.  It guards the existing movement request
-- API so priests normally path only inside home station coverage; while carrying
-- a valid superior writ/order, subordinates may also path inside authorized
-- superior station spheres.  Long authorized moves can be decomposed into a
-- station-corridor waypoint instead of one wilderness path request.

local M = {}
M.version = "0.1.574"
M.storage_key = "authority_corridor_pathing_0574"

M.default_radius = 32
M.default_chunk = 36
M.log_interval = 900
M.service_interval = 113
M.chunk_radius = 1.2
M.return_reissue_ticks = 60 * 4

local pre_request = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a,b) local d2=dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      guard_movement = true,
      decompose_long_moves = true,
      return_on_unwrit_far_move = true,
      stats = {}, recent = {}, last_log = {}, last_return = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.guard_movement == nil then r.guard_movement = true end
  if r.decompose_long_moves == nil then r.decompose_long_moves = true end
  if r.return_on_unwrit_far_move == nil then r.return_on_unwrit_far_move = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}; r.last_return = r.last_return or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, pair, detail, force)
  local r=M.root(); action=tostring(action or "event")
  stat(action)
  local rec={tick=now(), action=action, station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent>96 do table.remove(r.recent,1) end
  local key=action..":"..safe(rec.station)
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.574] "..action.." station="..safe(rec.station).." priest="..safe(rec.priest).." "..safe(detail)) end
  end
  return rec
end

local function runtime_radius(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or nil
  if _G.refresh_pair_radius and pair then local ok, got = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(got) then r = tonumber(got) end end
  if (not r) and _G.get_station_operating_radius and valid(pair and pair.station) then local ok, got = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(got) then r = tonumber(got) end end
  return r or M.default_radius
end

local function is_return_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("return",1,true) or s:find("home",1,true) or s:find("overleash",1,true) or s:find("station",1,true)
end
local function is_recovery_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("recovery",1,true) or s:find("respawn",1,true) or s:find("pair%-link",1,false)
end
local function is_exempt_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  if is_return_reason(reason, opts) or is_recovery_reason(reason, opts) then return true end
  if s:find("combat",1,true) or s:find("retreat",1,true) or s:find("flee",1,true) then return true end
  if s:find("conversation",1,true) or s:find("approach%-player",1,false) then return true end
  if s:find("corridor%-waypoint%-0574",1,false) then return true end
  return false
end

local function authorized_pairs(pair)
  if type(_G.tech_priests_0573_authorized_pairs) == "function" then
    local ok, list, order, source = pcall(_G.tech_priests_0573_authorized_pairs, pair)
    if ok and type(list)=="table" and #list>0 then return list, order, source end
  end
  return valid_pair(pair) and {{pair=pair, role="home", station_unit=station_unit(pair)}} or {}, nil, "fallback-home"
end

local function station_rec_contains(rec, pos)
  local p = rec and rec.pair
  if not (valid_pair(p) and pos and p.station.surface == (pos.surface or p.station.surface)) then return false, nil, nil end
  local radius = runtime_radius(p)
  local d = dist(p.station.position, pos) or 0
  return d <= radius, d, radius
end

local function destination_surface(pair, pos)
  if pos and pos.surface then return pos.surface end
  return valid(pair and pair.station) and pair.station.surface or nil
end

function M.authorization_for_destination(pair, pos, reason, opts)
  if not (valid_pair(pair) and pos) then return true, nil, "invalid-or-no-pos" end
  if is_exempt_reason(reason, opts) then return true, {pair=pair, role="exempt", station_unit=station_unit(pair)}, "exempt" end
  local surface = destination_surface(pair, pos)
  local auth, order, source = authorized_pairs(pair)
  local best, best_d = nil, nil
  for _, rec in ipairs(auth or {}) do
    local p = rec.pair
    if valid_pair(p) and p.station.surface == surface and p.station.force == pair.station.force then
      local ok, d, radius = station_rec_contains(rec, pos)
      if ok then return true, rec, source or "authorized" end
      if d and (not best_d or d < best_d) then best, best_d = rec, d end
    end
  end
  return false, best, source or "not-authorized"
end

function M.position_allowed(pair, pos, reason, opts)
  local ok = M.authorization_for_destination(pair, pos, reason, opts)
  return ok
end

local function clear_invalid_movement(pair, reason)
  if not pair then return end
  pair.movement_request_0418 = nil; pair.movement_lease_0518 = nil; pair.movement_mode = nil; pair.move_target = nil
  pair.movement_corridor_rejected_0574 = { tick=now(), reason=tostring(reason or "corridor-rejected") }
  pcall(function()
    if valid(pair.priest) and pair.priest.commandable and pair.priest.commandable.valid then pair.priest.commandable.set_command({type=defines.command.stop})
    elseif valid(pair.priest) then pair.priest.set_command({type=defines.command.stop}) end
  end)
end

function M.return_home(pair, reason)
  local r=M.root()
  if not valid_pair(pair) then return false end
  local key=safe(station_unit(pair))
  if now() - (tonumber(r.last_return[key] or -1000000) or -1000000) < M.return_reissue_ticks then return true end
  r.last_return[key]=now()
  record("corridor-return-home-0574", pair, safe(reason))
  local pos=pair.station.position
  pcall(function()
    if pre_request then pre_request(pair, pos, "corridor-return-home-0574", {owner="authority-corridor-pathing-0574", priority=845, ttl=600, radius=1.0, distraction=defines and defines.distraction and defines.distraction.none})
    elseif _G.tech_priests_request_movement_0418 then _G.tech_priests_request_movement_0418(pair, pos, "corridor-return-home-0574", {owner="authority-corridor-pathing-0574", priority=845, ttl=600, radius=1.0, distraction=defines and defines.distraction and defines.distraction.none}) end
  end)
  return true
end

local function nearest_authorized_station_to_current(pair, pos)
  local auth = authorized_pairs(pair)
  local best, best_score = nil, nil
  for _, rec in ipairs(auth or {}) do
    local p=rec.pair
    if valid_pair(p) and p.station.surface == pair.priest.surface and p.station.force == pair.station.force then
      local score = (dist(pair.priest.position, p.station.position) or 0) + (dist(p.station.position, pos) or 0) * 0.25
      if not best_score or score < best_score then best, best_score = rec, score end
    end
  end
  return best
end

function M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
  local r=M.root()
  if r.enabled == false or r.decompose_long_moves == false then return nil end
  if not (valid_pair(pair) and pos and rec and valid_pair(rec.pair)) then return nil end
  if rec.role == "home" or rec.role == "exempt" then return nil end
  if pair.priest.surface ~= rec.pair.station.surface then return nil end
  local pd = dist(pair.priest.position, pos) or 0
  local in_auth_now = (dist(pair.priest.position, rec.pair.station.position) or 0) <= runtime_radius(rec.pair)
  if pd <= M.default_chunk or in_auth_now then return nil end
  -- Do not issue one long visible path.  Send the priest to the superior station
  -- first; the existing executor will reissue the work movement once corridor
  -- coverage has been entered.
  return rec.pair.station.position, rec
end

function M.guard_request(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.guard_movement == false then return true, pos, nil end
  if not (valid_pair(pair) and pos) then return true, pos, nil end
  local ok, rec, source = M.authorization_for_destination(pair, pos, reason, opts)
  if ok then
    if rec and rec.role and rec.role ~= "home" and rec.role ~= "exempt" then stat("authorized_superior_move") end
    local wp, wrec = M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
    if wp then
      record("corridor-waypoint-0574", pair, "role="..safe(wrec.role).." via="..safe(wrec.station_unit).." final="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)))
      return true, wp, { owner="authority-corridor-pathing-0574", radius=M.chunk_radius, priority=tonumber(opts and opts.priority or 700) or 700, ttl=tonumber(opts and opts.ttl or 600) or 600, distraction=opts and opts.distraction }
    end
    return true, pos, nil
  end
  clear_invalid_movement(pair, "unauthorized-corridor")
  record("corridor-move-rejected-0574", pair, "source="..safe(source).." dest="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)).." nearest="..safe(rec and rec.station_unit or "none").." reason="..safe(reason).." owner="..safe(opts and opts.owner))
  if r.return_on_unwrit_far_move ~= false then M.return_home(pair, "unauthorized-corridor") end
  return false, pos, nil
end

local function wrap_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" or pre_request then return false end
  pre_request = _G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0574_PRE_REQUEST_MOVEMENT_0418 = pre_request
  _G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts, ...)
    local allowed, new_pos, new_opts = M.guard_request(pair, pos, reason, opts)
    if not allowed then return false end
    if new_opts then return pre_request(pair, new_pos, "corridor-waypoint-0574", new_opts, ...) end
    return pre_request(pair, new_pos, reason, opts, ...)
  end
  return true
end

local function destination_from_pair(pair)
  local req = pair and (pair.movement_request_0418 or pair.movement_lease_0518 or pair.move_request or pair.movement)
  if type(req)=="table" then return req.position or req.destination or req.target_position or req.move_target or req.pos end
  if pair and type(pair.move_target)=="table" and pair.move_target.x then return pair.move_target end
  if pair and valid(pair.target) then return pair.target.position end
  if pair and type(pair.target)=="table" and pair.target.x then return pair.target end
  return nil
end

function M.service_pair(pair)
  if M.root().enabled == false or not valid_pair(pair) then return false end
  local pos = destination_from_pair(pair)
  if pos then
    local allowed = M.guard_request(pair, pos, "service-scan-0574", {owner="authority-corridor-pathing-0574-service"})
    return not allowed
  end
  return false
end

function M.service_all()
  wrap_request()
  for _, pair in pairs(pair_map()) do if valid_pair(pair) then M.service_pair(pair) end end
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected=player.selected
  if not (selected and selected.valid) then return nil end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and (pair.station == selected or pair.priest == selected) then return pair end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-path-corridors-0574") end end)
  commands.add_command("tp-path-corridors-0574", "Tech Priests 0.1.574 Cogitator corridor pathing guard. Params: on/off/status/all", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false elseif param=="all" then M.service_all() end
    local msg="[tp-path-corridors-0574] enabled="..safe(r.enabled).." rejected="..safe(r.stats["corridor-move-rejected-0574"] or 0).." waypoints="..safe(r.stats["corridor-waypoint-0574"] or 0).." superior_moves="..safe(r.stats.authorized_superior_move or 0).." returns="..safe(r.stats["corridor-return-home-0574"] or 0)
    if player and player.valid then
      player.print(msg)
      local pair=selected_pair(player)
      if pair then
        local auth = authorized_pairs(pair)
        player.print("  selected station#"..safe(station_unit(pair)).." authorized zones="..safe(#auth))
        for _, rec in ipairs(auth) do player.print("  - "..safe(rec.role).." station#"..safe(rec.station_unit).." radius="..safe(runtime_radius(rec.pair))) end
      end
    elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_request()
  _G.TECH_PRIESTS_AUTHORITY_CORRIDOR_PATHING_0574 = M
  _G.tech_priests_0574_position_allowed = M.position_allowed
  _G.tech_priests_0574_authorization_for_destination = M.authorization_for_destination
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick)=="function" then
    registry.on_nth_tick(M.service_interval, function() M.service_all() end, { owner="authority_corridor_pathing_0574", category="movement", priority="last", note="enforce home/superior-writ corridor bounds" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_interval, function() M.service_all() end)
  end
  record("install", nil, "Cogitator corridor pathing guard installed", true)
  if log then log("[Tech-Priests 0.1.574] Cogitator corridor pathing guard installed") end
  return true
end

return M
