-- scripts/core/movement_recovery_authority_0508.lua
-- Tech Priests 0.1.508
--
-- Second legacy cleanup pass: recovery is no longer a movement owner.
-- 0.1.503 restored useful missing-priest rescue, but it also restored recall
-- teleports through ensure_pair_priest. Live 0.1.507 logs showed those recalls
-- still firing during ordinary movement and direct acquisition, producing stunted
-- walk/teleport behavior. This module makes the contract explicit:
--   * valid same-surface priests are passively validated only;
--   * missing/cross-surface priests may still use the recovery chain;
--   * direct acquisition requests a movement lease and waits for adjacency;
--   * remote-mining blockers become diagnostics rather than an executor loop.

local M = {}
M.version = "0.1.508"
M.storage_key = "movement_recovery_authority_0508"
M.close_distance_sq = 7.84 -- about 2.8 tiles; matches the 0.1.505/0506 physical-work band
M.travel_reissue_ticks = 60
M.log_interval = 240

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

function M.root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {}, last_travel = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.passive_valid_recovery == nil then r.passive_valid_recovery = true end
  if r.physical_direct_travel == nil then r.physical_direct_travel = true end
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
    if log then log("[Tech-Priests 0.1.508] " .. action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. safe(detail)) end
  end
end

local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function same_surface(pair)
  return valid_pair(pair) and pair.station.surface == pair.priest.surface
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
  pair.lifecycle_0508 = pair.lifecycle_0508 or {}
  pair.lifecycle_0508.last_valid_tick = now()
  pair.lifecycle_0508.last_valid_reason = tostring(reason or "valid")
  pair.lifecycle_0508.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function clear_recall_pressure(pair, reason)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({
    "recalling", "pending_recall", "force_recall", "recall_requested",
    "stuck_since", "last_stuck_tick", "stuck_recall_pending",
    "lost_priest_0490", "missing_priest_rescue_0490",
    "paused_by_missing_priest_0498", "paused_by_missing_priest_0500"
  }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.link_0495 and pair.link_0495.missing_since then pair.link_0495.missing_since = nil; changed = true end
  if changed then record("recall-pressure-cleared-0508", pair, "reason=" .. safe(reason)) end
  return changed
end

local function unpause_missing_order(pair)
  if not pair then return false end
  local changed = false
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
  if changed then record("order-unpaused-0508", pair, "valid-priest") end
  return changed
end

function M.passive_valid_pair(pair, reason)
  if not valid_pair(pair) then return false end
  repair_reverse_maps(pair, reason or "passive-valid")
  clear_recall_pressure(pair, reason or "passive-valid")
  unpause_missing_order(pair)
  return true
end

local function direct_kind(kind)
  kind = tostring(kind or "")
  return kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336"
end

local function direct_task_from_pair(pair)
  if not pair then return nil, nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = task and (task.current or task)
    if cur and direct_kind(cur.kind) then return task, cur end
  end
  return nil, nil
end

local function current_position(pair, cur)
  if cur and valid(cur.entity) then return cur.entity.position end
  if cur and valid(cur.target) then return cur.target.position end
  if cur and valid(cur.source) then return cur.source.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function current_name(cur)
  if cur and valid(cur.entity) then return cur.entity.name end
  if cur and valid(cur.target) then return cur.target.name end
  if cur and valid(cur.source) then return cur.source.name end
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

function M.request_physical_direct_travel(pair, task, cur, reason)
  if not (M.root().physical_direct_travel ~= false and valid_pair(pair) and cur) then return false end
  local pos = current_position(pair, cur)
  if not pos then return false end
  local d2 = dist_sq(pair.priest.position, pos) or 0
  if d2 <= M.close_distance_sq then return false end
  local r = M.root()
  local key = tostring(station_unit(pair) or "nil")
  local last = r.last_travel[key] or -1000000
  if now() - last < M.travel_reissue_ticks then
    stat("physical-direct-travel-held-0508")
    pair.mode = cur.kind == "direct-dirt-0273" and "travelling-to-dirt-scrape" or "travelling-to-direct-acquisition"
    return true
  end
  r.last_travel[key] = now()
  clear_direct_due(task)
  clear_recall_pressure(pair, "physical-direct-travel")
  pair.mode = cur.kind == "direct-dirt-0273" and "travelling-to-dirt-scrape" or "travelling-to-direct-acquisition"
  pair.target = valid(cur.entity) and cur.entity or (valid(cur.target) and cur.target or nil)
  pair.remote_direct_blocked_0505 = nil
  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "movement", "movement_recovery_authority_0508", reason or "physical-direct") end
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      _G.tech_priests_request_movement_0418(pair, pos, "physical-direct-acquisition-0508", { radius = 0.75, owner = "physical-direct-acquisition-0508", priority = 125, ttl = 60 * 8, distraction = defines.distraction.none })
    elseif pair.priest and pair.priest.valid and pair.priest.set_command then
      local command = { type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, "physical-direct-0508-fallback-0621", { pair = pair, priority = 125, ttl = 480 })
      else
        pair.priest.set_command(command)
      end
    end
  end)
  record("physical-direct-travel-requested-0508", pair, "target=" .. safe(current_name(cur)) .. " dist=" .. safe(string.format("%.1f", math.sqrt(d2))) .. " reason=" .. safe(reason))
  return true
