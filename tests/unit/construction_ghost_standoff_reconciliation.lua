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
local priest={valid=true,unit_number=21,position={x=6,y=0.6}}
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
check(moves[1].pos.x>ghost.selection_box.right_bottom.x
  and moves[1].pos.x<=ghost.selection_box.right_bottom.x+2
  and moves[1].pos.x>ghost.position.x,
  "standoff route did not lead to the outer side of the real ghost")
-- A physically clear point inside the engine build reach is sufficient.
-- Do not demand exact waypoint convergence near solid station geometry.
priest.position={x=7.25,y=0.5}
game.tick=5030
local completed=Construction.service_pair(pair,"revive-after-moving")
check(completed and completed.acted==1 and revives==2
  and pair.construction_task_0338==nil
  and pair.construction_custody_0338==nil,
  "successful physical ghost revival did not finish the custody transaction")
check(task.carried.count==0 and task.built_entity==rebuilt,
  "completed construction failed to consume its exact carried item")
-- 1201 genuine 216000-tick midgame trace: the Junior had already
-- physically withdrawn its assembler, but one transient refusal on the
-- ghost-clear movement path aborted/refunded it, stalling factory growth.
-- Movement arbitration may deny a route temporarily; it cannot destroy the
-- 0338 transaction or grant an immediate ghost build.
ghost.valid=true
priest.position={x=6,y=0.6}
revives=0
task={version="test",phase="build",started_tick=game.tick,
  active_started_tick_0338=game.tick,
  item_name="tech-priests-emergency-assembler",
  entity_name="tech-priests-emergency-assembler",
  position={x=6,y=0},ghost=ghost,
  carried={item_name="tech-priests-emergency-assembler",count=1}}
pair.construction_task_0338=task
pair.construction_custody_0338={item_name=task.item_name,count=1}
local attempts=0
_G.tech_priests_request_movement_0418=function(_,pos,reason,opts)
 attempts=attempts+1
 check(reason=="construction-clear-ghost-footprint-0338",
  "transient test observed an unrelated construction movement")
 return attempts>1
end
local enter_clear=Construction.service_pair(pair,"new-revival-refusal")
check(enter_clear and enter_clear.waiting==1
 and task.phase=="move-clear-site" and revives==1,
 "transient denial test failed to enter existing ghost clearance route")
local transient=Construction.service_pair(pair,"first-clearance-route-denied")
check(transient and transient.waiting==1 and transient.blocked==1
 and task.phase=="move-clear-site"
 and pair.construction_task_0338==task
 and task.carried.count==1 and pair.construction_custody_0338
 and pair.construction_custody_0338.count==1 and attempts==1,
 "single transient movement refusal discarded physically acquired machine")
game.tick=game.tick+30
local retried=Construction.service_pair(pair,"clearance-route-retry")
check(retried and retried.waiting==1
 and task.phase=="move-clear-site" and attempts==2
 and task.carried.count==1,
 "transient movement refusal did not resume same owned construction task")
priest.position={x=7.25,y=0.5}
game.tick=game.tick+30
local eventual=Construction.service_pair(pair,"revive-after-transient-denial")
check(eventual and eventual.acted==1 and revives==2
 and task.carried.count==0
 and not pair.construction_task_0338
 and not pair.construction_custody_0338,
 "retry did not complete real ghost revival without double-spending cargo")
print("[construction-ghost-standoff-regression] PASS scenarios=5, transient denial custody")

