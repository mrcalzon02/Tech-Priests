-- Tech Priests - technology prototypes.
-- Range increases are read by control.lua and applied to all Cogitator tiers.
-- 0.1.72: technology progression is now recipe-aware. Any recipe that consumes
-- vanilla tech-gated ingredients is placed behind the vanilla technology that
-- unlocks those ingredients. Mechanical Detritus is deliberately ignored here
-- because its recycling path can backfeed base ingredients and would create a
-- circular dependency analysis trap.
-- 0.1.542: order strings and late-station prerequisites were re-normalized so
-- material preparation, orbital procurement, station tiers, and station-doctrine
-- upgrades appear in a cleaner recipe-aware sequence instead of sharing order
-- slots or placing Void doctrine beside early radius upgrades.

local function science(count, time)
  return {
    count = count,
    ingredients = {
      { "automation-science-pack", 1 }
    },
    time = time
  }
end

local function red_green_science(count, time)
  return {
    count = count,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 }
    },
    time = time
  }
end

local function red_green_blue_science(count, time)
  return {
    count = count,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 }
    },
    time = time
  }
end

local techs = {
  -- Early ritual chemistry/material preparation.
  {
    type = "technology",
    name = "pure-carbon-processing",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "automation" },
    effects = {
      { type = "unlock-recipe", recipe = "pure-carbon" }
    },
    unit = science(30, 10),
    order = "c-l-a"
  },
  {
    type = "technology",
    name = "ritual-wood-pulping",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "automation" },
    effects = {
      { type = "unlock-recipe", recipe = "wood-pulp" }
    },
    unit = science(35, 10),
    order = "c-l-b"
  },
  {
    type = "technology",
    name = "ritual-salt-extraction",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    -- Water-to-item extraction is a crafting-with-fluid recipe, so it belongs
    -- after automation-2 rather than pretending the player can hand-craft brine.
    prerequisites = { "automation-2" },
    effects = {
      { type = "unlock-recipe", recipe = "ritual-salt" }
    },
    unit = red_green_science(45, 15),
    order = "c-l-c"
  },
  {
    type = "technology",
    name = "sodium-carbonate-synthesis",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "ritual-salt-extraction", "pure-carbon-processing" },
    effects = {
      { type = "unlock-recipe", recipe = "sodium-carbonate" }
    },
    unit = red_green_science(55, 15),
    order = "c-l-d"
  },
  {
    type = "technology",
    name = "efficient-sacred-oil-rendering",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "sodium-carbonate-synthesis", "ritual-wood-pulping", "automation-2" },
    effects = {
      { type = "unlock-recipe", recipe = "efficient-sacred-machine-oil" }
    },
    unit = red_green_science(75, 20),
    order = "c-l-e"
  },

  -- Orbital exchange infrastructure. The machine itself consumes steel and red
  -- circuits, so it must sit behind steel-processing and advanced-circuit.
  {
    type = "technology",
    name = "orbital-trader-deployment",
    icon = "__tech-priests__/graphics/technology/orbital-trader-deployment.png",
    icon_size = 256,
    prerequisites = { "efficient-sacred-oil-rendering", "steel-processing", "advanced-circuit" },
    effects = {
      { type = "unlock-recipe", recipe = "orbital-trader" },
      { type = "unlock-recipe", recipe = "orbital-trade-offworld-cogitator-components" },
      { type = "unlock-recipe", recipe = "orbital-trade-servitor-parts" },
      { type = "unlock-recipe", recipe = "orbital-trade-void-sealed-cargo" }
    },
    unit = red_green_science(120, 30),
    order = "c-m-a"
  },
  {
    type = "technology",
    name = "void-sealed-cargo-unsealing",
    icon = "__tech-priests__/graphics/icons/void-sealed-cargo.png",
    icon_size = 64,
    prerequisites = { "orbital-trader-deployment", "military" },
    effects = {
      { type = "unlock-recipe", recipe = "void-sealed-cargo-scrutiny" },
      { type = "unlock-recipe", recipe = "void-sealed-cargo-militant-unsealing" },
      { type = "unlock-recipe", recipe = "void-sealed-cargo-riteful-sorting" }
    },
    unit = red_green_science(90, 25),
    order = "c-m-b"
  },

  -- Cogitator Stations. Junior stations consume imported orbital parts plus
  -- green/red circuits, so they naturally follow the Orbital Trader.
  {
    type = "technology",
    name = "cogitator-station-deployment",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "orbital-trader-deployment" },
    effects = {
      { type = "unlock-recipe", recipe = "junior-cogitator-station" }
    },
    unit = red_green_science(90, 20),
    order = "c-k-a"
  },

  -- Oil/candle/litany chain. Paraffin is chemistry, so it stays behind vanilla
  -- oil-processing. Litanies do not require Cogitator Stations directly; they
  -- are their own material chain and are then consumed by later station tiers.
  {
    type = "technology",
    name = "paraffin-separation",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "oil-processing", "efficient-sacred-oil-rendering" },
    effects = {
      { type = "unlock-recipe", recipe = "paraffin" }
    },
    unit = red_green_science(75, 20),
    order = "c-l-f"
  },
  {
    type = "technology",
    name = "sacred-candle-rendering",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "paraffin-separation" },
    effects = {
      { type = "unlock-recipe", recipe = "sacred-candle" }
    },
    unit = red_green_science(85, 20),
    order = "c-l-g"
  },
  {
    type = "technology",
    name = "sacred-incense-grenades",
    icon = "__tech-priests__/graphics/icons/sacred-incense-grenade.png",
    icon_size = 64,
    prerequisites = { "sacred-candle-rendering", "explosives" },
    effects = {
      { type = "unlock-recipe", recipe = "sacred-incense-grenade" }
    },
    unit = red_green_science(95, 20),
    order = "c-l-h"
  },
  {
    type = "technology",
    name = "machine-maintenance-litanies",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "sacred-candle-rendering", "sacred-incense-grenades" },
    effects = {
      { type = "unlock-recipe", recipe = "machine-maintenance-litany" }
    },
    unit = red_green_science(100, 25),
    order = "c-l-i"
  },
  -- Machine Spirit baseline improvements. These are runtime-read technologies:
  -- the first pair improves the sanctification new machines begin with, while
  -- the second pair raises the researched maximum capacity from 100 to 110/120.
  {
    type = "technology",
    name = "machine-spirit-initial-consecration-1",
    icon = "__tech-priests__/graphics/icons/sacred-machine-oil.png",
    icon_size = 64,
    prerequisites = { "efficient-sacred-oil-rendering" },
    effects = {},
    unit = red_green_science(90, 20),
    order = "c-l-k-a"
  },
  {
    type = "technology",
    name = "machine-spirit-initial-consecration-2",
    icon = "__tech-priests__/graphics/icons/machine-maintenance-litany.png",
    icon_size = 64,
    prerequisites = { "machine-spirit-initial-consecration-1", "machine-maintenance-litanies" },
    effects = {},
    unit = red_green_science(130, 25),
    order = "c-l-k-b"
  },
  {
    type = "technology",
    name = "machine-spirit-capacity-1",
    icon = "__tech-priests__/graphics/icons/ritual-of-machine-appeasement.png",
    icon_size = 64,
    prerequisites = { "machine-spirit-initial-consecration-2", "ritual-of-machine-appeasement" },
    effects = {},
    unit = red_green_science(160, 30),
    order = "c-l-k-c"
  },
  {
    type = "technology",
    name = "machine-spirit-capacity-2",
    icon = "__tech-priests__/graphics/icons/relic-fragment.png",
    icon_size = 64,
    prerequisites = { "machine-spirit-capacity-1", "senior-cogitator-stations" },
    effects = {},
    unit = red_green_science(220, 35),
    order = "c-l-k-d"
  },


  -- Higher-order orbital imports that consume higher-order ritual materials are
  -- no longer unlocked early with the basic trader.
  {
    type = "technology",
    name = "orbital-relic-procurement",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "orbital-trader-deployment", "machine-maintenance-litanies" },
    effects = {
      { type = "unlock-recipe", recipe = "orbital-trade-relic-fragment" }
    },
    unit = red_green_science(110, 25),
    order = "c-m-c"
  },

  -- Intermediate and senior stations consume the newly staged ritual/orbital
  -- products, so their techs are now downstream of those products.

  {
    type = "technology",
    name = "cogitator-logistic-requisition",
    icon = "__tech-priests__/graphics/icons/cogitator-station.png",
    icon_size = 64,
    prerequisites = { "cogitator-station-deployment", "logistic-system" },
    effects = {},
    unit = red_green_blue_science(200, 30),
    order = "c-k-b-l"
  },
  {
    type = "technology",
    name = "intermediate-cogitator-stations",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-station-deployment", "machine-maintenance-litanies" },
    effects = {
      { type = "unlock-recipe", recipe = "intermediate-cogitator-station" }
    },
    unit = red_green_science(120, 25),
    order = "c-k-b"
  },
  {
    type = "technology",
    name = "senior-cogitator-stations",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "intermediate-cogitator-stations", "orbital-relic-procurement" },
    effects = {
      { type = "unlock-recipe", recipe = "senior-cogitator-station" }
    },
    unit = red_green_science(150, 30),
    order = "c-k-c"
  },
  {
    type = "technology",
    name = "planetary-magos-cogitator-stations",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "senior-cogitator-stations", "utility-science-pack", "logistic-system" },
    effects = {
      { type = "unlock-recipe", recipe = "planetary-magos-cogitator-station" }
    },
    unit = red_green_blue_science(190, 35),
    order = "c-k-d"
  },

  {
    type = "technology",
    name = "tech-priests-data-spike-reclamation-1",
    icon = "__tech-priests__/graphics/icons/data-spike.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-cogitator-stations" },
    effects = {
      { type = "unlock-recipe", recipe = "tech-priests-data-spike" }
    },
    unit = red_green_blue_science(180, 45),
    order = "c-k-e-a"
  },
  {
    type = "technology",
    name = "tech-priests-data-spike-reclamation-2",
    icon = "__tech-priests__/graphics/icons/data-spike.png",
    icon_size = 64,
    prerequisites = { "tech-priests-data-spike-reclamation-1" },
    effects = {},
    unit = red_green_blue_science(260, 55),
    order = "c-k-e-b"
  },
  {
    type = "technology",
    name = "tech-priests-data-spike-reclamation-3",
    icon = "__tech-priests__/graphics/icons/data-spike.png",
    icon_size = 64,
    prerequisites = { "tech-priests-data-spike-reclamation-2" },
    effects = {},
    unit = red_green_blue_science(360, 65),
    order = "c-k-e-c"
  },
  {
    type = "technology",
    name = "tech-priests-data-spike-reclamation-4",
    icon = "__tech-priests__/graphics/icons/data-spike.png",
    icon_size = 64,
    prerequisites = { "tech-priests-data-spike-reclamation-3" },
    effects = {},
    unit = red_green_blue_science(500, 75),
    order = "c-k-e-d"
  },
  {
    type = "technology",
    name = "tech-priests-data-spike-defense",
    icon = "__tech-priests__/graphics/icons/data-spike.png",
    icon_size = 64,
    prerequisites = { "tech-priests-data-spike-reclamation-1" },
    effects = {},
    max_level = "infinite",
    upgrade = true,
    unit = {
      count_formula = "200+100*L",
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 }
      },
      time = 60
    },
    order = "c-k-e-z"
  },
  {
    type = "technology",
    name = "planetary-magos-command-range-1",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-cogitator-stations" },
    effects = {},
    unit = red_green_blue_science(120, 30),
    order = "c-k-d-a"
  },
  {
    type = "technology",
    name = "planetary-magos-command-range-2",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-command-range-1" },
    effects = {},
    unit = red_green_blue_science(140, 30),
    order = "c-k-d-b"
  },
  {
    type = "technology",
    name = "planetary-magos-command-range-3",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-command-range-2" },
    effects = {},
    unit = red_green_blue_science(160, 30),
    order = "c-k-d-c"
  },
  {
    type = "technology",
    name = "planetary-magos-command-range-4",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-command-range-3" },
    effects = {},
    unit = red_green_blue_science(180, 30),
    order = "c-k-d-d"
  },
  {
    type = "technology",
    name = "void-cogitator-stations",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-cogitator-stations", "void-sealed-cargo-unsealing" },
    effects = {
      { type = "unlock-recipe", recipe = "void-cogitator-station" }
    },
    unit = red_green_blue_science(180, 35),
    order = "c-k-e"
  },
  {
    type = "technology",
    name = "ritual-of-machine-appeasement",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "machine-maintenance-litanies", "orbital-trader-deployment" },
    effects = {
      { type = "unlock-recipe", recipe = "ritual-of-machine-appeasement" }
    },
    unit = red_green_science(125, 30),
    order = "c-l-j"
  },

  -- Station improvement technologies remain downstream of the station tiers.
  {
    type = "technology",
    name = "cogitator-operating-radius-1",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-station-deployment" },
    effects = {},
    unit = red_green_science(60, 15),
    order = "c-k-a-r"
  },
  {
    type = "technology",
    name = "cogitator-operating-radius-2",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-operating-radius-1", "intermediate-cogitator-stations" },
    effects = {},
    unit = red_green_science(90, 20),
    order = "c-k-b-r"
  },
  {
    type = "technology",
    name = "cogitator-operating-radius-3",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-operating-radius-2", "senior-cogitator-stations" },
    effects = {},
    unit = red_green_science(120, 25),
    order = "c-k-c-r"
  },
  {
    type = "technology",
    name = "cogitator-radar-sweep-acceleration",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-operating-radius-2", "senior-cogitator-stations", "radar" },
    effects = {},
    unit = red_green_blue_science(130, 25),
    order = "c-k-c-s"
  },

  {
    type = "technology",
    name = "tech-priest-reimprinting-acceleration-1",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "cogitator-station-deployment" },
    effects = {},
    unit = red_green_science(80, 20),
    order = "c-k-a-t"
  },
  {
    type = "technology",
    name = "tech-priest-reimprinting-acceleration-2",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "tech-priest-reimprinting-acceleration-1", "intermediate-cogitator-stations" },
    effects = {},
    unit = red_green_science(120, 25),
    order = "c-k-b-t"
  },
  {
    type = "technology",
    name = "tech-priest-reimprinting-acceleration-3",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "tech-priest-reimprinting-acceleration-2", "senior-cogitator-stations" },
    effects = {},
    unit = red_green_blue_science(160, 30),
    order = "c-k-c-t"
  },
  {
    type = "technology",
    name = "tech-priest-rite-of-kinetic-exemption",
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "senior-cogitator-stations" },
    effects = {},
    unit = red_green_science(150, 30),
    order = "c-k-c-u"
  }
}


