local M = {bearings = {north = 0, east = .25, south = .5, west = .75}}
local prefix = "tp-voidship-fx-"
local layer = "higher-object-above"
local cycle = 2 * math.pi
local exhaust = {
  macro = {animation = "macro-plume", width = 1.55, length = 8.7, speed = .53, interval = 6,
    spread = .31, size = .38, mote = {1, .54, .22}},
  torpedo = {animation = "plasma-plume", width = 2.65, length = 12.4, speed = .34, interval = 4,
    spread = .53, size = .74, mote = {.42, .67, 1}},
}

local function plume_target(root, bearing, length)
  local angle = bearing * cycle
  return {entity = root.entity, offset = {
    root.offset[1] - math.sin(angle) * length * .5,
    root.offset[2] + math.cos(angle) * length * .5,
  }}
end

function M.plume(surface, kind, root, bearing, length, duration)
  local art = exhaust[kind]
  return rendering.draw_animation{animation = prefix .. art.animation, surface = surface,
    target = plume_target(root, bearing, length), orientation = bearing, render_layer = layer,
    sprite_width = art.width, sprite_height = length, animation_speed = art.speed, time_to_live = duration}
end

function M.move_plume(image, root, bearing, length)
  image.target = plume_target(root, bearing, length)
  image.sprite_height = length
end

local function wake_length(art, age)
  return art.length * (.30 + .70 * math.min(1, age / 19))
end

function M.wake(surface, kind, root, bearing, age)
  return M.plume(surface, kind, root, bearing, wake_length(exhaust[kind], age))
end

function M.update_wake(shot, surface, kind, tick)
  local art, age = exhaust[kind], tick - shot.entry_tick
  if age <= 21 and age % 3 == 0 and shot.wake.valid then
    M.move_plume(shot.wake, shot.outlet, shot.bearing, wake_length(art, age))
  end
  if age < 5 or age % art.interval ~= 0 then return end
  local phase = shot.id * 2.39 + age * .91
  local drift = math.sin(phase) * art.spread
  local distance = .48 + .54 * (1 + math.cos(phase * 1.31))
  local pos, offset = shot.round.position, shot.outlet.offset
  local size = art.size * (.61 + .38 * (1 + math.sin(phase * 1.77)))
  rendering.draw_animation{animation = prefix .. "wake-mote", surface = surface,
    target = {pos.x + offset[1] - shot.dx * distance + shot.dy * drift,
              pos.y + offset[2] - shot.dy * distance - shot.dx * drift},
    orientation = shot.bearing, sprite_width = size, sprite_height = size * 1.8, render_layer = layer,
    tint = {art.mote[1], art.mote[2], art.mote[3], .42 + .20 * math.cos(phase)},
    animation_speed = .29, time_to_live = 20}
end

function M.flash(surface, position, color, size)
  rendering.draw_light{sprite = "utility/light_medium", surface = surface, target = position,
    scale = size, intensity = 1, minimum_darkness = 0, color = color, time_to_live = 10}
  rendering.draw_animation{animation = prefix .. "entry-flash", surface = surface, target = position,
    sprite_width = size, sprite_height = size, tint = color, render_layer = layer,
    animation_speed = .34, time_to_live = 23}
end

function M.update_target(shot, tick)
  local mark = shot.reticle
  local remaining = math.max(0, shot.impact_tick - tick)
  local age = math.max(0, tick - shot.launched_at)
  local duration = shot.impact_tick - shot.launched_at
  local fraction = math.min(1, age / duration)
  local phase = (age / 76 + age * fraction / 82) * cycle
  local pulse = (math.sin(phase) + 1) * .5
  local size = 2.65 + 3.08 * (1 - fraction) ^ .82 + .16 * pulse
  local caption = {shot.target.x, shot.target.y - 1.98 - .23 * size - (shot.label_slot or 0) * .91}
  if mark.brackets.valid then
    mark.brackets.sprite_width, mark.brackets.sprite_height = size, size
    mark.brackets.color = {1, .94 - .22 * fraction, .84 - .34 * fraction, .70 + .28 * pulse}
  end
  if mark.backplate.valid then mark.backplate.target = caption end
  if mark.text.valid then
    local tenth = math.ceil(remaining / 6)
    if tenth ~= mark.tenth then
      mark.text.text = {"tp-voidship.incoming-marker", mark.name, string.format("%.1f", tenth / 10)}
      mark.tenth = tenth
    end
    mark.text.target = caption
  end
end

function M.target(shot, surface, kind, tick)
  local audience = {shot.defender, shot.attacker}
  local function sprite(name, width, height)
    local image = rendering.draw_sprite{sprite = prefix .. name, surface = surface, target = shot.target,
      sprite_width = width, sprite_height = height, render_layer = layer, forces = audience}
    shot.effects[#shot.effects + 1] = image
    return image
  end
  local mark = {
    brackets = sprite("target-brackets", 5.75, 5.75),
    backplate = sprite("target-label", 7.4, .86),
    name = {"tp-voidship.marker-" .. kind},
  }
  sprite("target-cell", 1.28, 1.28)
  mark.text = rendering.draw_text{surface = surface, target = shot.target, text = mark.name,
    color = {1, .89, .67}, alignment = "center", vertical_alignment = "middle", scale = .95,
    font = "default-bold", forces = audience}
  shot.effects[#shot.effects + 1] = mark.text
  shot.reticle = mark
  M.update_target(shot, tick)
end

return M
