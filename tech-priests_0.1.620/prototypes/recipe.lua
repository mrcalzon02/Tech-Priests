-- Tech Priests - recipe prototypes.
-- Temporary Cogitator recipes remain intentionally cheap while the behavior stack is validated.

local recipes = {}

local MARTIAN_MICRO_ICON_SIZE = 128
local MARTIAN_MICRO_ICON_PATH = "__tech-priests__/graphics/icons/martian-micro/"

local function tech_priests_micro_icon_path(name)
  return MARTIAN_MICRO_ICON_PATH .. name .. ".png"
end

local function soften_station_tint_for_recipe_0313(tint)
  tint = tint or { r = 1, g = 1, b = 1, a = 1 }
  local blend = 0.44
  return {
    r = 1.0 - ((1.0 - (tint.r or 1.0)) * blend),
    g = 1.0 - ((1.0 - (tint.g or 1.0)) * blend),
    b = 1.0 - ((1.0 - (tint.b or 1.0)) * blend),
    a = 1.0
  }
end

local station_recipe_tints_0313 = {
  ["junior-cogitator-station"] = { r = 1.0, g = 0.58, b = 0.18, a = 1.0 },
  ["intermediate-cogitator-station"] = { r = 0.70, g = 0.70, b = 0.70, a = 1.0 },
  ["senior-cogitator-station"] = { r = 0.92, g = 0.10, b = 0.08, a = 1.0 },
  ["planetary-magos-cogitator-station"] = { r = 0.08, g = 0.07, b = 0.06, a = 1.0 },
  ["void-cogitator-station"] = { r = 1.00, g = 0.96, b = 0.86, a = 1.0 }
}

local station_recipe_icons_0534 = {
  ["junior-cogitator-station"] = "__tech-priests__/graphics/icons/junior-cogitator-station.png",
  ["intermediate-cogitator-station"] = "__tech-priests__/graphics/icons/cogitator-station.png",
  ["senior-cogitator-station"] = "__tech-priests__/graphics/icons/senior-cogitator-station.png",
  ["planetary-magos-cogitator-station"] = "__tech-priests__/graphics/icons/planetary-magos-cogitator-station.png",
  ["void-cogitator-station"] = "__tech-priests__/graphics/icons/void-cogitator-station.png"
}

local station_recipes = {
  {
    name = "junior-cogitator-station",
    energy_required = 8,
    ingredients = {
      { type = "item", name = "offworld-cogitator-components", amount = 2 },
      { type = "item", name = "servitor-parts", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "advanced-circuit", amount = 2 },
      { type = "item", name = "copper-cable", amount = 20 }
    }
  },
  {
    name = "intermediate-cogitator-station",
    energy_required = 12,
    ingredients = {
      { type = "item", name = "junior-cogitator-station", amount = 1 },
      { type = "item", name = "offworld-cogitator-components", amount = 4 },
      { type = "item", name = "servitor-parts", amount = 3 },
      { type = "item", name = "machine-maintenance-litany", amount = 2 },
      { type = "item", name = "advanced-circuit", amount = 6 }
    }
  },
  {
    name = "senior-cogitator-station",
    energy_required = 16,
    ingredients = {
      { type = "item", name = "intermediate-cogitator-station", amount = 1 },
      { type = "item", name = "offworld-cogitator-components", amount = 6 },
      { type = "item", name = "servitor-parts", amount = 5 },
      { type = "item", name = "machine-maintenance-litany", amount = 4 },
      { type = "item", name = "relic-fragment", amount = 1 },
      { type = "item", name = "void-sealed-cargo", amount = 1 }
    }
  },
  {
    name = "planetary-magos-cogitator-station",
    energy_required = 20,
    ingredients = {
      { type = "item", name = "senior-cogitator-station", amount = 1 },
      { type = "item", name = "offworld-cogitator-components", amount = 8 },
      { type = "item", name = "servitor-parts", amount = 6 },
      { type = "item", name = "machine-maintenance-litany", amount = 6 },
      { type = "item", name = "relic-fragment", amount = 2 },
      { type = "item", name = "processing-unit", amount = 8 },
      { type = "item", name = "roboport", amount = 1 }
    }
  },
  {
    name = "void-cogitator-station",
    energy_required = 22,
    ingredients = {
      { type = "item", name = "planetary-magos-cogitator-station", amount = 1 },
      { type = "item", name = "offworld-cogitator-components", amount = 10 },
      { type = "item", name = "servitor-parts", amount = 8 },
      { type = "item", name = "machine-maintenance-litany", amount = 6 },
      { type = "item", name = "relic-fragment", amount = 2 },
      { type = "item", name = "void-sealed-cargo", amount = 3 }
    }
  }
}