-- 0.1.562 doctrine appeasement researches. These are infinite, hard-coded
-- pressure relief rites for the Conclave system: when a doctrine family cannot
-- get its preferred ordinary technology, the player can still research that
-- family's repeatable rite to restore loyalty through the runtime research hook.
local doctrine_appeasement_families_0562 = {
  { key = "logistics", label = "Logistics Reliquary", order = "c-z-a" },
  { key = "industry", label = "Forge-Industry", order = "c-z-b" },
  { key = "energy", label = "Motive Force", order = "c-z-c" },
  { key = "military", label = "Ballistic Litany", order = "c-z-d" },
  { key = "science", label = "Noospheric Inquiry", order = "c-z-e" },
  { key = "space", label = "Void Doctrine", order = "c-z-f" },
  { key = "sanctification", label = "Machine-Spirit Rite", order = "c-z-g" }
}

for _, fam in pairs(doctrine_appeasement_families_0562) do
  techs[#techs + 1] = {
    type = "technology",
    name = "tech-priests-doctrine-appeasement-" .. fam.key,
    icon = "__tech-priests__/graphics/icons/tech-priests-category.png",
    icon_size = 64,
    prerequisites = { "planetary-magos-cogitator-stations" },
    effects = {},
    unit = {
      count_formula = "100+50*L",
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 }
      },
      time = 30
    },
    max_level = "infinite",
    upgrade = true,
    order = fam.order
  }
