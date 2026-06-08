-- scripts/core/priest_vanish_guard_0502.lua
-- Tech Priests 0.1.502
--
-- The 0.1.501 live test proved that the visible unit is still becoming
-- invalid during emergency direct-acquisition work, even while direct script
-- destruction is blocked and controlled respawn can replace the unit.  The
-- diagnostic trail points at the direct gather/mining movement loop: a priest is
-- sent away from the Cogitator Station toward world targets, goes invalid, is
-- respawned, then the current order remains paused-missing-priest.
--
-- This pass makes emergency direct acquisition station-side for now.  The
-- priest remains visibly tethered to the station; world-source acquisition is
-- simulated/deposited through the station inventory instead of commanding a
-- native Factorio unit to travel to a tree/rock/resource target.  It also
-- unpauses the 0498 order queue after a successful 0501/0502 recovery.

local M = {}
M.version = "0.1.509"
M.storage_key = "priest_vanish_guard_0502"
M.tick_interval = 31
M.station_tether_radius_sq = 144 -- 12 tiles
M.station_side_ticks = 90
M.station_side_min_interval = 30 -- hard anti-slam gate: one station-side work pass per pair per half-second
M.movement_log_interval = 300
M.max_per_pulse = 8

local PRIEST_NAMES = {
  ["junior-tech-priest"] = true,
  ["intermediate-tech-priest"] = true,
  ["senior-tech-priest"] = true,
  ["planetary-magos-tech-priest"] = true,
  ["void-tech-priest"] = true,
  ["junior-tech-priest-belt-immune"] = true,
  ["intermediate-tech-priest-belt-immune"] = true,
  ["senior-tech-priest-belt-immune"] = true,
  ["planetary-magos-tech-priest-belt-immune"] = true,
  ["void-tech-priest-belt-immune"] = true
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function tp_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

local function pair_map()
  local tp = storage and storage.tech_priests
  return tp and tp.pairs_by_station or {}
end

local function root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, last_log = {}, last_service = {}, circuit_breakers = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.station_side_direct_acquisition == nil then r.station_side_direct_acquisition = false end
  if r.suppress_far_acquisition_movement == nil then r.suppress_far_acquisition_movement = false end
  if r.tether_visible_priest == nil then r.tether_visible_priest = false end
  if r.station_side_min_interval == nil then r.station_side_min_interval = M.station_side_min_interval end
  if r.movement_log_interval == nil then r.movement_log_interval = M.movement_log_interval end
  if r.log_station_side_working == nil then r.log_station_side_working = false end
  if r.log_movement_suppression == nil then r.log_movement_suppression = false end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.last_service = r.last_service or {}
  r.circuit_breakers = r.circuit_breakers or {}
  return r
end

local LOG_ALWAYS = {
  ["station-side-direct-deposit-0502"] = true,
  ["station-side-target-invalid-0502"] = true,
  ["missing-priest-observed-0502"] = true,
  ["order-unpaused-after-priest-recovery-0502"] = true,
  ["priest-reanchored-station-side-0502"] = true,
  ["station-side-circuit-breaker-0504"] = true,
}

local function record(action, pair, detail, force_log)
  local r = root()
  action = tostring(action or "event")
  r.stats[action] = (r.stats[action] or 0) + 1
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 100 do table.remove(r.recent, 1) end

  -- 0.1.504: never let diagnostic logging become the performance bug.
  local should_log = force_log == true or LOG_ALWAYS[action] == true
  if action == "station-side-direct-working-0502" and r.log_station_side_working ~= true then should_log = false end
  if action == "far-acquisition-movement-suppressed-0502" and r.log_movement_suppression ~= true then should_log = false end
  if should_log and log then
    local key = action .. ":" .. safe(rec.station)
    local last = r.last_log[key] or -1000000
    local interval = tonumber(r.movement_log_interval) or M.movement_log_interval
    if force_log or LOG_ALWAYS[action] or now() - last >= interval then
      r.last_log[key] = now()
      log("[Tech-Priests 0.1.504] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail)
    end
  end
end

local function station_key(pair)
  return tostring(station_unit(pair) or "nil")
end

local function service_allowed(pair, reason)
  local r = root()
  local key = station_key(pair)
  local tick = now()
  local last = tonumber(r.last_service[key]) or -1000000
  local interval = tonumber(r.station_side_min_interval) or M.station_side_min_interval
  if tick - last < interval then
    r.stats["station-side-throttled-0504"] = (r.stats["station-side-throttled-0504"] or 0) + 1
    return false, "station-side-throttled-0504"
  end
  r.last_service[key] = tick
  return true, "ok"
end

local function note_suppressed_movement(pair, destination, reason)
  local r = root()
  local key = station_key(pair)
  local cb = r.circuit_breakers[key] or { tick = now(), count = 0 }
  if now() - (cb.tick or 0) > 60 then cb = { tick = now(), count = 0 } end
  cb.count = (cb.count or 0) + 1
  r.circuit_breakers[key] = cb
  pair.station_side_acquisition_0502 = { tick = now(), x = destination.x, y = destination.y, reason = tostring(reason or "movement") }
  if cb.count == 1 or cb.count == 25 or cb.count == 100 then
    record("far-acquisition-movement-suppressed-0502", pair, "reason=" .. safe(reason) .. " dest=" .. string.format("%.1f,%.1f", destination.x or 0, destination.y or 0) .. " count60=" .. safe(cb.count))
  else
    r.stats["far-acquisition-movement-suppressed-0502"] = (r.stats["far-acquisition-movement-suppressed-0502"] or 0) + 1
  end
  if cb.count == 200 then
    record("station-side-circuit-breaker-0504", pair, "reason=" .. safe(reason) .. " suppressed_in_60_ticks=" .. safe(cb.count), true)
    -- Clear the visible movement/task pressure. The underlying emergency order may
    -- replan next pulse, but this stops same-second self-hammering.
    pair.target = nil
    pair.movement_request_0418 = nil
    pair.pathing_target_0418 = nil
    pair.mining_lock_0315 = nil
    pair.direct_target_lease_0414 = nil
  end
end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if game and game.item_prototypes and game.item_prototypes[name] then return true end
  return false
end

local function is_priest_name(name) return PRIEST_NAMES[tostring(name or "")] == true end
local function is_priest_entity(e) return valid(e) and is_priest_name(e.name) end

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function current_order(pair)
  return pair and pair.order_queue_0469 and pair.order_queue_0469.current or nil
end

local function order_summary(pair)
  local o = current_order(pair)
  if not o then return "order=none" end
  return "order=" .. safe(o.key or o.id or "?") .. " kind=" .. safe(o.kind) .. " item=" .. safe(o.item or o.item_name or o.requested_item) .. " status=" .. safe(o.status)
end

local function repair_reverse_maps(pair, reason)
  if not valid_pair(pair) then return false end
  local tp = tp_root()
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.lifecycle_0502 = pair.lifecycle_0502 or {}
  pair.lifecycle_0502.last_valid_tick = now()
  pair.lifecycle_0502.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0502.last_reason = tostring(reason or "repair")
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function resume_paused_order(pair, reason)
  if not valid_pair(pair) then return false end
  local changed = false
  if pair.paused_by_missing_priest_0498 then pair.paused_by_missing_priest_0498 = nil; changed = true end
  if pair.paused_by_missing_priest_0500 then pair.paused_by_missing_priest_0500 = nil; changed = true end
  if pair.lost_priest_0490 then pair.lost_priest_0490 = nil; changed = true end
  if pair.link_0495 and pair.link_0495.missing_since then pair.link_0495.missing_since = nil; changed = true end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "paused-missing-priest" then
    q.current.status = "active"
    q.current.paused_tick = nil
    q.current.pause_reason = nil
    pair.active_order_0469 = q.current
    changed = true
  end
  if changed then record("order-unpaused-after-priest-recovery-0502", pair, "reason=" .. safe(reason) .. " " .. order_summary(pair)) end
  return changed
end

local function anchor_position(pair)
  if not valid(pair and pair.station) then return nil end
  local s = pair.station
  local surface = s.surface
  local base = { x = s.position.x + 0.35, y = s.position.y + 1.35 }
  if surface and surface.find_non_colliding_position then
    local ok, p = pcall(function() return surface.find_non_colliding_position(pair.priest and pair.priest.name or "character", base, 4, 0.25) end)
    if ok and p then return p end
  end
  return base
end

local function stop_priest(pair, reason)
  if not valid_pair(pair) then return false end
  local ok = false
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.stop })
    else
      pair.priest.set_command({ type = defines.command.stop })
    end
    ok = true
  end)
  pair.movement_request_0418 = nil
  pair.pathing_target_0418 = nil
  pair.movement_controller_state_0418 = "station-side-held-0502"
  pair.movement_controller_reason_0418 = tostring(reason or "station-side")
  return ok