for _, spec in pairs(station_recipes) do
  table.insert(recipes, {
    type = "recipe",
    name = spec.name,
    icon = nil,
    icon_size = nil,
    icons = {
      {
        icon = station_recipe_icons_0534[spec.name] or "__tech-priests__/graphics/icons/cogitator-station.png",
        icon_size = 64,
        tint = soften_station_tint_for_recipe_0313(station_recipe_tints_0313[spec.name])
      }
    },
    category = "crafting",
    enabled = false,
    energy_required = spec.energy_required,
    ingredients = spec.ingredients,
    results = {
      { type = "item", name = spec.name, amount = 1 }
    }
  })
end

-- Basic sacred oil is intentionally default-unlocked, but it now requires steam.
-- That moves actual production into early boiler/assembler logistics instead of
-- letting the player hand-craft a miracle from plates and cable.

-- 0.1.348: absolute-start emergency consecration oil. This exists because the
-- normal Sacred Machine Oil recipe needs steam/fluid handling, which blocks
-- survival consecration testing before the bootstrap chain exists.

-- 0.1.479: emergency Martian repair pack.  This is deliberately brutal: start-unlocked
-- and available to the player / emergency micro-assembler, but expensive enough
-- that a real vanilla repair-pack recipe is still preferable as soon as the cell
-- can support proper industry.
table.insert(recipes, {
  type = "recipe",
  name = "tech-priests-emergency-repair-pack",
  localised_name = { "recipe-name.tech-priests-emergency-repair-pack" },
  localised_description = { "recipe-description.tech-priests-emergency-repair-pack" },
  icon = "__base__/graphics/icons/repair-pack.png",
  icon_size = 64,
  category = "crafting",
  subgroup = "tech-priest-emergency-industry",
  order = "i[emergency-repair-pack]",
  enabled = true,
  hidden = false,
  energy_required = 6,
  ingredients = {
    { type = "item", name = "copper-plate", amount = 4 },
    { type = "item", name = "iron-plate", amount = 7 }
  },
  results = {
    { type = "item", name = "repair-pack", amount = 1 }
  },
  main_product = "repair-pack",
  allow_productivity = false
})

table.insert(recipes, {
  type = "recipe",
  name = "emergency-sacred-machine-oil",
  localised_name = { "recipe-name.emergency-sacred-machine-oil" },
  localised_description = { "recipe-description.emergency-sacred-machine-oil" },
  icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
  icon_size = 64,
  category = "crafting",
  enabled = true,
  energy_required = 4,
  ingredients = {
    { type = "item", name = "coal", amount = 3 },
    { type = "item", name = "wood", amount = 5 }
  },
  results = {
    { type = "item", name = "sacred-machine-oil", amount = 1 }
  },
  main_product = "sacred-machine-oil",
  allow_productivity = false
})

table.insert(recipes, {
  type = "recipe",
  name = "sacred-machine-oil",
  icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
  icon_size = 64,
  category = "crafting-with-fluid",
  enabled = true,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "wood", amount = 1 },
    { type = "item", name = "coal", amount = 1 },
    { type = "fluid", name = "steam", amount = 100 }
  },
  results = {
    { type = "item", name = "sacred-machine-oil", amount = 1 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "ritual-salt",
  icon = "__tech-priests__/graphics/icons/ritual-salt.png",
  icon_size = 64,
  category = "crafting-with-fluid",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "fluid", name = "water", amount = 100 }
  },
  results = {
    { type = "item", name = "ritual-salt", amount = 8 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "pure-carbon",
  icon = "__tech-priests__/graphics/icons/pure-carbon.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "coal", amount = 2 }
  },
  results = {
    { type = "item", name = "pure-carbon", amount = 3 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "sodium-carbonate",
  icon = "__tech-priests__/graphics/icons/sodium-carbonate.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "ritual-salt", amount = 2 },
    { type = "item", name = "pure-carbon", amount = 1 }
  },
  results = {
    { type = "item", name = "sodium-carbonate", amount = 2 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "wood-pulp",
  icon = "__tech-priests__/graphics/icons/wood-pulp.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 1,
  ingredients = {
    { type = "item", name = "wood", amount = 1 }
  },
  results = {
    { type = "item", name = "wood-pulp", amount = 4 }
  }
})

-- Four times as efficient by output amount versus the crude default oil recipe.
table.insert(recipes, {
  type = "recipe",
  name = "efficient-sacred-machine-oil",
  localised_name = { "recipe-name.efficient-sacred-machine-oil" },
  icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
  icon_size = 64,
  category = "crafting-with-fluid",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "wood-pulp", amount = 1 },
    { type = "item", name = "sodium-carbonate", amount = 1 },
    { type = "fluid", name = "steam", amount = 100 }
  },
  results = {
    { type = "item", name = "sacred-machine-oil", amount = 4 }
  },
  main_product = "sacred-machine-oil"
})


