-- Regression 1476: indexed station scans fail closed on capped/partial/stale data.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=0}
storage={tech_priests={}}
defines={events={on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
 script_raised_revive=4,on_player_mined_entity=5,on_robot_mined_entity=6,
 on_entity_died=7,script_raised_destroy=8}}
local callbacks={}
_G.TechPriestsRuntimeEventRegistry={
 on_event=function(ids,fn)
   for _,id in ipairs(ids) do callbacks[id]=fn end
   return {handler=fn}
 end,
 on_nth_tick=function(_,fn) return {handler=fn} end,
}
local I=require("scripts.core.efficiency_economy_0579")
assert(I.install()==true,"index governor failed to install")
local scan=_G.tech_priests_efficiency_0579_note_area_scan
local query=_G.tech_priests_efficiency_0579_entities_for_area
assert(type(scan)=="function" and type(query)=="function","index bridge unavailable")
local surface={index=7}
local full={{0,0},{32,32}}
local left={{0,0},{16,32}}
local right={{16,0},{32,32}}
local e={valid=true,type="assembling-machine",name="assembler",
 unit_number=41,position={x=8,y=8},surface=surface}
assert(scan(surface,full,{e},1)==true,"capped scan rejected")
assert(query(surface,full,768)==nil,
 "installed wrapper dropped the scan limit and cached capped data")
assert(scan(surface,left,{e},768))
assert(query(surface,full,768)==nil,
 "partial scan was treated as full-cell knowledge")
assert(scan(surface,full,{e},768))
local result=query(surface,full,768)
assert(type(result)=="table" and #result==1 and result[1]==e,
 "complete noncapped cell was not reusable")
game.tick=5
assert(scan(surface,right,{},768))
assert(query(surface,full,768)[1]==e,
 "partial re-scan discarded a fully known cell")
game.tick=6
callbacks[1]({entity=e})
assert(query(surface,full,768)==nil,
 "build event did not invalidate indexed cell")
game.tick=7
assert(scan(surface,full,{e},768))
assert(query(surface,full,1)==nil,
 "an exact result cap produced silently truncated cached data")
assert(query(surface,full,768)[1]==e)
game.tick=7+I.max_cache_age_ticks+1
assert(query(surface,full,768)==nil,
 "cache survived stale-result revalidation deadline")
-- On load, old false-complete cell flags are discarded, not world entities.
local root=I.root()
root.cache_schema_1476=nil
root.surfaces["7"].cells["0:0"].known_tick=999999
assert(query(surface,full,768)==nil and root.surfaces["7"]==nil,
 "incorrect legacy cell knowledge survived schema migration")
local negative={{-32,-32},{0,0}}
local se={index=12}
local en={valid=true,type="furnace",name="stone-furnace",
 unit_number=55,position={x=-1,y=-1},surface=se}
game.tick=10000
assert(scan(se,negative,{en},768))
assert(query(se,negative,768)[1]==en,
 "negative-coordinate aligned cell was missed")
print("[station-cache-completeness-1476] PASS")
