-- Native 7419f997: a physical roboport was stocked and its exact 0338
-- candidate existed, but a generic logistics order was always acquisition.
-- This read-only arbiter must dispatch only that verified funded frontier
-- without preempting hostile combat, explicit work or existing cargo.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Arbiter=require("scripts.core.action_state_arbiter_0488")
game={tick=35640}
storage={tech_priests={}}
local force={name="player",index=1}
local surface={index=1}
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=913,force=force,surface=surface,position={x=0,y=0}}
local priest={valid=true,unit_number=921,force=force,surface=surface,
  position={x=32,y=0}}
local request={item_name="roboport",entity_name="roboport",
  frontier_root_unit_1076=station.unit_number,
  site_reason="powered-roboport-frontier-1076",
  position={x=38,y=0}}
local candidate={item_name=request.item_name,entity_name=request.entity_name,
  site_reason=request.site_reason,position={x=38,y=0},
  request_field="construction_request",request_value=request}
local pair={station=station,priest=priest,construction_request=request,
  construction_candidate_0338=candidate,mode="idle",
  order_queue_0469={current={kind="logistics",status="active"}}}
local real_stock=1
local recommendation_calls=0
_G.TechPriestsConstructionPlanner0338={
  recommend_action=function(p)
    assert(p==pair)
    recommendation_calls=recommendation_calls+1
    -- The production 0338 source observer refuses absent physical stock.
    if real_stock<1 then return nil end
    return {kind="construction",position=candidate.position,
      item="roboport",source="construction-planner-0338",active=false}
  end}
local function expect(kind,why)
  local a=Arbiter.action(pair)
  assert(a.kind==kind,why..": "..tostring(a.kind))
  return a
end
local adopted=expect("construction",
  "queued funded physical roboport was starved by generic logistics")
assert(adopted.position==candidate.position and recommendation_calls==1,
  "read-only arbiter lost the exact requested 0338 site")
assert(pair.order_queue_0469.current.kind=="logistics"
  and pair.construction_request==request
  and pair.construction_candidate_0338==candidate
  and not pair.construction_task_0338
  and not pair.construction_custody_0338,
  "arbiter fabricated a task, cargo, order cancellation or item")
real_stock=0
expect("acquisition","unfunded candidate took the sole builder")
real_stock=1
pair.direct_acquisition_custody_0513={item_name="iron-ore",count=1}
expect("acquisition","already mined ore was preempted")
pair.direct_acquisition_custody_0513=nil
pair.machine_logistics_custody_0528={item_name="iron-plate",count=1}
expect("acquisition","machine physical custody was preempted")
pair.machine_logistics_custody_0528=nil
pair.inventory_transfer_custody_0687={item_name="coal",count=1}
expect("acquisition","physical inventory transfer was preempted")
pair.inventory_transfer_custody_0687=nil
pair.defense_task_0259={position={x=4,y=0}}
expect("acquisition","active perimeter defense was preempted")
pair.defense_task_0259=nil
pair.emergency_craft={strict_recipe_0647=true}
expect("acquisition","strict recipe was preempted by frontier")
pair.emergency_craft=nil
pair.order_queue_0469.current={kind="combat",status="active"}
expect("combat","explicit combat order was stolen by queued frontier")
pair.order_queue_0469.current={kind="repair",status="active"}
expect("repair","explicit repair order was stolen by queued frontier")
pair.order_queue_0469.current={kind="acquisition",status="active"}
expect("acquisition","explicit acquisition order was stolen by queued frontier")
pair.order_queue_0469.current={kind="logistics",status="active"}
request.frontier_root_unit_1076=999
expect("acquisition","foreign frontier root took builder")
request.frontier_root_unit_1076=station.unit_number
request.site_reason="unrelated-construction"
expect("acquisition","foreign construction request took builder")
request.site_reason="powered-roboport-frontier-1076"
candidate.request_value={}
expect("acquisition","stale candidate identity took builder")
candidate.request_value=request
candidate.position={x=99,y=0}
expect("acquisition","mismatched physical site took builder")
candidate.position=request.position
expect("construction","restored exact funded frontier did not resume")
-- Native 41590979173: 1076 submitted an actual Senior->Intermediate
-- robot-network request after two counted ports, but 0488 kept choosing
-- routine acquisition for >15k ticks. Classify only an EXACT 1076-ranked
-- request ahead of generic logistics; the real 0338 executor still owns
-- all network/item/robot/ghost preflights and may refuse zero supply.
local magos={station=station,priest=priest}
local senior_station={valid=true,name="senior-cogitator-station",
  unit_number=933,force=force,surface=surface,position={x=42,y=0}}