table.insert(recipes, {
  type = "recipe",
  name = "orbital-trader",
  icon = "__tech-priests__/graphics/icons/orbital-trader.png",
  icon_size = 128,
  category = "crafting",
  enabled = false,
  energy_required = 10,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 40 },
    { type = "item", name = "electronic-circuit", amount = 30 },
    { type = "item", name = "advanced-circuit", amount = 5 },
    { type = "item", name = "copper-cable", amount = 40 },
    { type = "item", name = "sacred-machine-oil", amount = 20 }
  },
  results = {
    { type = "item", name = "orbital-trader", amount = 1 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "orbital-trade-offworld-cogitator-components",
  localised_name = { "recipe-name.orbital-trade-offworld-cogitator-components" },
  icon = "__tech-priests__/graphics/icons/offworld-cogitator-components.png",
  icon_size = 64,
  category = "orbital-trader",
  enabled = false,
  energy_required = 20,
  ingredients = {
    { type = "item", name = "sacred-machine-oil", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 }
  },
  results = { { type = "item", name = "offworld-cogitator-components", amount = 1 } }
})

table.insert(recipes, {
  type = "recipe",
  name = "orbital-trade-servitor-parts",
  localised_name = { "recipe-name.orbital-trade-servitor-parts" },
  icon = "__tech-priests__/graphics/icons/servitor-parts.png",
  icon_size = 64,
  category = "orbital-trader",
  enabled = false,
  energy_required = 20,
  ingredients = {
    { type = "item", name = "sacred-machine-oil", amount = 12 },
    { type = "item", name = "iron-gear-wheel", amount = 10 }
  },
  results = { { type = "item", name = "servitor-parts", amount = 1 } }
})

table.insert(recipes, {
  type = "recipe",
  name = "orbital-trade-relic-fragment",
  localised_name = { "recipe-name.orbital-trade-relic-fragment" },
  icon = "__tech-priests__/graphics/icons/relic-fragment.png",
  icon_size = 64,
  category = "orbital-trader",
  enabled = false,
  energy_required = 30,
  ingredients = {
    { type = "item", name = "machine-maintenance-litany", amount = 2 },
    { type = "item", name = "steel-plate", amount = 10 }
  },
  results = { { type = "item", name = "relic-fragment", amount = 1 } }
})

table.insert(recipes, {
  type = "recipe",
  name = "orbital-trade-void-sealed-cargo",
  localised_name = { "recipe-name.orbital-trade-void-sealed-cargo" },
  icon = "__tech-priests__/graphics/icons/void-sealed-cargo.png",
  icon_size = 64,
  category = "orbital-trader",
  enabled = false,
  energy_required = 45,
  ingredients = {
    { type = "item", name = "sacred-machine-oil", amount = 20 },
    { type = "item", name = "repair-pack", amount = 5 }
  },
  results = { { type = "item", name = "void-sealed-cargo", amount = 1 } }
})

-- 0.1.415: Void-Sealed Cargo gacha processing. These recipes intentionally
-- produce odd, low-probability multi-output crates rather than deterministic
-- progression materials. The Orbital Trader is used as the controlled processing
-- altar so normal assemblers do not become loot-box engines by accident.
local function tech_priests_void_cargo_result_0415(name, probability, min_amount, max_amount)
  local result = {
    type = "item",
    name = name,
    probability = probability
  }
  if max_amount and max_amount ~= min_amount then
    result.amount_min = min_amount or 1
    result.amount_max = max_amount
  else
    result.amount = min_amount or 1
  end
  return result
end

