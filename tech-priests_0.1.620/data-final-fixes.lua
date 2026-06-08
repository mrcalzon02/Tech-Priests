-- Tech Priests - final prototype correction stage.
-- Keep last-pass prototype edits here.

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


-- 0.1.411 emergency pseudo-mining pacing repair.
-- The earlier debug pass forced emergency mining/smelting wrappers to one second,
-- which was useful during first visibility testing but made the Martian
-- Micro-Miner feel absurdly productive.  Keep smelting wrappers alone for now,
-- and reassert pseudo-mining as a slow, last-ditch survival rite.
local tech_priests_emergency_mine_min_times_0411 = {
  ["tech-priests-emergency-mine-wood"] = 150,
  ["tech-priests-emergency-mine-stone"] = 120,
  ["tech-priests-emergency-mine-iron-ore"] = 120,
  ["tech-priests-emergency-mine-copper-ore"] = 120,
  ["tech-priests-emergency-mine-coal"] = 120,
  ["tech-priests-emergency-mine-uranium-ore"] = 240,
}
for name, recipe in pairs(data.raw.recipe or {}) do
  if type(name) == "string" and string.sub(name, 1, #"tech-priests-emergency-mine-") == "tech-priests-emergency-mine-" then
    local min_time = tech_priests_emergency_mine_min_times_0411[name] or 180
    if (tonumber(recipe.energy_required) or 0) < min_time then
      recipe.energy_required = min_time
    end
  end
end

-- 0.1.302 fixed priest armor-equivalent progression gates.
-- The runtime 0.1.302 armor mirror assigns rank-specific armor profiles.  This
-- data-stage pass lines the station/reimprinting progression up with the same
-- armor tiers when the relevant vanilla/Space Age technologies exist.
do
  local function tech_exists(name)
    return data.raw.technology and data.raw.technology[name] ~= nil
  end
  local function add_prereq(tech_name, prereq)
    if not (tech_exists(tech_name) and tech_exists(prereq)) then return end
    local tech = data.raw.technology[tech_name]
    tech.prerequisites = tech.prerequisites or {}
    for _, existing in pairs(tech.prerequisites) do
      if existing == prereq then return end
    end
    table.insert(tech.prerequisites, prereq)
  end

  -- Heavy armor is a recipe in base, normally enabled by steel-processing.
  add_prereq("cogitator-station-deployment", "steel-processing")
  add_prereq("tech-priest-reimprinting-acceleration-1", "steel-processing")

  add_prereq("intermediate-cogitator-stations", "modular-armor")
  add_prereq("tech-priest-reimprinting-acceleration-2", "modular-armor")

  add_prereq("senior-cogitator-stations", "power-armor")
  add_prereq("tech-priest-reimprinting-acceleration-3", "power-armor")

  add_prereq("planetary-magos-cogitator-stations", "power-armor-mk2")
  if tech_exists("mech-armor") then
    add_prereq("void-cogitator-stations", "mech-armor")
  else
    add_prereq("void-cogitator-stations", "power-armor-mk2")
  end
end

-- 0.1.314 equipment-grid abandonment cleanup.
-- The Tech-Priest sub-equipment grid experiment has been retired in favor of
-- unified research-unlocked bonuses.  Do NOT add the removed
-- tech-priests-sub-equipment category to vanilla/modded equipment here; doing
-- so causes Factorio to fail assignID because the category prototype is no
-- longer loaded.


-- ============================================================================
-- 0.1.342 Martian emergency prototype visual / fluid-port repair
-- ============================================================================
-- Several emergency entities are cloned from large vanilla machines whose visual
-- definitions live in different prototype fields. Earlier passes scaled the
-- common fields, but some prototypes, especially labs and generators, still kept
-- large or wrong-orientation sprite branches. This final-fixes pass recursively
-- normalizes the visual layers after all other mods have touched the prototypes.
do
  local function box(sel, col)
    return table.deepcopy(sel), table.deepcopy(col or sel)
  end
  local one_sel, one_col = box({{-0.50,-0.50},{0.50,0.50}}, {{-0.35,-0.35},{0.35,0.35}})
  local fluid_sel, fluid_col = box({{-0.66,-0.66},{0.66,0.66}}, {{-0.51,-0.51},{0.51,0.51}})
  local two_sel, two_col = box({{-1.12,-1.12},{1.12,1.12}}, {{-0.96,-0.96},{0.96,0.96}})

  local function force_scale_tree(t, factor)
    if type(t) ~= "table" then return end
    if (t.filename or t.filenames or t.stripes) and (t.width or t.height or t.size or t.hr_version) then
      t.scale = factor
      if type(t.shift) == "table" then
        t.shift = { (t.shift[1] or t.shift.x or 0) * factor, (t.shift[2] or t.shift.y or 0) * factor }
      else
        t.shift = {0,0}
      end
      if t.hr_version and type(t.hr_version) == "table" then
        t.hr_version.scale = factor * 0.5
        t.hr_version.shift = {0,0}
      end
    end
    for _, v in pairs(t) do
      if type(v) == "table" then force_scale_tree(v, factor) end
    end
  end

  local function normalize_visual(proto, factor, sel, col, ext)
    if not proto then return end
    proto.selection_box = table.deepcopy(sel or one_sel)
    proto.collision_box = table.deepcopy(col or one_col)
    proto.drawing_box_vertical_extension = ext or 0.25
    force_scale_tree(proto, factor)
  end

  local lab = data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"]
  if lab then
    normalize_visual(lab, 0.28, one_sel, one_col, 0.20)
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    normalize_visual(engine, 0.62, two_sel, two_col, 0.35)
    -- Default placement renders the engine vertically; align steam ports to
    -- that visual orientation so pipes match what the player sees.
    engine.fluid_box = {
      production_type = "input-output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.north, position = { 0, -0.50 } },
        { flow_direction = "input-output", direction = defines.direction.south, position = { 0,  0.50 } }
      }
    }
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    normalize_visual(boiler, 0.84, fluid_sel, fluid_col, 0.30)
    -- Match the compact boiler art: water comes in from the top, steam exits to
    -- left and right.  This is deliberately symmetrical so either side can feed
    -- a micro steam engine during the bootstrap power chain.
    boiler.fluid_box = {
      production_type = "input-output",
      filter = "water",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.north, position = {0, -0.50} }
      }
    }
    boiler.output_fluid_box = {
      production_type = "output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "output", direction = defines.direction.west, position = {-0.50, 0} },
        { flow_direction = "output", direction = defines.direction.east, position = { 0.50, 0} }
      }
    }
  end
