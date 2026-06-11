-- Tech Priests - final prototype correction stage.
-- Keep last-pass prototype edits here.

-- 0.1.641: final prototype correction for the emergency micro-miner. It is a
-- bootstrap pseudo-miner and should cost painful time, not fuel logistics.
require("prototypes.emergency_miner_no_fuel_0641")

-- Consecration waste slot support.
--
-- Factorio assembler output inventories are effectively recipe-product filtered.
-- Increasing result_inventory_size adds room, but it does not make the output
-- inventory accept arbitrary items. To give Mechanical Detritus a real output
-- slot that the script can insert into, every item-producing recipe receives a
-- zero-probability Mechanical Detritus product. The engine should never create
-- it by itself, but the item becomes a valid product for the assembler output
-- inventory, allowing the runtime sanctification system to insert Detritus and
-- jam the machine if the player ignores the trash.

local DETRITUS_NAME = "mechanical-detritus"


local function collect_player_handcraft_categories()
  local categories = { crafting = true }
  for _, character in pairs(data.raw.character or {}) do
    if type(character.crafting_categories) == "table" then
      for _, category in pairs(character.crafting_categories) do
        if type(category) == "string" then
          categories[category] = true
        end
      end
    end
  end
  return categories
end

local PLAYER_HANDCRAFT_CATEGORIES = collect_player_handcraft_categories()

local function recipe_category(recipe)
  return (recipe and recipe.category) or "crafting"
end

local function recipe_is_player_handcraftable(recipe)
  return PLAYER_HANDCRAFT_CATEGORIES[recipe_category(recipe)] == true
end

local function product_name(product)
  if type(product) == "string" then return product end
  if type(product) ~= "table" then return nil end
  return product.name or product[1]
end

local function product_type(product)
  if type(product) == "string" then return "item" end
  if type(product) ~= "table" then return nil end
  return product.type or "item"
end

local function recipe_has_detritus_product(results)
  if type(results) ~= "table" then return false end
  for _, product in pairs(results) do
    if product_name(product) == DETRITUS_NAME then
      return true
    end
  end
  return false
end

local function recipe_has_any_item_product(results)
  if type(results) ~= "table" then return false end
  for _, product in pairs(results) do
    if product_type(product) == "item" then
      return true
    end
  end
  return false
end

local function product_matches_name(product, name)
  if not name then return false end
  return product_name(product) == name
end

local function recipe_primary_product_is_fluid(recipe)
  if not recipe then return false end

  -- If Factorio or another mod has explicitly declared a main_product, trust it.
  -- This prevents mixed-output recipes from being wrongly blocked just because
  -- they happen to have a fluid byproduct somewhere in the results table.
  if recipe.main_product then
    if type(recipe.results) == "table" then
      for _, product in pairs(recipe.results) do
        if product_matches_name(product, recipe.main_product) then
          local name = product_name(product)
          return product_type(product) == "fluid" or (data.raw.fluid and data.raw.fluid[name] ~= nil)
        end
      end
    end
    return data.raw.fluid and data.raw.fluid[recipe.main_product] ~= nil
  end

  -- Legacy single-result recipes are item outputs in this mod pass; legacy
  -- fluid outputs are normally represented through results, not result.
  if recipe.result then return false end

  -- Without an explicit main_product, Factorio's identity for a multi-product
  -- recipe tends to follow the first listed product. Treat a first fluid product
  -- as a fluid-primary recipe and do not inject solid Mechanical Detritus into it.
  if type(recipe.results) == "table" then
    for _, product in pairs(recipe.results) do
      local name = product_name(product)
      if name and name ~= DETRITUS_NAME then
        return product_type(product) == "fluid" or (data.raw.fluid and data.raw.fluid[name] ~= nil)
      end
    end
  end

  return false
end

local function recipe_uses_detritus(recipe)
  local function check_ingredients(ingredients)
    if type(ingredients) ~= "table" then return false end
    for _, ingredient in pairs(ingredients) do
      local name = type(ingredient) == "table" and (ingredient.name or ingredient[1]) or nil
      if name == DETRITUS_NAME then return true end
    end
    return false
  end

  if check_ingredients(recipe.ingredients) then return true end
  if recipe.normal and check_ingredients(recipe.normal.ingredients) then return true end
  if recipe.expensive and check_ingredients(recipe.expensive.ingredients) then return true end
  return false
