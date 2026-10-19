-- Lua 5.2 regression: inventory custody reach is measured to a physical
-- entity footprint, not to the unreachable center of a large Cogitator.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}}
local Construction=require("scripts.core.construction_planner")
local stock=1
local inv={valid=true}
inv.get_item_count=function(name)
  return name=="tech-priests-emergency-miner" and stock or 0
end
inv.remove=function(stack)
  if stack.name~="tech-priests-emergency-miner" then return 0 end
  local n=math.min(stock,stack.count);stock=stock-n;return n
end
inv.insert=function(stack)
  if stack.name~="tech-priests-emergency-miner" then return 0 end
  stock=stock+stack.count;return stack.count
end
local surface={index=1}
local force={index=1,name="player"}
local station={valid=true,unit_number=1,position={x=0,y=0},
  selection_box={left_top={x=-1.25,y=-1.25},
    right_bottom={x=1.25,y=1.25}},
  surface=surface,force=force}
local priest={valid=true,position={x=1.8,y=0}}
local pair={station=station,priest=priest,station_unit=1}
storage.tech_priests.pairs_by_station[1]=pair
local moves={}
_G.tech_priests_request_movement_0418=function(_,pos,reason,opts)
  moves[#moves+1]={pos=pos,reason=reason,owner=opts.owner}
  return true
end
local function check(cond,msg)
  if not cond then error("construction-footprint regression: "..msg,2) end
end
local function task(phase)
  return {phase=phase,started_tick=game.tick,
    source_entity=station,source_inv=inv,item_name="tech-priests-emergency-miner",
    entity_name="tech-priests-emergency-miner",position={x=6,y=0}}
end

pair.construction_task_0338=task("move-source")
local pickup=Construction.service_pair(pair,"station-footprint-pickup")
check(pickup.waiting==1 and pickup.detail=="moving-site",
  "standing beside the station box did not advance to construction site")
check(stock==0,"physical device was not removed from its original inventory")
check(pair.construction_custody_0338 and pair.construction_custody_0338.count==1,
  "picked-up machine lacks persistent physical custody")
check(#moves==1 and moves[1].reason=="construction-site-0338",
  "unreachable station-center movement was requested rather than a site route")

-- The same proximity correction must apply when interrupted construction
-- returns an item to its original machine inventory.
pair.construction_task_0338=task("return-custody")
pair.construction_task_0338.carried={item_name="tech-priests-emergency-miner",count=1}
moves={}
local returned=Construction.service_pair(pair,"station-footprint-return")
check(returned and returned.detail=="custody-returned-source",
  "interrupted build failed to return custody beside the station footprint")
check(stock==1 and not pair.construction_custody_0338,
  "returned item was not physically restored or custody was not cleared")
check(#moves==0,"station-center route blocked physically reachable item return")

-- A remote priest must still travel to the station; using the footprint
-- cannot make machine inventories accessible from arbitrary distances.
priest.position={x=10,y=0}
pair.construction_task_0338=task("move-source")
moves={}
local remote=Construction.service_pair(pair,"remote-pickup-needs-movement")
check(remote and remote.detail=="moving-source",
  "out-of-range construction pickup was incorrectly accepted")
check(stock==1 and #moves==1
  and moves[1].reason=="construction-source-0338",
  "remote pickup removed an item or skipped physical movement")
check(moves[1].pos.x>station.selection_box.right_bottom.x
    and moves[1].pos.x<priest.position.x
    and moves[1].pos.y==0,
  "construction requested movement into an impassable station center")
-- A returning priest can be hundreds of real tiles away after gathering
-- material beyond its assigned radius. A fixed 1,200-tick timeout is shorter
-- than legitimate travel; scale that deadline once a source exists.
priest.position={x=300,y=0}
game.tick=5000
pair.construction_task_0338=task("move-source")
pair.construction_task_0338.started_tick=1000
moves={}
local far=Construction.service_pair(pair,"long-physical-return")
check(far and far.detail=="moving-source" and stock==1,
  "legitimate far-away source route aborted without moving")
check(pair.construction_task_0338.travel_allowance_ticks_0338>Construction.request_timeout,
  "construction route failed to account for 300 real tiles of travel")
game.tick=6300
local enroute=Construction.service_pair(pair,"long-physical-return-continuing")
check(enroute and enroute.detail=="moving-source",
  "far-away priest was timed out after only the old fixed deadline")
game.tick=15000
local timed=Construction.service_pair(pair,"unreachable-route-is-finite")
check(timed and tostring(timed.detail):find("construction%-timeout:move%-source"),
  "unreachable construction was allowed to monopolize its source indefinitely")
check(stock==1 and pair.construction_task_0338==nil,
  "construction timeout incorrectly consumed uncollected materials")

-- Manufacturing time is not construction travel. An item produced after
-- the former timeout still permits actual source pickup and site travel.
game.tick=20000
stock=0
_G.tech_priests_inventory_steward_sources_for_pair=function()
  return {{inv=inv,entity=station,source="station-container"}}
end
priest.position={x=1.8,y=0}
pair.construction_task_0338=task("waiting-source")
pair.construction_task_0338.started_tick=1
local awaiting=Construction.service_pair(pair,"ingredient-manufacture-pending")
check(awaiting and awaiting.detail=="waiting-source"
  and not pair.construction_task_0338.active_started_tick_0338,
  "unmanufactured placeable consumed its physical travel budget")
stock=1
local acquired=Construction.service_pair(pair,"material-now-available")
check(acquired and acquired.detail=="moving-site" and stock==0
  and pair.construction_custody_0338 and pair.construction_custody_0338.count==1,
  "manufactured item was not physically acquired after a long recipe wait")
print("[construction-footprint-regression] PASS scenarios=7")
