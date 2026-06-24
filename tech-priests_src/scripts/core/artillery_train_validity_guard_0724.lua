-- Tech Priests 0.1.674-dev artillery train-validity integrity guard.
--
-- Artillery wagons are serviceable only while attached to a valid train that is
-- stationary and explicitly in manual mode. This leaf guard tightens the existing
-- 0712/0713 authorities without adding a timer, scanner, movement owner, or task
-- producer. Invalid or detached wagons are monitor-only; carried shells return.

local M = {
  version = "0.1.674-dev",
  storage_key = "artillery_train_validity_guard_0724",
}

local previous_readiness_inspect
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
  while #state.recent > 100 do table.remove(state.recent, 1) end
end

local function train_status(entity)
  if not (valid(entity) and entity.type == "artillery-wagon") then
    return true, "not-wagon", nil
  end
  local train
  pcall(function() train = entity.train end)
  if not (train and train.valid) then return false, "invalid-or-detached-train", nil end

  local speed, manual
  pcall(function() speed = tonumber(train.speed) or 0 end)
  pcall(function() manual = train.manual_mode == true end)
  if math.abs(speed or 0) >= 0.001 then return false, "train-moving", train end
  if manual ~= true then return false, "train-not-manual", train end
  return true, "stationary-manual-train", train
end

local function annotate_report(report)
  if not (type(report) == "table" and valid(report.entity)
    and report.entity.type == "artillery-wagon")
  then
    return report
  end
  local safe_for_service, reason, train = train_status(report.entity)
  report.train_validity_guard_0724 = {
    safe_for_service = safe_for_service,
    reason = reason,
    train_valid = train and train.valid or false,
  }
  if not safe_for_service then
    report.state = reason == "invalid-or-detached-train"
      and "invalid-train-monitor"
      or (reason == "train-moving" and "moving-train-monitor" or "automatic-train-owned")
    report.severity = "monitor"
    if type(report.train) == "table" then
      report.train.valid = train and train.valid or false
      report.train.safe_for_manual_service = false
      report.train.stationary = reason ~= "train-moving"
      report.train.manual_mode = reason ~= "train-not-manual" and train ~= nil
      report.train.state_name = reason
    end
    stat("reports-blocked-" .. reason)
  end
  return report
end

local function patch_readiness(readiness)
  if not (readiness and type(readiness.inspect_entity) == "function") then return false end
  if readiness.artillery_train_validity_guard_0724_active then return true end
  readiness.artillery_train_validity_guard_0724_active = true
  previous_readiness_inspect = readiness.inspect_entity
  readiness.inspect_entity = function(...)
    local report, why = previous_readiness_inspect(...)
    return annotate_report(report), why
  end
  _G.tech_priests_artillery_inspect_0712 = readiness.inspect_entity
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
    if type(request) == "table" and request.source == "artillery-logistics-0713"
      and (not task or not request.target_unit or request.target_unit == task.target_unit)
    then
      pair[field] = nil
    end
  end
end

local function carried_count(pair, task)
  local task_count = type(task and task.carried) == "table"
    and (tonumber(task.carried.count) or 0) or 0
  local custody = pair and pair.artillery_custody_0713
  local custody_count = type(custody) == "table" and (tonumber(custody.count) or 0) or 0
  return math.max(task_count, custody_count)
end

local function abort_uncarried(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  task.phase = "aborted"
  task.completed_tick = now()
  task.result = reason
  pair.artillery_logistics_last_task_0713 = task
  pair.artillery_logistics_0713 = nil
  record(pair, "unsafe-wagon-task-aborted", safe(task.target_name) .. " reason=" .. reason)
end

local function guard_active_task(pair)
  local task = pair and pair.artillery_logistics_0713
  if not (type(task) == "table" and valid(task.target)
    and task.target.type == "artillery-wagon")
  then
    return false
  end
  local safe_for_service, reason = train_status(task.target)
  if safe_for_service then return false end
  if carried_count(pair, task) > 0 then
    task.phase = "return-custody"
    record(pair, "unsafe-wagon-custody-return", safe(task.target_name) .. " reason=" .. reason)
  else
    abort_uncarried(pair, task, reason)
  end
  return true
end

local function filtered_reports(pair)
  local original = pair.artillery_reports_0712
  if type(original) ~= "table" then return original end
  local filtered = {}
  for _, report in ipairs(original) do
    annotate_report(report)
    local safe_for_service = not (valid(report.entity) and report.entity.type == "artillery-wagon")
      or train_status(report.entity)
    if safe_for_service then filtered[#filtered + 1] = report end
  end
  pair.artillery_reports_0712 = filtered
  return original
end

local function patch_logistics(logistics)
  if not (logistics and type(logistics.service_pair) == "function") then return false end
  if logistics.artillery_train_validity_guard_0724_active then return true end
  logistics.artillery_train_validity_guard_0724_active = true
  previous_logistics_service = logistics.service_pair
  logistics.service_pair = function(pair, reason, ...)
    if root().enabled == false or not valid_pair(pair) then
      return previous_logistics_service(pair, reason, ...)
    end
    guard_active_task(pair)
    local original = filtered_reports(pair)
    local acted, why = previous_logistics_service(pair, reason, ...)
    if original ~= nil then pair.artillery_reports_0712 = original end
    guard_active_task(pair)
    return acted, why
  end
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.artillery_train_validity_guard_0724_wrapped then return true end
  diagnostics.artillery_train_validity_guard_0724_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ARTILLERY-TRAIN-GUARD-0724 enabled="
      .. safe(state.enabled)
      .. " invalid_reports=" .. safe(state.stats["reports-blocked-invalid-or-detached-train"] or 0)
      .. " moving_reports=" .. safe(state.stats["reports-blocked-train-moving"] or 0)
      .. " automatic_reports=" .. safe(state.stats["reports-blocked-train-not-manual"] or 0)
      .. " tasks_aborted=" .. safe(state.stats["unsafe-wagon-task-aborted"] or 0)
      .. " custody_returns=" .. safe(state.stats["unsafe-wagon-custody-return"] or 0)
      .. " train_mutations=0"
    for index = math.max(1, #state.recent - 8), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 artillery-train-guard.recent["
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
  local ok_readiness, readiness = pcall(require, "scripts.core.artillery_readiness_0712")
  local ok_logistics, logistics = pcall(require, "scripts.core.artillery_logistics_0713")
  if not (ok_readiness and readiness and ok_logistics and logistics) then return false end
  local readiness_ok = patch_readiness(readiness)
  local logistics_ok = patch_logistics(logistics)
  local diagnostics_ok = patch_diagnostics()
  _G.TechPriestsArtilleryTrainValidityGuard0724 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] artillery train validity guard armed readiness="
      .. safe(readiness_ok) .. " logistics=" .. safe(logistics_ok)
      .. " diagnostics=" .. safe(diagnostics_ok))
  end
  return readiness_ok and logistics_ok and diagnostics_ok
end

return M
