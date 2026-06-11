-- scripts/core/acquisition_executor.lua
-- Tech Priests 0.1.336 direct acquisition executor.
--
-- Previous repair layers could assign a direct-mine-0273/current target while
-- the priest still loitered around the station and merely claimed to be busy.
-- This module turns that claimed mining state into an enforced movement and
-- work loop: move to the target, show distance/progress, mine/damage the target,
-- deposit the result, and reissue movement if progress stalls.

local Exec = {}
Exec.version = "0.1.541"
Exec.storage_key = "acquisition_executor_0340"
Exec.move_refresh_ticks = 90
Exec.stall_ticks = 180
Exec.gather_ticks = 90
Exec.close_distance_sq = 4.00
Exec.max_per_pulse = 12

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pairs_by_station() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  return false
end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Exec.storage_key] = storage.tech_priests[Exec.storage_key] or { version = Exec.version, enabled = true, stats = {} }
  local root = storage.tech_priests[Exec.storage_key]
  root.version = Exec.version
  root.stats = root.stats or {}
  if root.enabled == nil then root.enabled = true end
  return root
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  local task = pair.emergency_craft
  local cur = task and task.current or nil
  if cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273" or cur.kind == "dirt" or cur.kind == "direct-mine-0336") then
    return task, cur
  end
  return nil, nil
end

local function target_position(pair, cur)
  if cur and cur.entity and cur.entity.valid then return cur.entity.position end
  if cur and cur.position then return cur.position end
  if pair and pair.target and pair.target.valid then return pair.target.position end
  return nil
end

local function station_inventory(pair)
  if not (pair and pair.station and pair.station.valid and pair.station.get_inventory) then return nil end
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

  -- 0.1.356 inventory steward: never use ground spill as the normal overflow
  -- path.  Try station inventory, known nearby containers, or an emergency
  -- stash chest before allowing the direct acquisition loop to proceed.
  if _G.tech_priests_safe_deposit_item then
    local ok = false
    local why = nil
    pcall(function() ok, why = _G.tech_priests_safe_deposit_item(pair, item, count, "direct-acquisition") end)
    if ok then return true end
    if _G.tech_priests_draw_emergency_operation_status_0184 then
      pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, string.format("[item=%s] deposit blocked: %s", tostring(item), tostring(why)))
    end
    return false
  end

  local inv = station_inventory(pair)
  if inv and inv.can_insert and inv.can_insert({ name = item, count = count }) then
    local ok, inserted = pcall(function() return inv.insert({ name = item, count = count }) end)
    if ok and (inserted or 0) > 0 then return true end
  end
  -- Legacy fallback retained only for saves where the steward failed to load.
  pcall(function()
    pair.station.surface.spill_item_stack({
      position = pair.priest and pair.priest.valid and pair.priest.position or pair.station.position,
      stack = { name = item, count = count },
      force = pair.station.force,
      allow_belts = false
    })
  end)
  return true
end

local function show(pair, text, target)
  if _G.tech_priests_draw_emergency_operation_status_0184 then pcall(_G.tech_priests_draw_emergency_operation_status_0184, pair, text) end
  if _G.draw_emergency_craft_scan_line and target and target.valid then pcall(_G.draw_emergency_craft_scan_line, pair, target) end
end

local function set_command_to(pair, pos, reason)
  if not valid_pair(pair) or not pos then return false end
  if pair.movement_lockdown_until_0416 and now() < pair.movement_lockdown_until_0416 then return false end
  local ok = false
  if _G.tech_priests_request_movement_0418 then
    ok = _G.tech_priests_request_movement_0418(pair, pos, reason or "acquisition-executor", { radius = 0.75, owner = "acquisition-executor", priority = 60, distraction = defines.distraction.by_enemy })
  else
    local command = {
      type = defines.command.go_to_location,
      destination = pos,
      radius = 0.75,
      distraction = defines.distraction.by_enemy
    }
    if _G.tech_priests_route_ground_command_0429 then
      local ok_route, res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "acquisition-executor-fallback-0621", { pair = pair, priority = 60, ttl = 600 })
      ok = ok_route and res ~= false
    else
      ok = pcall(function()
        local commandable = pair.priest.commandable
        if commandable and commandable.valid then commandable.set_command(command) else pair.priest.set_command(command) end
      end)
    end
  end
  if ok then pair.last_direct_mine_command_0336 = { tick = now(), x = pos.x, y = pos.y, reason = reason } end
  return ok
end

