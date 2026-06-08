-- scripts/core/task_transition_governor.lua
-- Tech Priests 0.1.447 task-transition/cogitation governor setting attachment repair.
--
-- Purpose:
--   The visible Speedy-Gonzales symptom is often not raw movement speed. It is
--   rapid low-priority task churn: resource doctrine, mouse-over refresh,
--   subordinate assignment, idle scan, direct gathering, and return logic can all
--   re-label the same pair inside a very small tick window. This module does not
--   delete the old wrapper chain. It observes the pair state, records churn, and
--   applies a short cogitation delay to ordinary task transitions so movement
--   authority has time to settle.
--
-- Doctrine:
--   * Combat, death/recovery, invalid-pair recovery, and emergency operations are
--     never delayed.
--   * Ordinary supply/resource/idle/return/consecration transitions may be held.
--   * The delay is visible through priest status bubbles and Work State output.
--   * The governor does not teleport or snap priests. Movement_controller sees
--     the lock and stops/loiters during the cogitation window.

local M = {}

M.version = "0.1.448"
M.storage_key = "task_transition_governor_0445"
M.service_ticks = 10
M.default_delay_ticks = 45
M.repeated_churn_delay_ticks = 90
M.max_delay_ticks = 150
M.minimum_stable_ticks = 30
M.history_limit = 8
M.low_priority_threshold = 800

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    pairs = {}
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.pairs = root.pairs or {}
  return root
end

local function pairs_by_station()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function pair_key(pair)
  if pair and valid(pair.station) and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if pair and valid(pair.priest) and pair.priest.unit_number then return "p" .. tostring(pair.priest.unit_number) end
  return nil
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  if _G.tech_priests_get_selected_pair_0247 then
    local ok, pair = pcall(_G.tech_priests_get_selected_pair_0247, player)
    if ok and pair then return pair end
  end
  if _G.selected_pair_for_player then
    local ok, pair = pcall(_G.selected_pair_for_player, player)
    if ok and pair then return pair end
  end
  local selected = player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  if _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  return nil
end

local function safe_text(value)
  value = tostring(value or "")
  value = value:gsub("\n", " ")
  if #value > 120 then value = value:sub(1, 117) .. "..." end
  return value
end

local function active_task_signature(pair)
  if not pair then return "none" end
  local task = pair.active_task or pair.active_task_0285
  if type(task) == "table" then
    return table.concat({
      safe_text(task.type or task.kind or "task"),
      safe_text(task.phase or task.key or "phase"),
      safe_text(task.item or task.item_name or task.output_item or "")
    }, ":")
  end
  if pair.emergency_craft then
    local t = pair.emergency_craft
    return "emergency-craft:" .. safe_text(t.output_item or t.item_name or t.craft_item or "?")
  end
  if pair.scavenge then return "scavenge:" .. safe_text(pair.scavenge.item_name or pair.scavenge.item or "?") end
  if pair.inventory_scan then return "inventory-scan:" .. safe_text(pair.inventory_scan.item_name or pair.inventory_scan.item or "?") end
  if pair.logistic_requested_item then return "logistics:" .. safe_text(pair.logistic_requested_item) end
  return "none"
end

local function current_mode(pair)
  if not pair then return "nil" end
  return tostring(pair.visual_state_0276 or pair.mode or pair.task_phase_0276 or "idle")
end

local function current_signature(pair)
  local mode = current_mode(pair)
  local kind = pair and tostring(pair.task_kind_0276 or "") or ""
  local phase = pair and tostring(pair.task_phase_0276 or "") or ""
  local task = active_task_signature(pair)
  return mode .. "|" .. kind .. "|" .. phase .. "|" .. task, mode, kind, phase, task
end

local function mode_priority(mode, pair)
  mode = tostring(mode or "idle")
  if mode:find("death", 1, true) or mode:find("respawn", 1, true) or mode:find("recovery", 1, true) or mode:find("invalid", 1, true) then return 1000 end
  if mode:find("laser%-fallback") then
    local target = pair and (pair.combat_target or pair.target)
    local priest_force = pair and pair.priest and pair.priest.valid and pair.priest.force or nil
    if target and target.valid and target.force and priest_force and target.force ~= priest_force and tostring(target.force.name) ~= "neutral" then return 950 end
    return 520
  end
  if mode:find("combat", 1, true) or mode:find("defending", 1, true) or mode:find("attack", 1, true) then return 950 end
  if mode:find("emergency", 1, true) then return 860 end
  if mode:find("repair", 1, true) then return 760 end
  if mode:find("consecrat", 1, true) or mode:find("sanct", 1, true) then return 680 end
  if mode:find("supply", 1, true) or mode:find("logistic", 1, true) or mode:find("scavenge", 1, true) or mode:find("cram", 1, true) then return 520 end
  if mode:find("mine", 1, true) or mode:find("resource", 1, true) or mode:find("gather", 1, true) then return 500 end
  if mode:find("return", 1, true) or mode:find("deploy", 1, true) then return 420 end
  if mode:find("idle", 1, true) or mode == "no-managed-priority-claimed" or mode == "scheduler-0277" then return 120 end
  return 300
