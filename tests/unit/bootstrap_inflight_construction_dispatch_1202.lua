-- 1202: genuine midgame Factorio 2.0.77 Magos repeatedly timed out in
-- move-source while an automatically assigned emergency_acquire logistics
-- order took the canonical dispatcher. A previously admitted, physically
-- funded 0338 bootstrap task must be able to finish pickup/build/refund,
-- but no mere unstocked ghost or explicit foreign duty can seize priority.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=36000}
storage={tech_priests={pairs_by_station={}}}
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local force={name="player",index=1}
local surface={index=1}
local station={valid=true,unit_number=403,
 name="planetary-magos-cogitator-station",
 position={x=192,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=404,position={x=191,y=0},
 force=force,surface=surface}
local source={valid=true,unit_number=405,name="steel-chest",
 type="container",position={x=174,y=-22},force=force,surface=surface}
local count=1
local inv={valid=true,get_item_count=function(item)
 return item=="wooden-chest" and count or 0
end}
local request={item="wooden-chest",entity_name="wooden-chest",
 position={x=190,y=-3},status="ghosted"}
local task={phase="move-source",request_field="construction_bootstrap_ghost_0645",
 request_value=request,item_name="wooden-chest",entity_name="wooden-chest",
 source_entity=source,source_inv=inv,position=request.position}
local pair={station=station,priest=priest,
 construction_bootstrap_ghost_0645=request,
 construction_task_0338=task,mode="independent-emergency-operation",
 order_queue_0469={current={kind="logistics",source="emergency_acquire",
  status="active"}}}
storage.tech_priests.pairs_by_station[station.unit_number]=pair
local recommendations=0
_G.TechPriestsConstructionPlanner0338={recommend_action=function(p)
 assert(p==pair)
 recommendations=recommendations+1
 if task.phase=="move-source" and count<1 then return nil end
 return {kind="construction",family="construction",
  position=task.position,phase=task.phase,item=task.item_name,
  source="construction-planner-0338",active=true}
end}
local function expect(kind,why)
 local a=Arbiter.action(pair)
 assert(a.kind==kind,why..": "..tostring(a.kind))
 return a
end
local old_order=pair.order_queue_0469.current
local a=expect("construction",
 "stocked, admitted bootstrap builder was starved by routine emergency logistics")
assert(a.phase=="move-source" and task.phase=="move-source"
 and count==1 and pair.order_queue_0469.current==old_order
 and pair.construction_task_0338==task,
 "arbiter fabricated stock, changed task or cancelled queued duty")
count=0
expect("acquisition","an empty source stole an auto emergency acquisition")
count=1
task.source_entity={valid=true,unit_number=406,name="steel-chest",
 type="container",position=source.position,force={name="enemy"},surface=surface}
expect("acquisition","foreign stocked chest stole construction priority")
task.source_entity=source
pair.direct_acquisition_custody_0513={item_name="iron-ore",count=1}
expect("acquisition","real mining custody preempted by old bootstrap")
pair.direct_acquisition_custody_0513=nil
pair.machine_logistics_custody_0528={item_name="iron-plate",count=1}
expect("acquisition","machine cargo was preempted")
pair.machine_logistics_custody_0528=nil
pair.direct_acquisition_task_0336={kind="direct-mine-0336"}
expect("acquisition","live physical direct acquisition was preempted")
pair.direct_acquisition_task_0336=nil
pair.order_queue_0469.current={kind="acquisition",source="user",status="active"}
expect("acquisition","explicit acquisition order was preempted")
pair.order_queue_0469.current={kind="combat",source="user",status="active"}
expect("combat","combat order was preempted")
pair.order_queue_0469.current=old_order
task.phase="move-site"
task.carried={item_name=task.item_name,count=1}
pair.construction_custody_0338={item_name=task.item_name,count=1}
count=0
expect("construction","already-debited machine could not reach its build site")
pair.construction_bootstrap_ghost_0645=nil
task.phase="return-custody"
expect("construction","held item could not return to original chest after obsolete ghost")
pair.construction_custody_0338.count=2
expect("acquisition","mismatched cargo count forged priority over routine logistics")
pair.construction_custody_0338.count=1
pair.station_cargo_custody_0824={item_name="coal",count=1}
expect("acquisition","foreign station cargo was preempted by bootstrap")
pair.station_cargo_custody_0824=nil
expect("construction","verified original carried item could not resume refund")
assert(pair.order_queue_0469.current==old_order
 and task.carried.count==1,
 "classification illegally changed physical custody or queue")
print("[bootstrap-inflight-construction-dispatch-1202] PASS physically funded moving/held bootstrap without foreign cargo preemption")
