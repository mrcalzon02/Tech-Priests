-- scripts/core/movement_enforcement_0566.lua
-- Tech Priests 0.1.566
--
-- Movement enforcement governor. This is not a new behavior owner: it wraps the
-- existing movement request authority and runs a low-frequency sanity pulse so
-- priests cannot keep walking toward stale, out-of-network, or legacy targets.
-- It rejects non-return movement outside the pair's operating envelope, clears
-- stale movement leases/targets, and sends overleashed priests home through the
-- existing movement request path.

local M = {}
M.version = "0.1.566"
M.storage_key = "movement_enforcement_0566"

M.service_interval = 89
M.log_interval = 900
M.reject_cooldown_ticks = 60 * 12
M.return_reissue_ticks = 60 * 4
M.default_work_radius = 36
M.default_hard_leash = 52
M.work_radius_by_tier = {
  ["planetary-magos"] = 28,
  ["planetary_magos"] = 28,
  ["planetary"] = 28,
  ["senior"] = 36,
  ["intermediate"] = 38,
  ["junior"] = 40,
}
M.hard_leash_by_tier = {
  ["planetary-magos"] = 42,
  ["planetary_magos"] = 42,
  ["planetary"] = 42,
  ["senior"] = 52,
  ["intermediate"] = 56,
  ["junior"] = 60,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a,b)
  if not (a and b) then return nil end
  local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end
local function dist(a,b) local d2=dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    reject_far_work_targets = true,
    clear_stale_targets = true,
    return_overleashed = true,
    stats = {},
    recent = {},
    last_log = {},
    rejected_until = {},
    last_return = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.reject_far_work_targets == nil then r.reject_far_work_targets = true end
  if r.clear_stale_targets == nil then r.clear_stale_targets = true end
  if r.return_overleashed == nil then r.return_overleashed = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.rejected_until = r.rejected_until or {}
  r.last_return = r.last_return or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end

local function record(action, pair, detail, force)
  local r=M.root()
  action = tostring(action or "event")
  stat(action)
  local rec={tick=now(), action=action, station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent > 96 do table.remove(r.recent,1) end
  local key=action..":"..safe(rec.station)
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.566] "..action.." station="..safe(rec.station).." priest="..safe(rec.priest).." "..safe(detail)) end
  end
  return rec
end

local function tier_key(pair)
  local t = lower(pair and (pair.tier or pair.rank or pair.station_tier or pair.priest_name or (valid(pair.station) and pair.station.name) or ""))
  if t:find("planetary",1,true) or t:find("magos",1,true) then return "planetary-magos" end
  if t:find("senior",1,true) then return "senior" end
  if t:find("intermediate",1,true) then return "intermediate" end
  if t:find("junior",1,true) then return "junior" end
  return "default"
end

