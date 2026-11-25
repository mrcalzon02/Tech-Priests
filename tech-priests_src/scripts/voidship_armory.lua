local names = require("scripts.voidship_armory_names")
local Visuals = require("scripts.voidship_armory_visuals")
local Shield = require("scripts.voidship_armory_shield")
local Ordnance = require("scripts.voidship_armory_ordnance")
local Rounds = require("scripts.voidship_armory_rounds")
local Asteroids = require("scripts.voidship_armory_asteroids")
local weapons = require("scripts.voidship_armory_weapons")
local M = {}
local SHELL = "artillery-shell"
local unlocks = {[names.macro] = "artillery", [names.lance] = "space-platform",
                 [names.launcher] = "space-platform", [names.shield] = "space-platform",
                 [names.torpedo] = "space-platform"}

local function state()
  storage.tech_priests_voidship_breeches = storage.tech_priests_voidship_breeches
    or {ready_at = {}, registrations = {}}
  local s = storage.tech_priests_voidship_breeches
  s.capacitors, s.next_bay = s.capacitors or {}, s.next_bay or {}
  return s
end

local function capacitor(mount)
  local s, unit = state(), mount.unit_number
  local bank, position = s.capacitors[unit], mount.position
  local platform = Visuals.platform(mount)
  if bank and bank.valid then
    if platform and bank.surface == mount.surface and bank.force == mount.force
        and bank.position.x == position.x and bank.position.y == position.y then return bank end
    bank.destroy()
  end
  s.capacitors[unit] = nil
  if not platform then return end
  bank = mount.surface.create_entity{name = names.lance_capacitor, position = position, force = mount.force}
  if bank then
    bank.destructible = false
    s.capacitors[unit] = bank
    s.registrations[script.register_on_object_destroyed(mount)] = unit
  end
  return bank
end

local function filter_breech(entity)
  local inventory = entity.get_inventory(defines.inventory.chest)
  for i = 1, #inventory do
    inventory.set_filter(i, {name = SHELL, quality = "normal", comparator = ">="})
  end
end

local function added(event)
  local entity = event.destination or event.entity
  if not (entity and entity.valid) then return end
  if entity.name == names.macro then filter_breech(entity) end
  if entity.name == names.lance then capacitor(entity) end
  Visuals.add(entity)
  Shield.add(entity)
end

local function transformed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == names.lance then capacitor(entity) end
  Visuals.add(entity)
  Shield.add(entity)
end

local function init()
  state()
  Visuals.init()
  Shield.init()
  for _, surface in pairs(game.surfaces) do
    if surface.platform then
      for _, lance in ipairs(surface.find_entities_filtered{name = names.lance}) do capacitor(lance) end
    end
  end
  for _, force in pairs(game.forces) do
    for recipe, tech in pairs(unlocks) do
      if force.technologies[tech] and force.technologies[tech].researched and force.recipes[recipe] then
        force.recipes[recipe].enabled = true
      end
    end
  end
end

local function destroyed(event)
  Visuals.destroyed(event)
  Shield.destroyed(event)
  local s = state()
  local unit = s.registrations[event.registration_number]
  if unit then
    local bank = s.capacitors[unit]
    if bank and bank.valid then bank.destroy() end
    s.registrations[event.registration_number], s.ready_at[unit] = nil, nil
    s.capacitors[unit], s.next_bay[unit] = nil, nil
  end
end

local hostile = Rounds.hostile

local function hull_platform(target)
  if Shield.hull_entity(target) and target.destructible and target.health > 0 then
    return target.surface.platform
  end
end

local function cooling_down(mount)
  local ready = state().ready_at[mount.unit_number]
  if ready and game.tick < ready then return ready end
end

local function firing_solution(mount, target_ship)
  local source_ship = Visuals.platform(mount)
  if not source_ship then return nil, "space-platform-required" end
  if not (target_ship and target_ship.valid and Visuals.platform(target_ship.hub)) then return nil, "invalid-target" end
  if source_ship.surface.index == target_ship.surface.index then return nil, "same-platform" end
  if not hostile(mount.force, target_ship.force) then return nil, "no-hostility" end
  local origin, destination = source_ship.space_location, target_ship.space_location
  if not origin or not destination or origin.name ~= destination.name then return nil, "out-of-range" end
  local ready = cooling_down(mount)
  if ready then return nil, "cooldown", ready end
  return source_ship
