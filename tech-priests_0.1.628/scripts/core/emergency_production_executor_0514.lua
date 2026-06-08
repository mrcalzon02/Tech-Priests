-- scripts/core/emergency_production_executor_0514.lua
-- Tech Priests 0.1.514
--
-- Dispatcher-owned emergency production executor.  This module is the first
-- cleanup pass for the “I need an item” production chain after direct
-- acquisition was migrated in 0.1.513.  It keeps Martian emergency facility
-- doctrine as a leaf helper, but prevents it and the old desperation craft
-- handler from acting as independent controllers while the dispatcher owns
-- station/emergency production.

local M = {}
M.version = "0.1.514"
M.storage_key = "emergency_production_executor_0514"
M.station_close_distance_sq = 5.76
M.move_refresh_ticks = 45
M.progress_refresh_ticks = 12
M.default_station_craft_ticks = 240
M.facility_wait_ticks = 60 * 8
M.max_pairs_per_pulse = 24

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end; local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function at_station(pair) return valid_pair(pair) and (dist_sq(pair.priest.position, pair.station.position) or 999999) <= M.station_close_distance_sq end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item then local ok, p = pcall(function() return prototypes.item[name] end); return ok and p ~= nil end
  return true
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    suppress_independent_facility_pulses = true,
    block_legacy_desperation_craft = true,
    prefer_emergency_facilities = true,
    allow_timed_station_fallback = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.suppress_independent_facility_pulses == nil then r.suppress_independent_facility_pulses = true end
  if r.block_legacy_desperation_craft == nil then r.block_legacy_desperation_craft = true end
  if r.prefer_emergency_facilities == nil then r.prefer_emergency_facilities = true end
  if r.allow_timed_station_fallback == nil then r.allow_timed_station_fallback = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail)
  local r = M.root()
  stat(action)
  local rec = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), priest = safe(priest_unit(pair)), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 160 do table.remove(r.recent, 1) end
end

local function draw(pair, text, ttl)
  if _G.tech_priests_emit_overhead_status_0473 then
    return pcall(_G.tech_priests_emit_overhead_status_0473, pair, text, { r = 1.0, g = 0.74, b = 0.20, a = 0.98 }, ttl or 45, 0.64, "emergency-production-0514")
  end
  if _G.tech_priests_draw_emergency_operation_status_0184 then return pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  return false
end

local function bar(progress, width)
  width = width or 16
  progress = math.max(0, math.min(1, tonumber(progress) or 0))
  local filled = math.floor(progress * width + 0.5)
  local out = ""
  for i = 1, width do out = out .. (i <= filled and "█" or "░") end
  return out
end

local function station_inventory(pair)
  if not (valid(pair and pair.station) and pair.station.get_inventory) then return nil end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
  }
  for _, id in ipairs(ids) do
    local ok, inv = pcall(function() return pair.station.get_inventory(id) end)
    if ok and inv and inv.valid then return inv end
  end
  return nil
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, n = pcall(function() return inv.remove({ name = item, count = count }) end)
  return ok and (tonumber(n) or 0) or 0
end

