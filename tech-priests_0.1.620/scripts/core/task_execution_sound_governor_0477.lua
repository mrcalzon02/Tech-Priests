-- scripts/core/task_execution_sound_governor_0477.lua
-- Tech Priests 0.1.477
-- Late authority for two stabilization defects observed in 0.1.476:
--   * an order could be active in the queue while no legacy movement/work surface
--     was actually executing it, leaving priests standing still with a valid writ;
--   * station task-switch audio could still be triggered by mode-string churn and
--     older transition calls, even when the stable order did not really change.

local M = {}
M.version = "0.1.477"
M.storage_key = "task_execution_sound_governor_0477"
M.tick_interval = 60
M.default_watchdog_seconds = 10
M.default_task_switch_cooldown_seconds = 45
M.default_writ_audio_cooldown_seconds = 30
M.max_reactivate_attempts_before_fail = 6

local original_sound_emit = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end
local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end
local function setting_seconds(name, fallback, lo, hi)
  local v = nil
  if settings and settings.global and settings.global[name] ~= nil then
    v = tonumber(settings.global[name].value)
  end
  return clamp(v or fallback, lo or 1, hi or 3600)
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end
local function enabled() return root().enabled ~= false end
local function stat(name, delta) local r = root(); r.stats[name] = (r.stats[name] or 0) + (delta or 1) end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and valid(pair.station) and pair.station.unit_number or nil
end

local function conversation_locked(pair)
  if not pair then return false end
  if pair.idle_conversation then return true end
  if pair.idle_conversation_listener_until and now() < pair.idle_conversation_listener_until then return true end
  if pair.idle_conversation_speaker_station_unit then return true end
  if pair.idle_conversation_lock_position_0179 then return true end
  local mode = lower(pair.mode)
  return mode:find("conversation", 1, true) ~= nil or mode:find("convers", 1, true) ~= nil
end

local function normalize_kind(kind)
  local k = lower(kind)
  if k == "" then return "idle" end
  if k:find("combat", 1, true) or k:find("defend", 1, true) or k:find("laser%-fallback") then return "combat" end
  if k:find("repair", 1, true) then return "repair" end
  if k:find("consecr", 1, true) or k:find("sanct", 1, true) then return "consecration" end
  if k:find("assign", 1, true) then return "assignment" end
  if k:find("logistic", 1, true) or k:find("supply", 1, true) then return "logistics" end
  if k:find("scavenge", 1, true) then return "scavenge" end
  if k:find("mine", 1, true) or k:find("acqui", 1, true) or k:find("gather", 1, true) or k:find("resource", 1, true) then return "acquisition" end
  if k:find("emergency", 1, true) or k:find("craft", 1, true) then return "emergency_craft" end
  return k
end

local active_work_fields = {
  "active_task",
  "active_task_0285",
  "assignment_0252",
  "emergency_assist_job_0187",
  "scavenge",
  "inventory_scan",
  "direct_acquisition_task_0336",
  "active_acquisition_0333",
  "station_crafting_task_0337",
  "station_craft_lock_0337",
  "crafting_lock_0418",
}

local function has_live_movement(pair)
  local req = pair and pair.movement_request_0418
  if type(req) == "table" and (not req.expires_tick or req.expires_tick >= now()) then return true, "movement-request" end
  if pair and pair.last_direct_mine_command_0336 and now() - (pair.last_direct_mine_command_0336.tick or 0) < 180 then return true, "direct-mine-command" end
  if pair and pair.movement_controller_state_0418 and lower(pair.movement_controller_state_0418):find("moving", 1, true) then return true, "movement-state" end
  return false, nil
end

local function has_lower_execution_surface(pair)
  if not pair then return false, nil end
  for _, k in ipairs(active_work_fields) do
    if pair[k] ~= nil then return true, k end
  end
  if pair.emergency_craft and type(pair.emergency_craft) == "table" then return true, "emergency_craft" end
  local moving, why = has_live_movement(pair)
  if moving then return true, why end
  return false, nil
end

local low_execution_kinds = {
  logistics = true,
  acquisition = true,
  gather = true,
  direct_mine = true,
  scavenge = true,
  emergency_craft = true,
  assignment = true,
}

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return pair and (pair.active_order_0469 or (q and q.current)) or nil
end

local function current_signature(pair)
  local order = current_order(pair)
  if order then return safe(order.key) .. "|" .. safe(order.item) .. "|" .. safe(order.kind) end
  return "none"
end

local function should_reactivate(pair)
  if not valid_pair(pair) then return false, "invalid" end
  if conversation_locked(pair) then return false, "conversation" end
  local order = current_order(pair)
  if not order then return false, "no-current-order" end
  local kind = normalize_kind(order.kind or order.type or order.source)
  if not low_execution_kinds[kind] then return false, "high-authority-kind" end
  local surface, why = has_lower_execution_surface(pair)
  if surface then return false, "has-" .. tostring(why) end
  local mode = lower(pair.mode)
  if mode:find("combat", 1, true) or mode:find("defend", 1, true) or mode:find("laser%-fallback") then return false, "combat-mode" end
  local age = now() - (tonumber(order.activated_tick or order.created_tick or now()) or now())
  local threshold = math.floor(setting_seconds("tech-priests-order-execution-watchdog-seconds", M.default_watchdog_seconds, 2, 600) * 60)
  if age < threshold then return false, "young-order" end
  return true, "active-order-without-executor"
