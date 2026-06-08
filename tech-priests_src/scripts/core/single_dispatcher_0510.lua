-- scripts/core/single_dispatcher_0510.lua
-- Tech Priests 0.1.510
--
-- First authoritative dispatcher pass.  This does not delete the generated
-- legacy fragments yet; it changes their role.  Scheduler modules may submit or
-- promote work, the action arbiter may classify the one visible action, and
-- executors may perform physical work.  Legacy tick_pair is gated for the action
-- families that now have explicit module owners so it cannot keep reasserting
-- direct/crafting behavior behind the dispatcher.

local M = {}
M.version = "0.1.510"
M.storage_key = "single_dispatcher_0510"
M.tick_interval = 23
M.max_pairs_per_pulse = 24
M.legacy_gate_window = 5

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a, b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["dirt"] = true,
  ["direct-mine-0336"] = true,
}

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    gate_legacy_tick = true,
    suppress_independent_executor_pulses = true,
    dispatcher_owns_direct = true,
    dispatcher_owns_station_craft = true,
    dispatcher_owns_consecration = true,
    dispatcher_owns_repair = true,
    dispatcher_owns_combat_repair = true,
    stats = {},
    recent = {},
    last = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.gate_legacy_tick == nil then r.gate_legacy_tick = true end
  if r.suppress_independent_executor_pulses == nil then r.suppress_independent_executor_pulses = true end
  if r.dispatcher_owns_direct == nil then r.dispatcher_owns_direct = true end
  if r.dispatcher_owns_station_craft == nil then r.dispatcher_owns_station_craft = true end
  if r.dispatcher_owns_consecration == nil then r.dispatcher_owns_consecration = true end
  if r.dispatcher_owns_repair == nil then r.dispatcher_owns_repair = true end
  if r.dispatcher_owns_combat_repair == nil then r.dispatcher_owns_combat_repair = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last = r.last or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = M.root()
  stat(action)
  local rec = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 160 do table.remove(r.recent, 1) end
  return rec
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = task and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur end
  end
  return nil, nil
end

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end

local function target_position(pair, cur)
  local e = target_entity(cur)
  if e then return e.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function target_label(cur)
  local e = target_entity(cur)
  if e then return safe(e.name) .. "#" .. safe(e.unit_number or "?") end
  return safe(cur and (cur.item_name or cur.output_item or cur.wanted_item or cur.kind) or "nil")
end

local function repair_identity(pair, reason)
  if not valid_pair(pair) then return false end
  storage.tech_priests = storage.tech_priests or {}
  local tp = storage.tech_priests
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  pair.priest_name = pair.priest.name
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.dispatcher_identity_0510 = { tick = now(), reason = tostring(reason or "dispatcher") }
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function order_tick(pair)
  local ok, OQ = pcall(require, "scripts.core.order_queue_0469")
  if ok and OQ and type(OQ.tick_pair) == "function" then
    local ok2, result = pcall(OQ.tick_pair, pair, "dispatcher-0510")
    if ok2 then return result end
  end
  return false
end

local function choose_action(pair)
  -- 0.1.517: tactical combat repair is checked before ordinary combat
  -- classification.  It only returns an action when a damaged wall/gate is
  -- under enemy pressure and has active/loaded turret or priest cover.
  local okCR, CombatRepair0517 = pcall(require, "scripts.core.combat_repair_doctrine_0517")
  if okCR and CombatRepair0517 and type(CombatRepair0517.recommend_action) == "function" then
    local ok2, action = pcall(CombatRepair0517.recommend_action, pair)
    if ok2 and type(action) == "table" then return action end
  end
  local ok, Arbiter = pcall(require, "scripts.core.action_state_arbiter_0488")
  if ok and Arbiter and type(Arbiter.action) == "function" then
    local ok2, action = pcall(Arbiter.action, pair)
    if ok2 and type(action) == "table" then return action end
  end
  local task, cur = current_direct_task(pair)
  if task and cur then return { kind = "direct-acquisition", item = cur.item_name or cur.output_item or task.output_item or task.item_name, target = target_entity(cur), reason = "direct-task" } end
  if pair and pair.emergency_craft then return { kind = "timed-station-crafting", item = pair.emergency_craft.output_item or pair.emergency_craft.item_name, target = pair.station, reason = "emergency-craft" } end
  if pair and valid(pair.combat_target) then return { kind = "combat", target = pair.combat_target, reason = "combat-target" } end
  return { kind = "idle", reason = "no-claim" }
end

