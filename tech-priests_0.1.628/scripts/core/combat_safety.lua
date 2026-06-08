-- scripts/core/combat_safety.lua
-- Tech Priests 0.1.322
-- Canonical friendly-fire safety gate for all combat/attack target selection.
-- This module is intentionally defensive: same-force, allied, and cease-fire
-- entities are never legal combat targets. Neutral entities remain legal only
-- for explicit direct-mining/resource work, not for combat.

local M = {}

local function now()
  return game and game.tick or 0
end

local function entity_name(entity)
  if not entity then return "nil" end
  local ok, name = pcall(function() return entity.name end)
  return ok and tostring(name) or tostring(entity)
end

local function force_name(force)
  if not force then return "nil" end
  local ok, name = pcall(function() return force.name end)
  return ok and tostring(name) or tostring(force)
end

local function safe_field(obj, key)
  if not obj then return nil end
  local ok, value = pcall(function() return obj[key] end)
  if ok then return value end
  return nil
end

local function get_force(owner)
  if not owner then return nil end
  local force = safe_field(owner, "force")
  if force then return force end
  if type(owner) == "table" then
    local priest = owner.priest
    if priest and priest.valid then
      force = safe_field(priest, "force")
      if force then return force end
    end
    local station = owner.station
    if station and station.valid then
      force = safe_field(station, "force")
      if force then return force end
    end
  end
  return nil
end

local function is_asteroid(entity)
  if not (entity and entity.valid) then return false end
  local ok_type, typ = pcall(function() return entity.type end)
  if ok_type and typ == "asteroid" then return true end
  local ok_name, name = pcall(function() return entity.name end)
  if not ok_name or not name then return false end
  if string.find(name, "%-asteroid%-chunk") then return false end
  return string.match(name, "^small%-.*%-asteroid$")
      or string.match(name, "^medium%-.*%-asteroid$")
      or string.match(name, "^big%-.*%-asteroid$")
      or string.match(name, "^huge%-.*%-asteroid$")
end

local function force_get_friend(a, b)
  if not (a and b) then return false end
  local ok, value = pcall(function()
    if a.get_friend then return a.get_friend(b) end
    return false
  end)
  return ok and value or false
end

local function force_get_cease_fire(a, b)
  if not (a and b) then return false end
  local ok, value = pcall(function()
    if a.get_cease_fire then return a.get_cease_fire(b) end
    return false
  end)
  return ok and value or false
end

local function force_is_enemy(a, b)
  if not (a and b) then return false end
  local hostile = false
  local ok = pcall(function()
    if a.is_enemy then hostile = a.is_enemy(b) end
  end)
  if ok and hostile then return true end
  ok = pcall(function()
    if b.is_enemy then hostile = b.is_enemy(a) end
  end)
  return ok and hostile or false
end

function M.is_same_or_friendly_force(owner_or_force, target)
  if not (target and target.valid) then return false end
  local owner_force = get_force(owner_or_force) or owner_or_force
  local target_force = target.force
  if not (owner_force and target_force) then return false end
  if owner_force == target_force then return true end
  if force_get_friend(owner_force, target_force) or force_get_friend(target_force, owner_force) then return true end
  if force_get_cease_fire(owner_force, target_force) or force_get_cease_fire(target_force, owner_force) then return true end
  return false
end

function M.is_valid_hostile_target(owner_or_force, target)
  if not (target and target.valid) then return false end
  if is_asteroid(target) then return true end

  local owner_force = get_force(owner_or_force) or owner_or_force
  local target_force = target.force
  if not (owner_force and target_force) then return false end
  if owner_force == target_force then return false end
  if target_force.name == "neutral" then return false end
  if force_get_friend(owner_force, target_force) or force_get_friend(target_force, owner_force) then return false end
  if force_get_cease_fire(owner_force, target_force) or force_get_cease_fire(target_force, owner_force) then return false end
  if force_is_enemy(owner_force, target_force) then return true end

  -- Fallback for modded hostile forces that do not expose is_enemy cleanly.
  -- Still refuses player/same/friend/cease-fire/neutral above.
  return target_force ~= owner_force
end

function M.is_safe_direct_mining_target(owner_or_force, target)
  if not (target and target.valid) then return false end
  local typ = target.type
  if typ == "resource" then return true end
  if typ == "tree" then return true end
  if typ == "simple-entity" then return not M.is_same_or_friendly_force(owner_or_force, target) end
  if typ == "rock" then return not M.is_same_or_friendly_force(owner_or_force, target) end
  -- No direct-mining laser may damage same-force machines, characters, cars,
  -- spidertrons, turrets, assemblers, or anything allied/cease-fire.
  return M.is_valid_hostile_target(owner_or_force, target)
