-- scripts/core/construction_site_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical read-only placement authority. It chooses coordinates only; it never
-- owns inventory, movement, construction execution, broker cadence, or ghosts.

local Planner = {
  version = "0.1.674-dev",
  default_radius = 36,
  max_radius = 40,
  min_radius = 3,
  max_candidates_per_ring = 4096,
  threat_scan_limit = 128,
  placement_authority = true,
  read_only = true,
  effectiveness_scoring = true,
}

local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function dist_sq(a, b)
  if not (a and b) then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function constraints()
  local module = rawget(_G, "TechPriestsPlanningConstraints0646")
  if not module then
    local ok, loaded = pcall(require, "scripts.core.planning_constraints_0646")
    if ok then module = loaded end
  end
  return module
end
local function routed_find(surface, filters, category, negative_key, ttl)
  local scan = rawget(_G, "TechPriestsScanRouting0610")
  if not scan then
    local ok, loaded = pcall(require, "scripts.core.scan_routing_0610")
    if ok then scan = loaded end
  end
  if scan and type(scan.find_entities) == "function" then
    local entities = select(1, scan.find_entities(surface, filters, {
      category = category or "construction",
      negative_key = negative_key,
      negative_ttl = ttl or 60 * 4,
    }))
    return entities or {}
  end
  local ok, entities = pcall(surface.find_entities_filtered, surface, filters)
  return ok and entities or {}
end
local function prototype(entity_name)
  if not (entity_name and prototypes and prototypes.entity) then return nil end
  local ok, value = pcall(function() return prototypes.entity[entity_name] end)
  return ok and value or nil
end
local function entity_type(entity_name)
  local value = prototype(entity_name)
  local result
  if value then pcall(function() result = value.type end) end
  return result
end
local function radius_for(pair)
  if not (pair and valid(pair.station)) then return Planner.default_radius end
  if type(_G.refresh_pair_radius) == "function" then
    local ok, radius = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(radius) then return math.max(8, math.min(96, tonumber(radius))) end
  end
  if type(_G.get_station_operating_radius) == "function" then
    local ok, radius = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(radius) then return math.max(8, math.min(96, tonumber(radius))) end
  end
  return math.max(8, math.min(96, tonumber(pair.radius or pair.base_radius) or Planner.default_radius))
end
local function as_xy(position)
  if not position then return { x = 0, y = 0 } end
  return { x = position.x or position[1] or 0, y = position.y or position[2] or 0 }
end
local function collision_box(entity_name)
  local value = prototype(entity_name)
  if not value then return nil end
  local box
  pcall(function() box = value.collision_box end)
  if not box then return nil end
  local left_top = as_xy(box.left_top or box[1] or box.lt)
  local right_bottom = as_xy(box.right_bottom or box[2] or box.rb)
  return {
    left_top = left_top,
    right_bottom = right_bottom,
    width = math.abs(right_bottom.x - left_top.x),
    height = math.abs(right_bottom.y - left_top.y),
  }
end
local function buffer_for(entity_name, category)
  if category == "assembler" then return 2 end
  if category == "defense-roboport" then return 2 end
  if category == "defense-artillery" then return 2 end
  if category == "defense-turret" or category == "defense-wall" then return 1.25 end
  if category == "emergency-powertrain" then return 1.25 end
  local box = collision_box(entity_name)
  if box and math.max(box.width, box.height) >= 3 then return 1.5 end
  return 1
end
local function footprint_area(entity_name, position, buffer)
  local box = collision_box(entity_name)
  buffer = tonumber(buffer) or 1
  if box then
    return {
      { position.x + box.left_top.x - buffer, position.y + box.left_top.y - buffer },
      { position.x + box.right_bottom.x + buffer, position.y + box.right_bottom.y + buffer },
    }
  end
  return {
    { position.x - buffer, position.y - buffer },
    { position.x + buffer, position.y + buffer },
  }
end
local ignored_clearance_types = {
  corpse = true,
  ["particle-source"] = true,
  ["highlight-box"] = true,
  ["simple-entity-with-owner"] = true,
}
local function area_clear(surface, entity_name, position, buffer, ignore_resources)
  local entities = routed_find(
    surface,
    { area = footprint_area(entity_name, position, buffer) },
    "construction-clearance",
    nil,
    60 * 2
  )
  for _, entity in pairs(entities or {}) do
    if valid(entity) and not ignored_clearance_types[entity.type]
      and not (ignore_resources and entity.type == "resource")
    then
      return false
    end
  end
  return true