local function stop_for_work_0541(pair, cur)
  if not valid_pair(pair) then return false end
  pair.movement_request_0418 = nil
  pair.movement_controller_state_0418 = "work-clamped-direct-acquisition-0541"
  pair.movement_controller_clamp_0418 = "direct-acquisition-working"
  pair.movement_controller_reason_0418 = "direct-acquisition-working-0541"
  pair.movement_stabilize_until_0418 = math.max(tonumber(pair.movement_stabilize_until_0418) or 0, now() + 30)
  pair.mining_lock_0315 = { tick = now(), until_tick = now() + 45, target = cur and cur.entity }
  local ok_any = false
  if _G.tech_priests_stop_movement_0418 then
    local ok, res = pcall(_G.tech_priests_stop_movement_0418, pair, "direct-acquisition-working-0621")
    ok_any = ok and res ~= false
  end
  if not ok_any then
    pcall(function()
      local commandable = pair.priest.commandable
      if commandable and commandable.valid then commandable.set_command({ type = defines.command.stop }); ok_any = true end
    end)
    pcall(function() if pair.priest.set_command then pair.priest.set_command({ type = defines.command.stop }); ok_any = true end end)
  end
  pcall(function() pair.priest.walking_state = { walking = false } end)
  return ok_any
end

local function mine_hit(pair, task, cur, final)
  if cur.entity and cur.entity.valid then
    local e = cur.entity
    if _G.draw_emergency_craft_scan_line then pcall(function() _G.draw_emergency_craft_scan_line(pair, e) end) end
    if _G.spawn_emergency_craft_smoke then
      pcall(function() _G.spawn_emergency_craft_smoke(pair, e.position, final == true) end)
    elseif e.surface and e.surface.create_trivial_smoke then
      pcall(function() e.surface.create_trivial_smoke({ name = "smoke-fast", position = e.position }) end)
    end
    pcall(function()
      if e.valid and e.type == "resource" then
        local amount = tonumber(e.amount) or 0
        if amount > 1 then e.amount = math.max(1, amount - (final and 25 or 3)) end
      elseif e.valid and e.health and e.health > 1 then
        e.damage(final and 35 or 5, pair.station.force, "impact", pair.priest)
      end
    end)
  elseif cur.position and _G.spawn_emergency_craft_smoke then
    pcall(function() _G.spawn_emergency_craft_smoke(pair, cur.position, final == true) end)
  end
end

local function output_item(task, cur)
  local item = cur and (cur.output_item or cur.item_name or cur.wanted_item) or nil
  if item_exists(item) then return item end
  item = task and (task.output_item or task.item_name) or nil
  if item_exists(item) then return item end
  return item_exists("stone") and "stone" or nil
end

local function required_units(task)
  local n = task and task.recipe and tonumber(task.recipe.units) or nil
  n = n or tonumber(task and task.required_count) or tonumber(task and task.count) or 1
  return math.max(1, math.min(50, n))
end

function Exec.service_pair(pair, reason)
  local root = ensure_root(); if root.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  local task, cur = current_direct_task(pair)
  if not task then return false, "no-direct-task" end
  if _G.tech_priests_0507_action_claim then pcall(_G.tech_priests_0507_action_claim, pair, "direct-acquisition", "acquisition_executor", reason or "service_pair") end
  local pos = target_position(pair, cur)
  if not pos then return false, "no-target-position" end

  pair.direct_mine_executor_0336 = pair.direct_mine_executor_0336 or {}
  local state = pair.direct_mine_executor_0336
  state.last_seen_tick = now()
  state.reason = reason or state.reason or "pulse"

  local d2 = dist_sq(pair.priest.position, pos)
  local d = math.sqrt(d2)
  local previous = state.last_distance
  state.last_distance = d

  -- If the target vanished, clear only the current pointer and let the repair
  -- layer choose a new target on the next pulse.
  if cur.entity and not cur.entity.valid then
    task.current = nil
    pair.mining_lock_0315 = nil
    pair.mode = "emergency-gathering"
    root.stats.invalid_target = (root.stats.invalid_target or 0) + 1
    show(pair, "direct mine target vanished; reacquiring", pair.station)
    return false, "invalid-target"
  end

  -- Far away means movement is mandatory, not just a label saying “busy”.
  if d2 > Exec.close_distance_sq then
    pair.mining_lock_0315 = nil
    local stale = (not pair.last_direct_mine_command_0336) or (now() - (pair.last_direct_mine_command_0336.tick or 0) >= Exec.move_refresh_ticks)
    local stalled = previous and d >= previous - 0.05 and (now() - (state.last_progress_tick or 0) >= Exec.stall_ticks)
    if not previous or d < previous - 0.05 then state.last_progress_tick = now() end
    if stale or stalled then
      set_command_to(pair, pos, stalled and "stall-reissue" or "move-refresh")
      root.stats.move_commands = (root.stats.move_commands or 0) + 1
    end
    show(pair, string.format("[item=%s] moving to mine %.1fm", tostring(output_item(task, cur) or cur.item_name or "stone"), d), cur.entity)
    return true, "moving"
  end

  -- Close enough: begin or continue actual work.
  stop_for_work_0541(pair, cur)
  pair.mode = "emergency-gathering"
  pair.target = cur.entity
  if not task.direct_due_tick_0336 then
    task.direct_due_tick_0336 = now() + Exec.gather_ticks
    task.direct_started_tick_0336 = now()
    task.direct_due_tick_0273 = task.direct_due_tick_0273 or task.direct_due_tick_0336
    root.stats.work_started = (root.stats.work_started or 0) + 1
  end

  if now() < task.direct_due_tick_0336 then
    stop_for_work_0541(pair, cur)
    if (not task.direct_last_visual_tick_0336) or now() - task.direct_last_visual_tick_0336 >= 15 then
      task.direct_last_visual_tick_0336 = now()
      mine_hit(pair, task, cur, false)
    end
    local remain = math.max(0, task.direct_due_tick_0336 - now())
    show(pair, string.format("[item=%s] mining %ds", tostring(output_item(task, cur) or cur.item_name or "stone"), math.ceil(remain / 60)), cur.entity)
    return true, "working"
  end

  mine_hit(pair, task, cur, true)
  local item = output_item(task, cur)
  if item then deposit(pair, item, 1) end
  task.gathered_units = (task.gathered_units or 0) + 1
  root.stats.deposited = (root.stats.deposited or 0) + 1
  pair.last_direct_mine_completion_0336 = { tick = now(), item = item, count = task.gathered_units, reason = reason }

  if task.gathered_units < required_units(task) and ((not cur.entity) or cur.entity.valid) then
    task.direct_due_tick_0336 = nil
    task.direct_due_tick_0273 = nil
    show(pair, string.format("[item=%s] mined %d/%d", tostring(item or "stone"), task.gathered_units, required_units(task)), cur.entity)
    return true, "continue"
  end

  -- 0.1.337: if this direct gathering was part of an emergency recipe, do not
  -- clear the task just because the last raw ingredient was gathered. The next
  -- visible step is to return to the Cogitator Station and craft the requested
  -- output there.
  if task.recipe and task.output_item and item_exists(task.output_item) then
    task.current = nil
    pair.mining_lock_0315 = nil
    task.direct_due_tick_0336 = nil
    task.direct_due_tick_0273 = nil
    task.station_craft_pending_0337 = true
    pair.mode = "returning-to-station-for-craft"
    pair.target = pair.station
    show(pair, string.format("[item=%s] materials ready; returning to station to craft", tostring(task.output_item)), pair.station)
    if pair.station and pair.station.valid then set_command_to(pair, pair.station.position, "return-for-craft") end
    pcall(function()
      local Craft = require("scripts.core.crafting_executor")
      if Craft and Craft.before_legacy_handle then Craft.before_legacy_handle(pair) end
    end)
    return true, "ready-to-craft"
  end

  task.current = nil
  pair.mining_lock_0315 = nil
  pair.emergency_craft = nil
  pair.mode = "returning"
  pair.target = nil
  show(pair, string.format("[item=%s] direct mining complete", tostring(item or "stone")), pair.station)
  if _G.return_to_station then pcall(function() _G.return_to_station(pair) end) end
  return true, "complete"
