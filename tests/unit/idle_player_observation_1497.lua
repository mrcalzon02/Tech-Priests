package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Observer=require('scripts.core.idle_player_observation_1497')
local surf={index=1}; local other={index=2}
local station={valid=true,unit_number=10,surface=surf,position={x=0,y=0}}
local priest={valid=true,unit_number=11,surface=surf,position={x=0,y=0}}
local pair={station=station,priest=priest}
local player={valid=true,character={valid=true,surface=surf,position={x=100,y=0}}}
local reads=0
local g=setmetatable({tick=1},{__index=function(_,key)
  if key=='connected_players' then reads=reads+1;return {player} end
end})
for i=1,1000 do assert(not Observer.observed(pair,g)) end
assert(reads==1,'player position list read for each priest instead of once per tick')
-- Same-tick GUI opens and selections must bypass positional cache immediately.
player.opened=station
assert(Observer.observed(pair,g),'opened station missed same-tick wake')
player.opened=nil
player.selected=priest
assert(Observer.observed(pair,g),'selected priest missed same-tick wake')
player.selected=nil
player.selected=station
assert(Observer.observed(pair,g),'selected station missed same-tick wake')
player.selected=nil
assert(reads==1,'GUI wakeup unexpectedly rebuilt position snapshot')
g.tick=2;player.character.position={x=80,y=0}
assert(Observer.observed(pair,g),'80-tile observation boundary incorrectly excluded')
assert(reads==2)
g.tick=3;player.character.position={x=80.01,y=0}
assert(not Observer.observed(pair,g),'beyond-80 position incorrectly observed')
g.tick=4;player.character.surface=other;player.character.position={x=0,y=0}
assert(not Observer.observed(pair,g),'player on another surface observed')
g.tick=5;player.character.valid=false;player.opened=station
assert(Observer.observed(pair,g),'GUI operation without character must still wake')
player.opened=nil
g.tick=6;player.character=nil
assert(not Observer.observed(pair,g))
player.selected=station
assert(Observer.observed(pair,g),'GUI selection without character not observed')
assert(not Observer.observed(nil,g) and not Observer.observed(pair,nil))
player.selected=nil
priest.valid=false;station.valid=true;station.position={x=0,y=0}
player.character={valid=true,surface=surf,position={x=4,y=1}}
g.tick=7
assert(Observer.observed(pair,g),'station fallback not observed')
station.valid=false
assert(not Observer.observed(pair,g),'invalid pair unexpectedly observed')
print('[idle-player-observation-1497] PASS: one sample/tick, live GUI, 80-tile, surfaces')
