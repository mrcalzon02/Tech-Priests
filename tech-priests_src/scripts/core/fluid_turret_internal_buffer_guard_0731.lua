-- Tech Priests 0.1.674-dev fluid-turret internal buffer correction.
--
-- LuaEntity.get_fluid_contents() aggregates fluidbox storage and non-fluidbox
-- storage, including a fluid turret's internal ammunition buffer. Subtract the
-- turret's local fluidbox contents before evaluating the activation threshold so
-- pipeline fluid cannot masquerade as ready internal ammunition. Read-only.

local M = {
  version = "0.1.674-dev",
  storage_key = "fluid_turret_internal_buffer_guard_0731",
}

local previous_inspect

local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function entity_contents(entity)
  local contents = {}
  if valid(entity) and entity.get_fluid_contents then
    pcall(function() contents = entity.get_fluid_contents() or {} end)
  end
  return type(contents) == "table" and contents or {}
end

local function local_fluidbox_contents(entity)
  local contents = {}
  if not valid(entity) then return contents end
  local box
  pcall(function() box = entity.fluidbox end)
  if not (box and box.valid) then return contents end
  for index = 1, #box do
    local fluid
    pcall(function() fluid = box[index] end)
    if type(fluid) == "table" and fluid.name then
      contents[fluid.name] = (contents[fluid.name] or 0) + (tonumber(fluid.amount) or 0)
    end
  end
  return contents
end

local function storage_records(entity)
  local out, count = {}, 0
  pcall(function() count = tonumber(entity.fluids_count) or 0 end)
  for index = 1, count do
    local fluid
    pcall(function() fluid = entity.get_fluid(index) end)
    if type(fluid) == "table" and fluid.name then
      out[#out + 1] = {
        index = index,
        name = fluid.name,
        amount = tonumber(fluid.amount) or 0,
        temperature = tonumber(fluid.temperature),
      }
    else
      out[#out + 1] = { index = index, amount = 0 }
    end
  end
  return out
end

local function corrected_buffer(entity, accepted)
  local total = entity_contents(entity)
  local local_pipe = local_fluidbox_contents(entity)
  local internal = {}
  for name, amount in pairs(total) do
    local remainder = math.max(0, (tonumber(amount) or 0) - (tonumber(local_pipe[name]) or 0))
    if remainder > 0.000001 then internal[name] = remainder end
  end

  local accepted_amount, wrong = 0, {}
  for name, amount in pairs(internal) do
    if accepted[name] then
      accepted_amount = accepted_amount + amount
    elseif amount > 0.001 then
      wrong[#wrong + 1] = { name = name, amount = amount }
    end
  end

  local size, ratio = 0, 0
  pcall(function() size = tonumber(entity.prototype.fluid_buffer_size) or 0 end)
  pcall(function() ratio = tonumber(entity.prototype.activation_buffer_ratio) or 0 end)
  local threshold = math.max(0, size * ratio)
  return {
    contents = internal,
    storages = storage_records(entity),
    entity_total_contents = total,
    local_fluidbox_contents = local_pipe,
    accepted_amount = accepted_amount,
    wrong_fluids = wrong,
    capacity = size,
    activation_ratio = ratio,
    activation_threshold = threshold,
    above_activation_threshold = accepted_amount + 0.001 >= threshold,
    separation_method_0731 = "entity-total-minus-local-fluidboxes",
  }
end

local function corrected_state(report)
  local pipeline = report.pipeline or {}
  local buffer = report.buffer or {}
  if #(report.accepted_fluids or {}) == 0 then
    return "accepted-fluid-unknown", "blocked"
  elseif #(pipeline.wrong_fluids or {}) > 0 or #(buffer.wrong_fluids or {}) > 0 then
    return "wrong-fluid-contamination", "blocked"
  elseif not pipeline.present then
    return "input-fluidbox-unavailable", "blocked"
  elseif not pipeline.connected then
    return "input-pipeline-unconnected", "blocked"
  elseif (tonumber(pipeline.accepted_amount) or 0) < 0.001
    and (tonumber(buffer.accepted_amount) or 0) <= 0.001
  then
    return "connected-pipeline-empty", "waiting"
  elseif not buffer.above_activation_threshold then
    return "internal-buffer-filling", "waiting"
  end
  return "fluid-ammunition-ready", "ready"
end

local function correct_report(report)
  if not (type(report) == "table" and valid(report.entity)
    and report.entity.type == "fluid-turret")
  then
    return report
  end
  local previous_state = report.state
  report.buffer = corrected_buffer(report.entity, report.accepted_lookup or {})
  report.state, report.severity = corrected_state(report)
  report.connection_required = report.state == "input-pipeline-unconnected"
  report.internal_buffer_corrected_0731 = true
  if report.state ~= previous_state then
    stat("reports-corrected")
    stat("from-" .. tostring(previous_state or "nil"))
    stat("to-" .. tostring(report.state or "nil"))
  end
  return report
end

local function patch_readiness(readiness)
  if not (readiness and type(readiness.inspect_entity) == "function") then return false end
  if readiness.fluid_turret_internal_buffer_guard_0731_active then return true end
  readiness.fluid_turret_internal_buffer_guard_0731_active = true
  previous_inspect = readiness.inspect_entity
  readiness.inspect_entity = function(...)
    local report, why = previous_inspect(...)
    return correct_report(report), why
  end
  _G.tech_priests_fluid_turret_inspect_0716 = readiness.inspect_entity
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.fluid_turret_internal_buffer_guard_0731_wrapped then return true end
  diagnostics.fluid_turret_internal_buffer_guard_0731_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-TURRET-BUFFER-GUARD-0731 enabled="
      .. safe(state.enabled)
      .. " corrected=" .. safe(state.stats["reports-corrected"] or 0)
      .. " method=entity-total-minus-local-fluidboxes"
      .. " fluid_mutations=0"
    return lines
  end
  return true
end

function M.install()
  root()
  local ok, readiness = pcall(require, "scripts.core.fluid_turret_readiness_0716")
  if not (ok and readiness) then return false end
  local readiness_ok = patch_readiness(readiness)
  local diagnostics_ok = patch_diagnostics()
  _G.TechPriestsFluidTurretInternalBufferGuard0731 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] fluid turret internal buffer correction armed readiness="
      .. safe(readiness_ok) .. " diagnostics=" .. safe(diagnostics_ok))
  end
  return readiness_ok and diagnostics_ok
end

return M
