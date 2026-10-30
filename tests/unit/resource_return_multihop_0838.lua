-- Source fixture: counted natural ore across three distinct physical hops.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local old_chain=package.loaded["scripts.core.resource_station_chain_0820"]
local route={103,102,101,100}
package.loaded["scripts.core.resource_station_chain_0820"]={
  return_route=function() return route,"verified-physical-upstream-route" end,
}
package.loaded["scripts.core.resource_return_courier_0837"]=nil
local Courier
local function inventory(n,capacity)
  local inv={valid=true,items={["iron-ore"]=n or 0},capacity=capacity or 100}
  function inv.get_item_count(name)
    if name then return inv.items[name] or 0 end
    local total=0
    for _,count in pairs(inv.items) do total=total+count end
    return total
  end
  function inv.get_insertable_count() return inv.capacity-inv.get_item_count() end
  function inv.insert(stack)
    local amount=math.min(stack.count,inv.get_insertable_count())
    inv.items[stack.name]=(inv.items[stack.name] or 0)+amount
    return amount
  end
  function inv.remove(stack)
    local amount=math.min(stack.count,inv.get_item_count(stack.name))
    inv.items[stack.name]=inv.get_item_count(stack.name)-amount
    return amount
  end
  function inv.destroy()
    assert(inv.get_item_count()==0,"nonempty engine inventory destroyed")
    inv.valid=false
  end
  return inv
end
local force={index=1}
local surface={index=1}
local function station(id,x)
  return {station={valid=true,unit_number=id,position={x=x,y=0},
      force=force,surface=surface},
    priest={valid=true,unit_number=id+1000,position={x=x,y=0},
      force=force,surface=surface},
    radius=30}
end
local magos=station(100,0)
local senior=station(101,30)
local intermediate=station(102,60)
local terminal=station(103,90)
for _,p in ipairs({senior,intermediate,terminal}) do
  p.remote_resource_assignment_0820={root_station_unit=100}
end
local invs={[100]=inventory(0),[101]=inventory(0),[102]=inventory(0,0)}
_G.get_station_inventory=function(s) return invs[s.unit_number] end
local ore={valid=true,unit_number=900,type="resource",name="iron-ore",
  amount=8,position={x=94,y=0},surface=surface,
  prototype={mineable_properties={products={{type="item",name="iron-ore",amount=1}}}}}
local mines=0
function ore.mine(args)
  assert(args.inventory and args.force==nil)
  mines=mines+1
  ore.amount=ore.amount-1
  assert(args.inventory.insert{name="iron-ore",count=1}==1)
  return true
end
_G.TechPriestsScanRouting0610={find_entities=function(s,f)
  assert(s==surface and f.name=="iron-ore" and f.type=="resource")
  return {ore}
end}
local commands={}
_G.issue_priest_command=function()
  error("0838 courier must use canonical movement controller")
end
package.loaded["scripts.core.movement_controller"]={
  request=function(worker,pos,reason,opts)
    assert(worker and worker.priest and pos and
      opts.owner=="resource-return-courier-0953" and opts.priority==72
      and opts.bounds_exempt==true and
      (reason=="resource-return-upstream-delivery-0953"
        or reason=="resource-return-upstream-pickup-0953"))
    commands[#commands+1]={priest=worker.priest,cmd={destination=pos}}
    return true,"accepted-by-canonical-controller"
  end,
  request_status=function(worker)
    local req=worker.movement_request_0418
    if req and req.expires_tick>=game.tick then
      return {active=true,status="moving",owner=req.owner}
    end
    return {active=false,status=req and "expired" or "missing-request"}
  end,
}
-- Resolve the canonical movement mock during module parsing, as Factorio requires.
Courier=require("scripts.core.resource_return_courier_0837")
_G.defines={command={go_to_location=1},distraction={none=0}}
_G.prototypes={item={["iron-ore"]={}}}
_G.game={tick=100,create_inventory=function() return inventory(0) end}
local mission={status="reached-resource",root_station_unit=100,
  current_station_unit=103,target={x=94,y=0},
  resource_name="iron-ore",need="iron-ore"}
magos.resource_expansion_0259={chain_0820=mission}
_G.storage={tech_priests={pairs_by_station={
  [100]=magos,[101]=senior,[102]=intermediate,[103]=terminal}}}
local function step(t) game.tick=t; return Courier.service(magos) end
local ok,reason=step(100)
assert(ok and reason=="physical-ore-mined" and ore.amount==7 and mines==1)
local state=mission.return_courier_0837
assert(Courier.worker_reserved(terminal)
  and state.inventory.get_item_count("iron-ore")==1)
ok,reason=step(161)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[102].get_item_count("iron-ore")==0)
terminal.priest.position={x=61,y=0}
ok,reason=step(222)
assert(not ok and reason=="upstream-inventory-full"
  and state.inventory.get_item_count("iron-ore")==1)
invs[102].capacity=100
ok,reason=step(283)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[102].get_item_count("iron-ore")==1
  and invs[101].get_item_count("iron-ore")==0
  and invs[100].get_item_count("iron-ore")==0
  and not Courier.worker_reserved(terminal))
assert(Courier.reserved_at_station(intermediate,"iron-ore")==1
  and Courier.spendable_station_item(intermediate,"iron-ore",1)==0
  and Courier.reserved_at_station(senior,"iron-ore")==0,
  "counted relay receipt not reserved from unrelated station spending")
for id,p in pairs(storage.tech_priests.pairs_by_station) do
  p.station.get_inventory=function() return invs[id] end
end
surface.find_entities_filtered=function() return {} end
defines.inventory={chest=1}
local StorageAuthority=require("scripts.core.storage_role_authority_0686")
assert(StorageAuthority.remove_generic_item(intermediate,"iron-ore",1)==0
  and invs[102].get_item_count("iron-ore")==1,
  "generic storage stole physically deposited relay ore")
invs[102].insert{name="iron-ore",count=2}
assert(StorageAuthority.remove_generic_item(intermediate,"iron-ore",3)==2
  and invs[102].get_item_count("iron-ore")==1,
  "generic storage failed to preserve exactly one item, not all excess")
