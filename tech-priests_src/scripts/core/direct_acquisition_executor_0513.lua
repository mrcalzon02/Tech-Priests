-- scripts/core/direct_acquisition_executor_0513.lua
-- Tech Priests 0.1.513
--
-- Dispatcher-owned direct acquisition executor migration.  This module turns
-- direct acquisition into an explicit phase machine owned by the dispatcher:
-- choose/adopt target -> walk to target -> work over time -> deposit -> return
-- or yield to station craft.  Legacy direct-mining bodies may remain installed
-- as helpers/compatibility shims, but they may not be independent controllers
-- once this module is enabled.

local M = {}
M.version = "0.1.539"
M.storage_key = "direct_acquisition_executor_0513"
M.close_distance_sq = 2.25
M.move_refresh_ticks = 120
M.stall_ticks = 240
M.work_ticks = 90
M.visual_ticks = 18
M.max_pairs_per_pulse = 24
M.log_interval = 600

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["dirt"] = true,
  ["direct-mine-0336"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function dist(a, b) local d2 = dist_sq(a, b); return d2 and math.sqrt(d2) or nil end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  return false
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_only = true,
    block_legacy_direct_controllers = true,
    physical_only = true,
    stats = {},
    recent = {},
    last_log = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_only == nil then r.dispatcher_only = true end
  if r.block_legacy_direct_controllers == nil then r.block_legacy_direct_controllers = true end
  if r.physical_only == nil then r.physical_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  return r
end

local function stat(name, n)
  local r = M.root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function record(action, pair, detail, force)
  local r = M.root()
  action = tostring(action or "event")
  stat(action)
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 180 do table.remove(r.recent, 1) end
  local key = action .. ":" .. safe(rec.station)
  local last = r.last_log[key] or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.513] " .. action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. safe(detail)) end
  end
  return rec
end

local function current_direct_task(pair)
  if not pair then return nil, nil, nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = task and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end
M.current_direct_task = current_direct_task

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end

local function target_position(pair, cur)
  local e = target_entity(cur)
  if e then return e.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function target_label(cur)
  local e = target_entity(cur)
  if e then return safe(e.name) .. "#" .. safe(e.unit_number or "?") end
  if cur and cur.position then return string.format("pos:%.1f,%.1f", tonumber(cur.position.x) or 0, tonumber(cur.position.y) or 0) end
  return safe(cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.kind) or "nil")
end

local function output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.requested_item) or nil
  if item_exists(item) then return item end
  item = task and (task.output_item or task.item_name or task.wanted_item or task.requested_item) or nil
  if item_exists(item) then return item end
  local e = target_entity(cur)
  if valid(e) then
    if e.type == "resource" and item_exists(e.name) then return e.name end
    local n = lower(e.name)
    if n:find("tree", 1, true) and item_exists("wood") then return "wood" end
    if (n:find("rock", 1, true) or n:find("stone", 1, true)) and item_exists("stone") then return "stone" end
    if n:find("coal", 1, true) and item_exists("coal") then return "coal" end
    if n:find("iron", 1, true) and item_exists("iron-ore") then return "iron-ore" end
    if n:find("copper", 1, true) and item_exists("copper-ore") then return "copper-ore" end
  end
  return item_exists("stone") and "stone" or nil
end

local function required_units(task)
  local n = task and task.recipe and tonumber(task.recipe.units) or nil
  n = n or tonumber(task and task.required_count) or tonumber(task and task.count) or 1
  return math.max(1, math.min(50, n))
end

local function clear_direct_due(task)
  if not task then return end
  task.direct_due_tick_0273 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0336 = nil
  task.direct_started_tick_0336 = nil
  task.next_direct_laser_tick_0315 = nil
  task.direct_last_visual_tick_0306 = nil
  task.direct_last_visual_tick_0336 = nil
  task.scan_due_tick = nil
end

local function set_phase(pair, phase, detail)
  if not pair then return end
  pair.dispatcher_action = "direct-acquisition"
  pair.dispatcher_phase = phase
  pair.dispatcher_direct_0513 = pair.dispatcher_direct_0513 or {}
  local s = pair.dispatcher_direct_0513
  s.version = M.version
  s.phase = phase
  s.tick = now()
  s.detail = tostring(detail or "")
  if not s.started_tick then s.started_tick = now() end
  s.last_seen_tick = now()
end

