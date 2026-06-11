-- Auto-split control.lua fragment 022 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0315_insert_loose_item(pair, item_entity)
  if not (pair and pair.station and pair.station.valid and item_entity and item_entity.valid and item_entity.type == "item-entity") then return false end
  local stack = nil
  local ok_stack = pcall(function() stack = item_entity.stack end)
  if not (ok_stack and stack and stack.valid_for_read) then return false end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if not inv then return false end
  local inserted = 0
  pcall(function() inserted = inv.insert(stack) end)
  if inserted and inserted > 0 then
    if inserted >= stack.count then
      pcall(function() item_entity.destroy() end)
    else
      pcall(function() stack.count = stack.count - inserted end)
    end
    pair.last_ground_pickup_0315 = { tick = game and game.tick or 0, item = stack.name, count = inserted }
    return true
  end
  return false
end

function tech_priests_0315_stop_for_mining(pair)
  if not tech_priests_0315_valid_pair(pair) then return end
  local tick = game and game.tick or 0
  if tick < (pair.next_mining_stop_command_0315 or 0) then return end
  pair.next_mining_stop_command_0315 = tick + 30
  if tech_priests_stop_movement_0418 then
    pcall(function() tech_priests_stop_movement_0418(pair, "mining-work-clamp-0315") end)
  else
    pcall(function() pair.priest.set_command({ type = defines.command.stop }) end)
  end
end

function tech_priests_0315_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not tech_priests_0315_valid_pair(pair) then return false end

  -- Loose dropped items are not quarry targets. Pick them up or let the ground
  -- stockpile scavenger handle them; never fire a mining beam at them.
  if cur.entity and cur.entity.valid and cur.entity.type == "item-entity" then
    return tech_priests_0315_insert_loose_item(pair, cur.entity)
  end

  if tech_priests_0315_is_hostile_nearby(pair, TECH_PRIESTS_0315_INTERRUPT_RADIUS) then
    pair.mining_lock_0315 = nil
    return false
  end

  local priest = pair.priest
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  local dist2 = dx * dx + dy * dy

  if dist2 > TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ then
    if (game and game.tick or 0) >= (pair.next_mining_move_command_0315 or 0) then
      pair.next_mining_move_command_0315 = (game and game.tick or 0) + 30
      pcall(function()
        if tech_priests_request_movement_0418 then
          tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0315", { radius = 0.65, owner = "direct-gather-0315", priority = 55, distraction = defines.distraction.by_enemy })
        else
          priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.65, distraction = defines.distraction.by_enemy })
        end
      end)
    end
    pair.mining_lock_0315 = nil
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end

  tech_priests_0315_stop_for_mining(pair)
  pair.mining_lock_0315 = { tick = game and game.tick or 0, x = pos.x, y = pos.y, kind = cur.kind, item = cur.output_item or cur.item_name }
  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"

  local tick = game and game.tick or 0
  if not task.direct_due_tick_0315 then
    task.direct_due_tick_0315 = tick + (TECH_PRIESTS_0315_MINING_FINISH_TICKS or 60)
    task.direct_due_tick_0312 = task.direct_due_tick_0315
    task.direct_due_tick_0273 = task.direct_due_tick_0315
  end

  local profile = tech_priests_0315_effective_profile(priest.force)
  local pulse_ticks = math.max(3, math.min(TECH_PRIESTS_0315_MINING_PULSE_TICKS, profile.mining_laser_ticks or TECH_PRIESTS_0315_MINING_PULSE_TICKS))
  if cur.entity and cur.entity.valid and tick >= (task.next_direct_laser_tick_0315 or 0) then
    task.next_direct_laser_tick_0315 = tick + pulse_ticks
    tech_priests_0312_fire_laser(priest, cur.entity, profile.mining_laser_damage or 5, "direct-mining", { r = 1.0, g = 0.34, b = 0.04, a = 0.78 })
  elseif cur.position and tick >= (task.next_direct_laser_tick_0315 or 0) then
    task.next_direct_laser_tick_0315 = tick + pulse_ticks
    if spawn_emergency_craft_smoke then pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end) end
  end

  if tick < (task.direct_due_tick_0315 or tick) then return true end

  if cur.entity and cur.entity.valid then
    tech_priests_0312_fire_laser(priest, cur.entity, math.max(10, (profile.mining_laser_damage or 5) * 2), "direct-mining-final", { r = 1.0, g = 0.58, b = 0.08, a = 0.92 })
    pcall(function()
      local e = cur.entity
      if e.valid and e.type == "resource" then
        local amount = e.amount or 0
        if amount > 1 then e.amount = math.max(1, amount - 25) else e.destroy() end
      elseif e.valid and e.health and e.health > 0 then
        e.damage(math.max(25, (profile.mining_laser_damage or 5) * 4), priest.force, "laser", priest)
        if e.valid and e.health and e.health <= 1 then e.destroy() end
      end
    end)
  end

  local output = cur.output_item or cur.item_name or (task and task.item) or "stone"
  if not (tech_priests_0312_item_exists and tech_priests_0312_item_exists(output)) then output = "stone" end
  local deposited = false
  if tech_priests_0273_deposit then
    local ok, result = pcall(function() return tech_priests_0273_deposit(pair, output, 1) end)
    deposited = ok and result
  end
  if not deposited then
    local inv = get_station_inventory and get_station_inventory(pair.station) or nil
    if inv and inv.can_insert({ name = output, count = 1 }) then pcall(function() inv.insert({ name = output, count = 1 }) end) end
  end

  task.gathered_units = (task.gathered_units or 0) + 1
  task.current = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0273 = nil
  pair.mining_lock_0315 = nil
  pair.last_direct_mining_laser_0315 = { tick = tick, output = output, source = cur.item_name or (cur.entity and cur.entity.name) or cur.kind }
  return true
