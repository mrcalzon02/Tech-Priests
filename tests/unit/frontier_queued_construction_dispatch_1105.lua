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
print("[frontier-queued-construction-dispatch-1105] PASS funded exact 1076 candidate cuts routine order starvation without stealing cargo or explicit authority")