end

local function tether_pair(pair, reason, force)
  if not valid_pair(pair) then return false end
  repair_reverse_maps(pair, "tether-0502")
  local d2 = dist_sq(pair.priest.position, pair.station.position) or 0
  if force or d2 > M.station_tether_radius_sq then
    local p = anchor_position(pair)
    local ok = false
    if p then pcall(function() ok = pair.priest.teleport(p, pair.station.surface) end) end
    stop_priest(pair, reason or "tether")
    record("priest-reanchored-station-side-0502", pair, "reason=" .. safe(reason) .. " dist_sq=" .. safe(math.floor(d2)) .. " ok=" .. safe(ok))
    return true
  end
  return false
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  local task = pair.emergency_craft or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333
  local cur = task and task.current or nil
  if not cur then return nil, nil end
  local kind = tostring(cur.kind or "")
  if kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336" then return task, cur end
  return nil, nil
end

local function target_position(pair, cur)
  if cur and valid(cur.entity) then return cur.entity.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function direct_output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item) or nil
  if item_exists(item) then return item end
  if cur and (cur.kind == "direct-dirt-0273" or cur.kind == "dirt") then return item_exists("stone") and "stone" or nil end
  local e = cur and cur.entity
  if valid(e) then
    if e.type == "resource" and item_exists(e.name) then return e.name end
    if e.type == "tree" and item_exists("wood") then return "wood" end
    if (e.type == "simple-entity" or e.type == "simple-entity-with-owner" or e.type == "rock") and item_exists("stone") then return "stone" end
  end
  item = task and (task.output_item or task.item_name)
  if item_exists(item) then return item end
  return item_exists("stone") and "stone" or nil
