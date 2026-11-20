-- Regression 1497: real 0599 wrapper wakes during damage, work and observation.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={pairs_by_station={}}}
local surf={index=1}
local force={index=1}
local station={valid=true,unit_number=42,surface=surf,force=force,position={x=0,y=0}}
local priest={valid=true,unit_number=43,surface=surf,force=force,position={x=0,y=0}}
local pair={station=station,priest=priest}
storage.tech_priests.pairs_by_station[42]=pair
local player={valid=true,character={valid=true,position={x=100,y=0},surface=surf}}
local player_list_reads=0
local game_ref=setmetatable({tick=1},{__index=function(_,key)
  if key=='connected_players' then
    player_list_reads=player_list_reads+1
    return {player}
  end
end})
game=game_ref
local events={}
defines={events={on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
  script_raised_revive=4,on_player_mined_entity=5,on_robot_mined_entity=6,
  on_entity_died=7,script_raised_destroy=8,on_entity_damaged=9,
  on_research_finished=10}}
_G.TechPriestsRuntimeEventRegistry={
  on_event=function(id, fn) events[id]=fn; return true end,
  on_nth_tick=function()return true end,
}
local calls=0
_G.tick_pair=function()calls=calls+1; return true end
local M=require('scripts.core.efficiency_economy_0599')
assert(M.install())
assert(_G.tick_pair(pair)==true and calls==1,'initial idle probe must run')
local root=storage.tech_priests.efficiency_economy_0599
local state=root.pair_state[42]
assert(state and state.next_tick==61)
game.tick=2
assert(_G.tick_pair(pair)==nil and calls==1,'unobserved idle was not slept')
game.tick=3
events[9]({name=9,entity={valid=true,surface=surf,force=force,position={x=1,y=1}}})
assert(_G.tick_pair(pair)==true and calls==2,'damage did not immediately wake')
assert(root.pair_state[42]==state,'damage wake reset allocated a new pair state')
-- Move near and probe across ticks: player position snapshots refreshed per tick.
root.dirty_cells={}
game.tick=4; player.character.position={x=1,y=1}
assert(_G.tick_pair(pair)==true and calls==3,'nearby player was skipped')
game.tick=5
assert(_G.tick_pair(pair)==true and calls==4,'visible priest did not remain awake')
assert(root.pair_state[42]==state,'visible priest created state each tick')
-- Same-tick selection/opened changes must wake even after a cached far snapshot.
game.tick=6; player.character.position={x=100,y=0}
assert(_G.tick_pair(pair)==true and calls==5,'first idle probe after visibility must run')
assert(_G.tick_pair(pair)==nil and calls==5,'idle gate did not re-arm')
player.opened=station
assert(_G.tick_pair(pair)==true and calls==6,'same-tick station opening was not observed')
player.opened=nil
player.selected=priest
assert(_G.tick_pair(pair)==true and calls==7,'same-tick priest selection was not observed')
player.selected=nil
pair.current_order={target={}}
assert(_G.tick_pair(pair)==true and calls==8,'active order was skipped')
pair.current_order=nil
assert(root.pair_state[42]==state,'active order reset allocated state')
-- More priests at one tick share the same player-list snapshot.
game.tick=7
for i=100,150 do
  local p={station={valid=true,unit_number=i,surface=surf,force=force,
      position={x=200,y=200}},priest={valid=true,unit_number=1000+i,
      surface=surf,force=force,position={x=200,y=200}}}
  _G.tick_pair(p)
end
local before=player_list_reads
for i=100,150 do
  local p={station={valid=true,unit_number=i,surface=surf,force=force,
      position={x=200,y=200}},priest={valid=true,unit_number=1000+i,
      surface=surf,force=force,position={x=200,y=200}}}
  _G.tick_pair(p)
end
assert(player_list_reads==before,'player list resampled per pair within one tick')
print('[idle-adaptive-observation-integration-1497] PASS')
