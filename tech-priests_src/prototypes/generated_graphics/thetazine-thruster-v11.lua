-- Exhaust-only correction for the owner-accepted V09 mechanical assembly.
-- V10 supplies its unchanged body, shadow, installation, caps and icon.
require("prototypes.generated_graphics.thetazine-thruster-v10")

local p = data.raw.thruster and data.raw.thruster["thetazine-thruster"]
if not (p and p.graphics_set) then return end
local g = p.graphics_set

-- The native shader draws additive RGB from the beginning of its quad.
-- Its forward extent is flame_position.y - flame_effect_offset. The former
-- aperture-centre anchor therefore painted native fire over the bell exterior.
-- All 64 physical near-lips end before native Y=6.245. Keep the trail quad
-- at Y=6.3875, aft of that complete motion envelope, including a clear margin.
g.flame_position = {0.00000407686457, 7.95}

-- Restore the complete original Blender thrust cone from the approved 360.
-- No mouth clipping, short bridge, attenuation or new density LUT is applied.
-- Original physical black occluders protect the bell's exterior.
-- Working cells retain the same 64-frame clock and additive RGB convention.
local base = "__tech-priests__/graphics/entity/thetazine-thruster-v11/"
for _, visual in ipairs(g.working_visualisations or {}) do
  if visual.name == "v10-separate-heat-glow" then
    visual.name = "v11-full-source-cone-heat"
    local heat = visual.animation.layers[1]
    heat.filenames = {base.."heat-glow-1.png", base.."heat-glow-2.png"}
  end
end