end

local function ammunition(inventory, item)
  if not inventory then return end
  for i = 1, #inventory do
    local slot = inventory[i]
    if slot.valid_for_read and slot.name == item then return slot end
  end
end

local function spend_one(slot)
  if slot.count == 1 then slot.clear() else slot.count = slot.count - 1 end
end

local function muzzle_flash(cannon)
  local _, origins = Visuals.begin(cannon)
  if not origins then return end
  local offset, position = origins[1], cannon.position
  local muzzle = {x = position.x + offset[1], y = position.y + offset[2]}
  cannon.surface.create_entity{name = "medium-explosion",
    position = muzzle}
  rendering.draw_light{sprite = "utility/light_medium", surface = cannon.surface,
    target = {entity = cannon, offset = offset}, scale = 1.8, intensity = .9,
    color = {1., .68, .31}, time_to_live = 5}
  return muzzle
end

local function impact_effect(weapon, surface, position)
  if weapon.explosion then surface.create_entity{name = weapon.explosion, position = position} end
  if weapon.flash then
    rendering.draw_light{sprite = "utility/light_medium", surface = surface, target = position,
      scale = 4.2, intensity = .92, color = weapon.flash, time_to_live = 23}
  end
end

local function strike(weapon, target, force, cause, position)
  local surface, point = target.surface, position or target.position
  local ok, result = pcall(Shield.apply_ship_damage, target, weapon.damage, force.index, weapon.damage_type, nil, cause)
  if not ok then log("[Tech Priests voidship] " .. tostring(result)); return end
  if result and result.hull_damage > 0 and surface.valid then impact_effect(weapon, surface, point) end
  return result
end

local function reload(mount, weapon)
  local s, unit = state(), mount.unit_number
  local ready = game.tick + weapon.reload
  s.ready_at[unit] = ready
  s.registrations[script.register_on_object_destroyed(mount)] = unit
  return ready
end

local function fire_macro(cannon, weapon, aim, player_index)
  local slot = ammunition(cannon.get_inventory(defines.inventory.chest), SHELL)
  if not slot then return nil, "no-shells" end
  local shot, reason
  if aim.asteroid then
    Visuals.aim(cannon, Asteroids.heading(cannon.position, aim.asteroid.position))
    local muzzle = muzzle_flash(cannon)
    if not muzzle then return nil, "invalid-mount" end
    shot, reason = Rounds.launch_asteroid(cannon, aim.asteroid, muzzle, 0)
  else
    shot = Rounds.launch(cannon, aim.ship, aim.position, player_index)
  end
  if not shot then return nil, reason end
  spend_one(slot)
  shot.shells_spent, shot.cooldown_until = 1, reload(cannon, weapon)
  if not aim.asteroid then muzzle_flash(cannon) end
  return shot
end

local function fire_lance(mount, target, weapon, source_ship, target_ship, player_index)
  local bank = capacitor(mount)
  if not bank or bank.energy < weapon.charge then return nil, "no-lance-power" end
  local asteroid = target.type == "asteroid"
  local shot = {weapon = mount.name, target = target, force_index = mount.force.index,
    orbit = not asteroid and source_ship.space_location.name or nil, target_surface = target.surface.index,
    asteroid = asteroid, asteroid_range = weapon.asteroid_range,
    target_name = asteroid and target.prototype.localised_name or target_ship.name, player_index = player_index}
  local accepted, reason = Ordnance.play(mount, nil, shot)
  if not accepted then return nil, reason end
  bank.energy = bank.energy - weapon.charge
  return {impact_tick = shot.impact_tick, cooldown_until = reload(mount, weapon), joules_spent = weapon.charge}
end