end


-- 0.1.343: emergency smelter split. Keep the micro-assembler out of the
-- smelting categories even if another compatibility pass or mod touches it.
do
  local assembler = data.raw["assembling-machine"] and data.raw["assembling-machine"]["tech-priests-emergency-assembler"]
  if assembler then
    assembler.crafting_categories = { "crafting", "basic-crafting", "advanced-crafting" }
  end
  local smelter = data.raw["furnace"] and data.raw["furnace"]["tech-priests-emergency-smelter"]
  if smelter then
    smelter.crafting_categories = { "smelting", "tech-priests-emergency-smelting" }
    smelter.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
    smelter.collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } }
  end
end


-- ============================================================================
-- 0.1.348 emergency prototype scale / port orientation repair
-- ============================================================================
-- 0.1.342 still left several cloned emergency machines visually out of sync
-- with their intended bootstrap footprints.  This final pass is deliberately
-- aggressive: it rescales any sprite-like table that carries a filename,
-- normalizes boxes, and swaps generator animation branches so the micro steam
-- engine art and fluid ports agree in default placement.
do
  local function clone(v) return table.deepcopy(v) end
  local one_sel = {{-0.50,-0.50},{0.50,0.50}}
  local one_col = {{-0.35,-0.35},{0.35,0.35}}
  local two_sel = {{-1.00,-1.00},{1.00,1.00}}
  local two_col = {{-0.82,-0.82},{0.82,0.82}}

  local function scale_visual_tree(t, factor)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames or t.stripes then
      t.scale = factor
      if type(t.shift) == "table" then
        local sx = t.shift[1] or t.shift.x or 0
        local sy = t.shift[2] or t.shift.y or 0
        t.shift = { sx * factor, sy * factor }
      end
      if type(t.hr_version) == "table" then
        t.hr_version.scale = factor * 0.5
        if type(t.hr_version.shift) == "table" then
          local hx = t.hr_version.shift[1] or t.hr_version.shift.x or 0
          local hy = t.hr_version.shift[2] or t.hr_version.shift.y or 0
          t.hr_version.shift = { hx * factor, hy * factor }
        end
      end
    end
    for _, v in pairs(t) do
      if type(v) == "table" then scale_visual_tree(v, factor) end
    end
  end

  local function normalize(proto, factor, sel, col, ext)
    if not proto then return end
    proto.selection_box = clone(sel or one_sel)
    proto.collision_box = clone(col or one_col)
    proto.drawing_box_vertical_extension = ext or 0.20
    scale_visual_tree(proto, factor)
  end

  local lab = data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"]
  if lab then
    normalize(lab, 0.28, one_sel, one_col, 0.20)
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    -- The boiler is meant to be a two-by-two emergency machine.  Its previous
    -- visual had crept back toward default boiler size while the box remained
    -- one-by-one, which made placement and fluid layout dishonest.
    normalize(boiler, 0.46, two_sel, two_col, 0.22)
    boiler.fluid_box = {
      production_type = "input-output",
      filter = "water",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.north, position = {0, -0.88} }
      }
    }
    boiler.output_fluid_box = {
      production_type = "output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "output", direction = defines.direction.west, position = {-0.88, 0} },
        { flow_direction = "output", direction = defines.direction.east, position = { 0.88, 0} }
      }
    }
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    -- Swap the vanilla steam-engine visual branches so default placement reads
    -- in the same plane as the east/west steam pipe ports.  Keep it compact but
    -- large enough to see beside the other Martian emergency machines.
    engine.horizontal_animation, engine.vertical_animation = engine.vertical_animation, engine.horizontal_animation
    engine.horizontal_frozen_patch, engine.vertical_frozen_patch = engine.vertical_frozen_patch, engine.horizontal_frozen_patch
    normalize(engine, 0.70, two_sel, two_col, 0.25)
    engine.fluid_box = {
      production_type = "input-output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.west, position = {-0.88, 0} },
        { flow_direction = "input-output", direction = defines.direction.east, position = { 0.88, 0} }
      }
    }
  end

  local smelter = data.raw["furnace"] and data.raw["furnace"]["tech-priests-emergency-smelter"]
  if smelter then
    normalize(smelter, 0.52, one_sel, one_col, 0.12)
    smelter.crafting_categories = { "smelting", "tech-priests-emergency-smelting" }
  end
end


