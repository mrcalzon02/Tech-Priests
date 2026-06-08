-- Auto-split control.lua fragment 019 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0293_assign_combat(pair, target, reason)
  if not (pair and target and target.valid) then return false end
  local tick = tech_priests_0293_now()
  local task = {
    type = "combat",
    target = target,
    priority = TECH_PRIESTS_0285_TASK_PRIORITY and TECH_PRIESTS_0285_TASK_PRIORITY.combat or 100,
    owner_system = "combat-proxy-0293",
    reason = reason or "enemy-pressure",
    updated_tick = tick,
    expires_tick = tick + math.max(90, PROXY_KEEPALIVE_TICKS or 120)
  }
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.assignment_op_0252 = nil
  pair.scheduler_acquisition_op_0287 = nil
  pair.active_task = task
  pair.active_task_0285 = task
  pair.task_kind = "combat"
  pair.combat_target = target
  pair.target = target
  pair.mode = "defending"
  return true
end

function tech_priests_0293_prime_proxy_attack(pair, target, reason)
  if not (tech_priests_0293_valid_pair(pair) and target and target.valid) then return false end
  local tick = tech_priests_0293_now()
  local priest = pair.priest
  local proxy = ensure_proxy and ensure_proxy(pair) or nil
  if not (proxy and proxy.valid) then
    pair.last_combat_fail_0293 = "no-proxy"
    return false
  end

  if tech_priests_align_proxy_to_priest_0430 then tech_priests_align_proxy_to_priest_0430(pair, proxy, priest, "combat proxy retarget attached to visible priest") else pcall(function() proxy.teleport(priest.position) end) end
  pcall(function() proxy.active = true end)
  pcall(function() proxy.operable = false end)
  pcall(function() proxy.destructible = false end)

  if not tech_priests_0293_proxy_has_ammo(pair) then
    local ok, loaded = pcall(function() return load_proxy_from_station and load_proxy_from_station(pair) end)
    if not (ok and loaded) then
      pair.mode = "missing-ammo-supplies"
      pair.target = target
      pair.combat_target = target
      pair.last_combat_fail_0293 = "no-compatible-ammo"
      pair.last_combat_fail_tick_0293 = tick
      if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "ammo", target) end) end
      return true
    end
  end

  -- Only reassign the turret target when it changes or on a slow keepalive.
  local target_unit = target.unit_number or tostring(target)
  if pair.last_proxy_target_unit_0293 ~= target_unit or tick >= (pair.next_proxy_retarget_tick_0293 or 0) then
    pcall(function() proxy.shooting_target = target end)
    pair.last_proxy_target_unit_0293 = target_unit
    pair.next_proxy_retarget_tick_0293 = tick + 60
  end

  pair.proxy_expires = tick + math.max(90, PROXY_KEEPALIVE_TICKS or 120)
  pair.combat_target = target
  pair.target = target
  pair.mode = "defending"
  pair.task_kind = "combat"
  pair.last_proxy_prime_reason_0293 = reason or "combat-prime"
  pair.last_proxy_prime_tick_0293 = tick

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local dist_sq = dx * dx + dy * dy
  local fire_range = COMBAT_FIRE_RANGE or 15

  -- Character command churn is the dangerous part.  The proxy turret is the real
  -- weapon; the priest command is visual/positioning and should not be spammed.
  if tick >= (pair.next_combat_command_tick_0293 or 0) or pair.last_combat_command_target_0293 ~= target_unit then
    pair.next_combat_command_tick_0293 = tick + TECH_PRIESTS_0293_COMBAT_COMMAND_COOLDOWN
    pair.last_combat_command_target_0293 = target_unit
    if issue_priest_command then
      if dist_sq > fire_range * fire_range then
        pcall(function()
          issue_priest_command(priest, {
            type = defines.command.go_to_location,
            destination = target.position,
            radius = COMBAT_APPROACH_RADIUS or math.max(1, fire_range - 2),
            distraction = defines.distraction.by_enemy
          })
        end)
        pair.mode = "moving-to-combat"
      else
        pcall(function()
          issue_priest_command(priest, {
            type = defines.command.attack,
            target = target,
            distraction = defines.distraction.none
          })
        end)
      end
    end
  end
  return true
end

function tech_priests_0293_force_combat_tick(pair, reason, force)
  if not tech_priests_0293_valid_pair(pair) then return false end
  local tick = tech_priests_0293_now()
  if not force and tick < (pair.next_combat_service_tick_0293 or 0) then return false end
  pair.next_combat_service_tick_0293 = tick + TECH_PRIESTS_0293_COMBAT_PAIR_COOLDOWN

  local target = tech_priests_0293_select_target(pair)
  if not (target and target.valid) then
    tech_priests_0293_clear_dead_combat(pair, "no-target")
    return false
  end

  local has_ammo = tech_priests_0293_station_has_ammo(pair) or tech_priests_0293_proxy_has_ammo(pair)
  local current = pair.active_task or pair.active_task_0285
  local current_priority = tech_priests_0285_task_priority and tech_priests_0285_task_priority(current) or 0
  local combat_priority = TECH_PRIESTS_0285_TASK_PRIORITY and TECH_PRIESTS_0285_TASK_PRIORITY.combat or 100

  if force or has_ammo or current_priority < combat_priority or (current and current.type == "combat") then
    tech_priests_0293_assign_combat(pair, target, reason or "enemy-pressure")
  else
    return false
  end

  return tech_priests_0293_prime_proxy_attack(pair, target, reason or "combat-guard")
end

-- Override the over-eager 0.1.292 force function used by its tick_pair wrapper.
tech_priests_0292_force_combat_tick = tech_priests_0293_force_combat_tick

-- Stop the 0.1.292 global scan cadence and replace it with a slower guard pass.
pcall(function() TechPriestsRuntimeEventRegistry.on_nth_tick(17, nil) end)
TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_0293_GLOBAL_SCAN_TICKS, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local processed = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    processed = processed + 1
    if processed > 16 then break end
    pcall(function() tech_priests_0293_force_combat_tick(pair, "nth-tick-0293", false) end)
  end
end)

-- Replace tick_pair with a guard that calls the pre-0.1.292 behavior stack.  This
-- avoids the 0.1.292 double combat call before and after every legacy tick.
TECH_PRIESTS_0293_PRE_TICK_PAIR = TECH_PRIESTS_0292_PRE_TICK_PAIR or TECH_PRIESTS_0293_PRE_TICK_PAIR or tick_pair
function tick_pair(pair)
  if pair and tech_priests_0293_force_combat_tick(pair, "tick-guard-0293", false) then
    return true
  end
  if TECH_PRIESTS_0293_PRE_TICK_PAIR then
    return TECH_PRIESTS_0293_PRE_TICK_PAIR(pair)
  end
  return false
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-combat-0293", "Tech Priests: guarded combat proxy check for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      local selected = player.selected
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests 0.1.293] Select a Cogitator Station or Tech-Priest first."); return end
      local did = tech_priests_0293_force_combat_tick(pair, "manual-command", true)
      local target = pair.combat_target or pair.target
      player.print("[Tech Priests 0.1.293] combat did=" .. tostring(did) .. " target=" .. tostring(target and target.valid and target.name or "none") .. " station_ammo=" .. tostring(tech_priests_0293_station_has_ammo(pair)) .. " proxy_ammo=" .. tostring(tech_priests_0293_proxy_has_ammo(pair)) .. " mode=" .. tostring(pair.mode or "nil") .. " fail=" .. tostring(pair.last_combat_fail_0293 or pair.last_combat_fail_0292 or "none"))
    end)
  end)
end

