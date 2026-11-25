-- A cardinal foundation and a world-heading cap share the FMPL mount origin.
local names = require("scripts.voidship_armory_names")
local art = require("prototypes.generated_graphics.voidship_armory")
local M = {}
local types = {[names.macro] = "macro-cannon", [names.lance] = "lance-battery"}
local base_headings = {[defines.direction.north] = 0, [defines.direction.east] = 16,
                       [defines.direction.south] = 32, [defines.direction.west] = 48}

local function state()
  storage.tech_priests_voidship_caps = storage.tech_priests_voidship_caps
    or {mounts = {}, registrations = {}, moving = {}}
  return storage.tech_priests_voidship_caps
end

function M.platform(entity)
  if not (entity and entity.valid) then return end
  local platform = entity.surface.platform
  if platform and platform.valid and platform.scheduled_for_deletion == 0
      and platform.force.index == entity.force.index then return platform end
end

local function draw(record, heading, frame)
  local art_name = string.format("tp-voidship-%s-%02d", record.design, heading)
  local image, entity = record.image, record.entity
  if image and image.valid and image.surface ~= entity.surface then image.destroy() end
  if not (image and image.valid) then
    image = rendering.draw_animation{
      animation = art_name, target = entity, surface = entity.surface,
      animation_speed = 0, animation_offset = frame, render_layer = "higher-object-above",
      tint = record.ghost and {.55, .77, 1., .48} or nil,
    }
    record.image = image
  else
    if image.animation ~= art_name then image.animation = art_name end
    if image.animation_offset ~= frame then image.animation_offset = frame end
  end
  record.visual_heading, record.frame = heading, frame
end

local function remove(unit)
  local s = state()
  local record = s.mounts[unit]
  if record then
    if record.image and record.image.valid then record.image.destroy() end
    s.registrations[record.registration], s.mounts[unit], s.moving[unit] = nil, nil, nil
  end
end

function M.add(entity)
  if not (entity and entity.valid and entity.unit_number) then return end
  local ghost = entity.name == "entity-ghost"
  local design = types[ghost and entity.ghost_name or entity.name]
  if not design then return end
  local unit = entity.unit_number
  if not M.platform(entity) then remove(unit); return end
  local s = state()
  local record = s.mounts[unit]
  if not record then
    local id = script.register_on_object_destroyed(entity)
    record = {entity = entity, design = design, heading = base_headings[entity.direction] or 0,
              ghost = ghost, registration = id}
    s.mounts[unit], s.registrations[id] = record, unit
  elseif ghost then
    record.heading = base_headings[entity.direction] or record.heading
  end
  local motion = s.moving[unit]
  draw(record, motion and motion.heading or record.heading, motion and record.frame or 0)
  return record
end

function M.destroyed(event)
  local unit = state().registrations[event.registration_number]
  if unit then remove(unit) end
end

local function heading_for(record, degrees)
  local count = art[record.design].heading_count
  return math.floor((degrees % 360) / 360 * count + .5) % count
end

function M.aim(entity, degrees)
  if type(degrees) ~= "number" or degrees ~= degrees or math.abs(degrees) == math.huge then
    return nil, "invalid-heading"
  end
  local record = M.add(entity)
  if not record or record.ghost then return nil, "invalid-mount" end
  record.heading = heading_for(record, degrees)
  if not state().moving[entity.unit_number] then draw(record, record.heading, 0) end
  return record.heading
end

function M.track_lance(entity, degrees)
  local s, unit = state(), entity.unit_number
  local record, motion = s.mounts[unit], s.moving[unit]
  if not (record and motion and record.design == "lance-battery") then return end
  local heading = heading_for(record, degrees)
  record.heading, motion.heading = heading, heading
  if record.visual_heading ~= heading then draw(record, heading, record.frame) end
end

function M.begin(entity)
  local record = M.add(entity)
  if not record or record.ghost then return end
  state().moving[entity.unit_number] = {tick = game.tick, heading = record.heading}
  draw(record, record.heading, 0)
  local model = art[record.design]
  return record.heading, model.headings[record.heading + 1].sockets[1], #model.lookup
end

function M.lance_sockets(entity, frame)
  local record = state().mounts[entity.unit_number]
  if not record or record.design ~= "lance-battery" then return end
  local model, d = art[record.design], record.visual_heading
  local q = d * math.pi * 2 / model.heading_count
  local elevation = math.rad(model.elevations[frame])
  local forward = {math.sin(q) * math.cos(elevation),
                   -(math.cos(q) * math.cos(elevation) + math.sin(elevation)) / math.sqrt(2)}
  return model.headings[d + 1].sockets[frame], forward
end

function M.tick(event)
  local s = state()
  for unit, motion in pairs(s.moving) do
    local record = s.mounts[unit]
    local age = event.tick - motion.tick
    if not record.entity.valid or not M.platform(record.entity) then
      remove(unit)
    else
      local timeline = art[record.design].lookup
      local frame = timeline[age + 1]
      if frame then
        if record.frame ~= frame or not record.image.valid then draw(record, motion.heading, frame) end
      else
        s.moving[unit] = nil
        draw(record, record.heading, 0)
      end
    end
  end
end

function M.status(entity)
  if not (entity and entity.valid) then return end
  local record = state().mounts[entity.unit_number]
  if record then
    return {heading = record.heading, displayed_heading = record.visual_heading,
            frame = record.frame, base_direction = entity.direction}
  end
end

function M.init()
  state()
  local mounts = {names.macro, names.lance}
  for _, surface in pairs(game.surfaces) do
    if surface.platform then
      for _, entity in ipairs(surface.find_entities_filtered{name = mounts}) do M.add(entity) end
      for _, ghost in ipairs(surface.find_entities_filtered{type = "entity-ghost", ghost_name = mounts}) do
        M.add(ghost)
      end
    end
  end
end

return M
