-- 0.1.558 Conclave Center prototype.
-- Physical console anchor for Tech-Priest management and doctrine governance.

local util = require("util")

local ENTITY = "tech-priests-conclave-center"
local ICON = "__tech-priests__/graphics/entity/martian-micro/future/emm13.png"
local WIDTH = 1024
local HEIGHT = 1024
local SCALE = 0.0625 -- 1024px * 0.0625 = 64px, a readable 2x2-ish footprint.

local entity = {
  type = "container",
  name = ENTITY,
  icon = ICON,
  icon_size = 1024,
  flags = { "placeable-neutral", "player-creation" },
  minable = { mining_time = 0.4, result = ENTITY },
  max_health = 450,
  corpse = "small-remnants",
  dying_explosion = (data.raw.explosion and data.raw.explosion["medium-explosion"] and "medium-explosion") or "explosion",
  collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
  selection_box = { { -1.0, -1.0 }, { 1.0, 1.0 } },
  inventory_size = 1,
  picture = {
    layers = {
      {
        filename = ICON,
        priority = "high",
        width = WIDTH,
        height = HEIGHT,
        scale = SCALE,
        shift = util.by_pixel(0, -8)
      }
    }
  },
  open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.5 },
  close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.45 }
}

local item = {
  type = "item",
  name = ENTITY,
  icon = ICON,
  icon_size = 1024,
  subgroup = "tech-priest-cogitators",
  order = "e[conclave-center]",
  place_result = ENTITY,
  stack_size = 10
}

local recipe = {
  type = "recipe",
  name = ENTITY,
  enabled = false,
  category = "crafting",
  energy_required = 20,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "processing-unit", amount = 10 },
    { type = "item", name = "low-density-structure", amount = 8 },
    { type = "item", name = "senior-cogitator-station", amount = 1 }
  },
  results = { { type = "item", name = ENTITY, amount = 1 } }
}

-- Add the unlock to the Planetary Magos research without reordering the tree.
if data.raw.technology and data.raw.technology["planetary-magos-cogitator-stations"] then
  local effects = data.raw.technology["planetary-magos-cogitator-stations"].effects or {}
  effects[#effects + 1] = { type = "unlock-recipe", recipe = ENTITY }
  data.raw.technology["planetary-magos-cogitator-stations"].effects = effects
end

data:extend({ entity, item, recipe })