end

local function required_units(task)
  local n = task and task.recipe and tonumber(task.recipe.units) or nil
  n = n or tonumber(task and task.required_count) or tonumber(task and task.count) or 1
  return math.max(1, math.min(50, n or 1))
end

local function station_inventory(pair)
  if not (pair and valid(pair.station) and pair.station.get_inventory) then return nil end
  local inv = nil
  pcall(function()
    inv = pair.station.get_inventory(defines.inventory.chest)
       or pair.station.get_inventory(defines.inventory.assembling_machine_input)
       or pair.station.get_inventory(defines.inventory.assembling_machine_output)
  end)
  if inv and inv.valid then return inv end
  return nil
end

local function deposit(pair, item, count)
  if not (valid_pair(pair) and item and item_exists(item)) then return false end
  count = math.max(1, tonumber(count) or 1)
  if _G.tech_priests_safe_deposit_item then
    local ok = false
    pcall(function() ok = _G.tech_priests_safe_deposit_item(pair, item, count, "station-side-direct-0502") end)
    if ok then return true end
  end
  local inv = station_inventory(pair)
  if inv and inv.can_insert and inv.can_insert({ name = item, count = count }) then
    local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
    if ok and (inserted or 0) > 0 then return true end
  end
  return false
end

local function show(pair, text, target)
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  if target and valid(target) and _G.draw_emergency_craft_scan_line then pcall(_G.draw_emergency_craft_scan_line, pair, target) end
end

