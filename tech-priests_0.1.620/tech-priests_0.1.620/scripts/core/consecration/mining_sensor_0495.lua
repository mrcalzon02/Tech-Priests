-- scripts/core/consecration/mining_sensor_0495.lua
-- Tech Priests 0.1.495
--
-- Mining drills do not reliably expose products_finished like assemblers and
-- furnaces. This late sensor records mining operation completions for
-- consecrated miners by watching mining progress wraps and output inventory
-- increases, then routes the completed operation through the same consecration
-- ledger/decay function used by crafting machines.

local M = {}
M.version = "0.1.544"
M.storage_key = "consecration_mining_sensor_0495"
M.tick_interval = 19
M.max_ops_per_tick = 8

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, delta)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (delta or 1)
end

local function record(action, rec, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = action,
    machine = rec and (rec.machine_id_0446 or rec.machine_id or rec.unit_number) or nil,
    entity = rec and rec.entity and rec.entity.valid and rec.entity.name or nil,
    detail = tostring(detail or "")
  }
  while #r.recent > 18 do table.remove(r.recent, 1) end
end

local function output_inventory(entity)
  if not valid(entity) then return nil end
  local ok, inv = pcall(function()
    if entity.get_output_inventory then return entity.get_output_inventory() end
    return nil
  end)
  if ok and inv and inv.valid then return inv end
  if defines and defines.inventory and defines.inventory.mining_drill_output then
    ok, inv = pcall(function() return entity.get_inventory(defines.inventory.mining_drill_output) end)
    if ok and inv and inv.valid then return inv end
  end
  return nil
end

local function inventory_total(inv)
  if not (inv and inv.valid) then return nil, nil end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not ok or type(contents) ~= "table" then return nil, nil end
  local total = 0
  local first_item = nil
  for key, value in pairs(contents) do
    local name = nil
    local count = 0
    if type(value) == "number" then
      name = tostring(key)
      count = value
    elseif type(value) == "table" then
      name = value.name or value[1] or tostring(key)
      count = tonumber(value.count or value.amount or value[2] or 0) or 0
    end
    if name and count > 0 then
      if not first_item then first_item = name end
      total = total + count
    end
  end
  return total, first_item
end

local function mining_progress(entity)
  if not valid(entity) then return nil end
  local ok, progress = pcall(function() return entity.mining_progress end)
  if ok and type(progress) == "number" then return progress end
  return nil
end

local function products_finished(entity)
  if not valid(entity) then return nil end
  local ok, value = pcall(function() return entity.products_finished end)
  if ok and type(value) == "number" then return value end
  return nil
end

local function mining_target_name(entity)
  if not valid(entity) then return nil end
  local ok, target = pcall(function() return entity.mining_target end)
  if ok and target and target.valid then return target.name end
  ok, target = pcall(function() return entity.prototype and entity.prototype.resource_categories end)
  if ok and target then return "mining-output" end
  return nil
end

local function pseudo_recipe(output_name)
  output_name = tostring(output_name or "mining-output")
  return {
    name = "mining:" .. output_name,
    products = {
      { type = "item", name = output_name, amount = 1 }
    }
  }
end

local function apply_mining_operation(record_obj, output_name, source)
  if not (record_obj and valid(record_obj.entity)) then return false end
  if type(apply_completed_sanctification_operation) ~= "function" then return false end
  local ok, result = pcall(apply_completed_sanctification_operation, record_obj, pseudo_recipe(output_name))
  if ok and result then
    record_obj.last_operation_sensor_0495 = source or "mining-sensor"
    record_obj.last_mining_output_0495 = output_name
    record_obj.last_mining_operation_tick_0495 = now()
    if draw_sanctification_label then pcall(draw_sanctification_label, record_obj) end
    if update_sanctification_overlay then pcall(update_sanctification_overlay, record_obj, true) end
    record("mining-operation", record_obj, "output=" .. tostring(output_name) .. " sensor=" .. tostring(source))
    return true
  end
  record("mining-operation-failed", record_obj, "output=" .. tostring(output_name) .. " sensor=" .. tostring(source) .. " error=" .. tostring(result))
  return false
end