end

function M.mode_priority(mode, pair)
  return mode_priority(mode, pair)
end

function M.is_urgent_mode(mode, pair)
  return mode_priority(mode, pair) >= M.low_priority_threshold
end

local function is_pair_valid_enough(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function pair_rec(pair)
  local key = pair_key(pair)
  if not key then return nil end
  local root = ensure_root()
  root.pairs[key] = root.pairs[key] or { history = {} }
  local rec = root.pairs[key]
  rec.station_unit = pair.station and pair.station.unit_number or rec.station_unit
  rec.priest_unit = pair.priest and pair.priest.unit_number or rec.priest_unit
  return rec, root, key
end

local function push_history(rec, entry)
  rec.history = rec.history or {}
  table.insert(rec.history, 1, entry)
  while #rec.history > M.history_limit do table.remove(rec.history) end
end

local function delay_for(rec)
  local churn = tonumber(rec.churn_count_window or 0) or 0
  if churn >= 3 then return M.repeated_churn_delay_ticks end
  return M.default_delay_ticks
end

local function export_to_pair(pair, rec)
  if not pair then return end
  pair.task_transition_governor_0445 = {
    version = M.version,
    enabled = true,
    locked_until = rec.lock_until,
    pending_mode = rec.pending_mode,
    pending_signature = rec.pending_signature,
    previous_mode = rec.previous_mode,
    stable_mode = rec.stable_mode,
    stable_signature = rec.stable_signature,
    last_change_tick = rec.last_change_tick,
    suppressed_count = rec.suppressed_count,
    churn_count_window = rec.churn_count_window,
    last_source = rec.last_source,
    last_reason = rec.last_reason,
    status_symbol = M.status_symbol_for_record(rec)
  }
end

function M.status_symbol_for_record(rec)
  if not rec then return "" end
  local remaining = 0
  if rec.lock_until then remaining = math.max(0, math.ceil((rec.lock_until - now()) / 60)) end
  if remaining <= 0 then return "" end
  return "⏳" .. tostring(remaining) .. "s"
end

function M.observe(pair, source)
  local root = ensure_root()
  if root.enabled == false then return true end
  if not is_pair_valid_enough(pair) then return true end

  local rec, _, key = pair_rec(pair)
  if not rec then return true end

  local sig, mode, kind, phase, task = current_signature(pair)
  local tick = now()
  rec.last_source = tostring(source or "observe")

  if not rec.stable_signature then
    rec.stable_signature = sig
    rec.stable_mode = mode
    rec.last_signature = sig
    rec.last_mode = mode
    rec.last_change_tick = tick
    rec.last_accepted_tick = tick
    rec.churn_count_window = 0
    export_to_pair(pair, rec)
    return true
  end

  if sig == rec.last_signature then
    rec.last_seen_tick = tick
    if rec.churn_reset_tick and tick >= rec.churn_reset_tick then rec.churn_count_window = 0 end
    export_to_pair(pair, rec)
    return true
  end

  local old_mode = rec.last_mode or rec.stable_mode or "idle"
  local old_priority = mode_priority(old_mode, pair)
  local new_priority = mode_priority(mode, pair)
  local urgent = old_priority >= M.low_priority_threshold or new_priority >= M.low_priority_threshold
  local since_accept = tick - (tonumber(rec.last_accepted_tick) or tick)

  rec.previous_mode = old_mode
  rec.last_signature = sig
  rec.last_mode = mode
  rec.last_change_tick = tick
  rec.churn_count_window = (tonumber(rec.churn_count_window) or 0) + 1
  rec.churn_reset_tick = tick + 240

  push_history(rec, {
    tick = tick,
    from = old_mode,
    to = mode,
    kind = kind,
    phase = phase,
    task = task,
    source = tostring(source or "observe"),
    priority = new_priority
  })

  if urgent then
    rec.stable_signature = sig
    rec.stable_mode = mode
    rec.last_accepted_tick = tick
    rec.lock_until = nil
    rec.pending_mode = nil
    rec.pending_signature = nil
    rec.last_reason = "urgent-immediate"
    root.stats.urgent_passes = (root.stats.urgent_passes or 0) + 1
    export_to_pair(pair, rec)
    return true
  end

  if since_accept < M.minimum_stable_ticks then
    local delay = math.min(M.max_delay_ticks, delay_for(rec))
    rec.lock_until = math.max(tonumber(rec.lock_until) or 0, tick + delay)
    rec.pending_mode = mode
    rec.pending_signature = sig
    rec.last_reason = "ordinary-task-transition-cooldown"
    rec.suppressed_count = (tonumber(rec.suppressed_count) or 0) + 1
    root.stats.cooldowns = (root.stats.cooldowns or 0) + 1
    root.last_cooldown = { tick = tick, station = pair.station.unit_number, priest = pair.priest.unit_number, from = old_mode, to = mode, source = tostring(source or "observe"), until_tick = rec.lock_until }
    export_to_pair(pair, rec)
    return false
  end

  rec.stable_signature = sig
  rec.stable_mode = mode
  rec.last_accepted_tick = tick
  rec.lock_until = nil
  rec.pending_mode = nil
  rec.pending_signature = nil
  rec.last_reason = "accepted-stable-transition"
  export_to_pair(pair, rec)
  return true
end

function M.is_locked(pair)
  if not is_pair_valid_enough(pair) then return false end
  local rec = pair_rec(pair)
  if not rec then return false end
  return (tonumber(rec.lock_until) or 0) > now()
end

function M.remaining_ticks(pair)
  local rec = pair_rec(pair)
  if not rec then return 0 end
  return math.max(0, (tonumber(rec.lock_until) or 0) - now())
end

function M.clamp_reason(pair)
  if M.is_locked(pair) then return "task-transition-cogitation" end
  return nil
end

function M.describe_pair(pair)
  local lines = {}
  local rec = pair_rec(pair)
  if not rec then return { "Task transition governor: no pair record yet." } end
  local remaining = math.max(0, (tonumber(rec.lock_until) or 0) - now())
  if remaining > 0 then
    lines[#lines + 1] = "Task transition governor: " .. M.status_symbol_for_record(rec) .. " cogitating; movement held for " .. tostring(math.ceil(remaining / 60)) .. "s"
    lines[#lines + 1] = "  stable=" .. tostring(rec.stable_mode or "?") .. " -> pending=" .. tostring(rec.pending_mode or rec.last_mode or "?") .. " source=" .. tostring(rec.last_source or "?")
  else
    lines[#lines + 1] = "Task transition governor: ready; stable=" .. tostring(rec.stable_mode or rec.last_mode or "idle")
  end
  lines[#lines + 1] = "  churn-window=" .. tostring(rec.churn_count_window or 0) .. " suppressed=" .. tostring(rec.suppressed_count or 0) .. " reason=" .. tostring(rec.last_reason or "none")
  if rec.history and #rec.history > 0 then
    local limit = math.min(4, #rec.history)
    for i = 1, limit do
      local h = rec.history[i]
      lines[#lines + 1] = "  #" .. tostring(i) .. " " .. tostring(h.from or "?") .. " -> " .. tostring(h.to or "?") .. " [" .. tostring(h.source or "?") .. "]"
    end
  end
  return lines
end

function M.service()
  ensure_root()
  for _, pair in pairs(pairs_by_station()) do
    if is_pair_valid_enough(pair) then M.observe(pair, "service") end
  end
end

function M.wrap_globals()
  _G.TECH_PRIESTS_TASK_TRANSITION_GOVERNOR_0445 = M
  _G.tech_priests_0445_task_transition_locked = function(pair) return M.is_locked(pair) end
  _G.tech_priests_0445_task_transition_describe = function(pair) return M.describe_pair(pair) end
  _G.tech_priests_0445_task_transition_observe = function(pair, source) return M.observe(pair, source) end

  if _G.tech_priests_set_pair_task_0276 and not _G.TECH_PRIESTS_0445_PREVIOUS_SET_PAIR_TASK_0276 then
    _G.TECH_PRIESTS_0445_PREVIOUS_SET_PAIR_TASK_0276 = _G.tech_priests_set_pair_task_0276
    _G.tech_priests_set_pair_task_0276 = function(pair, task_kind, task_phase, visual_state, target, task_owner)
      local result = _G.TECH_PRIESTS_0445_PREVIOUS_SET_PAIR_TASK_0276(pair, task_kind, task_phase, visual_state, target, task_owner)
      if pair then M.observe(pair, "set-pair-task-0276") end
      return result
    end
  end

  if _G.tech_priests_clear_pair_task_0276 and not _G.TECH_PRIESTS_0445_PREVIOUS_CLEAR_PAIR_TASK_0276 then
    _G.TECH_PRIESTS_0445_PREVIOUS_CLEAR_PAIR_TASK_0276 = _G.tech_priests_clear_pair_task_0276
    _G.tech_priests_clear_pair_task_0276 = function(pair, visual_state)
      local result = _G.TECH_PRIESTS_0445_PREVIOUS_CLEAR_PAIR_TASK_0276(pair, visual_state)
      if pair then M.observe(pair, "clear-pair-task-0276") end
      return result
    end
  end

  if _G.classify_priest_visual_state and not _G.TECH_PRIESTS_0445_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE then
    _G.TECH_PRIESTS_0445_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE = _G.classify_priest_visual_state
    _G.classify_priest_visual_state = function(pair)
      if M.is_locked(pair) then return "task-transition-cooldown" end
      return _G.TECH_PRIESTS_0445_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE(pair)
    end
  end

  if _G.get_priest_status_setting_name and not _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SETTING_NAME then
    _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SETTING_NAME = _G.get_priest_status_setting_name
    _G.get_priest_status_setting_name = function(state)
      if state == "task-transition-cooldown" then return "tech-priests-priest-status-symbol-task-transition-cooldown" end
      return _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SETTING_NAME(state)
    end
  end

  if _G.get_priest_status_fallback_symbol and not _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_FALLBACK_SYMBOL then
    _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_FALLBACK_SYMBOL = _G.get_priest_status_fallback_symbol
    _G.get_priest_status_fallback_symbol = function(state)
      if state == "task-transition-cooldown" then return "⏳{task_seconds}" end
      return _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_FALLBACK_SYMBOL(state)
    end
  end

  if _G.get_priest_status_symbol and not _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SYMBOL then
    _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SYMBOL = _G.get_priest_status_symbol
    _G.get_priest_status_symbol = function(pair)
      if M.is_locked(pair) then
        local remaining = math.max(0, math.ceil(M.remaining_ticks(pair) / 60))
        local state = "task-transition-cooldown"
        local raw = "⏳{task_seconds}s"
        if read_global_string_setting then
          raw = read_global_string_setting("tech-priests-priest-status-symbol-task-transition-cooldown", raw)
        end
        local symbol = raw
        if choose_priest_status_variant then
          symbol = choose_priest_status_variant(raw, pair, state)
        end
        symbol = tostring(symbol or raw)
        symbol = symbol:gsub("{task_seconds}", tostring(remaining))
        symbol = symbol:gsub("{seconds}", tostring(remaining))
        return symbol
      end
      return _G.TECH_PRIESTS_0445_PREVIOUS_STATUS_SYMBOL(pair)
    end
  end
end

function M.commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-task-governor-0445") end)
  commands.add_command("tp-task-governor-0445", "Tech Priests 0.1.445 task transition governor: status|enable|disable|reset", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = tostring(event and event.parameter or "status")
    local root = ensure_root()
    if param == "enable" then root.enabled = true end
    if param == "disable" then root.enabled = false end
    if param == "reset" then root.pairs = {}; root.stats = {} end
    if player and player.valid then
      local pair = selected_pair(player)
      player.print("[tp-task-governor-0445] enabled=" .. tostring(root.enabled) .. " cooldowns=" .. tostring(root.stats.cooldowns or 0) .. " urgent=" .. tostring(root.stats.urgent_passes or 0))
      if pair then
        for _, line in ipairs(M.describe_pair(pair)) do player.print("  " .. tostring(line)) end
      else
        player.print("  Select a Cogitator Station or Tech-Priest for pair-specific task-churn status.")
      end
    end
  end)
end

function M.install()
  ensure_root()
  M.wrap_globals()
  M.commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.service_ticks, function() M.service() end, { owner = "task_transition_governor", category = "scheduler", note = "visible cogitation cooldown for ordinary task churn" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_ticks, function() M.service() end)
  end
  if log then log("[Tech-Priests 0.1.448] task-transition governor installed; ordinary retarget churn displays as cogitation without freezing current route") end
  return true
end

return M
