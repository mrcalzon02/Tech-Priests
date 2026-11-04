-- Native-like LuaEntity force transfer refusal/rollback regression (1184).
-- This is SOURCE-level proof; separate Factorio native schism is still needed.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
_G.storage={tech_priests={pairs_by_station={}}}
_G.settings={global={
 ["tech-priests-enable-doctrine-rebellions"]={value=true},
 ["tech-priests-dont-touch-my-toys"]={value=true},
}}
local callbacks,nth={},{}
local surface={index=1,name="nauvis",map_gen_settings={seed=1184}}
surface.find_entities_filtered=function()return {}end
local function force(name,index)
 local f={name=name,index=index,valid=true,technologies={},recipes={}}
 f.print=function()end
 f.set_cease_fire=function()end
 f.set_friend=function()end
 return f
end
local owner=force("player",1)
_G.game={tick=1,forces={player=owner},surfaces={[1]=surface},
 create_force=function(name)
  local f=force(name,5);game.forces[name]=f;return f
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
   for _,e in ipairs(events) do callbacks[e]=fn end
  else callbacks[events]=fn end
 end,
 on_nth_tick=function(period,fn) nth[period]=fn end,
}
package.loaded["scripts.core.doctrine_chatter"]={
 profile_for_pair=function()
  return {doctrine_camp="mixed_spaghetti"}
 end
}
local block_priest=true
local function entity(id,who,deny)
 local data={force=who}
 local out={valid=true,name="senior-cogitator-station",
  unit_number=id,position={x=id,y=0},surface=surface}
 setmetatable(out,{
  __index=function(_,k)if k=="force" then return data.force end end,
  __newindex=function(_,k,v)
   if k=="force" then
    if deny and block_priest and v~=owner then
      error("native-setter-forbidden")
    end
    data.force=v
   else rawset(_,k,v) end
  end})
 return out
end
local station=entity(41,owner,false)
local priest=entity(1041,owner,true)
local pair={station=station,priest=priest,doctrine_family="industry"}
storage.tech_priests.pairs_by_station[41]=pair
local conclave=require("scripts.core.conclave_center_0558")
conclave.install()
callbacks[1]({entity={valid=true,name="tech-priests-conclave-center",
 unit_number=5,force=owner,position={x=0,y=0},surface=surface}})
local state=storage.tech_priests.conclave_center_0558.force_state.player
state.loyalty.industry=0
game.tick=607;nth[607]()
local rogue=game.forces["tech-priests-rogue-industry"]
assert(rogue and rogue.valid and pair.station.force==owner
 and pair.priest.force==owner and pair.rogue_doctrine_0588==nil
 and state.loyalty.industry==0
 and #(state.doctrine_web_0588.schism_waves)==0,
 "failed force setter produced phantom defection or erased schism debt")
assert(pair.last_blocker_0590=="schism-force-transfer:force-setter-refused",
 "failed force setter did not report an exact rollback/refusal")

-- Once the engine allows the setter, the next real governance pulse must
-- convert the same exact pair, not a duplicate/foreign-force identity.
block_priest=false
game.tick=1214;nth[607]()
assert(pair.station.force==rogue and pair.priest.force==rogue
 and pair.rogue_doctrine_0588==true and state.loyalty.industry==100
 and #state.doctrine_web_0588.schism_waves==1
 and state.doctrine_web_0588.schism_waves[1].converted==1,
 "recovered force ownership did not complete exactly one real schism")

-- Failed player reclamation may not clear rogue flags. Re-enable the
-- denial for setting the priest to the ORIGINAL owner, then retry.
owner.technologies["tech-priests-data-spike-reclamation-1"]={
 researched=true}
game.get_player=function(index)
 if index==1 then return {valid=true,force=owner} end
end
local blocked_owner_transfer=true
local mt=getmetatable(priest)
local prev_new=mt.__newindex
mt.__newindex=function(ent,k,v)
 if k=="force" and blocked_owner_transfer and v==owner then
  error("native-player-recapture-refused")
 end
 return prev_new(ent,k,v)
end
local function attempt_spike()
 callbacks[11]({effect_id="tech-priests-data-spike-impact",
  source_player_index=1,target_entity=station})
 local pending=storage.tech_priests.conclave_center_0558.data_spike_pending_0591
 assert(pending and next(pending),"real player claim not recorded")
 game.tick=game.tick+90*60
 nth[60]()
 return pending
end
local pending=attempt_spike()
assert(pair.station.force==rogue and pair.priest.force==rogue
 and pair.rogue_doctrine_0588==true
 and pair.last_blocker_0590=="data-spike-force-transfer:force-setter-refused"
 and next(pending)==nil,
 "failed player recapture stole pair or cleared rogue state")
blocked_owner_transfer=false
pending=attempt_spike()
assert(pair.station.force==owner and pair.priest.force==owner
 and pair.rogue_doctrine_0588==nil and next(pending)==nil
 and pair.mode=="returning",
 "verified player reclamation did not restore the original pair")
print("[conclave-force-transfer-1184] PASS setter refusal rollback, zero phantom schisms, debt retry and exact player Data Spike ownership readback")
