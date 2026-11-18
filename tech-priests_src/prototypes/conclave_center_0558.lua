-- 0.1.558 Conclave Center prototype.
-- Physical console anchor for Tech-Priest management and doctrine governance.

local util = require("util")

local ENTITY = "tech-priests-conclave-center"
local ICON = "__tech-priests__/graphics/entity/conclave-center-v08/icon.png"
local WIDTH = 512
local HEIGHT = 512
local SCALE = 3.15 * 32 / 512 -- exact orthographic tile-to-pixel scale

local entity = {
  type = "container",
  name = ENTITY,
  icon = ICON,
  icon_size = 128,
  flags = { "placeable-neutral", "player-creation" },
  minable = { mining_time = 0.4, result = ENTITY },
  max_health = 450,
  corpse = "small-remnants",
  dying_explosion = (data.raw.explosion and data.raw.explosion["medium-explosion"] and "medium-explosion") or "explosion",
  collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
  selection_box = { { -1.0, -1.0 }, { 1.0, 1.0 } },
  inventory_size = 1,
  -- Native fixed north container. Ambient ritual/CRT effects do not alter storage.
  picture = { layers = {
    { filename = "__tech-priests__/graphics/entity/conclave-center-v08/placement-base.png", priority = "high", width = WIDTH, height = HEIGHT,
      scale = SCALE, shift = { 0, -0.5586143571373725 } },
    { filename = "__tech-priests__/graphics/entity/conclave-center-v08/shadow.png", priority = "high", width = WIDTH, height = HEIGHT,
      scale = SCALE, shift = { 0, -0.5586143571373725 }, draw_as_shadow = true }
  } },
  stateless_visualisation = {
    count = 1,
    render_layer = "object",
    light = {
      { intensity = 0.11, size = 1.45, color = { 0.14, 0.9, 0.025 }, shift = { 0.000000, -0.460000 }, minimum_darkness = 0.20, flicker_interval = 6, flicker_min_modifier = 0.94, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.11, size = 1.45, color = { 0.14, 0.9, 0.025 }, shift = { -0.600000, -0.320000 }, minimum_darkness = 0.20, flicker_interval = 6, flicker_min_modifier = 0.94, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.11, size = 1.45, color = { 0.14, 0.9, 0.025 }, shift = { 0.600000, -0.320000 }, minimum_darkness = 0.20, flicker_interval = 6, flicker_min_modifier = 0.94, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { 0.621991, -1.546445 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { 0.529097, -1.672917 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { 0.384412, -1.773779 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { 0.202097, -1.863784 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { 0.000000, -1.876661 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { -0.202097, -1.843985 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { -0.384412, -1.793578 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { -0.529097, -1.672917 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
      { intensity = 0.035, size = 0.60, color = { 1.0, 0.29, 0.045 }, shift = { -0.621991, -1.526646 }, minimum_darkness = 0.20, flicker_interval = 5, flicker_min_modifier = 0.72, flicker_max_modifier = 1.0, offset_flicker = true },
    },
    animation = { layers = {
      { filename = "__tech-priests__/graphics/entity/conclave-center-v08/ambient-effects.png",
        priority = "high", width = WIDTH, height = HEIGHT,
        frame_count = 144, line_length = 12, animation_speed = 0.2,
        scale = SCALE, shift = { 0, -0.5586143571373725 } },
      { filename = "__tech-priests__/graphics/entity/conclave-center-v08/ambient-light.png",
        priority = "high", width = 256, height = 256,
        frame_count = 144, line_length = 12, animation_speed = 0.2,
        scale = 3.15 * 32 / 256, shift = { 0, -0.5586143571373725 },
        draw_as_light = true, blend_mode = "additive" }
    } }
  },
  open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.5 },
  close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.45 }
}

local item = {
  type = "item",
  name = ENTITY,
  icon = ICON,
  icon_size = 128,
  subgroup = "tech-priest-cogitators",
  order = "e[conclave-center]",
  place_result = ENTITY,
  stack_size = 10
}

local recipe = {
  type = "recipe",
  name = ENTITY,
  -- An early, handcraftable governance hub. All three ingredients are
  -- available from basic vanilla crafting without research or other stations.
  enabled = true,
  category = "crafting",
  energy_required = 5,
  ingredients = {
    { type = "item", name = "copper-cable", amount = 20 },
    { type = "item", name = "iron-gear-wheel", amount = 10 },
    { type = "item", name = "iron-plate", amount = 20 }
  },
  results = { { type = "item", name = ENTITY, amount = 1 } }
}

data:extend({ entity, item, recipe })
