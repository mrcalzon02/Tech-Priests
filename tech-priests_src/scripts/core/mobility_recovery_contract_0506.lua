-- scripts/core/mobility_recovery_contract_0506.lua
-- Tech Priests 0.1.506
--
-- Mobility/recovery contract after the 0.1.503-0.1.505 recovery layers proved
-- too aggressive.  Valid priests must be allowed to travel to work targets.
-- Recovery may rebind/respawn an invalid or cross-surface priest, but it must
-- not teleport a valid same-surface priest merely because a legacy caller passed
-- force_recall/immediate or because a direct acquisition task is active.
--
-- This module keeps the anti-remote-mining doctrine: direct world extraction may
-- only execute when the visible priest is adjacent.  If not adjacent, the direct
-- service requests physical movement and waits; it does not mine from the
-- station and does not yank the priest home.

local M = {}
M.version = "0.1.539"
M.storage_key = "mobility_recovery_contract_0506"
M.close_distance_sq = 7.84 -- mirrors 0.1.505, about 2.8 tiles
M.travel_reissue_ticks = 45
M.max_per_pulse = 16
M.log_interval = 180

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function M.root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {}, last_travel = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.block_valid_priest_recovery_teleports == nil then r.block_valid_priest_recovery_teleports = true end
  if r.allow_physical_direct_travel == nil then r.allow_physical_direct_travel = true end
  if r.disable_station_side_tether == nil then r.disable_station_side_tether = true end
  if r.disable_0505_remote_blocker == nil then r.disable_0505_remote_blocker = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.last_travel = r.last_travel or {}
  return r
end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function record(action, pair, detail, force)
  local r = M.root()
  action = tostring(action or "event")
  stat(action)
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 96 do table.remove(r.recent, 1) end
  local key = action .. ":" .. safe(rec.station)
  local last = r.last_log[key] or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.506] " .. action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. tostring(detail or "")) end
  end
end