local Fetch0526=require("scripts.core.logistics_fetch_executor_0526")
local Fetch0527=require("scripts.core.logistics_fetch_executor_0527")
assert(Fetch0526.spendable_source_count(intermediate.station,"iron-ore",1)==0
  and Fetch0527.spendable_source_count(intermediate.station,"iron-ore",1)==0
  and Fetch0527.spendable_source_count(intermediate.station,"iron-ore",3)==2
  and Fetch0526.spendable_source_count(senior.station,"iron-ore",2)==2
  and Fetch0527.spendable_source_count({valid=true,unit_number=9999},"iron-ore",2)==2,
  "known-source logistics could steal counted relay ore")
intermediate.active_task={kind="existing-task"}
ok,reason=step(344)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and invs[102].get_item_count("iron-ore")==1
  and state.phase=="first-hop-delivered"
  and state.pending_upstream_station_unit==102
  and state.pending_upstream_priest_unit==1102
  and Courier.worker_reserved(intermediate)
  and intermediate.active_task.kind=="existing-task"
  and state.inventory==nil,
  "busy upstream priest was preempted or left open to new assignments")
local prior_commands=#commands
ok,reason=step(345)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and #commands==prior_commands
  and invs[102].get_item_count("iron-ore")==1,
  "waiting upstream reservation moved priest or remotely debited ore")
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.worker_reserved(intermediate)
  and state.pending_upstream_station_unit==102,
  "reload lost upstream future-work reservation")
intermediate.active_task=nil
-- Actual Factorio 2.0.77 reload stalled with mode=assignment,
-- recipe_missing=stone, no active task/custody, and a reserved real ore item.
-- A dormant 0647 request may yield only for this exact physical receipt.
intermediate.mode="assignment"
local deferred_recipe={item="tech-priests-emergency-smelter",missing="stone"}
intermediate.infrastructure_recipe_request_0647=deferred_recipe
intermediate.priest.position={x=68,y=0}
local assignment_commands=#commands
intermediate.combat_target={valid=true}
ok,reason=step(405)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and state.phase=="first-hop-delivered",
  "a combat assignment was incorrectly treated as idle")
intermediate.combat_target=nil
intermediate.order_queue_0469={current={status="active"}}
ok,reason=step(405)
assert(not ok and reason=="upstream-priest-has-existing-duty",
  "an active order was preempted by the physical ore reservation")
intermediate.order_queue_0469=nil
-- 0975: Engine's baseline four-station relay can retain mode=assignment
-- after direct work ends. An actual 0469 material order may yield only
-- through its own authority and an exact counted station-inventory receipt.
do
  local saved={}
  for k,v in pairs(state) do saved[k]=v end
  local OrderQueue=require("scripts.core.order_queue_0469")
  local order={key="assignment-stone-0975",kind="logistics",
    source="doctrine_handle_no_source",item="stone",status="active",
    expires_tick=game.tick+7200}
  intermediate.order_queue_0469={current=order,pending={},history={},stats={}}
  intermediate.active_order_0469=order
  intermediate.active_task_0285={kind="live-0285-task"}
  ok,reason=step(405)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="live-duty:active_task_0285"
    and order.status=="active" and invs[102].get_item_count("iron-ore")==1,
    "assignment relay preempted a live 0285 task")
  intermediate.active_task_0285=nil
  order.source="assign_task"
  ok,reason=step(405)
  assert(not ok and state.last_upstream_handoff_reason
      =="active-order:order-source-not-material" and order.status=="active",
    "assignment relay preempted a foreign 0469 order")
  order.source="doctrine_handle_no_source"
  order.item="copper-ore"
  ok,reason=step(405)
  assert(not ok and state.last_upstream_handoff_reason
      =="active-order:order-item-mismatch" and order.status=="active",
    "assignment relay preempted a foreign ingredient")
  order.item="stone"
  order.status="paused"
  order.pause_reason="missing-priest"
  ok,reason=step(405)
  assert(not ok and state.last_upstream_handoff_reason
      =="active-order:order-not-active",
    "assignment relay preempted another owner's paused order")
  order.status="active"
  order.pause_reason=nil
  ok,reason=step(405)
  assert(ok and reason=="next-physical-upstream-hop-reserved"
    and state.source_station_unit==102
    and state.destination_station_unit==101
    and state.inventory==nil and order.status=="paused"
    and order.pause_reason=="physical-ore-relay-0974"
    and intermediate.infrastructure_recipe_request_0647==deferred_recipe
    and invs[102].get_item_count("iron-ore")==1
    and #commands==assignment_commands,
    "counted assignment material order did not yield without remote debit")
  package.loaded["scripts.core.order_queue_0469"]=nil
  local ReloadedQueue=require("scripts.core.order_queue_0469")
  assert(ReloadedQueue.tick_pair(intermediate,"after-reload")==false
    and order.status=="paused" and invs[102].get_item_count("iron-ore")==1,
    "assignment order pause did not survive module reload")
  local resumed,why=ReloadedQueue.resume_after_resource_relay_0974(intermediate)
  assert(resumed and why=="relay-resumed"
    and order.status=="active"
    and intermediate.active_order_0469==order
    and intermediate.infrastructure_recipe_request_0647==deferred_recipe,
    "original assignment order did not resume intact")
  intermediate.order_queue_0469=nil
  intermediate.active_order_0469=nil
  for k in pairs(state) do state[k]=nil end
  for k,v in pairs(saved) do state[k]=v end