tech_priests_0293_log("0.1.293 combat hard-lock guard + proxy cadence limiter loaded")


-- -----------------------------------------------------------------------------
-- 0.1.294 combat cadence tune + low-health retreat doctrine
-- -----------------------------------------------------------------------------
-- 0.1.293 fixed the combat hard-lock by being deliberately conservative.  Live
-- testing confirmed firing now works, but the proxy service cadence was too slow.
-- This layer loosens the combat service timing and adds a survival doctrine: a
-- priest under 25% health retreats to its station unless an enemy is physically in
-- collision/contact range.  Poison/fire/area damage does not count as contact.

TECH_PRIESTS_PATCH_0294 = "0.1.294-combat-cadence-retreat-doctrine"
TECH_PRIESTS_0294_COMBAT_PAIR_COOLDOWN = 6
TECH_PRIESTS_0294_COMBAT_COMMAND_COOLDOWN = 30
TECH_PRIESTS_0294_PROXY_RETARGET_COOLDOWN = 30
TECH_PRIESTS_0294_RETREAT_HEALTH_RATIO = 0.25
TECH_PRIESTS_0294_RETREAT_CONTACT_RADIUS = 1.35
TECH_PRIESTS_0294_RETREAT_STATION_RADIUS = 2.25
TECH_PRIESTS_0294_RETREAT_SERVICE_COOLDOWN = 15
TECH_PRIESTS_0294_RETREAT_REPAIR_COOLDOWN = 45

function tech_priests_0294_now()
  return game and game.tick or 0
end

function tech_priests_0294_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.294] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.294] " .. tostring(msg))
  end
end

function tech_priests_0294_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0294_max_health(entity)
  if not (entity and entity.valid) then return nil end
  local ok, maxh = pcall(function()
    return entity.prototype and entity.prototype.max_health
  end)
  if ok and type(maxh) == "number" and maxh > 0 then return maxh end
  return nil
end

function tech_priests_0294_health_ratio(entity)
  if not (entity and entity.valid and entity.health) then return 1 end
  local maxh = tech_priests_0294_max_health(entity)
  if not maxh or maxh <= 0 then return 1 end
  return entity.health / maxh
end

function tech_priests_0294_enemy_in_contact(pair)
  if not tech_priests_0294_valid_pair(pair) then return false end
  local priest = pair.priest
  local surface = priest.surface
  if not surface then return false end
  local enemies = {}
  local ok = pcall(function()
    enemies = surface.find_entities_filtered({
      position = priest.position,
      radius = TECH_PRIESTS_0294_RETREAT_CONTACT_RADIUS,
      force = priest.force and priest.force.get_friend and nil or nil
    })
  end)
  if not ok then
    local ok2, found = pcall(function()
      return surface.find_entities_filtered({position = priest.position, radius = TECH_PRIESTS_0294_RETREAT_CONTACT_RADIUS})
    end)
    enemies = ok2 and found or {}
  end
  local my_force = priest.force
  for _, e in pairs(enemies or {}) do
    if e and e.valid and e ~= priest and e.force and my_force and e.force ~= my_force then
      local hostile = true
      pcall(function() hostile = e.force.is_enemy(my_force) end)
      if hostile and (e.type == "unit" or e.type == "unit-spawner" or e.type == "turret" or e.type == "spider-vehicle") then
        return true
      end
    end
  end
  return false
end

function tech_priests_0294_get_station_inventory(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  if get_station_inventory then
    local ok, inv = pcall(function() return get_station_inventory(pair.station) end)
    if ok and inv then return inv end
  end
  local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
  if ok and inv then return inv end
  ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.assembling_machine_input) end)
  if ok and inv then return inv end
  return nil
end

function tech_priests_0294_count_item(inv, name)
  if not (inv and name) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(name) end)
  return ok and n or 0
end

function tech_priests_0294_remove_item(inv, name, count)
  if not (inv and name and count and count > 0) then return 0 end
  local ok, n = pcall(function() return inv.remove({name=name, count=count}) end)
  return ok and (n or 0) or 0
end

function tech_priests_0294_heal_entity(entity, amount)
  if not (entity and entity.valid and amount and amount > 0) then return false end
  local maxh = tech_priests_0294_max_health(entity)
  if not maxh or not entity.health then return false end
  local before = entity.health
  local after = math.min(maxh, before + amount)
  if after <= before then return false end
  local ok = pcall(function() entity.health = after end)
  return ok
end

function tech_priests_0294_try_station_repair_supplies(pair)
  if not tech_priests_0294_valid_pair(pair) then return false end
  local tick = tech_priests_0294_now()
  if tick < (pair.next_retreat_repair_tick_0294 or 0) then return false end
  pair.next_retreat_repair_tick_0294 = tick + TECH_PRIESTS_0294_RETREAT_REPAIR_COOLDOWN

  local inv = tech_priests_0294_get_station_inventory(pair)
  if not inv then return false end
  if tech_priests_0294_count_item(inv, "repair-pack") <= 0 then
    if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "repair-pack", pair.station) end) end
    pair.last_retreat_fail_0294 = "no-repair-pack"
    return false
  end

  local priest_max = tech_priests_0294_max_health(pair.priest) or 100
  local station_max = tech_priests_0294_max_health(pair.station) or 100
  local repaired_any = false

  if pair.priest.health and pair.priest.health < priest_max then
    local removed = tech_priests_0294_remove_item(inv, "repair-pack", 1)
    if removed > 0 then
      repaired_any = tech_priests_0294_heal_entity(pair.priest, math.max(25, priest_max * 0.35)) or repaired_any
    end
  end

  if pair.station.health and pair.station.health < station_max and tech_priests_0294_count_item(inv, "repair-pack") > 0 then
    local removed = tech_priests_0294_remove_item(inv, "repair-pack", 1)
    if removed > 0 then
      repaired_any = tech_priests_0294_heal_entity(pair.station, math.max(50, station_max * 0.25)) or repaired_any
    end
  end

  if repaired_any then
    pair.last_retreat_repair_tick_0294 = tick
    pair.last_retreat_fail_0294 = nil
  end
  return repaired_any
end

function tech_priests_0294_distance_sq(a, b)
  if not (a and b) then return 999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx*dx + dy*dy
end

function tech_priests_0294_retreat_tick(pair, reason)
  if not tech_priests_0294_valid_pair(pair) then return false end
  local tick = tech_priests_0294_now()
  if tick < (pair.next_retreat_service_tick_0294 or 0) then return false end
  pair.next_retreat_service_tick_0294 = tick + TECH_PRIESTS_0294_RETREAT_SERVICE_COOLDOWN

  local ratio = tech_priests_0294_health_ratio(pair.priest)
  if ratio > TECH_PRIESTS_0294_RETREAT_HEALTH_RATIO then
    if pair.mode == "retreating-to-station" or (pair.active_task and pair.active_task.type == "retreat") then
      pair.mode = "idle"
      if pair.active_task and pair.active_task.type == "retreat" then pair.active_task = nil end
      if pair.active_task_0285 and pair.active_task_0285.type == "retreat" then pair.active_task_0285 = nil end
    end
    return false
  end

  -- If the priest is literally in claw-range, it does not try to flee through the
  -- enemy collision box.  Poison/fire/area damage has no contact body here, so it
  -- does not block retreat.
  if tech_priests_0294_enemy_in_contact(pair) then
    pair.last_retreat_blocked_0294 = "enemy-contact-fight-to-death"
    pair.last_retreat_blocked_tick_0294 = tick
    return false
  end

  if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.shooting_target = nil end) end
  pair.combat_target = nil
  pair.target = pair.station
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.scheduler_acquisition_op_0287 = nil
  pair.mode = "retreating-to-station"
  pair.task_kind = "retreat"
  local task = {
    type = "retreat",
    priority = 110,
    target = pair.station,
    owner_system = "retreat-0294",
    reason = reason or "low-health",
    updated_tick = tick,
    expires_tick = tick + 600
  }
  pair.active_task = task
  pair.active_task_0285 = task

  local dist_sq = tech_priests_0294_distance_sq(pair.priest.position, pair.station.position)
  if dist_sq <= TECH_PRIESTS_0294_RETREAT_STATION_RADIUS * TECH_PRIESTS_0294_RETREAT_STATION_RADIUS then
    tech_priests_0294_try_station_repair_supplies(pair)
  else
    if issue_priest_command then
      pcall(function()
        issue_priest_command(pair.priest, {
          type = defines.command.go_to_location,
          destination = pair.station.position,
          radius = TECH_PRIESTS_0294_RETREAT_STATION_RADIUS,
          distraction = defines.distraction.by_enemy
        })
      end)
    end
  end
  return true
