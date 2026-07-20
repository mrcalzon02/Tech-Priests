-- scripts/core/single_dispatcher_0510.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- One fair per-pair scheduler/executor dispatcher and canonical action owner.

local M = {
  version = "0.1.674-dev",
  storage_key = "single_dispatcher_0510",
  tick_interval = 5,
  max_pairs_per_pulse = 24,
  legacy_gate_window = 30,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number))
end
local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number))
end

local OWNERSHIP_KEYS = {
  "enabled",
  "gate_legacy_tick",
  "suppress_independent_executor_pulses",
  "dispatcher_owns_direct",
  "dispatcher_owns_station_craft",
  "dispatcher_owns_consecration",
  "dispatcher_owns_repair",
  "dispatcher_owns_combat_repair",
  "dispatcher_owns_machine_logistics",
  "dispatcher_owns_item_family_logistics",
  "dispatcher_owns_energy_family_logistics",
}

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    gate_legacy_tick = true,
    suppress_independent_executor_pulses = true,
    dispatcher_owns_direct = true,
    dispatcher_owns_station_craft = true,
    dispatcher_owns_consecration = true,
    dispatcher_owns_repair = true,
    dispatcher_owns_combat_repair = true,
    dispatcher_owns_machine_logistics = true,
    dispatcher_owns_item_family_logistics = true,
    dispatcher_owns_energy_family_logistics = true,
    stats = {},
    recent = {},
    cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  for _, key in ipairs(OWNERSHIP_KEYS) do
    if state[key] == nil then state[key] = true end
  end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cursor = tonumber(state.cursor) or 0
  return state
end

local function stat(key, amount)
  local state = root()
  state.stats[key] = (state.stats[key] or 0) + (tonumber(amount) or 1)
end

local function record(action, pair, detail)
  local state = root()
  local signature = safe(station_unit(pair)) .. ":" .. safe(action) .. ":" .. safe(detail)
  if state.last_signature == signature then return end
  state.last_signature = signature
  state.recent[#state.recent + 1] = {
    tick = now(),
    action = safe(action),
    station = station_unit(pair),
    priest = priest_unit(pair),
    detail = safe(detail),
  }
  while #state.recent > 120 do table.remove(state.recent, 1) end
end

local function order_tick(pair)
  local queue = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
  if queue and type(queue.tick_pair) == "function" then
    local ok, acted = pcall(queue.tick_pair, pair, "single-dispatcher-0510")
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
  return {
    kind = lower(pair.mode) ~= "" and lower(pair.mode) or "idle",
    source = "compatibility-mode",
  }
end

local function direct_active(pair)
  local module = rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
    or package.loaded["scripts.core.direct_acquisition_executor_0513"]
  if not module then return false end
  if pair.direct_acquisition_custody_0513 then return true end
  if type(module.current_direct_task) == "function" then
    local task, current = module.current_direct_task(pair)
    return task ~= nil and current ~= nil
  end
  return false
end