local function repair_reverse_maps(pair, reason)
  if not valid_pair(pair) then return false end
  local tp = tp_root()
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  pair.priest_name = pair.priest.name
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.lifecycle_0506 = pair.lifecycle_0506 or {}
  pair.lifecycle_0506.last_valid_tick = now()
  pair.lifecycle_0506.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0506.last_reason = tostring(reason or "repair")
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function clear_recall_pressure(pair, reason)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({ "recalling", "pending_recall", "force_recall", "stuck_since", "last_stuck_tick", "stuck_recall_pending", "recall_requested" }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.lifecycle_0503 then
    pair.lifecycle_0503.last_recall_suppressed_0506 = now()
  end
  if changed then record("valid-priest-recall-pressure-cleared-0506", pair, "reason=" .. safe(reason)) end
  return changed
end

local function unpause_missing_priest_order(pair)
  local changed = false
  if not pair then return false end
  for _, key in ipairs({ "paused_by_missing_priest_0498", "paused_by_missing_priest_0500", "lost_priest_0490" }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.link_0495 and pair.link_0495.missing_since then pair.link_0495.missing_since = nil; changed = true end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "paused-missing-priest" then
    q.current.status = "active"
    q.current.paused_tick = nil
    q.current.pause_reason = nil
    pair.active_order_0469 = q.current
    changed = true
  end
  if pair.active_order_0469 and pair.active_order_0469.status == "paused-missing-priest" then
    pair.active_order_0469.status = "active"
    pair.active_order_0469.paused_tick = nil
    pair.active_order_0469.pause_reason = nil
    changed = true
  end
  return changed
end

local function direct_kind(kind)
  kind = tostring(kind or "")
  return kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336"
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  local task = pair.emergency_craft
  local cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  task = pair.direct_acquisition_task_0336
  cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  task = pair.active_acquisition_0333
  cur = task and (task.current or task)
  if cur and direct_kind(cur.kind) then return task, cur end
  return nil, nil
end

local function target_position(pair, cur)
  if cur and valid(cur.entity) then return cur.entity.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function target_name(cur)
  if cur and valid(cur.entity) then return cur.entity.name end
  return cur and (cur.item_name or cur.output_item or cur.kind) or "nil"
end

local function clear_direct_due(task)
  if not task then return end
  task.direct_due_tick_0273 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0336 = nil
  task.next_direct_laser_tick_0315 = nil
  task.direct_last_visual_tick_0306 = nil
end

local function request_direct_travel(pair, task, cur, reason)
  if not (M.root().allow_physical_direct_travel ~= false and valid_pair(pair) and cur) then return false end
  local pos = target_position(pair, cur)
  if not pos then return false end
  local d2 = dist_sq(pair.priest.position, pos) or 0
  if d2 <= M.close_distance_sq then return false end
  local key = tostring(station_unit(pair) or "nil")
  local r = M.root()
  local last = r.last_travel[key] or -1000000
  if now() - last < M.travel_reissue_ticks then
    stat("physical-direct-travel-throttled-0506")
    return true
  end
  r.last_travel[key] = now()
  clear_direct_due(task)
  pair.mode = cur.kind == "direct-dirt-0273" and "travelling-to-dirt-scrape" or "travelling-to-direct-acquisition"
  pair.target = valid(cur.entity) and cur.entity or nil
  pair.remote_direct_blocked_0505 = nil
  pair.movement_controller_state_0418 = nil
  pair.movement_controller_reason_0418 = nil
  clear_recall_pressure(pair, "physical-direct-travel")
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      _G.tech_priests_request_movement_0418(pair, pos, "physical-direct-acquisition-0506", { radius = 0.75, owner = "physical-direct-acquisition-0506", priority = 75, distraction = defines.distraction.none })
    elseif pair.priest and pair.priest.valid then
      local command = { type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, "physical-direct-0506-fallback-0621", { pair = pair, priority = 75, ttl = 600 })
      else
        pair.priest.set_command(command)
      end
    end
  end)
  record("physical-direct-travel-requested-0506", pair, "target=" .. safe(target_name(cur)) .. " dist=" .. safe(string.format("%.1f", math.sqrt(d2))) .. " reason=" .. safe(reason))
  return true
end

local function pre0502_name(name)
  return "TECH_PRIESTS_0502_PRE_" .. string.upper(name)
end

local function call_pre0502(name, pair, task, ...)
  local fn = rawget(_G, pre0502_name(name))
  if type(fn) ~= "function" then fn = rawget(_G, "TECH_PRIESTS_0506_PRE_" .. string.upper(name)) end
  if type(fn) == "function" then return fn(pair, task, ...) end
  return false
end

function M.service_direct(pair, task, reason, service_name, ...)
  if M.root().enabled == false then return false end
  if not valid_pair(pair) then return false end
  task = task or pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333
  local _, cur = current_direct_task(pair)
  if not (task and cur) then return false end
  repair_reverse_maps(pair, "service-direct-0506")
  unpause_missing_priest_order(pair)
  if request_direct_travel(pair, task, cur, reason or service_name or "direct") then return true end
  -- Now and only now is the visible priest adjacent enough for the older direct
  -- mining service to pulse smoke, lasers, damage, and deposit output.
  local name = service_name or "tech_priests_0315_service_direct_current"
  -- 0.1.539: Lua does not allow `...` inside this nested pcall closure.
  -- Capture varargs once so this compatibility module can actually install.
  local extra = { ... }
  local ok, result = pcall(function() return call_pre0502(name, pair, task, table.unpack(extra)) end)
  if ok then
    stat("physical-direct-adjacent-service-0506")
    return result
  end
  record("physical-direct-service-error-0506", pair, "service=" .. safe(name) .. " error=" .. safe(result), true)
  return false
end

local function patch_direct_services()
  local function wrap(name)
    local key = "TECH_PRIESTS_0506_PRE_" .. string.upper(name)
    if type(_G[name]) == "function" and not rawget(_G, key) then
      _G[key] = _G[name]
      _G[name] = function(pair, task, ...)
        local t, cur = current_direct_task(pair)
        if M.root().enabled ~= false and valid_pair(pair) and t and cur then
          return M.service_direct(pair, task or t, name, name, ...)
        end
        return _G[key](pair, task, ...)
      end
    end
  end
  wrap("tech_priests_0273_service_direct_current")
  wrap("tech_priests_0312_service_direct_current")
  wrap("tech_priests_0315_service_direct_current")

  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok and Exec and type(Exec.service_pair) == "function" and not Exec.mobility_0506_wrapped then
    Exec.mobility_0506_wrapped = true
    Exec.TECH_PRIESTS_0506_PRE_SERVICE_PAIR = Exec.service_pair
    Exec.service_pair = function(pair, reason)
      local task, cur = current_direct_task(pair)
      if M.root().enabled ~= false and valid_pair(pair) and task and cur then
        return M.service_direct(pair, task, reason or "acquisition-executor-0506", "tech_priests_0315_service_direct_current")
      end
      return Exec.TECH_PRIESTS_0506_PRE_SERVICE_PAIR(pair, reason)
    end
  end
end

local function patch_recovery()
  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0506_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0506_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate, ...)
      if M.root().enabled ~= false and M.root().block_valid_priest_recovery_teleports ~= false and valid_pair(pair) then
        repair_reverse_maps(pair, "ensure-valid-0506")
        unpause_missing_priest_order(pair)
        if pair.priest.surface == pair.station.surface then
          if force_recall or immediate or pair.recalling or pair.pending_recall or pair.force_recall then
            clear_recall_pressure(pair, "ensure-valid-suppressed")
            record("valid-priest-teleport-suppressed-0506", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
          end
          return true
        end
        -- Different surface is a real recovery problem; let the previous layer
        -- rebind or respawn safely.
      end
      return _G.TECH_PRIESTS_0506_PRE_ENSURE_PAIR_PRIEST(pair, force_recall, immediate, ...)
    end
  end

  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0506_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0506_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if M.root().enabled ~= false and valid_pair(pair) and pair.priest.surface == pair.station.surface then
        repair_reverse_maps(pair, "respawn-valid-suppressed-0506")
        unpause_missing_priest_order(pair)
        clear_recall_pressure(pair, "respawn-valid-suppressed")
        record("valid-priest-respawn-suppressed-0506", pair, "reason=" .. safe(reason))
        return true
      end
      return _G.TECH_PRIESTS_0506_PRE_RESPAWN_PAIR_PRIEST(pair, reason)
    end
  end
end

local function soften_older_quarantines()
  local r502 = rawget(_G, "TechPriestsPriestVanishGuard0502")
  if r502 and type(r502.root) == "function" then
    local ok, root = pcall(r502.root)
    if ok and root then
      if M.root().disable_station_side_tether ~= false then
        root.tether_visible_priest = false
        root.suppress_far_acquisition_movement = false
        root.station_side_direct_acquisition = false
      end
    end
  end
  local r505 = rawget(_G, "TechPriestsBehaviorExecutionDoctrine0505")
  if r505 and type(r505.root) == "function" then
    local ok, root = pcall(r505.root)
    if ok and root and M.root().disable_0505_remote_blocker ~= false then
      root.block_remote_world_mining = false
      -- 0.1.506 replaces the blocker with a physical travel contract.  The
      -- 0.1.505 facility and timed-craft gates remain useful and stay enabled.
    end
  end
end

function M.service_pair(pair)
  if M.root().enabled == false or not valid(pair and pair.station) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "service-valid-0506")
    unpause_missing_priest_order(pair)
    clear_recall_pressure(pair, "service-valid-0506")
    local task, cur = current_direct_task(pair)
    if task and cur then M.service_direct(pair, task, "service-pulse-0506", "tech_priests_0315_service_direct_current") end
    return true
  end
  return false