end

-- Retune the 0.1.293 guard constants when that layer is present.
TECH_PRIESTS_0293_COMBAT_PAIR_COOLDOWN = TECH_PRIESTS_0294_COMBAT_PAIR_COOLDOWN
TECH_PRIESTS_0293_COMBAT_COMMAND_COOLDOWN = TECH_PRIESTS_0294_COMBAT_COMMAND_COOLDOWN

-- Wrap proxy priming to lower the target keepalive delay without restoring the
-- 0.1.292 hard-lock behavior.
TECH_PRIESTS_0294_PRE_PRIME_PROXY_ATTACK = tech_priests_0293_prime_proxy_attack
function tech_priests_0293_prime_proxy_attack(pair, target, reason)
  if not tech_priests_0294_valid_pair(pair) then return false end
  local result = TECH_PRIESTS_0294_PRE_PRIME_PROXY_ATTACK and TECH_PRIESTS_0294_PRE_PRIME_PROXY_ATTACK(pair, target, reason) or false
  if result and pair then
    pair.next_proxy_retarget_tick_0293 = math.min(pair.next_proxy_retarget_tick_0293 or 0, tech_priests_0294_now() + TECH_PRIESTS_0294_PROXY_RETARGET_COOLDOWN)
  end
  return result
end

-- Wrap combat selection so retreat suppresses ranged combat only while low-health
-- and not physically pinned by an enemy.
TECH_PRIESTS_0294_PRE_FORCE_COMBAT_TICK = tech_priests_0293_force_combat_tick
function tech_priests_0293_force_combat_tick(pair, reason, force)
  if tech_priests_0294_valid_pair(pair)
     and tech_priests_0294_health_ratio(pair.priest) <= TECH_PRIESTS_0294_RETREAT_HEALTH_RATIO
     and not tech_priests_0294_enemy_in_contact(pair) then
    if tech_priests_0294_retreat_tick(pair, "combat-suppressed-low-health") then return true end
    return false
  end
  return TECH_PRIESTS_0294_PRE_FORCE_COMBAT_TICK and TECH_PRIESTS_0294_PRE_FORCE_COMBAT_TICK(pair, reason, force) or false
end
tech_priests_0292_force_combat_tick = tech_priests_0293_force_combat_tick

-- Main behavior wrapper: retreat gets first claim, but melee contact lets combat
-- proceed so the priest fights to the death when physically surrounded.
TECH_PRIESTS_0294_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  if tech_priests_0294_valid_pair(pair)
     and tech_priests_0294_health_ratio(pair.priest) <= TECH_PRIESTS_0294_RETREAT_HEALTH_RATIO
     and not tech_priests_0294_enemy_in_contact(pair) then
    if tech_priests_0294_retreat_tick(pair, "tick-low-health") then return true end
  end
  if TECH_PRIESTS_0294_PRE_TICK_PAIR then return TECH_PRIESTS_0294_PRE_TICK_PAIR(pair) end
  return false
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-retreat-0294", "Tech Priests: force low-health retreat doctrine check for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = nil
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests 0.1.294] Select a Cogitator Station or Tech-Priest first."); return end
      local did = tech_priests_0294_retreat_tick(pair, "manual-command")
      player.print("[Tech Priests 0.1.294] retreat did=" .. tostring(did) .. " hp=" .. tostring(math.floor(tech_priests_0294_health_ratio(pair.priest) * 100)) .. "% contact=" .. tostring(tech_priests_0294_enemy_in_contact(pair)) .. " mode=" .. tostring(pair.mode or "nil") .. " fail=" .. tostring(pair.last_retreat_fail_0294 or pair.last_retreat_blocked_0294 or "none"))
    end)
  end)
end

tech_priests_0294_log("0.1.294 combat cadence loosened + low-health retreat doctrine loaded")


-- -----------------------------------------------------------------------------
-- 0.1.295 retreat/no-ammo swarm crash guard
-- -----------------------------------------------------------------------------
-- Live testing showed 0.1.294 could cork Factorio when low-health priests were
-- swarmed while their stations had no ammunition.  The likely bad loop was:
-- combat tick -> no ammo -> supply/scavenge request -> retreat check -> melee
-- contact/retreat reconsideration -> repeat at high cadence across multiple
-- pairs.  This layer deliberately separates "I am pinned and ammo-empty" from
-- normal acquisition.  Pinned priests may die; they must not launch pathing or
-- logistics churn every few ticks while being eaten.

TECH_PRIESTS_0295_PINNED_RADIUS = 2.35
TECH_PRIESTS_0295_NO_AMMO_RETRY_TICKS = 180
TECH_PRIESTS_0295_RETREAT_RECHECK_TICKS = 60
TECH_PRIESTS_0295_SUPPLY_RETRY_TICKS = 300

function tech_priests_0295_now()
  return game and game.tick or 0
end

function tech_priests_0295_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.295] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.295] " .. tostring(msg))
  end
end

function tech_priests_0295_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0295_is_enemy_entity(entity, my_force)
  if not (entity and entity.valid and my_force and entity.force) then return false end
  if entity.force == my_force then return false end
  local hostile = false
  local ok = pcall(function() hostile = entity.force.is_enemy(my_force) end)
  if not ok then hostile = (entity.force ~= my_force) end
  if not hostile then return false end
  return entity.type == "unit" or entity.type == "unit-spawner" or entity.type == "turret" or entity.type == "spider-vehicle"
end

function tech_priests_0295_enemy_in_body_contact(pair, radius)
  if not tech_priests_0295_valid_pair(pair) then return false end
  local priest = pair.priest
  local surface = priest.surface
  if not surface then return false end
  local found = nil
  local ok = pcall(function()
    found = surface.find_entities_filtered({
      position = priest.position,
      radius = radius or TECH_PRIESTS_0295_PINNED_RADIUS
    })
  end)
  if not ok or not found then return false end
  local my_force = priest.force
  local count = 0
  for _, e in pairs(found) do
    count = count + 1
    if count > 80 then break end
    if e ~= priest and tech_priests_0295_is_enemy_entity(e, my_force) then
      return true
    end
  end
  return false
end

-- Replace the narrower/less guarded 0.1.294 contact test.  This still ignores
-- poison/fire unless there is a hostile body actually near the priest.
function tech_priests_0294_enemy_in_contact(pair)
  return tech_priests_0295_enemy_in_body_contact(pair, TECH_PRIESTS_0295_PINNED_RADIUS)
end

