-- scripts/core/behavior_mutex_0466.lua
-- Tech Priests 0.1.466
-- Late behavior mutex for live validation: combat/defense and acquisition/direct
-- mining must not render or execute at the same time.  Combat remains the top of
-- the activity stack; acquisition work is paused, not destroyed, while a valid
-- hostile combat target is active.

local M = {}
M.version = "0.1.466"
M.storage_key = "behavior_mutex_0466"
M.combat_hold_ticks = 90
M.invalid_target_log_ticks = 180

local CombatSafety = nil
pcall(function() CombatSafety = require("scripts.core.combat_safety") end)

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, stats = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.stats = root.stats or {}
  return root
end

local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function pair_for_priest(priest)
  if not valid(priest) then return nil end
  if storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then
    local pair = storage.tech_priests.pairs_by_priest[priest.unit_number]
    if pair then return pair end
  end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, priest); if ok and pair then return pair end end
  return nil
end

local function entity_name(entity)
  if not entity then return "nil" end
  local ok, name = pcall(function() return entity.name end)
  return ok and tostring(name) or tostring(entity)
end

local function force_name(force)
  if not force then return "nil" end
  local ok, name = pcall(function() return force.name end)
  return ok and tostring(name) or tostring(force)
end

local function mode_text(pair)
  return tostring(pair and (pair.visual_state_0276 or pair.mode or pair.task_phase_0276 or "") or "")
end

local function combatish_mode(pair)
  local mode = string.lower(mode_text(pair))
  if mode == "combat" or mode == "defending" or mode == "moving-to-combat" then return true end
  if mode:find("combat", 1, true) then return true end
  if mode:find("defending", 1, true) then return true end
  if mode:find("laser%-fallback") then return true end
  return false
end

local function active_task_kind(pair)
  local task = pair and (pair.active_task or pair.active_task_0285) or nil
  if type(task) == "table" then return tostring(task.kind or task.type or "") end
  if task ~= nil then return tostring(task) end
  return tostring(pair and (pair.task_kind or pair.task_kind_0276 or "") or "")
end

function M.is_hostile(pair, target)
  if not (pair and target and target.valid) then return false end
  if CombatSafety and CombatSafety.is_valid_hostile_target then
    local ok, hostile = pcall(CombatSafety.is_valid_hostile_target, pair.priest or pair.station or pair, target)
    if ok then return hostile == true end
  end
  local owner_force = pair.priest and pair.priest.valid and pair.priest.force or (pair.station and pair.station.valid and pair.station.force)
  local target_force = target.force
  if not (owner_force and target_force) then return false end
  if owner_force == target_force then return false end
  if target_force.name == "neutral" then return false end
  local hostile = false
  pcall(function() if owner_force.is_enemy then hostile = owner_force.is_enemy(target_force) end end)
  return hostile == true
end

function M.clear_invalid_combat_target(pair, reason)
  if not pair then return false end
  local changed = false
  local target = pair.combat_target
  if target and target.valid and not M.is_hostile(pair, target) then
    pair.combat_target = nil
    changed = true
  end
  target = pair.target
  if combatish_mode(pair) and target and target.valid and not M.is_hostile(pair, target) then
    pair.target = nil
    changed = true
  end
  if changed then
    pair.last_invalid_combat_target_clear_0466 = { tick = now(), reason = reason or "invalid-combat-target" }
    if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.shooting_target = nil end) end
    local root = ensure_root()
    root.stats.invalid_combat_targets_cleared = (root.stats.invalid_combat_targets_cleared or 0) + 1
    if now() >= (pair.next_mutex_invalid_target_log_0466 or 0) then
      pair.next_mutex_invalid_target_log_0466 = now() + M.invalid_target_log_ticks
      if log then log("[Tech-Priests 0.1.466 mutex] cleared invalid combat target for station=" .. safe(pair.station and pair.station.unit_number) .. " mode=" .. mode_text(pair) .. " reason=" .. safe(reason)) end
    end
  end
  return changed
end