end
-- 0977: actual Factorio 2.0.77 retained an adopted 0285 iron-plate
-- assignment while the 0647 smelter recipe awaited stone. These outputs
-- differ legitimately. Only the queue-owned exact dormant assignment can
-- be losslessly yielded for the counted physical ore receipt.
do
  local saved={}
  for k,v in pairs(state) do saved[k]=v end
  local task={type="assignment",kind="assignment",
    item="iron-plate",owner_system="legacy-task-0276"}
  local order={key="adopted-assignment-0976",kind="assignment",
    source="adopt-active",item=task.item,task=task,
    status="active",expires_tick=game.tick+7200}
  intermediate.mode="assignment"
  intermediate.active_task=nil
  intermediate.active_task_0285=task
  intermediate.order_queue_0469={current=order,pending={},history={},stats={}}
  intermediate.active_order_0469=order
  intermediate.infrastructure_recipe_request_0647=deferred_recipe
  intermediate.priest.position={x=68,y=0}
  local before=#commands
  assert(task.item~=deferred_recipe.item and task.item~=deferred_recipe.missing,
    "regression must model the actual unrelated engine assignment")
  order.task={type="assignment",item=task.item}
  local ok,reason=step(406)
  assert(not ok and state.last_upstream_handoff_reason
    =="live-duty:active_task_0285" and order.status=="active",
    "unrelated 0285 assignment was incorrectly yielded")
  -- The adopted task's identity and output must be exact; a live entity
  -- target, active pair task, or foreign 0285 task cannot be displaced.
  order.task=task
  task.target={valid=true}
  ok,reason=step(407)
  assert(not ok and order.status=="active" and #commands==before,
    "0285 assignment with live entity target was preempted")
  task.target={x=10,y=0}
  ok,reason=step(407)
  assert(not ok and order.status=="active" and #commands==before,
    "0285 assignment with a coordinate target was preempted")
  task.target=nil
  intermediate.active_task={kind="physical-work"}
  ok,reason=step(408)
  assert(not ok and order.status=="active",
    "live pair task was preempted by adopted assignment yield")
  intermediate.active_task=nil
  order.task={type="assignment",item=task.item}
  ok,reason=step(409)
  assert(not ok and order.status=="active",
    "foreign 0285 task was preempted")
  order.task=task
  order.item="copper-plate"
  ok,reason=step(410)
  assert(not ok and order.status=="active",
    "mismatched adopted assignment was preempted")
  order.item=task.item
  task.item="copper-plate"
  ok,reason=step(410)
  assert(not ok and order.status=="active",
    "adopted task output mismatch was preempted")
  task.item="iron-plate"
  ok,reason=step(411)
  assert(ok and reason=="next-physical-upstream-hop-reserved"
    and order.status=="paused"
    and order.relay_paused_task_0285==task
    and intermediate.active_task_0285==nil
    and intermediate.active_order_0469==order
    and invs[102].get_item_count("iron-ore")==1
    and state.inventory==nil and #commands==before,
    "adopted 0285 material order was not losslessly paused")
  local Scheduler=require("scripts.core.task_scheduler")
  assert(Scheduler.reconcile(intermediate,"physical-ore-relay-paused")
    and intermediate.active_task_0285==nil,
    "scheduler recreated a second 0285 task during relay")
  package.loaded["scripts.core.order_queue_0469"]=nil
  local ReloadedQueue=require("scripts.core.order_queue_0469")
  assert(ReloadedQueue.tick_pair(intermediate,"relay-reload")==false
    and order.relay_paused_task_0285==task
    and invs[102].get_item_count("iron-ore")==1,
    "reload lost paused adopted 0285 assignment or ore")
  local resumed,why=ReloadedQueue.resume_after_resource_relay_0974(intermediate)
  assert(resumed and why=="relay-resumed"
    and order.status=="active" and order.task==task
    and intermediate.active_task_0285==task
    and order.relay_paused_task_0285==nil
    and intermediate.infrastructure_recipe_request_0647==deferred_recipe,
    "original adopted 0285 task was not restored intact")
  intermediate.active_task_0285=nil
  intermediate.order_queue_0469=nil
  intermediate.active_order_0469=nil
  for k in pairs(state) do state[k]=nil end
  for k,v in pairs(saved) do state[k]=v end
end
-- 0981: the engine's upstream relay may retain the SAME adopted 0318
-- assignment in both task aliases after direct acquisition stops. It must
-- remain protected until the canonical 0513 task owner, 0418 movement owner,
-- exact 0469 order and counted ore receipt all independently agree.
do
  local saved={}
  for k,v in pairs(state) do saved[k]=v end
  local previous_mode=intermediate.mode
  local task={type="assignment",kind="assignment",item="iron-plate",
    owner_system="legacy-task-0276"}
  local order={key="dual-adopted-0981",kind="assignment",
    source="adopt-active",item=task.item,task=task,status="active",
    expires_tick=game.tick+7200}
  intermediate.mode="direct-acquisition-working"
  intermediate.active_task=task
  intermediate.active_task_0285=task
  intermediate.order_queue_0469={current=order,pending={},history={},stats={}}
  intermediate.active_order_0469=order
  intermediate.infrastructure_recipe_request_0647=deferred_recipe
  intermediate.priest.position={x=68,y=0}
  local before=#commands
  task.target={x=10,y=0}
  local ok,reason=step(412)
  assert(not ok and order.status=="active" and #commands==before,
    "dual adopted assignment with live coordinate target was preempted")
  task.target=nil
  intermediate.active_task={type="assignment",item="iron-plate"}
  ok,reason=step(413)
  assert(not ok and order.status=="active" and #commands==before,
    "foreign active_task alias was preempted")
  intermediate.active_task=task
  intermediate.direct_acquisition_task_0336={kind="direct-mine-0336"}
  ok,reason=step(414)
  assert(not ok and order.status=="active" and #commands==before,
    "live direct acquisition was preempted")
  intermediate.direct_acquisition_task_0336=nil
  intermediate.movement_request_0418={
    owner="direct-acquisition-0513",expires_tick=game.tick+500}
  ok,reason=step(415)
  assert(not ok and order.status=="active" and #commands==before,
    "live canonical movement was preempted")
  intermediate.movement_request_0418=nil
  ok,reason=step(416)
  assert(ok and reason=="next-physical-upstream-hop-reserved"
    and order.status=="paused"
    and order.relay_paused_task_0285==task
    and order.relay_paused_task_active==task
    and intermediate.active_task==nil
    and intermediate.active_task_0285==nil
    and state.inventory==nil
    and invs[102].get_item_count("iron-ore")==1
    and #commands==before,
    "exact dual-slot adopted assignment was not safely suspended")
  local Scheduler=require("scripts.core.task_scheduler")
  assert(Scheduler.reconcile(intermediate,"dual-slot-ore-relay-0981")
    and intermediate.active_task==nil
    and intermediate.active_task_0285==nil,
    "scheduler recreated a suspended adopted assignment")
  package.loaded["scripts.core.order_queue_0469"]=nil
  local ReloadedQueue=require("scripts.core.order_queue_0469")
  assert(ReloadedQueue.tick_pair(intermediate,"dual-slot-reload")==false
    and order.relay_paused_task_active==task
    and invs[102].get_item_count("iron-ore")==1,
    "reload lost dual-slot assignment or physical ore")
  intermediate.active_task={type="foreign",item="copper-plate"}
  local resumed,why=ReloadedQueue.resume_after_resource_relay_0974(intermediate)
  assert(not resumed and why=="relay-task-identity-changed"
    and order.status=="paused",
    "foreign task was overwritten during relay resumption")
  intermediate.active_task=nil
  resumed,why=ReloadedQueue.resume_after_resource_relay_0974(intermediate)
  assert(resumed and why=="relay-resumed" and order.status=="active"
    and intermediate.active_task==task
    and intermediate.active_task_0285==task
    and order.relay_paused_task_active==nil
    and order.relay_paused_task_0285==nil
    and intermediate.infrastructure_recipe_request_0647==deferred_recipe,
    "original dual-slot task aliases were not restored after delivery")
  intermediate.active_task=nil
  intermediate.active_task_0285=nil
  intermediate.order_queue_0469=nil
  intermediate.active_order_0469=nil
  intermediate.mode=previous_mode
  for k in pairs(state) do state[k]=nil end
  for k,v in pairs(saved) do state[k]=v end