function tech_priests_0295_station_or_proxy_has_ammo(pair)
  local has_station = false
  local has_proxy = false
  if tech_priests_0293_station_has_ammo then
    local ok, res = pcall(function() return tech_priests_0293_station_has_ammo(pair) end)
    has_station = ok and res or false
  elseif count_station_ammo_items and pair and pair.station and pair.station.valid then
    local ok, n = pcall(function() return count_station_ammo_items(pair.station) end)
    has_station = ok and n and n > 0 or false
  end
  if tech_priests_0293_proxy_has_ammo then
    local ok, res = pcall(function() return tech_priests_0293_proxy_has_ammo(pair) end)
    has_proxy = ok and res or false
  end
  return has_station or has_proxy
end

function tech_priests_0295_mark_pinned_no_ammo(pair, target, reason)
  if not pair then return false end
  local tick = tech_priests_0295_now()
  pair.mode = "pinned-no-ammo"
  pair.task_kind = "combat"
  pair.target = target
  pair.combat_target = target
  pair.last_combat_fail_0295 = reason or "pinned-no-ammo"
  pair.last_combat_fail_tick_0295 = tick
  pair.next_combat_service_tick_0293 = tick + TECH_PRIESTS_0295_NO_AMMO_RETRY_TICKS
  pair.next_retreat_service_tick_0294 = tick + TECH_PRIESTS_0295_RETREAT_RECHECK_TICKS
  pair.next_ammo_supply_retry_tick_0295 = math.max(pair.next_ammo_supply_retry_tick_0295 or 0, tick + TECH_PRIESTS_0295_SUPPLY_RETRY_TICKS)
  if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.shooting_target = nil end) end
  local task = {
    type = "combat",
    subtype = "pinned-no-ammo",
    priority = TECH_PRIESTS_0285_TASK_PRIORITY and TECH_PRIESTS_0285_TASK_PRIORITY.combat or 100,
    target = target,
    owner_system = "combat-swarm-guard-0295",
    reason = reason or "pinned-no-ammo",
    updated_tick = tick,
    expires_tick = tick + TECH_PRIESTS_0295_NO_AMMO_RETRY_TICKS
  }
  pair.active_task = task
  pair.active_task_0285 = task
  return true
end

-- Guard no-ammo combat before the old proxy priming path can start supply/scavenge
-- requests every few ticks.  If not pinned, acquisition is still allowed but much
-- more throttled.
TECH_PRIESTS_0295_PRE_PRIME_PROXY_ATTACK = tech_priests_0293_prime_proxy_attack
function tech_priests_0293_prime_proxy_attack(pair, target, reason)
  if not (tech_priests_0295_valid_pair(pair) and target and target.valid) then return false end
  local tick = tech_priests_0295_now()
  local has_ammo = tech_priests_0295_station_or_proxy_has_ammo(pair)
  if not has_ammo then
    if tech_priests_0295_enemy_in_body_contact(pair, TECH_PRIESTS_0295_PINNED_RADIUS) then
      return tech_priests_0295_mark_pinned_no_ammo(pair, target, "enemy-contact-no-ammo")
    end
    -- Not pinned: ask for ammo/supply, but no more rapid-fire acquisition spam.
    if tick >= (pair.next_ammo_supply_retry_tick_0295 or 0) then
      pair.next_ammo_supply_retry_tick_0295 = tick + TECH_PRIESTS_0295_SUPPLY_RETRY_TICKS
      if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "ammo", target) end) end
    end
    pair.mode = "missing-ammo-supplies"
    pair.target = target
    pair.combat_target = target
    pair.last_combat_fail_0295 = "no-compatible-ammo-throttled"
    pair.last_combat_fail_tick_0295 = tick
    pair.next_combat_service_tick_0293 = tick + TECH_PRIESTS_0295_NO_AMMO_RETRY_TICKS
    return true
  end
  return TECH_PRIESTS_0295_PRE_PRIME_PROXY_ATTACK and TECH_PRIESTS_0295_PRE_PRIME_PROXY_ATTACK(pair, target, reason) or false
end
tech_priests_0292_force_combat_tick = tech_priests_0293_force_combat_tick

-- Wrap retreat so pinned priests do not try to flee/path while physically swarmed.
-- This is especially important when ammo-empty, because pathing + acquisition +
-- combat reassignment was the dangerous triangle.
TECH_PRIESTS_0295_PRE_RETREAT_TICK = tech_priests_0294_retreat_tick
function tech_priests_0294_retreat_tick(pair, reason)
  if not tech_priests_0295_valid_pair(pair) then return false end
  local tick = tech_priests_0295_now()
  if tech_priests_0295_enemy_in_body_contact(pair, TECH_PRIESTS_0295_PINNED_RADIUS) then
    pair.last_retreat_blocked_0295 = "enemy-contact-pinned"
    pair.last_retreat_blocked_tick_0295 = tick
    pair.next_retreat_service_tick_0294 = tick + TECH_PRIESTS_0295_RETREAT_RECHECK_TICKS
    if not tech_priests_0295_station_or_proxy_has_ammo(pair) then
      tech_priests_0295_mark_pinned_no_ammo(pair, pair.combat_target or pair.target, "retreat-blocked-no-ammo")
      return true
    end
    return false
  end
  return TECH_PRIESTS_0295_PRE_RETREAT_TICK and TECH_PRIESTS_0295_PRE_RETREAT_TICK(pair, reason) or false
end

-- Final tick wrapper: detect the pinned/no-ammo case before the 0.1.294 wrapper
-- can oscillate between retreat and combat.  Otherwise defer to the existing stack.
TECH_PRIESTS_0295_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  if tech_priests_0295_valid_pair(pair)
     and tech_priests_0295_enemy_in_body_contact(pair, TECH_PRIESTS_0295_PINNED_RADIUS)
     and not tech_priests_0295_station_or_proxy_has_ammo(pair) then
    local target = pair.combat_target or pair.target
    if not (target and target.valid) and tech_priests_0293_select_target then
      local ok, found = pcall(function() return tech_priests_0293_select_target(pair) end)
      if ok then target = found end
    end
    tech_priests_0295_mark_pinned_no_ammo(pair, target, "tick-pinned-no-ammo")
    return true
  end
  if TECH_PRIESTS_0295_PRE_TICK_PAIR then return TECH_PRIESTS_0295_PRE_TICK_PAIR(pair) end
  return false
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-swarm-0295", "Tech Priests: inspect pinned/no-ammo swarm guard state for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = nil
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests 0.1.295] Select a Cogitator Station or Tech-Priest first."); return end
      player.print("[Tech Priests 0.1.295] mode=" .. tostring(pair.mode or "nil") ..
        " contact=" .. tostring(tech_priests_0295_enemy_in_body_contact(pair, TECH_PRIESTS_0295_PINNED_RADIUS)) ..
        " ammo=" .. tostring(tech_priests_0295_station_or_proxy_has_ammo(pair)) ..
        " combat_fail=" .. tostring(pair.last_combat_fail_0295 or pair.last_combat_fail_0293 or "none") ..
        " retreat_block=" .. tostring(pair.last_retreat_blocked_0295 or pair.last_retreat_blocked_0294 or "none"))
    end)
  end)
end

tech_priests_0295_log("0.1.295 retreat/no-ammo swarm crash guard loaded")


-- -----------------------------------------------------------------------------
-- 0.1.296 invalid request item crash guard
-- -----------------------------------------------------------------------------
-- Runtime testing of 0.1.295 found a clean crash in the station request/status
-- icon pass: pair.logistic_requested_item could contain the supply KIND "repair"
-- instead of the real Factorio item name "repair-pack".  LuaInventory
-- get_item_count() raises on unknown item names, so all status/request checks now
-- normalize symbolic supply names before touching inventories.