local function family_for(pair, action)
  local kind = lower(action and action.kind)
  if kind == "acquisition" and direct_active(pair) then return "direct-acquisition" end
  if kind == "crafting" or kind == "station-craft" or kind == "emergency-craft" then
    return "station-craft"
  end
  if kind == "machine-logistics" or kind == "machine_logistics" then
    return "machine-logistics"
  end
  if kind == "item-family-logistics" or kind == "item_family_logistics" then
    return "item-family-logistics"
  end
  if kind == "energy-family-logistics" or kind == "energy_family_logistics" then
    return "energy-family-logistics"
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
  local record_value = {
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
  pair.canonical_action_0744 = record_value
  local owned_family = family == "direct-acquisition"
    or family == "station-craft"
    or family == "consecration"
    or family == "repair"
    or family == "combat-repair"
    or family == "machine-logistics"
    or family == "item-family-logistics"
    or family == "energy-family-logistics"
  pair.dispatcher_0510 = {
    tick = record_value.updated_tick,
    action = safe(action and action.kind or family),
    family = family,
    reason = safe(action and action.reason or action and action.source or detail),
    target = safe(record_value.target_name
      and (record_value.target_name .. "#" .. safe(record_value.target_unit)) or "nil"),
    gates_legacy = owned_family and status ~= "idle" and status ~= "failed",
    acted = status == "acted",
    result = safe(detail),
  }
  return record_value
end

local function normalize_execution(primary, secondary)
  local output = {
    processed = 1,
    acted = 0,
    blocked = 0,
    waiting = 0,
    failed = 0,
    exhausted = false,
    detail = safe(secondary or primary or ""),
  }
  if type(primary) == "table" then
    output.processed = math.max(0, tonumber(primary.processed) or 1)
    output.acted = math.max(0, tonumber(primary.acted) or 0)
    output.blocked = math.max(0, tonumber(primary.blocked) or 0)
    output.waiting = math.max(0, tonumber(primary.waiting) or 0)
    output.failed = math.max(0, tonumber(primary.failed) or 0)
    output.exhausted = primary.exhausted == true
    output.detail = safe(primary.detail or primary.reason or secondary or "")
  elseif primary == true then
    output.acted = 1
  elseif type(primary) == "number" then
    output.acted = math.max(0, primary)
  else
    local detail = lower(output.detail)
    if detail:find("block", 1, true) then
      output.blocked = 1
    elseif detail:find("wait", 1, true) or detail:find("cooldown", 1, true)
      or detail:find("move", 1, true)
    then
      output.waiting = 1
    elseif detail:find("fail", 1, true) or detail:find("error", 1, true) then
      output.failed = 1
    end
  end
  return output
end

local function call_module(module_name, global_name, function_name, pair, reason)
  local module = rawget(_G, global_name) or package.loaded[module_name]
  if not module then
    local ok, loaded = pcall(require, module_name)
    if ok then module = loaded end
  end
  if not (module and type(module[function_name]) == "function") then
    return {
      processed = 1,
      failed = 1,
      detail = module_name .. "." .. function_name .. " unavailable",
    }
  end
  local ok, primary, secondary = pcall(module[function_name], pair, reason)
  if not ok then return { processed = 1, failed = 1, detail = safe(primary) } end
  return normalize_execution(primary, secondary)
end

local EXECUTORS = {
  ["direct-acquisition"] = {
    "scripts.core.direct_acquisition_executor_0513",
    "TechPriestsDirectAcquisitionExecutor0513",
  },
  ["consecration"] = {
    "scripts.core.consecration_executor_0515",
    "TechPriestsConsecrationExecutor0515",
  },
  ["combat-repair"] = {
    "scripts.core.combat_repair_doctrine_0517",
    "TechPriestsCombatRepairDoctrine0517",
  },
  ["repair"] = {
    "scripts.core.repair_executor_0516",
    "TechPriestsRepairExecutor0516",
  },
  ["machine-logistics"] = {
    "scripts.core.logistics_machine_fulfillment_0528",
    "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528",
  },
  ["item-family-logistics"] = {
    "scripts.core.item_family_logistics_0702",
    "TechPriestsItemFamilyLogistics0702",
  },
  ["energy-family-logistics"] = {
    "scripts.core.energy_family_logistics_0707",
    "TechPriestsEnergyFamilyLogistics0707",
  },
}

local function execute(pair, family, reason)
  if family == "station-craft" then
    local result = call_module(
      "scripts.core.emergency_production_executor_0514",
      "TechPriestsEmergencyProductionExecutor0514",
      "service_pair", pair, reason)
    if result.failed == 0 and (result.acted > 0 or result.waiting > 0
      or result.blocked > 0)
    then
      return result
    end
    local fallback = call_module(
      "scripts.core.crafting_executor",
      "TechPriestsCraftingExecutor",
      "service_pair", pair, reason)
    if fallback.failed == 0 then return fallback end
    return result.failed > 0 and result or fallback
  end
  local spec = EXECUTORS[family]
  if spec then
    return call_module(spec[1], spec[2], "service_pair", pair, reason)
  end
  return {
    processed = 1,
    waiting = family ~= "idle" and 1 or 0,
    detail = family == "idle" and "idle" or "compatibility-leaf-family",
  }
end

local OWNERSHIP_BY_FAMILY = {
  ["direct-acquisition"] = "dispatcher_owns_direct",
  ["station-craft"] = "dispatcher_owns_station_craft",
  ["consecration"] = "dispatcher_owns_consecration",
  ["repair"] = "dispatcher_owns_repair",
  ["combat-repair"] = "dispatcher_owns_combat_repair",
  ["machine-logistics"] = "dispatcher_owns_machine_logistics",
  ["item-family-logistics"] = "dispatcher_owns_item_family_logistics",
  ["energy-family-logistics"] = "dispatcher_owns_energy_family_logistics",
}

local function family_owned(state, family)
  local key = OWNERSHIP_BY_FAMILY[family]
  return key ~= nil and state[key] ~= false
end

function M.service_pair(pair, reason)
  local state = root()
  if state.enabled == false or not valid_pair(pair) then
    return {
      processed = 0,
      failed = not valid_pair(pair) and 1 or 0,
      detail = "disabled-or-invalid",
    }
  end
  order_tick(pair)
  local action = classifier(pair)
  local family = family_for(pair, action)
  publish_action(pair, action, family, "selected", reason or action.reason)
  if type(_G.tech_priests_0507_action_claim) == "function" then
    pcall(_G.tech_priests_0507_action_claim, pair, family,
      "single_dispatcher_0510", action.reason or reason or "service")
  end
  local execution = family_owned(state, family)
    and execute(pair, family, "dispatcher-0510:" .. safe(reason))
    or {
      processed = 1,
      acted = 0,
      waiting = family ~= "idle" and 1 or 0,
      detail = family == "idle" and "idle" or "compatibility-leaf-family",
    }
  local status = execution.failed > 0 and "failed"
    or execution.acted > 0 and "acted"
    or execution.blocked > 0 and "blocked"
    or execution.waiting > 0 and "waiting" or "idle"
  publish_action(pair, action, family, status, execution.detail)
  if status ~= "idle" then
    record("dispatch-" .. family, pair, status .. " " .. safe(execution.detail))
  end
  stat("pairs_processed")
  stat("actions", execution.acted)
  stat("failures", execution.failed)
  return execution
end

function M.service_all(reason, budget)
  local state = root()
  if state.enabled == false then
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
  local start = state.cursor % #list + 1
  local aggregate = {
    processed = 0, acted = 0, blocked = 0, waiting = 0,
    failed = 0, exhausted = #list > limit,
  }
  state.dispatching = true
  for index = 0, limit - 1 do
    local pair = list[((start + index - 1) % #list) + 1].pair
    local ok, output = pcall(M.service_pair, pair, reason or "broker")
    aggregate.processed = aggregate.processed + 1
    if ok and type(output) == "table" then
      for _, key in ipairs({ "acted", "blocked", "waiting", "failed" }) do
        aggregate[key] = aggregate[key] + (tonumber(output[key]) or 0)
      end
    else
      aggregate.failed = aggregate.failed + 1
      record("dispatcher-error", pair, ok and "invalid-result" or output)
    end
  end
  state.dispatching = false
  state.cursor = (start + limit - 2) % #list + 1
  aggregate.detail = "pairs=" .. aggregate.processed
    .. " acted=" .. aggregate.acted .. " failed=" .. aggregate.failed
  return aggregate
end

function M.should_gate_legacy(pair)
  local state = root()
  if state.enabled == false or state.gate_legacy_tick == false or not valid_pair(pair) then
    return false
  end
  local dispatcher = pair.dispatcher_0510
  return dispatcher and now() - (tonumber(dispatcher.tick) or -1000000)
    <= M.legacy_gate_window and dispatcher.gates_legacy == true
end

local function wrap_legacy_tick_pair()
  if type(_G.tick_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0510_PRE_TICK_PAIR") then
    return true
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
  local ok_acquisition, acquisition = pcall(require, "scripts.core.acquisition_executor")
  if ok_acquisition and acquisition and type(acquisition.pulse) == "function"
    and not acquisition.dispatcher_0510_pulse_wrapped
  then
    acquisition.dispatcher_0510_pulse_wrapped = true
    acquisition.TECH_PRIESTS_0510_PRE_PULSE = acquisition.pulse
    acquisition.pulse = function(reason)
      local state = root()
      local text = tostring(reason or "")
      if state.enabled ~= false
        and state.suppress_independent_executor_pulses ~= false
        and not state.dispatching
        and not text:find("manual", 1, true)
        and not text:find("kick", 1, true)
        and not text:find("dispatcher%-0510")
      then
        stat("independent-direct-pulse-suppressed")
        return false
      end
      return acquisition.TECH_PRIESTS_0510_PRE_PULSE(reason)
    end
  end

  local ok_craft, craft = pcall(require, "scripts.core.crafting_executor")
  if ok_craft and craft and type(craft.pulse) == "function"
    and not craft.dispatcher_0510_pulse_wrapped
  then
    craft.dispatcher_0510_pulse_wrapped = true
    craft.TECH_PRIESTS_0510_PRE_PULSE = craft.pulse
    craft.pulse = function(...)
      local state = root()
      if state.enabled ~= false
        and state.suppress_independent_executor_pulses ~= false
        and not state.dispatching
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
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 SINGLE-DISPATCHER-0510 version="
      .. M.version .. " processed=" .. safe(state.stats.pairs_processed or 0)
      .. " actions=" .. safe(state.stats.actions or 0)
      .. " failures=" .. safe(state.stats.failures or 0)
      .. " legacy_gated=" .. safe(state.stats["legacy-tick-gated"] or 0)
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
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "single_dispatcher_0510",
    category = "dispatcher",
    interval = M.tick_interval,
    priority = 20,
    budget = M.max_pairs_per_pulse,
    note = "canonical per-pair action and executor owner",
    fn = function(_, budget) return M.service_all("broker-0510", budget) end,
  })
  _G.TechPriestsSingleDispatcher0510 = M
  if log then
    log("[Tech-Priests recovery] canonical dispatcher installed; broker-owned, fair, and energy-family aware")
  end
  return service ~= nil
end

return M