local senior_priest={valid=true,unit_number=934,force=force,surface=surface,
  position={x=60,y=0}}
local robot_request={root_station_unit=933,
  frontier_root_unit_1076=913,frontier_builder_unit_1076=933,
  item_name="intermediate-cogitator-station",
  entity_name="intermediate-cogitator-station",
  site_reason="ranked-robot-remote-frontier-1076",
  position={x=64,y=0}}
local senior={station=senior_station,priest=senior_priest,
  robot_network_request_0338=robot_request,
  mode="direct-acquisition-working",
  order_queue_0469={current={kind="logistics",status="active"}}}
local goal={remote_station_item_1076="intermediate-cogitator-station",
  remote_station_position_1076={x=64,y=0}}
local frontier={status="complete",
  remote_station_request_1076=robot_request,
  remote_station_builder_1076=933}
magos.roboport_expansion_goal_1076=goal
magos.roboport_frontier_1076=frontier
storage.tech_priests.pairs_by_station={[913]=magos,[933]=senior}
local direct=true
_G.TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p==magos and 4 or p==senior and 3 or 0 end,
  is_direct_subordinate=function(a,b)
    return direct and a==magos and b==senior
  end}
local source_available=true
local dispatch_calls=0
_G.TechPriestsConstructionPlanner0338.recommend_action=function(p)
  assert(p==senior, "robot delegation invoked foreign physical builder")
  dispatch_calls=dispatch_calls+1
  if not source_available then return nil end
  if p.robot_network_task_0338
    and p.robot_network_task_0338.ghost
    and p.robot_network_task_0338.ghost.valid then return nil end
  return {kind="construction",position=robot_request.position,
    item=robot_request.item_name,source="construction-planner-0338"}
end
local function senior_action(expected,why)
  local result=Arbiter.action(senior)
  assert(result.kind==expected,
    why..": expected "..expected.." got "..tostring(result.kind))
  return result
end
local first=senior_action("construction",
  "funded ranked robot outpost was starved by routine logistics")
assert(first.position==robot_request.position and dispatch_calls==1
  and senior.robot_network_request_0338==robot_request
  and senior.order_queue_0469.current.kind=="logistics"
  and senior.robot_network_task_0338==nil,
  "read-only arbiter mutated ghost, request, order, task or inventory")
source_available=false
senior_action("acquisition","unavailable physical robot source preempted logistics")
source_available=true
senior.direct_acquisition_custody_0513={item_name="iron-ore",count=1}
senior_action("acquisition","actual mined ore was displaced by robot request")
senior.direct_acquisition_custody_0513=nil
senior.station_cargo_custody_0824={item_name="coal",count=1}
senior_action("acquisition","station cargo was displaced by robot request")
senior.station_cargo_custody_0824=nil
senior.construction_custody_0338={item_name="roboport",count=1}
senior_action("acquisition","physically carried 0338 cargo was displaced")
senior.construction_custody_0338=nil
senior.emergency_craft={strict_recipe_0647=true}
senior_action("acquisition","strict craft was displaced by robot request")
senior.emergency_craft=nil
senior.defense_task_0259={position={x=3,y=0}}
senior_action("acquisition","actual defensive work was displaced")
senior.defense_task_0259=nil
senior.order_queue_0469.current.kind="combat"
senior_action("combat","explicit combat was displaced")
senior.order_queue_0469.current.kind="repair"
senior_action("repair","explicit repair was displaced")
senior.order_queue_0469.current.kind="acquisition"
senior_action("acquisition","explicit acquisition was displaced")
senior.order_queue_0469.current.kind="logistics"
direct=false
senior_action("acquisition","revoked Magos-to-Senior edge was accepted")
direct=true
frontier.remote_station_request_1076={}
senior_action("acquisition","stale request identity was accepted")
frontier.remote_station_request_1076=robot_request
robot_request.frontier_root_unit_1076=999
senior_action("acquisition","foreign Magos origin was accepted")
robot_request.frontier_root_unit_1076=913
robot_request.frontier_builder_unit_1076=999
senior_action("acquisition","foreign Senior builder was accepted")
robot_request.frontier_builder_unit_1076=933
goal.remote_station_position_1076.x=99
senior_action("acquisition","changed remote site was accepted")
goal.remote_station_position_1076.x=64
senior.robot_network_task_0338={request_value=robot_request,
  ghost={valid=true}}
