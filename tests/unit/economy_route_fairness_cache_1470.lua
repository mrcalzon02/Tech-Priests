-- Regression 1470: fair per-route pulse schedules, non-compounded governors,
-- complete-only station indexing, and registry-owned idle wakeups.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={pairs_by_station={}}}
game={tick=0,connected_players={}}
local function populate(n)
  storage.tech_priests.pairs_by_station={}
  for i=1,n do
    storage.tech_priests.pairs_by_station[i]={
      station={valid=true,unit_number=i},
      priest={valid=true,unit_number=i+10000}
    }
  end
end
local R={nth_tick_routes={},on_nth_tick=function(tick,fn,opts)
  local key=tostring(tick)
  R.nth_tick_routes[key]=R.nth_tick_routes[key] or {}
  local entry={tick=tick,handler=fn,owner=opts.owner,route=opts.route,
    category=opts.category,id=opts.owner..":"..opts.route}
  R.nth_tick_routes[key][#R.nth_tick_routes[key]+1]=entry
  return entry
end}
_G.TechPriestsRuntimeEventRegistry=R
local E594=require("scripts.core.efficiency_economy_0594")
populate(100)
local legacyRuns=0
local visual={tick=5,owner="test-visual",route="visual",category="visuals",
  id="test-visual:visual",handler=function()legacyRuns=legacyRuns+1 end}
R.nth_tick_routes["5"]={visual}
assert(E594.install()==true,"0594 failed to wrap test route")
for i=1,120 do game.tick=i*5; visual.handler({tick=game.tick}) end
assert(legacyRuns==24,"0594 must execute every route once per 5 received pulses, not tick residues")

local E598=require("scripts.core.efficiency_economy_0598")
populate(35)
local background={tick=60,owner="test-gui",route="redraw",category="gui",id="test-gui:redraw"}
local admitted=0
for i=1,120 do
  game.tick=1000+i*60
  if E598.route_budget(background,{tick=game.tick},60) then admitted=admitted+1 end
end
assert(admitted==30,"0598 must admit every phase once per 4 received pulses")

populate(100)
local guiRuns=0
local gui={tick=60,owner="presentation",route="refresh",category="gui",
  id="presentation:refresh",handler=function()guiRuns=guiRuns+1 end}
R.nth_tick_routes["60"]={gui}
assert(E594.install()==true,"0594 failed to rescan registry")
for i=1,120 do
  game.tick=10000+i*60
  local event={tick=game.tick}
  if E598.route_budget(gui,event,60) then gui.handler(event) end
end
assert(guiRuns==12,"0594 and 0598 compounded background throttling")

storage={tech_priests={}}
game.tick=0
local E579=require("scripts.core.efficiency_economy_0579")
local surface={index=1}
local area={{0,0},{16,16}}
local entity={valid=true,type="assembling-machine",name="assembling-machine-1",
  unit_number=123,surface=surface,position={x=4,y=4}}
assert(E579.index_entity(entity,"built"))
assert(E579.entities_for_area(surface,area)==nil,
  "one build event must not mark a whole catalog cell known")
assert(E579.note_area_scan(surface,area,{entity},768))
local indexed=E579.entities_for_area(surface,area)
assert(type(indexed)=="table" and #indexed==1,
  "complete area scan must be reusable")
assert(E579.note_area_scan(surface,area,{entity},1))
assert(E579.entities_for_area(surface,area)==nil,
  "capped area scan must fail closed instead of returning an incomplete index")

storage={tech_priests={pairs_by_station={}}}
game.tick=0
defines={events={
  on_built_entity=1,on_robot_built_entity=2,script_raised_built=3,
  script_raised_revive=4,on_player_mined_entity=5,on_robot_mined_entity=6,
  on_entity_died=7,script_raised_destroy=8,on_entity_damaged=9,
  on_research_finished=10}}
local registered,cleanup,rawRegistrations={},nil,0
R.on_event=function(id,handler)
  registered[id]=handler
  return {handler=handler}
end
R.on_nth_tick=function(tick,handler,opts)
  if tick==600 and opts.owner=="efficiency_economy_0599" then cleanup=handler end
  return {handler=handler}
end
script={on_event=function()rawRegistrations=rawRegistrations+1 end}
local originalCalls=0
_G.tick_pair=function()originalCalls=originalCalls+1 end
local E599=require("scripts.core.efficiency_economy_0599")
assert(E599.install()==true and rawRegistrations==0,
  "0599 must register wakeups via shared event registry only")
for i=1,10 do assert(registered[i],"missing 0599 wake event "..i) end
assert(cleanup,"0599 housekeeping route missing")
local pair={
  station={valid=true,unit_number=42,position={x=2,y=2},
    force={index=1},surface=surface},
  priest={valid=true,unit_number=43,position={x=2,y=2},
    force={index=1},surface=surface}}
storage.tech_priests.pairs_by_station[42]=pair
_G.tick_pair(pair)
game.tick=10; _G.tick_pair(pair)
assert(originalCalls==1,"idle tick_pair did not sleep")
game.tick=11
registered[defines.events.on_entity_damaged]({name=9,
  entity={valid=true,position={x=3,y=3},force={index=1},surface=surface}})
game.tick=12; _G.tick_pair(pair)
assert(originalCalls==2,"damage must wake sleeping priest immediately")
local state=storage.tech_priests.efficiency_economy_0599
state.dirty_cells["obsolete"]=25
state.pair_state[9999]={next_tick=5000}
game.tick=2000; cleanup({tick=2000})
assert(state.dirty_cells.obsolete==nil and state.pair_state[9999]==nil,
  "0599 housekeeping must prune expired dirty cells and orphaned pair states")
print("[economy-route-fairness-cache-1470] PASS")
