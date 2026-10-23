-- CI combat setup: the industry benchmark must not receive free research.
local M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(type(M.test_combat_preset_defense_research)=="function",
  "late combat technology preset unavailable")
local old=rawget(_G,"TP_CI_LATE_COMBAT")
local oldlog=log
local trace={}
log=function(msg)trace[#trace+1]=msg end
local make_tech=function(researched,recipe)
  local state={researched=researched}
  return setmetatable({},{
    __index=function(_,key)return state[key]end,
    __newindex=function(_,key,value)
      if key=="researched" then
        state.researched=value
        if value then recipe.enabled=true end
      else state[key]=value end
    end,
  })
end
local recipes={
  ["gun-turret"]={enabled=false},
  ["stone-wall"]={enabled=false},
  ["automation"]={enabled=false},
}
local technologies={
  ["gun-turret"]=make_tech(false,recipes["gun-turret"]),
  ["stone-wall"]=make_tech(false,recipes["stone-wall"]),
  ["automation"]=make_tech(false,recipes["automation"]),
}
local force={technologies=technologies,recipes=recipes}
local no,why=pcall(M.test_combat_preset_defense_research,force)
assert(not no and tostring(why):find("COMBAT_TECH_PRESET_OUTSIDE_LATE_FIXTURE",1,true),
  "combat research leaked outside intentional late fixture")
_G.TP_CI_LATE_COMBAT=true
-- The flag is sampled at module load; reload the actual harness with it set.
M=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(M.test_combat_preset_defense_research(force),
  "presets could not be applied")
assert(technologies["gun-turret"].researched
  and technologies["stone-wall"].researched
  and recipes["gun-turret"].enabled and recipes["stone-wall"].enabled,
  "engine technology effects did not unlock both defense recipes")
assert(not technologies.automation.researched
  and not recipes.automation.enabled,
  "unrelated research was granted during combat fixture")
assert(#trace==1 and trace[1]:find("after_industry_acceptance=true",1,true),
  "combat fixture provenance was not logged")
assert(M.test_combat_preset_defense_research(force),
  "idempotent combat fixture rejected existing technology research")
assert(#trace==2 and trace[2]:find("newly_preset=",1,true),
  "second combat fixture pass lost readback")
local oldWall=technologies["stone-wall"]
technologies["stone-wall"]=nil
local ok,err=pcall(M.test_combat_preset_defense_research,force)
assert(not ok and tostring(err):find("COMBAT_TECH_PRESET_MISSING_PROTOTYPE: stone-wall",1,true),
  "missing essential vanilla technology did not block combat fixture")
technologies["stone-wall"]=oldWall
_G.TP_CI_LATE_COMBAT=old
log=oldlog
print("[combat-technology-preset] PASS scoped turret/wall research with genuine engine recipe effects")