local function action_family(action)
  local k = lower(action and action.kind or "idle")
  if k == "acquisition" or k == "direct-acquisition" or k:find("acquisition", 1, true) or k:find("min", 1, true) then return "direct-acquisition" end
  if k == "crafting" or k == "timed-station-crafting" or k:find("craft", 1, true) then return "station-craft" end
  if k == "combat-repair" or k:find("combat%-repair", 1, false) then return "combat-repair" end
  if k == "combat" or k:find("combat", 1, true) then return "combat" end
  if k == "repair" then return "repair" end
  if k == "consecration" then return "consecration" end
  if k == "movement" or k:find("travell", 1, true) then return "movement" end
  return k ~= "" and k or "idle"
end

local function execute_direct(pair)
  local ok513, Direct513 = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if ok513 and Direct513 and type(Direct513.service_pair) == "function" then
    local ok2, acted, why = pcall(Direct513.service_pair, pair, "dispatcher-0510")
    if ok2 then return acted, why or "direct-0513" end
    record("direct-0513-error", pair, acted)
  end
  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok and Exec and type(Exec.service_pair) == "function" then
    local ok2, acted, why = pcall(Exec.service_pair, pair, "dispatcher-0510")
    if ok2 then return acted, why or "direct" end
    record("direct-exec-error", pair, acted)
  end
  return false, "no-direct-executor"
end

local function execute_craft(pair)
  local ok514, Prod514 = pcall(require, "scripts.core.emergency_production_executor_0514")
  if ok514 and Prod514 and type(Prod514.service_pair) == "function" then
    local ok2, acted, why = pcall(Prod514.service_pair, pair, "dispatcher-0510")
    if ok2 and (acted or (why and why ~= "no-production-task")) then return acted, why or "emergency-production-0514" end
    if not ok2 then record("production-0514-error", pair, acted) end
  end
  local ok, Craft = pcall(require, "scripts.core.crafting_executor")
  if ok and Craft and type(Craft.before_legacy_handle) == "function" then
    local ok2, acted = pcall(Craft.before_legacy_handle, pair)
    if ok2 then return acted, acted and "craft-service" or "craft-waiting-legacy" end
    record("craft-exec-error", pair, acted)
  end
  return false, "no-craft-executor"
end


local function execute_consecration(pair)
  local ok515, Cons515 = pcall(require, "scripts.core.consecration_executor_0515")
  if ok515 and Cons515 and type(Cons515.service_pair) == "function" then
    local ok2, acted, why = pcall(Cons515.service_pair, pair, "dispatcher-0510")
    if ok2 then return acted, why or "consecration-0515" end
    record("consecration-0515-error", pair, acted)
  end
  return false, "no-consecration-executor"
end

local function execute_combat_repair(pair)
  local ok517, CombatRepair0517 = pcall(require, "scripts.core.combat_repair_doctrine_0517")
  if ok517 and CombatRepair0517 and type(CombatRepair0517.service_pair) == "function" then
    local ok2, acted, why = pcall(CombatRepair0517.service_pair, pair, "dispatcher-0510")
    if ok2 then return acted, why or "combat-repair-0517" end
    record("combat-repair-0517-error", pair, acted)
  end
  return false, "no-combat-repair-executor"
end

local function execute_repair(pair)
  local ok516, Repair516 = pcall(require, "scripts.core.repair_executor_0516")
  if ok516 and Repair516 and type(Repair516.service_pair) == "function" then
    local ok2, acted, why = pcall(Repair516.service_pair, pair, "dispatcher-0510")
    if ok2 then return acted, why or "repair-0516" end
    record("repair-0516-error", pair, acted)
  end
  return false, "no-repair-executor"
end

local function active_family_needs_legacy_gate(family, pair)
  if family == "station-craft" then return true end
  if family == "direct-acquisition" then
    local ok513, Direct513 = pcall(require, "scripts.core.direct_acquisition_executor_0513")
    if ok513 and Direct513 and type(Direct513.current_direct_task) == "function" then
      local task, cur = Direct513.current_direct_task(pair)
      return task ~= nil and cur ~= nil
    end
    local task = current_direct_task(pair)
    return task ~= nil
  end
  if family == "consecration" then
    local ok515, Cons515 = pcall(require, "scripts.core.consecration_executor_0515")
    if ok515 and Cons515 and type(Cons515.active) == "function" then return Cons515.active(pair) end
    return pair and lower(pair.mode):find("consecr", 1, true) ~= nil
  end
  if family == "combat-repair" then
    local ok517, CombatRepair0517 = pcall(require, "scripts.core.combat_repair_doctrine_0517")
    if ok517 and CombatRepair0517 and type(CombatRepair0517.active) == "function" then return CombatRepair0517.active(pair) end
    return pair and lower(pair.mode):find("combat%-repair", 1, false) ~= nil
  end
  if family == "repair" then
    local ok516, Repair516 = pcall(require, "scripts.core.repair_executor_0516")
    if ok516 and Repair516 and type(Repair516.active) == "function" then return Repair516.active(pair) end
    return pair and lower(pair.mode):find("repair", 1, true) ~= nil
  end
  if pair then
    local mode = lower(pair.mode)
    if mode:find("travelling%-to%-direct", 1, false) or mode:find("emergency%-craft", 1, false) or mode:find("returning%-to%-station%-for%-craft", 1, false) then return true end
  end
  return false
