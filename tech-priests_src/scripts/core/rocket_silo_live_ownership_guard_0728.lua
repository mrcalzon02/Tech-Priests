-- Tech Priests 0.1.674-dev rocket-silo live ownership guard.
--
-- A silo may enter rocket creation/launch state or acquire external logistics after
-- a cached 0709 report selected it. Revalidate ownership before every 0710 service
-- pass. Unsafe uncarried work aborts before source removal; existing custody is
-- returned. This guard never changes recipes, payload, cargo, rocket parts, launch
-- state, transitional requests, automation, or fluidboxes.

local M = {
  version = "0.1.674-dev",
  storage_key = "rocket_silo_live_ownership_guard_0728",
}

local previous_service_pair

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

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

local function readiness()
  return rawget(_G, "TechPriestsRocketSiloReadiness0709")
    or package.loaded["scripts.core.rocket_silo_readiness_0709"]
end

local function live_report(pair, silo)
  local doctrine = readiness()
  if not (doctrine and type(doctrine.inspect_silo) == "function"
    and valid_pair(pair) and valid(silo))
  then
    return nil, "readiness-unavailable"
  end
  local ok, report = pcall(doctrine.inspect_silo, pair, silo, true)
  if not ok or type(report) ~= "table" then return nil, "readiness-failed" end
  if report.launch_sequence_active then return report, "launch-sequence-active" end
  if report.automation_owned then return report, "external-logistics-owned" end
  return report, "manual-owner"
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
    if type(request) == "table" and request.source == "rocket-silo-logistics-0710"
      and (not task or not request.target_unit or request.target_unit == task.target_unit)
    then
      pair[field] = nil
    end
  end
end

local function carried_count(pair, task)
  local task_count = type(task and task.carried) == "table"
    and (tonumber(task.carried.count) or 0) or 0
  local custody = pair and pair.rocket_silo_custody_0710
  local custody_count = type(custody) == "table" and (tonumber(custody.count) or 0) or 0
  return math.max(task_count, custody_count)
end

local function abort_uncarried(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  task.phase = "aborted"
  task.completed_tick = now()
  task.result = reason
  pair.rocket_silo_logistics_last_task_0710 = task
  pair.rocket_silo_logistics_0710 = nil
  record(pair, "unsafe-silo-task-aborted",
    safe(task.family) .. " target=" .. safe(task.target_name) .. " reason=" .. reason)
end

local function guard_active_task(pair)
  local task = pair and pair.rocket_silo_logistics_0710
  if not (type(task) == "table" and valid(task.target)
    and task.target.type == "rocket-silo")
  then
    return false
  end
  local _, reason = live_report(pair, task.target)
  if reason == "manual-owner" then return false end
  if carried_count(pair, task) > 0 then
    task.phase = "return-custody"
    record(pair, "unsafe-silo-custody-return",
      safe(task.family) .. " target=" .. safe(task.target_name) .. " reason=" .. reason)
  else
    abort_uncarried(pair, task, reason)
  end
  return true
end

local function filter_reports(pair)
  local original = pair.rocket_silo_reports_0709
  if type(original) ~= "table" then return original end
  local filtered = {}
  for _, report in ipairs(original) do
    if type(report) == "table" and valid(report.silo) then
      local live, reason = live_report(pair, report.silo)
      if live then
        report = live
        if reason == "manual-owner" then
          filtered[#filtered + 1] = report
        else
          stat("reports-filtered-" .. reason)
        end
      end
    end
  end
  pair.rocket_silo_reports_0709 = filtered
  return original
end

local function patch_logistics(logistics)
  if not (logistics and type(logistics.service_pair) == "function") then return false end
  if logistics.rocket_silo_live_ownership_guard_0728_active then return true end
  logistics.rocket_silo_live_ownership_guard_0728_active = true
  previous_service_pair = logistics.service_pair
  logistics.service_pair = function(pair, reason, ...)
    if root().enabled == false or not valid_pair(pair) then
      return previous_service_pair(pair, reason, ...)
    end

    guard_active_task(pair)
    local original = filter_reports(pair)
    local acted, why = previous_service_pair(pair, reason, ...)
    if original ~= nil then pair.rocket_silo_reports_0709 = original end
    guard_active_task(pair)
    return acted, why
  end
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.rocket_silo_live_ownership_guard_0728_wrapped then return true end
  diagnostics.rocket_silo_live_ownership_guard_0728_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ROCKET-SILO-LIVE-GUARD-0728 enabled="
      .. safe(state.enabled)
      .. " launch_reports_filtered=" .. safe(state.stats["reports-filtered-launch-sequence-active"] or 0)
      .. " automation_reports_filtered=" .. safe(state.stats["reports-filtered-external-logistics-owned"] or 0)
      .. " tasks_aborted=" .. safe(state.stats["unsafe-silo-task-aborted"] or 0)
      .. " custody_returns=" .. safe(state.stats["unsafe-silo-custody-return"] or 0)
      .. " payload_mutations=0 launch_mutations=0 automation_mutations=0"
    for index = math.max(1, #state.recent - 8), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 rocket-silo-live-guard.recent["
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
  local ok, logistics = pcall(require, "scripts.core.rocket_silo_logistics_0710")
  if not (ok and logistics) then return false end
  local logistics_ok = patch_logistics(logistics)
  local diagnostics_ok = patch_diagnostics()
  _G.TechPriestsRocketSiloLiveOwnershipGuard0728 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] rocket silo live ownership guard armed logistics="
      .. safe(logistics_ok) .. " diagnostics=" .. safe(diagnostics_ok))
  end
  return logistics_ok and diagnostics_ok
end

return M
