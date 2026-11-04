-- 1181: Conclave research must use the live personal doctrine profile,
-- not silently substitute the station rank. No parallel faction state.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local callbacks, nth={},{}
_G.storage={tech_priests={pairs_by_station={}}}
_G.settings={global={
 ["tech-priests-enable-doctrine-rebellions"]={value=true},
 ["tech-priests-dont-touch-my-toys"]={value=true},
}}
local surface={index=1,name="nauvis",map_gen_settings={seed=1181}}
local hostility=0
local function new_force(name)
 local f={valid=true,name=name,technologies={},recipes={}}
 f.print=function()end
 f.set_cease_fire=function() hostility=hostility+1 end
 f.set_friend=function() hostility=hostility+1 end
 return f
end
local player_force=new_force("player")
_G.game={tick=1,forces={player=player_force},surfaces={[1]=surface},
 create_force=function(name)
  assert(game.forces[name]==nil, "duplicate rogue force")
  local f=new_force(name)
  game.forces[name]=f
  return f
 end}
_G.defines={events={
 on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
 script_raised_revive=4,on_entity_died=5,on_pre_player_mined_item=6,
 on_robot_pre_mined=7,script_raised_destroy=8,on_gui_opened=9,
 on_research_finished=10,on_script_trigger_effect=11}}
_G.script={}
_G.TechPriestsRuntimeEventRegistry={
 on_event=function(events,fn)
  if type(events)=="table" then
   for _,id in ipairs(events) do callbacks[id]=fn end
  else callbacks[events]=fn end
 end,
 on_nth_tick=function(period,fn) nth[period]=fn end,
}
local profiles={}
package.loaded["scripts.core.doctrine_chatter"]={
 profile_for_pair=function(pair) return profiles[pair.station.unit_number] end
}
local module=require("scripts.core.conclave_center_0558")
module.install()
assert(type(callbacks[defines.events.on_research_finished])=="function"
 and type(callbacks[defines.events.on_built_entity])=="function"
 and type(nth[607])=="function","Conclave research events were not registered")
local center={valid=true,name="tech-priests-conclave-center",
 unit_number=90,force=player_force,surface=surface,position={x=0,y=0}}
callbacks[defines.events.on_built_entity]({entity=center})
local root=storage.tech_priests.conclave_center_0558
local state=root.force_state.player
assert(state and state.loyalty.science==100
 and state.loyalty.industry==100,"real Conclave center did not initialize politics")
local function pair(id,camp,explicit)
 local station={valid=true,name="senior-cogitator-station",
  unit_number=id,position={x=id,y=0},surface=surface,force=player_force}
 local priest={valid=true,unit_number=id+2000,force=player_force}
 local p={station=station,priest=priest}
 if explicit then p.doctrine_family=explicit end
 storage.tech_priests.pairs_by_station[id]=p
 profiles[id]={doctrine_camp=camp,current_doctrine_camp_0370=camp}
 return p
end
-- Twenty actual profile-aligned Sushi Belt mystics are a SCIENCE
-- constituency, despite ALL having Senior (formerly industry) stations.
for i=1,20 do pair(100+i,"sushi") end
local heretic=pair(500,"mixed_spaghetti")
state.next_conclave_tick=0
game.tick=607
nth[607]()
assert(state.phase=="voting" and state.votes.science==20
 and state.votes.industry==1,
 "Conclave ignored shared personal doctrine and voted by station rank")
-- No science-family research must NEVER silently select military research.
local military={name="military-1",valid=true,enabled=true,
 researched=false,research_unit_count=10,prerequisites={}}
player_force.technologies[military.name]=military
game.tick=game.tick+300*60
nth[607]()
assert(state.phase=="waiting" and player_force.current_research==nil,
 "winning science doctrine stole another faction's technology")
-- Select a genuinely matching science technology; an unreached
-- prerequisite must not become a shortcut Conclave research.
local classify=_G.tech_priests_conclave_0588_family_for_technology
local candidate=nil
for i=1,200 do
 local name="science-lab-research-"..i
 local tech={name=name,valid=true,enabled=true,
  researched=false,research_unit_count=10,prerequisites={}}
 if classify(player_force,tech)=="science" then candidate=tech;break end
end
assert(candidate,"no science-family research candidate for seed")
local locked={name="science-lab-locked",valid=true,enabled=true,
 researched=false,research_unit_count=1,
 prerequisites={{name="prerequisite-not-researched",researched=false}}}
if classify(player_force,locked)=="science" then
 player_force.technologies[locked.name]=locked
end
player_force.technologies[candidate.name]=candidate
state.phase="voting";state.vote_ends_tick=game.tick
state.votes={science=25,industry=1}
nth[607]()
assert(player_force.current_research==candidate.name,
 "Conclave ignored research family or bypassed prerequisite")
-- An actual completed science research (never a fake grant) can exert
-- gradual pressure on a disliked industry family until a REAL schism.
player_force.current_research=nil
state.loyalty.industry=1
local saw_pressure=false
for i=1,3000 do
 game.tick=game.tick+1
 local tech={name="science-lab-completed-"..i,
  force=player_force,prototype={name="science-lab-completed-"..i}}
 if classify(player_force,tech)=="science" then
  callbacks[defines.events.on_research_finished]({research=tech})
  if (state.loyalty.industry or 100)<1 or heretic.station.force~=player_force then
   saw_pressure=true;break
  end
 end
end
local rogue=game.forces["tech-priests-rogue-industry"]
assert(saw_pressure and rogue and rogue.valid,
 "completed hostile research did not trigger a Conclave-owned schism")
assert(heretic.station.force==rogue and heretic.priest.force==rogue
 and heretic.rogue_doctrine_0588==true
 and heretic.rogue_family_0588=="industry"
 and state.loyalty.industry==100,
 "schism did not preserve the actual priest/station conversion and reset")
assert(root.force_state.player.doctrine_web_0588.schism_waves[1].converted==1
 and hostility>0,
 "schism did not record true conversion or set rogue force hostility")
for i=1,20 do
 assert(storage.tech_priests.pairs_by_station[100+i].station.force==player_force,
  "unrelated research constituency was incorrectly defected")
end
-- Hard-loyal Void does not schism; disabling rebellion protects priests.
state.loyalty.space=0
game.tick=game.tick+607
nth[607]()
assert(state.loyalty.space==100 and not game.forces["tech-priests-rogue-space"],
 "hard-loyal Void doctrine unexpectedly defected")
local loyal=pair(700,"sushi","military")
state.loyalty.military=0
settings.global["tech-priests-enable-doctrine-rebellions"].value=false
game.tick=game.tick+607
nth[607]()
assert(state.loyalty.military==100 and loyal.station.force==player_force
 and loyal.priest.force==player_force
 and not game.forces["tech-priests-rogue-military"],
 "disabled rebellion still stole an original priest or station")
print("[conclave-research-schism-1181] PASS profile-family voting, no cross-family research fallback, prerequisite refusal, completed-research opposition, physical defections, hard-loyal Void, and disabled rebellion")