local function soften_world_source(pair, cur, final)
  local e = cur and cur.entity
  if not valid(e) then return end
  if _G.spawn_emergency_craft_smoke then pcall(function() _G.spawn_emergency_craft_smoke(pair, e.position, final == true) end) end
  pcall(function()
    if not e.valid then return end
    if e.type == "resource" then
      local amount = tonumber(e.amount) or 0
      if amount > 1 then e.amount = math.max(1, amount - (final and 10 or 1)) end
    elseif e.health and e.health > 1 then
      -- Do not pass the priest as cause while this vanishing fault is under
      -- isolation.  The world can be marked without involving native unit combat.
      e.damage(final and 10 or 1, pair.station.force, "impact")
    end
  end)
end

local function finish_or_continue(pair, task, cur, item, reason)
  task.gathered_units = (task.gathered_units or 0) + 1
  pair.last_station_side_direct_0502 = { tick = now(), item = item, count = task.gathered_units, reason = reason }
  local req = required_units(task)
  if task.gathered_units < req and ((not cur.entity) or cur.entity.valid) then
    task.current = nil
    task.direct_due_tick_0273 = nil
    task.direct_due_tick_0312 = nil
    task.direct_due_tick_0315 = nil
    task.direct_due_tick_0336 = nil
    show(pair, "[item=" .. safe(item) .. "] station-side gathered " .. tostring(task.gathered_units) .. "/" .. tostring(req), pair.station)
    return true, "station-side-continue"
  end
  if task.recipe and task.output_item and item_exists(task.output_item) then
    task.current = nil
    task.direct_due_tick_0273 = nil
    task.direct_due_tick_0312 = nil
    task.direct_due_tick_0315 = nil
    task.direct_due_tick_0336 = nil
    task.station_craft_pending_0337 = true
    pair.mode = "returning-to-station-for-craft"
    pair.target = pair.station
    show(pair, "[item=" .. safe(task.output_item) .. "] materials ready; station-side craft", pair.station)
    pcall(function()
      local Craft = require("scripts.core.crafting_executor")
      if Craft and Craft.before_legacy_handle then Craft.before_legacy_handle(pair) end
    end)
    return true, "station-side-ready-to-craft"
  end
  task.current = nil
  if pair.emergency_craft == task then pair.emergency_craft = nil end
  pair.mode = "returning"
  pair.target = pair.station
  show(pair, "[item=" .. safe(item) .. "] station-side direct acquisition complete", pair.station)
  return true, "station-side-complete"
end

local function station_side_service(pair, reason)
  local r = root(); if r.station_side_direct_acquisition == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local task, cur = current_direct_task(pair)
  if not task then return false, "no-direct-task" end
  local pos = target_position(pair, cur)
  if cur.entity and not cur.entity.valid then
    task.current = nil
    pair.target = nil
    record("station-side-target-invalid-0502", pair, "reason=" .. safe(reason), true)
    return false, "invalid-target"
  end

  local allowed, gate_reason = service_allowed(pair, reason)
  if not allowed then return true, gate_reason end

  resume_paused_order(pair, "station-side-valid")
  tether_pair(pair, reason or "station-side-direct", false)
  stop_priest(pair, reason or "station-side-direct")
  pair.mode = "emergency-gathering"
  pair.target = nil
  pair.mining_lock_0315 = nil
  pair.direct_target_lease_0414 = nil

  cur.station_side_0502 = cur.station_side_0502 or { started = now(), source_reason = tostring(reason or "service") }
  if not cur.station_side_0502.due then cur.station_side_0502.due = now() + M.station_side_ticks end
  local item = direct_output_item(task, cur)
  if now() < cur.station_side_0502.due then
    if (not cur.station_side_0502.last_visual) or now() - cur.station_side_0502.last_visual >= 15 then
      cur.station_side_0502.last_visual = now()
      soften_world_source(pair, cur, false)
    end
    local remain = math.max(0, cur.station_side_0502.due - now())
    show(pair, "[item=" .. safe(item or "stone") .. "] station-side acquisition " .. tostring(math.ceil(remain / 60)) .. "s", cur.entity or pair.station)
    record("station-side-direct-working-0502", pair, "reason=" .. safe(reason) .. " item=" .. safe(item) .. " target=" .. safe(cur.entity and cur.entity.name or cur.kind))
    return true, "station-side-working"
  end

  soften_world_source(pair, cur, true)
  if item then deposit(pair, item, 1) end
  record("station-side-direct-deposit-0502", pair, "reason=" .. safe(reason) .. " item=" .. safe(item) .. " target=" .. safe(cur.entity and cur.entity.name or cur.kind))
  cur.station_side_0502 = nil
  return finish_or_continue(pair, task, cur, item, reason)
