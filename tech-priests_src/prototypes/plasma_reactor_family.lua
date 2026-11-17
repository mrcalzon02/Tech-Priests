-- The native burner-generator selects the operating or idle graphics from fuel and electrical load.
local art_root = "__tech-priests__/graphics/entity/plasma-reactor-family/"
local quality = settings.startup["tech-priests-reactor-sprite-resolution"].value
local regions = require("prototypes.generated_graphics.plasma_reactor_regions")[quality]
local directions = {"north", "east", "south", "west"}
local plasma_fuel_category = "tp-metallicized-hydrogen"

-- Apply the fuel contract after data.lua, including when upgrading from the standalone prototypes.
data:extend({{type = "fuel-category", name = plasma_fuel_category}})
local sealed_pellet = data.raw["item-with-tags"]["tp-mh7-contained-metallicized-pellet"]
sealed_pellet.fuel_categories = {plasma_fuel_category}
sealed_pellet.fuel_value = "240MJ"
sealed_pellet.weight = 100 * kg
sealed_pellet.burnt_result = nil
sealed_pellet.localised_description = {"item-description.tp-mh7-contained-metallicized-pellet"}
if mods["tp-mh7-pellet-decay"] then
  local inert = data.raw.item["tp-mh7-inert-pellet"]
  inert.localised_name = {"item-name." .. inert.name}
  inert.localised_description = {"item-description." .. inert.name}
end

local function ingredient(name, amount)
  return {type = "item", name = name, amount = amount}
end

local classes = {
  {
    id = "minoris", footprint = 4, megawatts = 1, craft_time = 10,
    technology = "cogitator-station-deployment",
    ingredients = {
      ingredient("steam-engine", 1), ingredient("steel-plate", 20),
      ingredient("copper-cable", 40), ingredient("pipe", 10)
    }
  },
  {
    id = "majoris", footprint = 6, megawatts = 2, craft_time = 20,
    technology = "intermediate-cogitator-stations",
    ingredients = {
      ingredient("mars-plasma-reactor-minoris", 1), ingredient("steel-plate", 30),
      ingredient("pipe", 20), ingredient("advanced-circuit", 10)
    }
  },
  {
    id = "maximus", footprint = 8, megawatts = 4, craft_time = 40,
    technology = "senior-cogitator-stations",
    ingredients = {
      ingredient("mars-plasma-reactor-majoris", 1), ingredient("steel-plate", 60),
      ingredient("pipe", 40), ingredient("advanced-circuit", 20)
    }
  }
}

local function picture(class, heading, role)
  local region = regions[class.id][heading][role]
  local moving = role == "on" or role == "glow"
  local layer = {
    filename = art_root .. quality .. "/" .. class.id .. "/" .. heading .. "-" .. role .. ".png",
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
    layer.draw_as_glow = true
    layer.blend_mode = "additive"
  elseif role == "shadow" then
    layer.draw_as_shadow = true
  end
  return layer
end

local function directional(class, active)
  local animation = {}
  for _, heading in ipairs(directions) do
    local layers = {picture(class, heading, "shadow")}
    table.insert(layers, picture(class, heading, active and "on" or "off"))
    if active then table.insert(layers, picture(class, heading, "glow")) end
    animation[heading] = {layers = layers}
  end
  return animation
end

for index, class in ipairs(classes) do
  -- Retain the preview's prototype names and types so existing entities, inventories and blueprints resolve.
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
  -- The enclosed reactor operates on both planet surfaces and platform foundations.
  generator.surface_conditions = {}
  generator.max_power_output = class.megawatts .. "MW"
  generator.burner.fuel_categories = {"chemical", plasma_fuel_category}
  generator.burner.effectivity = 1
  generator.burner.smoke = nil
  generator.burner.emissions_per_minute = nil
  generator.corpse = nil
  generator.perceived_performance = {minimum = 1, maximum = 1}
  generator.animation = directional(class, true)
  generator.idle_animation = directional(class, false)
  generator.always_draw_idle_animation = false

  local item = {
    type = "item", name = name, icon = icon, icon_size = 64,
    subgroup = "energy", order = "z[mars-reactor]-" .. index,
    place_result = name, stack_size = 10,
    localised_name = {"entity-name." .. name},
    localised_description = {"entity-description." .. name}
  }
  local recipe = {
    type = "recipe", name = name, enabled = false, energy_required = class.craft_time,
    ingredients = class.ingredients, results = {ingredient(name, 1)},
    localised_name = {"entity-name." .. name}
  }
  data:extend({generator, item, recipe})
  table.insert(data.raw.technology[class.technology].effects, {type = "unlock-recipe", recipe = name})
end
