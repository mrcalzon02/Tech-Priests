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
  serialization_work_budget = 256,
  serialization_continuation_interval = 5,
  serialization_frame_limit = 2048,
  serialization_schema = 2,
  serialization_issue_limit = 40,
}
local registered_service

-- Require the current owners after 0646's declared consolidation. Intentional
-- retirements are reported from that same declaration, not as missing globals.
local REQUIRED_GLOBALS = {
  "TechPriestsFluidNetworkDoctrine0689",
  "TechPriestsWorkReservations0601",
  "TechPriestsFluidConnectionPlanner0691",
  "TechPriestsItemFamilyLogistics0702",
  "TechPriestsEnergyFamilyReadiness0705",
  "TechPriestsEnergyFamilyLogistics0707",
  "TechPriestsRocketSiloReadiness0709",
  "TechPriestsRocketSiloLogistics0710",
  "TechPriestsArtilleryReadiness0712",
  "TechPriestsArtilleryLogistics0713",
  "TechPriestsRoboportReadiness0714",
  "TechPriestsRoboportRepairPackLogistics0715",
  "TechPriestsFluidTurretReadiness0716",
  "TechPriestsFluidTurretConnectionProposals0717",
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
  local cleanup = rawget(_G, "TechPriestsRuntimeCommandCleanup0720")
    or package.loaded["scripts.core.runtime_command_cleanup_0720"]
  if not (cleanup and type(cleanup.is_managed_command) == "function") then
    return out, false
  end
  local registered
  if commands then pcall(function() registered = commands.commands end) end
  if type(registered) ~= "table" then return out, true end
  for name, description in pairs(registered) do
    if cleanup.is_managed_command(name, description) then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out, true
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
  -- Native LuaObjects are userdata. A plain saved table can contain an
  -- object_name field without becoming an opaque, serializable engine object.
  if kind ~= "userdata" then return nil end
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
  scan.failed = true
  if #scan.issues >= M.serialization_issue_limit then return end
  scan.issues[#scan.issues + 1] = {
    code = tostring(code),
    path = short_path(path),
    detail = tostring(detail or ""),
  }
  issue(nil, code, short_path(path) .. " " .. tostring(detail or ""))
end

local function schedule_audit(state)
  local tick = now()
  local due = tonumber(state.next_audit_tick_0721) or tick
  if state.enabled == false then
    due = tick + M.interval
  elseif state.serialization_job_0721 then
    due = math.min(due, tick + M.serialization_continuation_interval)
  else
    local serial_due = (tonumber(state.last_serialization_tick) or -M.serialization_interval)
      + M.serialization_interval
    if state.last_serialization.schema ~= M.serialization_schema then serial_due = tick end
    due = math.min(due, serial_due)
  end
  due = math.max(tick + M.serialization_continuation_interval, due)
  state.next_service_tick_0721 = due
  if registered_service then
    registered_service.next_due_tick = due
    local ran = rawget(_G, "tech_priests_broker_ran_0598")
    if type(ran) == "function" then ran(registered_service) end
  end
end

local function update_serialization_status(state, scan)
  local last = state.last
  last.serialization = scan
  last.pending = scan.pending == true
  last.issues_current = (tonumber(last.behavior_issues) or 0) + (tonumber(scan.unsupported) or 0)
  last.complete = scan.complete == true and scan.failed ~= true
    and last.issues_current == 0
end

local function maybe_audit_storage(state)
  local job = state.serialization_job_0721
  if job then return job.scan end
  local tick, previous = now(), state.last_serialization
  local last_tick = tonumber(state.last_serialization_tick) or -M.serialization_interval
  if previous.schema == M.serialization_schema and tick - last_tick < M.serialization_interval then
    return previous
  end
  local scan = {schema = M.serialization_schema, tick = tick, finished_tick = 0,
    nodes = 0, tables = 0, lua_objects = 0, circular_references = 0,
    unsupported = 0, truncated = false, issues = {}, pending = true,
    complete = false, failed = false, status = "pending", work = 0,
    last_step_tick = 0, last_step_work = 0, cursor_resets = 0,
    observation = "rolling-live-storage"}
  -- Only the job holds traversal references. Public receipts hold the scalar
  -- summary and bounded issue records, never frames, seen maps or raw values.
  state.serialization_job_0721 = {root = storage.tech_priests, phase = "root",
    frames = {}, seen = {}, scan = scan}
  state.last_serialization = scan
  state.stats["serialization-audits"] = (state.stats["serialization-audits"] or 0) + 1
  return scan
end

local function key_path(frame, key, key_table)
  local kind = type(key)
  local segment
  if key_table then segment = "key#" .. frame.ordinal
  elseif kind == "string" then segment = string.sub(key, 1, 100)
  elseif kind == "number" or kind == "boolean" then segment = tostring(key)
  else segment = "<" .. kind .. "-key#" .. frame.ordinal .. ">" end
  return short_path(frame.path .. "[" .. segment .. "]")
end

local function inspect_value(job, value, path)
  -- The cursor's growing implementation state is not part of its own input.
  if value == job then return end
  local scan, kind = job.scan, type(value)
  scan.nodes = scan.nodes + 1
  if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then return end
  if kind == "function" or kind == "thread" then
    add_serialization_issue(scan, "storage-nonserializable-" .. kind, path, kind); return
  end
  local object = lua_object_name(value)
  if object then
    scan.lua_objects = scan.lua_objects + 1
    if object == "LuaCustomTable" then
      add_serialization_issue(scan, "storage-nonserializable-lua-custom-table", path, object)
    end
    return
  end
  if kind ~= "table" then
    add_serialization_issue(scan, "storage-nonserializable-" .. kind, path, kind); return
  end
  if job.seen[value] then scan.circular_references = scan.circular_references + 1; return end
  if #job.frames >= M.serialization_frame_limit then
    add_serialization_issue(scan, "storage-depth-limit", path, "frame-limit")
    scan.truncated = true; job.abort_reason = "frame-limit"; return
  end
  job.seen[value] = true
  scan.tables = scan.tables + 1
  job.frames[#job.frames + 1] = {value = value, path = path, phase = "next",
    processed = {}, ordinal = 0}
end

local function finish_serialization(state, job)
  local scan = job.scan
  scan.pending = false
  scan.complete = job.abort_reason == nil
  scan.failed = scan.failed or job.abort_reason ~= nil
  scan.status = scan.failed and "failed" or "complete"
  scan.finished_tick = now()
  scan.abort_reason = job.abort_reason
  state.serialization_job_0721 = nil
  if scan.complete then state.last_completed_serialization_0721 = scan end
  -- Allow a completed result to be observed even if the walk itself exceeded
  -- 3600 ticks. A periodic deadline never restarts an in-flight traversal.
  state.last_serialization_tick = job.abort_reason == "root-changed"
    and (now() - M.serialization_interval) or now()
  local name = scan.complete and "serialization-completed" or "serialization-incomplete"
  state.stats[name] = (state.stats[name] or 0) + 1
  if scan.truncated then
    state.stats["serialization-truncated"] = (state.stats["serialization-truncated"] or 0) + 1
  end
end

function M.step_storage_audit(requested_budget)
  local state, tick = root(), now()
  local job = state.serialization_job_0721
  if not job or state.enabled == false then return state.last_serialization, 0 end
  if state.serialization_step_tick_0721 ~= tick then
    state.serialization_step_tick_0721, state.serialization_step_work_0721 = tick, 0
  end
  local cap = math.max(1, math.floor(tonumber(M.serialization_work_budget) or 256))
  local left = math.max(0, cap - (state.serialization_step_work_0721 or 0))
  local budget = math.min(left, math.max(0, math.floor(tonumber(requested_budget) or cap)))
  local scan, used = job.scan, 0
  local old_nodes, old_unsupported = scan.nodes, scan.unsupported
  if job.root ~= storage.tech_priests then job.abort_reason = "root-changed" end
  while used < budget do
    if job.abort_reason or (job.phase ~= "root" and #job.frames == 0) then
      used = used + 1; finish_serialization(state, job); break
    end
    if job.phase == "root" then
      if budget - used < 2 then break end
      used = used + 2; job.phase = "tables"
      inspect_value(job, job.root, "storage.tech_priests")
    else
      local frame = job.frames[#job.frames]
      if frame.phase == "pop" then
        used = used + 1; job.frames[#job.frames] = nil
      elseif frame.phase == "key" then
        if budget - used < 3 then break end
        used = used + 3; frame.phase = "value"
        inspect_value(job, frame.current_key, key_path(frame, frame.current_key, true))
      elseif frame.phase == "value" then
        if budget - used < 3 then break end
        used = used + 3
        local key = frame.current_key
        frame.current_key, frame.phase = nil, "next"
        inspect_value(job, rawget(frame.value, key), key_path(frame, key, false))
      elseif frame.cursor ~= nil and rawget(frame.value, frame.cursor) == nil then
        -- Deletion can invalidate next(table, cursor). Restart this frame only;
        -- persisted processed keys prevent duplicate inspection, and skips cost work.
        used = used + 1; frame.cursor = nil; scan.cursor_resets = scan.cursor_resets + 1
      else
        if budget - used < 3 then break end
        used = used + 3
        local ok, key = pcall(next, frame.value, frame.cursor)
        if not ok then
          add_serialization_issue(scan, "storage-iteration-failed", frame.path, "next-failed")
          job.abort_reason = "iteration-failed"
        elseif key == nil then
          frame.phase = "pop"
        else
          local kind, object = type(key), lua_object_name(key)
          if kind == "function" or kind == "thread" or object == "LuaCustomTable"
              or (kind == "userdata" and not object) then
            add_serialization_issue(scan, "storage-nonserializable-key", frame.path, object or kind)
            -- Never save an unsupported value as a bookmark or visited-map key.
            job.abort_reason = "unsupported-key"
          else
            frame.cursor = key
            if not frame.processed[key] then
              frame.processed[key] = true; frame.current_key = key
              frame.ordinal = frame.ordinal + 1
              frame.phase = kind == "table" and "key" or "value"
            end
          end
        end
      end
    end
  end
  state.serialization_step_work_0721 = (state.serialization_step_work_0721 or 0) + used
  scan.work = scan.work + used
  scan.last_step_tick, scan.last_step_work = tick, state.serialization_step_work_0721
  state.stats["serialization-work"] = (state.stats["serialization-work"] or 0) + used
  state.stats["serialization-nodes"] = (state.stats["serialization-nodes"] or 0) + scan.nodes - old_nodes
  state.stats["serialization-unsupported"] = (state.stats["serialization-unsupported"] or 0)
    + scan.unsupported - old_unsupported
  update_serialization_status(state, scan)
  schedule_audit(state)
  return scan, used
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
  if state.enabled == false then return 0, "disabled", {complete = false, pending = false} end
  local before = state.stats.issues or 0
  local audited_pairs = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      M.audit_pair(pair)
      audited_pairs = audited_pairs + 1
    end
  end

  local missing = check_modules()
  for _, name in ipairs(missing) do issue(nil, "missing-module-global", name) end
  local remaining_commands, command_policy_available = tech_priests_commands()
  if not command_policy_available then issue(nil, "command-policy-unavailable", "runtime_command_cleanup_0720") end
  for _, name in ipairs(remaining_commands) do issue(nil, "surviving-command", name) end
  local serialization = maybe_audit_storage(state)
  local constraints = rawget(_G, "TechPriestsPlanningConstraints0646")
  local retired = constraints and constraints.RETIRED

  stat("audits")
  stat("pairs-audited", audited_pairs)
  state.last = {
    tick = now(),
    pairs = audited_pairs,
    issues_added = (state.stats.issues or 0) - before,
    missing_modules = missing,
    -- Report the loader's declaration itself; missing live replacement globals
    -- above remain real audit issues, not silently skipped retirements.
    retired_modules = type(retired) == "table" and retired or {},
    retirement_registry_available = type(retired) == "table",
    surviving_commands = remaining_commands,
    command_policy_available = command_policy_available,
    serialization = serialization,
  }
  state.last.behavior_issues = state.last.issues_added
  state.next_audit_tick_0721 = now() + M.interval
  update_serialization_status(state, serialization)
  schedule_audit(state)
  return state.last.issues_current, "pairs=" .. safe(audited_pairs)
    .. " serialization=" .. tostring(serialization.status), state.last
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
      .. " retirement_registry_available=" .. safe(last.retirement_registry_available)
      .. " surviving_commands=" .. safe(table_count(last.surviving_commands))
      .. " storage_nodes=" .. safe(serialization.nodes or 0)
      .. " storage_unsupported=" .. safe(serialization.unsupported or 0)
      .. " storage_cycles=" .. safe(serialization.circular_references or 0)
      .. " storage_scan_truncated=" .. safe(serialization.truncated == true)
      .. " storage_pending=" .. safe(serialization.pending == true)
      .. " storage_complete=" .. safe(serialization.complete == true)
      .. " storage_failed=" .. safe(serialization.failed == true)
      .. " storage_step_work=" .. safe(serialization.last_step_work or 0)
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

M.patch_diagnostics = patch_diagnostics

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    registered_service = broker.register_service({
      name = "development_integration_audit_0721",
      category = "diagnostics",
      interval = M.interval,
      priority = 998,
      budget = 1,
      next_due_tick = root().next_service_tick_0721,
      note = "read-only cross-authority task custody plan request module command and storage serialization audit",
      fn = function(_, _, service)
        if service then registered_service = service end
        local state = root()
        if state.enabled == false then
          schedule_audit(state)
          return {processed = 0, acted = 0, detail = "disabled"}
        end
        local audited = 0
        if now() >= (tonumber(state.next_audit_tick_0721) or 0) then
          M.audit_all(); audited = 1
        else
          maybe_audit_storage(state)
        end
        local scan, work = M.step_storage_audit(M.serialization_work_budget)
        update_serialization_status(state, scan)
        schedule_audit(state)
        local issues = tonumber(state.last.issues_current) or 0
        return {processed = audited + work, acted = 0,
          waiting = scan.pending and 1 or 0,
          failed = (issues > 0 or scan.failed) and 1 or 0,
          exhausted = scan.pending == true,
          detail = "pairs=" .. safe(state.last.pairs or 0)
            .. " issues=" .. safe(issues) .. " serialization=" .. safe(scan.status)
            .. " work=" .. safe(work)}
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