function M.service_record(record_obj)
  if not (record_obj and valid(record_obj.entity)) then return false end
  local entity = record_obj.entity
  if entity.type ~= "mining-drill" then return false end

  local changed = false

  -- 0.1.544: Some mining drills expose products_finished; when present this is
  -- the cleanest operation counter and avoids relying on output inventory, which
  -- belts/inserters can empty before the polling window sees it.
  local finished = products_finished(entity)
  if finished ~= nil then
    local last_finished = record_obj.mining_products_finished_0544
    record_obj.mining_products_finished_0544 = finished
    record_obj.last_mining_products_finished_seen_0544 = finished
    if last_finished ~= nil and finished > last_finished then
      local ops = math.min(M.max_ops_per_tick, math.max(1, math.floor(finished - last_finished)))
      for _ = 1, ops do
        changed = apply_mining_operation(record_obj, mining_target_name(entity) or "mining-output", "products-finished") or changed
      end
    end
  end

  local inv = output_inventory(entity)
  local total, first_item = inventory_total(inv)
  if total ~= nil then
    local last = record_obj.mining_output_total_0495
    record_obj.mining_output_total_0495 = total
    record_obj.last_mining_output_total_seen_0495 = total
    if last ~= nil and total > last then
      local ops = math.min(M.max_ops_per_tick, math.max(1, math.floor(total - last)))
      for _ = 1, ops do
        changed = apply_mining_operation(record_obj, first_item or mining_target_name(entity) or "mining-output", "output-inventory") or changed
      end
    end
  end

  local progress = mining_progress(entity)
  if progress ~= nil then
    local last_progress = record_obj.mining_progress_0495
    record_obj.mining_progress_0495 = progress
    record_obj.last_mining_progress_seen_0495 = progress

    -- 0.1.544: Accumulate observed mining progress instead of only watching a
    -- high-to-low wrap. Polling at 37 ticks could miss short cycles entirely or
    -- see similar values on both sides of a completed extraction. This still
    -- avoids inventing remote work; it only observes a sanctified mining drill.
    if last_progress ~= nil then
      local delta = 0
      if progress >= last_progress then
        delta = progress - last_progress
      elseif last_progress > 0.05 then
        delta = (1 - last_progress) + progress
      end
      if delta > 0 and delta < 1.5 then
        record_obj.mining_progress_accumulator_0544 = (record_obj.mining_progress_accumulator_0544 or 0) + delta
      end
      local guard = 0
      while (record_obj.mining_progress_accumulator_0544 or 0) >= 1 and guard < M.max_ops_per_tick do
        record_obj.mining_progress_accumulator_0544 = (record_obj.mining_progress_accumulator_0544 or 0) - 1
        guard = guard + 1
        if now() - tonumber(record_obj.last_mining_operation_tick_0495 or -1000000) > 1 then
          changed = apply_mining_operation(record_obj, mining_target_name(entity) or first_item or "mining-output", "mining-progress-accumulator") or changed
        end
      end
    end
  end

  if changed then stat("records_changed") end
  return changed
end

function M.service_all()
  local r = root()
  if r.enabled == false then return end
  local machines = storage and storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.machines or nil
  if not machines then return end
  for _, record_obj in pairs(machines) do
    M.service_record(record_obj)
  end
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.consecration_mining_sensor_wrapped_0495 then return false end
  local prev = diag.pair_dump_lines
  diag.consecration_mining_sensor_wrapped_0495 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "PAIR-DUMP-0468 CONSECRATION-MINING-SENSOR-0495 BEGIN enabled=" .. tostring(r.enabled)
      .. " operations=" .. tostring(r.stats["mining-operation"] or 0)
      .. " changed=" .. tostring(r.stats.records_changed or 0)
    for i = math.max(1, #r.recent - 8), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 mining0495[" .. tostring(i) .. "] tick=" .. tostring(ev.tick) .. " action=" .. tostring(ev.action) .. " machine=" .. tostring(ev.machine) .. " entity=" .. tostring(ev.entity) .. " " .. tostring(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 CONSECRATION-MINING-SENSOR-0495 END"
    return lines
  end
  return true
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-consecration-mining-0495") end end)
  commands.add_command("tp-consecration-mining-0495", "Tech Priests: consecration mining-operation sensor status. Usage: status|once|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "once" or p == "all" then M.service_all() end
    if player and player.valid then
      player.print("[tp-consecration-mining-0495] enabled=" .. tostring(r.enabled)
        .. " mining_ops=" .. tostring(r.stats["mining-operation"] or 0)
        .. " changed=" .. tostring(r.stats.records_changed or 0))
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  _G.TechPriestsConsecrationMiningSensor0495 = M
  M.wrap_pair_dump()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "consecration_mining_sensor_0495", category = "consecration", priority = "normal" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.544] consecration mining sensor installed; mining drills use products_finished/output/progress accumulator operation counters") end
  return true
end

return M