end

local function log_block(pair, msg)
  if not (game and game.tick) then return end
  if pair then
    if game.tick < (pair.next_friendly_fire_block_log_0322 or 0) then return end
    pair.next_friendly_fire_block_log_0322 = game.tick + 120
  end
  if log then log("[Tech-Priests 0.1.322 combat safety] " .. msg) end
end

function M.clear_invalid_combat_state(pair, reason)
  if not pair then return false end
  local force_owner = pair.priest or pair.station or pair
  local changed = false
  if pair.combat_target and pair.combat_target.valid and not M.is_valid_hostile_target(force_owner, pair.combat_target) then
    log_block(pair, "cleared invalid combat_target=" .. entity_name(pair.combat_target) .. " reason=" .. tostring(reason or "friendly-fire-gate"))
    pair.combat_target = nil
    changed = true
  end
  if pair.target and pair.target.valid and (pair.mode == "defending" or pair.mode == "moving-to-combat" or pair.mode == "combat" or pair.task_kind == "combat") and not M.is_valid_hostile_target(force_owner, pair.target) then
    log_block(pair, "cleared invalid combat pair.target=" .. entity_name(pair.target) .. " reason=" .. tostring(reason or "friendly-fire-gate"))
    pair.target = nil
    changed = true
  end
  if pair.proxy and pair.proxy.valid and changed then
    pcall(function() pair.proxy.shooting_target = nil end)
  end
  return changed
end