TECH_PRIESTS_0296_ITEM_ALIASES = {
  repair = "repair-pack",
  repairs = "repair-pack",
  ["repair-pack"] = "repair-pack",
  ammo = "firearm-magazine",
  ammunition = "firearm-magazine",
  magazine = "firearm-magazine",
  ["firearm-magazine"] = "firearm-magazine"
}

function tech_priests_0296_item_exists(name)
  if not (name and name ~= "") then return false end
  if prototypes then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok and proto then return true end
  end
  if tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) then return true end
  return false
end

function tech_priests_0296_normalize_item_name(name, context_kind)
  if not (name and name ~= "") then
    if context_kind == "repair" then return "repair-pack" end
    if context_kind == "ammo" then return "firearm-magazine" end
    return nil
  end
  name = tostring(name)
  local mapped = TECH_PRIESTS_0296_ITEM_ALIASES[name] or name
  if tech_priests_0296_item_exists(mapped) then return mapped end
  if context_kind == "repair" and tech_priests_0296_item_exists("repair-pack") then return "repair-pack" end
  if context_kind == "ammo" and tech_priests_0296_item_exists("firearm-magazine") then return "firearm-magazine" end
  return nil
end

function tech_priests_0296_safe_inventory_count(inventory, name, context_kind)
  if not inventory then return 0 end
  local item_name = tech_priests_0296_normalize_item_name(name, context_kind)
  if not item_name then return 0 end
  local ok, count = pcall(function() return inventory.get_item_count(item_name) end)
  if ok and count then return count end
  return 0
end

function tech_priests_0296_sanitize_request(request)
  if not request then return nil end
  if request.kind == "repair" then
    request.candidates = { { name = "repair-pack", count = 1, score = 1 } }
    request.item_name = "repair-pack"
    return request
  end
  if request.kind == "ammo" and request.item_name then
    request.item_name = tech_priests_0296_normalize_item_name(request.item_name, "ammo") or nil
  end
  if request.candidates then
    local cleaned = {}
    for _, candidate in pairs(request.candidates) do
      local normalized = candidate and tech_priests_0296_normalize_item_name(candidate.name, request.kind)
      if normalized then
        candidate.name = normalized
        cleaned[#cleaned + 1] = candidate
      end
    end
    request.candidates = cleaned
  end
  return request
end

function tech_priests_0296_sanitize_pair_supply_state(pair)
  if not pair then return end
  if pair.active_supply_request then tech_priests_0296_sanitize_request(pair.active_supply_request) end
  if pair.inventory_scan and pair.inventory_scan.request then tech_priests_0296_sanitize_request(pair.inventory_scan.request) end
  if pair.scavenge and pair.scavenge.request then tech_priests_0296_sanitize_request(pair.scavenge.request) end
  if pair.emergency_craft and pair.emergency_craft.request then tech_priests_0296_sanitize_request(pair.emergency_craft.request) end

  if pair.logistic_requested_item then
    local context = pair.active_supply_request and pair.active_supply_request.kind or nil
    local normalized = tech_priests_0296_normalize_item_name(pair.logistic_requested_item, context)
    if normalized then
      pair.logistic_requested_item = normalized
    else
      pair.last_invalid_logistic_requested_item_0296 = tostring(pair.logistic_requested_item)
      pair.logistic_requested_item = nil
    end
  end
end

TECH_PRIESTS_0296_PRE_GET_INVENTORY_SCAN_ITEM_NAME = get_inventory_scan_item_name
function get_inventory_scan_item_name(scan)
  if scan and scan.request then
    tech_priests_0296_sanitize_request(scan.request)
    if scan.request.item_name then
      local normalized = tech_priests_0296_normalize_item_name(scan.request.item_name, scan.request.kind)
      if normalized then return normalized end
    end
    if scan.request.candidates and scan.request.candidates[1] and scan.request.candidates[1].name then
      local normalized = tech_priests_0296_normalize_item_name(scan.request.candidates[1].name, scan.request.kind)
      if normalized then return normalized end
    end
    if scan.request.kind == "repair" then return "repair-pack" end
    if scan.request.kind == "ammo" then return "firearm-magazine" end
  end
  local ok, result = pcall(function()
    return TECH_PRIESTS_0296_PRE_GET_INVENTORY_SCAN_ITEM_NAME and TECH_PRIESTS_0296_PRE_GET_INVENTORY_SCAN_ITEM_NAME(scan) or ""
  end)
  if ok then
    return tech_priests_0296_normalize_item_name(result, scan and scan.request and scan.request.kind) or tostring(result or "")
  end
  return ""
end

TECH_PRIESTS_0296_PRE_BUILD_SUPPLY_REQUEST = build_supply_request
function build_supply_request(pair, kind, target)
  if kind == "repair-pack" then kind = "repair" end
  local request = TECH_PRIESTS_0296_PRE_BUILD_SUPPLY_REQUEST and TECH_PRIESTS_0296_PRE_BUILD_SUPPLY_REQUEST(pair, kind, target) or nil
  return tech_priests_0296_sanitize_request(request)
end

TECH_PRIESTS_0296_PRE_MAYBE_START_SUPPLY_SCAVENGE = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  if kind == "repair-pack" then kind = "repair" end
  if pair then tech_priests_0296_sanitize_pair_supply_state(pair) end
  return TECH_PRIESTS_0296_PRE_MAYBE_START_SUPPLY_SCAVENGE and TECH_PRIESTS_0296_PRE_MAYBE_START_SUPPLY_SCAVENGE(pair, kind, target) or false
end

-- Override the 0.1.173 helper with a fully guarded version. This is the exact
-- function in the crash stack, so do not let unknown symbolic names reach
-- LuaInventory.get_item_count().
function tech_priests_station_inventory_has_requested_supply_0173(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  tech_priests_0296_sanitize_pair_supply_state(pair)
  request = tech_priests_0296_sanitize_request(request)
  local inventory = get_station_inventory and get_station_inventory(pair.station) or nil
  if not inventory then return nil end

  if request.kind == "ammo" then
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack and stack.valid_for_read and is_ammo_item and is_ammo_item(stack.name) then
        return stack.name
      end
    end
    return nil
  end

  for _, candidate in pairs(request.candidates or {}) do
    local name = tech_priests_0296_normalize_item_name(candidate and candidate.name, request.kind)
    if name and tech_priests_0296_safe_inventory_count(inventory, name, request.kind) > 0 then
      return name
    end
  end

  local fallback = tech_priests_0296_normalize_item_name(pair.logistic_requested_item, request.kind)
  if fallback and tech_priests_0296_safe_inventory_count(inventory, fallback, request.kind) > 0 then
    pair.logistic_requested_item = fallback
    return fallback
  end

  return nil
end

TECH_PRIESTS_0296_PRE_SHOULD_SHOW_STATION_REQUEST_ICON = should_show_station_request_icon
function should_show_station_request_icon(pair)
  tech_priests_0296_sanitize_pair_supply_state(pair)
  local ok, result = pcall(function()
    return TECH_PRIESTS_0296_PRE_SHOULD_SHOW_STATION_REQUEST_ICON and TECH_PRIESTS_0296_PRE_SHOULD_SHOW_STATION_REQUEST_ICON(pair) or false
  end)
  if ok then return result end
  if pair then pair.last_station_request_icon_error_0296 = tostring(result) end
  return false
end

TECH_PRIESTS_0296_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  tech_priests_0296_sanitize_pair_supply_state(pair)
  if TECH_PRIESTS_0296_PRE_TICK_PAIR then return TECH_PRIESTS_0296_PRE_TICK_PAIR(pair) end
  return false
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-supply-0296", "Tech Priests: inspect/sanitize current supply request item names for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = nil
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests 0.1.296] Select a Cogitator Station or Tech-Priest first."); return end
      tech_priests_0296_sanitize_pair_supply_state(pair)
      player.print("[Tech Priests 0.1.296] requested=" .. tostring(pair.logistic_requested_item or "nil") ..
        " invalid_before=" .. tostring(pair.last_invalid_logistic_requested_item_0296 or "none") ..
        " request_kind=" .. tostring(pair.active_supply_request and pair.active_supply_request.kind or "nil") ..
        " mode=" .. tostring(pair.mode or "nil"))
    end)
  end)
