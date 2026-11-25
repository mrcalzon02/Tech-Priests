local names = require("scripts.voidship_armory_names")
local weapons = require("scripts.voidship_armory_weapons")
local art = require("prototypes.generated_graphics.voidship_armory")
local graphics = "__tech-priests__/graphics/entity/voidship-armory/"
local faces = {"north", "east", "south", "west"}
local conditions = {
  {property = "gravity", min = 0, max = 0},
  {property = "pressure", min = 0, max = 0},
}
local footprint = {{
  area = {{-1.95, -1.95}, {1.95, 1.95}},
  required_tiles = {layers = {ground_tile = true}},
  colliding_tiles = {layers = {empty_space = true}},
  remove_on_collision = true,
}}

local function picture(file, size, shift)
  return {filename = graphics .. file, width = size, height = size, scale = .5, shift = shift}
end

local function foundation(entity, name, icon)
  entity.name = name
  entity.icon, entity.icon_size, entity.icons = graphics .. icon, 64, nil
  entity.flags = {"placeable-player", "player-creation"}
  entity.collision_box = {{-1.9, -1.9}, {1.9, 1.9}}
  entity.selection_box = {{-2, -2}, {2, 2}}
  entity.tile_width, entity.tile_height = 4, 4
  entity.drawing_box_vertical_extension = 2
  entity.surface_conditions = table.deepcopy(conditions)
  entity.tile_buildability_rules = table.deepcopy(footprint)
  entity.minable = {mining_time = .75, result = name}
  entity.fast_replaceable_group = nil
  entity.circuit_connector = nil
  entity.circuit_wire_max_distance = 0
end

local function unlock(tech, recipe)
  local technology = data.raw.technology[tech]
  technology.effects = technology.effects or {}
  table.insert(technology.effects, {type = "unlock-recipe", recipe = recipe})
end

local function device(entity, tech, seconds, ingredients, stack)
  local name = entity.name
  data:extend{entity,
    {type = "item", name = name, icon = entity.icon, icon_size = 64, subgroup = "defensive-structure",
     order = "z[tech-priests-voidship]-" .. name, stack_size = stack or 5, place_result = name},
    {type = "recipe", name = name, enabled = false, energy_required = seconds, ingredients = ingredients,
     results = {{type = "item", name = name, amount = 1}}, surface_conditions = table.deepcopy(conditions)},
  }
  unlock(tech, name)
end

local function hidden_power_intake(name, icon, capacity, input_limit, priority)
  data:extend{{
    type = "electric-energy-interface", name = name, icon = icon, icon_size = 64,
    flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-selectable-in-game", "placeable-off-grid"},
    hidden = true, hidden_in_factoriopedia = true, selectable_in_game = false,
    collision_box = {{0, 0}, {0, 0}}, collision_mask = {layers = {}},
    selection_box = {{0, 0}, {0, 0}}, max_health = 1, gui_mode = "none",
    surface_conditions = table.deepcopy(conditions),
    energy_source = {type = "electric", buffer_capacity = capacity, usage_priority = priority,
                     input_flow_limit = input_limit, output_flow_limit = "0W", drain = "0W",
                     render_no_network_icon = false, render_no_power_icon = false},
    energy_production = "0W", energy_usage = "0W",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
  }}
end

local function deck_and_cap(entity, design)
  local model = art[design]
  local base = {}
  for _, direction in ipairs(faces) do
    base[direction] = picture(design .. "/base-" .. direction .. ".png", model.cell, model.shift)
  end
  entity.picture = base
  for heading = 0, model.heading_count - 1 do
    local view = model.headings[heading + 1]
    data:extend{{
      type = "animation", name = string.format("tp-voidship-%s-%02d", design, heading),
      filename = graphics .. design .. "/" .. view.file,
      width = view.width, height = view.height, scale = .5, shift = view.shift,
      frame_count = model.frame_count, line_length = view.line_length,
    }}
  end
end

local cannon = table.deepcopy(data.raw.container["steel-chest"])
foundation(cannon, names.macro, "macro-cannon-icon.png")
cannon.max_health = 2400
cannon.direction_count = 4
cannon.inventory_size = 6
cannon.inventory_type = "with_filters_and_bar"
cannon.quality_affects_inventory_size = false
deck_and_cap(cannon, "macro-cannon")
device(cannon, "artillery", 45, {{type = "item", name = "artillery-turret", amount = 1},
                           {type = "item", name = "processing-unit", amount = 24},
                           {type = "item", name = "low-density-structure", amount = 32}})

local hull_recipe = {{type = "item", name = "low-density-structure", amount = 24},
                     {type = "item", name = "processing-unit", amount = 12}}
local lance = {type = "simple-entity-with-owner", max_health = 2000}
foundation(lance, names.lance, "lance-battery-icon.png")
deck_and_cap(lance, "lance-battery")
device(lance, "space-platform", 25, hull_recipe)

hidden_power_intake(names.lance_capacitor, lance.icon, "6MJ", "2MW", "secondary-input")

local launcher = {type = "simple-entity-with-owner", max_health = 2000, picture = {}}
foundation(launcher, names.launcher, "prow-launcher-icon.png")
for _, direction in ipairs(faces) do
  launcher.picture[direction] = picture("prow-launcher-" .. direction .. ".png", 384, {0, -.7071067812})
  data:extend{{
    type = "sprite", name = "tech-priests-voidship-censer-" .. direction,
    filename = graphics .. "plasma-torpedo-" .. direction .. ".png",
    width = 384, height = 384, scale = .5,
  }}
