-- The production constraints/metadata path, including a long disabled recipe
-- membership list, must not collapse back into one synchronous caller scan.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1};storage={tech_priests={pairs_by_station={}}}
defines={direction={north=0}}
local Queue=require("scripts.core.force_planning_queue")
local Metadata=require("scripts.core.planning_metadata_1507")
local Constraints=require("scripts.core.planning_constraints_0646")
_G.TechPriestsPlanningConstraints0646=Constraints
local Site=require("scripts.core.construction_site_planner")
local Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
prototypes={entity={["iron-chest"]={type="container",collision_box={{-.35,-.35},{.35,.35}}}},item={}}
for i=1,100 do prototypes.item["unrelated-"..i]={}end
prototypes.item["iron-chest"]={place_result={name="iron-chest"}}
local enabled_reads,queries,created=0,0,0
local force={valid=true,index=1,name="player",recipes={},technologies={}}
local enabled={}
for i=1,120 do
 local name="chest-recipe-"..i
 force.recipes[name]=setmetatable({object_name="LuaRecipe",products={{name="iron-chest"}}},
  {__index=function(_,key)if key=="enabled"then enabled_reads=enabled_reads+1;return enabled[name]==true end end})
end
local surface={index=1,can_place_entity=function()queries=queries+1;return true end,
 find_entities_filtered=function()queries=queries+1;return {}end}
surface.create_entity=function(args)
 created=created+1
 return {valid=true,unit_number=1000+created,name="entity-ghost",ghost_name=args.inner_name,
   position=args.position,force=force,surface=surface}
end
_G.TechPriestsScanRouting0610={find_entities=function()return {}end}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2},radius=8,self_construction_frustration_unlocked_1504=true}
storage.tech_priests.pairs_by_station[1]=pair
local did,why=Ghost.service_pair(pair,"cold-metadata","iron-chest")
assert(not did and why=="placement-pending-metadata" and enabled_reads==0 and queries==0,
 "cold ghost caller scanned recipe/prototype metadata")
for i=1,2000 do
 game.tick=game.tick+1
 Queue.pulse({tick=game.tick},16)
 if Metadata.ready(force) then break end
end
assert(Metadata.ready(force),"bounded immutable metadata did not complete")
local names=Metadata.recipe_names(force,"iron-chest")
enabled[names[#names]]=true
local start=enabled_reads
local pos,reason=Site.plan_site(pair,{entity_name="iron-chest",category="storage"})
assert(not pos and Site.is_pending(reason) and enabled_reads==start,
 "ready metadata caller scanned enabled state synchronously")
for i=1,2000 do
 game.tick=game.tick+1
 local before=enabled_reads
 Queue.pulse({tick=game.tick},1)
 assert(enabled_reads-before<=2,"one planner operation inspected a complete recipe membership list")
 pos,reason=Site.plan_site(pair,{entity_name="iron-chest",category="storage"})
 if pos then break end
end
assert(pos and enabled_reads-start>=#names,"disabled candidate recipes escaped charged accounting")
-- Availability changes after the private scan must revoke the saved witness.
enabled[names[#names]]=false
local before=enabled_reads
local ghosted,pending=Ghost.service_pair(pair,"revoked-before-ghost","iron-chest")
assert(not ghosted and Site.is_pending(pending) and created==0
 and enabled_reads-before==1,"final action used a stale enabled recipe or rescanned all recipes")
-- A new enabled recipe can resume the same job; no failure cooldown was saved.
enabled[names[1]]=true
for i=1,2000 do
 game.tick=game.tick+1;Queue.pulse({tick=game.tick},16)
 if Ghost.service_pair(pair,"new-enabled-witness","iron-chest") then break end
end
assert(created==1 and pair.construction_bootstrap_ghost_0645,
 "recipe witness change prevented legitimate queued ghost creation")
print("[placement-metadata-witness-1507] PASS production constraints, cold metadata, one enabled-recipe candidate per step, live revoked witness and legitimate resumption")