end

if tech_priests_0264_log then
  pcall(function() tech_priests_0264_log("[0.1.296] invalid symbolic supply item crash guard loaded", true) end)
elseif log then
  log("[Tech-Priests 0.1.296] invalid symbolic supply item crash guard loaded")
end


-- -----------------------------------------------------------------------------
-- 0.1.297 Tech-Priest Sub-Equipment Armor Mirror
-- -----------------------------------------------------------------------------
-- Runtime prototypes cannot be rewritten per-force after data stage, so this
-- module keeps a force-local "sub equipment" armor profile and applies it as
-- runtime damage mitigation to Tech-Priest entities.  It refreshes when priests
-- are placed, when technology completes, and when configuration changes.

TECH_PRIESTS_ARMOR_PROFILE_VERSION_0297 = "0.1.297"
-- 0.1.300: tolerate older/newer naming tables. The canonical base table is PRIEST_TO_STATION.
function tech_priests_0300_priest_name_map()
  return rawget(_G, "PRIEST_TO_STATION_NAME") or rawget(_G, "PRIEST_TO_STATION") or {}
end
TECH_PRIESTS_ARMOR_FALLBACK_RECIPES_0297 = {
  ["light-armor"] = true,
  ["heavy-armor"] = true,
  ["modular-armor"] = true,
  ["power-armor"] = true,
  ["power-armor-mk2"] = true
}

function tech_priests_0297_get_item_prototypes()
  if tech_priests_prototype_table_0440 then return tech_priests_prototype_table_0440("item") end
  if prototypes and prototypes.item then return prototypes.item end
  return nil
end

function tech_priests_0297_is_priest_entity(entity)
  if not (entity and entity.valid and entity.name) then return false end
  if is_priest then
    local ok, result = pcall(is_priest, entity)
    if ok and result then return true end
  end
  local map = tech_priests_0300_priest_name_map()
  return map and map[entity.name] ~= nil
end

function tech_priests_0297_resistance_type_name(entry_key, entry)
  if type(entry) == "table" then
    return entry.type or entry.name or entry.damage_type or entry_key
  end
  return entry_key
end

function tech_priests_0297_resistance_decrease(entry)
  if type(entry) ~= "table" then return 0 end
  local value = entry.decrease or entry.flat or entry.damage_decrease or 0
  return tonumber(value) or 0
end

function tech_priests_0297_resistance_percent(entry)
  if type(entry) ~= "table" then return 0 end
  local value = entry.percent or entry.resistance or entry.damage_percent or 0
  return tonumber(value) or 0
end

function tech_priests_0297_collect_resistances(proto)
  local resistances = {}
  local raw = nil
  local ok, result = pcall(function() return proto and proto.resistances end)
  if ok then raw = result end
  if not raw then return resistances end

  local ok_pairs = pcall(function()
    for key, entry in pairs(raw) do
      local damage_type = tech_priests_0297_resistance_type_name(key, entry)
      if damage_type then
        resistances[damage_type] = {
          decrease = tech_priests_0297_resistance_decrease(entry),
          percent = tech_priests_0297_resistance_percent(entry)
        }
      end
    end
  end)
  if not ok_pairs then return {} end
  return resistances
end

function tech_priests_0297_resistance_score(resistances)
  local score = 0
  for damage_type, resistance in pairs(resistances or {}) do
    local weight = 1
    if damage_type == "physical" then weight = 3 end
    if damage_type == "acid" or damage_type == "fire" or damage_type == "poison" then weight = 2 end
    score = score + weight * ((tonumber(resistance.decrease) or 0) * 10 + (tonumber(resistance.percent) or 0))
  end
  return score
end

function tech_priests_0297_recipe_outputs_item(recipe, item_name)
  if not (recipe and item_name) then return false end
  if recipe.name == item_name then return true end
  local products = nil
  local ok = pcall(function() products = recipe.products end)
  if not ok or not products then return false end
  local found = false
  pcall(function()
    for _, product in pairs(products) do
      if product and product.name == item_name then found = true; break end
    end
  end)
  return found
end

function tech_priests_0297_force_can_use_armor(force, armor_name)
  if not (force and force.valid and armor_name) then return false end
  -- Vanilla light armor is effectively a starting item in most games; allow it
  -- when no gated recipe can be found so the mirror has a sane floor.
  if armor_name == "light-armor" then return true end
  local recipes = force.recipes
  if not recipes then return false end

  local direct = recipes[armor_name]
  if direct and direct.enabled then return true end

  -- Some mods unlock armor through a recipe whose name does not exactly match
  -- the item.  Scan enabled recipes and match their product list.
  local found = false
  pcall(function()
    for _, recipe in pairs(recipes) do
      if recipe and recipe.enabled and tech_priests_0297_recipe_outputs_item(recipe, armor_name) then
        found = true
      end
    end
  end)
  return found
end

function tech_priests_0297_find_best_force_armor_profile(force)
  local item_prototypes = tech_priests_0297_get_item_prototypes()
  if not item_prototypes then return nil end
  local best = nil
  local ok = pcall(function()
    for item_name, proto in pairs(item_prototypes) do
      local item_type = nil
      pcall(function() item_type = proto.type end)
      if item_type == "armor" and tech_priests_0297_force_can_use_armor(force, item_name) then
        local resistances = tech_priests_0297_collect_resistances(proto)
        local score = tech_priests_0297_resistance_score(resistances)
        if score > 0 and ((not best) or score > best.score) then
          best = {
            name = item_name,
            score = score,
            resistances = resistances
          }
        end
      end
    end
  end)
  if not ok then return best end
  return best
end

function tech_priests_0297_refresh_force_armor_profile(force, reason)
  if not (force and force.valid) then return nil end
  ensure_storage()
  storage.tech_priests.armor_profiles_0297 = storage.tech_priests.armor_profiles_0297 or {}
  local profile = tech_priests_0297_find_best_force_armor_profile(force)
  if profile then
    profile.force = force.name
    profile.reason = reason or "refresh"
    profile.tick = game and game.tick or 0
    storage.tech_priests.armor_profiles_0297[force.name] = profile
  else
    storage.tech_priests.armor_profiles_0297[force.name] = nil
  end
  return profile
end

function tech_priests_0297_get_force_armor_profile(force)
  if not (force and force.valid) then return nil end
  ensure_storage()
  storage.tech_priests.armor_profiles_0297 = storage.tech_priests.armor_profiles_0297 or {}
  local profile = storage.tech_priests.armor_profiles_0297[force.name]
  if not profile then profile = tech_priests_0297_refresh_force_armor_profile(force, "lazy") end
  return profile
end

function tech_priests_0297_apply_profile_to_pair(pair, reason)
  if not (pair and pair.priest and pair.priest.valid) then return end
  local profile = tech_priests_0297_get_force_armor_profile(pair.priest.force)
  pair.sub_equipment_armor_profile_0297 = profile and {
    name = profile.name,
    score = profile.score,
    reason = reason or "pair-refresh",
    tick = game and game.tick or 0
  } or nil
