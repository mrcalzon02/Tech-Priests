-- Lua 5.2: transient ghost revive refusal must retain the physically
-- acquired device and walk outside the ghost footprint before retrying.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=5000}
storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}}
local force={index=1}
local surface={index=1}
local station={valid=true,unit_number=20,position={x=0,y=0},
  surface=surface,force=force}
local priest={valid=true,unit_number=21,position={x=6,y=1.4}}
local pair={station=station,priest=priest,station_unit=20}
storage.tech_priests.pairs_by_station[20]=pair
local moves={}
_G.tech_priests_request_movement_0418=function(_,pos,reason,opts)
  moves[#moves+1]={pos=pos,reason=reason,owner=opts.owner}
  return true
end
local ghost={valid=true,name="entity-ghost",
  ghost_name="tech-priests-emergency-assembler",
  position={x=6,y=0},selection_box={
    left_top={x=5.5,y=-0.5},right_bottom={x=6.5,y=0.5}},
  force=force,surface=surface}
local rebuilt={valid=true,name="tech-priests-emergency-assembler",
  type="assembling-machine",position={x=6,y=0},
  force=force,surface=surface}
local revives=0
ghost.revive=function(_)
  revives=revives+1
  if revives==1 then return nil,nil end
  ghost.valid=false
  return {},rebuilt
end
local task={version="test",phase="build",started_tick=game.tick,
  active_started_tick_0338=game.tick,
  item_name="tech-priests-emergency-assembler",
  entity_name="tech-priests-emergency-assembler",
  position={x=6,y=0},ghost=ghost,
  carried={item_name="tech-priests-emergency-assembler",count=1}}
pair.construction_task_0338=task
pair.construction_custody_0338={item_name=task.item_name,count=1}
local Construction=require("scripts.core.construction_planner")
local function check(ok,detail)
  if not ok then error("construction-ghost-standoff regression: "..detail,2) end
end
local refused=Construction.service_pair(pair,"blocked-ghost")
check(refused and refused.waiting==1 and task.phase=="move-clear-site"
  and revives==1 and task.carried.count==1,
  "first refused revival discarded machine item instead of retaining custody")
local clearing=Construction.service_pair(pair,"walk-clear")
check(clearing and clearing.waiting==1 and #moves==1
  and moves[1].reason=="construction-clear-ghost-footprint-0338",
  "priest did not physically request a clear-footprint standoff")
check(moves[1].pos.y>ghost.selection_box.right_bottom.y
  and moves[1].pos.y<=ghost.selection_box.right_bottom.y+2,
  "standoff route did not clear the real ghost footprint")
priest.position={x=moves[1].pos.x,y=moves[1].pos.y}
game.tick=5030
local completed=Construction.service_pair(pair,"revive-after-moving")
check(completed and completed.acted==1 and revives==2
  and pair.construction_task_0338==nil
  and pair.construction_custody_0338==nil,
  "successful physical ghost revival did not finish the custody transaction")
check(task.carried.count==0 and task.built_entity==rebuilt,
  "completed construction failed to consume its exact carried item")
print("[construction-ghost-standoff-regression] PASS scenarios=3")