table.insert(recipes, {
  type = "recipe",
  name = "void-sealed-cargo-scrutiny",
  localised_name = { "recipe-name.void-sealed-cargo-scrutiny" },
  localised_description = { "recipe-description.void-sealed-cargo-scrutiny" },
  icon = "__tech-priests__/graphics/icons/void-sealed-cargo.png",
  icon_size = 64,
  subgroup = "tech-priest-void-cargo",
  order = "a[void-cargo]-a[scrutiny]",
  category = "orbital-trader",
  enabled = false,
  energy_required = 14,
  ingredients = {
    { type = "item", name = "void-sealed-cargo", amount = 1 }
  },
  results = {
    tech_priests_void_cargo_result_0415("auspex-scrap", 0.34, 1, 2),
    tech_priests_void_cargo_result_0415("hexagrammic-circuit-shard", 0.26, 1, 2),
    tech_priests_void_cargo_result_0415("archeotech-capacitor", 0.22, 1, 2),
    tech_priests_void_cargo_result_0415("micro-servitor-actuator", 0.18, 1, 1),
    tech_priests_void_cargo_result_0415("machine-spirit-bound-relay", 0.20, 1, 1),
    tech_priests_void_cargo_result_0415("sanctified-lens-array", 0.13, 1, 1),
    tech_priests_void_cargo_result_0415("plasma-coil-reliquary", 0.08, 1, 1),
    tech_priests_void_cargo_result_0415("void-burned-cogitator-core", 0.06, 1, 1),
    tech_priests_void_cargo_result_0415("offworld-cogitator-components", 0.11, 1, 2),
    tech_priests_void_cargo_result_0415("relic-fragment", 0.025, 1, 1)
  },
  allow_productivity = false,
  allow_decomposition = false
})

table.insert(recipes, {
  type = "recipe",
  name = "void-sealed-cargo-militant-unsealing",
  localised_name = { "recipe-name.void-sealed-cargo-militant-unsealing" },
  localised_description = { "recipe-description.void-sealed-cargo-militant-unsealing" },
  icon = "__tech-priests__/graphics/icons/las-carbine.png",
  icon_size = 64,
  subgroup = "tech-priest-void-cargo",
  order = "a[void-cargo]-b[militant]",
  category = "orbital-trader",
  enabled = false,
  energy_required = 18,
  ingredients = {
    { type = "item", name = "void-sealed-cargo", amount = 1 },
    { type = "item", name = "repair-pack", amount = 1 }
  },
  results = {
    tech_priests_void_cargo_result_0415("hot-shot-power-cell", 0.22, 1, 3),
    tech_priests_void_cargo_result_0415("las-carbine", 0.035, 1, 1),
    tech_priests_void_cargo_result_0415("rite-sealed-flak-vest", 0.025, 1, 1),
    tech_priests_void_cargo_result_0415("mars-pattern-repair-kit", 0.16, 1, 2),
    tech_priests_void_cargo_result_0415("noospheric-targeter", 0.08, 1, 1),
    tech_priests_void_cargo_result_0415("combat-servitor-targeting-eye", 0.07, 1, 1),
    tech_priests_void_cargo_result_0415("spent-phosphor-lumen", 0.12, 1, 2),
    tech_priests_void_cargo_result_0415("firearm-magazine", 0.18, 1, 2),
    tech_priests_void_cargo_result_0415("piercing-rounds-magazine", 0.09, 1, 1),
    tech_priests_void_cargo_result_0415("grenade", 0.04, 1, 1)
  },
  allow_productivity = false,
  allow_decomposition = false
})