end

function tech_priests_0297_apply_force_armor_to_existing_priests(force, reason)
  if not (force and force.valid) then return end
  tech_priests_0297_refresh_force_armor_profile(force, reason or "force-refresh")
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair and pair.priest and pair.priest.valid and pair.priest.force == force then
      tech_priests_0297_apply_profile_to_pair(pair, reason or "force-refresh")
    end
  end
end

function tech_priests_0297_get_pair_for_priest(entity)
  if not tech_priests_0297_is_priest_entity(entity) then return nil end
  if find_pair_for_entity then return find_pair_for_entity(entity) end
  if storage and storage.tech_priests and storage.tech_priests.station_by_priest then
    local station = storage.tech_priests.station_by_priest[entity.unit_number]
    if station and station.valid and storage.tech_priests.pairs_by_station then
      return storage.tech_priests.pairs_by_station[station.unit_number]
    end
  end
  return nil
end

function tech_priests_0297_event_damage_type(event)
  local name = nil
  pcall(function()
    if event and event.damage_type then name = event.damage_type.name or event.damage_type end
  end)
  return name or "physical"
end

function tech_priests_0297_mitigate_damage(event)
  local entity = event and event.entity
  if not tech_priests_0297_is_priest_entity(entity) then return end
  if not (entity.health and entity.health > 0) then return end
  local profile = tech_priests_0297_get_force_armor_profile(entity.force)
  if not (profile and profile.resistances) then return end
  local damage_type = tech_priests_0297_event_damage_type(event)
  local resistance = profile.resistances[damage_type] or profile.resistances["physical"]
  if not resistance then return end

  local final_damage = tonumber(event.final_damage_amount or event.original_damage_amount or 0) or 0
  if final_damage <= 0 then return end
  local decrease = math.max(0, tonumber(resistance.decrease) or 0)
  local percent = math.max(0, math.min(100, tonumber(resistance.percent) or 0))
  local after_decrease = math.max(0, final_damage - decrease)
  local after_percent = after_decrease * (1 - (percent / 100))
  local prevented = final_damage - after_percent
  if prevented <= 0 then return end

  local new_health = entity.health + prevented
  local max_health = nil
  pcall(function() max_health = entity.prototype and entity.prototype.max_health end)
  if max_health then new_health = math.min(max_health, new_health) end
  entity.health = new_health

  local pair = tech_priests_0297_get_pair_for_priest(entity)
  if pair then
    pair.last_armor_mitigation_0297 = {
      tick = game.tick,
      armor = profile.name,
      damage_type = damage_type,
      prevented = prevented,
      final_damage = final_damage,
      health = entity.health
    }
    tech_priests_0297_apply_profile_to_pair(pair, "damage-mitigation")
  end
end

TECH_PRIESTS_0297_PRE_ON_BUILT = on_built
function on_built(event)
  if TECH_PRIESTS_0297_PRE_ON_BUILT then TECH_PRIESTS_0297_PRE_ON_BUILT(event) end
  local entity = event and (event.entity or event.created_entity or event.destination) or nil
  if not entity then return end
  if tech_priests_0297_is_priest_entity(entity) then
    local pair = tech_priests_0297_get_pair_for_priest(entity)
    if pair then tech_priests_0297_apply_profile_to_pair(pair, "priest-built") end
  elseif is_station and is_station(entity) then
    local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
    if pair then tech_priests_0297_apply_profile_to_pair(pair, "station-built") end
  end
end

-- Re-register the build handlers so the late 0.1.297 on_built wrapper is the one Factorio calls.
if script and defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, on_built)
end

TECH_PRIESTS_0297_PRE_RESEARCH_HANDLER = nil
-- The original research handler is anonymous, so install a second narrow handler
-- only for this armor-mirror module.  Factorio allows one handler per event per
-- mod, so we cannot stack it directly; instead, hook through script.on_event by
-- wrapping the existing research work in a local delegate is not possible here.
-- Use on_technology_effects_reset and a low cadence refresh as safety, and also
-- a direct research handler replacement that preserves the old handler by
-- calling the known functions it needed.  This is deliberately conservative.

function tech_priests_0297_on_research_finished(event)
  -- Preserve the legacy research side effects from the original anonymous handler.
  if event and event.research and event.research.force then
    ensure_storage()
    storage.tech_priests.last_researched_technology_by_force = storage.tech_priests.last_researched_technology_by_force or {}
    storage.tech_priests.last_researched_technology_by_force[event.research.force.name] = event.research.name
    if RANGE_TECH_BONUSES and RANGE_TECH_BONUSES[event.research.name] then
      for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
        if pair.station and pair.station.valid and pair.station.force == event.research.force and refresh_pair_radius then refresh_pair_radius(pair) end
      end
    end
    if event.research.name == TECH_PRIEST_BELT_IMMUNITY_TECH and upgrade_force_priests_to_current_mobility then
      upgrade_force_priests_to_current_mobility(event.research.force)
    end
    if event.research.name == COGITATOR_LOGISTIC_REQUISITION_TECH then
      for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
        if pair.station and pair.station.valid and pair.station.force == event.research.force and ensure_pair_logistic_caches then
          ensure_pair_logistic_caches(pair)
        end
      end
    end
    if is_sanctification_baseline_technology and is_sanctification_baseline_technology(event.research.name) then
      local previous_base_max = get_base_sanctification_max(event.research.force) - ((MAX_SANCTIFICATION_TECH_BONUSES and MAX_SANCTIFICATION_TECH_BONUSES[event.research.name]) or 0)
      if apply_sanctification_research_to_existing_machines then
        apply_sanctification_research_to_existing_machines(event.research.force, previous_base_max, get_base_sanctification_max(event.research.force))
      end
    end
    tech_priests_0297_apply_force_armor_to_existing_priests(event.research.force, "research:" .. tostring(event.research.name))
  end
end

if script and defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, tech_priests_0297_on_research_finished)
  if defines.events.on_technology_effects_reset then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_technology_effects_reset, function(event)
      if event and event.force then tech_priests_0297_apply_force_armor_to_existing_priests(event.force, "technology-effects-reset") end
    end)
  end
  if defines.events.on_entity_damaged then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0297_mitigate_damage)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(811, function()
  ensure_storage()
  if not (game and game.forces) then return end
  for _, force in pairs(game.forces) do
    tech_priests_0297_refresh_force_armor_profile(force, "periodic")
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-armor-0297", "Tech Priests: inspect/apply mirrored armor sub-equipment profile for selected priest/station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = selected and find_pair_for_entity and find_pair_for_entity(selected) or nil
      if not pair then player.print("[Tech Priests 0.1.297] Select a Cogitator Station or Tech-Priest first."); return end
      local force = (pair.priest and pair.priest.valid and pair.priest.force) or (pair.station and pair.station.valid and pair.station.force)
      local profile = tech_priests_0297_refresh_force_armor_profile(force, "debug-command")
      tech_priests_0297_apply_profile_to_pair(pair, "debug-command")
      local last = pair.last_armor_mitigation_0297
      player.print("[Tech Priests 0.1.297] armor=" .. tostring(profile and profile.name or "none") ..
        " score=" .. tostring(profile and profile.score or 0) ..
        " pair_profile=" .. tostring(pair.sub_equipment_armor_profile_0297 and pair.sub_equipment_armor_profile_0297.name or "nil") ..
        " last_prevented=" .. tostring(last and last.prevented or "nil") ..
        " last_type=" .. tostring(last and last.damage_type or "nil"))
    end)
  end)