end
local receipt_hop=state.receipt_hop
state.receipt_hop=nil
ok,reason=step(405)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and state.phase=="first-hop-delivered",
  "an incomplete physical delivery receipt authorized pickup")
state.receipt_hop=receipt_hop
intermediate.infrastructure_recipe_request_0647=nil
ok,reason=step(405)
assert(not ok and reason=="upstream-priest-has-existing-duty",
  "unattributed assignment mode was treated as an idle priest")
intermediate.infrastructure_recipe_request_0647=deferred_recipe
invs[102].remove{name="iron-ore",count=1}
ok,reason=step(405)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and state.phase=="first-hop-delivered" and state.inventory==nil,
  "a receipt without real ore bypassed station inventory custody")
assert(invs[102].insert{name="iron-ore",count=1}==1)
ok,reason=step(405)
assert(ok and reason=="next-physical-upstream-hop-reserved"
  and state.source_station_unit==102 and state.destination_station_unit==101
  and state.pending_upstream_station_unit==nil
  and state.pending_upstream_priest_unit==nil
  and Courier.worker_reserved(intermediate)
  and intermediate.mode=="assignment"
  and intermediate.infrastructure_recipe_request_0647==deferred_recipe
  and invs[102].get_item_count("iron-ore")==1
  and #commands==assignment_commands,
  "real upstream receipt did not release dormant assignment safely")
-- 0970: execute actual 0953 movement authority on an 0837 first-hop
-- receipt. The ore remains physically at this station until local pickup.
do
  -- The outer 0821 test loads the real movement controller before this
  -- fixture replaces Chain.return_route. Rebind the production authority
  -- to the fixture's explicit physical route, not that stale module cache.
  local old_authority=package.loaded["scripts.core.resource_return_movement_0953"]
  package.loaded["scripts.core.resource_return_movement_0953"]=nil
  local MovementAuthority=require("scripts.core.resource_return_movement_0953")
  local pickup_request={
    owner="resource-return-courier-0953",
    reason="resource-return-upstream-pickup-0953",
    priority=72,expires_tick=game.tick+600,
    x=intermediate.station.position.x,y=intermediate.station.position.y,
  }
  local function authorized()
    return MovementAuthority.authorized(intermediate,pickup_request)==true
  end
  assert(state.phase=="to-upstream-pickup" and state.hop_index==2
    and state.station_custody_unit==102 and state.delivered_station_unit==102
    and state.receipt_hop==1 and state.hops_completed==1
    and state.inventory==nil and invs[102].get_item_count("iron-ore")==1
    and authorized(),"real deposited ore was denied its local pickup walk")
  local custody=state.station_custody_unit
  state.station_custody_unit=nil
  assert(not authorized(),"missing physical station custody authorized movement")
  state.station_custody_unit=custody
  state.delivered_station_unit=999
  assert(not authorized(),"foreign delivery station authorized movement")
  state.delivered_station_unit=102
  state.receipt_hop=nil
  assert(not authorized(),"missing counted prior-hop receipt authorized movement")
  state.receipt_hop=1
  state.quantity=2
  assert(not authorized(),"ambiguous quantity authorized physical movement")
  state.quantity=1
  invs[102].remove{name="iron-ore",count=1}
  assert(not authorized(),"missing real station ore authorized movement")
  assert(invs[102].insert{name="iron-ore",count=1}==1)
  intermediate.active_task={kind="existing-duty"}
  assert(not authorized(),"active duty was preempted for ore pickup")
  intermediate.active_task=nil
  pickup_request.x=0
  assert(not authorized(),"foreign movement destination was authorized")
  pickup_request.x=intermediate.station.position.x
  assert(authorized(),"valid local movement did not recover after refusals")
  package.loaded["scripts.core.resource_return_movement_0953"]=nil
  MovementAuthority=require("scripts.core.resource_return_movement_0953")
  assert(authorized() and invs[102].get_item_count("iron-ore")==1
    and state.inventory==nil,
    "module reload lost real station receipt or moved inventory")
  package.loaded["scripts.core.resource_return_movement_0953"]=old_authority
end
ok,reason=step(466)
assert(not ok and reason=="walking-to-upstream-pickup"
  and #commands==assignment_commands+1
  and invs[102].get_item_count("iron-ore")==1
  and state.inventory==nil,
  "deferred assignment remotely debited ore instead of walking home")