end

local function reason_is_acquisition(reason, opts)
  local text = lower(tostring(reason or "") .. " " .. tostring(opts and opts.owner or ""))
  return text:find("acquisition", 1, false)
      or text:find("direct", 1, false)
      or text:find("gather", 1, false)
      or text:find("mine", 1, false)
      or text:find("behavior", 1, false)
      or text:find("contract", 1, false)
      or text:find("task%-lifecycle", 1, false)
      or text:find("move%-refresh", 1, false)
      or text:find("stall%-reissue", 1, false)
end

local function should_suppress_movement(pair, destination, reason, opts)
  local r = root(); if r.suppress_far_acquisition_movement == false then return false end
  if not valid_pair(pair) or not destination then return false end
  if lower(reason):find("return", 1, false) or lower(reason):find("station", 1, false) then return false end
  local task, cur = current_direct_task(pair)
  if not task and not reason_is_acquisition(reason, opts) then return false end
  local d2 = dist_sq(destination, pair.station.position) or 0
  if d2 <= M.station_tether_radius_sq then return false end
  return true
end

local function patch_movement()
  if type(_G.tech_priests_request_movement_0418) == "function" and not rawget(_G, "TECH_PRIESTS_0502_PRE_REQUEST_MOVEMENT") then
    _G.TECH_PRIESTS_0502_PRE_REQUEST_MOVEMENT = _G.tech_priests_request_movement_0418
    _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
      if should_suppress_movement(pair, destination, reason, opts) then
        note_suppressed_movement(pair, destination, reason or (opts and opts.owner) or "movement")
        -- 0.1.504: do not perform work from every movement request. Movement
        -- suppression can be requested several times in one tick by behavior
        -- contract + action arbiter + legacy refresh paths. Work is serviced by
        -- the throttled direct-service/on_nth_tick path instead.
        -- Work is intentionally not performed from the movement hook anymore;
        -- it is serviced by the throttled direct-service/on_nth_tick path.
        return true
      end
      return _G.TECH_PRIESTS_0502_PRE_REQUEST_MOVEMENT(pair, destination, reason, opts)
    end
  end
end

local function patch_direct_services()
  local function wrap_global(name)
    local prev_key = "TECH_PRIESTS_0502_PRE_" .. string.upper(name)
    if type(_G[name]) == "function" and not rawget(_G, prev_key) then
      _G[prev_key] = _G[name]
      _G[name] = function(pair, task, ...)
        local t, cur = current_direct_task(pair)
        if root().station_side_direct_acquisition ~= false and t and (not task or task == t) then
          local handled = station_side_service(pair, name)
          if handled then return true end
        end
        return _G[prev_key](pair, task, ...)
      end
    end
  end
  wrap_global("tech_priests_0273_service_direct_current")
  wrap_global("tech_priests_0312_service_direct_current")
  wrap_global("tech_priests_0315_service_direct_current")

  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if ok and Exec and type(Exec.service_pair) == "function" and not Exec.station_side_wrapped_0502 then
    Exec.station_side_wrapped_0502 = true
    Exec.TECH_PRIESTS_0502_PRE_SERVICE_PAIR = Exec.service_pair
    Exec.service_pair = function(pair, reason)
      local task, cur = current_direct_task(pair)
      if root().station_side_direct_acquisition ~= false and task and cur then
        local handled = station_side_service(pair, reason or "acquisition-executor-0502")
        if handled then return true end
      end
      return Exec.TECH_PRIESTS_0502_PRE_SERVICE_PAIR(pair, reason)
    end
  end
end

function M.service_pair(pair)
  if root().enabled == false then return false end
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "service-valid-0502")
    resume_paused_order(pair, "service-valid-0502")
    if root().tether_visible_priest ~= false then
      local has_direct = current_direct_task(pair) ~= nil
      if has_direct then tether_pair(pair, "service-direct-0502", false) end
    end
    local task, cur = current_direct_task(pair)
    if task and cur then station_side_service(pair, "service-pulse-0502") end
    return true
  end
  record("missing-priest-observed-0502", pair, "station-valid=true " .. order_summary(pair))
  return false
