-- 1182: Two separate parent forces must NEVER share a same-family rogue.
-- Repeat source-driven schisms after a simulated Factorio save/reload, and
-- preserve the user machine-protection switch without granting inventory.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
_G.storage={tech_priests={pairs_by_station={}}}
_G.settings={global={
 ["tech-priests-enable-doctrine-rebellions"]={value=true},
 ["tech-priests-dont-touch-my-toys"]={value=true},
}}
local callbacks,nth={},{}
local surface={index=1,name="nauvis",map_gen_settings={seed=1182}}
local objects={}
surface.find_entities_filtered=function(args)
 local result={}
 for _,entity in ipairs(objects) do
  if entity.valid and entity.force==args.force then
   local dx=entity.position.x-args.position.x
   local dy=entity.position.y-args.position.y
   if dx*dx+dy*dy<=(args.radius or 0)^2 then
    result[#result+1]=entity
   end
  end
 end
 return result
end
local relations={}
local function force(name,index)
 local f={name=name,index=index,valid=true,technologies={},recipes={}}
 f.print=function()end
 f.set_cease_fire=function(other,enabled)
  relations[f.name..":"..other.name..":cease"]=enabled
 end
 f.set_friend=function(other,enabled)
  relations[f.name..":"..other.name..":friend"]=enabled
 end
 return f
end
local player=force("player",1)
local second=force("settlers",2)
_G.game={tick=1,forces={player=player,settlers=second},
 surfaces={[1]=surface},create_force=function(name)
  assert(game.forces[name]==nil,"rogue force was created twice")
  local f=force(name,100+#name)
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
package.loaded["scripts.core.doctrine_chatter"]={
 profile_for_pair=function()return {doctrine_camp="mixed_spaghetti",
 current_doctrine_camp_0370="mixed_spaghetti"}end
}
local function pair(id,parent,x)
 local station={valid=true,name="senior-cogitator-station",
  unit_number=id,position={x=x,y=0},surface=surface,force=parent}
 local priest={valid=true,unit_number=id+1000,force=parent}
 local p={station=station,priest=priest,doctrine_family="industry"}
 storage.tech_priests.pairs_by_station[id]=p
 return p
end
local first=pair(100,player,0)
local other=pair(200,second,200)
local machine_one={valid=true,type="assembling-machine",name="assembling-machine-1",
 position={x=3,y=0},surface=surface,force=player}
local machine_two={valid=true,type="assembling-machine",name="assembling-machine-1",
 position={x=203,y=0},surface=surface,force=second}
objects={machine_one,machine_two}
local conclave=require("scripts.core.conclave_center_0558")
conclave.install()
callbacks[1]({entity={valid=true,name="tech-priests-conclave-center",
 unit_number=5,force=player,position={x=0,y=0},surface=surface}})
callbacks[1]({entity={valid=true,name="tech-priests-conclave-center",
 unit_number=6,force=second,position={x=200,y=0},surface=surface}})
local root=storage.tech_priests.conclave_center_0558
assert(root.force_state.player and root.force_state.settlers,
 "separate original Conclave centers did not initialize separate ledgers")
root.force_state.player.loyalty.industry=0
root.force_state.settlers.loyalty.industry=0
game.tick=607
nth[607]()
local rogueA=game.forces["tech-priests-rogue-industry"]
local rogueB=game.forces["tech-priests-rogue-industry-2"]
assert(rogueA and rogueB and rogueA~=rogueB
 and first.station.force==rogueA and first.priest.force==rogueA
 and other.station.force==rogueB and other.priest.force==rogueB,
 "same-family schisms from separate parents shared allegiance")
assert(machine_one.force==player and machine_two.force==second,
 "protected player machines were seized by a doctrine schism")
assert(root.force_state.player.doctrine_web_0588.schism_waves[1].converted==1
 and root.force_state.settlers.doctrine_web_0588.schism_waves[1].converted==1,
 "cross-force conversion counts or history were misattributed")
assert(relations["player:"..rogueA.name..":cease"]==false
 and relations["settlers:"..rogueB.name..":cease"]==false,
 "distinct newly schismed forces were not hostile to their own parent")

-- Simulate Factorio reloading the Lua runtime while preserving all state
-- and native entities. The module re-registers its ONE governance authority.
local savedRoot=root
package.loaded["scripts.core.conclave_center_0558"]=nil
callbacks,nth={},{}
conclave=require("scripts.core.conclave_center_0558")
conclave.install()
assert(storage.tech_priests.conclave_center_0558==savedRoot
 and type(nth[607])=="function",
 "save/reload replaced the Conclave ledger or lost the event hook")
game.tick=1214
nth[607]()
assert(first.rogue_force_0589==rogueA.name
 and other.rogue_force_0589==rogueB.name
 and first.station.force==rogueA and other.station.force==rogueB
 and #root.force_state.player.doctrine_web_0588.schism_waves==1
 and #root.force_state.settlers.doctrine_web_0588.schism_waves==1,
 "save/reload changed existing rebellion forces or duplicated a schism")

-- A later wave from the SAME original force must rejoin only its original
-- rogue domain, and only when the player disables machine protection.
settings.global["tech-priests-dont-touch-my-toys"].value=false
local later=pair(300,player,0)
root.force_state.player.loyalty.industry=0
game.tick=1821
nth[607]()
assert(later.station.force==rogueA and later.priest.force==rogueA
 and machine_one.force==rogueA and machine_two.force==second
 and #root.force_state.player.doctrine_web_0588.schism_waves==2
 and #root.force_state.settlers.doctrine_web_0588.schism_waves==1,
 "subsequent wave captured wrong-parent stock or made a second rogue force")
assert(root.force_state.player.doctrine_web_0588.schism_waves[2].seized==1,
 "explicitly permitted local machine capture was not counted")
print("[conclave-multiforce-reload-1182] PASS distinct original forces, honest machine protection/seizure, faction hostility, saved force identity and no duplicate defection")