intermediate.priest.position={x=60,y=0}
ok,reason=step(527)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[102].get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1
  and Courier.reserved_at_station(intermediate,"iron-ore")==0)
ok,reason=step(588)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[101].get_item_count("iron-ore")==0)
intermediate.priest.position={x=31,y=0}
ok,reason=step(649)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[101].get_item_count("iron-ore")==1
  and Courier.reserved_at_station(senior,"iron-ore")==1
  and not Courier.worker_reserved(intermediate))
-- 0972: the real Senior relay was stranded in a stale 0513 travel mode,
-- with an uncommitted smelter/stone request but no live task or movement.
-- Exercise the production 0513 task owner and a counted, physically deposited
-- ore receipt. This exploratory reservation is rolled back in the fixture
-- BEFORE any inventory debit, preserving the existing returning-mode test.
do
  local saved={}
  for k,v in pairs(state) do saved[k]=v end
  senior.mode="travelling-to-direct-acquisition"
  senior.priest.position={x=38,y=0}
  local recipe={item="tech-priests-emergency-smelter",missing="stone"}
  senior.infrastructure_recipe_request_0647=recipe
  local commands_before=#commands
  senior.movement_request_0418={
    owner="direct-acquisition-0513",expires_tick=game.tick+500}
  local eligible,why=Courier.probe_dormant_direct_relay_0973(senior)
  assert(not eligible and why=="canonical-movement:moving",
    "canonical movement owner refusal was not identified")
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="canonical-movement:moving"
    and #commands==commands_before and invs[101].get_item_count("iron-ore")==1,
    "active direct-acquisition movement was preempted")
  senior.movement_request_0418=nil
  senior.direct_acquisition_task_0336={kind="direct-mine-0336"}
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="live-duty:direct_acquisition_task_0336",
    "live 0513 extraction task was mistaken for a stale travel label")
  senior.direct_acquisition_task_0336=nil
  senior.requested_item="copper-ore"
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="foreign-ingredient-request",
    "foreign ingredient request was overridden")
  senior.requested_item=nil
  senior.infrastructure_recipe_request_0647=nil
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="missing-uncommitted-0647-request",
    "unowned stale travel label authorized ore pickup")
  senior.infrastructure_recipe_request_0647=recipe
  local prior_receipt=state.receipt_hop
  state.receipt_hop=nil
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="upstream-priest-has-existing-duty",
    "stale direct mode bypassed the actual counted relay receipt")
  state.receipt_hop=prior_receipt
  senior.direct_acquisition_expedition_0513={
    authorized=true,expires_tick=game.tick+300}
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="active-direct-expedition",
    "live direct-acquisition expedition was overridden")
  senior.direct_acquisition_expedition_0513=nil
  -- 0974: the real Senior's 0469 order remains active after its 0513
  -- physical task ended. A foreign or live order must not be preempted.
  local OrderQueue=require("scripts.core.order_queue_0469")
  local order={key="stone-planning-0974",kind="logistics",
    source="assign_task",item="stone",status="active",
    expires_tick=game.tick+7200}
  senior.order_queue_0469={current=order,pending={},history={},stats={}}
  senior.active_order_0469=order
  ok,reason=step(649)
  assert(not ok and reason=="upstream-priest-has-existing-duty"
    and state.last_upstream_handoff_reason=="active-order:order-source-not-material"
    and order.status=="active" and #commands==commands_before,
    "unrelated active order was silently bypassed")
  order.source="doctrine_handle_no_source"
  order.item="copper-ore"
  ok,reason=step(649)
  assert(not ok and state.last_upstream_handoff_reason=="active-order:order-item-mismatch"
    and order.status=="active",
    "foreign ingredient order was preempted")
  order.item="stone"
  senior.active_task_0285={kind="live-task"}
  ok,reason=step(649)
  assert(not ok and state.last_upstream_handoff_reason=="live-duty:active_task_0285"
    and order.status=="active",
    "live order task was preempted")
  senior.active_task_0285=nil
  ok,reason=step(649)
  assert(ok and reason=="next-physical-upstream-hop-reserved"
    and state.last_upstream_handoff_reason==nil
    and order.status=="paused"
    and order.pause_reason=="physical-ore-relay-0974"
    and OrderQueue.tick_pair(senior,"relay-held")==false
    and state.source_station_unit==101
    and state.destination_station_unit==100
    and senior.infrastructure_recipe_request_0647==recipe
    and invs[101].get_item_count("iron-ore")==1
    and #commands==commands_before,
    "dormant 0513 travel blocked a receipt-backed physical relay")
  ok,reason=step(650)
  assert(not ok and reason=="walking-to-upstream-pickup"
    and #commands==commands_before+1
    and invs[101].get_item_count("iron-ore")==1
    and state.inventory==nil
    and senior.infrastructure_recipe_request_0647==recipe
    and order.status=="paused",
    "stale direct mode caused remote debit or lost recipe planning")
  -- Simulate a controller reload: the same order object and real station
  -- inventory must survive without duplicate promotion or material debit.
  package.loaded["scripts.core.order_queue_0469"]=nil
  local ReloadedQueue=require("scripts.core.order_queue_0469")
  assert(ReloadedQueue.tick_pair(senior,"after-reload")==false
    and order.status=="paused" and invs[101].get_item_count("iron-ore")==1,
    "save/reload lost paused material order or physical station custody")
  -- This exploratory branch is rolled back before the independent
  -- returning-mode delivery fixture. Restore its original active order.
  local resumed,why=ReloadedQueue.resume_after_resource_relay_0974(senior)
  assert(resumed and why=="relay-resumed"
    and order.status=="active"
    and senior.active_order_0469==order
    and senior.infrastructure_recipe_request_0647==recipe,
    "material order did not resume intact after courier handoff")
  senior.order_queue_0469=nil
  senior.active_order_0469=nil
  for k in pairs(state) do state[k]=nil end
  for k,v in pairs(saved) do state[k]=v end
  senior.infrastructure_recipe_request_0647=nil
  senior.mode="idle"
