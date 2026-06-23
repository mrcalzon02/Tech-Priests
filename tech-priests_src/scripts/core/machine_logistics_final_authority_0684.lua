-- Tech Priests 0.1.664 final machine-logistics authority.
-- Preserves the original no-task cooldown around the 0683 recovery scan, keeps
-- concrete machine pickup/delivery truth above generic emergency placeholder
-- text, removes the old command, and reports accurate hyphenated event counters.

local M = {
  version = "0.1.664",
  storage_key = "machine_logistics_final_authority_0684",
}

local previous_candidate_activate
local previous_machine_service
local previous_truth

local TERMINAL = {
  complete = true,
  completed = true,
  done = true,
  none = true,
  idle = true,
  failed = true,
  aborted = true,
  ["waiting-known-source-fetch"] = true,
}

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    preserve_no_task_cooldown = true,
    prefer_machine_leaf_over_generic_emergency = true,
    stats = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.preserve_no_task_cooldown == nil then r.preserve_no_task_cooldown = true end
  if r.prefer_machine_leaf_over_generic_emergency == nil then
    r.prefer_machine_leaf_over_generic_emergency = true
  end
  r.stats = r.stats or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function machine_root(machine)
  if machine and type(machine.root) == "function" then
    local ok, r = pcall(machine.root)
    if ok then return r end
  end
  return storage and storage.tech_priests
    and storage.tech_priests.logistics_machine_fulfillment_0528
    or nil
end

local function cooldown_active(machine, pair)
  if not valid_pair(pair) or pair.machine_logistics_0528 then return false end
  local r = machine_root(machine)
  local key = tostring(station_unit(pair) or "?")
  return r and r.cooldowns and (tonumber(r.cooldowns[key]) or 0) > now()
end

local function active_machine_state(pair)
  local state = pair and pair.machine_logistics_0528
  if type(state) ~= "table" then return nil end
  local phase = lower(state.phase)
  if phase == "" or TERMINAL[phase] then return nil end
  return state
end

local function machine_label(machine)
  if not valid(machine) then return "machine" end
  return tostring(machine.name) .. "#" .. tostring(machine.unit_number or "?")
end

local function machine_truth(pair)
  local state = active_machine_state(pair)
  if not (state and valid_pair(pair) and not valid(pair.combat_target)) then return nil end

  local phase = lower(state.phase)
  local target, truth_phase, label
  local item = state.item or (state.carried and state.carried.item)

  if phase == "move-to-station-for-supply" or phase == "collect-station-supply" then
    target = pair.station
    truth_phase = "collect-station-supply"
    label = "Collecting " .. safe(item) .. " from Cogitator"
  elseif phase == "move-to-machine" then
    target = state.machine
    if state.carried then
      truth_phase = "deliver-machine-supply"
      label = "Delivering " .. safe(item) .. " to " .. machine_label(state.machine)
    else
      truth_phase = "collect-machine-output"
      label = "Servicing " .. machine_label(state.machine)
    end
  elseif phase == "move-to-storage" then
    target = state.storage
    truth_phase = "deposit-machine-output"
    label = "Depositing " .. safe(item) .. " into storage"
  elseif phase == "return-custody-to-station" or phase == "custody-deposit-blocked" then
    target = pair.station
    truth_phase = "return-custody"
    label = "Returning " .. safe(item) .. " to Cogitator"
  end

  if not valid(target) then return nil end
  return {
    family = "logistics",
    phase = truth_phase or phase,
    entity = target,
    position = { x = target.position.x, y = target.position.y },
    item = item,
    label = label or "Machine logistics",
    owner = "machine-logistics-integrity-0682",
    priority = 976,
    radius = 1.2,
    color = { r = 1.0, g = 0.68, b = 0.18, a = 0.95 },
    can_move = true,
    source = "machine_logistics_integrity_0682",
  }
end