end

function M.service_pair(pair, reason)
  local r = M.root()
  if r.enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  repair_identity(pair, reason or "service")
  order_tick(pair)
  local action = choose_action(pair)
  local family = action_family(action)
  pair.dispatcher_0510 = pair.dispatcher_0510 or {}
  pair.dispatcher_0510.tick = now()
  pair.dispatcher_0510.action = safe(action.kind or family)
  pair.dispatcher_0510.family = family
  pair.dispatcher_0510.reason = safe(action.reason or reason or "service")
  pair.dispatcher_0510.gates_legacy = active_family_needs_legacy_gate(family, pair)
  pair.dispatcher_0510.target = safe(action.target and valid(action.target) and (action.target.name .. "#" .. tostring(action.target.unit_number or "?")) or "nil")

  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, family, "single_dispatcher_0510", pair.dispatcher_0510.reason) end

  local acted, why = false, "classified"
  if family == "direct-acquisition" and r.dispatcher_owns_direct ~= false then
    acted, why = execute_direct(pair)
  elseif family == "station-craft" and r.dispatcher_owns_station_craft ~= false then
    acted, why = execute_craft(pair)
  elseif family == "consecration" and r.dispatcher_owns_consecration ~= false then
    acted, why = execute_consecration(pair)
  elseif family == "combat-repair" and r.dispatcher_owns_combat_repair ~= false then
    acted, why = execute_combat_repair(pair)
  elseif family == "repair" and r.dispatcher_owns_repair ~= false then
    acted, why = execute_repair(pair)
  else
    -- Combat/construction are not fully migrated yet. They remain legacy
    -- leaf-controlled until a later pass moves each one behind the dispatcher.
    acted, why = false, "legacy-leaf-family"
  end
  pair.dispatcher_0510.acted = acted and true or false
  pair.dispatcher_0510.result = safe(why)
  record("dispatch-" .. family, pair, "acted=" .. safe(acted) .. " result=" .. safe(why))
  return acted, why
end

function M.service_all(reason)
  local r = M.root()
  if r.enabled == false then return 0 end
  r.dispatching = true
  local n = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      local ok = pcall(M.service_pair, pair, reason or "pulse")
      if ok then n = n + 1 end
      if n >= M.max_pairs_per_pulse then break end
    end
  end
  r.dispatching = false
  return n
end

function M.should_gate_legacy(pair)
  local r = M.root()
  if r.enabled == false or r.gate_legacy_tick == false or not valid_pair(pair) then return false end
  local d = pair.dispatcher_0510
  if not d then return false end
  if now() - (tonumber(d.tick) or -1000000) > M.legacy_gate_window then return false end
  if d.gates_legacy then return true end
  return false
end

