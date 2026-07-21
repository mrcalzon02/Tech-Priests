-- scripts/core/combat_safety.lua
-- Tech Priests 0.1.674-dev
-- Canonical friendly-fire safety gate for all combat/attack target selection.
-- This module is intentionally defensive: same-force, allied, and cease-fire
-- entities are never legal combat targets. Neutral entities remain legal only
-- for explicit direct-mining/resource work, not for combat.

local M = {
  version = "0.1.674-dev",
  command_routing_observer_only = true,
  proxy_prime_observer_only = true,
}

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
  -- 0.1.674-dev / 0785: target selection and combat execution call these
  -- predicates directly; this module no longer replaces generated functions.
  tech_priests_0322_is_valid_hostile_target = M.is_valid_hostile_target
  tech_priests_0322_clear_invalid_combat_state = M.clear_invalid_combat_state
  TECH_PRIESTS_0322_TARGET_COMBAT_WRAPPERS_RETIRED = true


  tech_priests_0322_is_laser_target_allowed = function(priest, target, reason)
    local reason_text = tostring(reason or "")
    local direct = string.find(reason_text, "direct%-mining") or string.find(reason_text, "direct%-dirt") or string.find(reason_text, "mining")
    if direct then
      if M.is_safe_direct_mining_target(priest, target) then return true end
      log_block(nil, "blocked direct laser against protected target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
      return false
    end
    if M.is_valid_hostile_target(priest, target) then return true end
    log_block(nil, "blocked combat laser against non-hostile target=" .. entity_name(target) .. " force=" .. force_name(target and target.force) .. " reason=" .. reason_text)
    return false
  end

  tech_priests_0322_validate_direct_mining_current = function(pair, task)
    local cur = task and task.current or nil
    if not (cur and cur.entity and cur.entity.valid) then return true end
    if cur.entity.type == "item-entity" then return true end
    if M.is_safe_direct_mining_target(pair and (pair.priest or pair.station), cur.entity) then return true end
    log_block(pair, "cancelled direct mining current against protected target=" .. entity_name(cur.entity) .. " force=" .. force_name(cur.entity.force))
    task.current = nil
    if pair then pair.mining_lock_0315 = nil end
    return false
  end

  TECH_PRIESTS_0322_BEAM_SERVICE_WRAPPERS_RETIRED = true

  TECH_PRIESTS_0322_DEBUG_COMMAND_RETIRED = true

  if log then log("[Tech-Priests 0.1.674-dev] observer-only friendly-fire predicates installed; command routing remains movement-controller-owned") end
  return true
end

return M