table.insert(recipes, {
  type = "recipe",
  name = "void-sealed-cargo-riteful-sorting",
  localised_name = { "recipe-name.void-sealed-cargo-riteful-sorting" },
  localised_description = { "recipe-description.void-sealed-cargo-riteful-sorting" },
  icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
  icon_size = 64,
  subgroup = "tech-priest-void-cargo",
  order = "a[void-cargo]-c[riteful]",
  category = "orbital-trader",
  enabled = false,
  energy_required = 22,
  ingredients = {
    { type = "item", name = "void-sealed-cargo", amount = 1 },
    { type = "item", name = "sacred-machine-oil", amount = 2 }
  },
  results = {
    tech_priests_void_cargo_result_0415("red-robe-fiber-bundle", 0.24, 1, 3),
    tech_priests_void_cargo_result_0415("sealed-ration-cache", 0.20, 1, 2),
    tech_priests_void_cargo_result_0415("omen-bearing-data-slate", 0.15, 1, 1),
    tech_priests_void_cargo_result_0415("ritually-suspect-machine-plate", 0.25, 1, 4),
    tech_priests_void_cargo_result_0415("void-chilled-lubricant-ampoule", 0.17, 1, 2),
    tech_priests_void_cargo_result_0415("servitor-parts", 0.09, 1, 1),
    tech_priests_void_cargo_result_0415("machine-maintenance-litany", 0.06, 1, 1),
    tech_priests_void_cargo_result_0415("sacred-incense-grenade", 0.035, 1, 1),
    tech_priests_void_cargo_result_0415("ritual-of-machine-appeasement", 0.02, 1, 1),
    tech_priests_void_cargo_result_0415("relic-fragment", 0.03, 1, 1)
  },
  allow_productivity = false,
  allow_decomposition = false
})

table.insert(recipes, {
  type = "recipe",
  name = "paraffin",
  icon = "__tech-priests__/graphics/icons/paraffin.png",
  icon_size = 64,
  category = "chemistry",
  enabled = false,
  energy_required = 3,
  ingredients = {
    { type = "fluid", name = "crude-oil", amount = 50 }
  },
  results = {
    { type = "item", name = "paraffin", amount = 2 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "sacred-candle",
  icon = "__tech-priests__/graphics/icons/sacred-candle.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "paraffin", amount = 2 },
    { type = "item", name = "sacred-machine-oil", amount = 1 }
  },
  results = {
    { type = "item", name = "sacred-candle", amount = 4 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "machine-maintenance-litany",
  icon = "__tech-priests__/graphics/icons/machine-maintenance-litany.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 3,
  ingredients = {
    { type = "item", name = "sacred-candle", amount = 2 },
    { type = "item", name = "iron-gear-wheel", amount = 1 },
    { type = "item", name = "repair-pack", amount = 1 }
  },
  results = {
    { type = "item", name = "machine-maintenance-litany", amount = 1 }
  }
})


table.insert(recipes, {
  type = "recipe",
  name = "sacred-incense-grenade",
  icon = "__tech-priests__/graphics/icons/sacred-incense-grenade.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 4,
  ingredients = {
    { type = "item", name = "sacred-machine-oil", amount = 1 },
    { type = "item", name = "sacred-candle", amount = 2 },
    { type = "item", name = "explosives", amount = 1 }
  },
  results = {
    { type = "item", name = "sacred-incense-grenade", amount = 1 }
  }
})

table.insert(recipes, {
  type = "recipe",
  name = "ritual-of-machine-appeasement",
  icon = "__tech-priests__/graphics/icons/ritual-of-machine-appeasement.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 6,
  ingredients = {
    { type = "item", name = "servitor-parts", amount = 1 },
    { type = "item", name = "machine-maintenance-litany", amount = 2 }
  },
  results = {
    { type = "item", name = "ritual-of-machine-appeasement", amount = 1 }
  }
})


local TECH_PRIESTS_PLANETSIDE_SURFACE_CONDITIONS = {
  { property = "pressure", min = 1 },
  { property = "gravity", min = 1 }
}

-- Horrid emergency micro-industry. These are start-enabled, weak stopgap machines
-- that keep a stranded Tech-Priest cell alive without competing with real industry.
local emergency_industry_recipes = {
  {
    name = "tech-priests-emergency-miner",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-miner"),
    order = "a[emergency-miner]",
    energy_required = 2,
    -- 0.1.287: Martian emergency hardware must be primitive enough for
    -- stranded priests to bootstrap immediately: at most one unit of up to
    -- two ingredients per device.
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "stone", amount = 1 }
    }
  },
  {
    name = "tech-priests-emergency-boiler",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-boiler"),
    order = "b[emergency-boiler]",
    energy_required = 2,
    ingredients = {
      { type = "item", name = "stone", amount = 1 },
      { type = "item", name = "iron-plate", amount = 1 }
    }
  },
  {
    name = "tech-priests-atmospheric-water-condenser",
    icon = tech_priests_micro_icon_path("tech-priests-atmospheric-water-condenser"),
    order = "c[atmospheric-water-condenser]",
    energy_required = 3,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "copper-plate", amount = 1 }
    }
  },
  {
    name = "tech-priests-emergency-steam-engine",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-steam-engine"),
    order = "d[emergency-steam-engine]",
    energy_required = 3,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "iron-gear-wheel", amount = 1 }
    }
  },
  {
    name = "tech-priests-emergency-smelter",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-smelter"),
    order = "e[emergency-smelter]",
    energy_required = 2,
    ingredients = {
      { type = "item", name = "stone", amount = 4 }
    }
  },
  {
    name = "tech-priests-emergency-assembler",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-assembler"),
    order = "f[emergency-assembler]",
    energy_required = 3,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "iron-gear-wheel", amount = 1 }
    }
  },
  {
    name = "tech-priests-emergency-laboratorium",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-laboratorium"),
    order = "g[emergency-laboratorium]",
    energy_required = 4,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "copper-plate", amount = 1 }
    }
  },
  {
    name = "tech-priests-emergency-power-grid",
    icon = tech_priests_micro_icon_path("tech-priests-emergency-power-grid"),
    order = "h[emergency-power-grid]",
    energy_required = 1,
    ingredients = {
      { type = "item", name = "wood", amount = 1 },
      { type = "item", name = "copper-plate", amount = 1 }
    }
  }
}