end

function M.service_all()
  if M.root().enabled == false then return false end
  soften_older_quarantines()
  local n = 0
  for _, pair in pairs(pair_map()) do
    if M.service_pair(pair) then n = n + 1 end
    if n >= M.max_per_pulse then break end
  end
  return true
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.mobility_recovery_0506_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.mobility_recovery_0506_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MOBILITY-RECOVERY-0506 BEGIN enabled=" .. safe(r.enabled)
      .. " block_valid_tp=" .. safe(r.block_valid_priest_recovery_teleports)
      .. " physical_direct=" .. safe(r.allow_physical_direct_travel)
      .. " suppressed_tp=" .. safe(r.stats["valid-priest-teleport-suppressed-0506"] or 0)
      .. " travel=" .. safe(r.stats["physical-direct-travel-requested-0506"] or 0)
      .. " adjacent=" .. safe(r.stats["physical-direct-adjacent-service-0506"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local _, cur = current_direct_task(pair)
        local pos = target_position(pair, cur)
        local pd = valid(pair.priest) and pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        local sd = valid(pair.priest) and math.sqrt(dist_sq(pair.priest.position, pair.station.position) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 mr0506[" .. safe(pair.station.unit_number) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest))
          .. " mode=" .. safe(pair.mode)
          .. " station_dist=" .. safe(sd and string.format("%.1f", sd) or "nil")
          .. " direct=" .. safe(cur and cur.kind or "nil")
          .. " target=" .. safe(target_name(cur))
          .. " target_dist=" .. safe(pd and string.format("%.1f", pd) or "nil")
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 MOBILITY-RECOVERY-0506 END"
    return lines
  end
  return true
end

local function commands_install()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-mobility-0506") end end)
  pcall(function()
    commands.add_command("tp-mobility-0506", "Tech Priests 0.1.506 mobility/recovery contract. status/all/enable/disable/teleports-on/teleports-off/direct-on/direct-off", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local p = tostring(event and event.parameter or "status")
      local r = M.root()
      if p == "enable" then r.enabled = true end
      if p == "disable" then r.enabled = false end
      if p == "teleports-on" then r.block_valid_priest_recovery_teleports = false end
      if p == "teleports-off" then r.block_valid_priest_recovery_teleports = true end
      if p == "direct-on" then r.allow_physical_direct_travel = true end
      if p == "direct-off" then r.allow_physical_direct_travel = false end
      if p == "all" then M.service_all() end
      local msg = "[Tech-Priests 0.1.506] enabled=" .. safe(r.enabled)
        .. " block_valid_tp=" .. safe(r.block_valid_priest_recovery_teleports)
        .. " physical_direct=" .. safe(r.allow_physical_direct_travel)
        .. " suppressed_tp=" .. safe(r.stats["valid-priest-teleport-suppressed-0506"] or 0)
        .. " travel=" .. safe(r.stats["physical-direct-travel-requested-0506"] or 0)
        .. " adjacent=" .. safe(r.stats["physical-direct-adjacent-service-0506"] or 0)
      if player then player.print(msg) elseif log then log(msg) end
    end)
  end)
end

function M.install()
  M.root()
  soften_older_quarantines()
  patch_recovery()
  patch_direct_services()
  wrap_pair_dump()
  commands_install()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "mobility_recovery_contract_0506", category = "movement", interval = 43, priority = 42, budget = 8, fn = function(event, budget) M.service_all("broker-0506") return true end, note = "mobility/recovery contract migrated from direct nth-tick" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(43, M.service_all, { owner = "mobility_recovery_contract_0506", category = "movement", note = "fallback until runtime broker is available", priority = "normal" })
    elseif script and script.on_nth_tick then script.on_nth_tick(43, M.service_all) end
  end
  _G.TechPriestsMobilityRecoveryContract0506 = M
  if log then log("[Tech-Priests 0.1.506] mobility/recovery contract installed; valid priests may travel, direct mining waits for adjacency, recovery teleports are reserved for real missing/cross-surface cases") end
  return true
end

return M
