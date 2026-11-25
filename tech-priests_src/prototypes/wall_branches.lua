local stone = data.raw.wall["stone-wall"]
local stone_item = data.raw.item["stone-wall"]

local function resistance_for(rows, damage_type)
  for _, row in ipairs(rows) do
    if row.type == damage_type then return row end
  end
  local row = {type = damage_type, decrease = 0, percent = 0}
  rows[#rows + 1] = row
  return row
end

local function set_resistance(rows, damage_type, values)
  local row = resistance_for(rows, damage_type)
  row.decrease, row.percent = values[1], values[2]
end

stone.resistances = stone.resistances or {}
for _, row in ipairs({
  {"tech-priests-penetration", 0, 10},
  {"tech-priests-bolt", 3, 20},
  {"tech-priests-power-field", 0, 10},
  {"tech-priests-radiation", 0, 0},
  {"tech-priests-thermal-ray", 0, 25},
  {"tech-priests-gravitic", 0, 0},
}) do
  set_resistance(stone.resistances, row[1], {row[2], row[3]})
end

local branches = {
  {
    id = "bastion",
    map_colors = {{0.94, 0.77, 0.44}, {0.94, 0.63, 0.28}, {0.94, 0.47, 0.17}},
    materials = {
      {{"steel-plate", 2}, {"concrete", 2}},
      {{"refined-concrete", 3}, {"steel-plate", 2}, {"advanced-circuit", 1}},
      {{"refined-concrete", 4}, {"steel-plate", 3}, {"low-density-structure", 2}},
    },
    prerequisites = {{"concrete", "military-science-pack"}, {"chemical-science-pack"}},
    resistances = {
      {"physical", {5, 30}, {6, 40}, {7, 50}},
      {"impact", {50, 65}, {55, 70}, {60, 75}},
      {"tech-priests-penetration", {5, 32}, {9, 47}, {14, 60}},
      {"tech-priests-bolt", {5, 30}, {7, 42}, {9, 54}},
    },
  },
  {
    id = "ablative",
    map_colors = {{0.68, 0.91, 0.41}, {0.48, 0.89, 0.37}, {0.29, 0.86, 0.44}},
    materials = {
      {{"concrete", 2}, {"plastic-bar", 2}, {"steel-plate", 1}},
      {{"refined-concrete", 2}, {"uranium-238", 1}, {"plastic-bar", 2}},
      {{"uranium-238", 2}, {"refined-concrete", 3}, {"low-density-structure", 2}},
    },
    prerequisites = {{"concrete", "plastics", "military-science-pack"}, {"chemical-science-pack", "uranium-processing"}},
    resistances = {
      {"explosion", {14, 40}, {18, 50}, {22, 60}},
      {"acid", {0, 85}, {0, 90}, {0, 92}},
      {"poison", {0, 45}, {0, 65}, {0, 80}},
      {"tech-priests-radiation", {0, 45}, {0, 62}, {0, 75}},
      {"tech-priests-thermal-ray", {0, 45}, {0, 60}, {0, 72}},
    },
  },
  {
    id = "warded",
    map_colors = {{0.59, 0.80, 1}, {0.40, 0.65, 1}, {0.49, 0.45, 1}},
    materials = {
      {{"copper-plate", 4}, {"battery", 1}, {"electronic-circuit", 1}},
      {{"copper-plate", 4}, {"battery", 2}, {"processing-unit", 1}},
      {{"processing-unit", 2}, {"battery", 2}, {"low-density-structure", 2}},
    },
    prerequisites = {{"battery", "electric-energy-distribution-1", "military-science-pack"},
      {"electric-energy-distribution-2", "processing-unit"}},
    resistances = {
      {"laser", {0, 76}, {0, 83}, {0, 89}},
      {"electric", {0, 38}, {0, 56}, {0, 72}},
      {"tech-priests-power-field", {2, 35}, {4, 50}, {6, 65}},
      {"tech-priests-gravitic", {0, 30}, {0, 46}, {0, 60}},
    },
  },
}

local packs = {"automation-science-pack", "logistic-science-pack", "military-science-pack",
  "chemical-science-pack", "production-science-pack", "utility-science-pack"}
local tiers = {
  {health = 450, research = 125, pack_count = 3, craft_time = 2},
  {health = 575, research = 350, pack_count = 4, craft_time = 4},
  {health = 725, research = 900, pack_count = 6, craft_time = 8},
}

local definitions = {
  {type = "item-subgroup", name = "tech-priests-wall-branches", group = "tech-priests", order = "f[wall-branches]"},
}
local original_stone = {}
for _, row in ipairs(stone.resistances) do original_stone[row.type] = table.deepcopy(row) end
local wall_profiles = {}
for branch_index, branch in ipairs(branches) do
  local prefix = "tech-priests-wall-" .. branch.id .. "-"
  for tier, stats in ipairs(tiers) do
    local name = prefix .. tier
    local predecessor = tier == 1 and "stone-wall" or prefix .. (tier - 1)
    local order = branch_index .. "-" .. tier
    local label = {"entity-name." .. name}
    local description = {"tech-priests-wall." .. branch.id}

    local wall = table.deepcopy(stone)
    wall.name = name
    wall.localised_name, wall.localised_description = label, description
    wall.minable.result = name
    wall.max_health = stats.health
    wall.next_upgrade = tier < #tiers and prefix .. (tier + 1) or nil
    wall.map_color = branch.map_colors[tier]
    local specialties = {}
    for _, row in ipairs(branch.resistances) do
      local damage_type, profile = row[1], row[tier + 1]
      set_resistance(wall.resistances, damage_type, profile)
      specialties[damage_type] = profile
    end
    wall_profiles[name] = specialties
    definitions[#definitions + 1] = wall

    local item = table.deepcopy(stone_item)
    item.name, item.place_result = name, name
    item.localised_name, item.localised_description = label, description
    item.subgroup, item.order = "tech-priests-wall-branches", order
    definitions[#definitions + 1] = item

    local ingredients = {{type = "item", name = predecessor, amount = 1}}
    for _, material in ipairs(branch.materials[tier]) do
      ingredients[#ingredients + 1] = {type = "item", name = material[1], amount = material[2]}
    end
    definitions[#definitions + 1] = {
      type = "recipe", name = name, enabled = false, energy_required = stats.craft_time,
      allow_productivity = false, main_product = name, ingredients = ingredients,
      results = {{type = "item", name = name, amount = 1}},
    }

    local prerequisites = {predecessor}
    for _, tech in ipairs(branch.prerequisites[tier] or {"production-science-pack", "utility-science-pack"}) do
      prerequisites[#prerequisites + 1] = tech
    end
    local science = {}
    for index = 1, stats.pack_count do science[index] = {packs[index], 1} end
    definitions[#definitions + 1] = {
      type = "technology", name = name, prerequisites = prerequisites, order = "z[wall-branches]-" .. order,
      localised_name = label, localised_description = description,
      icon = "__base__/graphics/technology/stone-wall.png", icon_size = 256,
      effects = {{type = "unlock-recipe", recipe = name}},
      unit = {count = stats.research, time = 30, ingredients = science},
    }
  end
end
data:extend(definitions)

local M = {}

function M.inherit_final_resistances()
  -- Late compatibility edits to Stone Wall also apply to its upgrade paths.
  -- Keep any edits another mod applied directly to a branch. Scale the
  -- specialty to the damage still passing through the upgraded baseline.
  for name, specialties in pairs(wall_profiles) do
    local wall = data.raw.wall[name]
    for _, stone_row in ipairs(stone.resistances) do
      local damage_type = stone_row.type
      local flat, percent = stone_row.decrease or 0, stone_row.percent or 0
      local specialty = specialties[damage_type]
      if specialty then
        local before = original_stone[damage_type] or {}
        local prior_percent = before.percent or 0
        flat = flat + math.max(0, specialty[1] - (before.decrease or 0))
        if prior_percent < 100 and specialty[2] > prior_percent then
          percent = 100 - (100 - percent) * (100 - specialty[2]) / (100 - prior_percent)
        end
      end
      local row = resistance_for(wall.resistances, damage_type)
      row.decrease = math.max(flat, row.decrease or 0)
      row.percent = math.max(percent, row.percent or 0)
    end
  end
end

return M
