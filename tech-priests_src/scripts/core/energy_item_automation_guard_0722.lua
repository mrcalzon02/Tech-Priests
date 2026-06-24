-- Tech Priests 0.1.674-dev energy-family item automation guard.
--
-- Boilers, burner generators, reactors, and fusion reactors may already have
-- inserters or loaders managing fuel and burnt results. Mark those entities as
-- externally owned in readiness reports and keep 0707 from creating or continuing
-- competing item tasks. Carried custody is returned physically; uncarried work is
-- released without touching the machine.

local M = {
  version = "0.1.674-dev",
  storage_key = "energy_item_automation_guard_0722",
}

local previous_readiness_install
local previous_readiness_inspect
local previous_logistics_install
local previous_logistics_service

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local state = root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = safe(station_unit(pair)),
    action = tostring(action),
    detail = tostring(detail or ""),
  }
  while #state.recent > 120 do table.remove(state.recent, 1) end
end

local function connected_item_automation(entity)
  if not valid(entity) then return false, {} end
  local reasons = {}
  local box
  pcall(function() box = entity.bounding_box end)
  local p = entity.position
  local area = box and {
    { box.left_top.x - 3, box.left_top.y - 3 },
    { box.right_bottom.x + 3, box.right_bottom.y + 3 },
  } or {
    { p.x - 3, p.y - 3 },
    { p.x + 3, p.y + 3 },
  }
  local nearby = {}
  pcall(function()
    nearby = entity.surface.find_entities_filtered({
      area = area,
      force = entity.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
    }) or {}
  end)
  for _, candidate in pairs(nearby) do
    if candidate.type == "inserter" then
      local pickup, drop
      pcall(function() pickup = candidate.pickup_target end)
      pcall(function() drop = candidate.drop_target end)
      if pickup == entity or drop == entity then
        reasons[#reasons + 1] = "connected-inserter:" .. safe(candidate.unit_number)
      end
    else
      local container
      pcall(function() container = candidate.loader_container end)
      if container == entity then
        reasons[#reasons + 1] = "connected-loader:" .. safe(candidate.unit_number)
      end
    end
  end
  return #reasons > 0, reasons
end

local function annotate_report(report)
  if not (type(report) == "table" and valid(report.entity)) then return report end
  local automated, reasons = connected_item_automation(report.entity)
  report.connected_item_automation = automated
  report.automation_reasons = reasons
  if automated and report.state ~= "monitor-only" then
    report.pre_automation_state_0722 = report.state
    report.state = "external-item-automation-owned"
    report.severity = "monitor"
    stat("reports-marked-external")
  end
  return report
end

local function patched_readiness_inspect(pair, entity, force, ...)
  local report, why = previous_readiness_inspect(pair, entity, force, ...)
  return annotate_report(report), why
end

local function patch_readiness(readiness)
  if not (readiness and type(readiness.inspect_entity) == "function")
    or readiness.energy_item_automation_guard_0722_active
  then
    return false
  end
  readiness.energy_item_automation_guard_0722_active = true
  previous_readiness_inspect = readiness.inspect_entity
  readiness.inspect_entity = patched_readiness_inspect
  _G.tech_priests_energy_family_inspect_0705 = readiness.inspect_entity
  return true
end

local function release_target(pair, task)
  local reservations = rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
  if reservations and type(reservations.release) == "function"
    and task and valid(task.target)
  then
    pcall(reservations.release, "machine-logistics", task.target, pair)
  end
end

local function clear_requests(pair, task)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    local request = pair[field]
    if type(request) == "table"
      and request.source == "energy-family-logistics-0707"
      and (not task or not request.target_unit or request.target_unit == task.target_unit)
    then
      pair[field] = nil
    end
  end
end

local function abort_uncarried(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  task.phase = "aborted"
  task.completed_tick = now()
  task.result = reason
  pair.energy_family_logistics_last_task_0707 = task
  pair.energy_family_logistics_0707 = nil
  record(pair, "automated-energy-task-aborted",
    safe(task.target_name) .. " reason=" .. safe(reason))
end

local function guard_active_task(pair)
  local task = pair and pair.energy_family_logistics_0707
  if not (type(task) == "table" and valid(task.target)) then return false end
  local automated, reasons = connected_item_automation(task.target)
  if not automated then return false end
  if type(task.carried) == "table" and (tonumber(task.carried.count) or 0) > 0 then
    task.phase = "return-custody"
    record(pair, "automated-energy-custody-return",
      safe(task.target_name) .. " " .. table.concat(reasons, ","))
  else
    abort_uncarried(pair, task, "external-item-automation-owned")
  end
  return true
end

local function filtered_reports(pair)
  local original = pair.energy_family_reports_0705
  if type(original) ~= "table" then return original, nil end
  local filtered = {}
  for _, report in ipairs(original) do
    annotate_report(report)
    if not report.connected_item_automation then filtered[#filtered + 1] = report end
  end
  pair.energy_family_reports_0705 = filtered
  return original, filtered
end

local function patched_logistics_service(pair, reason, ...)
  if root().enabled == false or not valid_pair(pair) then
    return previous_logistics_service(pair, reason, ...)
  end
  guard_active_task(pair)
  local original = filtered_reports(pair)
  local acted, why = previous_logistics_service(pair, reason, ...)
  if original ~= nil then pair.energy_family_reports_0705 = original end
  guard_active_task(pair)
  return acted, why
end

local function patch_logistics(logistics)
  if not (logistics and type(logistics.service_pair) == "function")
    or logistics.energy_item_automation_guard_0722_active
  then
    return false
  end
  logistics.energy_item_automation_guard_0722_active = true
  previous_logistics_service = logistics.service_pair
  logistics.service_pair = patched_logistics_service
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.energy_item_automation_guard_0722_wrapped
  then
    return false
  end
  diagnostics.energy_item_automation_guard_0722_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ENERGY-AUTOMATION-GUARD-0722 enabled="
      .. safe(state.enabled)
      .. " reports_external=" .. safe(state.stats["reports-marked-external"] or 0)
      .. " tasks_aborted=" .. safe(state.stats["automated-energy-task-aborted"] or 0)
      .. " custody_returned=" .. safe(state.stats["automated-energy-custody-return"] or 0)
      .. " automation_mutations=0"
    for index = math.max(1, #state.recent - 8), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 energy-automation.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " station=" .. safe(event.station)
          .. " action=" .. safe(event.action)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

function M.install()
  root()
  local ok_readiness, readiness = pcall(require, "scripts.core.energy_family_readiness_0705")
  local ok_logistics, logistics = pcall(require, "scripts.core.energy_family_logistics_0707")
  if not (ok_readiness and readiness and ok_logistics and logistics) then return false end

  patch_readiness(readiness)
  patch_logistics(logistics)
  patch_diagnostics()
  _G.TechPriestsEnergyItemAutomationGuard0722 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] energy item automation ownership guard armed")
  end
  return true
end

return M