end

TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT = handle_emergency_desperation_craft
function handle_emergency_desperation_craft(pair)
  if pair and pair.emergency_craft and pair.emergency_craft.current then
    local ok, handled = pcall(function() return tech_priests_0315_service_direct_current(pair, pair.emergency_craft) end)
    if ok and handled then return true end
  end
  return TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT and TECH_PRIESTS_0315_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT(pair) or false
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-mining-0315", "Tech Priests: inspect/force the 0.1.315 movement-locked unified mining beam for the selected pair.", function(event)
      local player = game and game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if find_pair_for_entity and player.selected then
        local ok, found = pcall(function() return find_pair_for_entity(player.selected) end)
        if ok then pair = found end
      end
      if not pair then player.print("[Tech Priests 0.1.315] select a Cogitator Station or Tech-Priest."); return end
      local cur = pair.emergency_craft and pair.emergency_craft.current or nil
      player.print("[Tech Priests 0.1.315] mode=" .. tostring(pair.mode) .. " lock=" .. tostring(pair.mining_lock_0315 ~= nil) .. " current=" .. tostring(cur and cur.kind or "nil") .. " target=" .. tostring(cur and cur.entity and cur.entity.valid and cur.entity.name or cur and cur.item_name or "nil"))
    end)
  end)
end

tech_priests_0315_log("movement-locked unified mining beam + glow clamp loaded")


-- 0.1.316 - local-variable-limit repair marker and glow nudge.
if commands then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-mining-0316", "Tech Priests: inspect movement-locked mining beam after 0.1.316 local limit repair.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = selected_pair_for_player and selected_pair_for_player(player) or nil
      if not pair then player.print("[Tech Priests 0.1.316] select a Cogitator Station or Tech-Priest."); return end
      local cur = pair.emergency_craft and pair.emergency_craft.current
      player.print("[Tech Priests 0.1.316] mode=" .. tostring(pair.mode) .. " lock=" .. tostring(pair.mining_lock_0315 ~= nil) .. " current=" .. tostring(cur and cur.kind or "nil") .. " target=" .. tostring(cur and cur.entity and cur.entity.valid and cur.entity.name or cur and cur.item_name or "nil") .. " glow=" .. tostring(TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY) .. "/" .. tostring(TECH_PRIESTS_0315_MODE_GLOW_INTENSITY))
    end)
  end)
end
if log then log("[Tech-Priests 0.1.316] mining local-variable-limit repair + slight glow nudge loaded") end

-- ============================================================================
-- 0.1.421: extracted late runtime installer spine.
-- ============================================================================
-- The 0.1.321+ patch/install chain used to live directly in control.lua.  It is
-- now delegated to scripts.core.bootstrap_runtime so control.lua is not the
-- permanent dumping ground for every new module installer and debug command.
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")
if TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 and TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install then
  TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install()
end
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = nil
