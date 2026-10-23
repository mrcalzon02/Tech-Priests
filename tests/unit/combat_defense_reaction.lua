-- Hostile damage creates a bounded station-local request, never fake supplies.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.combat_defense_reaction_0816")
local tick=108100
game={tick=tick}
local player={name="player"}
local enemy={name="enemy"}
player.is_enemy=function(other) return other==enemy end
enemy.is_enemy=function(other) return other==player end
local surface={}
local function entity(name,x,force)
  return {valid=true,name=name,position={x=x,y=0},force=force,surface=surface}
end
local left=entity("intermediate-cogitator-station",0,player)
local right=entity("planetary-magos-cogitator-station",64,player)
local priestA=entity("tech-priest",1,player)
local priestB=entity("tech-priest",65,player)
local first={station=left,priest=priestA,radius=28}
local second={station=right,priest=priestB,radius=28}
local pairs={a=first,b=second}
local biter=entity("small-biter",58,enemy)
local victim=entity("stone-furnace",60,player)
local ok,reason=M.record_damage({entity=victim,cause=biter,final_damage_amount=4},pairs)
assert(ok and reason=="queued","real hostile damage was not recorded")
assert(first.defense_perimeter_0259==nil,"remote station took hostile attack")
local state=second.defense_perimeter_0259
assert(#state.threats==1 and state.hostile_hits_0816==1
  and math.abs(state.threats[1].position.x-37)<0.01
  and state.threats[1].damage_position.x==60
  and state.turrets_built_at_first_hostile_hit_0816==0,
  "hostile approach was not projected to perimeter or damage position lost")
for _=1,20 do
  tick=tick+1;game.tick=tick
  local yes,why=M.record_damage({entity=victim,cause=biter,damage_amount=2},pairs)
  assert(yes and why=="coalesced","burst damage was not coalesced")
end
assert(#state.threats==1 and state.hostile_hits_0816==21,
  "damage event storm queued duplicate turrets")
local friendly=entity("allied-priest",58,player)
assert(not M.record_damage({entity=victim,cause=friendly,damage_amount=10},pairs))
assert(not M.record_damage({entity=victim,cause=biter,damage_amount=0},pairs))
local far=entity("rock",180,player)
assert(not M.record_damage({entity=far,cause=biter,damage_amount=3},pairs))
assert(#state.threats==1,"non-hostile or remote damage altered defense queue")
game.tick=game.tick+M.repeat_window+1
local yes,why=M.record_damage({entity=victim,cause=biter,damage_amount=4},pairs)
assert(yes and why=="queued" and #state.threats==2,
  "new hostile incident failed to enter bounded queue")
for i=1,30 do
  game.tick=game.tick+M.repeat_window+1
  M.record_damage({entity=victim,cause=biter,damage_amount=1},pairs)
end
assert(#state.threats==M.max_incidents,"hostile incident queue grew without bound")
local entry=nil
_G.TechPriestsRuntimeEventRegistry={on_event=function(id,callback,filters,opts)
  assert(id==92 and opts.owner=="combat_defense_reaction_0816")
  entry=callback
  return true
end}
defines={events={on_entity_damaged=92}}
assert(M.install() and entry==M.record_damage,
  "canonical event registration did not use existing route owner")
print("[combat-defense-reaction] PASS hostile queue, ownership, coalescing, safety")
