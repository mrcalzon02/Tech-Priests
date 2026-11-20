-- 1499: Idle inventory scanning must not target player/character inventories.
-- Pure source mocks, not native Factorio item/character acceptance.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.inventory_target_safety")
local player_character={valid=true,name="character",type="character"}
local modded_character={valid=true,name="modded-adept",type="unit",player={valid=true}}
local furnace={valid=true,name="stone-furnace",type="furnace"}
local direct_machine={valid=true,name="assembling-machine-1",type="assembling-machine"}
local hostile_property=setmetatable({valid=true,name="safe-machine",type="furnace"},{
  __index=function(_,key)
    if key=="entity" then error("LuaEntity field unsupported") end
    return nil
  end,
})
local requested={
  {entity=player_character,weight=1},
  {entity=furnace,weight=2},
  player_character,
  direct_machine,
  {entity=modded_character,weight=3},
  hostile_property,
}
local backend_failed=false
local filter_calls=0
_G.is_logistic_scan_candidate_entity=function(pair,entity)
  filter_calls=filter_calls+1
  return entity.valid
end
_G.get_idle_scan_candidates=function()
  if backend_failed then error("backend failed") end
  return requested
end
assert(M.install()==nil)
assert(is_logistic_scan_candidate_entity({},player_character)==false,
  "player inventory leaked to logistics scan")
assert(is_logistic_scan_candidate_entity({},modded_character)==false,
  "modded player inventory leaked to logistics scan")
assert(is_logistic_scan_candidate_entity({},furnace)==true and filter_calls==1,
  "ordinary machine source was blocked")
local result=get_idle_scan_candidates({})
assert(#result==3,"direct or wrapped player target passed idle scan")
assert(result[1].entity==furnace and result[2]==direct_machine
  and result[3]==hostile_property,
  "valid candidate ordering/payloads were changed")
backend_failed=true
assert(#get_idle_scan_candidates({})==0,"failed provider must return empty candidates")

-- No historical providers: preserve safe normal-machine fallback.
package.loaded["scripts.core.inventory_target_safety"]=nil
_G.is_logistic_scan_candidate_entity=nil
_G.get_idle_scan_candidates=nil
local Standalone=require("scripts.core.inventory_target_safety")
Standalone.install()
assert(is_logistic_scan_candidate_entity({},player_character)==false)
assert(is_logistic_scan_candidate_entity({},furnace)==true)
print("[inventory-target-safety-1499] PASS: player protection and legacy provider shapes")