end

local function recipe_should_receive_detritus_slot(recipe)
  if not recipe then return false end
  if recipe.name == DETRITUS_NAME then return false end
  if recipe.name == "mechanical-detritus-reclamation" then return false end
  if recipe.name == "mechanical-detritus-recycling" then return false end
  if recipe.category == "recycling" then return false end

  -- Keep the zero-probability Mechanical Detritus product slot on item-producing
  -- recipes, including recipes the player can also handcraft. The engine should
  -- not produce probability-0 products during handcrafting, while machines need
  -- this product slot so the runtime sanctification script can insert Detritus
  -- into assembler output inventories and let them clog naturally. Player
  -- inventories are excluded at runtime; the slot exists for machine outputs.

  if recipe_uses_detritus(recipe) then return false end
  if recipe_primary_product_is_fluid(recipe) then return false end
  return true
end

local function convert_legacy_result_to_results(recipe)
  if recipe.results then return end
  if not recipe.result then return end

  recipe.results = {
    {
      type = "item",
      name = recipe.result,
      amount = recipe.result_count or 1
    }
  }
  recipe.result = nil
  recipe.result_count = nil
end

local function add_detritus_product(recipe)
  if not recipe_should_receive_detritus_slot(recipe) then return end

  convert_legacy_result_to_results(recipe)

  if not recipe.results then return end
  if recipe_has_detritus_product(recipe.results) then return end
  if not recipe_has_any_item_product(recipe.results) then return end

  table.insert(recipe.results, {
    type = "item",
    name = DETRITUS_NAME,
    amount = 1,
    probability = 0,
    ignored_by_stats = 1,
    ignored_by_productivity = 1
  })

  -- Multi-product recipes without a main_product can have their icon/name
  -- behavior changed by Factorio. Preserve the existing recipe identity where
  -- possible by setting main_product to the first non-detritus item product.
  if recipe.main_product == nil then
    for _, product in pairs(recipe.results) do
      local name = product_name(product)
      if name and name ~= DETRITUS_NAME and product_type(product) == "item" then
        recipe.main_product = name
        break
      end
    end
  end
end

for _, recipe in pairs(data.raw.recipe or {}) do
  add_detritus_product(recipe)
end


-- Mechanical Detritus furnace reclamation.
-- This is intentionally dirty, lossy, and compatible: base ores are always
-- considered when present, and modded ore resources discovered from resource
-- prototypes are given a small extra probability so Detritus can occasionally
-- cough up whatever strange geology the active mod set has added.
local function item_exists(name)
  return data.raw.item and data.raw.item[name] ~= nil
end

local function add_product_unique(products, seen, name, probability)
  if not name or seen[name] or not item_exists(name) then return end
  if name == DETRITUS_NAME then return end
  seen[name] = true
  table.insert(products, {
    type = "item",
    name = name,
    amount = 1,
    probability = probability,
    ignored_by_stats = 1,
    ignored_by_productivity = 1
  })
end

local function collect_resource_item_results(resource, out)
  if not (resource and resource.minable) then return end
  local minable = resource.minable
  if minable.result and item_exists(minable.result) then
    out[minable.result] = true
  end
  if type(minable.results) == "table" then
    for _, result in pairs(minable.results) do
      if type(result) == "table" then
        local name = result.name or result[1]
        local rtype = result.type or "item"
        if rtype == "item" and name and item_exists(name) then
          out[name] = true
        end
      end
    end
  end
end