function M.combat_active(pair)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  M.clear_invalid_combat_target(pair, "combat-active-check")
  local target = (pair.combat_target and pair.combat_target.valid and pair.combat_target) or (pair.target and pair.target.valid and pair.target) or nil
  local hostile = target and M.is_hostile(pair, target)
  local kind = string.lower(active_task_kind(pair))
  if hostile and (combatish_mode(pair) or kind == "combat") then
    pair.combat_mutex_until_0466 = math.max(pair.combat_mutex_until_0466 or 0, now() + M.combat_hold_ticks)
    return true
  end
  if now() < (pair.combat_mutex_until_0466 or 0) then return true end
  return false
end

function M.pause_acquisition_for_combat(pair, reason)
  if not M.combat_active(pair) then return false end
  pair.acquisition_paused_by_combat_0466 = { tick = now(), reason = reason or "combat-preempts-acquisition", mode = mode_text(pair) }
  pair.inventory_scan = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  pair.active_supply_request = nil
  pair.active_acquisition_0333 = nil
  pair.acquisition_repair_task_0333 = nil
  pair.direct_acquisition_task_0336 = nil
  pair.scheduler_acquisition_op_0287 = nil
  -- Do not destroy emergency_craft itself; it may be the work to resume after
  -- combat.  The executor and direct-mining laser wrappers below simply refuse
  -- to run it while combat owns the pair.
  local root = ensure_root()
  root.stats.acquisition_pauses = (root.stats.acquisition_pauses or 0) + 1
  return true
end

local function pair_from_scan_args(pair_or_priest)
  if type(pair_or_priest) == "table" and pair_or_priest.station and pair_or_priest.priest then return pair_or_priest end
  if valid(pair_or_priest) then return pair_for_priest(pair_or_priest) end
  return nil
end

function M.wrap_globals()
  if _G.draw_emergency_craft_scan_line and not _G.TECH_PRIESTS_0466_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE then
    _G.TECH_PRIESTS_0466_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE = _G.draw_emergency_craft_scan_line
    _G.draw_emergency_craft_scan_line = function(pair, target_entity)
      if M.pause_acquisition_for_combat(pair, "scan-line-suppressed") then return nil end
      return _G.TECH_PRIESTS_0466_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE(pair, target_entity)
    end
  end

  if _G.handle_emergency_desperation_craft and not _G.TECH_PRIESTS_0466_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT then
    _G.TECH_PRIESTS_0466_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT = _G.handle_emergency_desperation_craft
    _G.handle_emergency_desperation_craft = function(pair)
      if M.pause_acquisition_for_combat(pair, "emergency-craft-suppressed") then return false end
      return _G.TECH_PRIESTS_0466_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT(pair)
    end
  end

  if _G.tech_priests_0312_fire_laser and not _G.TECH_PRIESTS_0466_PRE_0312_FIRE_LASER then
    _G.TECH_PRIESTS_0466_PRE_0312_FIRE_LASER = _G.tech_priests_0312_fire_laser
    _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
      local reason_text = tostring(reason or "")
      local pair = pair_for_priest(priest)
      local direct = reason_text:find("direct%-mining") or reason_text:find("direct%-dirt") or reason_text:find("legacy%-direct")
      if direct and M.pause_acquisition_for_combat(pair, "direct-laser-suppressed") then return false end
      if (not direct) and pair and target and target.valid and not M.is_hostile(pair, target) then
        M.clear_invalid_combat_target(pair, "fallback-laser-invalid-target")
        local root = ensure_root()
        root.stats.invalid_fallback_lasers_blocked = (root.stats.invalid_fallback_lasers_blocked or 0) + 1
        return false
      end
      return _G.TECH_PRIESTS_0466_PRE_0312_FIRE_LASER(priest, target, damage, reason, color)
    end
  end

  if _G.tech_priests_0312_fallback_combat_laser and not _G.TECH_PRIESTS_0466_PRE_0312_FALLBACK_COMBAT_LASER then
    _G.TECH_PRIESTS_0466_PRE_0312_FALLBACK_COMBAT_LASER = _G.tech_priests_0312_fallback_combat_laser
    _G.tech_priests_0312_fallback_combat_laser = function(pair, target, reason)
      target = (target and target.valid and target) or pair and ((pair.combat_target and pair.combat_target.valid and pair.combat_target) or (pair.target and pair.target.valid and pair.target)) or nil
      if target and target.valid and not M.is_hostile(pair, target) then
        M.clear_invalid_combat_target(pair, "fallback-combat-invalid-target")
        return false
      end
      local ok = _G.TECH_PRIESTS_0466_PRE_0312_FALLBACK_COMBAT_LASER(pair, target, reason)
      if ok then M.pause_acquisition_for_combat(pair, "fallback-combat-active") end
      return ok
    end
  end

  if _G.tech_priests_0293_force_combat_tick and not _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK then
    _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK = _G.tech_priests_0293_force_combat_tick
    _G.tech_priests_0293_force_combat_tick = function(pair, reason, force)
      M.clear_invalid_combat_target(pair, "before-force-combat")
      local ok = _G.TECH_PRIESTS_0466_PRE_0293_FORCE_COMBAT_TICK(pair, reason, force)
      if ok then M.pause_acquisition_for_combat(pair, "force-combat-active") end
      return ok
    end
    _G.tech_priests_0292_force_combat_tick = _G.tech_priests_0293_force_combat_tick
  end
