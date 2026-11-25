local names = require("scripts.voidship_armory_names")
local Visuals = require("scripts.voidship_armory_visuals")
local Effects = require("scripts.voidship_armory_effects")
local Asteroids = require("scripts.voidship_armory_asteroids")
local weapons = require("scripts.voidship_armory_weapons")
local frames = require("prototypes.generated_graphics.voidship_ordnance_frames")
local sockets = require("prototypes.generated_graphics.voidship_ordnance_sockets")
local M = {}
local MINIMUM_ENTRY_RANGE = 64
local MAXIMUM_ENTRY_RANGE = 256
local two_pi = math.pi * 2
local rounds = {
  [names.macro] = {entity = names.macro_round, kind = "macro", icon = "artillery-shell", transit = 36, speed = .30,
    sprite = "tech-priests-voidship-macro-round", size = 1.65, color = {1., .56, .23}},
  [names.launcher] = {entity = names.torpedo_round, kind = "torpedo", icon = names.torpedo, transit = 90, speed = .20,
    size = 6, color = {.29, .67, 1.}},
}
local cardinals = {
  [defines.direction.north] = {name = "north", x = 0, y = -1},
  [defines.direction.east] = {name = "east", x = 1, y = 0},
  [defines.direction.south] = {name = "south", x = 0, y = 1},
  [defines.direction.west] = {name = "west", x = -1, y = 0},
}
local sprite_facings = {"north", "east", "south", "west"}

local function state()
  storage.tech_priests_voidship_rounds = storage.tech_priests_voidship_rounds
    or {next_id = 1, order = {}, by_id = {}, by_unit = {}}
  return storage.tech_priests_voidship_rounds
end

function M.hostile(first, second)
  return first.index ~= second.index
    and not first.get_friend(second) and not second.get_friend(first)
    and not first.get_cease_fire(second) and not second.get_cease_fire(first)
end

local function point(shot, distance)
  return {x = shot.target.x - shot.dx * distance, y = shot.target.y - shot.dy * distance}
end

local function direction(mount)
  local cardinal = cardinals[mount.direction] or cardinals[defines.direction.north]
  if mount.name == names.macro then
    local pose = Visuals.status(mount)
    if pose then
      local bearing = pose.heading / 64
      return math.sin(bearing * two_pi), -math.cos(bearing * two_pi), bearing
    end
  end
  return cardinal.x, cardinal.y, nil, cardinal.name
end

function M.deck_cell(surface, position)
  local layers = surface.get_tile(position).prototype.collision_mask.layers
  return layers.ground_tile and not layers.empty_space and not layers.out_of_map
end

local function prepare_path(shot, surface)
  local distance = MINIMUM_ENTRY_RANGE
  while distance < MAXIMUM_ENTRY_RANGE and M.deck_cell(surface, point(shot, distance)) do distance = distance + 8 end
  shot.distance = distance
  for i = 0, math.ceil(distance / 24) do
    local pos = point(shot, math.min(i * 24, distance))
    if not surface.is_chunk_generated({math.floor(pos.x / 32), math.floor(pos.y / 32)}) then
      surface.request_to_generate_chunks(pos, 0)
    end
  end
end

local function label_slot(s, shot)
  local used = {}
  for _, other in pairs(s.by_id) do
    if other ~= shot and other.surface == shot.surface and other.label_slot
        and math.floor(other.target.x) == math.floor(shot.target.x)
        and math.floor(other.target.y) == math.floor(shot.target.y) then
      used[other.label_slot] = true
    end
  end
  local slot = 0
  while used[slot] do slot = slot + 1 end
  return slot
end