end

if tech_priests_0264_log then
  pcall(function() tech_priests_0264_log("[0.1.297] armor sub-equipment resistance mirror loaded", true) end)
elseif log then
  log("[Tech-Priests 0.1.297] armor sub-equipment resistance mirror loaded")
end


-- ============================================================================
-- 0.1.299 Tech-Priest Re-Imprinting / Respawn Module
-- ============================================================================
-- Priests no longer destroy their Cogitator Station when killed.  Death enters a
-- station-bound re-imprinting cooldown, with a visible countdown over the
-- station and command-overview status lines.  The actual priest entity is only
-- re-created when the timer expires; station death still cleans up the whole
-- pair through the legacy removal path.

TECH_PRIESTS_REIMPRINT_TECH_0298 = {
  "tech-priest-reimprinting-acceleration-1",
  "tech-priest-reimprinting-acceleration-2",
  "tech-priest-reimprinting-acceleration-3"
}
TECH_PRIESTS_REIMPRINT_BASE_TICKS_0298 = 60 * 90
TECH_PRIESTS_REIMPRINT_STEP_TICKS_0298 = 60 * 20
TECH_PRIESTS_REIMPRINT_MIN_TICKS_0298 = 60 * 30

function tech_priests_0298_is_reimprint_tech(name)
  for _, tech in pairs(TECH_PRIESTS_REIMPRINT_TECH_0298) do
    if name == tech then return true end
  end
  return false
end

function tech_priests_0298_reimprint_upgrade_count(force)
  if not (force and force.valid and force.technologies) then return 0 end
  local n = 0
  for _, tech_name in pairs(TECH_PRIESTS_REIMPRINT_TECH_0298) do
    local tech = force.technologies[tech_name]
    if tech and tech.researched then n = n + 1 end
  end
  return n
end

function tech_priests_0298_reimprint_duration(force)
  local ticks = TECH_PRIESTS_REIMPRINT_BASE_TICKS_0298 - tech_priests_0298_reimprint_upgrade_count(force) * TECH_PRIESTS_REIMPRINT_STEP_TICKS_0298
  if ticks < TECH_PRIESTS_REIMPRINT_MIN_TICKS_0298 then ticks = TECH_PRIESTS_REIMPRINT_MIN_TICKS_0298 end
  return ticks
end

function tech_priests_0298_format_time(ticks)
  ticks = math.max(0, math.floor(tonumber(ticks) or 0))
  local sec = math.ceil(ticks / 60)
  local m = math.floor(sec / 60)
  local s = sec % 60
  if m > 0 then return tostring(m) .. ":" .. string.format("%02d", s) end
  return tostring(s) .. "s"
end

function tech_priests_0298_destroy_render(obj)
  tech_priests_0309_destroy_render_object(obj)
end

function tech_priests_0298_clear_reimprint_render(pair)
  if pair and pair.reimprint_0298 and pair.reimprint_0298.render then
    tech_priests_0298_destroy_render(pair.reimprint_0298.render)
    pair.reimprint_0298.render = nil
  end
end

function tech_priests_0298_update_reimprint_render(pair)
  if not (pair and pair.reimprint_0298 and pair.station and pair.station.valid and game and game.tick) then return end
  local rem = math.max(0, (pair.reimprint_0298.finish_tick or game.tick) - game.tick)
  local text = "[img=utility/warning_icon] RE-IMPRINTING " .. tech_priests_0298_format_time(rem)
  if pair.reimprint_0298.render then tech_priests_0298_destroy_render(pair.reimprint_0298.render) end
  if rendering and rendering.draw_text then
    local ok, obj = pcall(function()
      return rendering.draw_text({
        text = text,
        surface = pair.station.surface,
        target = pair.station,
        target_offset = {0, -3.1},
        color = {r = 1.0, g = 0.25, b = 0.18, a = 0.96},
        scale = 0.85,
        alignment = "center",
        vertical_alignment = "middle",
        time_to_live = 75,
        players = nil,
        forces = { pair.station.force },
        draw_on_ground = false
      })
    end)
    if ok then pair.reimprint_0298.render = obj end
  end
end

function tech_priests_0298_pair_is_reimprinting(pair)
  return pair and pair.reimprint_0298 and pair.reimprint_0298.active and game and game.tick and game.tick < (pair.reimprint_0298.finish_tick or 0)
end

function tech_priests_0298_reimprint_status(pair)
  if not pair then return nil end
  if tech_priests_0298_pair_is_reimprinting(pair) then
    return "Re-imprinting · " .. tech_priests_0298_format_time((pair.reimprint_0298.finish_tick or game.tick) - game.tick)
  end
  if pair.reimprint_0298 and pair.reimprint_0298.active then return "Re-imprinting ready" end
  return nil
end

function tech_priests_0298_enter_reimprint(pair, dead_priest, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  ensure_storage()
  local force = pair.station.force
  local duration = tech_priests_0298_reimprint_duration(force)
  local old_unit = pair.priest_unit or (dead_priest and dead_priest.valid and dead_priest.unit_number)
  if old_unit and storage.tech_priests and storage.tech_priests.station_by_priest then
    storage.tech_priests.station_by_priest[old_unit] = nil
  end
  if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.destroy({ raise_destroy = false }) end) end
  pair.proxy = nil
  pair.proxy_expires = 0
  pair.priest = nil
  pair.priest_unit = nil
  pair.mode = "re-imprinting"
  pair.target = nil
  pair.combat_target = nil
  pair.active_task = nil
  pair.active_task_0285 = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.retreat_0294 = nil
  pair.pinned_no_ammo_0295 = nil
  pair.reimprint_0298 = pair.reimprint_0298 or {}
  pair.reimprint_0298.active = true
  pair.reimprint_0298.started_tick = game.tick
  pair.reimprint_0298.finish_tick = game.tick + duration
  pair.reimprint_0298.duration = duration
  pair.reimprint_0298.reason = reason or "priest-death"
  pair.reimprint_0298.station_unit = pair.station_unit or pair.station.unit_number
  pair.next_allowed_priest_respawn_tick = pair.reimprint_0298.finish_tick
  pair.deployment_queued = nil
  if pair.station.force and pair.station.force.valid then
    pair.station.force.print({"", "[Tech Priests] ", tech_priests_station_name_0189 and tech_priests_station_name_0189(pair) or "Cogitator Station", " has begun Tech-Priest re-imprinting. Return of the red-robed inconvenience in ", tech_priests_0298_format_time(duration), "."})
  end
  tech_priests_0298_update_reimprint_render(pair)
  return true
end

-- Replaces the old linked-death doctrine only for actual priest death.  Station
-- death, mining, script deletion, and station cleanup still use the existing
-- removal chain.
TECH_PRIESTS_PRE_REIMPRINT_ON_REMOVED_0298 = tech_priests_on_removed_trace_wrapper_0202 or on_removed
function tech_priests_on_removed_reimprint_wrapper_0298(event)
  local entity = event and event.entity
  if event and event.name == defines.events.on_entity_died and entity and entity.valid and is_priest and is_priest(entity) then
    local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
    if pair and pair.station and pair.station.valid then
      if spawn_priest_smoke_for_entity then pcall(function() spawn_priest_smoke_for_entity(entity, true) end) end
      tech_priests_0298_enter_reimprint(pair, entity, "death")
      return
    end
  end
  if TECH_PRIESTS_PRE_REIMPRINT_ON_REMOVED_0298 then return TECH_PRIESTS_PRE_REIMPRINT_ON_REMOVED_0298(event) end
end
if script and defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, tech_priests_on_removed_reimprint_wrapper_0298)
end
