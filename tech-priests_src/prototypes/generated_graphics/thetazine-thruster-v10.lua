-- V10: validated V09 mechanism plus the exact 88 fixed cradle components.
-- Native capture source SHA256: 783a9d8c1faa0dd88cdb3e105281ae33fedb1a6ef589fe08021282fc66b4fbdb
-- Body/heat and projected shadows are independently captured on one 64-frame clock.
local p = data.raw.thruster and data.raw.thruster["thetazine-thruster"]
local donor = data.raw.thruster and data.raw.thruster.thruster
if not (p and donor and p.graphics_set and donor.graphics_set) then return end

local base = "__tech-priests__/graphics/entity/thetazine-thruster-v10/"
local shift = {-3.725290298461914e-08, 2.8901551961898804}
local function animation(kind)
  return {filenames={base..kind.."-1.png", base..kind.."-2.png"},
    width=512, height=1280, line_length=8, lines_per_file=4,
    frame_count=64, animation_speed=0.5, scale=0.46875, shift=shift}
end
local shadow_shift = {0.029296837747097015, -1.1381651163101196}
local working_shadow = {filenames={base.."shadow-1.png", base.."shadow-2.png"},
  width=470, height=282, line_length=8, lines_per_file=4,
  frame_count=64, animation_speed=0.5, scale=0.46875, shift=shadow_shift,
  draw_as_shadow=true}
local cold_body = {filename=base.."idle-body.png", width=512, height=1280,
  frame_count=1, repeat_count=64, scale=0.46875, shift=shift}
local cold_shadow = {filename=base.."idle-shadow.png", width=470, height=282,
  frame_count=1, repeat_count=64, scale=0.46875, shift=shadow_shift,
  draw_as_shadow=true}
local g = p.graphics_set
g.animation = {north={layers={animation("body"), working_shadow}}}
g.idle_animation = {north={layers={cold_body, cold_shadow}}}
g.always_draw_idle_animation = false
g.animation_random_start_frame = false

local kept = {}
for _, visual in ipairs(g.working_visualisations or {}) do
  if visual.name == "platform-service-underlay" then
    visual.animation = {filename=base.."underlay.png", width=512, height=1280,
      scale=0.46875, shift=shift}
    kept[#kept+1] = visual
  elseif visual.enabled_by_name then
    -- Preserve the two original native connection-gated cap tables exactly.
    kept[#kept+1] = visual
  end
end
local heat = animation("heat-glow")
heat.draw_as_glow = true
heat.blend_mode = "additive"
kept[#kept+1] = {name="v10-separate-heat-glow", fadeout=true,
  animation={layers={heat}}}
g.working_visualisations = kept

-- Installed native mixture/thrust shader and plumes, without copied Wube art.
for _, key in ipairs({"flame_effect", "flame_half_height", "flame_effect_width",
    "flame_effect_height", "flame_effect_offset"}) do
  g[key] = table.deepcopy(donor.graphics_set[key])
end
-- Captured moving-mouth mean Y=5.612955244840123; installed donor lip offset
-- is 0.34375 tile. Native extreme-phase overlap is checked separately.
g.flame_position = {0.00000407686457, 5.269205244840123}
p.plumes = table.deepcopy(donor.plumes)
p.drawing_box = {{-4,-5},{4,42}}

local icon = "__tech-priests__/graphics/icons/thetazine-thruster-v10.png"
for _, prototype in ipairs({p, data.raw.item["thetazine-thruster"],
    data.raw.recipe["thetazine-thruster"]}) do
  prototype.icon = icon
  prototype.icons = nil
  prototype.icon_size = 64
end