senior_action("acquisition","live native ghost monopolized priest dispatcher")
senior.robot_network_task_0338.ghost.valid=false
senior_action("construction","consumed native ghost lost 0338 receipt dispatch")
senior.robot_network_task_0338=nil
senior_action("construction","exact eligible ranked request did not resume")
-- Native 41621389634: the original Senior's stocked, already-started
-- 0338 pole pickup lost dispatch to an automatically assigned 0285
-- acquisition until its movement timed out. A queue-owned automatic
-- assignment may yield temporarily; no physical cargo or foreign order
-- may be stolen, and no queue/task/source is mutated by classification.
local senior_pole_request={
  item_name="medium-electric-pole",entity_name="medium-electric-pole",
  site_reason="powered-roboport-frontier-1076",
  frontier_root_unit_1076=913,frontier_builder_unit_1076=933,
  position={x=50,y=0}}
local source_entity={valid=true,surface=surface,force=force}
local physical_poles=1
local source_inv={valid=true,get_item_count=function(_,item)
  return item=="medium-electric-pole" and physical_poles or 0
end}
local move_source_task={
  phase="move-source",site_reason="powered-roboport-frontier-1076",
  request_field="construction_request",request_value=senior_pole_request,
  item_name="medium-electric-pole",source_entity=source_entity,
  source_inv=source_inv}
senior.construction_request=senior_pole_request
senior.construction_task_0338=move_source_task
senior.robot_network_request_0338=nil
senior.order_queue_0469.current={
  kind="assignment",source="assign_task",status="active"}
_G.TechPriestsConstructionPlanner0338.recommend_action=function(p)
  assert(p==senior)
  if physical_poles<1 or not source_inv.valid then return nil end
  return {kind="construction",item="medium-electric-pole",
    position=senior_pole_request.position,
    source="construction-planner-0338",active=true}
end
senior_action("construction","stocked 0338 source was starved by automatic assignment")
assert(senior.construction_task_0338==move_source_task
  and senior.construction_request==senior_pole_request
  and senior.order_queue_0469.current.kind=="assignment"
  and physical_poles==1 and not senior.construction_custody_0338,
  "arbiter mutated original assignment, source, task or physical inventory")
senior.order_queue_0469.current.source="adopt-active"
senior_action("construction","legacy adopted automatic assignment starved source")
local function reject_source_override(why)
  assert(Arbiter.action(senior).kind~="construction",why)
end
senior.order_queue_0469.current.source="explicit-user-acquisition"
reject_source_override("foreign explicit assignment lost priority")
senior.order_queue_0469.current.source="assign_task"
physical_poles=0
reject_source_override("missing physical pole gained priority")
physical_poles=1
source_inv.valid=false
reject_source_override("invalid physical inventory gained priority")
source_inv.valid=true
senior.direct_acquisition_custody_0513={item_name="iron-ore",count=1}
reject_source_override("real mined ore was preempted by frontier")
senior.direct_acquisition_custody_0513=nil
senior.machine_logistics_custody_0528={item_name="iron-plate",count=1}
reject_source_override("machine output custody was preempted")
senior.machine_logistics_custody_0528=nil
senior.order_queue_0469.current.kind="combat"
senior_action("combat","combat assignment was preempted")
senior.order_queue_0469.current.kind="repair"
senior_action("repair","repair assignment was preempted")
senior.order_queue_0469.current.kind="acquisition"
senior_action("acquisition","explicit acquisition was preempted")
senior.order_queue_0469.current.kind="assignment"
direct=false
reject_source_override("revoked Magos-Senior rank link was bypassed")
direct=true
move_source_task.request_value={}
reject_source_override("stale 0338 request was admitted")
move_source_task.request_value=senior_pole_request
senior_action("construction","restored physical request did not resume")
print("[frontier-queued-construction-dispatch-1105] PASS ranked auto-assignment yields only to original funded 0338 move-source; cargo, rank, source and explicit-order negatives retained")