local function fire_torpedo(mount, weapon, source_ship, aim, player_index)
  local hub = source_ship.hub
  local cargo = hub and hub.valid and hub.get_inventory(defines.inventory.hub_main)
  local torpedo = ammunition(cargo, names.torpedo)
  if not torpedo then return nil, "no-torpedoes" end
  local unit, s = mount.unit_number, state()
  local bay = s.next_bay[unit] or 1
  local accepted, reason = Ordnance.play(mount, bay)
  if not accepted then return nil, reason end
  local shot
  if aim.asteroid then
    local exit, delay = Ordnance.launcher_exit(mount, bay)
    shot = Rounds.launch_asteroid(mount, aim.asteroid, exit, delay)
  else
    shot = Rounds.launch(mount, aim.ship, aim.position, player_index)
  end
  spend_one(torpedo)
  s.next_bay[unit] = bay % 4 + 1
  shot.torpedoes_spent, shot.bay, shot.cooldown_until = 1, bay, reload(mount, weapon)
  return shot
end

local function fire(mount, target_ship, target, position, player_index)
  local weapon = mount and mount.valid and weapons[mount.name]
  if not weapon then return nil, "invalid-mount" end
  local source_ship, reason, retry = firing_solution(mount, target_ship)
  if not source_ship then
    if mount.name == names.macro and reason == "space-platform-required" then return nil, "invalid-cannon" end
    return nil, reason, retry
  end
  local aim = {ship = target_ship, position = position}
  if mount.name == names.macro then return fire_macro(mount, weapon, aim, player_index) end
  if mount.name == names.launcher then return fire_torpedo(mount, weapon, source_ship, aim, player_index) end
  if not target then return nil, "lance-cell" end
  return fire_lance(mount, target, weapon, source_ship, target_ship, player_index)
end

local function fire_asteroid(mount, target, player_index)
  local weapon = mount and mount.valid and weapons[mount.name]
  if not weapon then return nil, "invalid-mount" end
  local ship = Visuals.platform(mount)
  if not ship then return nil, "space-platform-required" end
  local ready = cooling_down(mount)
  if ready then return nil, "cooldown", ready end
  target = target or Asteroids.nearest(mount, weapon.asteroid_range)
  if not target then return nil, "no-asteroids" end
  local distance, reason = Asteroids.check(mount, target, weapon.asteroid_range)
  if not distance then return nil, reason end
  local aim = {asteroid = target}
  local shot
  if mount.name == names.macro then shot, reason = fire_macro(mount, weapon, aim, player_index)
  elseif mount.name == names.launcher then shot, reason = fire_torpedo(mount, weapon, ship, aim, player_index)
  else shot, reason = fire_lance(mount, target, weapon, ship, ship, player_index) end
  if not shot then return nil, reason end
  shot.asteroid = target
  return shot
end

local function fire_at(mount, surface_index, x, y, player_index)
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or math.abs(x) >= 1e6 or math.abs(y) >= 1e6 then
    return nil, "invalid-cell"
  end
  local surface = type(surface_index) == "number" and surface_index % 1 == 0 and game.surfaces[surface_index]
  local platform = surface and surface.valid and surface.platform
  if not platform then return nil, "invalid-target" end
  local position = {x = math.floor(x) + .5, y = math.floor(y) + .5}
  if not Rounds.deck_cell(surface, position) then return nil, "invalid-cell" end
  return fire(mount, platform, nil, position, player_index)
end

local function fire_at_entity(mount, target, player_index)
  if target and target.valid and target.type == "asteroid" then return fire_asteroid(mount, target, player_index) end
  local platform = hull_platform(target)
  return fire(mount, platform, target, platform and target.position, player_index)
end

local function resolve_lance_asteroid(shot, mount, weapon, force)
  local target, damage = shot.target
  local own_ship = Visuals.platform(mount)
  if weapon and force and own_ship and mount.force == force and mount.surface.index == shot.target_surface
      and Asteroids.check(mount, target, shot.asteroid_range) then
    local position = target.position
    damage = target.damage(weapon.damage, force, weapon.damage_type, nil, mount)
    if damage > 0 then impact_effect(weapon, mount.surface, position) end
  end
  local player = shot.player_index and game.get_player(shot.player_index)
  if player then
    if damage then player.print({"tp-voidship.asteroid-hit", shot.target_name, string.format("%.0f", damage)})
    else player.print({"tp-voidship.asteroid-lost"}) end
  end
