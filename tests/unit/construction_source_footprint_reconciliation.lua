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
print("[construction-footprint-regression] PASS scenarios=4")