local function show(pair, text, target, opts)
  opts = opts or {}
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  -- 0.1.539: walking/status text is not mining.  Do not draw a mining/scan
  -- beam to the target until the priest is physically adjacent and in the
  -- work-target phase; otherwise the visual system makes it look like the
  -- priest is mining backwards while pathing away from the resource.
  if not opts.no_line and _G.draw_emergency_craft_scan_line and target and target.valid then pcall(_G.draw_emergency_craft_scan_line, pair, target) end
end

local function deposit(pair, item, count)
  if not (valid_pair(pair) and item and item_exists(item)) then return false end
  count = math.max(1, tonumber(count) or 1)
  if _G.tech_priests_safe_deposit_item then
    local ok, why = false, nil
    pcall(function() ok, why = _G.tech_priests_safe_deposit_item(pair, item, count, "direct-acquisition-0513") end)
    if ok then return true end
    show(pair, "direct acquisition deposit blocked: " .. safe(why), pair.station)
    return false
  end
  local inv = nil
  pcall(function()
    if pair.station.get_inventory then
      inv = pair.station.get_inventory(defines.inventory.chest)
        or pair.station.get_inventory(defines.inventory.assembling_machine_input)
        or pair.station.get_inventory(defines.inventory.assembling_machine_output)
    end
  end)
  if inv and inv.valid and inv.can_insert and inv.can_insert({ name = item, count = count }) then
    local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
    if ok and (inserted or 0) > 0 then return true end
  end
  return false
end

local function mine_visual(pair, cur, final)
  local e = target_entity(cur)
  if valid(e) then
    if _G.draw_emergency_craft_scan_line then pcall(function() _G.draw_emergency_craft_scan_line(pair, e) end) end
    if _G.spawn_emergency_craft_smoke then
      pcall(function() _G.spawn_emergency_craft_smoke(pair, e.position, final == true) end)
    elseif e.surface and e.surface.create_trivial_smoke then
      pcall(function() e.surface.create_trivial_smoke({ name = "smoke-fast", position = e.position }) end)
    end
  elseif cur and cur.position and _G.spawn_emergency_craft_smoke then
    pcall(function() _G.spawn_emergency_craft_smoke(pair, cur.position, final == true) end)
  end
end

local function mine_hit(pair, cur, final)
  local e = target_entity(cur)
  mine_visual(pair, cur, final)
  if not valid(e) then return end
  pcall(function()
    if e.valid and e.type == "resource" then
      local amount = tonumber(e.amount) or 0
      if amount > 1 then e.amount = math.max(1, amount - (final and 20 or 2)) end
    elseif e.valid and e.health and e.health > 1 then
      e.damage(final and 35 or 5, pair.station.force, "impact", pair.priest)
    end
  end)
end

local function stop_for_work(pair, reason)
  if not valid_pair(pair) then return false end
  pair.movement_request_0418 = nil
  pair.pathing_target_0418 = nil
  pair.movement_controller_state_0418 = "work-clamped"
  pair.movement_controller_clamp_0418 = tostring(reason or "direct-acquisition-work-0513")
  if type(_G.tech_priests_clear_movement_lease_0518) == "function" then
    pcall(_G.tech_priests_clear_movement_lease_0518, pair, reason or "direct-acquisition-work-0513")
  else
    pair.movement_lease_0518 = nil
  end
  if type(_G.tech_priests_stop_movement_0418) == "function" then
    pcall(_G.tech_priests_stop_movement_0418, pair, reason or "direct-acquisition-work-0513")
  else
    pcall(function()
      if pair.priest.commandable and pair.priest.commandable.valid then
        pair.priest.commandable.set_command({ type = defines.command.stop })
      elseif pair.priest.set_command then
        pair.priest.set_command({ type = defines.command.stop })
      end
    end)
  end
  return true
end

local function request_movement(pair, pos, reason)
  if not (valid_pair(pair) and pos) then return false end
  pair.mode = "travelling-to-direct-acquisition"
  pair.target = target_entity(select(2, current_direct_task(pair)))
  pair.movement_controller_reason_0418 = "direct-acquisition-0513"
  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "movement", "direct_acquisition_executor_0513", reason or "move") end
  local ok = false
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pos, reason or "direct-acquisition-0513", { radius = 0.75, owner = "direct-acquisition-0513", priority = 650, ttl = 60 * 10, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "direct-acquisition-fallback-0621", { pair = pair, priority = 650, ttl = 600 })
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
  return ok
end

