local names = require("scripts.voidship_armory_names")
local Visuals = require("scripts.voidship_armory_visuals")
local Effects = require("scripts.voidship_armory_effects")
local Asteroids = require("scripts.voidship_armory_asteroids")
local frames = require("prototypes.generated_graphics.voidship_ordnance_frames")
local sockets = require("prototypes.generated_graphics.voidship_ordnance_sockets")
local M = {}
local EJECTION_TICKS, EJECTION_DISTANCE = 30, 6
local types = {[names.lance] = "lance", [names.launcher] = "torpedo", [names.shield] = "shield"}
local facings = {[defines.direction.north] = "north", [defines.direction.east] = "east",
                 [defines.direction.south] = "south", [defines.direction.west] = "west"}

local function states()
  storage.tech_priests_voidship_ordnance = storage.tech_priests_voidship_ordnance or {}
  return storage.tech_priests_voidship_ordnance
end

local function attached(entity, origin, forward, distance, shift)
  return {entity = entity, offset = {origin[1] + forward[1] * distance,
                                    origin[2] + forward[2] * distance + (shift or 0)}}
end

local function light(mount, offset, color, duration)
  return rendering.draw_light{
    sprite = "utility/light_medium", surface = mount.surface,
    target = {entity = mount, offset = offset}, color = color, scale = 1.2,
    intensity = .34, minimum_darkness = 0, time_to_live = duration,
  }
end

local function flash_lance(state, destination)
  local mount = state.mount
  local origins, forward = Visuals.lance_sockets(mount, 4)
  for _, origin in ipairs(origins) do
    local from = attached(mount, origin, forward, 0)
    local to = destination or attached(mount, origin, forward, 8)
    state.effects[#state.effects + 1] = rendering.draw_line{
      surface = mount.surface, from = from, to = to,
      color = {1, .28, .04, .55}, width = 7, time_to_live = sockets.beam_duration,
    }
    state.effects[#state.effects + 1] = rendering.draw_line{
      surface = mount.surface, from = from, to = to,
      color = {1, .84, .51, 1}, width = 2, time_to_live = sockets.beam_duration - 3,
    }
  end
end

local function begin_launcher(state, bay)
  local mount, facing = state.mount, state.facing
  local forward = frames.facing[facing].forward
  state.bay, state.duration = bay, EJECTION_TICKS
  state.projectile = rendering.draw_sprite{
    sprite = "tech-priests-voidship-censer-" .. facing, surface = mount.surface,
    target = attached(mount, bay, forward, frames.tail_clearance, frames.shift),
    sprite_width = 6, sprite_height = 6, render_layer = "object", time_to_live = state.duration,
  }
  local tail = frames.tail_clearance + sockets.drive_socket
  state.trail = Effects.plume(mount.surface, "torpedo", attached(mount, bay, forward, tail),
    Effects.bearings[facing], .45, state.duration)
  state.effects = {state.projectile, state.trail}
end

function M.launcher_exit(mount, bay)
  local facing = facings[mount.direction] or "north"
  local origin, forward = sockets.facing[facing].bays[bay], frames.facing[facing].forward
  local runout = frames.tail_clearance + EJECTION_DISTANCE
  local position = mount.position
  return {x = position.x + origin[1] + forward[1] * runout,
          y = position.y + origin[2] + forward[2] * runout}, EJECTION_TICKS
end

