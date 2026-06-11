-- scripts/core/movement_cadence_contract_0518.lua
-- Tech Priests 0.1.518
--
-- Movement cadence and task-churn contract.  The dispatcher/executor stack now
-- owns several long physical actions (direct acquisition, consecration, repair,
-- combat repair).  Those actions must be allowed to finish walking instead of
-- being re-targeted every few ticks by older scheduler/legacy refresh paths.
-- This module does not become a new movement authority.  It wraps the existing
-- 0.1.418/0.1.452 movement controller request API and extends its retarget hold
-- rules while preserving urgent combat/retreat/recovery interrupts.

local M = {}
M.version = "0.1.539"
M.storage_key = "movement_cadence_contract_0518"
M.enabled_default = true
M.lease_ticks = 60 * 6
M.low_priority_retarget_hold_ticks = 60 * 3
M.same_destination_distance_sq = 1.00
M.minimum_priority_delta_to_break_lease = 60
M.command_refresh_ticks = 45
M.retarget_hold_ticks = 90
M.minimum_retarget_distance_sq = 1.00
M.max_recent = 180

local original_request = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function pair_key(pair)
  if pair and valid(pair.station) and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if pair and valid(pair.priest) and pair.priest.unit_number then return "p" .. tostring(pair.priest.unit_number) end
  return nil
end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b)
  if not (a and b) then return nil end
  local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = M.enabled_default,
    stats = {},
    recent = {},
    leases = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = M.enabled_default end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.leases = r.leases or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = M.root()
  stat(action)
  local ev = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > M.max_recent do table.remove(r.recent, 1) end
  return ev
end

local function request_owner(reason, opts)
  opts = opts or {}
  return lower(opts.owner or reason or "movement")
end

local function urgent_owner(owner, reason, opts)
  local text = lower((owner or "") .. " " .. tostring(reason or "") .. " " .. tostring(opts and opts.kind or ""))
  if text:find("combat",1,true) or text:find("retreat",1,true) or text:find("flee",1,true) then return true end
  if text:find("recovery",1,true) or text:find("respawn",1,true) or text:find("return%-home",1,false) then return true end
  return false
end

local function moving_action_owner(owner)
  owner = lower(owner)
  return owner:find("consecration",1,true)
      or owner:find("repair",1,true)
      or owner:find("direct",1,true)
      or owner:find("acquisition",1,true)
      or owner:find("construction",1,true)
      or owner:find("production",1,true)
      or owner:find("dispatcher",1,true)
end

local function lease_for(pair)
  local r = M.root()
  local key = pair_key(pair)
  return key and r.leases[key] or nil, key, r
end

local function update_lease(pair, dest, reason, opts)
  local lease, key, r = lease_for(pair)
  if not key then return nil end
  opts = opts or {}
  local owner = request_owner(reason, opts)
  local priority = tonumber(opts.priority) or 50
  local current = {
    x = dest and dest.x,
    y = dest and dest.y,
    owner = owner,
    reason = tostring(reason or owner),
    priority = priority,
    started_tick = (lease and lease.started_tick) or now(),
    updated_tick = now(),
    expires_tick = now() + (tonumber(opts.ttl) or M.lease_ticks),
  }
  r.leases[key] = current
  pair.movement_lease_0518 = current
  return current
end

local function lease_active(pair)
  local lease, key, r = lease_for(pair)
  if not lease and pair then lease = pair.movement_lease_0518 end
  if not lease then return nil end
  if tonumber(lease.expires_tick or 0) < now() then
    if key then r.leases[key] = nil end
    if pair then pair.movement_lease_0518 = nil end
    return nil
  end
  return lease
end

local function should_hold(pair, dest, reason, opts)
  if not (pair and dest) then return false end
  opts = opts or {}
  local owner = request_owner(reason, opts)
  if urgent_owner(owner, reason, opts) then return false end
  local priority = tonumber(opts.priority) or 50
  local lease = lease_active(pair)
  if not lease then return false end
  local same = dist_sq(lease, dest) or 999999
  if same <= M.same_destination_distance_sq then return false end
  local lease_priority = tonumber(lease.priority) or 0
  if priority >= lease_priority + M.minimum_priority_delta_to_break_lease then return false end
  local current_req = pair.movement_request_0418
  if current_req and current_req.expires_tick and current_req.expires_tick >= now() then
    return true, lease, owner, priority
  end
  -- If the priest is in an explicit long walking phase, hold even if the request
  -- table was momentarily cleared by an old service pulse.
  local mode = lower(pair.mode)
  local phase = lower(pair.dispatcher_phase or (pair.consecration_0515 and pair.consecration_0515.phase) or (pair.repair_0516 and pair.repair_0516.phase) or "")
  if mode:find("moving",1,true) or mode:find("walk",1,true) or phase:find("walk",1,true) then
    return true, lease, owner, priority
  end
  return false
end

local function tune_controller()
  local ok, Movement = pcall(require, "scripts.core.movement_controller")
  if ok and Movement then
    Movement.command_refresh_ticks = math.max(tonumber(Movement.command_refresh_ticks or 0) or 0, M.command_refresh_ticks)
    Movement.retarget_hold_ticks = math.max(tonumber(Movement.retarget_hold_ticks or 0) or 0, M.retarget_hold_ticks)
    Movement.minimum_retarget_distance_sq = math.max(tonumber(Movement.minimum_retarget_distance_sq or 0) or 0, M.minimum_retarget_distance_sq)
    Movement.service_ticks = math.min(tonumber(Movement.service_ticks or 10) or 10, 10)
    return true
  end
  return false
end

