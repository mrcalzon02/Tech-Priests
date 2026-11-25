-- Load the actual generated owners and canonical recipe index. The retired
-- force-wide timer must not compete with fixed-rank armor or repeat catalogues.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=1,forces={}}
settings={global={}}
defines={events={on_built_entity=1,on_robot_built_entity=2,
  script_raised_built=3,script_raised_revive=4,on_research_finished=5,
  on_technology_effects_reset=6,on_entity_damaged=7},inventory={chest=1}}
local events,ticks={},{}
script={on_event=function(id,handler)events[id]=handler end,
  get_event_handler=function(id)return events[id]end,
  on_nth_tick=function(id,handler)ticks[id]=handler end}
TechPriestsRuntimeEventRegistry=require("scripts.core.runtime_event_registry")
TechPriestsGuiRouter=require("scripts.gui.gui_router")
function ensure_storage()end
function tech_priests_0293_log()end
function log()end
local product_reads=0
local function recipe(name,item,enabled)
  return setmetatable({name=name,enabled=enabled,object_name="LuaRecipe"},
    {__index=function(_,key)
      if key=="products" then product_reads=product_reads+1;return {{name=item,type="item",amount=1}} end
    end})
end
local force={valid=true,index=1,name="player",recipes={}}
game.forces.player=force
for i=1,300 do force.recipes["unrelated-"..i]=recipe("unrelated-"..i,"ingredient-"..i,true)end
force.recipes["heavy-armor"]=recipe("heavy-armor","heavy-armor",false)
force.recipes["modded-heavy-armor"]=recipe("modded-heavy-armor","heavy-armor",false)
force.recipes["power-armor-mk2"]=recipe("power-armor-mk2","power-armor-mk2",true)
prototypes={item={}}
for _,name in ipairs({"light-armor","heavy-armor","modular-armor","power-armor","power-armor-mk2"})do
  prototypes.item[name]={name=name,type="armor",resistances={physical={decrease=5,percent=20}}}
end
local fragment_root=(arg and arg[1]) or "tech-priests_src/scripts/generated"
assert(loadfile(fragment_root.."/control_legacy_part_019.lua"))()
assert(loadfile(fragment_root.."/control_legacy_part_020.lua"))()
assert(not ticks[811],"superseded force-wide armor timer remains installed")
assert(ticks[887],"current fixed-rank armor service was removed")
assert(not tech_priests_0302_force_can_use_armor(force,"heavy-armor"),"locked armor was granted")
local initial_reads=product_reads
assert(initial_reads==303,"actual shared recipe membership was not populated once")
for _=1,100 do
  assert(not tech_priests_0302_force_can_use_armor(force,"heavy-armor"))
  assert(not tech_priests_0302_force_can_use_armor(force,"missing-armor"))
end
assert(product_reads==initial_reads,"warm armor checks walked recipe products again")
force.recipes["modded-heavy-armor"].enabled=true
assert(tech_priests_0302_force_can_use_armor(force,"heavy-armor"),"same-tick alias unlock was cached false")
force.recipes["modded-heavy-armor"].enabled=false
assert(not tech_priests_0302_force_can_use_armor(force,"heavy-armor"),"same-tick disable remained available")
assert(tech_priests_0302_force_can_use_armor(force,"mech-armor"),"missing-mech fallback changed")
assert(tech_priests_0297_force_can_use_armor(force,"light-armor"),"historical light-armor floor changed")
local priest={valid=true,name="junior-tech-priest",force=force,health=80,prototype={max_health=250}}
local pair={priest=priest,station={valid=true,force=force}}
storage.tech_priests.pairs_by_station[1]=pair
find_pair_for_entity=function(entity)if entity==priest then return pair end end
tech_priests_0297_find_best_force_armor_profile=function()error("retired force-wide owner was invoked")end
assert(tech_priests_0297_apply_profile_to_pair(pair,"build-chain")==nil,
  "higher-force armor bypassed the junior's fixed-rank gate")
assert(pair.fixed_armor_profile_0302.gated and not pair.sub_equipment_armor_profile_0297)
force.recipes["modded-heavy-armor"].enabled=true
local profile=tech_priests_0297_apply_profile_to_pair(pair,"build-chain")
assert(profile and profile.name=="heavy-armor" and pair.fixed_armor_profile_0302==profile,
  "compatibility build chain did not delegate to the existing fixed-rank owner")
tech_priests_0302_mitigate_damage({entity=priest,damage_type={name="physical"},final_damage_amount=100})
assert(priest.health==104 and pair.last_armor_mitigation_0302.fixed_rank,
  "fixed-rank damage mitigation changed")
ticks[887]({tick=887})
assert(pair.fixed_armor_profile_0302.name=="heavy-armor" and product_reads==initial_reads,
  "periodic fixed-rank maintenance repeated recipe discovery or changed rank")
print("[fixed-rank-armor-existing-authority] PASS retired811 live-alias-unlocks shared0646 recipe-index legacy-delegation fixed-rank-damage periodic887")