end
local function can_place(surface, force, entity_name, position)
  local ok, result = pcall(surface.can_place_entity, surface, {
    name = entity_name,
    position = position,
    force = force,
    build_check_type = defines and defines.build_check_type and defines.build_check_type.manual or nil,
  })
  if ok then return result == true end
  ok, result = pcall(surface.can_place_entity, surface, {
    name = entity_name,
    position = position,
    force = force,
  })
  return ok and result == true
end
local function open_side_clear(surface, entity_name, position, buffer)
  local box = collision_box(entity_name)
  local side = box and math.max(2.5, math.max(box.width, box.height) * 0.75 + 1.5) or 3
  for _, candidate in ipairs({
    { x = position.x - side, y = position.y },
    { x = position.x, y = position.y - side },
    { x = position.x + side, y = position.y },
    { x = position.x, y = position.y + side },
  }) do
    if area_clear(surface, entity_name, candidate, buffer or 1, true) then return true end
  end
  return false
end
local function x_order_for_ring(radius)
  local values = { 0 }
  for offset = 1, radius do
    values[#values + 1] = -offset
    values[#values + 1] = offset
  end
  return values
end
local function spiral_offsets(radius)
  local result, seen = {}, {}
  local function add(dx, dy)
    local key = dx .. ":" .. dy
    if not seen[key] then
      seen[key] = true
      result[#result + 1] = { dx = dx, dy = dy }
    end
  end
  for _, dx in ipairs(x_order_for_ring(radius)) do add(dx, -radius) end
  for dy = -radius + 1, radius do add(-radius, dy) end
  for dx = -radius + 1, radius do add(dx, radius) end
  for dy = radius - 1, -radius + 1, -1 do add(radius, dy) end
  return result
end
local function grid_position(origin, dx, dy)
  return { x = origin.x + dx, y = origin.y + dy }
end
local function force_is_enemy(force, other)
  if not (force and other and force ~= other) then return false end
  local ok, result = pcall(function() return force.is_enemy(other) end)
  return ok and result == true
end
local function threat_vector(pair)
  if not (pair and valid(pair.station)) then return nil end
  local station = pair.station
  local target = valid(pair.combat_target) and pair.combat_target or nil
  if target and force_is_enemy(station.force, target.force) then
    return {
      x = target.position.x - station.position.x,
      y = target.position.y - station.position.y,
      source = "active-combat-target",
    }
  end
  local scan_radius = math.min(160, radius_for(pair) * 2.5)
  local entities = routed_find(
    station.surface,
    {
      position = station.position,
      radius = scan_radius,
      type = { "unit", "unit-spawner", "turret" },
      limit = Planner.threat_scan_limit,
    },
    "construction-defense-threat",
    "defense-threat:" .. safe(station.surface.index) .. ":" .. safe(station.unit_number),
    60 * 4
  )
  local vx, vy, weight = 0, 0, 0
  for _, entity in pairs(entities or {}) do
    if valid(entity) and force_is_enemy(station.force, entity.force) then
      local dx = entity.position.x - station.position.x
      local dy = entity.position.y - station.position.y
      local distance = math.max(1, math.sqrt(dx * dx + dy * dy))
      local w = entity.type == "unit-spawner" and 4 or entity.type == "turret" and 3 or 1
      w = w / distance
      vx = vx + dx * w
      vy = vy + dy * w
      weight = weight + w
    end
  end
  if weight <= 0 or (vx == 0 and vy == 0) then return nil end
  return { x = vx / weight, y = vy / weight, source = "nearby-hostiles" }
end
local function defense_profile(entity_name, category)
  local typ = entity_type(entity_name)
  local requested = tostring(category or "")
  if requested == "defense-roboport" or requested == "roboport" or typ == "roboport" then
    local value = prototype(entity_name)
    local construction_radius, logistics_radius = 0, 0
    if value then
      pcall(function() construction_radius = tonumber(value.construction_radius) or 0 end)
      pcall(function() logistics_radius = tonumber(value.logistics_radius) or 0 end)
    end
    return {
      family = "roboport",
      category = "defense-roboport",
      perimeter = false,
      requires_power = true,
      construction_radius = construction_radius,
      logistics_radius = logistics_radius,
    }
  end
  if requested == "defense-wall" or typ == "wall" or typ == "gate" then
    return { family = "wall", category = "defense-wall", perimeter = true }
  end
  if requested == "defense-artillery" or typ == "artillery-turret" then
    return { family = "artillery", category = "defense-artillery", perimeter = true, needs_ammo = true }
  end
  if requested == "defense-turret" or requested == "turret"
    or typ == "ammo-turret" or typ == "electric-turret" or typ == "fluid-turret"
  then
    return {
      family = "turret",
      category = "defense-turret",
      perimeter = true,
      requires_power = typ == "electric-turret",
      needs_ammo = typ == "ammo-turret",
      needs_fluid = typ == "fluid-turret",
    }
  end
  if requested == "defense-radar" or typ == "radar" then
    return { family = "radar", category = "defense-radar", perimeter = false, requires_power = true }
  end
  if requested == "defense-mine" or typ == "land-mine" then
    return { family = "mine", category = "defense-mine", perimeter = true }
  end
  return nil
end
local function nearby_count(surface, position, radius, filters, predicate)
  filters = filters or {}
  filters.position = position
  filters.radius = radius
  filters.limit = filters.limit or 128
  local entities = routed_find(surface, filters, "construction-defense-support", nil, 60 * 3)
  local count = 0
  for _, entity in pairs(entities or {}) do
    if valid(entity) and (not predicate or predicate(entity)) then count = count + 1 end
  end
  return count
end
local function support_penalty(pair, position, profile)
  local surface, force = pair.station.surface, pair.station.force
  local penalty = 0
  if profile.requires_power then
    local poles = nearby_count(surface, position, 12, { type = "electric-pole", force = force })
    penalty = penalty + (poles > 0 and -18 or 45)
  end
  if profile.needs_fluid then
    local pipes = nearby_count(surface, position, 6, {
      type = { "pipe", "pipe-to-ground", "storage-tank", "pump" },
      force = force,
    })
    penalty = penalty + (pipes > 0 and -18 or 38)
  end
  if profile.needs_ammo then
    local stores = nearby_count(surface, position, 14, {
      type = { "container", "logistic-container", "cargo-wagon" },
      force = force,
    })
    penalty = penalty + (stores > 0 and -12 or 24)
  end
  return penalty
end
local function spacing_penalty(pair, entity_name, position, profile)
  local force, surface = pair.station.force, pair.station.surface
  local same_family_types
  if profile.family == "roboport" then same_family_types = { "roboport" }
  elseif profile.family == "wall" then same_family_types = { "wall", "gate" }
  elseif profile.family == "artillery" then same_family_types = { "artillery-turret" }
  elseif profile.family == "turret" then same_family_types = { "ammo-turret", "electric-turret", "fluid-turret" }
  elseif profile.family == "radar" then same_family_types = { "radar" }
  elseif profile.family == "mine" then same_family_types = { "land-mine" }
  end
  if not same_family_types then return 0 end
  local entities = routed_find(surface, {
    position = position,
    radius = profile.family == "roboport" and 64 or 16,
    type = same_family_types,
    force = force,
    limit = 96,
  }, "construction-defense-spacing", nil, 60 * 3)
  local penalty = 0
  for _, entity in pairs(entities or {}) do
    if valid(entity) then
      local distance = math.sqrt(dist_sq(position, entity.position))
      if profile.family == "roboport" then
        local existing_radius = 0
        pcall(function() existing_radius = tonumber(entity.prototype.construction_radius) or 0 end)
        local desired = math.max(10, math.min(48, (profile.construction_radius + existing_radius) * 0.7))
        if distance < desired * 0.35 then
          penalty = penalty + 70
        elseif distance <= desired then
          penalty = penalty - 18
        else
          penalty = penalty + math.min(24, (distance - desired) * 0.4)
        end
      elseif distance < 3 then
        penalty = penalty + 80
      elseif distance < 7 then
        penalty = penalty + 22
      else
        penalty = penalty - math.min(8, distance * 0.25)
      end
    end
  end
  return penalty
end
local function threat_alignment_score(station, position, threat)
  if not threat then return 0 end
  local cx = position.x - station.position.x
  local cy = position.y - station.position.y
  local c_len = math.sqrt(cx * cx + cy * cy)
  local t_len = math.sqrt(threat.x * threat.x + threat.y * threat.y)
  if c_len <= 0 or t_len <= 0 then return 0 end
  local dot = (cx * threat.x + cy * threat.y) / (c_len * t_len)
  return -55 * dot
end
local function target_radius(pair, profile)
  local radius = radius_for(pair)
  if profile.family == "roboport" then
    local inset = math.max(6, math.min(18, (profile.construction_radius or 0) * 0.55))
    return math.max(Planner.min_radius + 2, radius - inset)
  end
  if profile.family == "radar" then return math.max(Planner.min_radius + 2, radius * 0.65) end
  return radius
end
local function territory_allowed(pair, position, profile)
  local policy = constraints()
  if not policy then return true, "no-constraint-module" end
  if profile.perimeter and type(policy.defense_position_allowed) == "function" then
    return policy.defense_position_allowed(pair, position, 3.5)
  end
  if type(policy.interior_position_allowed) == "function" then
    return policy.interior_position_allowed(pair, position, 2)
  end
  return true, "no-territory-function"
end
function Planner.evaluate_defense_candidate(pair, entity_name, position, category, threat)
  if not (pair and valid(pair.station) and entity_name and position) then return nil, "invalid" end
  local profile = defense_profile(entity_name, category)
  if not profile then return nil, "not-defense" end
  local allowed, why = territory_allowed(pair, position, profile)
  if not allowed then return nil, why or "territory-denied" end
  local surface, force = pair.station.surface, pair.station.force
  local buffer = buffer_for(entity_name, profile.category)
  if not can_place(surface, force, entity_name, position) then return nil, "engine-blocked" end
  if not area_clear(surface, entity_name, position, buffer, false) then return nil, "clearance-blocked" end
  if profile.family ~= "wall" and profile.family ~= "mine"
    and not open_side_clear(surface, entity_name, position, 1)
  then
    return nil, "no-service-side"
  end
  local desired_radius = target_radius(pair, profile)
  local distance = math.sqrt(dist_sq(pair.station.position, position))
  local score = math.abs(distance - desired_radius) * 9
  score = score + threat_alignment_score(pair.station, position, threat)
  score = score + support_penalty(pair, position, profile)
  score = score + spacing_penalty(pair, entity_name, position, profile)
  local report = {
    version = Planner.version,
    read_only = true,
    placement_authority = true,
    family = profile.family,
    category = profile.category,
    entity_name = entity_name,
    position = { x = position.x, y = position.y },
    score = score,
    target_radius = desired_radius,
    actual_radius = distance,
    threat_source = threat and threat.source or "none",
    territory_reason = why,
  }
  return report, "effective"
end
function Planner.plan_defense_site(pair, entity_name, category)
  if not (pair and valid(pair.station)) then return nil, "invalid-station" end
  local profile = defense_profile(entity_name, category)
  if not profile then return nil, "not-defense" end
  local desired = math.floor(target_radius(pair, profile) + 0.5)
  local min_ring = math.max(Planner.min_radius, desired - 4)
  local max_ring = math.min(Planner.max_radius, desired + 4)
  local threat = threat_vector(pair)
  local best
  for ring = min_ring, max_ring do
    local tested = 0
    for _, offset in ipairs(spiral_offsets(ring)) do
      tested = tested + 1
      if tested > Planner.max_candidates_per_ring then break end
      local position = grid_position(pair.station.position, offset.dx, offset.dy)
      local report = Planner.evaluate_defense_candidate(pair, entity_name, position, profile.category, threat)
      if report and (not best or report.score < best.report.score
        or (report.score == best.report.score
          and (position.y < best.position.y
            or (position.y == best.position.y and position.x < best.position.x))))
      then
        best = { position = position, report = report }
      end
    end
  end
  if not best then return nil, "no-effective-defense-site" end
  return best.position,
    "defense-effective:" .. profile.family .. ":score=" .. string.format("%.2f", best.report.score),
    best.report
end
local function has_existing_miner_near(surface, position)
  local entities = routed_find(surface, {
    position = position,
    radius = 4.25,
    type = "mining-drill",
  }, "construction-miner", nil, 60 * 3)
  return entities and #entities > 0
end
local function plan_resource_miner(pair, entity_name)
  local station = pair and pair.station
  if not valid(station) then return nil, "invalid-station" end
  local radius = radius_for(pair)
  local resources = routed_find(station.surface, {
    position = station.position,
    radius = radius,
    type = "resource",
  }, "construction-resource",
    "construction-resource:" .. safe(station.surface.index) .. ":" .. safe(station.force.index)
      .. ":" .. safe(station.unit_number),
    60 * 6)
  local best, best_distance
  for _, resource in pairs(resources or {}) do
    if valid(resource) and (not resource.amount or resource.amount > 0) then
      local position = { x = resource.position.x, y = resource.position.y }
      local policy = constraints()
      local territory_ok = not policy or type(policy.interior_position_allowed) ~= "function"
        or policy.interior_position_allowed(pair, position)
      if territory_ok and dist_sq(position, station.position) <= radius * radius
        and not has_existing_miner_near(station.surface, position)
        and can_place(station.surface, station.force, entity_name, position)
        and area_clear(station.surface, entity_name, position, buffer_for(entity_name, "miner"), true)
      then
        local distance = dist_sq(position, station.position)
        if not best_distance or distance < best_distance then
          best = position
          best_distance = distance
        end
      end
    end
  end
  return best, best and "resource-patch-buffered" or "no-miner-site"
end
function Planner.plan_spiral(pair, entity_name, category)
  local station = pair and pair.station
  if not valid(station) then return nil, "invalid-station" end
  local max_radius = math.min(radius_for(pair), Planner.max_radius)
  local buffer = buffer_for(entity_name, category)
  local ignore_resources = category == "miner" or category == "emergency-miner"
  for ring = Planner.min_radius, max_radius do
    local tested = 0
    for _, offset in ipairs(spiral_offsets(ring)) do
      tested = tested + 1
      if tested > Planner.max_candidates_per_ring then break end
      local position = grid_position(station.position, offset.dx, offset.dy)
      local policy = constraints()
      local territory_ok = not policy or type(policy.interior_position_allowed) ~= "function"
        or policy.interior_position_allowed(pair, position)
      if territory_ok and can_place(station.surface, station.force, entity_name, position)
        and area_clear(station.surface, entity_name, position, buffer, ignore_resources)
        and (category ~= "assembler" or open_side_clear(station.surface, entity_name, position, 1))
      then
        return position, "station-spiral-top-left-buffered"
      end
    end
  end
  return nil, "no-spiral-site"
end
function Planner.plan_site(pair, placeable)
  if not (pair and valid(pair.station) and placeable and placeable.entity_name) then
    return nil, "invalid"
  end
  local policy = constraints()
  if policy and type(policy.entity_unlocked) == "function" then
    local unlocked, why = policy.entity_unlocked(pair, placeable.entity_name)
    if not unlocked then return nil, why or "technology-locked" end
  end
  local category = placeable.category or "generic"
  if category == "deferred-network" then return nil, "deferred-network-submodule" end
  local profile = defense_profile(placeable.entity_name, category)
  if profile then return Planner.plan_defense_site(pair, placeable.entity_name, profile.category) end
  if category == "miner" then return plan_resource_miner(pair, placeable.entity_name) end
  if category == "emergency-miner" then return Planner.plan_spiral(pair, placeable.entity_name, category) end
  if category == "emergency-power-pole" or category == "emergency-powertrain"
    or category == "emergency-smelter"
  then
    return Planner.plan_spiral(pair, placeable.entity_name, category)
  end
  if entity_type(placeable.entity_name) == "mining-drill" and category ~= "emergency-miner" then
    return plan_resource_miner(pair, placeable.entity_name)
  end
  return Planner.plan_spiral(pair, placeable.entity_name, category)
end
function Planner.placement_effectiveness_report(pair, entity_name, position, category)
  return Planner.evaluate_defense_candidate(pair, entity_name, position, category, threat_vector(pair))
end
function Planner.debug_sequence(pair, entity_name, limit)
  local station = pair and pair.station
  if not valid(station) then return {} end
  local result = {}
  limit = tonumber(limit) or 24
  for ring = Planner.min_radius, math.min(Planner.min_radius + 4, Planner.max_radius) do
    for _, offset in ipairs(spiral_offsets(ring)) do
      result[#result + 1] = {
        x = station.position.x + offset.dx,
        y = station.position.y + offset.dy,
        ring = ring,
      }
      if #result >= limit then return result end
    end
  end
  return result
end

_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359 = Planner
_G.TechPriestsConstructionSitePlanner = Planner

return Planner