end
-- A completed mining duty may leave "returning" set while the reserved
-- dispatcher withholds legacy idle transitions. Remote pickup remains denied.
senior.mode="returning"
senior.priest.position={x=38,y=0}
local prior_senior_commands=#commands
senior.movement_request_0418={owner="existing-return",expires_tick=game.tick+500}
ok,reason=step(649)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and #commands==prior_senior_commands
  and invs[101].get_item_count("iron-ore")==1
  and state.phase=="first-hop-delivered",
  "active returning movement was preempted")
senior.movement_request_0418=nil
senior.active_task={kind="legitimate-prior-duty"}
ok,reason=step(650)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and senior.active_task.kind=="legitimate-prior-duty"
  and invs[101].get_item_count("iron-ore")==1,
  "dormant return bypassed a still-active duty")
senior.active_task=nil
local saved_receipt=state.receipt_hop
state.receipt_hop=nil
ok,reason=step(650)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and invs[101].get_item_count("iron-ore")==1,
  "missing physical receipt authorized dormant return")
state.receipt_hop=saved_receipt
ok,reason=step(651)
assert(ok and reason=="next-physical-upstream-hop-reserved"
  and state.source_station_unit==101 and state.destination_station_unit==100
  and Courier.worker_reserved(senior)
  and invs[101].get_item_count("iron-ore")==1
  and #commands==prior_senior_commands,
  "dormant returning mode blocked authorized local relay walk")
ok,reason=step(710)
assert(not ok and reason=="walking-to-upstream-pickup"
  and #commands==prior_senior_commands+1
  and invs[101].get_item_count("iron-ore")==1
  and state.inventory==nil,
  "returning relay remotely debited ore before physical home arrival")
senior.priest.position={x=30,y=0}
ok,reason=step(771)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[101].get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1
  and Courier.reserved_at_station(senior,"iron-ore")==0)
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.worker_reserved(senior),"reload lost upstream carrier custody")
ok,reason=step(832)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[100].get_item_count("iron-ore")==0)
senior.priest.position={x=2,y=0}
ok,reason=step(893)
assert(ok and reason=="counted-natural-ore-received-by-magos"
  and state.phase=="magos-delivered" and state.hops_completed==3
  and mission.delivered_to_magos_count==1
  and invs[100].get_item_count("iron-ore")==1
  and mines==1 and ore.amount==7
  and not Courier.worker_reserved(senior))
local receipts=state.receipts_0982
assert(type(receipts)=="table" and #receipts==3
  and receipts[1].source_station_unit==103
  and receipts[1].destination_station_unit==102
  and receipts[1].carrier_priest_unit==terminal.priest.unit_number
  and receipts[2].source_station_unit==102
  and receipts[2].destination_station_unit==101
  and receipts[2].carrier_priest_unit==intermediate.priest.unit_number
  and receipts[3].source_station_unit==101
  and receipts[3].destination_station_unit==100
  and receipts[3].carrier_priest_unit==senior.priest.unit_number
  and receipts[1].tick<receipts[2].tick
  and receipts[2].tick<receipts[3].tick,
  "real inventory receipts did not retain every carrier and station")
assert(Courier.validate_receipts_0982(state,{103,102,101,100}),
  "valid physical relay ledger rejected")
local saved_after=receipts[2].destination_after
receipts[2].destination_after=saved_after+1
local ledger_ok,ledger_reason=Courier.validate_receipts_0982(state,{103,102,101,100})
assert(not ledger_ok and ledger_reason=="invalid-receipt:2",
  "tampered physical receipt was accepted")
ok,reason=step(954)
assert(not ok and reason=="physical-hop-receipt-ledger-invalid:invalid-receipt:2"
  and state.phase=="custody-blocked"
  and invs[100].get_item_count("iron-ore")==1
  and mission.delivered_to_magos_count==1,
  "receipt tampering permitted a duplicate or destructive transfer")
receipts[2].destination_after=saved_after
state.phase="magos-delivered"
ok,reason=step(954)
assert(not ok and reason=="natural-ore-already-delivered-to-magos"
  and mission.delivered_to_magos_count==1
  and invs[100].get_item_count("iron-ore")==1
  and mines==1,"duplicate Magos delivery")
-- Route mutation after mining quarantines the real carried inventory.
mission.return_courier_0837=nil
terminal.priest.position={x=94,y=0}
ok,reason=step(1015)
assert(ok and reason=="physical-ore-mined")
local stranded=mission.return_courier_0837
route={103,101,102,100}
ok,reason=step(1076)
assert(not ok and reason=="return-route-changed-during-custody"
  and stranded.phase=="custody-blocked"
  and stranded.inventory.get_item_count("iron-ore")==1
  and invs[100].get_item_count("iron-ore")==1
  and mission.delivered_to_magos_count==1,
  "changed route stole or fabricated physical cargo")
-- 0991: real 0528 drill-to-terminal receipts may feed the SAME physical
-- ranked courier. A receipt alone cannot create cargo or skip the terminal.
route={103,102,101,100}
mission.return_courier_0837=nil
terminal.mode="idle"
terminal.active_task=nil
terminal.active_task_0285=nil
terminal.current_task=nil
terminal.movement_request_0418=nil
terminal.priest.position={x=90,y=0}
invs[103]=inventory(2)
invs[102].capacity=100
local drill={valid=true,type="mining-drill",unit_number=700,
  force=force,surface=surface,drop_position={x=93,y=0}}
local receiver={valid=true,type="container",unit_number=701,
  force=force,surface=surface,position={x=93.5,y=0.5}}
game.get_entity_by_unit_number=function(id)
  return ({[700]=drill,[701]=receiver})[id]
end
local proof={station_unit=103,priest_unit=terminal.priest.unit_number,
  receiver_unit=701,drill_unit=700,item="iron-ore",count=2,
  source_before=2,source_after=0,pickup_tick=1000,deposit_tick=1100,
  cargo_before_0984=2,cargo_after_0984=0,
  station_before_0984=0,station_after_0984=2,
  deposit_authority="storage-role-deposit-exact-0686"}