-- ============================================================================
-- 0.1.349 prototype pipe-position repair / expanded assembler fluid alignment
-- ============================================================================
-- 0.1.348 exposed a hard Factorio validation rule: every pipe connection
-- position must remain inside the entity's final bounding box.  The emergency
-- boiler was intended to be a compact two-by-two machine, but the final pipe
-- edge was pushed past the inherited one-by-one collision box.  Reassert the
-- two-by-two box and keep all pipe positions safely inside it.
do
  local function clone(v) return table.deepcopy(v) end

  local two_sel = {{-1.00, -1.00}, {1.00, 1.00}}
  local two_col = {{-0.92, -0.92}, {0.92, 0.92}}
  local safe_pipe_edge = 0.84

  local function scale_visual_tree(t, factor)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames or t.stripes then
      t.scale = factor
      if type(t.shift) == "table" then
        local sx = t.shift[1] or t.shift.x or 0
        local sy = t.shift[2] or t.shift.y or 0
        t.shift = { sx * factor, sy * factor }
      end
      if type(t.hr_version) == "table" then
        t.hr_version.scale = factor * 0.5
        if type(t.hr_version.shift) == "table" then
          local hx = t.hr_version.shift[1] or t.hr_version.shift.x or 0
          local hy = t.hr_version.shift[2] or t.hr_version.shift.y or 0
          t.hr_version.shift = { hx * factor, hy * factor }
        end
      end
    end
    for _, v in pairs(t) do
      if type(v) == "table" then scale_visual_tree(v, factor) end
    end
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    boiler.selection_box = clone(two_sel)
    boiler.collision_box = clone(two_col)
    boiler.drawing_box_vertical_extension = 0.22
    -- Compact visual target: roughly half-size vanilla boiler, honest 2x2 footprint.
    scale_visual_tree(boiler, 0.46)
    boiler.fluid_box = {
      production_type = "input-output",
      filter = "water",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.north, position = {0, -safe_pipe_edge} }
      }
    }
    boiler.output_fluid_box = {
      production_type = "output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "output", direction = defines.direction.west, position = {-safe_pipe_edge, 0} },
        { flow_direction = "output", direction = defines.direction.east, position = { safe_pipe_edge, 0} }
      }
    }
  end

  -- The Mechanicus assembler pass expands vanilla assemblers to a four-by-four
  -- body.  Fluid-capable assembler pipe connection positions should be scaled
  -- with that footprint rather than left visually crowded around the old 3x3
  -- sprite center.  This intentionally scales actual pipe connection positions;
  -- pipe covers/pictures follow the connection point in game logic.
  local pipe_scale = 4 / 3
  local max_pipe = 1.68
  local function clamp(v)
    if v > max_pipe then return max_pipe end
    if v < -max_pipe then return -max_pipe end
    return v
  end
  local function scale_pipe_connections(box)
    if type(box) ~= "table" or type(box.pipe_connections) ~= "table" then return end
    for _, pc in pairs(box.pipe_connections) do
      if type(pc) == "table" and type(pc.position) == "table" then
        local x = pc.position[1] or pc.position.x or 0
        local y = pc.position[2] or pc.position.y or 0
        pc.position = { clamp(x * pipe_scale), clamp(y * pipe_scale) }
      end
    end
  end
  local function scale_fluid_boxes(proto)
    if not proto or proto.__tech_priests_0349_pipe_scaled then return end
    proto.__tech_priests_0349_pipe_scaled = true
    if type(proto.fluid_boxes) == "table" then
      for _, box in pairs(proto.fluid_boxes) do scale_pipe_connections(box) end
    end
    scale_pipe_connections(proto.fluid_box)
    scale_pipe_connections(proto.input_fluid_box)
    scale_pipe_connections(proto.output_fluid_box)
  end
  for _, name in pairs({"assembling-machine-2", "assembling-machine-3"}) do
    local assembler = data.raw["assembling-machine"] and data.raw["assembling-machine"][name]
    scale_fluid_boxes(assembler)
  end
end


-- ============================================================================
-- 0.1.350 emergency generator pipe-position cardinality/bounds repair
-- ============================================================================
-- The boiler fix in 0.1.349 correctly documented the bounding-box rule, but the
-- Martian Emergency Steam Engine still had east/west pipe positions outside its
-- inherited compact generator collision box after other final-fixes ran.  Keep
-- all emergency fluid machines inside the same final safe envelope at the very
-- end of final-fixes so later prototype edits cannot leave a pipe outside the
-- box.
do
  local two_sel = {{-1.00, -1.00}, {1.00, 1.00}}
  local two_col = {{-0.92, -0.92}, {0.92, 0.92}}
  local safe_pipe_edge = 0.84

  local function clone(v) return table.deepcopy(v) end

  local function clamp_position(pos)
    if type(pos) ~= "table" then return pos end
    local x = pos[1] or pos.x or 0
    local y = pos[2] or pos.y or 0
    if x > safe_pipe_edge then x = safe_pipe_edge end
    if x < -safe_pipe_edge then x = -safe_pipe_edge end
    if y > safe_pipe_edge then y = safe_pipe_edge end
    if y < -safe_pipe_edge then y = -safe_pipe_edge end
    return {x, y}
  end

  local function clamp_pipe_box(box)
    if type(box) ~= "table" or type(box.pipe_connections) ~= "table" then return end
    for _, pc in pairs(box.pipe_connections) do
      if type(pc) == "table" and type(pc.position) == "table" then
        pc.position = clamp_position(pc.position)
      end
    end
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    boiler.selection_box = clone(two_sel)
    boiler.collision_box = clone(two_col)
    clamp_pipe_box(boiler.fluid_box)
    clamp_pipe_box(boiler.output_fluid_box)
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    engine.selection_box = clone(two_sel)
    engine.collision_box = clone(two_col)
    engine.drawing_box_vertical_extension = 0.25
    engine.fluid_box = {
      production_type = "input-output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.west, position = {-safe_pipe_edge, 0} },
        { flow_direction = "input-output", direction = defines.direction.east, position = { safe_pipe_edge, 0} }
      }
    }
    clamp_pipe_box(engine.fluid_box)
  end
end