local function patch_truth()
  local ok, truth = pcall(require, "scripts.core.active_leaf_task_truth_0655")
  if not (ok and truth and type(truth.truth) == "function")
    or truth.machine_logistics_final_authority_0684_wrapped
  then
    return false
  end

  truth.machine_logistics_final_authority_0684_wrapped = true
  previous_truth = truth.truth
  truth.truth = function(pair)
    local existing = previous_truth(pair)
    if existing
      and existing.source == "emergency_craft"
      and root().prefer_machine_leaf_over_generic_emergency ~= false
    then
      local concrete = machine_truth(pair)
      if concrete then
        stat("generic_emergency_leaf_replaced")
        return concrete
      end
    end
    return existing or machine_truth(pair)
  end
  return true
end

local function patched_machine_service(pair, reason, ...)
  if root().enabled ~= false
    and root().preserve_no_task_cooldown ~= false
    and cooldown_active(M.machine, pair)
  then
    stat("recovery_scan_suppressed_by_cooldown")
    return false, "cooldown"
  end
  return previous_machine_service(pair, reason, ...)
end

local function remove_command()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-machine-logistics-0528")
  end
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.machine_logistics_final_authority_0684_wrapped
  then
    return false
  end

  diagnostics.machine_logistics_final_authority_0684_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local final = root()
    local integrity = storage and storage.tech_priests
      and storage.tech_priests.machine_logistics_integrity_0682
      or { stats = {} }
    local recovery = storage and storage.tech_priests
      and storage.tech_priests.machine_logistics_candidate_recovery_0683
      or { stats = {} }
    local is = integrity.stats or {}
    local rs = recovery.stats or {}

    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-FINAL-0684 enabled="
      .. safe(final.enabled)
      .. " station_routes=" .. safe(is["supply-routed-through-station"] or 0)
      .. " station_pickups=" .. safe(is["station-supply-picked-up"] or 0)
      .. " machine_inserts=" .. safe(is["machine-supply-inserted"] or 0)
      .. " custody_restored=" .. safe(is["orphaned-custody-restored"] or 0)
      .. " custody_blocked=" .. safe(is["custody-deposit-blocked"] or 0)
      .. " admission_blocked=" .. safe(is.new_machine_task_blocked or 0)
      .. " reservation_denied=" .. safe(is.machine_reservation_denied or 0)
      .. " false_automation_recovered=" .. safe(rs["false-automation-candidate-recovered"] or 0)
      .. " cooldown_suppressed=" .. safe(final.stats.recovery_scan_suppressed_by_cooldown or 0)
      .. " emergency_leaf_replaced=" .. safe(final.stats.generic_emergency_leaf_replaced or 0)

    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local state = pair.machine_logistics_0528 or {}
        local custody = pair.machine_logistics_custody_0682 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 machine-final[" .. safe(station_unit(pair)) .. "]"
          .. " phase=" .. safe(state.phase or "none")
          .. " action=" .. safe(state.action or "none")
          .. " item=" .. safe(state.item or custody.item or "none")
          .. " custody=" .. safe(custody.count or 0)
          .. " machine=" .. safe(state.machine_name or (valid(state.machine) and state.machine.name) or "none")
      end
    end
    return lines
  end
  return true
end

function M.activate(machine)
  if not (machine and type(machine.service_pair) == "function") then return false end
  if machine.machine_logistics_final_authority_0684_active then return true end
  machine.machine_logistics_final_authority_0684_active = true
  M.machine = machine
  previous_machine_service = machine.service_pair
  machine.service_pair = patched_machine_service
  patch_truth()
  patch_diagnostics()
  remove_command()
  _G.TechPriestsMachineLogisticsFinalAuthority0684 = M
  return true
end

function M.install()
  root()
  local ok, recovery = pcall(require, "scripts.core.machine_logistics_candidate_recovery_0683")
  if not (ok and recovery and type(recovery.activate) == "function") then return false end

  if not recovery.machine_logistics_final_authority_0684_activate_wrapped then
    recovery.machine_logistics_final_authority_0684_activate_wrapped = true
    previous_candidate_activate = recovery.activate
    recovery.activate = function(machine, ...)
      local result = previous_candidate_activate(machine, ...)
      M.activate(machine)
      return result
    end
  end

  local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
  if machine then M.activate(machine) end
  _G.TechPriestsMachineLogisticsFinalAuthority0684 = M
  return true
end

return M
