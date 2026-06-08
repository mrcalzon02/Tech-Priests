-- scripts/core/efficiency_economy_0580.lua
-- Tech Priests 0.1.580
--
-- Consecration runtime economy pass.  This is a governor around the existing
-- consecration decay/update pipeline, not a new ritual controller.  It replaces
-- the old full-table update pulse with a budgeted rolling service that gives
-- priority to dirty/recently-active machines and lets clean idle machines sleep.

local M = {}
M.version = "0.1.580"
M.storage_key = "efficiency_economy_0580"
M.default_budget_per_call = 28
M.dirty_budget_share = 14
M.idle_sleep_ticks = 60 * 10
M.clean_sleep_ticks = 60 * 6
M.active_sleep_ticks = 30
M.recent_operation_sleep_ticks = 45
M.dirty_retry_ticks = 20
M.cleanup_interval = 60 * 23

local original_update_all = nil
local original_register_target = nil
local original_remove_target = nil
local original_apply_operation = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      budget_per_call = M.default_budget_per_call,
      dirty = {},
      cursor_keys = {},
      cursor_index = 1,
      next_rebuild_tick = 0,
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.budget_per_call = tonumber(r.budget_per_call) or M.default_budget_per_call
  r.dirty = r.dirty or {}
  r.cursor_keys = r.cursor_keys or {}
  r.cursor_index = tonumber(r.cursor_index) or 1
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function consecration_root()
  if not (storage and storage.tech_priests and storage.tech_priests.consecration) then return nil end
  return storage.tech_priests.consecration
end

local function machines_table()
  local c = consecration_root()
  return c and c.machines or nil
end

local function unit_of(entity_or_record)
  if valid(entity_or_record) then return entity_or_record.unit_number end
  if type(entity_or_record) == "table" then
    if entity_or_record.unit_number then return entity_or_record.unit_number end
    if valid(entity_or_record.entity) then return entity_or_record.entity.unit_number end
  end
  return nil
end

function M.mark_record_dirty(record, reason)
  local unit = unit_of(record)
  if not unit then return false end
  local r=M.root()
  r.dirty[tostring(unit)] = { tick=now(), reason=tostring(reason or "dirty") }
  stat("dirty_marks")
  return true
end

function M.mark_entity_dirty(entity, reason)
  if not valid(entity) then return false end
  local unit = entity.unit_number
  if not unit then return false end
  local machines = machines_table()
  if machines and machines[unit] then
    return M.mark_record_dirty(machines[unit], reason or "entity-dirty")
  end
  return false
end

