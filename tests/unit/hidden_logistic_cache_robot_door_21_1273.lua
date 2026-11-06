-- 1273: Native 2.1 robot-door field relocation; protect 2.0 runtime too.
table.deepcopy = table.deepcopy or function(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do
    result[key] = table.deepcopy(child)
  end
  return result
end
local configure = dofile("tech-priests_src/prototypes/compatibility/native_robot_door_1273.lua")
local blank = {filename="__core__/graphics/empty.png", width=1, height=1, frame_count=1}
for _, version in ipairs({"2.1.0", "2.1.24", "2.2.0"}) do
  local original = { animation={filename="old.png"}, landing_location_offset={3, 4},
    opened_duration=14, animation_sound={filename="old.ogg"},
    robot_door={animation={filename="visible.png"}}}
  local updated = configure(original, blank, version)
  assert(updated == original and updated.animation == nil
    and updated.landing_location_offset == nil
    and updated.opened_duration == nil and updated.animation_sound == nil,
    "2.1 removed root fields still remain")
  assert(type(updated.robot_door) == "table"
    and updated.robot_door.animation.filename == blank.filename
    and updated.robot_door.animation ~= blank
    and updated.robot_door.opened_duration == 0
    and updated.robot_door.landing_location_offset[1] == 0,
    "2.1 hidden logistic cache does not use native robot_door")
end
for _, version in ipairs({"2.0.0", "2.0.77"}) do
  local updated = configure({robot_door={animation={filename="from_2.1.png"}}},
    blank, version)
  assert(updated.robot_door == nil and updated.animation == nil
    and updated.landing_location_offset[1] == 0
    and updated.opened_duration == 0, "2.0 classic fields regressed")
end
assert(not pcall(configure, {}, blank, "unknown"),
  "unknown Factorio engine version should fail closed")
print("[robot-door-2.1-1273] PASS nested native 2.1 schema and unchanged 2.0 behavior")