for _, spec in pairs(emergency_industry_recipes) do
  table.insert(recipes, {
    type = "recipe",
    name = spec.name,
    localised_name = { "recipe-name." .. spec.name },
    localised_description = { "recipe-description." .. spec.name },
    icon = spec.icon,
    icon_size = MARTIAN_MICRO_ICON_SIZE,
    category = "crafting",
    subgroup = "tech-priest-emergency-industry",
    order = spec.order or spec.name,
    enabled = true,
    hidden = false,
    energy_required = spec.energy_required,
    ingredients = spec.ingredients,
    results = { { type = "item", name = spec.name, amount = 1 } },
    main_product = spec.name,
    always_show_products = true
  })
end

table.insert(recipes, {
  type = "recipe",
  name = "tech-priests-atmospheric-water-condensing",
  localised_name = { "recipe-name.tech-priests-atmospheric-water-condensing" },
  localised_description = { "", "A fuel-fed emergency condensation rite. The condenser burns raw chemical fuel so water can be made before the emergency electrical grid exists." },
  icon = "__base__/graphics/icons/fluid/water.png",
  icon_size = 64,
  category = "tech-priests-atmospheric-condensing",
  enabled = true,
  hidden = false,
  energy_required = 30,
  ingredients = {},
  results = { { type = "fluid", name = "water", amount = 30 } },
  main_product = "water"
})


-- 0.1.250 Emergency Micro-Miner pseudo-mining recipes.
-- These recipes are hidden, zero-input, long-wait rites that only the
-- tech-priests-emergency-miner can run through its private recipe category.
-- They replace the old doctrine where the emergency miner had to pretend to be
-- a real mining drill or have the control script magically spawn quarry crumbs.
local function tech_priests_item_exists_0250(name)
  return name and data.raw.item and data.raw.item[name]
end

local function tech_priests_recipe_exists_0250(name)
  return name and data.raw.recipe and data.raw.recipe[name]
end

local function tech_priests_get_item_icon_0250(name)
  local item = data.raw.item and data.raw.item[name]
  if item then
    if item.icon then return item.icon, item.icon_size or 64 end
    if item.icons then return nil, nil, table.deepcopy(item.icons) end
  end
  return "__base__/graphics/icons/stone.png", 64, nil
end

local function tech_priests_safe_recipe_suffix_0250(name)
  return string.gsub(name or "unknown", "[^%w%-_]", "-")
end

local emergency_miner_recipe_outputs_0250 = {}
local emergency_miner_recipe_seen_0250 = {}

local function tech_priests_add_emergency_miner_output_0250(item_name, order_prefix, seconds)
  if not tech_priests_item_exists_0250(item_name) then return end
  if emergency_miner_recipe_seen_0250[item_name] then return end
  emergency_miner_recipe_seen_0250[item_name] = true
  emergency_miner_recipe_outputs_0250[#emergency_miner_recipe_outputs_0250 + 1] = {
    item_name = item_name,
    order = order_prefix or "z",
    energy_required = seconds or 45
  }
end