end

local function round_impact(shot, surface, attacker)
  local weapon, force = weapons[shot.weapon], game.forces[shot.defender]
  local position = shot.target
  local hull
  for _, candidate in ipairs(surface.find_entities_filtered{position = position, force = force}) do
    if hull_platform(candidate) and (not hull or (candidate.unit_number or 0) < (hull.unit_number or 0)) then
      hull = candidate
    end
  end
  if hull then return strike(weapon, hull, attacker, shot.round, position) end
  local absorbed = Shield.absorb_cell(surface, force, position, weapon.damage)
  if absorbed < weapon.damage then impact_effect(weapon, surface, position) end
  return {absorbed = absorbed, hull_damage = 0}
end

local function resolve(shot, mount)
  local weapon, force = weapons[shot.weapon], game.forces[shot.force_index]
  if shot.asteroid then resolve_lance_asteroid(shot, mount, weapon, force); return end
  local target_ship = hull_platform(shot.target)
  local orbit = target_ship and target_ship.space_location
  local own_ship = Visuals.platform(mount)
  local own_orbit = own_ship and own_ship.space_location
  local usable_lance = own_orbit and own_orbit.name == shot.orbit and mount.force.index == shot.force_index
  local result
  if weapon and force and orbit and orbit.name == shot.orbit and target_ship.surface.index == shot.target_surface
      and hostile(force, shot.target.force) and (not weapon.charge or usable_lance) then
    result = strike(weapon, shot.target, force, mount)
  end
  local player = shot.player_index and game.get_player(shot.player_index)
  if not player then return end
  local name = {"entity-name." .. shot.weapon}
  if result then
    player.print({"tp-voidship.ordnance-hit", name, shot.target_name, string.format("%.0f", result.absorbed),
                  string.format("%.0f", result.hull_damage)})
  else
    player.print({"tp-voidship.ordnance-miss", name, shot.target_name})
  end
end

local function owned(entity, player)
  return entity and entity.valid and entity.object_name == "LuaEntity"
    and entity.force == player.force and entity.surface == player.surface
end

local function possible_targets(ship)
  local candidates, location = {}, ship.space_location
  if not location then return candidates end
  for _, force in pairs(game.forces) do
    if hostile(force, ship.force) then
      for _, platform in pairs(force.platforms) do
        local orbit = platform.valid and platform.space_location
        if orbit and orbit.name == location.name and Visuals.platform(platform.hub) then
          candidates[#candidates + 1] = platform
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.surface.index < b.surface.index end)
  return candidates
end

local function parameter(event)
  return (event.parameter or ""):match("^%s*(.-)%s*$")
end

local function weapon_allowed(mount, player, macro_only)
  return owned(mount, player) and weapons[mount.name] and (not macro_only or mount.name == names.macro)
end

local function fire_command(event, macro_only)
  if not event.player_index then return end
  local player = game.get_player(event.player_index)
  local mount = player.opened
  if not weapon_allowed(mount, player, macro_only) then mount = player.selected end
  if not weapon_allowed(mount, player, macro_only) or not Visuals.platform(mount) then
    player.print({macro_only and "tp-voidship.select-cannon" or "tp-voidship.select-weapon"})
    return
  end
  local value = parameter(event)
  if value == "asteroid" then
    local result, reason = fire_asteroid(mount, nil, player.index)
    if not result then player.print({"tp-voidship." .. reason}); return end
    local target = result.asteroid
    if target.valid then player.print({"tp-voidship.asteroid-fired", target.prototype.localised_name}) end
    return
  end
  local targets = possible_targets(mount.surface.platform)
  if #targets == 0 then player.print({"tp-voidship.no-targets"}); return end
  if value == "" then
    for _, target in ipairs(targets) do player.print({"tp-voidship.target-row", target.name, target.surface.index}) end
    return
  end
  local platform_name, x, y = value:match("^(.-)%s+@%s*([+-]?%d+)%s*,%s*([+-]?%d+)%s*$")
  platform_name = platform_name or value
  local index = tonumber(platform_name:match("^#(%d+)$"))
  local match
  for _, target in ipairs(targets) do
    if target.surface.index == index or (not index and target.name == platform_name) then
      if match then player.print({"tp-voidship.ambiguous"}); return end
      match = target
    end
  end
  if not match then player.print({"tp-voidship.target-unavailable"}); return end
  local target_name = match.name
  local result, reason
  if x then result, reason = fire_at(mount, match.surface.index, tonumber(x), tonumber(y), player.index)
  else result, reason = fire_at_entity(mount, match.hub, player.index) end
  if not result then player.print({"tp-voidship." .. reason}); return end
  player.print({"tp-voidship.ordnance-start", {"entity-name." .. mount.name}, target_name})