-- ============================================================================
-- 0.1.351 micro-machine visual scale final clamp / assembler fluid limitation note
-- ============================================================================
-- Keep this at the end so later compatibility mods do not undo the emergency
-- prototype scale targets.  Also: the expanded vanilla assembler fluid connector
-- art is partly baked into the vanilla sprite; pipe logic can be moved, but the
-- visible blue connector pixels require a custom overlay/sprite pass to truly
-- relocate.
do
  local function clone(v) return table.deepcopy(v) end
  local one_sel = {{-0.50, -0.50}, {0.50, 0.50}}
  local one_col = {{-0.35, -0.35}, {0.35, 0.35}}
  local two_sel = {{-1.00, -1.00}, {1.00, 1.00}}
  local two_col = {{-0.92, -0.92}, {0.92, 0.92}}
  local safe_pipe_edge = 0.84

  local function scale_visual_tree(t, factor)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames or t.stripes then
      t.scale = factor
      if type(t.shift) == "table" then
        local sx = t.shift[1] or t.shift.x or 0
        local sy = t.shift[2] or t.shift.y or 0
        t.shift = { sx * factor, sy * factor }
      end
      if type(t.hr_version) == "table" then
        t.hr_version.scale = factor * 0.5
        if type(t.hr_version.shift) == "table" then
          local hx = t.hr_version.shift[1] or t.hr_version.shift.x or 0
          local hy = t.hr_version.shift[2] or t.hr_version.shift.y or 0
          t.hr_version.shift = { hx * factor, hy * factor }
        end
      end
    end
    for _, v in pairs(t) do
      if type(v) == "table" then scale_visual_tree(v, factor) end
    end
  end

  local smelter = data.raw["furnace"] and data.raw["furnace"]["tech-priests-emergency-smelter"]
  if smelter then
    smelter.selection_box = clone(one_sel)
    smelter.collision_box = clone(one_col)
    smelter.drawing_box_vertical_extension = 0.08
    scale_visual_tree(smelter, 0.36)
    smelter.crafting_categories = { "smelting", "tech-priests-emergency-smelting" }
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    engine.selection_box = clone(two_sel)
    engine.collision_box = clone(two_col)
    engine.drawing_box_vertical_extension = 0.16
    scale_visual_tree(engine, 0.35)
    engine.fluid_box = {
      production_type = "input-output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.west, position = {-safe_pipe_edge, 0} },
        { flow_direction = "input-output", direction = defines.direction.east, position = { safe_pipe_edge, 0} }
      }
    }
  end
end


-- ============================================================================
-- 0.1.352 emergency visuals / smoke emitter refinement
-- ============================================================================
-- Final visual pass after 0.1.351 testing:
-- * Micro Laboratorium was slightly too small; make it about 15% larger.
-- * Micro Boiler and Micro Steam Engine were still a touch too large; reduce
--   their visuals by roughly 10-15% while preserving the safe 2x2 pipe box.
-- * Chemical-plant/steam-engine inherited smoke and vapor emitters sat too high
--   after scaling; shift those visual effects down toward the compact body.
do
  local function clone(v) return table.deepcopy(v) end
  local one_sel = {{-0.50, -0.50}, {0.50, 0.50}}
  local one_col = {{-0.35, -0.35}, {0.35, 0.35}}
  local two_sel = {{-1.00, -1.00}, {1.00, 1.00}}
  local two_col = {{-0.92, -0.92}, {0.92, 0.92}}
  local safe_pipe_edge = 0.84

  local function scale_visual_tree(t, factor)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames or t.stripes then
      t.scale = factor
      if type(t.shift) == "table" then
        local sx = t.shift[1] or t.shift.x or 0
        local sy = t.shift[2] or t.shift.y or 0
        t.shift = { sx * factor, sy * factor }
      end
      if type(t.hr_version) == "table" then
        t.hr_version.scale = factor * 0.5
        if type(t.hr_version.shift) == "table" then
          local hx = t.hr_version.shift[1] or t.hr_version.x or 0
          local hy = t.hr_version.shift[2] or t.hr_version.y or 0
          t.hr_version.shift = { hx * factor, hy * factor }
        end
      end
    end
    for _, v in pairs(t) do if type(v) == "table" then scale_visual_tree(v, factor) end end
  end

  local function shift_effect_positions(t, dy)
    if type(t) ~= "table" then return end
    if type(t.position) == "table" then
      local x = t.position[1] or t.position.x or 0
      local y = t.position[2] or t.position.y or 0
      t.position = { x, y + dy }
    end
    for _, key in pairs({"north_position", "south_position", "east_position", "west_position"}) do
      if type(t[key]) == "table" then
        t[key] = { (t[key][1] or t[key].x or 0), (t[key][2] or t[key].y or 0) + dy }
      end
    end
    for _, v in pairs(t) do if type(v) == "table" then shift_effect_positions(v, dy) end end
  end

  local lab = data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"]
  if lab then
    lab.selection_box = clone(one_sel)
    lab.collision_box = clone(one_col)
    lab.drawing_box_vertical_extension = 0.12
    scale_visual_tree(lab, 0.28)
  end

  local smelter = data.raw["furnace"] and data.raw["furnace"]["tech-priests-emergency-smelter"]
  if smelter then
    smelter.selection_box = clone(one_sel)
    smelter.collision_box = clone(one_col)
    smelter.drawing_box_vertical_extension = 0.08
    scale_visual_tree(smelter, 0.36)
    smelter.crafting_categories = { "smelting", "tech-priests-emergency-smelting" }
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    boiler.selection_box = clone(two_sel)
    boiler.collision_box = clone(two_col)
    boiler.drawing_box_vertical_extension = 0.20
    scale_visual_tree(boiler, 0.405)
    shift_effect_positions(boiler.energy_source and boiler.energy_source.smoke, 0.35)
    boiler.fluid_box = {
      production_type = "input-output",
      filter = "water",
      volume = 100,
      pipe_connections = {{ flow_direction = "input-output", direction = defines.direction.north, position = {0, -safe_pipe_edge} }}
    }
    boiler.output_fluid_box = {
      production_type = "output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "output", direction = defines.direction.west, position = {-safe_pipe_edge, 0} },
        { flow_direction = "output", direction = defines.direction.east, position = { safe_pipe_edge, 0} }
      }
    }
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    engine.selection_box = clone(two_sel)
    engine.collision_box = clone(two_col)
    engine.drawing_box_vertical_extension = 0.14
    scale_visual_tree(engine, 0.31)
    shift_effect_positions(engine.smoke, 0.35)
    shift_effect_positions(engine.working_visualisations, 0.35)
    engine.fluid_box = {
      production_type = "input-output",
      filter = "steam",
      volume = 100,
      pipe_connections = {
        { flow_direction = "input-output", direction = defines.direction.west, position = {-safe_pipe_edge, 0} },
        { flow_direction = "input-output", direction = defines.direction.east, position = { safe_pipe_edge, 0} }
      }
    }
  end

  local condenser = data.raw["assembling-machine"] and data.raw["assembling-machine"]["tech-priests-atmospheric-water-condenser"]
  if condenser then
    shift_effect_positions(condenser.energy_source and condenser.energy_source.smoke, 0.45)
    shift_effect_positions(condenser.working_visualisations, 0.45)
    shift_effect_positions(condenser.graphics_set and condenser.graphics_set.working_visualisations, 0.45)
  end
