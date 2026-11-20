-- Diagnostic only: synthetic observer pass, not native Factorio UPS.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local Observer=require('scripts.core.idle_player_observation_1497')
local surface={index=1}
local all_players={}
for i=1,4 do
  all_players[i]={valid=true,character={valid=true,surface=surface,
    position={x=400+i*100,y=400+i*100}}}
end
local reads=0
local game_ref=setmetatable({tick=0},{__index=function(_,key)
  if key=='connected_players' then
    reads=reads+1
    return all_players
  end
end})
local priests={}
for i=1,80 do
  priests[i]={station={valid=true,unit_number=i,surface=surface,position={x=i,y=0}},
    priest={valid=true,unit_number=1000+i,surface=surface,position={x=i,y=0}}}
end
local function before(pair, g)
  local priest,station=pair.priest,pair.station
  local ent=priest and priest.valid and priest or station
  if not(ent and ent.valid and g)then return false end
  local surf,pos=ent.surface,ent.position
  for _,player in pairs(g.connected_players or {}) do
    if player and player.valid and player.character and player.character.valid
      and player.character.surface == surf then
      local pp=player.character.position
      local dx,dy=(pp.x or 0)-(pos.x or 0),(pp.y or 0)-(pos.y or 0)
      if dx*dx+dy*dy<=80*80 then return true end
    end
    if player and player.valid and player.opened==station then return true end
    if player and player.valid and player.selected
      and(player.selected==station or player.selected==priest)then return true end
  end
  return false
end
local function run(fn)
  reads=0
  local started=os.clock()
  for tick=1,500 do
    game_ref.tick=tick
    for _,pair in ipairs(priests)do
      assert(not fn(pair,game_ref))
    end
  end
  return reads,(os.clock()-started)*1000
end
local old_reads,old_ms=run(before)
local new_reads,new_ms=run(Observer.observed)
assert(old_reads==80*500 and new_reads==500,
  'position snapshot should reduce player-list reads to one per tick')
print(string.format('[idle-player-observation-1497-perf] 80 pairs x 500 ticks; old_reads=%d new_reads=%d',old_reads,new_reads))
print(string.format('[idle-player-observation-1497-perf] local Lua old_ms=%.3f new_ms=%.3f ratio=%.2fx (diagnostic only)',old_ms,new_ms,old_ms/new_ms))