end

function Exec.pulse(reason)
  local root = ensure_root(); if root.enabled == false then return end
  local n = 0
  for _, pair in pairs(pairs_by_station()) do
    if valid_pair(pair) and current_direct_task(pair) then
      local ok = Exec.service_pair(pair, reason or "pulse")
      if ok then n = n + 1 end
      if n >= Exec.max_per_pulse then break end
    end
  end
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok then return pair end end
  local selected = player and player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  return nil
end

function Exec.commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-mine-0336", "Tech Priests: direct mining executor status/kick/all/enable/disable.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local root = ensure_root()
      local p = tostring(event.parameter or "status")
      if p == "enable" then root.enabled = true end
      if p == "disable" then root.enabled = false end
      if p == "all" then Exec.pulse("manual-all") end
      local pair = selected_pair(player)
      local result = "none"
      if p == "kick" and pair then local _, r = Exec.service_pair(pair, "manual-kick"); result = tostring(r) end
      local task, cur = pair and current_direct_task(pair) or nil, nil
      if pair then task, cur = current_direct_task(pair) end
      local dist = "none"
      if pair and cur and target_position(pair, cur) and pair.priest and pair.priest.valid then dist = string.format("%.2f", math.sqrt(dist_sq(pair.priest.position, target_position(pair, cur)))) end
      player.print("[Tech Priests 0.1.337] direct mining executor enabled=" .. tostring(root.enabled) .. " selected-mode=" .. tostring(pair and pair.mode or "none") .. " has-direct=" .. tostring(cur ~= nil) .. " dist=" .. tostring(dist) .. " result=" .. result .. " move=" .. tostring(root.stats.move_commands or 0) .. " work=" .. tostring(root.stats.work_started or 0) .. " deposited=" .. tostring(root.stats.deposited or 0))
    end)
  end)
end

function Exec.install()
  ensure_root()
  if Exec.installed_0507 then return true end
  Exec.installed_0507 = true
  Exec.commands()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(30, function() Exec.pulse("nth-tick-30-acquisition-executor-owned-0507") end, { owner = "acquisition_executor", category = "acquisition", note = "single owned direct acquisition executor pulse", priority = "normal" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(30, function() Exec.pulse("nth-tick-30") end)
  end
  if log then log("[Tech-Priests 0.1.507] direct acquisition executor installed once via runtime registry") end
  return true
end

return Exec