end

function M.service_physical_direct(pair, task, reason)
  if M.root().enabled == false then return false end
  if not valid_pair(pair) then return false end
  local found_task, cur = direct_task_from_pair(pair)
  task = task or found_task
  if not (task and cur) then return false end
  M.passive_valid_pair(pair, "direct-service")
  return M.request_physical_direct_travel(pair, task, cur, reason or "direct-service")
end

local function patch_recovery()
  local previous_global = type(_G.ensure_pair_priest) == "function" and _G.ensure_pair_priest or nil
  if previous_global and not rawget(_G, "TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST = previous_global
  end
  _G.ensure_pair_priest = function(pair, force_recall, immediate, ...)
    if M.root().enabled ~= false and M.root().passive_valid_recovery ~= false and same_surface(pair) then
      M.passive_valid_pair(pair, "ensure force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
      if force_recall or immediate then record("valid-priest-teleport-suppressed-0508", pair, "global ensure") end
      return true
    end
    local prev = rawget(_G, "TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST")
    if type(prev) == "function" then return prev(pair, false, false, ...) end
    return false
  end

  local previous_respawn = type(_G.respawn_pair_priest) == "function" and _G.respawn_pair_priest or nil
  if previous_respawn and not rawget(_G, "TECH_PRIESTS_0508_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0508_PRE_RESPAWN_PAIR_PRIEST = previous_respawn
  end
  _G.respawn_pair_priest = function(pair, reason)
    if M.root().enabled ~= false and same_surface(pair) then
      M.passive_valid_pair(pair, "respawn-suppressed " .. safe(reason))
      record("valid-priest-respawn-suppressed-0508", pair, "reason=" .. safe(reason))
      return true
    end
    local prev = rawget(_G, "TECH_PRIESTS_0508_PRE_RESPAWN_PAIR_PRIEST")
    if type(prev) == "function" then return prev(pair, reason) end
    if type(_G.ensure_pair_priest) == "function" then return _G.ensure_pair_priest(pair, false, false) end
    return false
  end

  local rec = rawget(_G, "TechPriestsPriestRecoverySafety0503")
  if rec and not rec.movement_authority_0508_wrapped then
    rec.movement_authority_0508_wrapped = true
    rec.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST = rec.ensure_pair_priest
    rec.TECH_PRIESTS_0508_PRE_SERVICE_PAIR = rec.service_pair
    rec.TECH_PRIESTS_0508_PRE_RESPAWN_PAIR_PRIEST = rec.respawn_pair_priest
    rec.ensure_pair_priest = function(pair, force_recall, immediate, reason)
      if M.root().enabled ~= false and M.root().passive_valid_recovery ~= false and same_surface(pair) then
        M.passive_valid_pair(pair, reason or "0503-ensure-suppressed")
        if force_recall or immediate then record("valid-priest-teleport-suppressed-0508", pair, "0503 ensure") end
        return true
      end
      if type(rec.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST) == "function" then
        return rec.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST(pair, false, false, reason)
      end
      return false
    end
    rec.service_pair = function(pair)
      if M.root().enabled ~= false and same_surface(pair) then return M.passive_valid_pair(pair, "0503-service-suppressed") end
      if type(rec.TECH_PRIESTS_0508_PRE_SERVICE_PAIR) == "function" then return rec.TECH_PRIESTS_0508_PRE_SERVICE_PAIR(pair) end
      return false
    end
    rec.service_all = function()
      local n = 0
      for _, pair in pairs(pair_map()) do
        if pair and valid(pair.station) then
          pcall(function()
            if rec.service_pair(pair) then n = n + 1 end
          end)
        end
      end
      return true
    end
    record("recovery0503-passivized-0508", nil, "valid same-surface priests no longer teleport")
  end
end

local function patch_direct_services()
  local function wrap(name)
    if type(_G[name]) == "function" and not rawget(_G, "TECH_PRIESTS_0508_PRE_" .. string.upper(name)) then
      _G["TECH_PRIESTS_0508_PRE_" .. string.upper(name)] = _G[name]
      _G[name] = function(pair, task, ...)
        if M.service_physical_direct(pair, task, name) then return true end
        return _G["TECH_PRIESTS_0508_PRE_" .. string.upper(name)](pair, task, ...)
      end
    end
  end
  wrap("tech_priests_0273_service_direct_current")
  wrap("tech_priests_0312_service_direct_current")
  wrap("tech_priests_0315_service_direct_current")

  if type(_G.handle_emergency_desperation_craft) == "function" and not rawget(_G, "TECH_PRIESTS_0508_PRE_HANDLE_EMERGENCY_CRAFT") then
    _G.TECH_PRIESTS_0508_PRE_HANDLE_EMERGENCY_CRAFT = _G.handle_emergency_desperation_craft
    _G.handle_emergency_desperation_craft = function(pair, ...)
      if M.service_physical_direct(pair, nil, "handle-emergency-craft") then return true end
      return _G.TECH_PRIESTS_0508_PRE_HANDLE_EMERGENCY_CRAFT(pair, ...)
    end
  end

  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok and Exec and type(Exec.service_pair) == "function" and not Exec.movement_authority_0508_wrapped then
    Exec.movement_authority_0508_wrapped = true
    Exec.TECH_PRIESTS_0508_PRE_SERVICE_PAIR = Exec.service_pair
    Exec.service_pair = function(pair, reason)
      if M.service_physical_direct(pair, nil, reason or "acquisition-executor") then return true end
      return Exec.TECH_PRIESTS_0508_PRE_SERVICE_PAIR(pair, reason)
    end
  end
end

local function soften_blockers()
  local b = rawget(_G, "TechPriestsBehaviorExecutionDoctrine0505")
  if b and type(b.root) == "function" then
    local ok, r = pcall(b.root)
    if ok and r and M.root().disable_0505_remote_blocker ~= false then
      r.block_remote_world_mining = false
      record("remote-blocker-softened-0508", nil, "0508 owns physical direct movement")
    end
  end
  local m = rawget(_G, "TechPriestsMobilityRecoveryContract0506")
  if m and type(m.root) == "function" then
    local ok, r = pcall(m.root)
    if ok and r then
      r.enabled = false -- 0508 supersedes the failed/partial 0506 contract in this branch.
      record("mobility0506-superseded-0508", nil, "0508 owns recovery/movement contract")
    end
  end
end

function M.service_all()
  if M.root().enabled == false then return false end
  soften_blockers()
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) then
      pcall(function()
        if same_surface(pair) then
          M.passive_valid_pair(pair, "service")
          M.service_physical_direct(pair, nil, "service")
        elseif not valid(pair.priest) and type(_G.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST) == "function" then
          _G.TECH_PRIESTS_0508_PRE_ENSURE_PAIR_PRIEST(pair, false, false)
        end
      end)
    end
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    if tp.pairs_by_station and tp.pairs_by_station[selected.unit_number] then return tp.pairs_by_station[selected.unit_number] end
    if tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number] then return tp.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.movement_recovery_authority_0508_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.movement_recovery_authority_0508_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MOVEMENT-RECOVERY-0508 BEGIN enabled=" .. safe(r.enabled)
      .. " passive_valid=" .. safe(r.passive_valid_recovery)
      .. " physical_direct=" .. safe(r.physical_direct_travel)
      .. " tp_suppressed=" .. safe(r.stats["valid-priest-teleport-suppressed-0508"] or 0)
      .. " travel=" .. safe(r.stats["physical-direct-travel-requested-0508"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local task, cur = direct_task_from_pair(pair)
        local pos = current_position(pair, cur)
        local pd = valid(pair.priest) and pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        local sd = valid_pair(pair) and math.sqrt(dist_sq(pair.priest.position, pair.station.position) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 mr0508[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest))
          .. " same_surface=" .. safe(same_surface(pair))
          .. " mode=" .. safe(pair.mode)
          .. " station_dist=" .. safe(sd and string.format("%.1f", sd) or "nil")
          .. " direct=" .. safe(cur and cur.kind or "nil")
          .. " target=" .. safe(current_name(cur))
          .. " target_dist=" .. safe(pd and string.format("%.1f", pd) or "nil")
          .. " move_owner=" .. safe(pair.movement_request_0418 and pair.movement_request_0418.owner or "nil")
      end
    end
    for i = math.max(1, #r.recent - 10), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 mr0508.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 MOVEMENT-RECOVERY-0508 END"
    return lines
  end
  return true
end

local function install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-movement-recovery-0508") end end)
  commands.add_command("tp-movement-recovery-0508", "Tech Priests 0.1.508: movement/recovery authority status for selected pair.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "passive-on" then r.passive_valid_recovery = true end
    if p == "passive-off" then r.passive_valid_recovery = false end
    if p == "direct-on" then r.physical_direct_travel = true end
    if p == "direct-off" then r.physical_direct_travel = false end
    if p == "all" then M.service_all() end
    local pair = player and selected_pair(player) or nil
    local text = "[tp-movement-recovery-0508] enabled=" .. safe(r.enabled)
      .. " passive_valid=" .. safe(r.passive_valid_recovery)
      .. " physical_direct=" .. safe(r.physical_direct_travel)
      .. " tp_suppressed=" .. safe(r.stats["valid-priest-teleport-suppressed-0508"] or 0)
      .. " travel=" .. safe(r.stats["physical-direct-travel-requested-0508"] or 0)
    if pair then
      local _, cur = direct_task_from_pair(pair)
      text = text .. "\nselected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " mode=" .. safe(pair.mode) .. " direct=" .. safe(cur and cur.kind or "nil") .. " move_owner=" .. safe(pair.movement_request_0418 and pair.movement_request_0418.owner or "nil")
    end
    if player and player.valid then player.print(text) elseif game and game.print then game.print(text) end
  end)
end

function M.install()
  M.root()
  patch_recovery()
  patch_direct_services()
  soften_blockers()
  wrap_pair_dump()
  install_commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(47, function() M.service_all() end, { owner = "movement_recovery_authority_0508", category = "movement", note = "passive recovery and direct travel lease" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(47, function() M.service_all() end)
  end
  _G.TechPriestsMovementRecoveryAuthority0508 = M
  if log then log("[Tech-Priests 0.1.508] movement/recovery authority installed; valid priests are not teleported by ensure, direct acquisition uses physical travel leases") end
  return true
end

return M