-- Basic emergency survival outputs.  "wood" is intentionally included even
-- though it is tree-salvage rather than an ore patch; the machine is a pseudo-
-- miner, not a respectable industrial drill.
tech_priests_add_emergency_miner_output_0250("wood", "a[wood]", 180)
tech_priests_add_emergency_miner_output_0250("stone", "b[stone]", 180)
tech_priests_add_emergency_miner_output_0250("iron-ore", "c[iron-ore]", 240)
tech_priests_add_emergency_miner_output_0250("copper-ore", "d[copper-ore]", 240)
tech_priests_add_emergency_miner_output_0250("coal", "e[coal]", 240)
tech_priests_add_emergency_miner_output_0250("uranium-ore", "f[uranium-ore]", 720)

local function tech_priests_emergency_miner_seconds_for_resource_0554(resource_name, item_name)
  local key = string.lower(tostring(resource_name or item_name or ""))
  if key:find("uranium") then return 720 end
  if key:find("tungsten") or key:find("holmium") or key:find("lithium") or key:find("rare") or key:find("blackstone") or key:find("vulcanus") or key:find("fulgora") or key:find("gleba") or key:find("aquilo") then
    return 1200
  end
  return 900
end

-- Compatibility wrapper: discover item products from any resource prototype
-- supplied by other mods and add a matching emergency-mining rite.
if data.raw.resource then
  for resource_name, resource in pairs(data.raw.resource) do
    local minable = resource.minable
    if minable then
      local function add_product(product)
        if not product then return end
        local ptype = product.type or "item"
        local pname = product.name or product[1]
        if ptype == "item" and pname then
          tech_priests_add_emergency_miner_output_0250(pname, "m[modded]-[" .. tech_priests_safe_recipe_suffix_0250(resource_name) .. "]", tech_priests_emergency_miner_seconds_for_resource_0554(resource_name, pname))
        end
      end
      if minable.result then
        tech_priests_add_emergency_miner_output_0250(minable.result, "m[modded]-[" .. tech_priests_safe_recipe_suffix_0250(resource_name) .. "]", tech_priests_emergency_miner_seconds_for_resource_0554(resource_name, minable.result))
      end
      if minable.results then
        for _, product in pairs(minable.results) do add_product(product) end
      end
    end
  end
end

for _, spec in pairs(emergency_miner_recipe_outputs_0250) do
  local item_name = spec.item_name
  local recipe_name = "tech-priests-emergency-mine-" .. tech_priests_safe_recipe_suffix_0250(item_name)
  if not tech_priests_recipe_exists_0250(recipe_name) then
    local icon, icon_size, icons = tech_priests_get_item_icon_0250(item_name)
    local recipe = {
      type = "recipe",
      name = recipe_name,
      localised_name = { "", "Emergency pseudo-mining: ", { "item-name." .. item_name } },
      localised_description = { "", "A slow burner-fed survival rite run only by the Martian Emergency Micro-Miner. Produces one [item=", item_name, "] without a normal ore patch; coal and wood outputs bootstrap condenser/boiler fuel." },
      category = "tech-priests-emergency-mining",
      subgroup = "tech-priest-emergency-industry",
      order = spec.order,
      enabled = true,
      -- 0.1.554: visible in the micro-miner recipe selector, but still impossible
      -- for ordinary machines because the category is private to this entity.
      hidden = false,
      hide_from_stats = false,
      allow_decomposition = false,
      allow_as_intermediate = false,
      allow_intermediates = false,
      energy_required = spec.energy_required,
      ingredients = {},
      results = { { type = "item", name = item_name, amount = 1 } },
      main_product = item_name
    }
    if icons then recipe.icons = icons else recipe.icon = icon; recipe.icon_size = icon_size or 64 end
    table.insert(recipes, recipe)
  end
end

-- 0.1.251 Emergency Martian Assembler smelting rites.
-- The emergency assembler accepts ordinary smelting recipes as a burner-fed
-- hybrid machine, but these hidden wrappers make vanilla and modded ore-to-
-- metal conversions visible to the emergency doctrine under a private category.
local emergency_smelting_seen_0251 = {}

local function tech_priests_recipe_item_ingredient_0251(recipe)
  if not recipe or not recipe.ingredients then return nil, nil end
  for _, ingredient in pairs(recipe.ingredients) do
    local ingredient_type = ingredient.type or "item"
    local ingredient_name = ingredient.name or ingredient[1]
    local ingredient_amount = ingredient.amount or ingredient[2] or 1
    if ingredient_type == "item" and ingredient_name then return ingredient_name, ingredient_amount end
  end
  return nil, nil
end

