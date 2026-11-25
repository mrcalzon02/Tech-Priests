local names = require("scripts.voidship_armory_names")
local Visuals = require("scripts.voidship_armory_visuals")
local M = {}
local JOULES_PER_HIT_POINT = 25000
local UPDATE_TICKS = 12
local SECONDS_PER_UPDATE = UPDATE_TICKS / 60
local UPKEEP_JOULES = 100000 * SECONDS_PER_UPDATE
local UNPOWERED_LOSS_JOULES = 500000 * SECONDS_PER_UPDATE
local EFFICIENCY = .05
local applying_ship_damage = {}

local function state()
  storage.tech_priests_voidship_shield = storage.tech_priests_voidship_shield
    or {ships = {}, registrations = {}, by_unit = {}}
  return storage.tech_priests_voidship_shield
end

local function remove(entry)
  if entry.intake and entry.intake.valid then entry.intake.destroy() end
  local s = state()
  local ship = s.ships[entry.surface_index]
  if ship then
    for i, candidate in ipairs(ship) do
      if candidate == entry then
        table.remove(ship, i)
        break
      end
    end
    if #ship == 0 then s.ships[entry.surface_index] = nil end
  end
  s.registrations[entry.registration], s.by_unit[entry.unit] = nil, nil
end

local function power_intake(entry)
  local projector = entry.entity
  local input, position = entry.intake, projector.position
  if input and input.valid then
    if input.surface == projector.surface and input.force == projector.force
        and input.position.x == position.x and input.position.y == position.y then return input end
    input.destroy()
  end
  input = projector.surface.create_entity{name = names.shield_intake, position = position, force = projector.force}
  if input then input.destructible = false end
  entry.intake = input
  return input
end

function M.add(entity)
  if not (entity and entity.valid and entity.name == names.shield) then return end
  local s, unit = state(), entity.unit_number
  local entry, platform = s.by_unit[unit], Visuals.platform(entity)
  local surface_index = entity.surface.index
  if entry and (not platform or entry.surface_index ~= surface_index) then
    remove(entry)
    entry = nil
  end
  if not platform then return end
  if entry then power_intake(entry); return end
  local registration = script.register_on_object_destroyed(entity)
  entry = {entity = entity, surface_index = surface_index, unit = unit, registration = registration}
  local ship = s.ships[surface_index] or {}
  s.ships[surface_index], s.registrations[registration], s.by_unit[unit] = ship, entry, entry
  local i = #ship + 1
  while i > 1 and ship[i - 1].unit > unit do i = i - 1 end
  table.insert(ship, i, entry)
  power_intake(entry)
end

function M.init()
  for _, entry in pairs(state().by_unit) do
    if not entry.entity.valid or not Visuals.platform(entry.entity) then remove(entry) end
  end
  for _, surface in pairs(game.surfaces) do
    if surface.platform then
      for _, entity in ipairs(surface.find_entities_filtered{name = names.shield}) do M.add(entity) end
    end
  end
end

function M.tick(event)
  if event.tick % UPDATE_TICKS ~= 0 then return end
  for _, projectors in pairs(state().ships) do
    for _, entry in ipairs(projectors) do
      local projector = entry.entity
      if Visuals.platform(projector) then
        local input, charge = power_intake(entry), projector.energy
        local available = input and input.energy or 0
        local upkeep = math.min(available, UPKEEP_JOULES)
        local headroom = math.max(0, projector.electric_buffer_size - charge)
        local conversion = math.min(available - upkeep, headroom / EFFICIENCY)
        local loss = UNPOWERED_LOSS_JOULES * (1 - upkeep / UPKEEP_JOULES)
        if input then input.energy = available - upkeep - conversion end
        projector.energy = math.max(0, charge + conversion * EFFICIENCY - loss)
      end
    end
  end
end

function M.destroyed(event)
  local entry = state().registrations[event.registration_number]
  if entry then remove(entry) end
end

function M.surface_removed(event)
  local ship = state().ships[event.surface_index]
  if ship then for i = #ship, 1, -1 do remove(ship[i]) end end
end

function M.hull_entity(entity)
  return Visuals.platform(entity) and entity.health
    and (entity.type == "space-platform-hub" or entity.prototype.is_building)
end

local function absorb(surface, force, position, damage, radius)
  local ship = state().ships[surface.index]
  if not ship then return 0 end
  local remaining, spent = damage * JOULES_PER_HIT_POINT, 0
  for _, entry in ipairs(ship) do
    local projector = entry.entity
    if projector.valid and projector.force == force and projector.surface == surface then
      local used = math.min(projector.energy, remaining)
      projector.energy = projector.energy - used
      remaining, spent = remaining - used, spent + used
      if remaining <= 0 then break end
    end
  end
  local absorbed = spent / JOULES_PER_HIT_POINT
  if absorbed > 0 then
    rendering.draw_circle{
      color = {r = .40, g = .19, b = .78, a = .75 * math.min(1, absorbed / math.max(1, damage))},
      target = position, surface = surface, filled = false, width = 4,
      radius = radius, time_to_live = 18, forces = {force},
    }
  end
  return absorbed
end

local function absorb_entity(target, damage)
  return absorb(target.surface, target.force, target.position, damage, math.max(target.tile_width, target.tile_height) * .55)
end

function M.absorb_cell(surface, force, position, damage)
  return absorb(surface, force, position, damage, 1.5)
end

function M.damaged(event)
  local target = event.entity
  if not target.valid or applying_ship_damage[target.unit_number] then return end
  if not state().ships[target.surface.index] or not M.hull_entity(target) then return end
  -- Lethal native events report zero health, so their pre-hit health is unknown.
  if event.final_health <= 0 or target.health <= 0 then return end
  local recoverable = math.min(event.final_damage_amount, target.max_health - target.health)
  if recoverable <= 0 then return end
  local absorbed = absorb_entity(target, recoverable)
  if absorbed > 0 then target.health = target.health + absorbed end
end

-- Ship weapons spend shield power before hull resistances and lethal checks.
function M.apply_ship_damage(target, amount, force_name_or_index, damage_type, source, cause)
  if not (M.hull_entity(target) and target.destructible and target.health > 0) then
    return nil, "a live, destructible platform hull entity is required"
  end
  local kind = type(force_name_or_index)
  local force = (kind == "string" or kind == "number") and game.forces[force_name_or_index]
  if not (force and force.valid) then return nil, "invalid attacking force" end
  damage_type = damage_type or "impact"
  if not prototypes.damage[damage_type] then return nil, "invalid damage type" end
  if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount > 1000000000 then
    return nil, "invalid damage amount"
  end
  if source and (not source.valid or source.surface ~= target.surface) then
    return nil, "the immediate source must be on the same platform"
  end
  if cause and not cause.valid then return nil, "invalid damage cause" end
  if amount == 0 then return {absorbed = 0, unshielded = 0, hull_damage = 0} end
  local absorbed = absorb_entity(target, amount)
  local applied, spill = 0, amount - absorbed
  if spill > 0 then
    local unit = target.unit_number
    local previous = unit and applying_ship_damage[unit]
    if unit then applying_ship_damage[unit] = true end
    local ok, result = pcall(target.damage, spill, force, damage_type, source, cause)
    if unit then applying_ship_damage[unit] = previous end
    if not ok then error(result) end
    applied = result
  end
  return {absorbed = absorbed, unshielded = spill, hull_damage = applied}
end

return M
