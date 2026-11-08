-- Approved timber workbench, fixed one-tile registration and eight-second cycle.
local root = "__tech-priests__/graphics/entity/timber-workbench/"
local function direction(name, idle)
  return {
    filename = root .. (idle and "idle-" or "working-") .. name .. ".png",
    priority = "high", width = 128, height = 128,
    frame_count = idle and 1 or 96,
    repeat_count = idle and 96 or 1,
    line_length = idle and 1 or 12,
    animation_speed = 0.2, scale = 0.5,
    shift = {0, -0.44547727214752}
  }
end
local function four_way(idle)
  local result = {}
  for _, name in ipairs({"north", "east", "south", "west"}) do
    result[name] = direction(name, idle)
  end
  return result
end
local entity = data.raw["assembling-machine"]["tech-priests-emergency-assembler"]
if entity then
  entity.graphics_set = {
    animation = four_way(false), idle_animation = four_way(true),
    always_draw_idle_animation = false
  }
  entity.graphics_set_flipped = nil
  entity.match_animation_speed_to_activity = false
  entity.icon = root .. "icon.png"
  entity.icon_size = 64
  entity.icons = nil
  entity.water_reflection = nil
  if entity.energy_source then entity.energy_source.smoke = nil end
end
for _, kind in ipairs({"item", "recipe"}) do
  local prototype = data.raw[kind] and data.raw[kind]["tech-priests-emergency-assembler"]
  if prototype then
    prototype.icon = root .. "icon.png"
    prototype.icon_size = 64
    prototype.icons = nil
  end
end
