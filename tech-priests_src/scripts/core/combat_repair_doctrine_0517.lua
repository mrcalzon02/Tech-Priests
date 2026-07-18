-- scripts/core/combat_repair_doctrine_0517.lua
-- Tech Priests 0.1.674-dev recovery.
-- Dispatcher-owned tactical selector for repairing defended walls under pressure.
-- This module owns cover evaluation and cluster reservations only; all movement,
-- repair-pack custody, health mutation, and queue completion belong to 0516.

local M = {
  version = "0.1.674-dev",
  storage_key = "combat_repair_doctrine_0517",
  search_radius = 26,
  wall_enemy_radius = 9,
  wall_turret_radius = 8,
  priest_cover_radius = 12,
  personal_danger_radius_sq = 16,
  cluster_size = 3,
  cluster_reservation_ttl = 150,
  target_cooldown_ticks = 90,
  min_wall_missing_ratio = 0.04,
  critical_wall_missing_ratio = 0.35,
  max_candidates = 120,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function lower(value) return string.lower(tostring(value or "")) end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function distance(a, b) return math.sqrt(dist_sq(a, b)) end
local function result(fields)
  fields = fields or {}
  return {
    processed = tonumber(fields.processed) or 1,
    acted = tonumber(fields.acted) or 0,
    blocked = tonumber(fields.blocked) or 0,
    waiting = tonumber(fields.waiting) or 0,
    failed = tonumber(fields.failed) or 0,
    exhausted = fields.exhausted == true,
    detail = safe(fields.detail or ""),
  }
end
local function normalize(primary, secondary)
  if type(primary) == "table" then
    return result({
      processed = primary.processed,
      acted = primary.acted,
      blocked = primary.blocked,
      waiting = primary.waiting,
      failed = primary.failed,
      exhausted = primary.exhausted,
      detail = primary.detail or primary.reason or secondary,
    })
  end
  if primary == true then return result({ acted = 1, detail = secondary or "acted" }) end
  if type(primary) == "number" then return result({ acted = primary, detail = secondary }) end
  local detail = safe(secondary or primary or "")
  if lower(detail):find("block", 1, true) then return result({ blocked = 1, detail = detail }) end
  if lower(detail):find("wait", 1, true) or lower(detail):find("walk", 1, true) then
    return result({ waiting = 1, detail = detail })
  end
  if lower(detail):find("fail", 1, true) or lower(detail):find("error", 1, true) then
    return result({ failed = 1, detail = detail })
  end
  return result({ detail = detail })
end

local function repair_executor()
  local loaded = rawget(_G, "TechPriestsRepairExecutor0516")
  if loaded then return loaded end
  local ok, module = pcall(require, "scripts.core.repair_executor_0516")
  return ok and module or nil
end
local function read_root()
  local state = storage and storage.tech_priests and storage.tech_priests[M.storage_key]
  return state or {
    enabled = true,
    require_cover = true,
    reserve_clusters = true,
    cluster_reservations = {},
    target_cooldowns = {},
    stats = {},
    recent = {},
  }
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    require_cover = true,
    reserve_clusters = true,
    stats = {},
    recent = {},
    cluster_reservations = {},
    target_cooldowns = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.dispatcher_owned == nil then state.dispatcher_owned = true end
  if state.require_cover == nil then state.require_cover = true end
  if state.reserve_clusters == nil then state.reserve_clusters = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cluster_reservations = state.cluster_reservations or {}
  state.target_cooldowns = state.target_cooldowns or {}
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = station_unit(pair),
    priest = priest_unit(pair),
    action = safe(action),
    detail = safe(detail),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function is_wallish(entity)
  if not valid(entity) then return false end
  local kind = lower(entity.type)
  local name = lower(entity.name)
  return kind == "wall" or kind == "gate"
    or name:find("wall", 1, true) ~= nil
    or name:find("gate", 1, true) ~= nil
end
local function missing_health(entity)
  if not (valid(entity) and entity.health and entity.max_health) then return 0 end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end
local function missing_ratio(entity)
  local maximum = valid(entity) and tonumber(entity.max_health) or 0
  if not maximum or maximum <= 0 then return 0 end
  return missing_health(entity) / maximum
end
local function force_is_enemy(force, other)
  if not (force and other) or force == other or safe(force.name) == safe(other.name) then return false end
  if safe(other.name) == "neutral" then return false end
  if type(force.is_enemy) == "function" then
    local ok, enemy = pcall(function() return force.is_enemy(other) end)
    if ok then return enemy == true end
  end
  if type(force.get_friend) == "function" then
    local ok, friend = pcall(function() return force.get_friend(other) end)
    if ok and friend == true then return false end
  end
  if type(force.get_cease_fire) == "function" then
    local ok, cease = pcall(function() return force.get_cease_fire(other) end)
    if ok and cease == true then return false end
  end
  return true
end
local function enemyish(pair, entity)
  if not (valid_pair(pair) and valid(entity) and entity.force and pair.station.force) then return false end
  if not force_is_enemy(pair.station.force, entity.force) then return false end
  local kind = lower(entity.type)
  return kind == "unit" or kind == "unit-spawner" or kind == "turret"
    or kind == "spider-unit" or kind:find("biter", 1, true) ~= nil
    or kind:find("spitter", 1, true) ~= nil
end
local function area(position, radius)
  return {
    { (position.x or 0) - radius, (position.y or 0) - radius },
    { (position.x or 0) + radius, (position.y or 0) + radius },
  }
end
local function entities(surface, position, radius, force)
  if not (surface and position) then return {} end
  local ok, found = pcall(function()
    local spec = { area = area(position, radius), limit = M.max_candidates }
    if force then spec.force = force end
    return surface.find_entities_filtered(spec)
  end)
  return ok and found or {}
end
local function enemy_context(pair, position, radius)
  local count, nearest = 0, nil
  for _, entity in ipairs(entities(pair.station.surface, position, radius, nil)) do
    if enemyish(pair, entity) then
      count = count + 1
      local current = distance(position, entity.position)
      nearest = nearest and math.min(nearest, current) or current
    end
  end
  return count, nearest
end
local function blocked_status(entity)
  if not valid(entity) then return true end
  local status
  pcall(function() status = entity.status end)
  local values = defines and defines.entity_status
  if not (values and status) then return false end
  for _, name in ipairs({
    "disabled", "disabled_by_control_behavior", "no_power", "no_fuel",
    "no_input_fluid", "not_connected_to_rail", "marked_for_deconstruction",
  }) do
    if values[name] and status == values[name] then return true end
  end
  return false
end
local function ammo_loaded(turret)
  if not (valid(turret) and defines and defines.inventory and defines.inventory.turret_ammo) then return false end
  local ok, inventory = pcall(function() return turret.get_inventory(defines.inventory.turret_ammo) end)
  if not (ok and inventory and inventory.valid) then return false end
  local ok_empty, empty = pcall(function() return inventory.is_empty() end)
  if ok_empty then return empty == false end
  local ok_contents, contents = pcall(function() return inventory.get_contents() end)
  if ok_contents and contents then
    for _, count in pairs(contents) do if (tonumber(count) or 0) > 0 then return true end end
  end
  return false
end
local function turret_ready(pair, turret)
  if not (valid_pair(pair) and valid(turret) and turret.force == pair.station.force) then return false, "not-allied" end
  if lower(turret.type):find("turret", 1, true) == nil then return false, "not-turret" end
  if blocked_status(turret) then return false, "disabled-status" end
  local active
  pcall(function() active = turret.active end)
  if active == false then return false, "inactive" end
  local shooting
  pcall(function() shooting = turret.shooting_target end)
  if valid(shooting) and enemyish(pair, shooting) then return true, "shooting" end
  if ammo_loaded(turret) then return true, "ammo-loaded" end
  local energy = 0
  pcall(function() energy = tonumber(turret.energy) or 0 end)
  if energy > 1000 then return true, "energized" end
  local fluidbox
  pcall(function() fluidbox = turret.fluidbox end)
  if fluidbox then
    local ok_length, length = pcall(function() return #fluidbox end)
    if ok_length then
      for index = 1, length do
        local fluid
        pcall(function() fluid = fluidbox[index] end)
        if fluid and (tonumber(fluid.amount) or 0) > 0 then return true, "fluid-ready" end
      end
    end
  end
  return false, "not-ready"
end
local function turret_cover(pair, wall)
  local ready, total, labels = 0, 0, {}
  for _, entity in ipairs(entities(wall.surface, wall.position, M.wall_turret_radius, pair.station.force)) do
    if valid(entity) and lower(entity.type):find("turret", 1, true) then
      total = total + 1
      local ok, why = turret_ready(pair, entity)
      if ok then
        ready = ready + 1
        labels[#labels + 1] = safe(entity.name) .. ":" .. safe(why)
      end
    end
  end
  return ready > 0, ready, total, table.concat(labels, ",")
end
local function proxy_ready(pair)
  local ammo = rawget(_G, "TechPriestsProxyAmmoHardener0649")
  if ammo and type(ammo.proxy_has_ammo) == "function" then
    local ok, loaded = pcall(ammo.proxy_has_ammo, pair)
    if ok then return loaded == true end
  end
  local helper = rawget(_G, "tech_priests_0293_proxy_has_ammo")
  if type(helper) == "function" then
    local ok, loaded = pcall(helper, pair)
    if ok then return loaded == true end
  end
  return false
end
local function priest_cover(pair, wall)
  local ready = 0
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid_pair(other)
      and other.priest.surface == wall.surface
      and other.station.force == pair.station.force
      and dist_sq(other.priest.position, wall.position) <= M.priest_cover_radius * M.priest_cover_radius
    then
      local action = other.canonical_action_0744
      local family = lower(action and action.family)
      local engaged = family == "combat" or family == "combat-repair"
        or valid(other.combat_target)
      if engaged and proxy_ready(other) then ready = ready + 1 end
    end
  end
  return ready > 0, ready
end
local function station_has_pack(pair)
  local helper = rawget(_G, "station_has_repair_pack")
  if type(helper) == "function" then
    local ok, available = pcall(helper, pair.station)
    if ok then return available == true end
  end
  local steward = rawget(_G, "tech_priests_inventory_steward_sources_for_pair")
  if type(steward) == "function" then
    local ok, sources = pcall(steward, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do
        local inventory = source and (source.inv or source.inventory)
        if inventory and inventory.valid then
          local ok_count, count = pcall(function() return inventory.get_item_count("repair-pack") end)
          if ok_count and (tonumber(count) or 0) > 0 then return true end
        end
      end
    end
  end
  return false
end

local function cluster_key(entity)
  if not valid(entity) then return nil end
  local position = entity.position or { x = 0, y = 0 }
  local size = M.cluster_size
  local x = math.floor(((position.x or 0) / size) + 0.5) * size
  local y = math.floor(((position.y or 0) / size) + 0.5) * size
  return tostring(entity.surface.index) .. ":" .. tostring(entity.force and entity.force.name or "?")
    .. ":" .. tostring(x) .. ":" .. tostring(y)
end
local function target_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  return tostring(entity.name) .. "@" .. string.format("%.1f,%.1f", position.x or 0, position.y or 0)
end
local function cleanup_reservations()
  local root = M.root()
  local tick = now()
  for key, reservation in pairs(root.cluster_reservations) do
    if not reservation or (tonumber(reservation.until_tick) or 0) < tick then
      root.cluster_reservations[key] = nil
    end
  end
  for key, until_tick in pairs(root.target_cooldowns) do
    if (tonumber(until_tick) or 0) < tick then root.target_cooldowns[key] = nil end
  end
end
local function reserve_cluster(pair, target)
  cleanup_reservations()
  local root = M.root()
  if root.reserve_clusters == false then return true, "disabled" end
  local key = cluster_key(target)
  if not key then return false, "no-cluster-key" end
  local existing = root.cluster_reservations[key]
  if existing and safe(existing.station) ~= safe(station_unit(pair)) then
    return false, "cluster-reserved"
  end
  root.cluster_reservations[key] = {
    station = station_unit(pair),
    priest = priest_unit(pair),
    target = target_key(target),
    until_tick = now() + M.cluster_reservation_ttl,
  }
  return true, key
end
local function release_cluster(pair, target, stored_key)
  local root = M.root()
  local key = stored_key or cluster_key(target)
  local reservation = key and root.cluster_reservations[key]
  if reservation and safe(reservation.station) == safe(station_unit(pair)) then
    root.cluster_reservations[key] = nil
    return true
  end
  return false
end
local function eligible_wall(pair, wall)
  if not (valid_pair(pair) and valid(wall) and wall.force == pair.station.force and is_wallish(wall)) then
    return false, "not-allied-wall"
  end
  if missing_health(wall) <= 0.01 then return false, "not-damaged" end
  if missing_ratio(wall) < M.min_wall_missing_ratio then return false, "minor-damage" end
  if not station_has_pack(pair) then return false, "no-repair-pack" end
  local radius = math.max(8, tonumber(pair.radius or pair.base_radius) or 32)
  if dist_sq(pair.station.position, wall.position) > radius * radius then return false, "outside-radius" end
  local state = read_root()
  local cooldown = state.target_cooldowns and state.target_cooldowns[target_key(wall)]
  if cooldown and tonumber(cooldown) > now() then return false, "target-cooldown" end
  local enemies, nearest = enemy_context(pair, wall.position, M.wall_enemy_radius)
  if enemies <= 0 then return false, "no-enemy-pressure" end
  local turret_ok, active_turrets, turret_count, labels = turret_cover(pair, wall)
  local priest_ok, active_priests = priest_cover(pair, wall)
  local covered = turret_ok or priest_ok
  if state.require_cover ~= false and not covered then return false, "uncovered-under-fire" end
  local personal_enemies = select(1, enemy_context(pair, pair.priest.position, math.sqrt(M.personal_danger_radius_sq)))
  if personal_enemies > 0 and not covered and missing_ratio(wall) < M.critical_wall_missing_ratio then
    return false, "priest-personal-danger"
  end
  return true, {
    enemies = enemies,
    nearest_enemy = nearest,
    active_turrets = active_turrets,
    turret_count = turret_count,
    turret_labels = labels,
    active_priests = active_priests,
    covered = covered,
    personal_enemies = personal_enemies,
  }
end
local function score_wall(pair, wall, context)
  local ratio = missing_ratio(wall)
  local missing = missing_health(wall)
  local enemies = context and context.enemies or 0
  local turrets = context and context.active_turrets or 0
  local priests = context and context.active_priests or 0
  local nearest = context and context.nearest_enemy or M.wall_enemy_radius
  return ratio * 15000 + missing * 3 + enemies * 450 + turrets * 900 + priests * 650
    - nearest * 40 - math.sqrt(dist_sq(pair.priest.position, wall.position)) * 35
end

function M.find_combat_repair_target(pair)
  if read_root().enabled == false then return nil, "disabled" end
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local radius = math.min(math.max(8, tonumber(pair.radius or pair.base_radius) or 32), M.search_radius)
  local best, best_context, best_score
  local checked = 0
  for _, entity in ipairs(entities(pair.station.surface, pair.priest.position, radius, pair.station.force)) do
    if is_wallish(entity) then
      checked = checked + 1
      if checked > M.max_candidates then break end
      local ok, context = eligible_wall(pair, entity)
      if ok then
        local score = score_wall(pair, entity, context)
        if not best_score or score > best_score then
          best, best_context, best_score = entity, context, score
        end
      end
    end
  end
  return best, best and best_context or "no-defended-damaged-wall", best_score
end

function M.active(pair)
  local state = pair and pair.combat_repair_0517
  return type(state) == "table" and state.phase
    and state.phase ~= "none" and state.phase ~= "complete"
    and state.phase ~= "failed" and state.phase ~= "no-target"
end

function M.recommend_action(pair)
  if read_root().enabled == false or not valid_pair(pair) then return nil end
  local state = pair.combat_repair_0517
  local target = state and valid(state.target) and state.target or nil
  local context
  if target then
    local ok, current = eligible_wall(pair, target)
    if ok then context = current else target = nil end
  end
  local score
  if not target then target, context, score = M.find_combat_repair_target(pair) end
  if not valid(target) then return nil end
  return {
    kind = "combat-repair",
    target = target,
    item = "repair-pack",
    reason = "defended-wall-under-attack-0517",
    priority = 920,
    score = score or score_wall(pair, target, context),
    context = context,
    source = "combat_repair_doctrine_0517",
  }
end

function M.abort_pair(pair, reason)
  if not pair then return result({ failed = 1, detail = "invalid-pair" }) end
  local state = pair.combat_repair_0517 or {}
  local target = valid(state.target) and state.target or (valid(pair.combat_repair_target_0517) and pair.combat_repair_target_0517) or nil
  release_cluster(pair, target, state.cluster_key)
  local repair = repair_executor()
  local repair_result = result({ processed = 0, detail = "repair-unavailable" })
  if repair and type(repair.abort_pair) == "function" then
    local ok, primary = pcall(repair.abort_pair, pair, reason or "combat-repair-aborted-0517", target)
    repair_result = ok and normalize(primary) or result({ failed = 1, detail = primary })
  end
  pair.combat_repair_0517 = {
    version = M.version,
    phase = "failed",
    failed_tick = now(),
    last_blocker = safe(reason or "combat-repair-aborted"),
  }
  pair.combat_repair_target_0517 = nil
  if pair.target == target then pair.target = nil end
  pair.mode = valid(pair.combat_target) and "combat" or "idle"
  record(pair, "aborted", reason)
  return result({
    acted = repair_result.acted,
    blocked = repair_result.blocked,
    failed = repair_result.failed,
    detail = reason or "combat-repair-aborted",
  })
end

local function complete_pair(pair, target, state)
  release_cluster(pair, target, state.cluster_key)
  local key = target_key(target)
  if key then M.root().target_cooldowns[key] = now() + M.target_cooldown_ticks end
  state.phase = "complete"
  state.completed_tick = now()
  state.missing = 0
  pair.combat_repair_0517 = state
  pair.combat_repair_target_0517 = nil
  if pair.target == target then pair.target = nil end
  pair.mode = valid(pair.combat_target) and "combat" or "idle"
  record(pair, "complete", valid(target) and target.name or "invalid-target")
  return result({ acted = 1, detail = "complete" })
end

function M.service_pair(pair, reason, forced_target)
  local root = M.root()
  if root.enabled == false then return result({ processed = 0, detail = "disabled" }) end
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  local state = pair.combat_repair_0517 or { phase = "none" }
  local target = valid(forced_target) and forced_target or (valid(state.target) and state.target) or nil
  local context
  if target then
    local ok, current = eligible_wall(pair, target)
    if ok then context = current else target = nil end
  end
  if not target then target, context = M.find_combat_repair_target(pair) end
  if not valid(target) then
    if M.active(pair) then return M.abort_pair(pair, "no-safe-combat-repair-target-0517") end
    pair.combat_repair_0517 = {
      version = M.version,
      phase = "no-target",
      last_service_tick = now(),
      last_blocker = safe(context or "no-target"),
    }
    return result({ waiting = 1, detail = context or "no-target" })
  end

  local reserved, cluster = reserve_cluster(pair, target)
  if not reserved then return result({ blocked = 1, detail = cluster }) end
  state.version = M.version
  state.phase = "repair-via-0516"
  state.target = target
  state.target_name = target.name
  state.target_unit = target.unit_number
  state.cluster_key = cluster
  state.last_service_tick = now()
  state.last_reason = safe(reason or "service")
  state.missing = missing_health(target)
  state.ratio = missing_ratio(target)
  state.enemies = context and context.enemies or nil
  state.active_turrets = context and context.active_turrets or nil
  state.active_priests = context and context.active_priests or nil
  state.cover = context and context.covered == true
  state.turret_labels = context and context.turret_labels or ""
  pair.combat_repair_0517 = state
  pair.combat_repair_target_0517 = target
  pair.target = target
  pair.mode = "combat-repair"

  local repair = repair_executor()
  if not (repair and type(repair.service_pair) == "function") then
    return M.abort_pair(pair, "repair-executor-unavailable-0517")
  end
  local ok, primary, secondary = pcall(repair.service_pair, pair, reason or "combat-repair-0517", target)
  if not ok then return M.abort_pair(pair, "repair-executor-error:" .. safe(primary)) end
  local repair_result = normalize(primary, secondary)
  state.missing = missing_health(target)
  if state.missing <= 0.01 or lower(repair_result.detail):find("complete", 1, true) then
    return complete_pair(pair, target, state)
  end
  local still_safe, blocker = eligible_wall(pair, target)
  if not still_safe then return M.abort_pair(pair, "cover-lost:" .. safe(blocker)) end
  if repair_result.failed > 0 then return M.abort_pair(pair, "repair-failed:" .. repair_result.detail) end
  if repair_result.blocked > 0 then
    release_cluster(pair, target, state.cluster_key)
    state.phase = "blocked"
    state.last_blocker = repair_result.detail
    pair.combat_repair_0517 = state
  end
  return repair_result
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.combat_repair_0517_recovery_wrapped then return true end
  local previous = diagnostics.pair_dump_lines
  diagnostics.combat_repair_0517_recovery_wrapped = true
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 COMBAT-REPAIR-0517 version=" .. M.version
      .. " enabled=" .. safe(root.enabled)
      .. " complete=" .. safe(root.stats.complete or 0)
      .. " aborted=" .. safe(root.stats.aborted or 0)
      .. " no_target=" .. safe(root.stats["no-defended-damaged-wall"] or 0)
      .. " clusters=" .. safe((function() local n=0 for _ in pairs(root.cluster_reservations) do n=n+1 end return n end)())
    return lines
  end
  return true
end
local function remove_command()
  if commands and commands.remove_command then pcall(commands.remove_command, "tp-combat-repair-0517") end
end

function M.install()
  M.root()
  patch_diagnostics()
  remove_command()
  _G.TechPriestsCombatRepairDoctrine0517 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] dispatcher-owned combat repair doctrine installed; tactical selection separated from physical repair")
  end
  return true
end

return M