terminal.drill_output_receipts_0983={proof}
-- 0996: reproduce the engine sequence: a natural Magos receipt is already
-- complete when fresh drill output arrives. Do not manually erase the
-- completed courier to permit a second physically counted journey.
mission.return_courier_0837=state
assert(state.phase=="magos-delivered"
  and mission.delivered_to_magos_count==1)
game.tick=1199
assert(Courier.machine_source_reserved_0992(terminal,"iron-ore")==2
  and Courier.reserved_at_station(terminal,"iron-ore")==2
  and Courier.spendable_station_item(terminal,"iron-ore",2)==0,
  "unclaimed physical drill output was left spendable before local pickup")
assert(StorageAuthority.remove_generic_item(terminal,"iron-ore",2)==0
  and invs[103].get_item_count("iron-ore")==2,
  "generic storage spent machine output reserved for ranked physical return")
invs[103].insert{name="iron-ore",count=1}
assert(StorageAuthority.remove_generic_item(terminal,"iron-ore",2)==1
  and invs[103].get_item_count("iron-ore")==2,
  "machine receipt reserved unrelated excess terminal stock")
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.machine_source_reserved_0992(terminal,"iron-ore")==2,
  "reload lost receipt-backed physical terminal stock reservation")
local selected,selected_index=Courier.drill_source_receipt_0991(terminal,mission)
assert(selected==proof and selected_index==1,
  "real connected drill receipt not accepted")
proof.source_after=1
assert(not Courier.drill_source_receipt_0991(terminal,mission),
  "forged receiver debit authorized a drill relay")
proof.source_after=0
local saved_station_before=proof.station_before_0984
proof.station_before_0984=nil
assert(not Courier.drill_source_receipt_0991(terminal,mission),
  "incomplete canonical station-deposit receipt authorized a drill relay")
proof.station_before_0984=saved_station_before
proof.relay_claimed_count_0991=0.5
assert(not Courier.drill_source_receipt_0991(terminal,mission),
  "fractional machine-output claim bypassed counted custody")
proof.relay_claimed_count_0991=nil
drill.drop_position={x=100,y=0}
assert(not Courier.drill_source_receipt_0991(terminal,mission)
  and Courier.reserved_at_station(terminal,"iron-ore")==0,
  "disconnected physical receiver authorized a drill relay or stock lease")
drill.drop_position={x=93,y=0}
-- 0993: an adjacent chest is not a drill output receiver merely because
-- it is within the old permissive two-square-unit radius. The live 0528
-- source predicate requires an actual drop target, or a nil target and
-- a drop coordinate within 0.51 squared tiles of this exact chest.
drill.drop_position={x=94.5,y=0.5}
assert(not Courier.drill_source_receipt_0991(terminal,mission)
  and Courier.machine_source_reserved_0992(terminal,"iron-ore")==0,
  "nearby but disconnected receiver falsely reserved drill output")
drill.drop_position={x=93,y=0}
local other_receiver={valid=true,type="container",unit_number=702,
  force=force,surface=surface,position={x=93.5,y=0.5}}
drill.drop_target=other_receiver
assert(not Courier.drill_source_receipt_0991(terminal,mission)
  and Courier.reserved_at_station(terminal,"iron-ore")==0,
  "drill targeting a different chest authorized machine output")
drill.drop_target=receiver
assert(Courier.drill_source_receipt_0991(terminal,mission)==proof
  and Courier.machine_source_reserved_0992(terminal,"iron-ore")==2,
  "actual connected drop target was rejected")
drill.drop_target=nil
assert(Courier.drill_source_receipt_0991(terminal,mission)==proof,
  "physically close nil-target receiver was rejected")
local mined_before_machine=mines
local prior_after=state.receipts_0982[2].destination_after
state.receipts_0982[2].destination_after=prior_after+1
ok,reason=step(1199)
assert(not ok and reason:find("completed-return-rearm-unverified:",1,true)==1
  and mission.return_courier_0837==state
  and invs[103].get_item_count("iron-ore")==2
  and (proof.relay_claimed_count_0991 or 0)==0,
  "0996 corrupted Magos ledger was silently replaced by a fresh courier")
state.receipts_0982[2].destination_after=prior_after
ok,reason=step(1200)
assert(ok and reason=="physical-upstream-item-picked-up"
  and mission.completed_return_receipts_0996
  and #mission.completed_return_receipts_0996==1
  and mission.completed_return_receipts_0996[1].source_kind_0991=="natural-ore"
  and #mission.completed_return_receipts_0996[1].receipts_0982==3
  and mission.completed_return_receipts_0996[1].receipts_0982[3].destination_station_unit==100
  and mission.return_courier_0837.source_kind_0991=="drill-output"
  and mission.return_courier_0837.inventory.get_item_count("iron-ore")==1
  and invs[103].get_item_count("iron-ore")==1
  and proof.relay_claimed_count_0991==1
  and Courier.reserved_at_station(terminal,"iron-ore")==1
  and Courier.spendable_station_item(terminal,"iron-ore",1)==0
  and mines==mined_before_machine,
  "drill ore was not physically debited or remaining machine stock exposed")
local machine_courier=mission.return_courier_0837
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(machine_courier.inventory.valid
  and proof.relay_claimed_count_0991==1,
  "module reload lost physical machine-output cargo")
ok,reason=step(1261)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[102].get_item_count("iron-ore")==0,
  "machine output remotely credited upstream station")
terminal.priest.position={x=61,y=0}
ok,reason=step(1322)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[102].get_item_count("iron-ore")==1
  and machine_courier.inventory==nil
  and machine_courier.receipts_0982[1].source_station_unit==103,
  "machine output bypassed the counted physical first hop")
-- A second mission may claim the second counted real item, never a third.
mission.return_courier_0837=nil
terminal.priest.position={x=90,y=0}
ok,reason=step(1383)
assert(ok and reason=="physical-upstream-item-picked-up"
  and proof.relay_claimed_count_0991==2
  and invs[103].get_item_count("iron-ore")==0
  and Courier.reserved_at_station(terminal,"iron-ore")==0,
  "machine output was duplicated or the second real item was stranded")
