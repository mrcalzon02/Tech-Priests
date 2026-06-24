-- Tech Priests 0.1.674-dev development-candidate integration audit.
--
-- Read-only cross-authority verification for the expanded logistics and fluid
-- families. Detects missing module activation, simultaneous exclusive tasks,
-- overlapping pipe plans, orphaned custody, mismatched plan construction tasks,
-- mismatched exact-item requests, invalid entity targets, surviving Tech Priests
-- commands, and storage values that Factorio cannot serialize. It reports only
-- and never clears, repairs, or retargets work.

local M = {
  version = "0.1.674-dev",
  storage_key = "development_integration_audit_0721",
  interval = 307,
  recent_limit = 180,
  serialization_interval = 3600,
  serialization_node_limit = 50000,
  serialization_issue_limit = 40,
}

local REQUIRED_GLOBALS = {
  "TechPriestsFluidNetworkDoctrine0689",
  "TechPriestsFluidOutputSinkDoctrine0694",
  "TechPriestsReservationPositionScope0697",
  "TechPriestsFluidConnectionPlanner0691",
  "TechPriestsFluidConnectionExecutionGuard0692",
  "TechPriestsFluidOutputConnectionPlanner0696",
  "TechPriestsFluidPortCollisionValidator0699",
  "TechPriestsFluidPortContextGuard0700",
  "TechPriestsItemFamilyLogistics0702",
  "TechPriestsItemFamilyIntegrity0703",
  "TechPriestsEnergyFamilyReadiness0705",
  "TechPriestsEnergyReadinessDiagnostics0711",
  "TechPriestsEnergyFamilyLogistics0707",
  "TechPriestsEnergyItemAutomationGuard0722",
  "TechPriestsRocketSiloReadiness0709",
  "TechPriestsRocketSiloLogistics0710",
  "TechPriestsArtilleryReadiness0712",
  "TechPriestsArtilleryLogistics0713",
  "TechPriestsRoboportReadiness0714",
  "TechPriestsRoboportRepairPackLogistics0715",
  "TechPriestsFluidTurretReadiness0716",
  "TechPriestsFluidTurretConnectionProposals0717",
  "TechPriestsFluidTurretProposalIntegrity0718",
  "TechPriestsFluidTurretConnectionPlanner0719",
  "TechPriestsRuntimeCommandCleanup0720",
}

local EXCLUSIVE_TASK_FIELDS = {
  "machine_logistics_0528",
  "item_family_logistics_0702",
  "energy_family_logistics_0707",
  "rocket_silo_logistics_0710",
  "artillery_logistics_0713",
  "roboport_repair_logistics_0715",
}

local PLAN_FIELDS = {
  "fluid_pipe_plan_0691",
  "fluid_output_pipe_plan_0696",
  "fluid_turret_pipe_plan_0719",
}

local CUSTODY_TASKS = {
  { custody = "machine_logistics_custody_0682", task = "machine_logistics_0528" },
  { custody = "item_family_custody_0702", task = "item_family_logistics_0702" },
  { custody = "energy_family_custody_0707", task = "energy_family_logistics_0707" },
  { custody = "rocket_silo_custody_0710", task = "rocket_silo_logistics_0710" },
  { custody = "artillery_custody_0713", task = "artillery_logistics_0713" },
  { custody = "roboport_repair_custody_0715", task = "roboport_repair_logistics_0715" },
}

local REQUEST_SOURCES = {
  ["item-family-logistics-0702"] = "item_family_logistics_0702",
  ["energy-family-logistics-0707"] = "energy_family_logistics_0707",
  ["rocket-silo-logistics-0710"] = "rocket_silo_logistics_0710",
  ["artillery-logistics-0713"] = "artillery_logistics_0713",
  ["roboport-repair-pack-logistics-0715"] = "roboport_repair_logistics_0715",
  ["fluid-connection-planner-0691"] = "fluid_pipe_plan_0691",
  ["fluid-output-connection-planner-0696"] = "fluid_output_pipe_plan_0696",
  ["fluid-turret-connection-planner-0719"] = "fluid_turret_pipe_plan_0719",
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
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    stats = {},
    recent = {},
    last = {},
    last_serialization = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.read_only == nil then state.read_only = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last = state.last or {}
  state.last_serialization = state.last_serialization or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function issue(pair, code, detail)
  local state = root()
  stat("issues")
  stat("issue-" .. tostring(code))
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = safe(station_unit(pair)),
    code = tostring(code),
    detail = tostring(detail or ""),
  }
  while #state.recent > M.recent_limit do table.remove(state.recent, 1) end