local function return_to_station(pair, reason)
  if not valid_pair(pair) then return false end
  pair.mode = "returning-to-station"
  pair.target = pair.station
  set_phase(pair, "return-to-station", reason or "return")
  local ok = false
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pair.station.position, reason or "direct-acquisition-return-0513", { radius = 1.0, owner = "direct-acquisition-0513", priority = 610, ttl = 600, distraction = defines.distraction.none })
    else
      local command = { type = defines.command.go_to_location, destination = pair.station.position, radius = 1.0, distraction = defines.distraction.none }
      if _G.tech_priests_route_ground_command_0429 then
        local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "direct-acquisition-return-fallback-0621", { pair = pair, priority = 610, ttl = 600 })
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
  return ok
end

local function within_bounds(pair, pos)
  local b = rawget(_G, "TechPriestsMovementBounds0511")
  if b and type(b.target_within_bounds) == "function" then
    local ok, inside, d, maxd = pcall(b.target_within_bounds, pair, pos)
    if ok then return inside ~= false, d, maxd end
  end
  return true, nil, nil
end

function M.service_pair(pair, reason)
  local root = M.root()
  if root.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end

  local task, cur = current_direct_task(pair)
  if not (task and cur) then
    set_phase(pair, "none", "no-direct-task")
    return false, "no-direct-task"
  end

  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "direct-acquisition", "direct_acquisition_executor_0513", reason or "service") end
  pair.dispatcher_direct_0513 = pair.dispatcher_direct_0513 or {}
  local state = pair.dispatcher_direct_0513
  state.version = M.version
  state.reason = tostring(reason or state.reason or "service")
  state.item = output_item(task, cur)
  state.target = target_label(cur)
  state.last_seen_tick = now()

  if cur.entity and not valid(cur.entity) then
    clear_direct_due(task)
    task.current = nil
    pair.target = nil
    pair.mode = "direct-acquisition-replan"
    set_phase(pair, "target-invalid", "target vanished")
    record("target-invalid-0513", pair, state.target)
    return false, "target-invalid"
  end

  local pos = target_position(pair, cur)
  if not pos then
    clear_direct_due(task)
    task.current = nil
    pair.target = nil
    set_phase(pair, "need-target", "no-target-position")
    record("need-target-0513", pair, "no-target-position")
    return false, "no-target-position"
  end

  local inside, sd, maxd = within_bounds(pair, pos)
  if inside == false then
    clear_direct_due(task)
    task.current = nil
    pair.target = nil
    pair.mode = "direct-acquisition-target-rejected"
    set_phase(pair, "target-rejected", "station_dist=" .. safe(sd) .. " max=" .. safe(maxd))
    record("target-rejected-0513", pair, "target=" .. safe(state.target) .. " station_dist=" .. safe(sd and string.format("%.1f", sd) or "?") .. " max=" .. safe(maxd))
    return false, "target-out-of-bounds"
  end

  local d2 = dist_sq(pair.priest.position, pos) or 0
  local d = math.sqrt(d2)
  state.distance = d
  if d2 > M.close_distance_sq then
    clear_direct_due(task)
    local last_d = tonumber(state.last_distance)
    local made_progress = (not last_d) or d < last_d - 0.05
    if made_progress then state.last_progress_tick = now() end
    state.last_distance = d
    local stale = (not state.last_move_tick) or now() - (tonumber(state.last_move_tick) or 0) >= M.move_refresh_ticks
    local stalled = (not made_progress) and now() - (tonumber(state.last_progress_tick) or 0) >= M.stall_ticks
    if stale or stalled then
      state.last_move_tick = now()
      request_movement(pair, pos, stalled and "direct-acquisition-stall-repath-0513" or "direct-acquisition-travel-0513")
      record(stalled and "travel-repath-0513" or "travel-request-0513", pair, "target=" .. safe(state.target) .. " dist=" .. string.format("%.1f", d))
    else
      stat("travel-held-0513")
    end
    set_phase(pair, "walk-to-target", "dist=" .. string.format("%.1f", d))
    show(pair, "[item=" .. safe(state.item or "materials") .. "] walking to direct target " .. string.format("%.1fm", d), nil, { no_line = true })
    return true, "walking"
  end

  -- Adjacent: the priest owns the physical action now.  Stop and clear any
  -- movement lease before drawing work visuals or applying mining damage.
  stop_for_work(pair, "direct-acquisition-work-clamp-0539")
  pair.mode = "direct-acquisition-working"
  pair.target = target_entity(cur)
  set_phase(pair, "work-target", "target=" .. safe(state.target))

  if not task.direct_due_tick_0513 then
    clear_direct_due(task)
    task.direct_due_tick_0513 = now() + M.work_ticks
    task.direct_started_tick_0513 = now()
    state.work_started_tick = now()
    record("work-started-0513", pair, "target=" .. safe(state.target) .. " item=" .. safe(state.item))
  end

  if now() < task.direct_due_tick_0513 then
    if (not task.direct_last_visual_tick_0513) or now() - task.direct_last_visual_tick_0513 >= M.visual_ticks then
      task.direct_last_visual_tick_0513 = now()
      mine_hit(pair, cur, false)
    end
    local remain = math.max(0, task.direct_due_tick_0513 - now())
    show(pair, "[item=" .. safe(state.item or "materials") .. "] extracting " .. tostring(math.ceil(remain / 60)) .. "s", target_entity(cur) or pair.station)
    return true, "working"
  end

  mine_hit(pair, cur, true)
  local item = output_item(task, cur)
  local deposited = item and deposit(pair, item, 1) or false
  task.direct_due_tick_0513 = nil
  task.direct_started_tick_0513 = nil
  task.direct_last_visual_tick_0513 = nil
  state.last_progress_tick = now()
  state.last_deposit_item = item
  state.last_deposit_ok = deposited and true or false
  if not deposited then
    pair.mode = "direct-acquisition-deposit-blocked"
    set_phase(pair, "deposit-blocked", "item=" .. safe(item))
    record("deposit-failed-0513", pair, "item=" .. safe(item) .. " count=" .. safe(task.gathered_units or 0) .. "/" .. safe(required_units(task)), true)
    show(pair, "[item=" .. safe(item or "materials") .. "] deposit blocked; gathered count not advanced", pair.station)
    return false, "deposit-blocked"
  end
  task.gathered_units = (tonumber(task.gathered_units) or 0) + 1
  record("unit-collected-0513", pair, "item=" .. safe(item) .. " deposited=" .. safe(deposited) .. " count=" .. safe(task.gathered_units) .. "/" .. safe(required_units(task)))

  if task.gathered_units < required_units(task) and ((not cur.entity) or valid(cur.entity)) then
    set_phase(pair, "work-target", "continue " .. safe(task.gathered_units) .. "/" .. safe(required_units(task)))
    show(pair, "[item=" .. safe(item or "materials") .. "] acquired " .. safe(task.gathered_units) .. "/" .. safe(required_units(task)), target_entity(cur) or pair.station)
    return true, "continue"
  end

  if task.recipe and task.output_item and item_exists(task.output_item) then
    task.current = nil
    clear_direct_due(task)
    task.station_craft_pending_0337 = true
    task.station_craft_pending_0513 = true
    pair.mode = "returning-to-station-for-craft"
    pair.target = pair.station
    set_phase(pair, "return-for-craft", "output=" .. safe(task.output_item))
    show(pair, "[item=" .. safe(task.output_item) .. "] materials acquired; returning for station craft", pair.station)
    return_to_station(pair, "direct-acquisition-return-for-craft-0513")
    return true, "ready-to-craft"
  end

  task.current = nil
  pair.emergency_craft = nil
  pair.direct_acquisition_task_0336 = nil
  pair.active_acquisition_0333 = nil
  pair.target = nil
  set_phase(pair, "complete", "item=" .. safe(item))
  show(pair, "[item=" .. safe(item or "materials") .. "] acquisition complete", pair.station)
  return_to_station(pair, "direct-acquisition-complete-0513")
  return true, "complete"