local function make_detritus_reclamation_recipe()
  if data.raw.recipe and data.raw.recipe["mechanical-detritus-reclamation"] then return end

  local products = {}
  local seen = {}

  add_product_unique(products, seen, "iron-ore", 0.55)
  add_product_unique(products, seen, "copper-ore", 0.35)
  add_product_unique(products, seen, "stone", 0.20)
  add_product_unique(products, seen, "coal", 0.10)
  add_product_unique(products, seen, "uranium-ore", 0.005)

  local resource_results = {}
  for _, resource in pairs(data.raw.resource or {}) do
    collect_resource_item_results(resource, resource_results)
  end

  for name in pairs(resource_results) do
    if not seen[name]
      and name ~= "iron-ore"
      and name ~= "copper-ore"
      and name ~= "stone"
      and name ~= "coal"
      and name ~= "uranium-ore"
      and data.raw.item[name]
      and not data.raw.item[name].hidden
      and not data.raw.item[name].hidden_in_factoriopedia
    then
      local lname = string.lower(name)
      local chance = 0.015
      if string.find(lname, "uranium", 1, true) or string.find(lname, "radioactive", 1, true) then
        chance = 0.005
      end
      add_product_unique(products, seen, name, chance)
    end
  end

  if #products == 0 then return end

  data:extend({
    {
      type = "recipe",
      name = "mechanical-detritus-reclamation",
      category = "smelting",
      enabled = true,
      energy_required = 3.2,
      icon = "__tech-priests__/graphics/icons/mechanical-detritus.png",
      icon_size = 64,
      subgroup = "tech-priest-cogitators",
      order = "a[consecration]-c[mechanical-detritus-reclamation]",
      ingredients = {
        { type = "item", name = DETRITUS_NAME, amount = 10 }
      },
      results = products,
      allow_productivity = false,
      allow_decomposition = false,
      auto_recycle = false
    }
  })
end

local function make_detritus_recycling_recipe()
  if not (data.raw["recipe-category"] and data.raw["recipe-category"].recycling) then return end

  local products = {}
  local seen = {}

  -- Space Age already has the correct thematic trash endpoint: scrap.
  -- The exchange is intentionally awful. A full stack of Mechanical Detritus
  -- has only a small chance to become one unit of real Space Age scrap, which
  -- can then be processed by the normal recycler chain.
  if item_exists("scrap") then
    add_product_unique(products, seen, "scrap", 0.25)
  else
    add_product_unique(products, seen, "iron-ore", 0.40)
    add_product_unique(products, seen, "copper-ore", 0.28)
    add_product_unique(products, seen, "stone", 0.18)
    add_product_unique(products, seen, "coal", 0.08)
    add_product_unique(products, seen, "uranium-ore", 0.003)

    local resource_results = {}
    for _, resource in pairs(data.raw.resource or {}) do
      collect_resource_item_results(resource, resource_results)
    end

    for name in pairs(resource_results) do
      if not seen[name]
        and name ~= "iron-ore"
        and name ~= "copper-ore"
        and name ~= "stone"
        and name ~= "coal"
        and name ~= "uranium-ore"
        and data.raw.item[name]
        and not data.raw.item[name].hidden
        and not data.raw.item[name].hidden_in_factoriopedia
      then
        local lname = string.lower(name)
        local chance = 0.01
        if string.find(lname, "uranium", 1, true) or string.find(lname, "radioactive", 1, true) then
          chance = 0.003
        end
        add_product_unique(products, seen, name, chance)
      end
    end
  end

  if #products == 0 then return end

  local recipe = data.raw.recipe and data.raw.recipe["mechanical-detritus-recycling"]
  local patched = recipe or { type = "recipe", name = "mechanical-detritus-recycling" }

  -- Deliberately overwrite any Quality-generated recycling recipe. The auto
  -- recipe may try to recycle Detritus into less Detritus because Detritus is
  -- dynamically injected as a zero-probability product elsewhere. This explicit
  -- recycler recipe breaks that loop.
  patched.category = "recycling"
  patched.enabled = true
  patched.energy_required = 3.2
  patched.icon = "__tech-priests__/graphics/icons/mechanical-detritus.png"
  patched.icon_size = 64
  patched.subgroup = "tech-priest-cogitators"
  patched.order = "a[consecration]-d[mechanical-detritus-recycling]"
  patched.ingredients = {
    { type = "item", name = DETRITUS_NAME, amount = 10 }
  }
  patched.results = products
  patched.result = nil
  patched.result_count = nil
  patched.main_product = item_exists("scrap") and "scrap" or nil
  patched.allow_productivity = false
  patched.allow_decomposition = false
  patched.auto_recycle = false

  if not recipe then
    data:extend({ patched })
  end
end

make_detritus_reclamation_recipe()
make_detritus_recycling_recipe()