local function inv_insert(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, n = pcall(function() return inv.insert({ name = item, count = count }) end)
  return ok and (tonumber(n) or 0) or 0
end

local function station_count(pair, item)
  return inv_count(station_inventory(pair), item)
end

local function station_insert(pair, item, count)
  local inv = station_inventory(pair)
  if not inv then return 0 end
  return inv_insert(inv, item, count or 1)
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return q and q.current or nil
end

local function task_item(task)
  if type(task) == "string" then return task end
  if type(task) ~= "table" then return nil end
  return task.output_item or task.item_name or task.item or task.name or task.wanted_item or task.requested_item or (task.request and (task.request.item_name or task.request.name))
end

local function current_task(pair)
  if not pair then return nil, nil end
  if pair.emergency_craft then return pair.emergency_craft, "emergency_craft" end
  if pair.station_crafting_task_0337 then return pair.station_crafting_task_0337, "station_crafting_task_0337" end
  if pair.active_craft_0479 then return pair.active_craft_0479, "active_craft_0479" end
  local order = current_order(pair)
  if order and (order.kind == "emergency_craft" or lower(order.kind):find("craft", 1, true) or lower(order.reason):find("craft", 1, true)) and order.item then
    return { item_name = order.item, output_item = order.item, count = order.count or 1, order_key_0514 = order.key, order_proxy_0514 = true }, "order_proxy"
  end
  return nil, nil
end

local DIRECT_KINDS = { ["direct-mine-0273"] = true, ["direct-dirt-0273"] = true, ["direct-mine-0336"] = true, dirt = true }
local function task_has_direct_current(task)
  local cur = task and (task.current or task)
  return cur and DIRECT_KINDS[tostring(cur.kind or "")] == true and (valid(cur.entity) or cur.position)
end

local function needed_count(task)
  return math.max(1, tonumber(task and (task.count or task.required_count or task.amount)) or 1)
end

local function needed_units(task)
  local recipe = task and task.recipe or nil
  return math.max(1, tonumber(recipe and recipe.units) or tonumber(task and task.required_count) or 1)
end

local function gathered_units(task)
  return tonumber(task and task.gathered_units) or 0
end

local function ready_materials(task)
  if not task then return false end
  if task.station_craft_pending_0337 or task.station_craft_pending_0513 or task.station_craft_pending_0514 then return true end
  if gathered_units(task) >= needed_units(task) then return true end
  -- Bootstrap/device items with no recipe body may be allowed to use station fallback
  -- when the older chain has already represented them as an emergency craft task.
  if task.order_proxy_0514 then return false end
  return (task.recipe == nil and task.current == nil and task.item_name ~= nil)
end

local function set_phase(pair, phase, detail)
  pair.dispatcher_action = "emergency-production"
  pair.dispatcher_phase = phase
  pair.dispatcher_emergency_production_0514 = pair.dispatcher_emergency_production_0514 or {}
  local s = pair.dispatcher_emergency_production_0514
  s.version = M.version
  s.phase = phase
  s.tick = now()
  s.detail = tostring(detail or "")
  if not s.started_tick then s.started_tick = now() end
  s.last_seen_tick = now()
end

local function complete_order_if_matches(pair, item, reason)
  local q = pair and pair.order_queue_0469
  local order = q and q.current or nil
  if not (q and order) then return false end
  local oi = order.item or order.wanted_item or order.requested_item
  if item and oi and tostring(oi) ~= tostring(item) then return false end
  order.status = "complete"
  order.finished_tick = now()
  order.finish_reason = reason or "emergency-production-0514"
  q.history = q.history or {}
  q.history[#q.history + 1] = { key = order.key or "nil", kind = order.kind or "nil", item = order.item, status = "complete", reason = order.finish_reason, tick = now() }
  while #q.history > 12 do table.remove(q.history, 1) end
  q.current = nil
  pair.active_order_0469 = nil
  return true
end

local function clear_task(pair, source)
  if not pair then return end
  if source == "emergency_craft" then pair.emergency_craft = nil end
  if source == "station_crafting_task_0337" then pair.station_crafting_task_0337 = nil end
  if source == "active_craft_0479" then pair.active_craft_0479 = nil end
  if source == "order_proxy" then return end
end

local function request_move_station(pair, reason)
  if not valid_pair(pair) then return false end
  pair.mode = "returning-to-station-for-production"
  pair.target = pair.station
  local stale = (not pair.last_emergency_production_move_0514) or now() - (pair.last_emergency_production_move_0514.tick or 0) >= M.move_refresh_ticks
  if not stale then return true end
  local ok = false
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pair.station.position, reason or "emergency-production-0514", { radius = 1.15, owner = "emergency-production-0514", priority = 620, ttl = 600, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pair.station.position, radius = 1.15, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "emergency-production-fallback-0621", { pair = pair, priority = 620, ttl = 600 })
        ok = ok_route and res ~= false
      elseif pair.priest.commandable and pair.priest.commandable.valid then
        pair.priest.commandable.set_command(command)
        ok = true
      elseif pair.priest.set_command then
        pair.priest.set_command(command)
        ok = true
      end
    end
  end)
  pair.last_emergency_production_move_0514 = { tick = now(), ok = ok, reason = reason or "emergency-production-0514" }
  return ok
end

local function facility_root()
  return storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343 or nil
end

local function facility_records(pair)
  local root = facility_root()
  local key = station_unit(pair)
  local out = {}
  if not (root and key and root.by_station and root.facilities) then return out end
  local bucket = root.by_station[key]
  if bucket then
    for rec_key in pairs(bucket) do
      local rec = root.facilities[rec_key]
      if rec and valid(rec.entity) then out[#out + 1] = rec
      elseif root.facilities then root.facilities[rec_key] = nil end
    end
  end
  return out
end

local function facility_inventory(entity, id)
  if not (valid(entity) and entity.get_inventory and id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function collect_from_facilities(pair, item, count)
  if not (valid_pair(pair) and item and item_exists(item)) then return 0 end
  local need = math.max(1, tonumber(count) or 1)
  local moved = 0
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_result,
    defines.inventory.assembling_machine_input,
  }
  for _, rec in ipairs(facility_records(pair)) do
    if moved >= need then break end
    local e = rec.entity
    for _, id in ipairs(ids) do
      if moved >= need then break end
      local inv = facility_inventory(e, id)
      local have = inv_count(inv, item)
      if have > 0 then
        local take = math.min(have, need - moved)
        local removed = inv_remove(inv, item, take)
        if removed > 0 then
          local inserted = station_insert(pair, item, removed)
          if inserted < removed then inv_insert(inv, item, removed - inserted) end
          moved = moved + inserted
        end
      end
    end
  end
  return moved
end

local function production_role_for(item)
  item = tostring(item or "")
  if item == "iron-plate" or item == "copper-plate" or item == "stone-brick" then return "smelter" end
  if item == "water" then return "condenser" end
  if item == "iron-gear-wheel" or item == "repair-pack" or item == "firearm-magazine" or item:find("tech%-priests%-emergency", 1, false) then return "assembler" end
  return "assembler"
end

local function has_facility_role(pair, role)
  for _, rec in ipairs(facility_records(pair)) do if rec.role == role and valid(rec.entity) then return true, rec end end
  return false, nil
end

local function call_facility_doctrine(pair, item, reason)
  local r = M.root()
  if r.prefer_emergency_facilities == false then return false, "facilities-disabled" end
  local ok, Fac = pcall(require, "scripts.core.emergency_facility_doctrine")
  if not (ok and Fac and type(Fac.service_pair) == "function") then return false, "no-facility-doctrine" end
  r.dispatching_facility_0514 = true
  local ok2, acted, why = pcall(Fac.service_pair, pair, reason or "dispatcher-0514")
  r.dispatching_facility_0514 = false
  if not ok2 then record("facility-error-0514", pair, acted); return false, "facility-error" end
  if acted then record("facility-service-0514", pair, "item=" .. safe(item) .. " why=" .. safe(why)) end
  return acted == true, why or "facility-service"
end

local function fallback_ticks(task)
  local base = tonumber(_G.EMERGENCY_CRAFT_WORK_TICKS) or M.default_station_craft_ticks
  local units = needed_units(task)
  return math.max(M.default_station_craft_ticks, base * math.max(1, units))
end

local function service_timed_station_fallback(pair, task, source, item)
  local r = M.root()
  if r.allow_timed_station_fallback == false then return false, "fallback-disabled" end
  if not at_station(pair) then
    set_phase(pair, "return-to-station", "fallback craft " .. safe(item))
    draw(pair, "[item=" .. safe(item or "iron-gear-wheel") .. "] returning to Cogitator for timed fallback craft", 45)
    request_move_station(pair, "emergency-production-fallback-return-0514")
    return true, "returning"
  end
  pair.mode = "emergency-production-station-craft"
  task.station_craft_pending_0514 = true
  if not task.craft_due_tick_0514 then
    task.craft_started_tick_0514 = now()
    task.craft_due_tick_0514 = now() + fallback_ticks(task)
    record("fallback-started-0514", pair, "item=" .. safe(item) .. " due=" .. safe(task.craft_due_tick_0514))
  end
  local due = tonumber(task.craft_due_tick_0514) or now()
  local started = tonumber(task.craft_started_tick_0514) or (due - M.default_station_craft_ticks)
  local total = math.max(1, due - started)
  if now() < due then
    local progress = 1 - math.min(1, (due - now()) / total)
    if not task.next_progress_visual_0514 or now() >= task.next_progress_visual_0514 then
      task.next_progress_visual_0514 = now() + M.progress_refresh_ticks
      draw(pair, "[item=" .. safe(item or "product") .. "] station fallback craft " .. bar(progress, 16) .. " " .. tostring(math.ceil((due - now()) / 60)) .. "s", 30)
    end
    set_phase(pair, "fallback-station-craft", "progress=" .. string.format("%.2f", progress))
    return true, "crafting"
  end
  local need = needed_count(task)
  local inserted = station_insert(pair, item, need)
  if inserted < need then
    task.craft_due_tick_0514 = now() + 60
    task.craft_started_tick_0514 = now()
    set_phase(pair, "deposit-output", "station insert blocked item=" .. safe(item) .. " inserted=" .. safe(inserted) .. "/" .. safe(need))
    draw(pair, "[item=" .. safe(item or "product") .. "] output blocked; waiting for Cogitator inventory space", 60)
    record("fallback-deposit-blocked-0514", pair, "item=" .. safe(item) .. " inserted=" .. safe(inserted) .. "/" .. safe(need))
    return true, "deposit-blocked"
  end
  task.craft_due_tick_0514 = nil
  task.craft_started_tick_0514 = nil
  task.station_craft_pending_0514 = nil
  clear_task(pair, source)
  complete_order_if_matches(pair, item, "fallback-station-craft-0514")
  set_phase(pair, "complete", "fallback item=" .. safe(item) .. " inserted=" .. safe(inserted))
  draw(pair, "[item=" .. safe(item or "product") .. "] emergency production complete", 90)
  record("fallback-complete-0514", pair, "item=" .. safe(item) .. " inserted=" .. safe(inserted))
  return true, "complete"
end

function M.service_pair(pair, reason)
  local r = M.root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local task, source = current_task(pair)
  if not task then
    set_phase(pair, "none", "no-production-task")
    return false, "no-production-task"
  end
  if task_has_direct_current(task) then
    set_phase(pair, "await-direct-acquisition", "direct current still active")
    return false, "await-direct-acquisition"
  end
  local item = task_item(task)
  if not item or not item_exists(item) then
    set_phase(pair, "need-item", "missing or invalid output item " .. safe(item))
    return false, "invalid-item"
  end
  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "emergency-production", "emergency_production_executor_0514", reason or "service") end
  pair.dispatcher_emergency_production_0514 = pair.dispatcher_emergency_production_0514 or {}
  local s = pair.dispatcher_emergency_production_0514
  s.item = item
  s.source = source
  s.reason = tostring(reason or s.reason or "service")
  s.last_seen_tick = now()

  local requested = needed_count(task)
  if station_count(pair, item) >= requested and (source == "order_proxy" or gathered_units(task) <= 0 or ready_materials(task)) then
    clear_task(pair, source)
    complete_order_if_matches(pair, item, "already-supplied-0514")
    set_phase(pair, "complete", "already supplied " .. safe(item))
    record("already-supplied-0514", pair, "item=" .. safe(item))
    return true, "already-supplied"
  end

  local collected = collect_from_facilities(pair, item, requested)
  if collected > 0 then
    if station_count(pair, item) >= requested then
      clear_task(pair, source)
      complete_order_if_matches(pair, item, "facility-output-collected-0514")
      set_phase(pair, "complete", "facility output " .. safe(item))
      draw(pair, "[item=" .. safe(item) .. "] collected from Martian emergency machine", 90)
      record("facility-output-complete-0514", pair, "item=" .. safe(item) .. " moved=" .. safe(collected))
      return true, "facility-output-complete"
    end
    set_phase(pair, "collect-output", "moved=" .. safe(collected))
    return true, "collecting-output"
  end

  local role = production_role_for(item)
  local have_role = has_facility_role(pair, role)
  if r.prefer_emergency_facilities ~= false then
    local acted, why = call_facility_doctrine(pair, item, "dispatcher-0514")
    if acted then
      task.facility_started_tick_0514 = task.facility_started_tick_0514 or now()
      task.facility_role_0514 = role
      task.station_craft_pending_0514 = nil
      local phase = have_role and "feed-machine" or "need-machine"
      set_phase(pair, phase, "role=" .. safe(role) .. " why=" .. safe(why))
      draw(pair, "[item=" .. safe(item) .. "] routing through Martian emergency " .. safe(role), 60)
      return true, why or phase
    end
  end

  if have_role and task.facility_started_tick_0514 and now() - task.facility_started_tick_0514 < M.facility_wait_ticks then
    set_phase(pair, "wait-machine", "role=" .. safe(role))
    draw(pair, "[item=" .. safe(item) .. "] waiting on Martian emergency machine", 45)
    return true, "waiting-machine"
  end

  if not ready_materials(task) then
    set_phase(pair, "check-scavenge", "materials not ready")
    -- Leave material acquisition to the scheduler/direct-acquisition executor.
    return false, "materials-not-ready"
  end

  return service_timed_station_fallback(pair, task, source, item)
end

function M.service_all(reason)
  local r = M.root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and current_task(pair) then
      local ok = pcall(M.service_pair, pair, reason or "service-all")
      if ok then n = n + 1 end
      if n >= M.max_pairs_per_pulse then break end
    end
  end
  return n
end

local function should_block_legacy(pair)
  local r = M.root()
  if r.enabled == false or r.block_legacy_desperation_craft == false then return false end
  if not valid_pair(pair) then return false end
  local task = current_task(pair)
  if not task then return false end
  local s = pair.dispatcher_emergency_production_0514 or {}
  if s.phase and s.phase ~= "none" then return true end
  local d = pair.dispatcher_0510
  if d and d.family == "station-craft" and now() - (tonumber(d.tick) or 0) < 180 then return true end
  return false
end

local function wrap_legacy_desperation_craft()
  local fn = rawget(_G, "handle_emergency_desperation_craft")
  if type(fn) ~= "function" or rawget(_G, "TECH_PRIESTS_0514_PRE_HANDLE_EMERGENCY_CRAFT") then return false end
  _G.TECH_PRIESTS_0514_PRE_HANDLE_EMERGENCY_CRAFT = fn
  _G.handle_emergency_desperation_craft = function(pair, ...)
    if should_block_legacy(pair) then
      local ok, acted, why = pcall(M.service_pair, pair, "legacy-handle-wrapper-0514")
      record("legacy-craft-blocked-0514", pair, "acted=" .. safe(acted) .. " why=" .. safe(why))
      if ok then return acted ~= false end
      return true
    end
    return fn(pair, ...)
  end
  return true
end

local function wrap_legacy_finish()
  local fn = rawget(_G, "finish_emergency_desperation_craft")
  if type(fn) ~= "function" or rawget(_G, "TECH_PRIESTS_0514_PRE_FINISH_EMERGENCY_CRAFT") then return false end
  _G.TECH_PRIESTS_0514_PRE_FINISH_EMERGENCY_CRAFT = fn
  _G.finish_emergency_desperation_craft = function(pair, ...)
    if should_block_legacy(pair) then
      local ok, acted = pcall(M.service_pair, pair, "legacy-finish-wrapper-0514")
      record("legacy-finish-blocked-0514", pair, "acted=" .. safe(acted))
      if ok then return acted ~= false end
      return true
    end
    return fn(pair, ...)
  end
  return true
end

local function wrap_facility_doctrine()
  local ok, Fac = pcall(require, "scripts.core.emergency_facility_doctrine")
  if not ok or not Fac or Fac.emergency_production_0514_wrapped then return false end
  Fac.emergency_production_0514_wrapped = true
  if type(Fac.service_pair) == "function" then
    Fac.TECH_PRIESTS_0514_PRE_SERVICE_PAIR = Fac.service_pair
    Fac.service_pair = function(pair, reason, ...)
      local r = M.root()
      local rs = tostring(reason or "")
      if r.enabled ~= false and r.suppress_independent_facility_pulses ~= false and not r.dispatching_facility_0514 and not rs:find("dispatcher%-0514") and not rs:find("command") and not rs:find("manual") then
        stat("independent-facility-pulse-suppressed-0514")
        return false, "suppressed-by-0514"
      end
      return Fac.TECH_PRIESTS_0514_PRE_SERVICE_PAIR(pair, reason, ...)
    end
  end
  if type(Fac.service_all) == "function" then
    Fac.TECH_PRIESTS_0514_PRE_SERVICE_ALL = Fac.service_all
    Fac.service_all = function(reason, ...)
      local r = M.root()
      local rs = tostring(reason or "")
      if r.enabled ~= false and r.suppress_independent_facility_pulses ~= false and not r.dispatching_facility_0514 and not rs:find("dispatcher%-0514") and not rs:find("command") and not rs:find("manual") then
        stat("independent-facility-all-suppressed-0514")
        return 0
      end
      return Fac.TECH_PRIESTS_0514_PRE_SERVICE_ALL(reason, ...)
    end
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    if tp.pairs_by_station and tp.pairs_by_station[selected.unit_number] then return tp.pairs_by_station[selected.unit_number] end
    if tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number] then return tp.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-emergency-production-0514") end end)
  commands.add_command("tp-emergency-production-0514", "Tech Priests 0.1.514: dispatcher-owned emergency production status. Params: on/off/all/facilities-on/facilities-off/legacy-on/legacy-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "facilities-on" then r.suppress_independent_facility_pulses = true end
    if p == "facilities-off" then r.suppress_independent_facility_pulses = false end
    if p == "legacy-on" then r.block_legacy_desperation_craft = true end
    if p == "legacy-off" then r.block_legacy_desperation_craft = false end
    if p == "all" then M.service_all("manual-all") end
    local pair = selected_pair(player)
    local lines = {}
    lines[#lines + 1] = "[tp-emergency-production-0514] enabled=" .. safe(r.enabled)
      .. " suppress_facility_pulses=" .. safe(r.suppress_independent_facility_pulses)
      .. " block_legacy=" .. safe(r.block_legacy_desperation_craft)
      .. " facility_services=" .. safe(r.stats["facility-service-0514"] or 0)
      .. " fallback_complete=" .. safe(r.stats["fallback-complete-0514"] or 0)
      .. " suppressed_facility=" .. safe((r.stats["independent-facility-pulse-suppressed-0514"] or 0) + (r.stats["independent-facility-all-suppressed-0514"] or 0))
    if pair then
      local task, source = current_task(pair)
      local s = pair.dispatcher_emergency_production_0514 or {}
      lines[#lines + 1] = "selected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " mode=" .. safe(pair.mode)
        .. " phase=" .. safe(s.phase) .. " item=" .. safe(s.item or task_item(task)) .. " source=" .. safe(source) .. " detail=" .. safe(s.detail)
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468") or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.emergency_production_0514_wrapped then return false end
  diag.emergency_production_0514_wrapped = true
  local prev = diag.pair_dump_lines
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 EMERGENCY-PRODUCTION-0514 BEGIN enabled=" .. safe(r.enabled)
      .. " suppress_facility=" .. safe(r.suppress_independent_facility_pulses)
      .. " block_legacy=" .. safe(r.block_legacy_desperation_craft)
      .. " facility_services=" .. safe(r.stats["facility-service-0514"] or 0)
      .. " fallback_complete=" .. safe(r.stats["fallback-complete-0514"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local task, source = current_task(pair)
        local s = pair.dispatcher_emergency_production_0514 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 prod0514[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest)) .. " mode=" .. safe(pair.mode) .. " phase=" .. safe(s.phase)
          .. " item=" .. safe(s.item or task_item(task)) .. " source=" .. safe(source) .. " facilities=" .. safe(#facility_records(pair))
          .. " detail=" .. safe(s.detail)
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 prod0514.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 EMERGENCY-PRODUCTION-0514 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_facility_doctrine()
  wrap_legacy_desperation_craft()
  wrap_legacy_finish()
  wrap_pair_dump()
  install_command()
  _G.TechPriestsEmergencyProductionExecutor0514 = M
  if log then log("[Tech-Priests 0.1.514] dispatcher-owned emergency production executor installed; facility doctrine and desperation craft are now leaf helpers") end
  return true
end

return M