local function warning(shot, destination, spec)
  local surface, point = destination.surface, shot.target
  Effects.target(shot, surface, spec.kind, game.tick)
  shot.alert_anchor = destination.hub
  shot.alert_message = {"tp-voidship.incoming-alert", {"entity-name." .. spec.entity}, destination.name,
    math.floor(point.x), math.floor(point.y), shot.id}
  destination.force.add_custom_alert(shot.alert_anchor, {type = "item", name = spec.icon}, shot.alert_message, true)
  for _, player in ipairs(destination.force.connected_players) do
    if player.surface == surface then player.play_sound{path = "utility/alert_destroyed", position = point} end
  end
end

function M.launch(mount, target_ship, position, player_index)
  local s, spec = state(), rounds[mount.name]
  local dx, dy, orientation, facing = direction(mount)
  local shot = {id = s.next_id, weapon = mount.name, target = position,
    dx = dx, dy = dy, orientation = orientation, facing = facing,
    surface = target_ship.surface.index, defender = target_ship.force.index, attacker = mount.force.index,
    orbit = mount.surface.platform.space_location.name, ship_name = target_ship.name, player_index = player_index,
    launched_at = game.tick, entry_tick = game.tick + spec.transit, effects = {}}
  prepare_path(shot, target_ship.surface)
  shot.impact_tick = shot.entry_tick + math.ceil(shot.distance / spec.speed)
  shot.label_slot = label_slot(s, shot)
  warning(shot, target_ship, spec)
  s.next_id = s.next_id + 1
  s.order[#s.order + 1], s.by_id[shot.id] = shot, shot
  return {round_id = shot.id, entry_tick = shot.entry_tick, impact_tick = shot.impact_tick}
end

local function destination(shot)
  local surface = game.surfaces[shot.surface]
  local ship = surface and surface.valid and surface.platform
  local attacker = game.forces[shot.attacker]
  local location = ship and ship.valid and ship.space_location
  if location and location.name == shot.orbit and ship.scheduled_for_deletion == 0
      and ship.force.index == shot.defender and attacker and M.hostile(attacker, ship.force) then
    return surface, attacker
  end
end

local function body_offset(spec)
  return spec.sprite and {0, -.2} or {0, frames.shift}
end

local function exhaust_socket(shot, spec, offset)
  if spec.kind == "torpedo" then
    local forward = frames.facing[shot.facing].forward
    return {forward[1] * sockets.drive_socket, forward[2] * sockets.drive_socket}
  end
  return {offset[1] - shot.dx * .36, offset[2] - shot.dy * .36}
end

local function draw_round(shot, surface, spec, tick)
  local round, offset = shot.round, body_offset(spec)
  shot.outlet = {entity = round, offset = exhaust_socket(shot, spec, offset)}
  shot.bearing = shot.orientation or Effects.bearings[shot.facing] or 0
  shot.wake = Effects.wake(surface, spec.kind, shot.outlet, shot.bearing, tick - shot.entry_tick)
  shot.effects[#shot.effects + 1] = shot.wake
  shot.body = rendering.draw_sprite{
    surface = surface, sprite = spec.sprite or ("tech-priests-voidship-censer-" .. shot.facing),
    sprite_width = spec.size, sprite_height = spec.size, target = {entity = round, offset = offset},
    orientation = spec.sprite and shot.bearing or nil, render_layer = "higher-object-above",
  }
  shot.effects[#shot.effects + 1] = shot.body
  shot.glow = rendering.draw_light{sprite = "utility/light_medium", surface = surface,
    target = shot.outlet, scale = spec.sprite and 1.2 or 1.9, intensity = .63, minimum_darkness = 0,
    color = spec.color}
  shot.effects[#shot.effects + 1] = shot.glow
end

local function set_course(shot, bearing)
  shot.orientation = bearing
  shot.dx, shot.dy = math.sin(bearing * two_pi), -math.cos(bearing * two_pi)
  shot.facing = sprite_facings[math.floor(bearing * 4 + .5) % 4 + 1]
end

local function begin_asteroid_round(shot, surface, force, tick)
  local target, weapon = shot.asteroid, weapons[shot.weapon]
  if not Asteroids.valid(target, surface) then return end
  local mount = shot.mount and shot.mount.valid and shot.mount.surface == surface and shot.mount
  local round = surface.create_entity{name = weapon.asteroid_projectile, position = shot.origin,
    source = mount or shot.origin, cause = mount or force, target = target, force = force,
    speed = weapon.asteroid_speed, max_range = weapon.asteroid_range + 8}
  if not round then return end
  shot.round = round
  set_course(shot, Asteroids.heading(shot.origin, target.position) / 360)
  draw_round(shot, surface, rounds[shot.weapon], tick)
  return round
end

function M.launch_asteroid(mount, target, origin, delay)
  local s = state()
  local shot = {id = s.next_id, weapon = mount.name, asteroid = target, mount = mount, origin = origin,
    surface = mount.surface.index, attacker = mount.force.index, entry_tick = game.tick + delay, effects = {}}
  if delay == 0 and not begin_asteroid_round(shot, mount.surface, mount.force, game.tick) then
    return nil, "asteroid-lost"
  end
  s.next_id = s.next_id + 1
  s.order[#s.order + 1], s.by_id[shot.id] = shot, shot
  return {round_id = shot.id, entry_tick = shot.entry_tick}
end

local function enter(shot, surface, attacker, spec, tick)
  local pos = point(shot, shot.distance)
  if not surface.is_chunk_generated({math.floor(pos.x / 32), math.floor(pos.y / 32)}) then
    surface.force_generate_chunk_requests()
  end
  local round = surface.create_entity{name = spec.entity, position = pos, force = attacker}
  if not round then return false end
  round.disabled_by_script = true
  shot.round, shot.unit = round, round.unit_number
  state().by_unit[shot.unit] = shot
  draw_round(shot, surface, spec, tick)
  Effects.flash(surface, pos, spec.color, 5.7)
  return true
end

local function clear_effects(shot)
  for _, effect in ipairs(shot.effects) do
    if effect.valid then effect.destroy() end
  end
  shot.effects = {}
end

local function finish(shot, outcome, result, dying)
  local s = state()
  if not s.by_id[shot.id] then return end
  s.by_id[shot.id] = nil
  if shot.unit then s.by_unit[shot.unit] = nil end
  if shot.alert_anchor then
    local defender = game.forces[shot.defender]
    if defender and shot.alert_anchor.valid then
      defender.remove_alert{entity = shot.alert_anchor, type = defines.alert_type.custom,
        icon = {type = "item", name = rounds[shot.weapon].icon}, message = shot.alert_message}
    end
  end
  clear_effects(shot)
  if shot.round and shot.round.valid and not dying then shot.round.destroy() end
  local player = shot.player_index and game.get_player(shot.player_index)
  if not player then return end
  local weapon = {"entity-name." .. shot.weapon}
  if outcome == "hit" then
    player.print({"tp-voidship.ordnance-hit", weapon, shot.ship_name, string.format("%.0f", result.absorbed),
                  string.format("%.0f", result.hull_damage)})
  else
    player.print({"tp-voidship.ordnance-" .. outcome, weapon, shot.ship_name})
  end
end

function M.intercepted(event)
  local entity = event.entity
  if not entity.valid or (entity.name ~= names.macro_round and entity.name ~= names.torpedo_round) then return end
  local shot = state().by_unit[entity.unit_number]
  if not shot then return end
  local spec = rounds[shot.weapon]
  entity.surface.create_entity{name = "medium-explosion", position = entity.position}
  Effects.flash(entity.surface, entity.position, spec.color, 4.2)
  rendering.draw_text{surface = entity.surface, target = entity.position,
    text = {"tp-voidship.intercept-marker"}, color = {.63, 1., .62}, scale = 1.35, alignment = "center",
    forces = {shot.defender, shot.attacker}, time_to_live = 50}
  finish(shot, "intercepted", nil, true)
end

local function update_effects(shot, surface, spec, tick)
  -- Existing saves can hold both the round and its original render objects.
  if not shot.reticle then
    clear_effects(shot)
    shot.warning = nil
    shot.launched_at = shot.entry_tick - spec.transit
    shot.label_slot = label_slot(state(), shot)
    Effects.target(shot, surface, spec.kind, tick)
    if shot.round and shot.round.valid then draw_round(shot, surface, spec, tick) end
  elseif tick % 3 == 0 then
    Effects.update_target(shot, tick)
  end
end

local function update_asteroid_round(shot, tick)
  local surface, force = game.surfaces[shot.surface], game.forces[shot.attacker]
  local platform = surface and surface.valid and surface.platform
  if not force or not (platform and platform.valid and platform.scheduled_for_deletion == 0 and platform.force == force)
      or not Asteroids.valid(shot.asteroid, surface) then
    finish(shot)
    return
  end
  if tick < shot.entry_tick then return end
  if not shot.round then
    if not begin_asteroid_round(shot, surface, force, tick) then finish(shot) end
    return
  end
  if not shot.round.valid then finish(shot); return end
  local spec, bearing = rounds[shot.weapon], shot.round.orientation
  if bearing and math.abs(bearing - shot.bearing) > .001 then
    local last_facing = shot.facing
    set_course(shot, bearing)
    shot.bearing = bearing
    if shot.body.valid then
      if spec.sprite then shot.body.orientation = bearing
      elseif last_facing ~= shot.facing then shot.body.sprite = "tech-priests-voidship-censer-" .. shot.facing end
    end
    shot.outlet.offset = exhaust_socket(shot, spec, body_offset(spec))
    if shot.wake.valid then
      shot.wake.orientation = bearing
      Effects.move_plume(shot.wake, shot.outlet, bearing, shot.wake.sprite_height)
    end
    if shot.glow.valid then shot.glow.target = shot.outlet end
  end
  Effects.update_wake(shot, surface, spec.kind, tick)
end

local function advance(shot, tick, impact)
  if shot.asteroid then update_asteroid_round(shot, tick); return end
  local surface, attacker = destination(shot)
  if not surface then finish(shot, "miss"); return end
  local spec = rounds[shot.weapon]
  update_effects(shot, surface, spec, tick)
  if tick < shot.entry_tick then return end
  if not shot.round then
    if not enter(shot, surface, attacker, spec, tick) then finish(shot, "miss") end
    return
  end
  if not shot.round.valid then finish(shot, "miss"); return end
  if tick >= shot.impact_tick then
    if not shot.round.teleport(shot.target) then finish(shot, "miss"); return end
    local result = impact(shot, surface, attacker)
    finish(shot, result and "hit" or "miss", result)
    return
  end
  local remaining = shot.distance - (tick - shot.entry_tick) * spec.speed
  if shot.round.teleport(point(shot, remaining)) then Effects.update_wake(shot, surface, spec.kind, tick)
  else finish(shot, "miss") end
end

function M.tick(event, impact)
  local s = state()
  local write = 1
  for _, shot in ipairs(s.order) do
    if s.by_id[shot.id] then advance(shot, event.tick, impact) end
    if s.by_id[shot.id] then
      s.order[write] = shot
      write = write + 1
    end
  end
  for i = #s.order, write, -1 do s.order[i] = nil end
end

function M.status(id)
  local shot = state().by_id[id]
  if not shot then return end
  local round = shot.round and shot.round.valid and shot.round
  if shot.asteroid then
    return {stage = round and "flight" or "launching", surface_index = shot.surface,
      position = round and round.position or nil, target = shot.asteroid.valid and shot.asteroid.position or nil,
      entry = shot.origin, entry_tick = shot.entry_tick, bearing = shot.bearing}
  end
  return {stage = round and "incoming" or "transit", surface_index = shot.surface,
    position = round and round.position or nil, target = shot.target, entry = point(shot, shot.distance),
    entry_tick = shot.entry_tick, impact_tick = shot.impact_tick, health = round and round.health or nil}
end

return M
