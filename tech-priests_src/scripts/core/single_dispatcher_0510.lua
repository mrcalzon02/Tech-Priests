-- scripts/core/single_dispatcher_0510.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- One per-pair scheduler/executor dispatcher and canonical action-record owner.

local M = {
  version = "0.1.674-dev",
  storage_key = "single_dispatcher_0510",
  tick_interval = 5,
  max_pairs_per_pulse = 24,
  legacy_gate_window = 30,
}
local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, s = pcall(tostring, v)
  return ok and s or "?"
end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(p) return p and valid(p.station) and valid(p.priest) end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function station_unit(p)
  return p and (p.station_unit or valid(p.station) and p.station.unit_number)
end
local function priest_unit(p)
  return p and (p.priest_unit or valid(p.priest) and p.priest.unit_number)
end
local function root()
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
    stats = {}, recent = {}, cursor = 0,
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  for _, key in ipairs({
    "enabled", "gate_legacy_tick", "suppress_independent_executor_pulses",
    "dispatcher_owns_direct", "dispatcher_owns_station_craft",
    "dispatcher_owns_consecration", "dispatcher_owns_repair",
    "dispatcher_owns_combat_repair",
  }) do
    if r[key] == nil then r[key] = true end
  end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end
local function stat(k, n)
  local r = root()
  r.stats[k] = (r.stats[k] or 0) + (tonumber(n) or 1)
end
local function record(action, pair, detail)
  local r = root()
  local signature = safe(station_unit(pair)) .. ":" .. safe(action) .. ":" .. safe(detail)
  if r.last_signature == signature then return end
  r.last_signature = signature
  r.recent[#r.recent + 1] = {
    tick = now(), action = safe(action), station = station_unit(pair),
    priest = priest_unit(pair), detail = safe(detail),
  }
  while #r.recent > 120 do table.remove(r.recent, 1) end
end

local function order_tick(pair)
  local q = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
  if q and type(q.tick_pair) == "function" then
    local ok, acted = pcall(q.tick_pair, pair, "single-dispatcher-0510")
    return ok and acted == true
  end
  return false
