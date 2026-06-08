-- prototypes/portrait_cells_0520.lua
-- Tech Priests 0.1.560
-- Data-stage portrait-cell registration for Cogitator Work State identity panes.
-- 0.1.560 replaced the old crop-from-sheet math with generated normalized
-- per-cell files because the trimmed portrait sheets no longer share the old
-- uniform margins/stride assumptions.  The runtime sprite names are preserved
-- so existing pair portrait IDs remain stable where their cell index still
-- exists.

local out = {}

local function add_cell_files(prefix, base_path, count)
  for n = 1, count do
    local name = prefix .. string.format("-%03d", n)
    out[#out + 1] = {
      type = "sprite",
      name = name,
      filename = "__tech-priests__/" .. base_path .. "/" .. name .. ".png",
      width = 128,
      height = 128,
      flags = { "icon" },
    }
  end
end

-- These cells are generated from the trimmed portrait sheets during the 0.1.560
-- asset pass and normalized to 128x128 files under graphics/gui/portraits/cells_0560.
add_cell_files("tech-priests-portrait-cell-augmented-a", "graphics/gui/portraits/cells_0560", 64)
add_cell_files("tech-priests-portrait-cell-baseline-human", "graphics/gui/portraits/cells_0560", 64)
add_cell_files("tech-priests-portrait-cell-alternative-human-augmented-c", "graphics/gui/portraits/cells_0560", 315)

-- The trimmed Planetary Magos sheet is no longer the old 9x8 layout; its bottom
-- row is gone in the new asset.  Register only the 9x7 valid cells so the GUI
-- never references the missing/distorted final row.
add_cell_files("tech-priests-portrait-cell-planetary-magos-a", "graphics/gui/portraits/cells_0560", 63)

data:extend(out)