end
device(launcher, "space-platform", 25, table.deepcopy(hull_recipe))

data:extend{
  {type = "item", name = names.torpedo, icon = graphics .. "plasma-torpedo-icon.png", icon_size = 64,
   subgroup = "ammo", order = "z[tech-priests-voidship]-censer", stack_size = 20},
  {type = "recipe", name = names.torpedo, enabled = false, energy_required = 15,
   surface_conditions = table.deepcopy(conditions),
   ingredients = {{type = "item", name = "low-density-structure", amount = 4},
                  {type = "item", name = "explosives", amount = 8},
                  {type = "item", name = "battery", amount = 4},
                  {type = "item", name = "uranium-235", amount = 1}},
   results = {{type = "item", name = names.torpedo, amount = 1}}},
}
unlock("space-platform", names.torpedo)

local shield = table.deepcopy(data.raw.accumulator.accumulator)
foundation(shield, names.shield, "void-shield-icon.png")
shield.max_health = 750
shield.minable.mining_time = .4
shield.flags[#shield.flags + 1] = "not-rotatable"
shield.water_reflection, shield.working_sound = nil, nil
shield.energy_source = {type = "electric", buffer_capacity = "25MJ", usage_priority = "tertiary",
                        input_flow_limit = "0W", output_flow_limit = "0W"}
shield.chargable_graphics = {picture = picture("void-shield.png", 384, {0, -.7071067812})}
device(shield, "space-platform", 20, {{type = "item", name = "accumulator", amount = 4},
                                     {type = "item", name = "processing-unit", amount = 12},
                                     {type = "item", name = "low-density-structure", amount = 12}}, 10)
-- Holds one 12-tick interval of raw grid input. The visible accumulator
-- holds the usable field charge after upkeep and conversion losses.
hidden_power_intake(names.shield_intake, shield.icon, "240kJ", "1.2MW", "secondary-input")

local function incoming_round(name, icon, health, radius)
  local blank = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
  -- A small hostile unit gives ordinary Factorio defenses a damageable target.
  -- The flight controller moves it with native AI disabled.
  data:extend{{
    type = "unit", name = name, icon = icon, icon_size = 64,
    hidden = true, hidden_in_factoriopedia = true,
    flags = {"placeable-off-grid", "not-repairable"},
    surface_conditions = table.deepcopy(conditions),
    -- is_object is also used by line attacks such as the native railgun.
    collision_mask = {layers = {is_object = true}},
    trigger_target_mask = {"common"},
    collision_box = {{-radius, -radius}, {radius, radius}},
    selection_box = {{-radius, -radius}, {radius, radius}},
    max_health = health, movement_speed = .1, distance_per_frame = .1,
    vision_distance = 0, distraction_cooldown = 60, run_animation = blank,
    attack_parameters = {type = "projectile", range = .1, cooldown = 60, ammo_category = "bullet",
                         ammo_type = {}, animation = table.deepcopy(blank)},
  }}
end

incoming_round(names.macro_round, "__base__/graphics/icons/artillery-shell.png", 70, .22)
incoming_round(names.torpedo_round, graphics .. "plasma-torpedo-icon.png", 150, .35)
local shell = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"].picture)
shell.type, shell.name = "sprite", "tech-priests-voidship-macro-round"
data:extend{shell}

for _, sheet in ipairs({
  {"macro-plume", 72, 320, 8, 4},
  {"plasma-plume", 72, 320, 8, 4},
  {"wake-mote", 32, 32, 6, 3},
  {"entry-flash", 128, 128, 8, 4},
}) do
  local name, width, height, count, columns = table.unpack(sheet)
  data:extend{{type = "animation", name = "tp-voidship-fx-" .. name,
    filename = graphics .. "effects/" .. name .. ".png", width = width, height = height,
    frame_count = count, line_length = columns, blend_mode = "additive-soft", draw_as_glow = true}}
end

for _, mark in ipairs({{"target-brackets", 256, 256}, {"target-cell", 128, 128}, {"target-label", 320, 52}}) do
  local name, width, height = table.unpack(mark)
  data:extend{{type = "sprite", name = "tp-voidship-fx-" .. name,
    filename = graphics .. "effects/" .. name .. ".png", width = width, height = height}}
end

for _, mount in ipairs({names.macro, names.launcher}) do
  local weapon = weapons[mount]
  -- A direct hit follows the selected asteroid through the native projectile
  -- simulation. The armory renderer supplies its existing body and wake.
  data:extend{{type = "projectile", name = weapon.asteroid_projectile, hidden = true,
    flags = {"not-on-map"}, acceleration = weapon.asteroid_acceleration,
    max_speed = weapon.asteroid_max_speed, turn_speed = weapon.asteroid_turn_speed,
    hit_at_collision_position = true, hit_collision_mask = {layers = {}},
    animation = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
    action = {type = "direct", action_delivery = {type = "instant", target_effects = {
      {type = "damage", damage = {amount = weapon.damage, type = weapon.damage_type}},
      {type = "create-entity", entity_name = "medium-explosion", only_when_visible = true},
    }}},
  }}
end