local function rebuild_cursor_if_needed(root, machines)
  if now() < tonumber(root.next_rebuild_tick or 0) and type(root.cursor_keys) == "table" and #root.cursor_keys > 0 then return end
  local keys = {}
  for unit, _ in pairs(machines or {}) do keys[#keys+1] = unit end
  table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
  root.cursor_keys = keys
  if root.cursor_index > #keys then root.cursor_index = 1 end
  root.next_rebuild_tick = now() + 60 * 5
  stat("cursor_rebuilds")
end

local function entity_status_name(entity)
  if not valid(entity) then return "invalid" end
  local ok, st = pcall(function() return entity.status end)
  if not ok or st == nil then return "unknown" end
  return tostring(st)
end

local function is_active_record(record)
  if not (record and valid(record.entity)) then return false end
  local entity = record.entity
  local status = entity_status_name(entity)
  if status:find("working",1,true) or status:find("crafting",1,true) or status:find("mining",1,true) then return true end
  local progress = nil
  if _G.get_current_crafting_progress then pcall(function() progress = _G.get_current_crafting_progress(entity) end) end
  if tonumber(progress) and tonumber(progress) > 0 then return true end
  return false
end

local function next_delay_for(record, changed)
  if changed then return M.recent_operation_sleep_ticks end
  if not (record and valid(record.entity)) then return M.clean_sleep_ticks end
  if is_active_record(record) then return M.active_sleep_ticks end
  local last_op = tonumber(record.last_completed_operation_tick_0446 or record.last_sanctification_decay_tick_0417 or 0) or 0
  if last_op > 0 and now() - last_op < 60 * 20 then return M.clean_sleep_ticks end
  return M.idle_sleep_ticks
end

local function remove_record(unit, record)
  local c = consecration_root()
  if c and c.machines then c.machines[unit] = nil end
  if c and c.renders then
    local render = c.renders[unit]
    if render and _G.destroy_render_objects then pcall(_G.destroy_render_objects, render) end
    c.renders[unit] = nil
  end
  if _G.clear_sanctification_overlay then pcall(_G.clear_sanctification_overlay, unit) end
  stat("records_removed")
end

local function service_record(unit, record, reason)
  if not (record and valid(record.entity)) then remove_record(unit, record); return false end
  local before_op = tonumber(record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or 0) or 0
  local ok, changed = false, false
  if type(_G.update_machine_sanctification) == "function" then
    ok, changed = pcall(_G.update_machine_sanctification, record)
  end
  if not ok or changed == false then
    if not ok then
      record.next_sanctification_economy_tick_0580 = now() + M.dirty_retry_ticks
      record.last_sanctification_economy_error_0580 = tostring(changed)
      stat("service_errors")
      return false
    end
    remove_record(unit, record)
    return false
  end
  local after_op = tonumber(record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or 0) or 0
  local did_operation = after_op > before_op
  record.last_sanctification_economy_tick_0580 = now()
  record.next_sanctification_economy_tick_0580 = now() + next_delay_for(record, did_operation)
  if did_operation then M.mark_record_dirty(record, "operation-completed") end
  stat("records_serviced")
  if did_operation then stat("operation_records_serviced") end
  return true
end

local function service_dirty(root, machines, budget)
  local spent = 0
  local limit = math.min(budget, M.dirty_budget_share)
  local dirty_keys = {}
  for key, _ in pairs(root.dirty or {}) do dirty_keys[#dirty_keys+1] = key end
  table.sort(dirty_keys)
  for _, key in ipairs(dirty_keys) do
    if spent >= limit then break end
    local unit = tonumber(key) or key
    local record = machines[unit] or machines[key]
    root.dirty[key] = nil
    if record and valid(record.entity) then
      service_record(unit, record, "dirty")
      spent = spent + 1
    else
      stat("dirty_pruned")
    end
  end
  return spent
end

local function service_cursor(root, machines, budget)
  local spent = 0
  local keys = root.cursor_keys or {}
  if #keys == 0 then return 0 end
  local attempts = 0
  while spent < budget and attempts < #keys do
    attempts = attempts + 1
    local idx = root.cursor_index or 1
    if idx > #keys then idx = 1 end
    root.cursor_index = idx + 1
    local unit = keys[idx]
    local record = machines[unit]
    if record and valid(record.entity) then
      local due = tonumber(record.next_sanctification_economy_tick_0580 or 0) or 0
      if due <= now() then
        service_record(unit, record, "cursor")
        spent = spent + 1
      else
        stat("records_deferred_clean")
      end
    else
      if record ~= nil then remove_record(unit, record) end
      stat("cursor_invalid_skip")
    end
  end
  return spent
end

function M.update_all_budgeted()
  local r=M.root()
  if r.enabled == false then
    if original_update_all then return original_update_all() end
    return false
  end
  if not _G.update_machine_sanctification then return false end
  if _G.ensure_storage then pcall(_G.ensure_storage) end
  local machines = machines_table()
  if type(machines) ~= "table" then return false end
  rebuild_cursor_if_needed(r, machines)
  local budget = math.max(1, tonumber(r.budget_per_call) or M.default_budget_per_call)
  local spent_dirty = service_dirty(r, machines, budget)
  local spent_cursor = service_cursor(r, machines, math.max(0, budget - spent_dirty))
  stat("budget_calls")
  stat("budget_spent", spent_dirty + spent_cursor)
  r.last_budget_tick = now()
  r.last_budget_spent = spent_dirty + spent_cursor
  r.last_dirty_spent = spent_dirty
  r.last_cursor_spent = spent_cursor
  return true
end

local function wrap_update_all()
  if type(_G.update_all_consecration_targets) ~= "function" or original_update_all then return false end
  original_update_all = _G.update_all_consecration_targets
  _G.TECH_PRIESTS_0580_PRE_UPDATE_ALL_CONSECRATION_TARGETS = original_update_all
  _G.update_all_consecration_targets = function(...)
    return M.update_all_budgeted(...)
  end
  return true
end

local function wrap_registration()
  if type(_G.register_consecration_target) == "function" and not original_register_target then
    original_register_target = _G.register_consecration_target
    _G.register_consecration_target = function(entity, ...)
      local out = { original_register_target(entity, ...) }
      if valid(entity) then M.mark_entity_dirty(entity, "registered") end
      return table.unpack(out)
    end
  end
  if type(_G.remove_consecration_target) == "function" and not original_remove_target then
    original_remove_target = _G.remove_consecration_target
    _G.remove_consecration_target = function(entity, ...)
      if valid(entity) then M.mark_entity_dirty(entity, "removed") end
      return original_remove_target(entity, ...)
    end
  end
  if type(_G.apply_completed_sanctification_operation) == "function" and not original_apply_operation then
    original_apply_operation = _G.apply_completed_sanctification_operation
    _G.apply_completed_sanctification_operation = function(record, recipe, ...)
      local ok = original_apply_operation(record, recipe, ...)
      if ok and record then M.mark_record_dirty(record, "operation") end
      return ok
    end
  end
  return true
end

local function install_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not (R and R.on_event and defines and defines.events) then return false end
  local events = defines.events
  R.on_event({ events.on_built_entity, events.on_robot_built_entity, events.script_raised_built, events.script_raised_revive }, function(event)
    local entity = event and (event.entity or event.created_entity)
    if valid(entity) then M.mark_entity_dirty(entity, "built") end
  end, nil, { owner="efficiency_economy_0580", category="consecration", note="wake sanctification service for new machines" })
  R.on_event({ events.on_entity_damaged }, function(event)
    local entity = event and event.entity
    if valid(entity) then M.mark_entity_dirty(entity, "damaged") end
  end, nil, { owner="efficiency_economy_0580", category="consecration", note="wake sanctification service for damaged machines" })
  R.on_event({ events.on_player_mined_entity, events.on_robot_mined_entity, events.on_entity_died, events.script_raised_destroy }, function(event)
    local entity = event and event.entity
    if valid(entity) then M.mark_entity_dirty(entity, "removed-event") end
  end, nil, { owner="efficiency_economy_0580", category="consecration", note="remove/prune invalid sanctification records" })
  if R.on_nth_tick then
    R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0580", category="economy", priority="last", note="prune stale consecration dirty queue" })
  end
  return true
end

function M.cleanup()
  local r=M.root()
  local machines = machines_table() or {}
  for key, mark in pairs(r.dirty or {}) do
    local unit = tonumber(key) or key
    if not machines[unit] and not machines[key] then
      r.dirty[key] = nil
      stat("cleanup_dirty_missing")
    elseif type(mark) == "table" and tonumber(mark.tick or 0) and now() - tonumber(mark.tick or 0) > 60 * 30 then
      -- Keep long-lived dirty marks from becoming permanent priority churn.
      r.dirty[key] = nil
      stat("cleanup_dirty_stale")
    end
  end
  if tonumber(r.next_rebuild_tick or 0) < now() then r.next_rebuild_tick = now() end
end

local function selected_or_status(player)
  local r=M.root()
  local machines = machines_table() or {}
  local count = 0; for _ in pairs(machines) do count = count + 1 end
  local dirty = 0; for _ in pairs(r.dirty or {}) do dirty = dirty + 1 end
  return "[tp-efficiency-economy-0580] enabled="..safe(r.enabled).." machines="..safe(count).." dirty="..safe(dirty).." budget="..safe(r.budget_per_call).." last_spent="..safe(r.last_budget_spent or 0).." serviced="..safe(r.stats.records_serviced or 0).." deferred="..safe(r.stats.records_deferred_clean or 0).." operations="..safe(r.stats.operation_records_serviced or 0)
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0580") end end)
  commands.add_command("tp-efficiency-economy-0580", "Tech Priests 0.1.580 consecration economy. Params: on/off/status/budget N", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = tostring(event and event.parameter or "status")
    local r=M.root()
    local p = lower(param)
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    local n = tonumber(param:match("budget%s+(%d+)"))
    if n then r.budget_per_call = math.max(1, math.min(500, n)) end
    local msg = selected_or_status(player)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_registration()
  wrap_update_all()
  install_events()
  install_command()
  _G.TechPriestsEfficiencyEconomy0580 = M
  if log then log("[Tech-Priests 0.1.580] consecration economy installed; machine-spirit updates are budgeted and dirty-aware") end
  return true
end

return M