end

function M.service_all(reason)
  local r = M.root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and current_direct_task(pair) then
      local ok = pcall(M.service_pair, pair, reason or "service-all")
      if ok then n = n + 1 end
      if n >= M.max_pairs_per_pulse then break end
    end
  end
  return n
end

local function should_block_legacy(pair)
  local r = M.root()
  if r.enabled == false or r.block_legacy_direct_controllers == false then return false end
  if not valid_pair(pair) then return false end
  local task, cur = current_direct_task(pair)
  if not (task and cur) then return false end
  local s = pair.dispatcher_direct_0513 or {}
  if s.phase and s.phase ~= "none" then return true end
  local d = pair.dispatcher_0510
  if d and d.family == "direct-acquisition" and now() - (tonumber(d.tick) or 0) < 120 then return true end
  return false
end

local function wrap_acquisition_executor()
  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if not (ok and Exec and type(Exec.service_pair) == "function") or Exec.direct_executor_0513_wrapped then return false end
  Exec.direct_executor_0513_wrapped = true
  Exec.TECH_PRIESTS_0513_PRE_SERVICE_PAIR = Exec.service_pair
  Exec.service_pair = function(pair, reason, ...)
    local r = M.root()
    if r.enabled ~= false then return M.service_pair(pair, reason or "acquisition-executor-wrapper-0513") end
    return Exec.TECH_PRIESTS_0513_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