end

function M.wrap_modules()
  local ok_exec, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok_exec and Exec and Exec.service_pair and not Exec.TECH_PRIESTS_0466_WRAPPED then
    Exec.TECH_PRIESTS_0466_PRE_SERVICE_PAIR = Exec.service_pair
    Exec.service_pair = function(pair, reason)
      if M.pause_acquisition_for_combat(pair, "acquisition-executor-paused") then return false, "combat-mutex" end
      return Exec.TECH_PRIESTS_0466_PRE_SERVICE_PAIR(pair, reason)
    end
    Exec.TECH_PRIESTS_0466_WRAPPED = true
  end

  local ok_repair, Repair = pcall(require, "scripts.core.acquisition_repair")
  if ok_repair and Repair and Repair.service_pair and not Repair.TECH_PRIESTS_0466_WRAPPED then
    Repair.TECH_PRIESTS_0466_PRE_SERVICE_PAIR = Repair.service_pair
    Repair.service_pair = function(pair, reason)
      if M.pause_acquisition_for_combat(pair, "acquisition-repair-paused") then return false, "combat-mutex" end
      return Repair.TECH_PRIESTS_0466_PRE_SERVICE_PAIR(pair, reason)
    end
    Repair.TECH_PRIESTS_0466_WRAPPED = true
  end
end

function M.tick()
  ensure_root()
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and valid(pair.priest) then
      if M.combat_active(pair) then M.pause_acquisition_for_combat(pair, "periodic-combat-hold") end
    end
  end
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-mutex-0466") end end)
  commands.add_command("tp-behavior-mutex-0466", "Tech Priests 0.1.466: inspect selected pair combat/acquisition mutex.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local pair = nil
    if player.selected and player.selected.valid and _G.find_pair_for_entity then local ok, p = pcall(_G.find_pair_for_entity, player.selected); if ok then pair = p end end
    if not pair and player.selected and player.selected.valid and storage and storage.tech_priests then
      pair = (storage.tech_priests.pairs_by_station or {})[player.selected.unit_number] or (storage.tech_priests.pairs_by_priest or {})[player.selected.unit_number]
    end
    if not pair then player.print("[tp-behavior-mutex-0466] select a Cogitator Station or Tech-Priest."); return end
    local target = (pair.combat_target and pair.combat_target.valid and pair.combat_target) or (pair.target and pair.target.valid and pair.target) or nil
    player.print("[tp-behavior-mutex-0466] mode=" .. mode_text(pair) .. " kind=" .. active_task_kind(pair) .. " active=" .. tostring(M.combat_active(pair)) .. " target=" .. entity_name(target) .. " target_force=" .. force_name(target and target.force) .. " hostile=" .. tostring(M.is_hostile(pair, target)) .. " paused=" .. safe(pair.acquisition_paused_by_combat_0466 and pair.acquisition_paused_by_combat_0466.reason))
  end)
end

function M.install()
  ensure_root()
  M.wrap_globals()
  M.wrap_modules()
  M.install_commands()
  if script and script.on_nth_tick then
    script.on_nth_tick(11, function() M.tick() end)
  end
  _G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M
  _G.tech_priests_pair_combat_active_0466 = M.combat_active
  if log then log("[Tech-Priests 0.1.466] combat/acquisition behavior mutex installed") end
  return true
end

return M