-- Final Space Age placement cleanup.
-- Some Space Age prototype adjustments can run after the normal data stage and
-- re-apply surface/gravity restrictions to entity prototypes. Run the Tech
-- Priests platform compatibility pass again here so Cogitator Stations remain
-- buildable on zero-gravity space platforms.
if mods["space-age"] then
  require("prototypes.compatibility.space-age")
end

-- Hard final cleanup for Space Age low-gravity placement blockers.
-- This code is intentionally duplicated instead of relying only on require(),
-- because Lua require caches modules loaded during data.lua and would not rerun
-- prototypes.compatibility.space-age during data-final-fixes.
if mods["space-age"] then
  local function tech_priests_platform_safe_surface_conditions()
    return {
      { property = "gravity", min = -1000000, max = 1000000 },
      { property = "pressure", min = -1000000, max = 1000000 }
    }
  end

  local function tech_priests_first_existing_entity(candidates)
    for _, candidate in ipairs(candidates or {}) do
      local raw_type = candidate[1]
      local name = candidate[2]
      local proto = data.raw[raw_type] and data.raw[raw_type][name]
      if proto then return proto end
    end
    return nil
  end

  local tech_priests_platform_tile_source = tech_priests_first_existing_entity({
    {"assembling-machine", "crusher"},
    {"asteroid-collector", "asteroid-collector"},
    {"cargo-bay", "cargo-bay"},
    {"space-platform-hub", "space-platform-hub"}
  })

  local tech_priest_space_entity_names = {
    ["junior-cogitator-station"] = true,
    ["intermediate-cogitator-station"] = true,
    ["senior-cogitator-station"] = true,
    ["planetary-magos-cogitator-station"] = true,
    ["void-cogitator-station"] = true,
    ["orbital-trader"] = true,
    ["tech-priests-hidden-requester-cache"] = true,
    ["tech-priests-hidden-return-cache"] = true,
    ["junior-tech-priest"] = true,
    ["intermediate-tech-priest"] = true,
    ["senior-tech-priest"] = true,
    ["planetary-magos-tech-priest"] = true,
    ["void-tech-priest"] = true,
    ["junior-tech-priest-belt-immune"] = true,
    ["intermediate-tech-priest-belt-immune"] = true,
    ["senior-tech-priest-belt-immune"] = true,
    ["planetary-magos-tech-priest-belt-immune"] = true,
    ["void-tech-priest-belt-immune"] = true,
    ["junior-tech-priest-corpse"] = true,
    ["intermediate-tech-priest-corpse"] = true,
    ["senior-tech-priest-corpse"] = true,
    ["planetary-magos-tech-priest-corpse"] = true,
    ["void-tech-priest-corpse"] = true,
  }

  for name in pairs(tech_priest_space_entity_names) do
    for _, prototypes_of_type in pairs(data.raw or {}) do
      local proto = prototypes_of_type and prototypes_of_type[name]
      if proto then
        proto.surface_conditions = tech_priests_platform_safe_surface_conditions()
        if tech_priests_platform_tile_source and (name == "junior-cogitator-station" or name == "intermediate-cogitator-station" or name == "senior-cogitator-station" or name == "planetary-magos-cogitator-station" or name == "void-cogitator-station" or name == "orbital-trader") then
          proto.tile_buildability_rules = table.deepcopy(tech_priests_platform_tile_source.tile_buildability_rules)
        end
        if name == "junior-cogitator-station" or name == "intermediate-cogitator-station" or name == "senior-cogitator-station" or name == "planetary-magos-cogitator-station" or name == "void-cogitator-station" then
          proto.placeable_by = { item = name, count = 1 }
        end
        if proto.type ~= "unit" and proto.type ~= "corpse" then
          proto.heating_energy = "0W"
        end
      end
    end
  end
end


-- 0.1.178: make the emergency Laboratorium aggressively compatible with every
-- science/research tool item visible at final prototype time. This catches base,
-- Space Age, Quality-adjacent, and large overhaul/modded science packs without
-- hardcoding their names.
do
  local lab = data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"]
  if lab then
    local inputs = {}
    local seen = {}
    for name, tool in pairs(data.raw.tool or {}) do
      if type(name) == "string" and tool and not tool.hidden then
        seen[name] = true
      end
    end
    for name in pairs(seen) do
      table.insert(inputs, name)
    end
    table.sort(inputs)
    if #inputs > 0 then
      lab.inputs = inputs
    end
  end