end


-- ============================================================================
-- 0.1.355 assembler fluid connection rollback
-- ============================================================================
-- 0.1.349 attempted to scale vanilla assembler-2/3 pipe connection positions
-- outward to visually match the enlarged 4x4 assembler sprite. In practice this
-- made the actual connection points unreliable/non-connectable in game. Until we
-- provide custom assembler graphics or pipe-cover overlays, keep vanilla logical
-- fluid connection positions. Visual alignment is allowed to be imperfect;
-- connection functionality wins.
do
  local pipe_scale = 4 / 3
  local function revert_scaled_pipe_connections(box)
    if type(box) ~= "table" or type(box.pipe_connections) ~= "table" then return end
    for _, pc in pairs(box.pipe_connections) do
      if type(pc) == "table" and type(pc.position) == "table" then
        local x = pc.position[1] or pc.position.x or 0
        local y = pc.position[2] or pc.position.y or 0
        pc.position = { x / pipe_scale, y / pipe_scale }
      end
    end
  end
  local function revert_scaled_fluid_boxes(proto)
    if not (proto and proto.__tech_priests_0349_pipe_scaled) then return end
    if type(proto.fluid_boxes) == "table" then
      for _, box in pairs(proto.fluid_boxes) do revert_scaled_pipe_connections(box) end
    end
    revert_scaled_pipe_connections(proto.fluid_box)
    revert_scaled_pipe_connections(proto.input_fluid_box)
    revert_scaled_pipe_connections(proto.output_fluid_box)
    proto.__tech_priests_0349_pipe_scaled = nil
    proto.__tech_priests_0355_pipe_scale_rollback = true
  end
  for _, name in pairs({"assembling-machine-2", "assembling-machine-3"}) do
    local assembler = data.raw["assembling-machine"] and data.raw["assembling-machine"][name]
    revert_scaled_fluid_boxes(assembler)
  end
end

-- 0.1.509 final AI-safety hardening for all Tech-Priest unit prototypes.
-- These are scripted workers, and the runtime behavior stack now relies on
-- repeated go-to-location commands.  Do not allow inherited biter/compilatron AI
-- settings to destroy them after command failure or drag them into attack groups.
do
  local tech_priest_unit_names_0509 = {
    "junior-tech-priest",
    "intermediate-tech-priest",
    "senior-tech-priest",
    "planetary-magos-tech-priest",
    "void-tech-priest",
    "junior-tech-priest-belt-immune",
    "intermediate-tech-priest-belt-immune",
    "senior-tech-priest-belt-immune",
    "planetary-magos-tech-priest-belt-immune",
    "void-tech-priest-belt-immune",
  }
  for _, name in ipairs(tech_priest_unit_names_0509) do
    local unit = data.raw.unit and data.raw.unit[name]
    if unit then
      unit.ai_settings = unit.ai_settings or {}
      unit.ai_settings.destroy_when_commands_fail = false
      unit.ai_settings.allow_try_return_to_spawner = false
      unit.ai_settings.do_separation = false
      unit.ai_settings.join_attacks = false
      unit.ai_settings.path_resolution_modifier = unit.ai_settings.path_resolution_modifier or 0
      unit.has_belt_immunity = unit.has_belt_immunity or name:find("belt%-immune", 1, false) ~= nil or name == "void-tech-priest"
      unit.affected_by_tiles = false
      -- 0.1.518 movement cadence hardening: keep every loaded priest variant at
      -- the new observable-action speed even if another data-final-fixes pass or
      -- inherited prototype data overwrote the base definition. Void priests stay
      -- on their hover/space-platform doctrine and are not accelerated here.
      if name ~= "void-tech-priest" and name ~= "void-tech-priest-belt-immune" then
        local is_immune = name:find("belt%-immune", 1, false) ~= nil
        local min_speed = is_immune and 0.095 or 0.080
        local min_dpf = is_immune and 0.145 or 0.125
        unit.movement_speed = math.max(tonumber(unit.movement_speed or 0) or 0, min_speed)
        unit.distance_per_frame = math.max(tonumber(unit.distance_per_frame or 0) or 0, min_dpf)
      end
    end
  end
end


