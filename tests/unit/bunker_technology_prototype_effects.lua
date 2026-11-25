-- LuaTechnology in Factorio 2.1 keeps effects on LuaTechnologyPrototype.
-- Reproduce its strict member access so reloads of researched saves stay safe.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
package.loaded["scripts.bullet_turret_controller"] = {
  init = function() end,
  add = function() return false end,
}
local function technology(researched, effects)
  local members = {researched = researched, prototype = {effects = effects}}
  return setmetatable({}, {__index = function(_, key)
    assert(key == "researched" or key == "prototype", "LuaTechnology has no member " .. tostring(key))
    return members[key]
  end})
end
local recipes = {restored = {enabled = false}, locked = {enabled = false}, unrelated = {enabled = false}}
storage = {}
game = {surfaces = {}, forces = {player = {
  recipes = recipes,
  technologies = {
    ["tech-priests-bunker-autocannon"] = technology(true, {
      {type = "unlock-recipe", recipe = "restored"},
      {type = "unlock-recipe", recipe = "removed-recipe"},
      {type = "nothing", recipe = "unrelated"},
    }),
    ["tech-priests-bunker-lobber"] = technology(false, {{type = "unlock-recipe", recipe = "locked"}}),
  },
}}}
local family = require("scripts.bunker_family_visuals")
for _ = 1, 2 do
  family.init()
  assert(recipes.restored.enabled, "Researched bunker recipe was not restored")
  assert(not recipes.locked.enabled, "Unresearched bunker recipe was granted")
  assert(not recipes.unrelated.enabled, "A non-unlock effect enabled an unrelated recipe")
end
print("[bunker-technology-prototype-effects] PASS researched-save reload and idempotent unlock semantics")