local function wrap_legacy_tick_pair()
  if type(_G.tick_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0510_PRE_TICK_PAIR") then return false end
  _G.TECH_PRIESTS_0510_PRE_TICK_PAIR = _G.tick_pair
  _G.tick_pair = function(pair, ...)
    if M.should_gate_legacy(pair) then
      stat("legacy-tick-gated-0510")
      return true
    end
    return _G.TECH_PRIESTS_0510_PRE_TICK_PAIR(pair, ...)
  end
  return true
end

local function wrap_executor_pulses()
  local okE, Exec = pcall(require, "scripts.core.acquisition_executor")
  if okE and Exec and type(Exec.pulse) == "function" and not Exec.dispatcher_0510_pulse_wrapped then
    Exec.dispatcher_0510_pulse_wrapped = true
    Exec.TECH_PRIESTS_0510_PRE_PULSE = Exec.pulse
    Exec.pulse = function(reason)
      local r = M.root()
      local rs = tostring(reason or "")
      if r.enabled ~= false and r.suppress_independent_executor_pulses ~= false and not r.dispatching and not rs:find("manual", 1, true) and not rs:find("kick", 1, true) and not rs:find("dispatcher%-0510") then
        stat("independent-direct-pulse-suppressed-0510")
        return false
      end
      return Exec.TECH_PRIESTS_0510_PRE_PULSE(reason)
    end
  end

  local okC, Craft = pcall(require, "scripts.core.crafting_executor")
  if okC and Craft and type(Craft.pulse) == "function" and not Craft.dispatcher_0510_pulse_wrapped then
    Craft.dispatcher_0510_pulse_wrapped = true
    Craft.TECH_PRIESTS_0510_PRE_PULSE = Craft.pulse
    Craft.pulse = function(...)
      local r = M.root()
      if r.enabled ~= false and r.suppress_independent_executor_pulses ~= false and not r.dispatching then
        stat("independent-craft-pulse-suppressed-0510")
        return false
      end
      return Craft.TECH_PRIESTS_0510_PRE_PULSE(...)
    end
  end
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

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-dispatcher-0510") end end)
  commands.add_command("tp-dispatcher-0510", "Tech Priests 0.1.510: single dispatcher status. Params: on/off/all/gate-on/gate-off/pulses-on/pulses-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "gate-on" then r.gate_legacy_tick = true end
    if p == "gate-off" then r.gate_legacy_tick = false end
    if p == "pulses-on" then r.suppress_independent_executor_pulses = true end
    if p == "pulses-off" then r.suppress_independent_executor_pulses = false end
    if p == "all" then M.service_all("manual-all") end
    local pair = selected_pair(player)
    local lines = {}
    lines[#lines + 1] = "[tp-dispatcher-0510] enabled=" .. safe(r.enabled)
      .. " gate_legacy_tick=" .. safe(r.gate_legacy_tick)
      .. " suppress_executor_pulses=" .. safe(r.suppress_independent_executor_pulses)
      .. " owns_consecration=" .. safe(r.dispatcher_owns_consecration)
      .. " owns_repair=" .. safe(r.dispatcher_owns_repair)
      .. " owns_combat_repair=" .. safe(r.dispatcher_owns_combat_repair)
      .. " gated=" .. safe(r.stats["legacy-tick-gated-0510"] or 0)
      .. " direct_pulse_suppressed=" .. safe(r.stats["independent-direct-pulse-suppressed-0510"] or 0)
      .. " craft_pulse_suppressed=" .. safe(r.stats["independent-craft-pulse-suppressed-0510"] or 0)
    if pair then
      local d = pair.dispatcher_0510 or {}
      local task, cur = current_direct_task(pair)
      local pos = target_position(pair, cur)
      local dist = valid(pair.priest) and pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
      lines[#lines + 1] = "selected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " valid=" .. safe(valid(pair.priest))
        .. " mode=" .. safe(pair.mode) .. " action=" .. safe(d.action) .. " family=" .. safe(d.family) .. " result=" .. safe(d.result)
        .. " direct=" .. safe(cur and cur.kind or "nil") .. " target=" .. safe(target_label(cur)) .. " dist=" .. safe(dist and string.format("%.1f", dist) or "nil")
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.single_dispatcher_0510_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.single_dispatcher_0510_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 BEGIN enabled=" .. safe(r.enabled)
      .. " gate_legacy_tick=" .. safe(r.gate_legacy_tick)
      .. " suppress_executor_pulses=" .. safe(r.suppress_independent_executor_pulses)
      .. " owns_consecration=" .. safe(r.dispatcher_owns_consecration)
      .. " owns_repair=" .. safe(r.dispatcher_owns_repair)
      .. " owns_combat_repair=" .. safe(r.dispatcher_owns_combat_repair)
      .. " gated=" .. safe(r.stats["legacy-tick-gated-0510"] or 0)
      .. " direct_pulse_suppressed=" .. safe(r.stats["independent-direct-pulse-suppressed-0510"] or 0)
      .. " craft_pulse_suppressed=" .. safe(r.stats["independent-craft-pulse-suppressed-0510"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local d = pair.dispatcher_0510 or {}
        local _, cur = current_direct_task(pair)
        local pos = target_position(pair, cur)
        local dist = valid(pair.priest) and pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 dispatch0510[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest)) .. " mode=" .. safe(pair.mode)
          .. " action=" .. safe(d.action) .. " family=" .. safe(d.family) .. " result=" .. safe(d.result)
          .. " gates_legacy=" .. safe(d.gates_legacy) .. " direct=" .. safe(cur and cur.kind or "nil")
          .. " target=" .. safe(target_label(cur)) .. " dist=" .. safe(dist and string.format("%.1f", dist) or "nil")
      end
    end
    for i = math.max(1, #r.recent - 10), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 dispatch0510.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_executor_pulses()
  wrap_legacy_tick_pair()
  wrap_pair_dump()
  install_command()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick-0510") end, { owner = "single_dispatcher_0510", category = "dispatcher", priority = "first", note = "single per-pair dispatcher: scheduler -> action -> executor" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick-0510") end)
  end
  _G.TechPriestsSingleDispatcher0510 = M
  if log then log("[Tech-Priests 0.1.510] single dispatcher installed; direct acquisition and station-craft executor pulses now route through dispatcher; legacy tick_pair gated for dispatcher-owned action families") end
  return true
end

return M