function M.install()
  -- Filter the public enemy query so every later wrapper that calls it inherits
  -- the same same-force/allied/neutral rejection behavior.
  TECH_PRIESTS_0322_PRE_FIND_ENEMY_TARGET = find_enemy_target
  function find_enemy_target(station, radius, priest)
    local target = nil
    if TECH_PRIESTS_0322_PRE_FIND_ENEMY_TARGET then
      local ok, result = pcall(function() return TECH_PRIESTS_0322_PRE_FIND_ENEMY_TARGET(station, radius, priest) end)
      if ok then target = result end
    end
    local owner = priest or station
    if target and target.valid and M.is_valid_hostile_target(owner, target) then return target end
    if target and target.valid then
      log_block(nil, "rejected find_enemy_target result target=" .. entity_name(target) .. " target_force=" .. force_name(target.force) .. " owner_force=" .. force_name(get_force(owner)))
    end
    return nil
  end

  TECH_PRIESTS_0322_PRE_ENEMY_INSIDE_STATION_RADIUS = enemy_inside_station_radius
  function enemy_inside_station_radius(station, enemy, radius)
    if not (station and station.valid and enemy and enemy.valid) then return false end
    if not M.is_valid_hostile_target(station, enemy) then return false end
    if TECH_PRIESTS_0322_PRE_ENEMY_INSIDE_STATION_RADIUS then
      local ok, result = pcall(function() return TECH_PRIESTS_0322_PRE_ENEMY_INSIDE_STATION_RADIUS(station, enemy, radius) end)
      return ok and result or false
    end
    local dx = enemy.position.x - station.position.x
    local dy = enemy.position.y - station.position.y
    return dx * dx + dy * dy <= (radius or 0) * (radius or 0)
  end

  if tech_priests_0248_is_enemy_of_station then
    TECH_PRIESTS_0322_PRE_0248_IS_ENEMY_OF_STATION = tech_priests_0248_is_enemy_of_station
    function tech_priests_0248_is_enemy_of_station(station, entity)
      if not M.is_valid_hostile_target(station, entity) then return false end
      local ok, result = pcall(function() return TECH_PRIESTS_0322_PRE_0248_IS_ENEMY_OF_STATION(station, entity) end)
      return ok and result or false
    end
  end

  TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND = issue_priest_command
  function issue_priest_command(priest, command)
    if command and command.type == defines.command.attack then
      local target = command.target
      if not M.is_valid_hostile_target(priest, target) then
        log_block(nil, "blocked attack command priest=" .. entity_name(priest) .. " target=" .. entity_name(target) .. " target_force=" .. force_name(target and target.force) .. " priest_force=" .. force_name(priest and priest.force))
        if priest and priest.valid then
          if tech_priests_route_ground_command_0429 then
            pcall(function() tech_priests_route_ground_command_0429(priest, { type = defines.command.stop }, "friendly-fire-blocked-attack-0322", { priority = 100, ttl = 60 }) end)
          elseif priest.commandable and priest.commandable.valid then
            pcall(function() priest.commandable.set_command({ type = defines.command.stop }) end)
          end
        end
        return false
      end
    end
    return TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND and TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND(priest, command) or false
  end

  if handle_combat then
    TECH_PRIESTS_0322_PRE_HANDLE_COMBAT = handle_combat
    function handle_combat(pair)
      M.clear_invalid_combat_state(pair, "before-handle-combat")
      local ok, result = pcall(function() return TECH_PRIESTS_0322_PRE_HANDLE_COMBAT(pair) end)
      M.clear_invalid_combat_state(pair, "after-handle-combat")
      return ok and result or false
    end
  end

  if tech_priests_0292_prime_proxy_attack then
    TECH_PRIESTS_0322_PRE_0292_PRIME_PROXY_ATTACK = tech_priests_0292_prime_proxy_attack
    function tech_priests_0292_prime_proxy_attack(pair, target, reason)
      if not M.is_valid_hostile_target(pair and (pair.priest or pair.station), target) then
        M.clear_invalid_combat_state(pair, "0292-prime-rejected")
        return false
      end
      return TECH_PRIESTS_0322_PRE_0292_PRIME_PROXY_ATTACK(pair, target, reason)
    end
  end

  if tech_priests_0293_prime_proxy_attack then
    TECH_PRIESTS_0322_PRE_0293_PRIME_PROXY_ATTACK = tech_priests_0293_prime_proxy_attack
    function tech_priests_0293_prime_proxy_attack(pair, target, reason)
      if not M.is_valid_hostile_target(pair and (pair.priest or pair.station), target) then
        M.clear_invalid_combat_state(pair, "0293-prime-rejected")
        return false
      end
      return TECH_PRIESTS_0322_PRE_0293_PRIME_PROXY_ATTACK(pair, target, reason)
    end
  end

  if tech_priests_0312_fire_laser then
    TECH_PRIESTS_0322_PRE_0312_FIRE_LASER = tech_priests_0312_fire_laser
    function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
      local reason_text = tostring(reason or "")
      local direct = string.find(reason_text, "direct%-mining") or string.find(reason_text, "direct%-dirt") or string.find(reason_text, "mining")
      if direct then
        if not M.is_safe_direct_mining_target(priest, target) then
          log_block(nil, "blocked direct laser against protected target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
          return false
        end
      else
        if not M.is_valid_hostile_target(priest, target) then
          log_block(nil, "blocked combat laser against non-hostile target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
          return false
        end
      end
      return TECH_PRIESTS_0322_PRE_0312_FIRE_LASER(priest, target, damage, reason, color)
    end
  end

  if tech_priests_0315_service_direct_current then
    TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT = tech_priests_0315_service_direct_current
    function tech_priests_0315_service_direct_current(pair, task)
      local cur = task and task.current or nil
      if cur and cur.entity and cur.entity.valid and not M.is_safe_direct_mining_target(pair and (pair.priest or pair.station), cur.entity) then
        log_block(pair, "cancelled direct mining current against protected target=" .. entity_name(cur.entity) .. " force=" .. force_name(cur.entity.force))
        task.current = nil
        if pair then pair.mining_lock_0315 = nil end
        return false
      end
      return TECH_PRIESTS_0322_PRE_0315_SERVICE_DIRECT_CURRENT(pair, task)
    end
  end

  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-combat-safety-0322", "Tech Priests: inspect the 0.1.322 friendly-fire combat target gate.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        local pair = nil
        if selected_pair_for_player then
          local ok, found = pcall(function() return selected_pair_for_player(player) end)
          if ok then pair = found end
        end
        if not pair and find_pair_for_entity and player.selected then
          local ok, found = pcall(function() return find_pair_for_entity(player.selected) end)
          if ok then pair = found end
        end
        if not pair then player.print("[Tech Priests 0.1.322] select a Cogitator Station or Tech-Priest."); return end
        M.clear_invalid_combat_state(pair, "manual-inspect")
        local target = pair.combat_target or pair.target
        player.print("[Tech Priests 0.1.322] combat safety loaded. target=" .. entity_name(target) .. " hostile=" .. tostring(M.is_valid_hostile_target(pair.priest or pair.station, target)) .. " mode=" .. tostring(pair.mode))
      end)
    end)
  end

  if log then log("[Tech-Priests 0.1.322] friendly-fire combat target safety gate installed") end
end

return M