end

local function macro_command(event)
  fire_command(event, true)
end

local function preview_command(event)
  if not event.player_index then return end
  local player = game.get_player(event.player_index)
  local mount, value = player.selected, parameter(event)
  if not owned(mount, player) then player.print({"tp-voidship.invalid-mount"}); return end
  local accepted, reason = Ordnance.play(mount, value ~= "" and value or nil)
  if not accepted then player.print({"tp-voidship." .. reason}) end
end

local function aim_command(event)
  if not event.player_index then return end
  local player = game.get_player(event.player_index)
  local mount = player.selected
  if not owned(mount, player) then player.print({"tp-voidship.invalid-mount"}); return end
  local heading, reason = Visuals.aim(mount, tonumber(parameter(event)))
  if not heading then player.print({"tp-voidship." .. reason}); return end
  player.print({"tp-voidship.aimed", heading * 360 / 64})
end

function M.install_main(registry)
  local function route(name)
    return {owner = "voidship_armory", route = name, category = "combat", priority = 200}
  end
  local function on(event, handler, name)
    assert(registry.on_event(event, handler, nil, route(name)), name)
  end
  registry.on_init(init, route("initialize"))
  registry.on_configuration_changed(init, route("configuration"))
  on(defines.events.on_tick, function(event)
    Visuals.tick(event)
    Ordnance.tick(event, resolve)
    Rounds.tick(event, round_impact)
    Shield.tick(event)
  end, "weapon-motion")
  on({defines.events.on_built_entity, defines.events.on_robot_built_entity,
      defines.events.on_space_platform_built_entity, defines.events.script_raised_built,
      defines.events.script_raised_revive, defines.events.on_entity_cloned}, added, "mount-built")
  on({defines.events.on_player_rotated_entity, defines.events.script_raised_teleported}, transformed, "mount-moved")
  on(defines.events.on_object_destroyed, destroyed, "mount-destroyed")
  on({defines.events.on_surface_cleared, defines.events.on_surface_deleted}, Shield.surface_removed, "ship-removed")
  on(defines.events.on_entity_damaged, Shield.damaged, "shield-native-hit")
  on(defines.events.on_entity_died, Rounds.intercepted, "ordnance-interception")
  remote.add_interface("tech_priests_voidship", {
    fire = function(mount, target) return fire_at_entity(mount, target) end,
    fire_asteroid = function(mount, target) return fire_asteroid(mount, target) end,
    fire_at = function(mount, surface, x, y) return fire_at(mount, surface, x, y) end,
    round_status = Rounds.status,
    preview = function(mount, bay) return Ordnance.play(mount, bay) end,
    aim = Visuals.aim, visual_status = Visuals.status, apply_ship_damage = Shield.apply_ship_damage,
  })
  commands.add_command("tp-voidship-fire", {"tp-voidship.ordnance-fire-help"}, fire_command)
  commands.add_command("tp-macro-fire", {"tp-voidship.fire-help"}, macro_command)
  commands.add_command("tp-armory-demo", {"tp-voidship.demo-help"}, preview_command)
  commands.add_command("tp-voidship-aim", {"tp-voidship.aim-help"}, aim_command)
  if not script.active_mods["voidship-macro-candidate"] then
    commands.add_command("macro-fire", {"tp-voidship.fire-help"}, macro_command)
    commands.add_command("armory-demo", {"tp-voidship.demo-help"}, preview_command)
  end
  return true
end

return M