local function tech_priests_recipe_item_result_0251(recipe)
  if not recipe then return nil, nil end
  if recipe.result then return recipe.result, recipe.result_count or 1 end
  if recipe.results then
    for _, result in pairs(recipe.results) do
      local result_type = result.type or "item"
      local result_name = result.name or result[1]
      local result_amount = result.amount or result[2] or 1
      if result_type == "item" and result_name then return result_name, result_amount end
    end
  end
  return nil, nil
end

local function tech_priests_add_emergency_smelting_recipe_0251(input_item, output_item, output_amount, seconds, order)
  if not tech_priests_item_exists_0250(input_item) or not tech_priests_item_exists_0250(output_item) then return end
  local key = input_item .. "=>" .. output_item
  if emergency_smelting_seen_0251[key] then return end
  emergency_smelting_seen_0251[key] = true
  local recipe_name = "tech-priests-emergency-smelt-" .. tech_priests_safe_recipe_suffix_0250(input_item) .. "-to-" .. tech_priests_safe_recipe_suffix_0250(output_item)
  if tech_priests_recipe_exists_0250(recipe_name) then return end
  local icon, icon_size, icons = tech_priests_get_item_icon_0250(output_item)
  local recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = { "", "Emergency smelting: ", { "item-name." .. input_item }, " → ", { "item-name." .. output_item } },
    localised_description = { "", "A fuel-burning Martian emergency smelting rite run by the Martian Emergency Micro-Smelter. Converts [item=", input_item, "] into [item=", output_item, "] slowly and inefficiently." },
    category = "tech-priests-emergency-smelting",
    subgroup = "tech-priest-emergency-industry",
    order = order or ("s[smelting]-[" .. tech_priests_safe_recipe_suffix_0250(output_item) .. "]"),
    enabled = true,
    hidden = true,
    hide_from_stats = false,
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = false,
    energy_required = seconds or 12,
    ingredients = { { type = "item", name = input_item, amount = 1 } },
    results = { { type = "item", name = output_item, amount = output_amount or 1 } },
    main_product = output_item
  }
  if icons then recipe.icons = icons else recipe.icon = icon; recipe.icon_size = icon_size or 64 end
  table.insert(recipes, recipe)
end

tech_priests_add_emergency_smelting_recipe_0251("iron-ore", "iron-plate", 1, 16, "s[a]-[iron]")
tech_priests_add_emergency_smelting_recipe_0251("copper-ore", "copper-plate", 1, 16, "s[b]-[copper]")
tech_priests_add_emergency_smelting_recipe_0251("stone", "stone-brick", 1, 20, "s[c]-[stone-brick]")

-- Compatibility wrapper: mirror simple item→item recipes from smelting-style
-- categories into the private emergency-smelting category. This catches many
-- modded ores without hard dependencies.
local emergency_smelting_categories_0251 = {
  smelting = true,
  ["advanced-smelting"] = true,
  ["ore-processing"] = true,
  ["crushing"] = false
}

if data.raw.recipe then
  for _, source_recipe in pairs(data.raw.recipe) do
    if source_recipe and emergency_smelting_categories_0251[source_recipe.category or "crafting"] then
      local input_item = tech_priests_recipe_item_ingredient_0251(source_recipe)
      local output_item, output_amount = tech_priests_recipe_item_result_0251(source_recipe)
      if input_item and output_item and input_item ~= output_item then
        tech_priests_add_emergency_smelting_recipe_0251(input_item, output_item, output_amount or 1, math.max(12, (source_recipe.energy_required or 3) * 4), "s[compat]-[" .. tech_priests_safe_recipe_suffix_0250(output_item) .. "]")
      end
    end
  end
end


-- 0.1.590 Schism countermeasure.  Data Spikes are intentionally not cheap:
-- they are a panic-button reclamation tool for rogue doctrine forces, not a
-- normal factory automation primitive.
table.insert(recipes, {
  type = "recipe",
  name = "tech-priests-data-spike",
  icon = "__tech-priests__/graphics/icons/data-spike.png",
  icon_size = 64,
  category = "crafting",
  enabled = false,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "processing-unit", amount = 1 },
    { type = "item", name = "advanced-circuit", amount = 4 },
    { type = "item", name = "copper-cable", amount = 20 },
    { type = "item", name = "ritual-salt", amount = 2 }
  },
  results = { { type = "item", name = "tech-priests-data-spike", amount = 1 } }
})


data:extend(recipes)
