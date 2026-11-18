-- The runner extracts these exact blocks from the current production sources.
-- The machine's real burner, speed, categories, boxes and item/recipe survive.
require("prototypes.assembler-source")
require("prototypes.generated_graphics.emergency-assembler-v07")
require("prototypes.compatibility.native_recipe_schema_1274")(
  data.raw.recipe, mods["base"])

local name = "tech-priests-emergency-assembler"
local machine = assert(data.raw["assembling-machine"][name])
assert(machine.energy_source.type == "burner", "Production burner was replaced")
assert(machine.crafting_speed == .17, "Production crafting speed was replaced")
assert(machine.match_animation_speed_to_activity == false,
  "V07 twelve-second clock must run independently of recipe speed")
assert(machine.graphics_set.animation_progress == 1,
  "Native graphics progression must not halve the twelve-second cycle")
assert(machine.animation_random_start_frame == false,
  "The source cycle must start at its first frame")
assert(machine.perceived_performance.minimum == 1
  and machine.perceived_performance.maximum == 1,
  "Perceived performance must not accelerate or slow the source animation")
local categories = {}
for _, category in ipairs(machine.crafting_categories) do categories[category] = true end
assert(categories.crafting and categories["advanced-crafting"] and not categories.smelting,
  "Native assembler crafting identities changed")
if data.raw["recipe-category"].electronics then
  assert(categories.electronics, "Registered electronics capability was lost")
end
local function leaves(node, into)
  into = into or {}
  if type(node) ~= "table" then return into end
  if node.filename then into[#into + 1] = node end
  for _, value in pairs(node) do
    if type(value) == "table" then leaves(value, into) end
  end
  return into
end
for _, direction in ipairs({"north", "east", "south", "west"}) do
  local working = leaves(assert(machine.graphics_set.animation[direction]))
  local idle = leaves(assert(machine.graphics_set.idle_animation[direction]))
  assert(#working > 0 and #idle > 0, "Missing native directional states")
  for _, layer in ipairs(working) do
    assert(layer.filename:find("/emergency-assembler-v07/", 1, true), "Wrong assembler art")
    assert(layer.frame_count == 144 and layer.animation_speed == .2,
      "V07 needs 144 frames at .2 per tick: twelve native seconds")
  end
  for _, layer in ipairs(idle) do
    assert(layer.filename:find("/emergency-assembler-v07/", 1, true), "Wrong idle art")
    assert((layer.frame_count or 1) == 1, "Idle must display the closed machine")
    assert(layer.repeat_count == 144, "Native idle state must repeat across all 144 working frames")
  end
end
for _, kind in ipairs({"item", "recipe"}) do
  assert(data.raw[kind][name].icon:find("/emergency-assembler-v07/", 1, true),
    "Generated V07 icon missing from " .. kind)
end
log("[EMERGENCY ASSEMBLER V07 DATA] PASS real builder, four directions, twelve-second cycle and icons")