-- 0.1.531: Custom operational working sounds for Martian emergency machines.
-- This is prototype-side audio only; it does not alter recipes, energy use,
-- crafting speed, or runtime behavior authority.
do
  local operation_sound = {
    sound = {
      filename = "__tech-priests__/sound/operation/0531/machine_running.ogg",
      volume = 0.36
    },
    apparent_volume = 0.55
  }

  local function copy_working_sound(proto)
    if proto then
      proto.working_sound = table.deepcopy(operation_sound)
    end
  end

  local assembling_names = {
    "tech-priests-emergency-miner",
    "tech-priests-atmospheric-water-condenser",
    "tech-priests-emergency-assembler",
  }
  for _, name in pairs(assembling_names) do
    copy_working_sound(data.raw["assembling-machine"] and data.raw["assembling-machine"][name])
  end

  copy_working_sound(data.raw.furnace and data.raw.furnace["tech-priests-emergency-smelter"])
  copy_working_sound(data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"])
  copy_working_sound(data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"])
  copy_working_sound(data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"])
end

-- 0.1.532: Diegetic Cogitator GUI style tinting.
-- Prototype-side style only. Runtime UI still owns layout and content; this pass
-- gives the Work-State Reliquary a muted brown exterior and dark green internal
-- instrument frame without creating any behavior or GUI control loop.
do
  local styles = data.raw["gui-style"] and data.raw["gui-style"].default
  if styles and table.deepcopy then
    local function clone_style(primary, fallback)
      local src = styles[primary] or styles[fallback]
      if src then return table.deepcopy(src) end
      return {}
    end

    local function tint_graphical_set(gs, tint)
      if type(gs) ~= "table" then return end
      for _, key in pairs({ "base", "background", "border", "shadow", "glow", "underlay", "overlay" }) do
        local part = gs[key]
        if type(part) == "table" then part.tint = table.deepcopy(tint) end
      end
    end

    local function tune_padding(style, pad)
      if not style then return end
      style.top_padding = pad
      style.bottom_padding = pad
      style.left_padding = pad
      style.right_padding = pad
    end

    styles.tech_priests_cogitator_outer_frame_0532 = clone_style("frame")
    tint_graphical_set(styles.tech_priests_cogitator_outer_frame_0532.graphical_set, { r = 0.43, g = 0.26, b = 0.12, a = 1.0 })
    styles.tech_priests_cogitator_outer_frame_0532.font_color = { r = 0.88, g = 0.72, b = 0.44 }
    tune_padding(styles.tech_priests_cogitator_outer_frame_0532, 8)

    styles.tech_priests_cogitator_inner_frame_0532 = clone_style("inside_shallow_frame_with_padding", "frame")
    tint_graphical_set(styles.tech_priests_cogitator_inner_frame_0532.graphical_set, { r = 0.04, g = 0.18, b = 0.07, a = 1.0 })
    styles.tech_priests_cogitator_inner_frame_0532.font_color = { r = 0.45, g = 1.0, b = 0.35 }
    tune_padding(styles.tech_priests_cogitator_inner_frame_0532, 10)

    styles.tech_priests_cogitator_button_0532 = clone_style("button")
    tint_graphical_set(styles.tech_priests_cogitator_button_0532.default_graphical_set, { r = 0.18, g = 0.29, b = 0.12, a = 1.0 })
    tint_graphical_set(styles.tech_priests_cogitator_button_0532.hovered_graphical_set, { r = 0.25, g = 0.42, b = 0.16, a = 1.0 })
    tint_graphical_set(styles.tech_priests_cogitator_button_0532.clicked_graphical_set, { r = 0.09, g = 0.18, b = 0.07, a = 1.0 })
    styles.tech_priests_cogitator_button_0532.font_color = { r = 0.65, g = 1.0, b = 0.42 }
    styles.tech_priests_cogitator_button_0532.hovered_font_color = { r = 0.85, g = 1.0, b = 0.55 }
    styles.tech_priests_cogitator_button_0532.clicked_font_color = { r = 0.40, g = 0.95, b = 0.35 }

    styles.tech_priests_cogitator_tabbed_pane_0532 = clone_style("tabbed_pane")
    tint_graphical_set(styles.tech_priests_cogitator_tabbed_pane_0532.graphical_set, { r = 0.02, g = 0.14, b = 0.05, a = 1.0 })
    styles.tech_priests_cogitator_tabbed_pane_0532.font_color = { r = 0.45, g = 1.0, b = 0.35 }
    styles.tech_priests_cogitator_tabbed_pane_0532.selected_font_color = { r = 0.72, g = 1.0, b = 0.45 }

    styles.tech_priests_cogitator_tab_0541 = clone_style("tab")
    tint_graphical_set(styles.tech_priests_cogitator_tab_0541.default_graphical_set, { r = 0.04, g = 0.18, b = 0.07, a = 1.0 })
    tint_graphical_set(styles.tech_priests_cogitator_tab_0541.selected_graphical_set, { r = 0.02, g = 0.27, b = 0.08, a = 1.0 })
    styles.tech_priests_cogitator_tab_0541.font_color = { r = 0.35, g = 1.0, b = 0.28 }
    styles.tech_priests_cogitator_tab_0541.selected_font_color = { r = 0.80, g = 1.0, b = 0.50 }

    styles.tech_priests_cogitator_display_frame_0540 = clone_style("inside_shallow_frame_with_padding", "frame")
    -- 0.1.567: use the sliced green CRT/bezel artwork as the actual graphical
    -- set for inner screens instead of tinting Factorio's gray vanilla panel.
    -- This is the reusable blank digital canvas for Work-State, Conclave, and
    -- Machine-Spirit ledger interiors.
    styles.tech_priests_cogitator_display_frame_0540.graphical_set = {
      base = {
        filename = "__tech-priests__/graphics/gui/cogitator_frame_0536/slices_384/inner_bezel_full.png",
        position = { 0, 0 },
        size = 256,
        corner_size = 20,
        scale = 1
      }
    }
    styles.tech_priests_cogitator_display_frame_0540.font_color = { r = 0.58, g = 1.0, b = 0.42 }
    styles.tech_priests_cogitator_display_frame_0540.top_padding = 14
    styles.tech_priests_cogitator_display_frame_0540.bottom_padding = 14
    styles.tech_priests_cogitator_display_frame_0540.left_padding = 14
    styles.tech_priests_cogitator_display_frame_0540.right_padding = 14

    styles.tech_priests_cogitator_table_label_0540 = clone_style("label")
    styles.tech_priests_cogitator_table_label_0540.single_line = false
    styles.tech_priests_cogitator_table_label_0540.font_color = { r = 0.20, g = 1.0, b = 0.22 }

    -- 0.1.564: shared diegetic inner-screen styles for all custom Tech-Priest GUIs.
    -- Factorio's tabbed panes/scroll panes keep their own inner widget styles;
    -- tinting only the outer frame leaves a vanilla gray center.  These styles
    -- are applied explicitly at runtime to every custom inner page/screen area.
    styles.tech_priests_cogitator_screen_scroll_0564 = clone_style("scroll_pane")
    tint_graphical_set(styles.tech_priests_cogitator_screen_scroll_0564.graphical_set, { r = 0.00, g = 0.13, b = 0.035, a = 1.0 })
    styles.tech_priests_cogitator_screen_scroll_0564.font_color = { r = 0.35, g = 1.0, b = 0.28 }
    styles.tech_priests_cogitator_screen_scroll_0564.extra_padding_when_activated = 0
    styles.tech_priests_cogitator_screen_scroll_0564.top_padding = 8
    styles.tech_priests_cogitator_screen_scroll_0564.bottom_padding = 8
    styles.tech_priests_cogitator_screen_scroll_0564.left_padding = 8
    styles.tech_priests_cogitator_screen_scroll_0564.right_padding = 8

    styles.tech_priests_cogitator_screen_table_0564 = clone_style("table")
    styles.tech_priests_cogitator_screen_table_0564.graphical_set = {}
    styles.tech_priests_cogitator_screen_table_0564.cell_padding = 4
    styles.tech_priests_cogitator_screen_table_0564.horizontal_spacing = 6
    styles.tech_priests_cogitator_screen_table_0564.vertical_spacing = 4

    styles.tech_priests_cogitator_terminal_label_0564 = clone_style("label")
    styles.tech_priests_cogitator_terminal_label_0564.single_line = false
    styles.tech_priests_cogitator_terminal_label_0564.font_color = { r = 0.20, g = 1.0, b = 0.22 }

    styles.tech_priests_cogitator_screen_scroll_0565 = clone_style("naked_scroll_pane", "scroll_pane")
    styles.tech_priests_cogitator_screen_scroll_0565.graphical_set = {}
    styles.tech_priests_cogitator_screen_scroll_0565.font_color = { r = 0.35, g = 1.0, b = 0.28 }
    styles.tech_priests_cogitator_screen_scroll_0565.extra_padding_when_activated = 0
    styles.tech_priests_cogitator_screen_scroll_0565.top_padding = 6
    styles.tech_priests_cogitator_screen_scroll_0565.bottom_padding = 6
    styles.tech_priests_cogitator_screen_scroll_0565.left_padding = 6
    styles.tech_priests_cogitator_screen_scroll_0565.right_padding = 6
  end
end


-- ============================================================================
-- 0.1.548 Martian micro-machine final explicit sprite doctrine
-- ============================================================================
-- The emergency machines use single custom PNG assets.  Do not let inherited
-- vanilla furnace/boiler/lab/generator visual branches decide their final size.
-- This final data-stage pass overwrites the visible sprite branches with the
-- mod-owned single image at the intended footprint while preserving the logical
-- collision/selection boxes and machine behavior.
do
  local MICRO_PATH = "__tech-priests__/graphics/entity/martian-micro/"
  local dims = {
    ["tech-priests-atmospheric-water-condenser"] = {1254, 1254},
    ["tech-priests-emergency-smelter"] = {1254, 1254},
    ["tech-priests-emergency-laboratorium"] = {1254, 1254},
    ["tech-priests-emergency-boiler"] = {1024, 1024},
    ["tech-priests-emergency-steam-engine"] = {1024, 1024},
  }
  local one_sel = {{-0.50, -0.50}, {0.50, 0.50}}
  local one_col = {{-0.35, -0.35}, {0.35, 0.35}}
  local two_sel = {{-1.00, -1.00}, {1.00, 1.00}}
  local two_col = {{-0.90, -0.90}, {0.90, 0.90}}

  local function sprite_layer(name, scale, shadow)
    local d = dims[name] or {1024, 1024}
    return {
      filename = MICRO_PATH .. name .. (shadow and "-shadow.png" or ".png"),
      priority = "high",
      width = d[1],
      height = d[2],
      frame_count = 1,
      line_length = 1,
      scale = scale,
      shift = shadow and {0.08, 0.08} or {0, 0},
      draw_as_shadow = shadow or nil
    }
  end

  local function single_animation(name, scale)
    return { layers = { sprite_layer(name, scale, true), sprite_layer(name, scale, false) } }
  end

  local function boiler_pictures(name, scale)
    local function direction_picture()
      local anim = single_animation(name, scale)
      -- Structure owns the machine image.  Fire/glow use the same image only as
      -- a validation-safe no-frame fallback and are intentionally neutralized by
      -- clearing inherited working visual branches below.
      return { structure = anim, fire = anim, fire_glow = anim }
    end
    return { north = direction_picture(), east = direction_picture(), south = direction_picture(), west = direction_picture() }
  end

  local function clear_inherited_visual_noise(proto)
    if not proto then return end
    proto.graphics_set = nil
    proto.graphics_set_flipped = nil
    proto.working_visualisations = nil
    proto.integration_patch = nil
    proto.frozen_patch = nil
    proto.water_reflection = nil
    proto.base_picture = nil
  end

  -- 1254px art at 0.051 ~= 64px in-world, i.e. a two-tile visual footprint.
  -- 1024px art at 0.0625 ~= 64px in-world, i.e. a two-tile visual footprint.
  -- 1254px art at 0.0255 ~= 32px in-world, i.e. a one-tile visual footprint.
  local condenser = data.raw["assembling-machine"] and data.raw["assembling-machine"]["tech-priests-atmospheric-water-condenser"]
  if condenser then
    clear_inherited_visual_noise(condenser)
    condenser.selection_box = table.deepcopy(two_sel)
    condenser.collision_box = table.deepcopy(two_col)
    condenser.drawing_box_vertical_extension = 0.20
    condenser.graphics_set = { animation = single_animation("tech-priests-atmospheric-water-condenser", 0.051) }
  end

  local boiler = data.raw.boiler and data.raw.boiler["tech-priests-emergency-boiler"]
  if boiler then
    clear_inherited_visual_noise(boiler)
    boiler.selection_box = table.deepcopy(two_sel)
    boiler.collision_box = table.deepcopy(two_col)
    boiler.drawing_box_vertical_extension = 0.20
    boiler.pictures = boiler_pictures("tech-priests-emergency-boiler", 0.0625)
  end

  local engine = data.raw.generator and data.raw.generator["tech-priests-emergency-steam-engine"]
  if engine then
    clear_inherited_visual_noise(engine)
    engine.selection_box = table.deepcopy(two_sel)
    engine.collision_box = table.deepcopy(two_col)
    engine.drawing_box_vertical_extension = 0.20
    engine.horizontal_animation = single_animation("tech-priests-emergency-steam-engine", 0.0625)
    engine.vertical_animation = single_animation("tech-priests-emergency-steam-engine", 0.0625)
    engine.horizontal_frozen_patch = nil
    engine.vertical_frozen_patch = nil
  end

  local smelter = data.raw.furnace and data.raw.furnace["tech-priests-emergency-smelter"]
  if smelter then
    clear_inherited_visual_noise(smelter)
    smelter.selection_box = table.deepcopy(one_sel)
    smelter.collision_box = table.deepcopy(one_col)
    smelter.drawing_box_vertical_extension = 0.18
    -- 0.1.553: the furnace was invisible because the furnace render branch was
    -- not consistently using the field we overwrote. Put the same single-asset
    -- sprite on both accepted furnace paths. Slightly oversize the one-tile art
    -- so it remains visible in-world without changing collision/selection.
    local smelter_animation_0553 = single_animation("tech-priests-emergency-smelter", 0.040)
    smelter.animation = smelter_animation_0553
    smelter.graphics_set = { animation = smelter_animation_0553 }
    smelter.working_visualisations = nil
  end

  local lab = data.raw.lab and data.raw.lab["tech-priests-emergency-laboratorium"]
  if lab then
    clear_inherited_visual_noise(lab)
    lab.selection_box = table.deepcopy(one_sel)
    lab.collision_box = table.deepcopy(one_col)
    lab.drawing_box_vertical_extension = 0.12
    lab.on_animation = single_animation("tech-priests-emergency-laboratorium", 0.0255)
    lab.off_animation = single_animation("tech-priests-emergency-laboratorium", 0.0255)
  end
end


-- 0.1.551: final prototype correction for the stone-cache accumulator and
-- pressurized fluid vault after optional compatibility mods have had their say.
-- Transport Drones can tighten storage-tank bounds; keep the vault's real
-- north/south pipe coordinates on the pipe grid and widen only this custom tank
-- so the positions are valid and connectable.
do
  local function tp_stone_cache_sprite_0551(name, scale, shift)
    return {
      layers = {
        {
          filename = "__tech-priests__/graphics/entity/stone-cache/" .. name .. "-shadow.png",
          priority = "high",
          width = 1024,
          height = 1024,
          frame_count = 1,
          line_length = 1,
          draw_as_shadow = true,
          shift = shift and {(shift[1] or 0) + 0.08, (shift[2] or 0) + 0.08} or {0.08, 0.08},
          scale = scale or 0.068
        },
        {
          filename = "__tech-priests__/graphics/entity/stone-cache/" .. name .. ".png",
          priority = "high",
          width = 1024,
          height = 1024,
          frame_count = 1,
          line_length = 1,
          shift = shift or {0, 0},
          scale = scale or 0.068
        }
      }
    }
  end

  local battery_name = "tech-priests-stone-cache-primitive-acclimator-battery-bank"
  local bank = data.raw.accumulator and data.raw.accumulator[battery_name]
  if bank then
    bank.picture = nil
    bank.charge_animation = nil
    bank.discharge_animation = nil
    bank.charge_cooldown = nil
    bank.discharge_cooldown = nil
    bank.integration_patch = nil
    bank.water_reflection = nil
    bank.icon = "__tech-priests__/graphics/icons/stone-cache/" .. battery_name .. ".png"
    bank.icon_size = 64
    bank.chargable_graphics = {
      picture = tp_stone_cache_sprite_0551(battery_name, 0.068),
      charge_animation = tp_stone_cache_sprite_0551(battery_name, 0.068),
      charge_cooldown = 30,
      discharge_animation = tp_stone_cache_sprite_0551(battery_name, 0.068),
      discharge_cooldown = 30
    }
    bank.energy_source = bank.energy_source or { type = "electric" }
    -- 0.1.553: requested primitive acclimator battery-bank tuning.
    -- Accumulator storage is energy, so use a 1MJ buffer with 500kW I/O.
    bank.energy_source.buffer_capacity = "1MJ"
    bank.energy_source.input_flow_limit = "500kW"
    bank.energy_source.output_flow_limit = "500kW"
    bank.energy_source.render_no_network_icon = true
  end

  local vault_name = "tech-priests-stone-cache-pressurized-fluid-vault"
  local vault = data.raw["storage-tank"] and data.raw["storage-tank"][vault_name]
  if vault then
    vault.collision_box = {{-1.10, -1.10}, {1.10, 1.10}}
    vault.selection_box = {{-1.15, -1.15}, {1.15, 1.15}}
    vault.pictures = {
      picture = tp_stone_cache_sprite_0551(vault_name, 0.068)
    }
    vault.water_reflection = nil
    vault.integration_patch = nil
    vault.fluid_box = vault.fluid_box or {}
    vault.fluid_box.volume = vault.fluid_box.volume or 1000
    vault.fluid_box.pipe_connections = {
      { flow_direction = "input-output", direction = defines.direction.north, position = {0, -1.0} },
      { flow_direction = "input-output", direction = defines.direction.south, position = {0, 1.0} }
    }
    vault.fluid_box.pipe_covers = nil
    vault.fluid_box.pipe_picture = nil
  end
end


-- 0.1.586 optional lean GUI sprite swaps.
require("prototypes.lean_graphics_0586")