end

local function call_pre_queue_acquire(pair, order, reason)
  local fn = rawget(_G, "TECH_PRIESTS_0469_PRE_EMERGENCY_ACQUIRE") or rawget(_G, "TECH_PRIESTS_0333_PRE_EMERGENCY_ACQUIRE")
  if type(fn) ~= "function" then return false, "no-prequeue-acquire" end
  local item = order and (order.item or order.wanted_item or order.requested_item)
  if not item then return false, "no-item" end
  local ok, result = pcall(fn, pair, item, order.op, order.count or 1, order.depth or 0)
  if ok and result then return true, "prequeue-acquire" end
  return false, ok and "false-return" or safe(result)
end

function M.service_pair(pair)
  if not enabled() or not valid_pair(pair) then return false end
  local needed, reason = should_reactivate(pair)
  if not needed then return false end

  local order = current_order(pair)
  pair.execution_watchdog_0477 = pair.execution_watchdog_0477 or {}
  local w = pair.execution_watchdog_0477
  local next_tick = tonumber(w.next_tick or 0) or 0
  if now() < next_tick then return false end
  w.next_tick = now() + math.floor(setting_seconds("tech-priests-order-execution-watchdog-seconds", M.default_watchdog_seconds, 2, 600) * 60)
  w.last_reason = reason
  w.last_key = order and order.key
  w.last_item = order and order.item
  w.attempts = (tonumber(w.attempts or 0) or 0) + 1
  w.last_tick = now()

  local oq = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
  local ok, how = false, "no-order-reactivator"
  if oq and type(oq.reactivate_current) == "function" then
    ok, how = oq.reactivate_current(pair, "execution-watchdog-0477")
  end
  if not ok then
    local fallback_ok, fallback_how = call_pre_queue_acquire(pair, order, "execution-watchdog-0477")
    if fallback_ok then ok, how = true, fallback_how else how = tostring(how) .. "/" .. tostring(fallback_how) end
  end

  w.last_result = how
  if ok then
    stat("reactivated")
    pair.mode = pair.mode == "idle" and "emergency-gathering" or pair.mode
    return true
  end

  stat("reactivation_failed")
  local attempts = tonumber(order and order.reactivate_attempts_0477 or w.attempts) or 0
  if attempts >= M.max_reactivate_attempts_before_fail and oq and type(oq.fail_current) == "function" then
    oq.fail_current(pair, "execution-watchdog-0477-activation-failed")
    stat("failed_stuck_order")
  end
  return false
end

function M.tick_all()
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then pcall(function() M.service_pair(pair) end) end
  end
end

local function event_is_station_switch(event)
  local e = lower(event)
  return e == "station_task_switch" or e == "task_switch" or e:find("task%-switch", 1, false) ~= nil or e:find("station.*switch") ~= nil
end

