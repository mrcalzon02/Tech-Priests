-- Exact owner-supplied V07: 288 source frames at 24fps -> 144 frames at 12fps.
-- Hatches, articulated arm, capsule, arcs, heat, vapor and moving ground shadow
-- are rendered together from the original packed scene in all four directions.
local root = "__tech-priests__/graphics/entity/emergency-assembler-v07/"
local function direction(name, idle)
  return {
    filename = root .. (idle and "idle-" or "working-") .. name .. ".png",
    priority = "high", width = 256, height = 256,
    frame_count = idle and 1 or 144,
    repeat_count = idle and 144 or 1,
    line_length = idle and 1 or 12,
    animation_speed = 0.2, scale = 0.1875,
    shift = {0, -0.2121320343559643}
  }
end
local function four_way(idle)
  local result = {}
  for _, name in ipairs({"north", "east", "south", "west"}) do
    result[name] = direction(name, idle)
  end
  return result
end
local entity = assert(data.raw["assembling-machine"]["tech-priests-emergency-assembler"], "V07 requires the emergency assembler")
entity.graphics_set = {
  animation = four_way(false), idle_animation = four_way(true),
  always_draw_idle_animation = false,
  animation_progress = 1
}
entity.graphics_set_flipped = nil
entity.match_animation_speed_to_activity = false
entity.animation_random_start_frame = false
entity.perceived_performance = {minimum = 1, maximum = 1}
-- Native burner crafting machines need a non-square collision box to accept
-- directional placement. Keep the existing one-tile selection/grid and add
-- only .01 tile depth per side, following this model's deeper foundation.
-- The engine supports choosing these facings before placement, not in-place R.
entity.collision_box = {{-0.35, -0.36}, {0.35, 0.36}}
entity.icon, entity.icons, entity.icon_size = root .. "icon.png", nil, 128
entity.water_reflection = nil
if entity.energy_source then entity.energy_source.smoke = nil end
for _, kind in ipairs({"item", "recipe"}) do
  local prototype = (data.raw[kind] or {})["tech-priests-emergency-assembler"]
  if prototype then
    prototype.icon, prototype.icons, prototype.icon_size = root .. "icon.png", nil, 128
  end
end
