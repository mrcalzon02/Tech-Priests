-- Tech Priests - data stage entry point.
-- This file is loaded during the prototype definition phase.

require("prototypes.categories.recipe-category")
require("prototypes.categories.item-group")
require("prototypes.item")
require("prototypes.recipe")
require("prototypes.technology")
-- 0.1.313: equipment-grid experiment abandoned; priests use station inventory plus research-unlocked bonuses.
-- equipment grid prototypes intentionally disabled as of 0.1.313/0.1.314
require("prototypes.sound")
require("prototypes.gui_sprites")
require("prototypes.portrait_cells_0520")
require("prototypes.entity")
require("prototypes.martian_stone_cache")
require("prototypes.conclave_center_0558")

if mods["space-age"] then
  require("prototypes.compatibility.space-age")
end

if mods["quality"] then
  require("prototypes.compatibility.quality")
end

-- Runtime-rendered sanctification overlays.  The original generic grime/sheen
-- sprites remain as fallbacks, while 0.1.276 adds procedurally generated
-- per-machine overlays so assemblers, refineries, boilers, reactors, turbines,
-- roboports, and Space Age machines do not all wear the same stain pattern.
local tech_priests_sanctification_overlay_sprites = {
  {
    type = "sprite",
    name = "tech-priests-sanctification-grime-overlay",
    filename = "__tech-priests__/graphics/effect/sanctification-grime-overlay.png",
    width = 128,
    height = 128,
    flags = { "icon" }
  },
  {
    type = "sprite",
    name = "tech-priests-sanctification-sheen-overlay",
    filename = "__tech-priests__/graphics/effect/sanctification-sheen-overlay.png",
    width = 128,
    height = 128,
    flags = { "icon" }
  },
  {
    type = "sprite",
    name = "tech-priests-sanctification-vehicle-slime-overlay",
    filename = "__tech-priests__/graphics/effect/sanctification-vehicle-slime-overlay.png",
    width = 128,
    height = 128,
    flags = { "icon" }
  },
  {
    type = "sprite",
    name = "tech-priests-sanctification-vehicle-glow-overlay",
    filename = "__tech-priests__/graphics/effect/sanctification-vehicle-glow-overlay.png",
    width = 128,
    height = 128,
    flags = { "icon" }
  }
}

local tech_priests_machine_specific_sanctification_overlays = {
  "assembling-machine-1",
  "assembling-machine-2",
  "assembling-machine-3",
  "oil-refinery",
  "chemical-plant",
  "centrifuge",
  "electromagnetic-plant",
  "cryogenic-plant",
  "boiler",
  "steam-engine",
  "nuclear-reactor",
  "steam-turbine",
  "roboport",
}

for _, tech_priests_overlay_machine in pairs(tech_priests_machine_specific_sanctification_overlays) do
  tech_priests_sanctification_overlay_sprites[#tech_priests_sanctification_overlay_sprites + 1] = {
    type = "sprite",
    name = "tech-priests-sanctification-grime-" .. tech_priests_overlay_machine,
    filename = "__tech-priests__/graphics/effect/sanctification-grime-" .. tech_priests_overlay_machine .. ".png",
    width = 128,
    height = 128,
    flags = { "icon" }
  }
  tech_priests_sanctification_overlay_sprites[#tech_priests_sanctification_overlay_sprites + 1] = {
    type = "sprite",
    name = "tech-priests-sanctification-sheen-" .. tech_priests_overlay_machine,
    filename = "__tech-priests__/graphics/effect/sanctification-sheen-" .. tech_priests_overlay_machine .. ".png",
    width = 128,
    height = 128,
    flags = { "icon" }
  }
end

data:extend(tech_priests_sanctification_overlay_sprites)

-- 0.1.280 Runtime-rendered Cogitator Radar overlay.
-- This sprite is drawn in world-space by control.lua and scaled to each
-- station's current operating radius at runtime.
data:extend({
  {
    type = "sprite",
    name = "tech-priests-radar-overlay",
    filename = "__tech-priests__/graphics/effect/radar-splash.png",
    width = 1024,
    height = 1024,
    flags = { "icon" }
  }
})


-- 0.1.193 Tech-Priest Command Overview hotkey. Factorio custom-input consuming accepts game-only/none, not script-only.

-- 0.1.332 Runtime-rendered Cogitator Radar sweeper afterglow wedge.
-- Drawn by scripts/core/radar_afterglow.lua as a rotating, translucent sweep
-- sprite so the radar does not need to spam many phosphor line segments.
data:extend({
  {
    type = "sprite",
    name = "tech-priests-radar-sweeper-afterglow",
    filename = "__tech-priests__/graphics/effect/RADARSweeper.png",
    width = 256,
    height = 512,
    flags = { "icon" }
  }
})

data:extend({
  {
    type = "custom-input",
    name = "tech-priests-toggle-command-overview",
    key_sequence = "SHIFT + Y",
    consuming = "game-only",
    order = "z[tech-priests]-[command-overview]"
  }
})