function M.wrap_sound_manager()
  local sm = rawget(_G, "TECH_PRIESTS_SOUND_MANAGER_0475")
  if not (sm and type(sm.emit) == "function") then return false end
  if sm.execution_governor_wrapped_0477 then return true end
  original_sound_emit = sm.emit
  sm.execution_governor_wrapped_0477 = true
  sm.emit = function(pair, event, opts)
    opts = opts or {}
    if valid_pair(pair) then
      local e = lower(event)
      local sig = current_signature(pair)
      if event_is_station_switch(event) then
        local cd = math.floor(setting_seconds("tech-priests-station-task-switch-sound-cooldown-seconds", M.default_task_switch_cooldown_seconds, 1, 3600) * 60)
        if pair.last_station_switch_sig_0477 == sig then
          stat("station_switch_same_suppressed")
          return false, "0477-same-stable-task"
        end
        if now() < (tonumber(pair.next_station_switch_sound_0477 or 0) or 0) then
          stat("station_switch_cooldown_suppressed")
          return false, "0477-task-switch-cooldown"
        end
        pair.last_station_switch_sig_0477 = sig
        pair.next_station_switch_sound_0477 = now() + cd
        opts.cooldown_key = opts.cooldown_key or ("0477-station-switch:" .. safe(station_unit(pair)))
        opts.cooldown_ticks = math.max(tonumber(opts.cooldown_ticks or 0) or 0, cd)
      elseif e == "writ_issued" then
        local cd = math.floor(setting_seconds("tech-priests-writ-audio-cooldown-seconds", M.default_writ_audio_cooldown_seconds, 1, 3600) * 60)
        local key = safe(opts.key or opts.item or sig)
        if pair.last_writ_sound_key_0477 == key and now() < (tonumber(pair.next_writ_sound_0477 or 0) or 0) then
          stat("writ_same_suppressed")
          return false, "0477-duplicate-writ-audio"
        end
        if now() < (tonumber(pair.next_any_writ_sound_0477 or 0) or 0) then
          stat("writ_cadence_suppressed")
          return false, "0477-writ-audio-cadence"
        end
        pair.last_writ_sound_key_0477 = key
        pair.next_writ_sound_0477 = now() + cd
        pair.next_any_writ_sound_0477 = now() + math.min(cd, 60 * 10)
        opts.cooldown_key = opts.cooldown_key or ("0477-writ:" .. safe(station_unit(pair)) .. ":" .. key)
        opts.cooldown_ticks = math.max(tonumber(opts.cooldown_ticks or 0) or 0, cd)
      end
    end
    return original_sound_emit(pair, event, opts)
  end
  _G.TECH_PRIESTS_SOUND_MANAGER_0475 = sm
  return true
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") then return false end
  if diag.execution_watchdog_wrapped_0477 then return true end
  local prev = diag.pair_dump_lines
  diag.execution_watchdog_wrapped_0477 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    lines[#lines + 1] = "EXECUTION-WATCHDOG-0477 BEGIN enabled=" .. safe(enabled())
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local order = current_order(pair)
        local surface, why = has_lower_execution_surface(pair)
        local w = pair.execution_watchdog_0477 or {}
        lines[#lines + 1] = "exec[" .. safe(key) .. "] current=" .. safe(order and order.key or "none") .. " item=" .. safe(order and order.item) .. " mode=" .. safe(pair.mode) .. " lower_surface=" .. safe(surface and why or "none") .. " last=" .. safe(w.last_result) .. " attempts=" .. safe(w.attempts or (order and order.reactivate_attempts_0477))
      end
    end
    lines[#lines + 1] = "EXECUTION-WATCHDOG-0477 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  if not (player and player.valid and storage and storage.tech_priests) then return nil end
  local e = player.selected
  if valid(e) then
    return (storage.tech_priests.pairs_by_station or {})[e.unit_number] or (storage.tech_priests.pairs_by_priest or {})[e.unit_number]
  end
  return nil
end

function M.describe(pair)
  local r = root()
  local lines = {}
  lines[#lines + 1] = "enabled=" .. safe(r.enabled) .. " reactivated=" .. safe(r.stats.reactivated or 0) .. " failed=" .. safe(r.stats.reactivation_failed or 0) .. " switch-suppressed=" .. safe((r.stats.station_switch_same_suppressed or 0) + (r.stats.station_switch_cooldown_suppressed or 0)) .. " writ-suppressed=" .. safe((r.stats.writ_same_suppressed or 0) + (r.stats.writ_cadence_suppressed or 0))
  if pair and valid_pair(pair) then
    local needed, reason = should_reactivate(pair)
    local order = current_order(pair)
    local surface, why = has_lower_execution_surface(pair)
    local w = pair.execution_watchdog_0477 or {}
    lines[#lines + 1] = "current=" .. safe(order and order.key or "none") .. " item=" .. safe(order and order.item) .. " mode=" .. safe(pair.mode) .. " needs-reactivation=" .. safe(needed) .. " reason=" .. safe(reason)
    lines[#lines + 1] = "lower-surface=" .. safe(surface and why or "none") .. " last-result=" .. safe(w.last_result) .. " attempts=" .. safe(w.attempts or (order and order.reactivate_attempts_0477))
    lines[#lines + 1] = "sound-sig=" .. safe(pair.last_station_switch_sig_0477) .. " next-station-sound=" .. safe(pair.next_station_switch_sound_0477) .. " next-writ-sound=" .. safe(pair.next_writ_sound_0477)
  end
  return lines
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-execution-watchdog-0477") end end)
  pcall(function()
    commands.add_command("tp-execution-watchdog-0477", "Tech Priests 0.1.477: inspect/toggle active-order execution watchdog and task-switch audio governor. Usage: status|all|on|off|kick", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local param = lower(event and event.parameter or "status")
      local r = root()
      if param == "off" or param == "disable" then r.enabled = false end
      if param == "on" or param == "enable" then r.enabled = true end
      local pair = selected_pair(player)
      if param == "kick" and pair then M.service_pair(pair) end
      if player and player.valid then
        if param == "all" then
          for _, p in pairs(pair_map()) do
            for _, line in ipairs(M.describe(p)) do player.print("[tp-execution-watchdog-0477] " .. line) end
          end
        else
          for _, line in ipairs(M.describe(pair)) do player.print("[tp-execution-watchdog-0477] " .. line) end
          if not pair then player.print("[tp-execution-watchdog-0477] select a Cogitator Station or Tech-Priest for pair-local status.") end
        end
      end
    end)
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.wrap_sound_manager()
  M.wrap_diagnostics()
  _G.TECH_PRIESTS_TASK_EXECUTION_SOUND_GOVERNOR_0477 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick_all() end, { owner = "task_execution_sound_governor_0477", category = "scheduler", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.tick_all() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.477] active-order execution watchdog and task-switch audio governor installed") end
  return true
end

return M