local function begin_shield(state, frame)
  local mount = state.mount
  state.duration = 32
  for _, crown in ipairs(frame.crowns) do
    state.effects[#state.effects + 1] = light(mount, crown, {.42, .25, 1.}, 20)
  end
  state.field = rendering.draw_circle{surface = mount.surface,
    target = {entity = mount, offset = frame.field}, radius = .35, width = 3,
    color = {.62, .39, 1., .72}, filled = false, time_to_live = state.duration}
  state.effects[#state.effects + 1] = state.field
end

function M.play(mount, selected_bay, shot)
  if not (mount and mount.valid and types[mount.name] and mount.unit_number) then return nil, "invalid-mount" end
  if not Visuals.platform(mount) then return nil, "space-platform-required" end
  local active = states()
  if active[mount.unit_number] then return nil, "busy" end
  local kind, facing = types[mount.name], facings[mount.direction] or "north"
  local state = {start = game.tick, mount = mount, surface = mount.surface,
                 facing = facing, kind = kind, effects = {}, shot = shot}
  if kind == "lance" then
    if shot and shot.asteroid then Visuals.aim(mount, Asteroids.heading(mount.position, shot.target.position)) end
    local heading, origins, duration = Visuals.begin(mount)
    if not heading then return nil, "invalid-mount" end
    state.duration = duration
    for _, origin in ipairs(origins) do
      state.effects[#state.effects + 1] = light(mount, origin, {1., .38, .09}, sockets.beam_delay)
    end
  elseif kind == "torpedo" then
    local index = selected_bay == nil and 3 or tonumber(selected_bay)
    local bay = index and sockets.facing[facing].bays[index]
    if not bay then return nil, "invalid-bay" end
    begin_launcher(state, bay)
  else
    begin_shield(state, sockets.facing[facing])
  end
  if shot then shot.impact_tick = state.start + (kind == "lance" and sockets.beam_delay or shot.flight_ticks) end
  active[mount.unit_number] = state
  return true
end

local function update_lance(state, elapsed)
  local shot = state.shot
  local destination
  if shot and shot.asteroid then
    if not Asteroids.check(state.mount, shot.target, shot.asteroid_range) then
      if elapsed >= sockets.beam_delay then state.discharge = true end
      return
    end
    destination = shot.target.position
    Visuals.track_lance(state.mount, Asteroids.heading(state.mount.position, destination))
  end
  if elapsed >= sockets.beam_delay and not state.discharge then
    state.discharge = true
    flash_lance(state, destination)
  elseif not state.discharge then
    local origins = Visuals.lance_sockets(state.mount, Visuals.status(state.mount).frame + 1)
    for i, glow in ipairs(state.effects) do
      if glow.valid then
        glow.target = {entity = state.mount, offset = origins[i]}
        glow.intensity = .34 + .60 * elapsed / sockets.beam_delay
      end
    end
  end
end

local function update_torpedo(state, fraction)
  local forward = frames.facing[state.facing].forward
  local travel = frames.tail_clearance + EJECTION_DISTANCE * fraction * fraction
  local tail = travel + sockets.drive_socket
  state.projectile.target = attached(state.mount, state.bay, forward, travel, frames.shift)
  local outlet = attached(state.mount, state.bay, forward, tail)
  local bearing, length = Effects.bearings[state.facing], .45 + 3.6 * fraction ^ 1.4
  if state.trail.valid and state.trail.type == "line" then
    state.trail.destroy()
    state.trail = Effects.plume(state.surface, "torpedo", outlet, bearing, length,
      math.ceil(state.duration * (1 - fraction)))
    state.effects[2] = state.trail
  elseif state.trail.valid then
    Effects.move_plume(state.trail, outlet, bearing, length)
  end
end

function M.tick(event, resolve)
  local active = states()
  for unit, state in pairs(active) do
    local elapsed = event.tick - state.start
    local mounted = Visuals.platform(state.mount) and state.mount.surface == state.surface
    if not state.visuals_done and (not mounted or elapsed >= state.duration) then
      for _, effect in ipairs(state.effects) do
        if effect.valid then effect.destroy() end
      end
      state.effects, state.visuals_done = {}, true
    elseif not state.visuals_done then
      if state.kind == "lance" then
        update_lance(state, elapsed)
      elseif state.kind == "torpedo" and state.projectile.valid then
        update_torpedo(state, elapsed / state.duration)
      elseif state.field and state.field.valid then
        local fraction = elapsed / state.duration
        state.field.radius = .35 + 3.3 * fraction
        state.field.color = {.62, .39, 1., .72 * (1 - fraction)}
      end
    end

    local shot = state.shot
    if shot and (event.tick >= shot.impact_tick or (state.kind == "lance" and not mounted)) then
      state.shot = nil
      resolve(shot, mounted and state.mount or nil)
    end
    if state.visuals_done and not state.shot then active[unit] = nil end
  end
end

return M