end

function M.service_all()
  if root().enabled == false then return end
  local n = 0
  for _, pair in pairs(pair_map()) do
    pcall(function()
      if M.service_pair(pair) then n = n + 1 end
    end)
    if n >= M.max_per_pulse then break end
  end
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.priest_vanish_guard_wrapped_0502 then return false end
  local prev = diag.pair_dump_lines
  diag.priest_vanish_guard_wrapped_0502 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0502 BEGIN enabled=" .. safe(r.enabled)
      .. " station_side=" .. safe(r.station_side_direct_acquisition)
      .. " suppress_far=" .. safe(r.suppress_far_acquisition_movement)
      .. " unpaused=" .. safe(r.stats["order-unpaused-after-priest-recovery-0502"] or 0)
      .. " suppressed=" .. safe(r.stats["far-acquisition-movement-suppressed-0502"] or 0)
      .. " deposits=" .. safe(r.stats["station-side-direct-deposit-0502"] or 0)
      .. " throttled=" .. safe(r.stats["station-side-throttled-0504"] or 0)
      .. " breakers=" .. safe(r.stats["station-side-circuit-breaker-0504"] or 0)
      .. " missing=" .. safe(r.stats["missing-priest-observed-0502"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local task, cur = current_direct_task(pair)
        local d = valid(pair.priest) and math.sqrt(dist_sq(pair.priest.position, pair.station.position) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 vg0502[" .. safe(pair.station.unit_number) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest))
          .. " dist=" .. safe(d and string.format("%.1f", d) or "nil")
          .. " has_direct=" .. safe(cur ~= nil)
          .. " current=" .. safe(cur and cur.kind or "nil")
          .. " order=" .. safe(current_order(pair) and current_order(pair).status or "none")
          .. " station_side=" .. safe(pair.station_side_acquisition_0502 and pair.station_side_acquisition_0502.reason or "nil")
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0502 END"
    return lines
  end
  return true
end

local function commands_install()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-priest-vanish-0502") end end)
  pcall(function()
    commands.add_command("tp-priest-vanish-0502", "Tech Priests: 0.1.504 station-side vanish guard status/all/enable/disable/debug-on/debug-off.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local param = tostring(event and event.parameter or "status")
      local r = root()
      if param == "enable" then r.enabled = true end
      if param == "disable" then r.enabled = false end
      if param == "station-side-off" then r.station_side_direct_acquisition = false end
      if param == "station-side-on" then r.station_side_direct_acquisition = true end
      if param == "debug-on" then r.log_station_side_working = true; r.log_movement_suppression = true end
      if param == "debug-off" then r.log_station_side_working = false; r.log_movement_suppression = false end
      if param == "all" then M.service_all() end
      local msg = "[Tech-Priests 0.1.504] enabled=" .. safe(r.enabled)
        .. " station_side=" .. safe(r.station_side_direct_acquisition)
        .. " suppressed=" .. safe(r.stats["far-acquisition-movement-suppressed-0502"] or 0)
        .. " deposits=" .. safe(r.stats["station-side-direct-deposit-0502"] or 0)
        .. " throttled=" .. safe(r.stats["station-side-throttled-0504"] or 0)
        .. " breakers=" .. safe(r.stats["station-side-circuit-breaker-0504"] or 0)
        .. " unpaused=" .. safe(r.stats["order-unpaused-after-priest-recovery-0502"] or 0)
        .. " missing=" .. safe(r.stats["missing-priest-observed-0502"] or 0)
      if player then player.print(msg) elseif log then log(msg) end
    end)
  end)
end

function M.install()
  root()
  patch_movement()
  patch_direct_services()
  wrap_pair_dump()
  commands_install()
  if script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, M.service_all) end
  _G.TechPriestsPriestVanishGuard0502 = M
  if log then log("[Tech-Priests 0.1.509] priest vanish guard diagnostics installed; station-side direct acquisition disabled by behavior stack cleanup") end
  return true
end

return M