end

local function table_count(list)
  local count = 0
  for _ in pairs(list or {}) do count = count + 1 end
  return count
end

local function active_fields(pair, fields)
  local out = {}
  for _, field in ipairs(fields) do
    local value = pair[field]
    if type(value) == "table" then
      local phase = tostring(value.phase or value.state or "active")
      if phase ~= "complete" and phase ~= "completed"
        and phase ~= "done" and phase ~= "aborted" and phase ~= "failed"
      then
        out[#out + 1] = field
      end
    end
  end
  return out
end

local function target_of(task)
  if type(task) ~= "table" then return nil end
  return task.target or task.machine or task.entity or task.source_entity
end

local function check_target(pair, field)
  local task = pair[field]
  if type(task) ~= "table" then return end
  local entity = target_of(task)
  if entity ~= nil and not valid(entity) then
    issue(pair, "invalid-task-target", field)
  end
end

local function check_exclusive_tasks(pair)
  local active = active_fields(pair, EXCLUSIVE_TASK_FIELDS)
  if #active > 1 then
    issue(pair, "exclusive-task-overlap", table.concat(active, ","))
  end
  for _, field in ipairs(active) do check_target(pair, field) end
end

local function check_pipe_plans(pair)
  local active = active_fields(pair, PLAN_FIELDS)
  if #active > 1 then
    issue(pair, "pipe-plan-overlap", table.concat(active, ","))
  end
  for _, field in ipairs(active) do
    local plan = pair[field]
    if plan == pair then issue(pair, "self-referential-plan", field) end
    local endpoint = plan.turret or plan.machine
    if endpoint ~= nil and not valid(endpoint) then issue(pair, "invalid-plan-endpoint", field) end
    if plan.source and plan.source.entity ~= nil and not valid(plan.source.entity) then
      issue(pair, "invalid-plan-source", field)
    end
  end

  local construction = pair.construction_task_0338
  if type(construction) ~= "table" then return end
  if construction.fluid_pipe_plan_id_0691 then
    local plan = pair.fluid_pipe_plan_0691
    if not plan or plan.id ~= construction.fluid_pipe_plan_id_0691 then
      issue(pair, "orphan-input-pipe-task", safe(construction.fluid_pipe_plan_id_0691))
    end
  end
  if construction.fluid_output_pipe_plan_id_0696 then
    local plan = pair.fluid_output_pipe_plan_0696
    if not plan or plan.id ~= construction.fluid_output_pipe_plan_id_0696 then
      issue(pair, "orphan-output-pipe-task", safe(construction.fluid_output_pipe_plan_id_0696))
    end
  end
  if construction.fluid_turret_pipe_plan_id_0719 then
    local plan = pair.fluid_turret_pipe_plan_0719
    if not plan or plan.id ~= construction.fluid_turret_pipe_plan_id_0719 then
      issue(pair, "orphan-turret-pipe-task", safe(construction.fluid_turret_pipe_plan_id_0719))
    end
  end
end

local function custody_count(custody)
  if type(custody) ~= "table" then return 0 end
  return tonumber(custody.count)
    or tonumber(custody.carried_count)
    or tonumber(custody.amount)
    or 0
end

local function task_has_custody(task)
  return type(task) == "table"
    and type(task.carried) == "table"
    and (tonumber(task.carried.count) or 0) > 0
end

local function check_custody(pair)
  local custody_total = 0
  for _, mapping in ipairs(CUSTODY_TASKS) do
    local custody = pair[mapping.custody]
    local task = pair[mapping.task]
    local count = custody_count(custody)
    if count > 0 then
      custody_total = custody_total + 1
      if type(task) ~= "table" then
        issue(pair, "orphan-custody", mapping.custody .. " count=" .. safe(count))
      elseif not task_has_custody(task) then
        issue(pair, "custody-task-ledger-mismatch", mapping.custody .. "->" .. mapping.task)
      end
    elseif task_has_custody(task) then
      issue(pair, "missing-persistent-custody", mapping.task)
    end
  end
  if custody_total > 1 then issue(pair, "multiple-custody-ledgers", safe(custody_total)) end
end

local function request_source(request)
  return type(request) == "table" and request.source or nil
end

local function check_requests(pair)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    local request = pair[field]
    local source = request_source(request)
    local expected = source and REQUEST_SOURCES[source] or nil
    if expected and type(pair[expected]) ~= "table" then
      issue(pair, "orphan-item-request", field .. " source=" .. source)
    end
    if type(request) == "table" and request.item
      and prototypes and prototypes.fluid and prototypes.fluid[request.item]
    then
      issue(pair, "fluid-prototype-in-item-request", field .. " item=" .. request.item)
    end
  end
end

local function tech_priests_commands()
  local out = {}
  local registered
  if commands then pcall(function() registered = commands.commands end) end
  if type(registered) ~= "table" then return out end
  for name, description in pairs(registered) do
    local text = string.lower(tostring(description or ""))
    if string.find(text, "tech priests", 1, true)
      or string.find(text, "tech-priests", 1, true)
    then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

local function check_modules()
  local missing = {}
  for _, name in ipairs(REQUIRED_GLOBALS) do
    if rawget(_G, name) == nil then missing[#missing + 1] = name end
  end
  return missing
end

local function lua_object_name(value)
  local kind = type(value)
  if kind ~= "table" and kind ~= "userdata" then return nil end
  local ok, name = pcall(function() return value.object_name end)
  if ok and type(name) == "string" and string.sub(name, 1, 3) == "Lua" then
    return name
  end
  return nil
end

local function short_path(path)
  path = tostring(path or "storage")
  if #path <= 280 then return path end
  return string.sub(path, 1, 120) .. "..." .. string.sub(path, -120)
end

local function add_serialization_issue(scan, code, path, detail)
  scan.unsupported = scan.unsupported + 1
  if #scan.issues >= M.serialization_issue_limit then return end
  scan.issues[#scan.issues + 1] = {
    code = tostring(code),
    path = short_path(path),
    detail = tostring(detail or ""),
  }
end

local function scan_serializable(value, path, seen, scan)
  if scan.truncated then return end
  scan.nodes = scan.nodes + 1
  if scan.nodes > M.serialization_node_limit then
    scan.truncated = true
    return
  end

  local kind = type(value)
  if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then
    return
  end
  if kind == "function" or kind == "thread" then
    add_serialization_issue(scan, "storage-nonserializable-" .. kind, path, kind)
    return
  end

  local object = lua_object_name(value)
  if object then
    scan.lua_objects = scan.lua_objects + 1
    if object == "LuaCustomTable" then
      add_serialization_issue(scan, "storage-nonserializable-lua-custom-table", path, object)
    end
    return
  end

  if kind == "userdata" then
    add_serialization_issue(scan, "storage-nonserializable-userdata", path, kind)
    return
  end
  if kind ~= "table" then
    add_serialization_issue(scan, "storage-unsupported-type", path, kind)
    return
  end

  if seen[value] then
    scan.circular_references = scan.circular_references + 1
    return
  end
  seen[value] = true
  scan.tables = scan.tables + 1

  local ok, err = pcall(function()
    for key, child in pairs(value) do
      local key_kind = type(key)
      local key_object = lua_object_name(key)
      if key_kind == "function" or key_kind == "thread"
        or (key_kind == "userdata" and not key_object)
      then
        add_serialization_issue(scan, "storage-nonserializable-key", path, key_kind)
      elseif key_object == "LuaCustomTable" then
        add_serialization_issue(scan, "storage-nonserializable-key", path, key_object)
      end
      scan_serializable(child, path .. "[" .. safe(key) .. "]", seen, scan)
      if scan.truncated then break end
    end
  end)
  if not ok then
    add_serialization_issue(scan, "storage-iteration-failed", path, safe(err))
  end
end

local function inspect_storage_serialization()
  local scan = {
    tick = now(),
    nodes = 0,
    tables = 0,
    lua_objects = 0,
    circular_references = 0,
    unsupported = 0,
    truncated = false,
    issues = {},
  }
  scan_serializable(storage and storage.tech_priests or {}, "storage.tech_priests", {}, scan)
  return scan
end

local function maybe_audit_storage(state)
  local tick = now()
  local last_tick = tonumber(state.last_serialization_tick) or -M.serialization_interval
  if tick - last_tick < M.serialization_interval and next(state.last_serialization or {}) ~= nil then
    return state.last_serialization
  end

  local scan = inspect_storage_serialization()
  state.last_serialization_tick = tick
  state.last_serialization = scan
  stat("serialization-audits")
  stat("serialization-nodes", scan.nodes)
  stat("serialization-unsupported", scan.unsupported)
  if scan.truncated then stat("serialization-truncated") end
  for _, entry in ipairs(scan.issues) do
    issue(nil, entry.code, entry.path .. " " .. entry.detail)
  end
  return scan
end

function M.audit_pair(pair)
  if not valid_pair(pair) then return false, "invalid-pair" end
  local before = root().stats.issues or 0
  check_exclusive_tasks(pair)
  check_pipe_plans(pair)
  check_custody(pair)
  check_requests(pair)
  pair.development_integration_audit_0721 = {
    version = M.version,
    tick = now(),
    issues_added = (root().stats.issues or 0) - before,
    read_only = true,
  }
  return true, pair.development_integration_audit_0721.issues_added
end

function M.audit_all()
  local state = root()
  if state.enabled == false then return 0, "disabled" end
  local before = state.stats.issues or 0
  local pairs = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      M.audit_pair(pair)
      pairs = pairs + 1
    end
  end

  local missing = check_modules()
  for _, name in ipairs(missing) do issue(nil, "missing-module-global", name) end
  local remaining_commands = tech_priests_commands()
  for _, name in ipairs(remaining_commands) do issue(nil, "surviving-command", name) end
  local serialization = maybe_audit_storage(state)

  stat("audits")
  stat("pairs-audited", pairs)
  state.last = {
    tick = now(),
    pairs = pairs,
    issues_added = (state.stats.issues or 0) - before,
    missing_modules = missing,
    surviving_commands = remaining_commands,
    serialization = serialization,
  }
  return state.last.issues_added, "pairs=" .. safe(pairs)
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.development_integration_audit_0721_wrapped
  then
    return false
  end
  diagnostics.development_integration_audit_0721_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last or {}
    local serialization = last.serialization or state.last_serialization or {}
    lines[#lines + 1] = "PAIR-DUMP-0468 DEVELOPMENT-INTEGRATION-0721 enabled="
      .. safe(state.enabled)
      .. " read_only=true audits=" .. safe(state.stats.audits or 0)
      .. " pairs=" .. safe(last.pairs or 0)
      .. " last_issues=" .. safe(last.issues_added or 0)
      .. " total_issues=" .. safe(state.stats.issues or 0)
      .. " missing_modules=" .. safe(table_count(last.missing_modules))
      .. " surviving_commands=" .. safe(table_count(last.surviving_commands))
      .. " storage_nodes=" .. safe(serialization.nodes or 0)
      .. " storage_unsupported=" .. safe(serialization.unsupported or 0)
      .. " storage_cycles=" .. safe(serialization.circular_references or 0)
      .. " storage_scan_truncated=" .. safe(serialization.truncated == true)
    for index = math.max(1, #state.recent - 14), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 integration.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " station=" .. safe(event.station)
          .. " code=" .. safe(event.code)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "development_integration_audit_0721",
      category = "diagnostics",
      interval = M.interval,
      priority = 998,
      budget = 1,
      note = "read-only cross-authority task custody plan request module command and storage serialization audit",
      fn = function()
        local issues, why = M.audit_all()
        return issues > 0, why .. " issues=" .. safe(issues)
      end,
    })
  end
end

function M.install()
  root()
  patch_diagnostics()
  register_service()
  _G.TechPriestsDevelopmentIntegrationAudit0721 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] read-only development-candidate integration audit armed")
  end
  return true
end

return M
