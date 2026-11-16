local art_root = "__mars-reactor-visuals__/graphics/"
local quality = settings.startup["mars-reactor-sprite-resolution"].value
local regions = require("sprite-regions")[quality]
local directions = {"north", "east", "south", "west"}
local classes = {
  {id = "minoris", footprint = 4, megawatts = 1},
  {id = "majoris", footprint = 6, megawatts = 2},
  {id = "maximus", footprint = 8, megawatts = 4}
}

local function picture(class, dir, role)
  local region = regions[class.id][dir][role]
  local moving = role == "on" or role == "glow"
  local p = {
    filename = art_root .. quality .. "/" .. class.id .. "/" .. dir .. "-" .. role .. ".png",
    width = region.width,
    height = region.height,
    line_length = moving and 4 or 1,
    frame_count = moving and 16 or 1,
    -- The burner-generator requires equivalent idle and running cycle lengths.
    repeat_count = moving and 1 or 16,
    animation_speed = 8 / 60,
    scale = quality == "hr" and 0.5 or 1,
    shift = region.shift
  }
  if role == "glow" then
    p.draw_as_glow = true
    p.blend_mode = "additive"
  elseif role == "shadow" then
    p.draw_as_shadow = true
  end
  return p
end

local function directional(class, active)
  local animation = {}
  for _, dir in ipairs(directions) do
    local layers = {picture(class, dir, "shadow")}
    table.insert(layers, picture(class, dir, active and "on" or "off"))
    if active then table.insert(layers, picture(class, dir, "glow")) end
    animation[dir] = {layers = layers}
  end
  return animation
end

for _, class in ipairs(classes) do
  local name = "mars-plasma-reactor-" .. class.id
  local icon = art_root .. "icons/" .. class.id .. ".png"
  local half = class.footprint / 2
  local generator = table.deepcopy(data.raw["burner-generator"]["burner-generator"])
  generator.name = name
  generator.hidden = false
  generator.icon = icon
  generator.icon_size = 64
  generator.minable = {mining_time = 0.35, result = name}
  generator.collision_box = {{-half + 0.15, -half + 0.15}, {half - 0.15, half - 0.15}}
  generator.selection_box = {{-half, -half}, {half, half}}
  generator.max_power_output = tostring(class.megawatts) .. "MW"
  generator.burner.effectivity = 1.0
  generator.burner.smoke = nil
  generator.burner.emissions_per_minute = nil
  generator.corpse = nil
  generator.working_sound = nil
  generator.perceived_performance = {minimum = 1, maximum = 1}
  generator.animation = directional(class, true)
  generator.idle_animation = directional(class, false)
  generator.always_draw_idle_animation = false
  data:extend({
    generator,
    {
      type = "item", name = name, icon = icon, icon_size = 64,
      subgroup = "energy", order = "z[mars-reactor]-" .. class.id,
      place_result = name, stack_size = 10
    },
    {
      type = "recipe", name = name, enabled = true, energy_required = 0.5,
      ingredients = {{type = "item", name = "iron-plate", amount = 1}},
      results = {{type = "item", name = name, amount = 1}}
    }
  })
end
