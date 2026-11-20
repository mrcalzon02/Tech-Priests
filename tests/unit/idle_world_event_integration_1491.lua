-- Integration: epoch wake must preserve exact idle/active behavior and avoid table churn.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=10}
defines={events={on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
 script_raised_revive=4,on_player_mined_entity=5,on_robot_mined_entity=6,
 on_entity_died=7,script_raised_destroy=8,on_entity_damaged=9}}
local registered={}
_G.TechPriestsRuntimeEventRegistry={
 on_nth_tick=function(_,fn) return {handler=fn} end,
 on_event=function(ids,fn)
   for _,id in ipairs(ids) do registered[id]=fn end
   return {handler=fn}
 end,
}
local dispatcher_calls,legacy_calls=0,0
local Dispatcher={service_pair=function()
  dispatcher_calls=dispatcher_calls+1
  return false,"no-work"
end}
package.preload["scripts.core.single_dispatcher_0510"]=function() return Dispatcher end
_G.tick_pair=function() legacy_calls=legacy_calls+1; return true end
local M=require("scripts.core.efficiency_economy_0582")
assert(M.install()==true,"0582 installer rejected fixture")
local pair={mode="idle",station_unit=100,
 station={valid=true,unit_number=100,position={x=0,y=0},
  surface={valid=true,index=1},force={valid=true,index=1}},
 priest={valid=true,unit_number=101}}
storage.tech_priests.pairs_by_station[100]=pair
Dispatcher.service_pair(pair,"broker")
assert(dispatcher_calls==1,"first idle dispatcher pass missing")
local root=M.root()
local rec=root.pair["100"]
assert(rec and rec.next_dispatch_after>game.tick,"idle window not armed")
Dispatcher.service_pair(pair,"broker")
assert(dispatcher_calls==1,"idle cache was not suppressing redundant work")
local history=#root.recent
for i=1,100 do
 registered[9]({entity={valid=true,unit_number=2000+i}})
end
assert(root.pair["100"]==rec and root.stats.world_change_events_1491==100,
 "damage burst replaced cached priest records")
assert(#root.recent==history,"damage burst created per-event history allocations")
Dispatcher.service_pair(pair,"broker")
assert(dispatcher_calls==2 and root.pair["100"]==rec
 and root.stats.lazy_world_wakes_1491>=1,
 "damage did not wake cached priest on next service")
-- Active repairs, manual movement and recovery must bypass caching regardless.
pair.repair_target={valid=true}
Dispatcher.service_pair(pair,"broker")
assert(dispatcher_calls==3,"active repair was suppressed")
pair.repair_target=nil
Dispatcher.service_pair(pair,"manual-operator")
assert(dispatcher_calls==4,"manual control was suppressed")
-- The old global tick_pair wrapper must also wake immediately after a new event.
game.tick=20
_G.tick_pair(pair,"broker")
local before=legacy_calls
_G.tick_pair(pair,"broker")
assert(legacy_calls==before,"legacy idle window failed to gate repeated work")
registered[1]({entity={valid=true,unit_number=4000}})
_G.tick_pair(pair,"broker")
assert(legacy_calls==before+1,"construction event did not wake legacy gate")
-- A direct event on the pair itself continues to invalidate only that pair.
registered[9]({entity=pair.station})
assert(root.pair["100"]==nil,"own-station damage did not invalidate the pair")
print("[idle-world-event-integration-1491] PASS")