local function runtime_radius(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or nil
  if _G.refresh_pair_radius and pair then local ok, got = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(got) then r = tonumber(got) end end
  if (not r) and _G.get_station_operating_radius and valid(pair and pair.station) then local ok, got = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(got) then r = tonumber(got) end end
  return r
end

function M.work_radius(pair)
  local cap = M.work_radius_by_tier[tier_key(pair)] or M.default_work_radius
  local rt = runtime_radius(pair) or cap
  -- Allow normal station-radius work, but do not allow research/GUI range
  -- bookkeeping to turn into unbounded walking.
  return math.max(8, math.min(math.max(rt, 8), cap))
end

function M.hard_leash(pair)
  local cap = M.hard_leash_by_tier[tier_key(pair)] or M.default_hard_leash
  return math.max(M.work_radius(pair) + 8, cap)
end

local function destination_from_request(req)
  if type(req) ~= "table" then return nil end
  return req.position or req.destination or req.target_position or req.move_target or req.pos
end

local function destination_from_pair(pair)
  local req = pair and (pair.movement_request_0418 or pair.movement_lease_0518 or pair.move_request or pair.movement)
  local pos = destination_from_request(req)
  if pos then return pos, "movement-request" end
  if pair and type(pair.move_target)=="table" then return pair.move_target, "move-target" end
  if pair and valid(pair.target) then return pair.target.position, "pair-target" end
  if pair and type(pair.target)=="table" and pair.target.x and pair.target.y then return pair.target, "pair-target-position" end
  return nil, "none"
end

local function distance_from_station(pair, pos)
  if not (valid(pair and pair.station) and pos) then return nil end
  return dist(pair.station.position, pos)
end

local function is_return_reason(reason, opts)
  local s = lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("return",1,true)
      or s:find("home",1,true)
      or s:find("overleash",1,true)
      or s:find("station",1,true)
      or s:find("movement%-bounds%-0511",1,false)
      or s:find("movement%-enforcement%-0566",1,false)
end

local function is_recovery_reason(reason, opts)
  local s = lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("recovery",1,true) or s:find("respawn",1,true) or s:find("pair%-link",1,false)
end

function M.position_allowed(pair, pos, reason, opts)
  if not (valid_pair(pair) and pos) then return true, nil, nil end
  if is_return_reason(reason, opts) or is_recovery_reason(reason, opts) then return true, nil, nil end
  -- 0.1.574: permit superior-station corridor movement only when the
  -- authority corridor guard says a valid writ/order currently authorizes it.
  -- Without this handoff, the older home-radius guard would reject the movement
  -- before the corridor guard could decompose or approve it.
  if type(_G.tech_priests_0574_position_allowed) == "function" then
    local ok_call, allowed = pcall(_G.tech_priests_0574_position_allowed, pair, pos, reason, opts)
    if ok_call and allowed then return true, nil, nil end
  end
  local d = distance_from_station(pair, pos) or 0
  local maxd = M.work_radius(pair)
  return d <= maxd, d, maxd
end

local function rejection_key(pair, pos, reason, opts)
  return safe(station_unit(pair))..":"..string.format("%.1f,%.1f", tonumber(pos and pos.x) or 0, tonumber(pos and pos.y) or 0)..":"..safe(reason)..":"..safe(opts and opts.owner)
end

local function clear_movement_state(pair, reason)
  if not pair then return false end
  pair.movement_request_0418 = nil
  pair.movement_lease_0518 = nil
  pair.movement_mode = nil
  pair.move_target = nil
  pair.movement_owner_0566 = nil
  pair.movement_target_0566 = nil
  -- Do not destroy active order queues here; just make the invalid travel fail
  -- fast so the scheduler can replan or cool down rather than chase forever.
  pair.target = nil
  pair.combat_target = nil
  pair.paused_by_combat = nil
  pair.mode = "movement-target-rejected-0566"
  pair.movement_rejected_0566 = { tick=now(), reason=tostring(reason or "invalid-target") }
  pcall(function()
    if valid(pair.priest) and pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.stop })
    elseif valid(pair.priest) then
      pair.priest.set_command({ type = defines.command.stop })
    end
  end)
  return true
end

function M.reject_far_destination(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.reject_far_work_targets == false then return false end
  local ok,d,maxd = M.position_allowed(pair, pos, reason, opts)
  if ok then return false end
  local key = rejection_key(pair,pos,reason,opts)
  if now() < tonumber(r.rejected_until[key] or 0) then
    stat("repeat_far_move_suppressed")
    return true
  end
  r.rejected_until[key] = now() + M.reject_cooldown_ticks
  clear_movement_state(pair, "far-destination")
  record("far-move-rejected-0566", pair, "dist="..safe(string.format("%.1f", d or 0)).." max="..safe(maxd).." reason="..safe(reason).." owner="..safe(opts and opts.owner).." dest="..safe(pos and (string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)) or "nil"))
  return true
end

