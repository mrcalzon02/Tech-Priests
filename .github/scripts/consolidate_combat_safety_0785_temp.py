#!/usr/bin/env python3
"""Temporary guarded transformation for canonical combat-safety ownership."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PART3_PATH = ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua"
PART13_PATH = ROOT / "tech-priests_src/scripts/generated/control_legacy_part_013.lua"
PART14_PATH = ROOT / "tech-priests_src/scripts/generated/control_legacy_part_014.lua"
SAFETY_PATH = ROOT / "tech-priests_src/scripts/core/combat_safety.lua"
HISTORY_PATH = ROOT / "docs/DEVELOPMENT_HISTORY.md"
LUA_PATHS = sorted((ROOT / "tech-priests_src").rglob("*.lua"))


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one exact source block, found {count}")
    return text.replace(old, new, 1)


all_before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
for needle, expected in {
    "function find_enemy_target(station, radius, priest)": 3,
    "function enemy_inside_station_radius(station, enemy, radius)": 2,
    "function tech_priests_0248_is_enemy_of_station(station, entity)": 2,
    "function handle_combat(pair)": 2,
}.items():
    actual = all_before.count(needle)
    if actual != expected:
        raise SystemExit(f"pre-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")

part3 = PART3_PATH.read_text(encoding="utf-8")
old_base_find = '''function find_enemy_target(station, radius, priest)
  local surface = station.surface
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local candidates = {}
  local enemies = surface.find_entities_filtered({ area = area, force = "enemy" })
  for _, entity in pairs(enemies) do
    table.insert(candidates, entity)
  end

  -- Space Age asteroids are not ordinary biter-style enemy creatures. Add an
  -- explicit asteroid pass so Cogitator Station defense can see incoming rocks
  -- the way platform turrets do, then let the existing proxy-turret combat path
  -- prove whether the selected asteroid can actually be engaged.
  for _, entity in pairs(find_space_asteroid_targets(surface, area)) do
    table.insert(candidates, entity)
  end

  local best = nil
  local best_score = nil

  for _, entity in pairs(candidates) do
    local health = get_entity_health_or_nil(entity)
    if entity.valid and (is_asteroid_threat_entity(entity) or (health and health > 0)) then
      local score, station_distance_sq = score_threat_to_station_and_priest(entity, position, priest)
      if station_distance_sq <= radius * radius then
        if not best_score or score < best_score then
          best = entity
          best_score = score
        end
      end
    end
  end

  return best
end'''
part3 = replace_once(
    part3,
    old_base_find,
    '''-- 0.1.674-dev / 0785: the original live scan is merged into the final 0248
-- cache-aware find_enemy_target owner in fragment 014.
TECH_PRIESTS_BASE_FIND_ENEMY_TARGET_0248_MERGED = true''',
    "fragment 003 base enemy query",
)

old_radius = '''function enemy_inside_station_radius(station, enemy, radius)
  if not (station and station.valid and enemy and enemy.valid) then return false end
  local dx = enemy.position.x - station.position.x
  local dy = enemy.position.y - station.position.y
  return dx * dx + dy * dy <= radius * radius
end'''
new_radius = '''function enemy_inside_station_radius(station, enemy, radius)
  if not (station and station.valid and enemy and enemy.valid) then return false end
  if tech_priests_0322_is_valid_hostile_target then
    local ok, hostile = pcall(function() return tech_priests_0322_is_valid_hostile_target(station, enemy) end)
    if not (ok and hostile) then return false end
  end
  local dx = enemy.position.x - station.position.x
  local dy = enemy.position.y - station.position.y
  return dx * dx + dy * dy <= radius * radius
end'''
part3 = replace_once(part3, old_radius, new_radius, "fragment 003 station-radius predicate")

old_combat = '''function handle_combat(pair)
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius(pair)
  if not (station and station.valid and priest and priest.valid) then return false end

  local target = pair.combat_target
  if not enemy_inside_station_radius(station, target, radius) then
    target = find_enemy_target(station, radius, priest)
    pair.combat_target = target
  end

  if not target then
    deactivate_proxy(pair)
    return false
  end
  combat_debug(pair, "enemy target acquired: " .. target.name)

  local proxy = ensure_proxy(pair)
  if not proxy then return false end

  if tech_priests_align_proxy_to_priest_0430 then tech_priests_align_proxy_to_priest_0430(pair, proxy, priest, "combat proxy attached to visible priest") else pcall(function() proxy.teleport(priest.position) end) end
  pcall(function() proxy.active = true end)
  pcall(function() proxy.operable = false end)

  if not load_proxy_from_station(pair) then
    deactivate_proxy(pair)
    pair.mode = "missing-ammo-supplies"
    pair.target = target
    maybe_start_supply_scavenge(pair, "ammo", target)
    return true
  end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local distance_sq = dx * dx + dy * dy

  local target_ok = pcall(function() proxy.shooting_target = target end)
  if target_ok then
    combat_debug(pair, "proxy assigned target while attached to priest")
  else
    combat_debug(pair, "proxy exists and is loaded, but shooting_target assignment failed")
  end
  describe_proxy_state(pair, proxy, target, "combat diagnostic")

  if distance_sq > COMBAT_FIRE_RANGE * COMBAT_FIRE_RANGE then
    issue_priest_command(priest, {
      type = defines.command.go_to_location,
      destination = target.position,
      radius = COMBAT_APPROACH_RADIUS,
      distraction = defines.distraction.by_enemy
    })
    pair.mode = "moving-to-combat"
    pair.target = target
    pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
    return true
  end

  issue_priest_command(priest, {
    type = defines.command.attack,
    target = target,
    distraction = defines.distraction.none
  })

  pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
  pair.mode = "defending"
  pair.target = target
  return true
end'''
new_combat = '''function handle_combat(pair)
  if tech_priests_0322_clear_invalid_combat_state then
    pcall(function() tech_priests_0322_clear_invalid_combat_state(pair, "before-handle-combat") end)
  end
  local function finish_0785(result)
    if tech_priests_0322_clear_invalid_combat_state then
      pcall(function() tech_priests_0322_clear_invalid_combat_state(pair, "after-handle-combat") end)
    end
    return result
  end

  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius(pair)
  if not (station and station.valid and priest and priest.valid) then return finish_0785(false) end

  local target = pair.combat_target
  if not enemy_inside_station_radius(station, target, radius) then
    target = find_enemy_target(station, radius, priest)
    pair.combat_target = target
  end

  if not target then
    deactivate_proxy(pair)
    return finish_0785(false)
  end
  combat_debug(pair, "enemy target acquired: " .. target.name)

  local proxy = ensure_proxy(pair)
  if not proxy then return finish_0785(false) end

  if tech_priests_align_proxy_to_priest_0430 then tech_priests_align_proxy_to_priest_0430(pair, proxy, priest, "combat proxy attached to visible priest") else pcall(function() proxy.teleport(priest.position) end) end
  pcall(function() proxy.active = true end)
  pcall(function() proxy.operable = false end)

  if not load_proxy_from_station(pair) then
    deactivate_proxy(pair)
    pair.mode = "missing-ammo-supplies"
    pair.target = target
    maybe_start_supply_scavenge(pair, "ammo", target)
    return finish_0785(true)
  end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local distance_sq = dx * dx + dy * dy

  local target_ok = pcall(function() proxy.shooting_target = target end)
  if target_ok then
    combat_debug(pair, "proxy assigned target while attached to priest")
  else
    combat_debug(pair, "proxy exists and is loaded, but shooting_target assignment failed")
  end
  describe_proxy_state(pair, proxy, target, "combat diagnostic")

  if distance_sq > COMBAT_FIRE_RANGE * COMBAT_FIRE_RANGE then
    issue_priest_command(priest, {
      type = defines.command.go_to_location,
      destination = target.position,
      radius = COMBAT_APPROACH_RADIUS,
      distraction = defines.distraction.by_enemy
    })
    pair.mode = "moving-to-combat"
    pair.target = target
    pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
    return finish_0785(true)
  end

  issue_priest_command(priest, {
    type = defines.command.attack,
    target = target,
    distraction = defines.distraction.none
  })

  pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
  pair.mode = "defending"
  pair.target = target
  return finish_0785(true)
end'''
part3 = replace_once(part3, old_combat, new_combat, "fragment 003 combat service")
PART3_PATH.write_text(part3, encoding="utf-8")

part13 = PART13_PATH.read_text(encoding="utf-8")
old_station_enemy = '''function tech_priests_0248_is_enemy_of_station(station, entity)
  if not (station and station.valid and entity and entity.valid) then return false end
  if is_asteroid_threat_entity and is_asteroid_threat_entity(entity) then return true end
  if not entity.force then return false end
  if station.force and station.force.is_enemy then
    local ok, value = pcall(function() return station.force.is_enemy(entity.force) end)
    if ok then return not not value end
  end
  return entity.force.name == "enemy" or (station.force and entity.force.name ~= station.force.name and entity.force.name ~= "neutral")
end'''
new_station_enemy = '''function tech_priests_0248_is_enemy_of_station(station, entity)
  if not (station and station.valid and entity and entity.valid) then return false end
  if tech_priests_0322_is_valid_hostile_target then
    local ok, hostile = pcall(function() return tech_priests_0322_is_valid_hostile_target(station, entity) end)
    if ok then return not not hostile end
  end
  if is_asteroid_threat_entity and is_asteroid_threat_entity(entity) then return true end
  if not entity.force then return false end
  if station.force and station.force.is_enemy then
    local ok, value = pcall(function() return station.force.is_enemy(entity.force) end)
    if ok then return not not value end
  end
  return entity.force.name == "enemy" or (station.force and entity.force.name ~= station.force.name and entity.force.name ~= "neutral")
end'''
part13 = replace_once(part13, old_station_enemy, new_station_enemy, "fragment 013 station enemy predicate")
PART13_PATH.write_text(part13, encoding="utf-8")

part14 = PART14_PATH.read_text(encoding="utf-8")
old_cached_find = '''TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248 = find_enemy_target
function find_enemy_target(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "hostiles", function(entity)
      return tech_priests_0248_is_enemy_of_station(station, entity) and enemy_inside_station_radius and enemy_inside_station_radius(station, entity, radius or (pair.sweep_0248 and pair.sweep_0248.radius) or 20)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end'''
new_cached_find = '''-- 0.1.674-dev / 0785: canonical cache-aware plus live enemy query.
TECH_PRIESTS_FIND_ENEMY_TARGET_PREDECESSOR_RETIRED = true
function find_enemy_target(station, radius, priest)
  if not (station and station.valid) then return nil end
  radius = radius or 20
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "hostiles", function(entity)
      return tech_priests_0248_is_enemy_of_station(station, entity)
        and enemy_inside_station_radius
        and enemy_inside_station_radius(station, entity, radius or (pair.sweep_0248 and pair.sweep_0248.radius) or 20)
    end)
    if cached then return cached end
  end

  local surface = station.surface
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius },
  }
  local candidates = {}
  local enemies = surface.find_entities_filtered({ area = area, force = "enemy" })
  for _, entity in pairs(enemies or {}) do table.insert(candidates, entity) end
  for _, entity in pairs(find_space_asteroid_targets(surface, area) or {}) do table.insert(candidates, entity) end

  local best = nil
  local best_score = nil
  for _, entity in pairs(candidates) do
    local health = get_entity_health_or_nil(entity)
    local hostile = tech_priests_0248_is_enemy_of_station(station, entity)
    if hostile and entity.valid and (is_asteroid_threat_entity(entity) or (health and health > 0)) then
      local score, station_distance_sq = score_threat_to_station_and_priest(entity, position, priest)
      if station_distance_sq <= radius * radius and (not best_score or score < best_score) then
        best = entity
        best_score = score
      end
    end
  end
  return best
end'''
part14 = replace_once(part14, old_cached_find, new_cached_find, "fragment 014 final enemy query")
PART14_PATH.write_text(part14, encoding="utf-8")

safety = SAFETY_PATH.read_text(encoding="utf-8")
old_wrappers = '''  -- Filter the public enemy query so every later wrapper that calls it inherits
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


  if handle_combat then
    TECH_PRIESTS_0322_PRE_HANDLE_COMBAT = handle_combat
    function handle_combat(pair)
      M.clear_invalid_combat_state(pair, "before-handle-combat")
      local ok, result = pcall(function() return TECH_PRIESTS_0322_PRE_HANDLE_COMBAT(pair) end)
      M.clear_invalid_combat_state(pair, "after-handle-combat")
      return ok and result or false
    end
  end'''
new_exports = '''  -- 0.1.674-dev / 0785: target selection and combat execution call these
  -- predicates directly; this module no longer replaces generated functions.
  tech_priests_0322_is_valid_hostile_target = M.is_valid_hostile_target
  tech_priests_0322_clear_invalid_combat_state = M.clear_invalid_combat_state
  TECH_PRIESTS_0322_TARGET_COMBAT_WRAPPERS_RETIRED = true'''
safety = replace_once(safety, old_wrappers, new_exports, "combat safety target/combat wrappers")
SAFETY_PATH.write_text(safety, encoding="utf-8")

all_after = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in LUA_PATHS)
for needle, expected in {
    "function find_enemy_target(station, radius, priest)": 1,
    "function enemy_inside_station_radius(station, enemy, radius)": 1,
    "function tech_priests_0248_is_enemy_of_station(station, entity)": 1,
    "function handle_combat(pair)": 1,
    "tech_priests_0322_is_valid_hostile_target = M.is_valid_hostile_target": 1,
    "tech_priests_0322_clear_invalid_combat_state = M.clear_invalid_combat_state": 1,
}.items():
    actual = all_after.count(needle)
    if actual != expected:
        raise SystemExit(f"post-patch ownership mismatch: {needle!r} expected {expected}, found {actual}")
for forbidden in (
    "TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248",
    "TECH_PRIESTS_0322_PRE_FIND_ENEMY_TARGET",
    "TECH_PRIESTS_0322_PRE_ENEMY_INSIDE_STATION_RADIUS",
    "TECH_PRIESTS_0322_PRE_0248_IS_ENEMY_OF_STATION",
    "TECH_PRIESTS_0322_PRE_HANDLE_COMBAT",
):
    if forbidden in all_after:
        raise SystemExit(f"post-patch forbidden wrapper remains: {forbidden}")
for required in (
    "TECH_PRIESTS_BASE_FIND_ENEMY_TARGET_0248_MERGED = true",
    "TECH_PRIESTS_FIND_ENEMY_TARGET_PREDECESSOR_RETIRED = true",
    "TECH_PRIESTS_0322_TARGET_COMBAT_WRAPPERS_RETIRED = true",
    "finish_0785(false)",
    "finish_0785(true)",
    "tech_priests_0322_is_valid_hostile_target(station, enemy)",
    "tech_priests_0322_is_valid_hostile_target(station, entity)",
):
    if required not in all_after:
        raise SystemExit(f"post-patch required contract missing: {required}")

history = HISTORY_PATH.read_text(encoding="utf-8")
heading = "## 2026-07-21 — Milestone 0785: Canonical Combat Safety Predicate Ownership"
if heading not in history:
    history += f'''\n\n{heading}\n\nConsolidated the remaining combat-safety target and combat wrappers into their authoritative source functions. Fragment 014 now owns one cache-aware plus live enemy query; fragment 003 owns one station-radius predicate and one combat service with direct before/after invalid-state cleanup hooks; fragment 013 owns one station-enemy predicate. combat_safety.lua now exports named hostile-target and invalid-state predicates instead of redefining find_enemy_target, enemy_inside_station_radius, tech_priests_0248_is_enemy_of_station, or handle_combat. The 0248 predecessor capture and all 0322 target/combat wrappers are explicitly retired. Static Source validation does not constitute Factorio runtime proof.\n'''
    HISTORY_PATH.write_text(history, encoding="utf-8")

print("0785 transformation complete: one enemy query, radius predicate, station-enemy predicate, and combat service")