end


-- 0.1.302 fixed priest armor-equivalent progression gates.
-- The runtime 0.1.302 armor mirror assigns rank-specific armor profiles.  This
-- data-stage pass lines the station/reimprinting progression up with the same
-- armor tiers when the relevant vanilla/Space Age technologies exist.
local TECH_PRIESTS_ARMOR_TECH_BY_STATION_RECIPE = {
  ["intermediate-cogitator-station"] = {
    "heavy-armor",
    "military"
  },
  ["senior-cogitator-station"] = {
    "modular-armor"
  },
  ["planetary-magos-cogitator-station"] = {
    "power-armor",
    "mech-armor"
  },
  ["void-cogitator-station"] = {
    "power-armor-mk2",
    "mech-armor"
  }
}

local function tech_priests_any_technology_exists(names)
  for _, name in ipairs(names) do
    if data.raw.technology and data.raw.technology[name] then
      return true
    end
  end
  return false
end

local function tech_priests_station_recipe_add_prereq(name, prereq)
  local recipe = data.raw.recipe and data.raw.recipe[name]
  if not recipe or not prereq then return end
  recipe.enabled = false
  recipe.hidden = false
  recipe.hide_from_player_crafting = false
  recipe.hide_from_signal_gui = false

  local technology = data.raw.technology and data.raw.technology[prereq]
  if not technology then return end
  technology.effects = technology.effects or {}
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == name then
      return
    end
  end
  table.insert(technology.effects, { type = "unlock-recipe", recipe = name })
end

for recipe_name, candidates in pairs(TECH_PRIESTS_ARMOR_TECH_BY_STATION_RECIPE) do
  if data.raw.recipe and data.raw.recipe[recipe_name] and tech_priests_any_technology_exists(candidates) then
    for _, tech in ipairs(candidates) do
      if data.raw.technology and data.raw.technology[tech] then
        tech_priests_station_recipe_add_prereq(recipe_name, tech)
        break
      end
    end
  end
end

-- 0.1.486: orbital trader unlock is now anchored to the local rocket-silo tier
-- instead of being hidden behind Space Age's platform/orbital logistics chain.
local orbital_trader_recipe = data.raw.recipe and data.raw.recipe["orbital-trader"]
if orbital_trader_recipe then
  orbital_trader_recipe.enabled = false
  orbital_trader_recipe.hidden = false
  orbital_trader_recipe.hide_from_player_crafting = false
  orbital_trader_recipe.hide_from_signal_gui = false

  local function add_unlock_to_tech(tech_name)
    local tech = data.raw.technology and data.raw.technology[tech_name]
    if not tech then return false end
    tech.effects = tech.effects or {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == "orbital-trader" then
        return true
      end
    end
    table.insert(tech.effects, { type = "unlock-recipe", recipe = "orbital-trader" })
    return true
  end

  if not add_unlock_to_tech("rocket-silo") then
    add_unlock_to_tech("space-platform")
  end
end

-- 0.1.488: ensure Conclave Center is unlocked by the same mid-late progression tier
-- that authorizes long-range network politics.
local conclave_recipe = data.raw.recipe and data.raw.recipe["tech-priests-conclave-center"]
if conclave_recipe then
  conclave_recipe.enabled = false
  conclave_recipe.hidden = false
  conclave_recipe.hide_from_player_crafting = false
  conclave_recipe.hide_from_signal_gui = false

  local function add_unlock_to_tech(tech_name)
    local tech = data.raw.technology and data.raw.technology[tech_name]
    if not tech then return false end
    tech.effects = tech.effects or {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == "tech-priests-conclave-center" then
        return true
      end
    end
    table.insert(tech.effects, { type = "unlock-recipe", recipe = "tech-priests-conclave-center" })
    return true
  end

  if not add_unlock_to_tech("processing-unit") then
    if not add_unlock_to_tech("production-science-pack") then
      add_unlock_to_tech("utility-science-pack")
    end
  end
end
-- 0.1.311/0.1.314: equipment grid experiment removed. Do not install armor grids
-- or grid equipment unlocks for Tech-Priests until the whole mechanic is redesigned.