assert(not Courier.drill_source_receipt_0991(terminal,mission),
  "exhausted physical machine receipt was spendable twice")
-- 0992: Continue the second physically debited machine item through every
-- rank, not merely its first upstream station. No priest, station inventory
-- or Magos receipt may be credited without the matching carrier walk.
intermediate.mode="idle"
senior.mode="idle"
for _,worker in ipairs({intermediate,senior}) do
  worker.active_task=nil
  worker.active_task_0285=nil
  worker.current_task=nil
  worker.movement_request_0418=nil
  worker.infrastructure_recipe_request_0647=nil
  worker.order_queue_0469=nil
  worker.active_order_0469=nil
end
ok,reason=step(1444)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[102].get_item_count("iron-ore")==1)
terminal.priest.position={x=61,y=0}
ok,reason=step(1505)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[102].get_item_count("iron-ore")==2
  and mission.return_courier_0837.receipts_0982[1].quantity==1)
ok,reason=step(1566)
assert(ok and reason=="next-physical-upstream-hop-reserved"
  and invs[102].get_item_count("iron-ore")==2)
intermediate.priest.position={x=60,y=0}
ok,reason=step(1627)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[102].get_item_count("iron-ore")==1
  and mission.return_courier_0837.inventory.get_item_count("iron-ore")==1)
ok,reason=step(1688)
assert(not ok and reason=="walking-to-upstream-station")
intermediate.priest.position={x=30,y=0}
ok,reason=step(1749)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[101].get_item_count("iron-ore")==1)
ok,reason=step(1810)
assert(ok and reason=="next-physical-upstream-hop-reserved")
senior.priest.position={x=30,y=0}
ok,reason=step(1871)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[101].get_item_count("iron-ore")==0)
ok,reason=step(1932)
assert(not ok and reason=="walking-to-upstream-station")
senior.priest.position={x=2,y=0}
ok,reason=step(1993)
local delivered=mission.return_courier_0837
assert(ok and reason=="counted-machine-ore-received-by-magos"
  and delivered.phase=="magos-delivered"
  and delivered.source_kind_0991=="drill-output"
  and delivered.hops_completed==3
  and #delivered.receipts_0982==3
  and invs[100].get_item_count("iron-ore")==2
  and mission.delivered_to_magos_count==2
  and mines==mined_before_machine,
  "physical machine ore did not traverse every ranked link to original Magos")
print("[resource-return-machine-output-0992] PASS completed natural return rearm, corrupted-ledger refusal, reserved real drill stock, module reload, all three physical ranked hops and counted Magos receipt")

-- 0995: real 0528 drill output must reach the terminal's own
-- inventory when a verified ranked 0820 return is waiting. A nearby
-- retention chest must not silently satisfy the receipt.
mission.segments=3
mission.route_station_units={100,101,102,103}
terminal.remote_resource_assignment_0820={
  root_station_unit=100,parent_station_unit=102,segment=3}
local stash_inventory=inventory(0)
stash_inventory.can_insert=function(stack)
  return stash_inventory.get_insertable_count()>=stack.count
end
local nearby_stash={valid=true,name="wooden-chest",type="container",
  unit_number=888,position={x=91,y=0},force=force,surface=surface}
nearby_stash.get_inventory=function(id)
  return id==defines.inventory.chest and stash_inventory or nil
end
surface.find_entities_filtered=function() return {nearby_stash} end
invs[103].can_insert=function(stack)
  return invs[103].get_insertable_count()>=stack.count
end
local deposited,why,amount=StorageAuthority.deposit_exact(
  terminal,"iron-ore",2,"ranked-machine-test-0995",
  {role="retention",station_only=true})
assert(deposited and amount==2
  and invs[103].get_item_count("iron-ore")==2
  and stash_inventory.get_item_count("iron-ore")==0,
  "0995 station-only exact deposit leaked into nearby retention stash: "..tostring(why))
assert(invs[103].remove{name="iron-ore",count=2}==2)
invs[103].capacity=0
local blocked=StorageAuthority.deposit_exact(
  terminal,"iron-ore",1,"ranked-machine-full-0995",
  {role="retention",station_only=true})
assert(not blocked and invs[103].get_item_count("iron-ore")==0
  and stash_inventory.get_item_count("iron-ore")==0,
  "0995 full station was bypassed by adjacent container")
invs[103].capacity=100
local Logistics0528=require("scripts.core.logistics_machine_fulfillment_0528")
local real_hold=inventory(1)
local drill_pickup={
  status="carried",station_unit=103,priest_unit=terminal.priest.unit_number,
  receiver_unit=701,drill_unit=700,item="iron-ore",count=1,
  source_before=2,source_after=1,tick=game.tick}
local output_state={
  phase="return-custody-to-station",action="clear-output",
  machine=receiver,machine_unit=701,drill_source_unit_0983=700,
  item="iron-ore",count=1,drill_pickup_0983=drill_pickup,
  custody={kind="output",item="iron-ore",count=1,inventory_0984=real_hold}}
terminal.machine_logistics_0528=output_state
terminal.machine_logistics_custody_0528=output_state.custody
terminal.priest.position={x=90,y=0}
local completion=Logistics0528.service_pair(terminal,"ranked-return-0995")
local last=terminal.drill_output_receipts_0983
  and terminal.drill_output_receipts_0983[#terminal.drill_output_receipts_0983]
assert(completion.acted==1 and completion.detail=="machine-output-complete"
  and not real_hold.valid
  and invs[103].get_item_count("iron-ore")==1
  and stash_inventory.get_item_count("iron-ore")==0
  and last and last.station_only_0995==true
  and last.station_container_before_0995==0
  and last.station_container_after_0995==1
  and last.source_before==2 and last.source_after==1,
  "0995 real drill hold did not deposit exact physical stock to ranked terminal")
print("[ranked-machine-station-deposit-0995] PASS station-only, full refusal, canonical drill custody and exact station receipt")

package.loaded["scripts.core.resource_station_chain_0820"]=old_chain
print("[resource-return-multihop-0838] PASS three physical inventory hops, non-preemptive upstream reservation, full storage, reload, Magos receipt, route quarantine")