end


-- 0.1.413 technology icon doctrine sweep.
-- All Tech Priests technologies should present as Tech Priests doctrine first.
-- Use a specific in-mod item/recipe icon only when it directly represents the
-- unlocked thing; use the category cog/skull icon for generic range, radar,
-- re-imprinting, and other abstract doctrine upgrades.  Do not copy vanilla
-- technology icons here: it makes our tech tree look like a scattered annex of
-- base Factorio rather than a single Mechanicus research branch.
local TECH_PRIESTS_CATEGORY_TECH_ICON = "__tech-priests__/graphics/icons/tech-priests-category.png"

local function tech_priests_internal_icon(icon, icon_size)
  return { icon = icon or TECH_PRIESTS_CATEGORY_TECH_ICON, icon_size = icon_size or 64 }
end

local technology_icon_sources = {
  ["pure-carbon-processing"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/pure-carbon.png"),
  ["ritual-wood-pulping"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/wood-pulp.png"),
  ["ritual-salt-extraction"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/ritual-salt.png"),
  ["sodium-carbonate-synthesis"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/sodium-carbonate.png"),
  ["efficient-sacred-oil-rendering"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/sacred-machine-oil.png"),
  ["orbital-trader-deployment"] = tech_priests_internal_icon("__tech-priests__/graphics/technology/orbital-trader-deployment.png", 256),
  ["void-sealed-cargo-unsealing"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/void-sealed-cargo.png"),
  ["cogitator-station-deployment"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/junior-cogitator-station.png"),
  ["paraffin-separation"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/paraffin.png"),
  ["sacred-candle-rendering"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/sacred-candle.png"),
  ["sacred-incense-grenades"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/sacred-incense-grenade.png"),
  ["machine-maintenance-litanies"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/machine-maintenance-litany.png"),
  ["machine-spirit-initial-consecration-1"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/sacred-machine-oil.png"),
  ["machine-spirit-initial-consecration-2"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/machine-maintenance-litany.png"),
  ["machine-spirit-capacity-1"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/ritual-of-machine-appeasement.png"),
  ["machine-spirit-capacity-2"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/relic-fragment.png"),
  ["orbital-relic-procurement"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/relic-fragment.png"),
  ["cogitator-logistic-requisition"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/cogitator-station.png"),
  ["intermediate-cogitator-stations"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/cogitator-station.png"),
  ["senior-cogitator-stations"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/senior-cogitator-station.png"),
  ["planetary-magos-cogitator-stations"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/planetary-magos-cogitator-station.png"),
  ["void-cogitator-stations"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/void-cogitator-station.png"),
  ["ritual-of-machine-appeasement"] = tech_priests_internal_icon("__tech-priests__/graphics/icons/ritual-of-machine-appeasement.png")
}

local function assign_icon_fields(target, icon_fields)
  target.icon = nil
  target.icons = nil
  target.icon_size = nil
  target.icon_mipmaps = nil

  icon_fields = icon_fields or tech_priests_internal_icon(TECH_PRIESTS_CATEGORY_TECH_ICON, 256)
  for key, value in pairs(icon_fields) do
    if value ~= nil then
      target[key] = value
    end
  end
end

for _, technology in pairs(techs) do
  assign_icon_fields(technology, technology_icon_sources[technology.name] or tech_priests_internal_icon(TECH_PRIESTS_CATEGORY_TECH_ICON, 256))
end


data:extend(techs)
