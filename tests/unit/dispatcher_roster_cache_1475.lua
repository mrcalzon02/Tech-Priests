-- Regression 1475: dispatcher roster reuse must not delay births, loss or rebind.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=0}
local M=require("scripts.core.single_dispatcher_0510")
local map=storage.tech_priests.pairs_by_station
local calls={}
M.service_pair=function(pair)
  calls[#calls+1]=pair.station.unit_number
  return {processed=1,acted=0,waiting=1,failed=0}
end
local function new_pair(unit)
  return {station={unit_number=unit,valid=true},
    priest={unit_number=10000+unit,valid=true}}
end
local function dispatch(expected)
  calls={}
  M.root().cursor=0
  local result=M.service_all("1475-fixture",24)
  assert(result.processed==#expected,"dispatcher pair count mismatch")
  for i=1,#expected do
    assert(calls[i]==expected[i],
      "lexicographic roster/order changed at slot "..i..
      " got "..tostring(calls[i]).." expected "..tostring(expected[i]))
  end
end
map[1]=new_pair(1);map[2]=new_pair(2);map[10]=new_pair(10)
dispatch({1,10,2})
assert(M.root().stats.roster_rebuilds==1)
dispatch({1,10,2})
assert(M.root().stats.roster_reuses==1,"stable roster was pointlessly sorted again")
map[3]=new_pair(3)
dispatch({1,10,2,3})
assert(M.root().stats.roster_rebuilds==2,"new priest was not scheduled immediately")
map[2]=nil
dispatch({1,10,3})
assert(M.root().stats.roster_rebuilds==3,"removed priest retained a slot")
map[3].priest.valid=false
dispatch({1,10})
assert(M.root().stats.roster_rebuilds==4,"invalid priest retained a slot")
map[10]=new_pair(10)
dispatch({1,10})
assert(M.root().stats.roster_rebuilds==5,"same-count priest replacement not detected")
local replacement={}
for k,v in pairs(map)do replacement[k]=v end
storage.tech_priests.pairs_by_station=replacement
dispatch({1,10})
assert(M.root().stats.roster_rebuilds==6,"storage map identity change not detected")
local large={}
for i=1,100 do large[i]=new_pair(i) end
storage.tech_priests.pairs_by_station=large
local visited={}
M.root().cursor=0
for pulse=1,5 do
  game.tick=pulse*5
  M.service_all("1475-round-robin",24)
  for _,unit in ipairs(calls)do visited[unit]=true end
  calls={}
end
local n=0;for _ in pairs(visited)do n=n+1 end
assert(n==100,"round-robin stopped visiting some priests")
assert(M.root().stats.roster_reuses>=5,"large stable roster was not reused")
print("[dispatcher-roster-cache-1475] PASS")
