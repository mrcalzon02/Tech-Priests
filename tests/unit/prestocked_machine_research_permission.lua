package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Constraints=require("scripts.core.planning_constraints_0646")
game={tick=100};defines={inventory={chest=1}}
local stock=18
prototypes={item={["electric-mining-drill"]={place_result={name="electric-mining-drill"}}}}
local recipe={enabled=false,products={{name="electric-mining-drill"}}}
local force={valid=true,index=3,recipes={drill=recipe}}
local pair={station={valid=true,force=force,get_inventory=function()
  return {valid=true,get_item_count=function()return stock end}
end}}
assert(not Constraints.item_unlocked(force,"electric-mining-drill"),"manufacture permission granted")
local allowed,why,item=Constraints.entity_unlocked(pair,"electric-mining-drill")
assert(allowed and why=="physical-construction-stock" and item=="electric-mining-drill")
assert(stock==18 and recipe.enabled==false,"permission check fabricated/debited stock or unlocked research")
stock=0
assert(not Constraints.entity_unlocked(pair,"electric-mining-drill"),"missing kit bypassed research")
TechPriestsStorageRoleAuthority0686={generic_item_count=function(p,name)
  assert(p==pair and name=="electric-mining-drill");return 18
end}
assert(Constraints.entity_unlocked(pair,"electric-mining-drill"),"canonical external stock was ignored")
TechPriestsStorageRoleAuthority0686.generic_item_count=function()return 0 end
assert(not Constraints.entity_unlocked(pair,"electric-mining-drill"),"empty external storage bypassed research")
TechPriestsStorageRoleAuthority0686=nil
game.tick=101;recipe.enabled=true
assert(Constraints.entity_unlocked(pair,"electric-mining-drill"),"researched manufacture became blocked")
assert(not Constraints.entity_unlocked(pair,"unplaceable-unknown-entity"))
print("PASS stocked machine construction without granting manufacture or research")