local function wrap_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" or original_request then return false end
  original_request = _G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0518_PRE_REQUEST_MOVEMENT_0418 = original_request
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
    local r = M.root()
    if r.enabled ~= false and pair and valid(pair.priest) and destination then
      local hold, lease, owner, priority = should_hold(pair, destination, reason, opts)
      if hold then
        stat("retargets_held")
        pair.movement_cadence_held_0518 = {
          tick = now(), owner = owner, priority = priority,
          requested = { x = destination.x, y = destination.y },
          held_for = { x = lease.x, y = lease.y, owner = lease.owner, reason = lease.reason }
        }
        -- If a legacy pulse cleared the request table but the action lease is
        -- still valid, quietly restore the held route instead of accepting the
        -- new lower-priority destination.
        if not pair.movement_request_0418 and lease.x and lease.y then
          pcall(original_request, pair, { x = lease.x, y = lease.y }, lease.reason or "movement-lease-0518", { owner = lease.owner or "movement_cadence_0518", priority = lease.priority or priority, ttl = math.max(60, (lease.expires_tick or now()) - now()) })
        end
        record("retarget-held", pair, "owner=" .. safe(owner) .. " held_for=" .. safe(lease.owner) .. " reason=" .. safe(reason))
        return true
      end
    end
    local ok, res = pcall(original_request, pair, destination, reason, opts)
    if ok and res ~= false and M.root().enabled ~= false and pair and destination then
      local owner = request_owner(reason, opts or {})
      if moving_action_owner(owner) or lower(pair.mode):find("moving",1,true) then
        update_lease(pair, destination, reason, opts or {})
        record("lease", pair, "owner=" .. safe(owner) .. " reason=" .. safe(reason) .. " x=" .. safe(destination.x) .. " y=" .. safe(destination.y))
      end
    end
    if ok then return res end
    return false
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp = storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-movement-cadence-0518") end end)
  commands.add_command("tp-movement-cadence-0518", "Tech Priests 0.1.518 movement cadence/task-churn contract. Params: on/off/all", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = M.root()
    if param == "on" then r.enabled = true end
    if param == "off" then r.enabled = false end
    tune_controller()
    local pair = selected_pair(player)
    local lines = {}
    lines[#lines+1] = "[tp-movement-cadence-0518] enabled=" .. safe(r.enabled) .. " held=" .. safe(r.stats.retargets_held or 0) .. " leases=" .. safe(r.stats.lease or 0) .. " controller_hold=" .. safe(M.retarget_hold_ticks)
    if pair then
      local req = pair.movement_request_0418 or {}
      local lease = pair.movement_lease_0518 or {}
      local held = pair.movement_cadence_held_0518 or {}
      lines[#lines+1] = "selected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " mode=" .. safe(pair.mode)
        .. " req=" .. safe(req.owner) .. "/" .. safe(req.reason) .. "@" .. safe(req.x) .. "," .. safe(req.y)
        .. " lease=" .. safe(lease.owner) .. "/" .. safe(lease.reason) .. " until=" .. safe(lease.expires_tick)
        .. " last_held=" .. safe(held.owner) .. " for=" .. safe(held.held_for and held.held_for.owner)
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468") or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.movement_cadence_0518_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.movement_cadence_0518_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines+1] = "PAIR-DUMP-0468 MOVEMENT-CADENCE-0518 BEGIN enabled=" .. safe(r.enabled) .. " held=" .. safe(r.stats.retargets_held or 0) .. " leases=" .. safe(r.stats.lease or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local req = pair.movement_request_0418 or {}
        local lease = pair.movement_lease_0518 or {}
        local held = pair.movement_cadence_held_0518 or {}
        lines[#lines+1] = "PAIR-DUMP-0468 cadence0518[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " mode=" .. safe(pair.mode) .. " req_owner=" .. safe(req.owner) .. " req_reason=" .. safe(req.reason) .. " req=" .. safe(req.x) .. "," .. safe(req.y)
          .. " lease_owner=" .. safe(lease.owner) .. " lease_reason=" .. safe(lease.reason) .. " lease_until=" .. safe(lease.expires_tick)
          .. " last_held_owner=" .. safe(held.owner) .. " held_for=" .. safe(held.held_for and held.held_for.owner)
      end
    end
    for i=math.max(1,#r.recent-10),#r.recent do
      local ev=r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 cadence0518.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 MOVEMENT-CADENCE-0518 END"
    return lines
  end
  return true
end

function M.clear_lease(pair, reason)
  local lease, key, r = lease_for(pair)
  if key then r.leases[key] = nil end
  if pair then
    pair.movement_lease_0518 = nil
    pair.movement_cadence_held_0518 = nil
    pair.movement_cadence_cleared_0539 = { tick = now(), reason = tostring(reason or "clear") }
  end
  record("lease-cleared-0539", pair, "reason=" .. safe(reason))
  return true
end

function M.service_all(reason)
  local r = M.root()
  if r.enabled == false then return false end
  for _, pair in pairs(pair_map()) do
    local lease = lease_active(pair)
    if lease then
      local req = pair.movement_request_0418
      if req and req.expires_tick and req.expires_tick < now() then pair.movement_request_0418 = nil end
    end
  end
  return true
end

function M.install()
  M.root()
  tune_controller()
  wrap_request()
  wrap_pair_dump()
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(30, function() M.service_all("nth-tick-0518") end, { owner="movement_cadence_contract_0518", category="movement", note="preserve long movement leases against task churn" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(30, function() M.service_all("nth-tick-0518") end)
  end
  _G.TechPriestsMovementCadenceContract0518 = M
  _G.tech_priests_clear_movement_lease_0518 = function(pair, reason) return M.clear_lease(pair, reason) end
  if log then log("[Tech-Priests 0.1.539] movement cadence contract installed; retarget churn is held behind active dispatcher movement leases; work clamps may clear stale leases") end
  return true
end

return M