local function wrap_legacy_direct_functions()
  local function wrap(name)
    local fn = _G[name]
    local key = "TECH_PRIESTS_0513_PRE_" .. string.upper(name)
    if type(fn) ~= "function" or rawget(_G, key) then return end
    _G[key] = fn
    _G[name] = function(pair, task, ...)
      if should_block_legacy(pair) then
        record("legacy-direct-blocked-0513", pair, name)
        return true
      end
      return fn(pair, task, ...)
    end
  end
  wrap("tech_priests_0273_service_direct_current")
  wrap("tech_priests_0312_service_direct_current")
  wrap("tech_priests_0315_service_direct_current")
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
  pcall(function() if commands.remove_command then commands.remove_command("tp-direct-acquisition-0513") end end)
  commands.add_command("tp-direct-acquisition-0513", "Tech Priests 0.1.513: dispatcher-owned direct acquisition executor status. Params: on/off/all/legacy-on/legacy-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "legacy-on" then r.block_legacy_direct_controllers = true end
    if p == "legacy-off" then r.block_legacy_direct_controllers = false end
    if p == "all" then M.service_all("manual-all") end
    local pair = selected_pair(player)
    local lines = {}
    lines[#lines + 1] = "[tp-direct-acquisition-0513] enabled=" .. safe(r.enabled) .. " block_legacy=" .. safe(r.block_legacy_direct_controllers)
      .. " walking=" .. safe(r.stats["travel-request-0513"] or 0) .. " work=" .. safe(r.stats["work-started-0513"] or 0)
      .. " collected=" .. safe(r.stats["unit-collected-0513"] or 0) .. " deposit_failed=" .. safe(r.stats["deposit-failed-0513"] or 0) .. " blocked_legacy=" .. safe(r.stats["legacy-direct-blocked-0513"] or 0)
    if pair then
      local task, cur = current_direct_task(pair)
      local s = pair.dispatcher_direct_0513 or {}
      local pos = target_position(pair, cur)
      local d = valid(pair.priest) and pos and dist(pair.priest.position, pos) or nil
      lines[#lines + 1] = "selected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " mode=" .. safe(pair.mode)
        .. " phase=" .. safe(s.phase) .. " item=" .. safe(s.item) .. " target=" .. safe(target_label(cur)) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil")
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468") or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.direct_acquisition_0513_wrapped then return false end
  diag.direct_acquisition_0513_wrapped = true
  local prev = diag.pair_dump_lines
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 DIRECT-ACQUISITION-0513 BEGIN enabled=" .. safe(r.enabled)
      .. " block_legacy=" .. safe(r.block_legacy_direct_controllers)
      .. " travel=" .. safe(r.stats["travel-request-0513"] or 0)
      .. " work=" .. safe(r.stats["work-started-0513"] or 0)
      .. " collected=" .. safe(r.stats["unit-collected-0513"] or 0)
      .. " deposit_failed=" .. safe(r.stats["deposit-failed-0513"] or 0)
      .. " legacy_blocked=" .. safe(r.stats["legacy-direct-blocked-0513"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local task, cur = current_direct_task(pair)
        local pos = target_position(pair, cur)
        local d = valid(pair.priest) and pos and dist(pair.priest.position, pos) or nil
        local s = pair.dispatcher_direct_0513 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 direct0513[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest)) .. " mode=" .. safe(pair.mode) .. " phase=" .. safe(s.phase)
          .. " item=" .. safe(s.item) .. " target=" .. safe(target_label(cur)) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil")
          .. " task=" .. safe(task and "yes" or "no") .. " detail=" .. safe(s.detail)
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 direct0513.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 DIRECT-ACQUISITION-0513 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_acquisition_executor()
  wrap_legacy_direct_functions()
  wrap_pair_dump()
  install_command()
  _G.TechPriestsDirectAcquisitionExecutor0513 = M
  if log then log("[Tech-Priests 0.1.513] dispatcher-owned direct acquisition executor installed; direct acquisition is now a phase-based leaf executor") end
  return true
end

return M