function M.return_to_station(pair, reason)
  local r=M.root()
  if r.enabled == false or r.return_overleashed == false or not valid_pair(pair) then return false end
  local key=safe(station_unit(pair))
  if now() - (tonumber(r.last_return[key] or -1000000) or -1000000) < M.return_reissue_ticks then return true end
  r.last_return[key]=now()
  local pos = pair.station.position
  record("return-home-0566", pair, safe(reason))
  pair.mode = "returning-movement-enforcement-0566"
  pair.target = pair.station
  pair.movement_rejected_0566 = { tick=now(), reason=tostring(reason or "return-home") }
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      _G.tech_priests_request_movement_0418(pair, pos, "return-home-0566", { radius=1.0, owner="movement-enforcement-0566", priority=840, ttl=600, distraction=defines.distraction.none })
    elseif pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type=defines.command.go_to_location, destination=pos, radius=1.0, distraction=defines.distraction.none })
    else
      pair.priest.set_command({ type=defines.command.go_to_location, destination=pos, radius=1.0, distraction=defines.distraction.none })
    end
  end)
  return true
end

function M.service_pair(pair, reason)
  if M.root().enabled == false or not valid_pair(pair) then return false end
  local d = dist(pair.priest.position, pair.station.position) or 0
  if d > M.hard_leash(pair) then
    clear_movement_state(pair, "overleash")
    M.return_to_station(pair, "overleash dist="..safe(string.format("%.1f", d)).." max="..safe(M.hard_leash(pair)))
    return true
  end

  local pos, source = destination_from_pair(pair)
  if pos then
    local rejected = M.reject_far_destination(pair, pos, reason or source, { owner = source })
    if rejected then
      M.return_to_station(pair, "stale/far "..safe(source))
      return true
    end
  end

  -- If a neutral/resource combat target is being carried by old behavior state,
  -- make sure it cannot act as a hidden long-range movement anchor.
  if valid(pair.combat_target) and pair.combat_target.force ~= pair.priest.force then
    local td = distance_from_station(pair, pair.combat_target.position) or 0
    if td > M.work_radius(pair) then
      pair.combat_target = nil
      pair.paused_by_combat = nil
      record("far-combat-target-cleared-0566", pair, "dist="..safe(string.format("%.1f", td)).." max="..safe(M.work_radius(pair)))
    end
  end

  return false
end

local function wrap_movement_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" or rawget(_G, "TECH_PRIESTS_0566_PRE_REQUEST_MOVEMENT_0418") then return false end
  local prev = _G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0566_PRE_REQUEST_MOVEMENT_0418 = prev
  _G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts, ...)
    if M.reject_far_destination(pair, pos, reason, opts) then
      if valid_pair(pair) then M.return_to_station(pair, "wrapped far movement") end
      return false
    end
    return prev(pair, pos, reason, opts, ...)
  end
  return true
end

function M.service_all(reason)
  if M.root().enabled == false then return false end
  wrap_movement_request()
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then M.service_pair(pair, reason or "service") end
  end
  return true
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-movement-enforcement-0566") end end)
  commands.add_command("tp-movement-enforcement-0566", "Tech Priests 0.1.566 movement enforcement. Params: on/off/all/status", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p=="on" then r.enabled=true elseif p=="off" then r.enabled=false elseif p=="all" then M.service_all("manual") end
    local msg = "[tp-movement-enforcement-0566] enabled="..safe(r.enabled)
      .." far_rejected="..safe(r.stats["far-move-rejected-0566"] or 0)
      .." repeats_suppressed="..safe(r.stats.repeat_far_move_suppressed or 0)
      .." returns="..safe(r.stats["return-home-0566"] or 0)
      .." far_combat_cleared="..safe(r.stats["far-combat-target-cleared-0566"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_movement_request()
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(M.service_interval, function() M.service_all("nth-tick-0566") end, { owner="movement_enforcement_0566", category="movement", priority="last", note="reject stale far movement and return overleashed priests" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_interval, function() M.service_all("nth-tick-0566") end)
  end
  _G.TechPriestsMovementEnforcement0566 = M
  if log then log("[Tech-Priests 0.1.566] movement enforcement governor installed; stale/far movement requests are rejected and overleashed priests return to station") end
  return true
end

return M