end
local function classifier(pair)
  local arbiter = rawget(_G, "TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
  if arbiter and type(arbiter.action) == "function" then
    local ok, action = pcall(arbiter.action, pair)
    if ok and type(action) == "table" then return action end
  end
  return { kind = lower(pair.mode) ~= "" and lower(pair.mode) or "idle",
    source = "compatibility-mode" }
end
local function direct_active(pair)
  local ok, mod = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if ok and mod then
    if pair.direct_acquisition_custody_0513 then return true end
    if type(mod.current_direct_task) == "function" then
      local task, current = mod.current_direct_task(pair)
      return task ~= nil and current ~= nil
    end
  end
  return false
end
local function craft_active(pair)
  return pair and (pair.emergency_production_custody_0514
    or pair.emergency_craft or pair.station_crafting_task_0337
    or pair.station_craft_0337 or pair.active_craft_0479) ~= nil
end
local function family_for(pair, action)
  local kind = lower(action and action.kind)
  if kind == "acquisition" and direct_active(pair) then return "direct-acquisition" end
  if kind == "crafting" or kind == "station-craft" or kind == "emergency-craft" then
    return "station-craft"
  end
  if kind:find("consecr", 1, true) then return "consecration" end
  if kind == "combat-repair" then return "combat-repair" end
  if kind == "repair" then return "repair" end
  return kind ~= "" and kind or "idle"
end
local function target_fields(action)
  local target = action and action.target
  local position = action and action.position
  if valid(target) then position = target.position end
  return target, position and { x = position.x, y = position.y } or nil
end
local function publish_action(pair, action, family, status, detail)
  local previous = pair.canonical_action_0744
  local target, position = target_fields(action)
  local order = pair.order_queue_0469 and pair.order_queue_0469.current
    or pair.active_order_0469
  local action_id = order and order.key or family .. ":" .. safe(station_unit(pair))
  local rec = {
    version = M.version,
    action_id = action_id,
    family = family,
    owner = "single_dispatcher_0510",
    phase = action and action.phase or pair.dispatcher_phase or status,
    status = status,
    detail = safe(detail),
    order_key = order and order.key or action and action.order_key,
    item = action and action.item or order and order.item,
    target = target,
    target_unit = valid(target) and target.unit_number or nil,
    target_name = valid(target) and target.name or nil,
    target_surface = valid(target) and target.surface and target.surface.index or nil,
    position = position,
    source = action and action.source or "dispatcher",
    issued_tick = previous and previous.action_id == action_id
      and previous.issued_tick or now(),
    updated_tick = now(),
  }
  pair.canonical_action_0744 = rec
  pair.dispatcher_0510 = {
    tick = rec.updated_tick,
    action = safe(action and action.kind or family),
    family = family,
    reason = safe(action and action.reason or action and action.source or detail),
    target = safe(rec.target_name and
      (rec.target_name .. "#" .. safe(rec.target_unit)) or "nil"),
    gates_legacy = status == "active" and (
      family == "direct-acquisition" or family == "station-craft"
      or family == "consecration" or family == "repair"
      or family == "combat-repair"
    ),
    acted = status == "acted",
    result = safe(detail),
  }
  return rec
end

local function normalize_execution(primary, secondary)
  local result = {
    processed = 1, acted = 0, blocked = 0, waiting = 0,
    failed = 0, detail = safe(secondary or primary or ""),
  }
  if type(primary) == "table" then
    result.acted = math.max(0, tonumber(primary.acted) or 0)
    result.blocked = math.max(0, tonumber(primary.blocked) or 0)
    result.waiting = math.max(0, tonumber(primary.waiting) or 0)
    result.failed = math.max(0, tonumber(primary.failed) or 0)
    result.detail = safe(primary.detail or primary.reason or secondary or "")
  elseif primary == true then
    result.acted = 1
  elseif type(primary) == "number" then
    result.acted = math.max(0, primary)
  else
    local d = lower(result.detail)
    if d:find("block", 1, true) then result.blocked = 1
    elseif d:find("wait", 1, true) or d:find("cooldown", 1, true) then
      result.waiting = 1
    elseif d:find("fail", 1, true) or d:find("error", 1, true) then
      result.failed = 1
    end
  end
  return result
end
local function call_module(module_name, fn_name, pair, reason)
  local ok, mod = pcall(require, module_name)
  if not (ok and mod and type(mod[fn_name]) == "function") then
    return { processed = 1, failed = 1,
      detail = module_name .. "." .. fn_name .. " unavailable" }
  end
  local ok_call, primary, secondary = pcall(mod[fn_name], pair, reason)
  if not ok_call then
    return { processed = 1, failed = 1, detail = safe(primary) }
  end
  return normalize_execution(primary, secondary)
end
local function execute(pair, family, reason)
  if family == "direct-acquisition" then
    return call_module("scripts.core.direct_acquisition_executor_0513",
      "service_pair", pair, reason)
  elseif family == "station-craft" then
    local result = call_module("scripts.core.emergency_production_executor_0514",
      "service_pair", pair, reason)
    if result.failed == 0 and (result.acted > 0 or result.waiting > 0
      or result.blocked > 0)
    then
      return result
    end
    local fallback = call_module("scripts.core.crafting_executor",
      "service_pair", pair, reason)
    if fallback.failed == 0 then return fallback end
    return result.failed > 0 and result or fallback
  elseif family == "consecration" then
    return call_module("scripts.core.consecration_executor_0515",
      "service_pair", pair, reason)
  elseif family == "combat-repair" then
    return call_module("scripts.core.combat_repair_doctrine_0517",
      "service_pair", pair, reason)
  elseif family == "repair" then
    return call_module("scripts.core.repair_executor_0516",
      "service_pair", pair, reason)
  end
  return { processed = 1, waiting = family ~= "idle" and 1 or 0,
    detail = family == "idle" and "idle" or "compatibility-leaf-family" }
end
local function family_owned(r, family)
  if family == "direct-acquisition" then return r.dispatcher_owns_direct ~= false end
  if family == "station-craft" then return r.dispatcher_owns_station_craft ~= false end
  if family == "consecration" then return r.dispatcher_owns_consecration ~= false end
  if family == "repair" then return r.dispatcher_owns_repair ~= false end
  if family == "combat-repair" then return r.dispatcher_owns_combat_repair ~= false end
  return false
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false or not valid_pair(pair) then
    return { processed = 0, failed = not valid_pair(pair) and 1 or 0,
      detail = "disabled-or-invalid" }
  end
  order_tick(pair)
  local action = classifier(pair)
  local family = family_for(pair, action)
  publish_action(pair, action, family, "selected", reason or action.reason)
  if type(_G.tech_priests_0507_action_claim) == "function" then
    pcall(_G.tech_priests_0507_action_claim, pair, family,
      "single_dispatcher_0510", action.reason or reason or "service")
  end

  local result
  if family_owned(r, family) then
    result = execute(pair, family, "dispatcher-0510:" .. safe(reason))
  else
    result = { processed = 1, acted = 0,
      waiting = family ~= "idle" and 1 or 0,
      detail = family == "idle" and "idle" or "compatibility-leaf-family" }
  end
  local status = result.failed > 0 and "failed"
    or result.acted > 0 and "acted"
    or result.blocked > 0 and "blocked"
    or result.waiting > 0 and "waiting" or "idle"
  publish_action(pair, action, family, status, result.detail)
  if status ~= "idle" then
    record("dispatch-" .. family, pair,
      status .. " " .. safe(result.detail))
  end
  stat("pairs_processed")
  stat("actions", result.acted)
  stat("failures", result.failed)
  return result
end

function M.service_all(reason, budget)
  local r = root()
  if r.enabled == false then
    return { processed = 0, acted = 0, detail = "disabled" }
  end
  local list = {}
  for key, pair in pairs(pair_map()) do
    if valid_pair(pair) then list[#list + 1] = { key = tostring(key), pair = pair } end
  end
  table.sort(list, function(a, b) return a.key < b.key end)
  if #list == 0 then return { processed = 0, acted = 0, detail = "no-pairs" } end
  local limit = math.max(1, math.min(#list,
    math.floor(tonumber(budget) or M.max_pairs_per_pulse)))
  local start = (tonumber(r.cursor) or 0) % #list + 1
  local aggregate = {
    processed = 0, acted = 0, blocked = 0, waiting = 0,
    failed = 0, exhausted = #list > limit,
  }
  r.dispatching = true
  for i = 0, limit - 1 do
    local pair = list[((start + i - 1) % #list) + 1].pair
    local ok, result = pcall(M.service_pair, pair, reason or "broker")
    aggregate.processed = aggregate.processed + 1
    if ok and type(result) == "table" then
      for _, key in ipairs({ "acted", "blocked", "waiting", "failed" }) do
        aggregate[key] = aggregate[key] + (tonumber(result[key]) or 0)
      end
    else
      aggregate.failed = aggregate.failed + 1
      record("dispatcher-error", pair, ok and "invalid-result" or result)
    end
  end
  r.dispatching = false
  r.cursor = (start + limit - 2) % #list + 1
  aggregate.detail = "pairs=" .. aggregate.processed
    .. " acted=" .. aggregate.acted .. " failed=" .. aggregate.failed
  return aggregate
end

function M.should_gate_legacy(pair)
  local r = root()
  if r.enabled == false or r.gate_legacy_tick == false
    or not valid_pair(pair)
  then
    return false
  end
  local d = pair.dispatcher_0510
  return d and now() - (tonumber(d.tick) or -1000000)
    <= M.legacy_gate_window and d.gates_legacy == true
end
local function wrap_legacy_tick_pair()
  if type(_G.tick_pair) ~= "function"
    or rawget(_G, "TECH_PRIESTS_0510_PRE_TICK_PAIR")
  then
    return false
  end
  _G.TECH_PRIESTS_0510_PRE_TICK_PAIR = _G.tick_pair
  _G.tick_pair = function(pair, ...)
    if M.should_gate_legacy(pair) then
      stat("legacy-tick-gated")
      return true
    end
    return _G.TECH_PRIESTS_0510_PRE_TICK_PAIR(pair, ...)
  end
  return true
end
local function wrap_executor_pulses()
  local ok_a, acquisition = pcall(require, "scripts.core.acquisition_executor")
  if ok_a and acquisition and type(acquisition.pulse) == "function"
    and not acquisition.dispatcher_0510_pulse_wrapped
  then
    acquisition.dispatcher_0510_pulse_wrapped = true
    acquisition.TECH_PRIESTS_0510_PRE_PULSE = acquisition.pulse
    acquisition.pulse = function(reason)
      local r, text = root(), tostring(reason or "")
      if r.enabled ~= false and r.suppress_independent_executor_pulses ~= false
        and not r.dispatching and not text:find("manual", 1, true)
        and not text:find("kick", 1, true)
        and not text:find("dispatcher%-0510")
      then
        stat("independent-direct-pulse-suppressed")
        return false
      end
      return acquisition.TECH_PRIESTS_0510_PRE_PULSE(reason)
    end
  end
  local ok_c, craft = pcall(require, "scripts.core.crafting_executor")
  if ok_c and craft and type(craft.pulse) == "function"
    and not craft.dispatcher_0510_pulse_wrapped
  then
    craft.dispatcher_0510_pulse_wrapped = true
    craft.TECH_PRIESTS_0510_PRE_PULSE = craft.pulse
    craft.pulse = function(...)
      local r = root()
      if r.enabled ~= false and r.suppress_independent_executor_pulses ~= false
        and not r.dispatching
      then
        stat("independent-craft-pulse-suppressed")
        return false
      end
      return craft.TECH_PRIESTS_0510_PRE_PULSE(...)
    end
  end
end
local function wrap_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.single_dispatcher_0510_wrapped
  then
    return false
  end
  diagnostics.single_dispatcher_0510_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510"
      .. " version=" .. M.version .. " processed="
      .. safe(r.stats.pairs_processed or 0)
      .. " actions=" .. safe(r.stats.actions or 0)
      .. " failures=" .. safe(r.stats.failures or 0)
      .. " legacy_gated=" .. safe(r.stats["legacy-tick-gated"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local action = pair.canonical_action_0744 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 action["
          .. safe(station_unit(pair)) .. "] id=" .. safe(action.action_id)
          .. " family=" .. safe(action.family)
          .. " status=" .. safe(action.status)
          .. " phase=" .. safe(action.phase)
          .. " target=" .. safe(action.target_name)
          .. "#" .. safe(action.target_unit)
          .. " item=" .. safe(action.item)
          .. " detail=" .. safe(action.detail)
      end
    end
    return lines
  end
  return true
end

function M.install()
  root()
  wrap_executor_pulses()
  wrap_legacy_tick_pair()
  wrap_diagnostics()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-dispatcher-0510")
  end
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "single_dispatcher_0510",
      category = "dispatcher",
      interval = M.tick_interval,
      priority = 20,
      budget = M.max_pairs_per_pulse,
      note = "canonical per-pair action and executor owner",
      fn = function(_, budget)
        return M.service_all("broker-0510", budget)
      end,
    })
  else
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if registry and type(registry.on_nth_tick) == "function" then
      registry.on_nth_tick(M.tick_interval, function()
        M.service_all("registry-fallback-0510")
      end, {
        owner = "single_dispatcher_0510", route = "fallback",
        category = "dispatcher", priority = "first",
      })
    end
  end
  _G.TechPriestsSingleDispatcher0510 = M
  if log then
    log("[Tech-Priests recovery] canonical dispatcher installed; broker-owned and fair")
  end
  return true
end

return M
