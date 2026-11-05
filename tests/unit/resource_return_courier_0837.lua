-- Fixture regression: actual ore entity mutation and one counted upstream
-- station transfer, without remote inventory credit or synthetic stock.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local saved_chain=package.loaded["scripts.core.resource_station_chain_0820"]
package.loaded["scripts.core.resource_station_chain_0820"]={
  return_route=function() return {103,102,101,100},"verified-physical-upstream-route" end,
}
package.loaded["scripts.core.resource_return_courier_0837"]=nil
local Courier
local function inventory(initial,capacity)
  local inv={valid=true,items={["iron-ore"]=initial or 0},capacity=capacity or 100}
  function inv.get_item_count(name)
    if name then return inv.items[name] or 0 end
    local total=0
    for _,n in pairs(inv.items) do total=total+n end
    return total
  end
  function inv.get_insertable_count(name)
    return inv.capacity-inv.get_item_count()
  end
  function inv.insert(stack)
    local n=math.min(stack.count,inv.get_insertable_count(stack.name))
    inv.items[stack.name]=(inv.items[stack.name] or 0)+n
    return n
  end
  function inv.remove(stack)
    local n=math.min(stack.count,inv.get_item_count(stack.name))
    inv.items[stack.name]=inv.get_item_count(stack.name)-n
    return n
  end
  function inv.destroy()
    assert(inv.get_item_count()==0,"nonempty courier inventory destroyed")
    inv.valid=false
  end
  return inv
end
local force={index=1}
local surface={index=1}
local function pair(id,x,rank)
  return {station={valid=true,unit_number=id,position={x=x,y=0},
      force=force,surface=surface},
    priest={valid=true,unit_number=id+1000,position={x=x,y=0}},
    rank=rank,radius=30}
end
local root=pair(100,0,4)
local senior=pair(101,30,3)
local parent=pair(102,60,2)
local terminal=pair(103,90,1)
senior.remote_resource_assignment_0820={root_station_unit=100}
parent.remote_resource_assignment_0820={root_station_unit=100}
terminal.remote_resource_assignment_0820={root_station_unit=100}
local mine_calls=0
local ore={valid=true,unit_number=900,type="resource",name="iron-ore",
  amount=8,position={x=94,y=0},surface=surface,
  prototype={mineable_properties={products={{type="item",name="iron-ore",amount=1}}}}}
function ore.mine(args)
  mine_calls=mine_calls+1
  assert(args.inventory and args.force==nil and ore.amount>0)
  ore.amount=ore.amount-1
  assert(args.inventory.insert({name="iron-ore",count=1})==1)
  return true
end
_G.TechPriestsScanRouting0610={find_entities=function(s,filter)
  assert(s==surface and filter.type=="resource" and filter.name=="iron-ore")
  return {ore}
end}
local upstream=inventory(0,0)
_G.get_station_inventory=function(station)
  assert(station==parent.station)
  return upstream
end
local commands={}
_G.issue_priest_command=function()
  error("0837 courier must not issue raw ground commands")
end
package.loaded["scripts.core.movement_controller"]={
  request=function(worker,pos,reason,opts)
    assert(worker==terminal and opts.owner=="resource-return-courier-0953"
      and opts.priority==72 and opts.bounds_exempt==true
      and reason=="resource-return-upstream-delivery-0953"
      and pos==parent.station.position)
    commands[#commands+1]={priest=worker.priest,command={destination=pos}}
    return true,"accepted-by-canonical-controller"
  end,
  request_status=function(worker)
    if worker.test_live_movement then
      return {active=true,status="active"}
    end
    return {active=false,status="missing-request"}
  end,
}
-- Resolve the canonical movement mock during module parsing, as Factorio requires.
Courier=require("scripts.core.resource_return_courier_0837")
_G.defines={command={go_to_location=1},distraction={none=0}}
_G.prototypes={item={["iron-ore"]={}}}
_G.game={tick=100,create_inventory=function() return inventory(0,100) end}
root.resource_expansion_0259={chain_0820={
  status="reached-resource",root_station_unit=100,
  current_station_unit=103,target={x=94,y=0},
  resource_name="iron-ore",need="iron-ore"}}
_G.storage={tech_priests={pairs_by_station={
  [100]=root,[101]=senior,[102]=parent,[103]=terminal}}}
terminal.active_task={kind="existing-miner"}
local denied,duty=Courier.service(root)
local pending=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(not denied and duty=="terminal-priest-has-existing-duty"
  and pending and pending.phase=="awaiting-terminal-duty"
  and pending.inventory==nil and pending.quantity==0
  and Courier.incumbent_relay_duty_needs_tick_1125(terminal)
  and not Courier.incumbent_relay_duty_needs_tick_1125(root)
  and Courier.worker_reserved(terminal)
  and Courier.worker_reserved(parent)
  and Courier.worker_reserved(senior)
  and Courier.worker_reserved(root)
  and terminal.active_task.kind=="existing-miner"
  and #commands==0 and ore.amount==8 and mine_calls==0,
  "pending courier failed to reserve future work without preempting current duty")
game.tick=101
denied,duty=Courier.service(root)
assert(not denied and duty=="terminal-priest-has-existing-duty"
  and root.resource_expansion_0259.chain_0820.return_courier_0837==pending
  and #commands==0 and mine_calls==0 and ore.amount==8,
  "waiting for a legitimate duty changed ore custody or moved its priest")
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.worker_reserved(terminal)
  and pending.phase=="awaiting-terminal-duty",
  "module reload lost the non-preemptive terminal work reservation")
terminal.active_task=nil
assert(not Courier.incumbent_relay_duty_needs_tick_1125(terminal),
  "idle reserved terminal could launch unrelated work before courier")
-- Simulate the native robot Intermediate's real direct-mining return with
-- one ore in its own physical 0513 custody. Reservation must allow the
-- original executor to finish that existing duty; no item is transferred.
terminal.mode="direct-acquisition-returning-with-custody"
terminal.direct_acquisition_custody_0513={item="iron-ore",count=1}
assert(Courier.incumbent_relay_duty_needs_tick_1125(terminal)
  and not Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "native incumbent physical return was frozen by future courier reservation")
terminal.direct_acquisition_custody_0513=nil
terminal.mode=nil
assert(not Courier.incumbent_relay_duty_needs_tick_1125(terminal),
  "released direct mining custody did not return priest to reserved courier")
-- Factorio's live 9190-tick engine record held precisely this 0647 mode
-- with active_task=nil: do not mistake a blocked recipe dependency for an
-- executable duty. Do NOT erase its original production objective.
terminal.mode="infrastructure-material-acquisition-0647"
local deferred={item="tech-priests-emergency-smelter",missing="iron-plate",
  ingredients={{name="iron-plate",count=5}},started_tick=98}
local unrelated,unrelated_why=Courier.service(root)
assert(not unrelated and unrelated_why=="terminal-priest-has-existing-duty"
  and pending.phase=="awaiting-terminal-duty" and ore.amount==8,
  "mere mode without proven deferred ingredient incorrectly seized a priest")
terminal.infrastructure_recipe_request_0647=deferred
-- Completed station placement remains in a saved pair record, but no
-- longer owns the priest or its station item. In contrast, actual held
-- machine logistics / repair / consecration goods must finish first.
terminal.station_expansion_0256={status="complete",completed_tick=100}
for _,field in ipairs({
  "machine_logistics_custody_0528","emergency_facility_feed_custody_0357",
  "repair_pack_custody_0516","consecration_refund_custody_0515"
})do
  terminal[field]={item="preserved-physical-resource",count=1}
  local postponed,cause=Courier.service(root)
  assert(not postponed and cause=="terminal-priest-has-existing-custody"
    and pending.phase=="awaiting-terminal-duty"
    and pending.inventory==nil and ore.amount==8 and mine_calls==0,
    "ore courier seized live "..field.." before existing physical custody cleared")
  terminal[field]=nil
end
-- An in-range engine resource must never override an out-of-range worker.
terminal.radius=3
_G.TechPriestsScanRouting0610.find_entities=function(_,filter,opts)
  assert(filter.name=="iron-ore" and filter.limit==8)
  -- Simulate a stale 0579 cache. The physical 0610 read must explicitly
  -- opt into fresh engine evidence to recover the real natural deposit.
  return opts and opts.require_fresh and {ore} or {}
end
local denied_range,range_reason=Courier.service(root)
assert(not denied_range and range_reason=="natural-ore-outside-station-radius"
  and ore.amount==8 and mine_calls==0 and pending.inventory==nil,
  "stale resource index bypassed physical station range")
terminal.radius=30
-- A denied preflight obeys the courier's 60-tick bounded retry interval.
game.tick=161
local ok,why=Courier.service(root)
assert(ok and why=="physical-ore-mined"
  and terminal.infrastructure_recipe_request_0647==deferred
  and terminal.mode=="infrastructure-material-acquisition-0647"
  and ore.amount==7 and mine_calls==1
  and pending.phase=="carrying"
  and pending.source_kind_0991=="natural-ore"
  and Courier.worker_reserved(terminal)
  and not Courier.incumbent_relay_duty_needs_tick_1125(terminal),
  "real mining did not reserve courier or establish physical source provenance")
local state=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(state.inventory.valid and state.inventory.get_item_count("iron-ore")==1)
game.tick=222
-- Factorio 2.0.77 rejects require() inside tick/event handlers. The fixture
-- must enforce that restriction rather than silently accepting runtime loads.
local parse_time_require=require
_G.require=function() error("runtime require forbidden by Factorio 2.0.77") end
local runtime_ok,runtime_result,runtime_reason=pcall(Courier.service,root)
_G.require=parse_time_require
assert(runtime_ok,"physical ore movement attempted a runtime require: "..tostring(runtime_result))
ok,why=runtime_result,runtime_reason
assert(not ok and why=="walking-to-upstream-station"
  and #commands==1 and upstream.get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1,
  "distant upstream received remote inventory credit")
terminal.priest.position={x=62,y=0}
game.tick=283
ok,why=Courier.service(root)
assert(not ok and why=="upstream-inventory-full"
  and state.inventory.get_item_count("iron-ore")==1
  and upstream.get_item_count("iron-ore")==0,
  "full parent storage lost or fabricated ore")
-- Reload module, preserving the real inventory reference in persistent storage.
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.worker_reserved(terminal),"reload lost exact courier ownership")
upstream.capacity=10
game.tick=344
ok,why=Courier.service(root)
assert(ok and why=="first-physical-upstream-hop-delivered"
  and state.delivered_count==1 and state.delivered_station_unit==102
  and state.receipt_hop==1 and state.receipt_destination_before==0
  and state.receipt_destination_after==1
  and upstream.get_item_count("iron-ore")==1
  and ore.amount==7 and mine_calls==1
  and not Courier.worker_reserved(terminal)
  and Courier.worker_reserved(parent) and Courier.worker_reserved(senior)
  and Courier.worker_reserved(root),
  "counted physical delivery or future-relay reservations failed")
-- 1140: the just-delivered ore must NOT freeze an incumbent BEFORE the
-- root has the chance to persist its next-worker lease. This was exactly
-- the native Senior's reservation=true / incumbent_tick=false deadlock.
-- Only the original paired recipient with a valid counted physical receipt
-- and still-present real stock may advance its incumbent task.
parent.active_task={kind="existing-pre-lease-assignment"}
assert(state.pending_upstream_station_unit==nil
  and Courier.incumbent_relay_duty_needs_tick_1125(parent)
  and not Courier.incumbent_relay_duty_needs_tick_1125(senior)
  and upstream.get_item_count("iron-ore")==1,
  "counted first-hop receipt froze the existing upstream worker before lease")
local held=upstream.items["iron-ore"]
upstream.items["iron-ore"]=0
assert(not Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "missing physical deposited ore was treated as a valid incumbent lease")
upstream.items["iron-ore"]=held
state.receipt_destination_after=state.receipt_destination_after+1
assert(not Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "invalid deposit ledger bypassed the exact counted receipt gate")
state.receipt_destination_after=state.receipt_destination_after-1
assert(Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "valid physical receipt did not restore only incumbent progress")
parent.active_task=nil
assert(not Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "idle upstream worker was authorized to start unrelated work pre-lease")
-- Before the next real 0837 dispatch, an existing upstream job may
-- complete under its original tick; no courier inventory is yet debited.
state.pending_upstream_station_unit=parent.station.unit_number
state.pending_upstream_priest_unit=parent.priest.unit_number
parent.active_task={kind="incumbent-physical-job"}
assert(Courier.incumbent_relay_duty_needs_tick_1125(parent)
  and not Courier.incumbent_relay_duty_needs_tick_1125(senior),
  "pending upstream worker was frozen before existing work could finish")
parent.active_task=nil
assert(not Courier.incumbent_relay_duty_needs_tick_1125(parent),
  "free upstream receiver did not remain reserved for physical ore pickup")
game.tick=405
assert(Courier.service(root) and state.phase=="to-upstream-pickup"
  and state.source_station_unit==102 and upstream.get_item_count("iron-ore")==1
  and mine_calls==1,"first-hop handoff duplicated ore or skipped local pickup")
-- Wrong priest identity must fail closed without losing the physical item.
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
terminal.priest.position={x=94,y=0}
game.tick=466
assert(Courier.service(root),"second real ore mine did not start")
local second=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(second.inventory.get_item_count("iron-ore")==1)
terminal.priest.unit_number=9999
game.tick=527
ok,why=Courier.service(root)
assert(not ok and why=="physical-route-or-carrier-identity-changed"
  and second.phase=="custody-blocked"
  and second.inventory.get_item_count("iron-ore")==1
  and upstream.get_item_count("iron-ore")==1,
  "wrong priest stole carried physical ore")
-- A failed physical mine must never become a synthetic delivery.
terminal.priest.unit_number=1103
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
local prior_amount=ore.amount
local actual_mine=ore.mine
ore.mine=function() return false end
game.tick=588
ok,why=Courier.service(root)
local refused=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(not ok and why=="physical-ore-mine-produced-no-verifiable-item"
  and refused.phase=="custody-blocked"
  and refused.inventory.get_item_count("iron-ore")==0
  and ore.amount==prior_amount
  and upstream.get_item_count("iron-ore")==1,
  "failed ore mine fabricated counted material")
ore.mine=actual_mine
-- 1036: a real terminal's coal is reserved during ranked drill/receiver
-- construction; the guard may not consume it for unrelated machines.
local mission=root.resource_expansion_0259.chain_0820
mission.remote_drill_1011={root_unit=100,terminal_unit=103,
  phase="receiver-requested"}
assert(Courier.remote_drill_fuel_reserved_1036(terminal,"coal")==5
  and Courier.reserved_at_station(terminal,"coal")==5
  and Courier.spendable_station_item(terminal,"coal",7)==2
  and Courier.spendable_station_item(terminal,"coal",3)==0
  and Courier.spendable_station_item(terminal,"iron-plate",7)==7,
  "ranked physical drill fuel was spendable by unrelated station work")
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.spendable_station_item(terminal,"coal",5)==0,
  "save/reload lost pending physical coal reservation")
mission.remote_drill_1011.fuel_escrow_1037={
  valid=true,get_item_count=function()return 5 end}
assert(Courier.remote_drill_fuel_reserved_1036(terminal,"coal")==0
  and Courier.spendable_station_item(terminal,"coal",5)==5,
  "1037 double-reserved unrelated station fuel")
mission.remote_drill_1011.fuel_escrow_1037=nil
mission.remote_drill_1011.phase="fuel-verified"
assert(Courier.spendable_station_item(terminal,"coal",5)==5,
  "completed drill fuel reservation never released")
mission.remote_drill_1011.phase="receiver-verified"
mission.remote_drill_1011.terminal_unit=999
assert(Courier.spendable_station_item(terminal,"coal",5)==5,
  "foreign terminal mission reserved unrelated coal")
mission.remote_drill_1011=nil

-- 1058: The five-process native run exposed a stranded Senior whose real
-- direct walk had failed, with no live task/cargo/movement and an adopted
-- *targetless* iron-ore assignment still owned by 0469. The courier may
-- borrow this priest only through the queue's lossless pause/resume.
local OrderQueue=require("scripts.core.order_queue_0469")
_G.tech_priests_movement_status_0418=function(worker)
  return package.loaded["scripts.core.movement_controller"].request_status(worker)
end
local failed=senior
local original_mode=failed.mode
local original_request=failed.infrastructure_recipe_request_0647
local order_task={type="assignment",item="iron-ore",source="adopted-plan"}
local old_order={status="active",kind="assignment",source="adopt-active",
  item="iron-ore",task=order_task}
local recipe={item="tech-priests-emergency-smelter",missing="stone"}
failed.mode="direct-acquisition-movement-failed"
failed.infrastructure_recipe_request_0647=recipe
failed.requested_item="stone"
failed.logistic_requested_item="stone"
failed.local_infrastructure_gate_0640={item=recipe.item}
failed.order_queue_0469={current=old_order,pending={},history={},stats={}}
failed.active_order_0469=old_order
failed.active_task=nil
failed.active_task_0285=nil
failed.current_task=nil
local eligible,why=OrderQueue.can_pause_uncommitted_relay_0974(failed,recipe)
assert(eligible and why=="uncommitted-material-order",
  "stale targetless adopted order blocked counted physical relay")
local dormant,reason=Courier.probe_dormant_direct_relay_0973(failed)
assert(dormant and reason=="dormant-direct-verified",
  "failed direct walk without live movement/custody remained an eternal duty")
local paused,pause_reason=OrderQueue.pause_uncommitted_relay_0974(failed,recipe)
assert(paused and pause_reason=="relay-paused" and old_order.status=="paused"
  and failed.active_order_0469==old_order and old_order.task==order_task
  and failed.infrastructure_recipe_request_0647==recipe,
  "relay pause lost original queue, recipe or task identity")
local resumed=OrderQueue.resume_after_resource_relay_0974(failed)
assert(resumed and old_order.status=="active" and old_order.task==order_task
  and failed.active_order_0469==old_order
  and failed.infrastructure_recipe_request_0647==recipe,
  "relay resume did not restore the exact uncommitted order")
for _,case in ipairs({
  {field="test_live_movement",value=true},
  {field="current_task",value={type="live-foreign"}},
  {field="direct_acquisition_custody_0513",value={item="iron-ore",count=1}},
  {field="active_task",value={type="foreign"}},
  {field="active_task_0285",value={type="assignment",item="copper-ore"}},
}) do
  failed[case.field]=case.value
  local allowed=OrderQueue.can_pause_uncommitted_relay_0974(failed,recipe)
  local permitted=Courier.probe_dormant_direct_relay_0973(failed)
  assert(not allowed and not permitted,
    "live or foreign "..case.field.." incorrectly yielded physical custody")
  failed[case.field]=nil
end
local original_task=old_order.task
old_order.task={type="assignment",item="iron-ore",
  target={valid=true,unit_number=222}}
assert(not OrderQueue.can_pause_uncommitted_relay_0974(failed,recipe)
  and not Courier.probe_dormant_direct_relay_0973(failed),
  "targeted foreign order was mistaken for a passive failed movement")
old_order.task=original_task
-- 1166: Some live 0285 lifecycles retire active_task_0285 but retain the
-- exact UNCOMMITTED adopted planning task as the sole active_task alias.
-- Preserve this object's identity through a counted relay pause/resume.
failed.active_task=original_task
failed.active_task_0285=nil
local only_alias_ok,only_alias_reason=
  OrderQueue.can_pause_uncommitted_relay_0974(failed,recipe)
assert(only_alias_ok and only_alias_reason=="uncommitted-material-order",
  "exact active-only adopted planning order was not yieldable")
local only_alias_dormant,only_alias_why=
  Courier.probe_dormant_direct_relay_0973(failed)
assert(only_alias_dormant and only_alias_why=="dormant-direct-verified",
  "active-only uncommitted assignment blocked the counted ore courier")
local only_alias_paused,only_alias_pause_reason=
  OrderQueue.pause_uncommitted_relay_0974(failed,recipe)
assert(only_alias_paused and only_alias_pause_reason=="relay-paused"
  and old_order.status=="paused"
  and failed.active_task==nil and failed.active_task_0285==nil
  and old_order.relay_paused_task_active==original_task
  and old_order.relay_paused_task_0285==nil,
  "active-only planning pointer was not saved exactly before relay")
-- A different owner cannot replace the stored task on reload/resumption.
local foreign={type="assignment",item="iron-ore"}
failed.active_task=foreign
assert(not OrderQueue.resume_after_resource_relay_0974(failed)
  and old_order.status=="paused"
  and old_order.relay_paused_task_active==original_task,
  "foreign active task overwrote a persisted relay task")
failed.active_task=nil
assert(OrderQueue.resume_after_resource_relay_0974(failed)
  and old_order.status=="active"
  and failed.active_task==original_task
  and failed.active_task_0285==nil
  and old_order.relay_paused_task_active==nil,
  "active-only adopted planning task was not restored after delivery")
failed.active_task=foreign
assert(not OrderQueue.can_pause_uncommitted_relay_0974(failed,recipe)
  and not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign targetless active assignment was incorrectly borrowed")
failed.active_task=original_task
failed.test_live_movement=true
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "live movement was overridden by an active-only adopted order")
failed.test_live_movement=nil
-- 1167: native 41750369912 reached a counted Intermediate->Senior deposit,
-- then its Senior finished a real direct task but retained an original 0285
-- targetless order for iron ore alongside a DIFFERENT 0647 stone shortage.
-- The sole active planning pointer and exact 0469 order can be parked, but
-- a truly foreign request or independent physical source cannot be seized.
failed.requested_item="iron-ore"
failed.logistic_requested_item="iron-ore"
local own_label,own_label_reason=
  Courier.probe_dormant_direct_relay_0973(failed)
assert(own_label and own_label_reason=="dormant-direct-verified",
  "original 0469-owned alternate ingredient label stranded counted ore")
assert(OrderQueue.pause_uncommitted_relay_0974(failed,recipe)
  and old_order.status=="paused"
  and failed.active_task==nil
  and old_order.relay_paused_task_active==original_task,
  "original alternate material assignment was not parked losslessly")
assert(OrderQueue.resume_after_resource_relay_0974(failed)
  and old_order.status=="active"
  and failed.active_task==original_task
  and failed.requested_item=="iron-ore"
  and failed.logistic_requested_item=="iron-ore",
  "alternate planning labels or original task were lost after relay")
failed.requested_item="copper-ore"
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign requested_item label was mistaken for the original order")
failed.requested_item="iron-ore"
failed.logistic_requested_item="copper-ore"
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign logistic label was mistaken for the original order")
failed.logistic_requested_item="iron-ore"
failed.requested_item={candidates={{name="iron-ore"},{name="stone"}}}
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "ambiguous request candidates were treated as exact owner material")
failed.requested_item="iron-ore"
failed.active_supply_request={source="independent-live",target={valid=true}}
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign live physical supply ownership was bypassed")
failed.active_supply_request=nil
failed.active_order_0469={item="iron-ore",status="active"}
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign active order pointer was not rejected")
failed.active_order_0469=old_order
-- 1169: exact native run 41758024613 had the SAME original 0285 order
-- in BOTH aliases, ordered iron-plate, while its 0647 recipe needed stone.
-- After one counted first-hop receipt, losing either original task alias is
-- a real scheduling defect: only the 0469 owner may pause/resume both.
original_task.item="iron-plate"
old_order.item="iron-plate"
failed.active_task=original_task
failed.active_task_0285=original_task
failed.requested_item="iron-plate"
failed.logistic_requested_item="iron-plate"
local both_ok,both_reason=Courier.probe_dormant_direct_relay_0973(failed)
assert(both_ok and both_reason=="dormant-direct-verified",
  "engine-identical dual-alias iron-plate order blocked the counted ore relay")
assert(OrderQueue.pause_uncommitted_relay_0974(failed,recipe)
  and old_order.status=="paused"
  and failed.active_task==nil and failed.active_task_0285==nil
  and old_order.relay_paused_task_active==original_task
  and old_order.relay_paused_task_0285==original_task,
  "owned dual-alias planning assignment was not losslessly parked")
assert(OrderQueue.resume_after_resource_relay_0974(failed)
  and old_order.status=="active"
  and failed.active_task==original_task
  and failed.active_task_0285==original_task
  and failed.requested_item=="iron-plate"
  and failed.logistic_requested_item=="iron-plate",
  "owned dual-alias task identity changed through a physical courier")
failed.active_task_0285={type="assignment",item="iron-plate"}
assert(not Courier.probe_dormant_direct_relay_0973(failed),
  "foreign second task alias was wrongly borrowed")
failed.active_task_0285=nil
failed.active_task=nil
old_order.item="iron-ore"
original_task.item="iron-ore"
failed.mode=original_mode
failed.infrastructure_recipe_request_0647=original_request
failed.order_queue_0469=nil
failed.active_order_0469=nil
failed.requested_item=nil
failed.logistic_requested_item=nil
failed.local_infrastructure_gate_0640=nil
_G.tech_priests_movement_status_0418=nil

-- Engine 41682123325: after the first live 0513 return, the original
-- robot-built terminal retained only a stale travel label and the 0647
-- material objective. The terminal and upstream relay must use the SAME
-- strict dormant-direct proof, not merely check whether mode == idle.
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
terminal.priest.unit_number=1103
terminal.priest.position={x=94,y=0}
terminal.mode="travelling-to-direct-acquisition"
terminal.infrastructure_recipe_request_0647={
  item="tech-priests-emergency-smelter",missing="iron-plate"}
terminal.active_task=nil
terminal.active_task_0285=nil
terminal.current_task=nil
terminal.active_order_0469=nil
terminal.order_queue_0469=nil
terminal.test_live_movement=true
game.tick=2500
local awaiting_ore=ore.amount
local held,held_reason=Courier.service(root)
local dormant_wait=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(not held and held_reason=="terminal-priest-has-existing-duty"
  and dormant_wait and dormant_wait.phase=="awaiting-terminal-duty"
  and not dormant_wait.inventory and ore.amount==awaiting_ore,
  "live 0418 movement was incorrectly displaced by courier")
terminal.test_live_movement=nil
terminal.direct_acquisition_custody_0513={item="iron-ore",count=1}
game.tick=2560
local cargo_blocked=Courier.service(root)
assert(not cargo_blocked and not dormant_wait.inventory
  and ore.amount==awaiting_ore
  and Courier.probe_dormant_direct_relay_0973(terminal)==false,
  "live 0513 physical ore custody was stolen by dormant-mode handoff")
terminal.direct_acquisition_custody_0513=nil
local dormant_ok,dormant_why=Courier.probe_dormant_direct_relay_0973(terminal)
assert(dormant_ok and dormant_why=="dormant-direct-verified",
  "physically finished direct task without live movement was not dormant")
game.tick=2620
local mined,mined_reason=Courier.service(root)
assert(mined and mined_reason=="physical-ore-mined"
  and dormant_wait.phase=="carrying"
  and dormant_wait.source_kind_0991=="natural-ore"
  and dormant_wait.inventory and dormant_wait.inventory.valid
  and dormant_wait.inventory.get_item_count("iron-ore")==1
  and ore.amount==awaiting_ore-1
  and terminal.infrastructure_recipe_request_0647.item==
    "tech-priests-emergency-smelter"
  and not terminal.direct_acquisition_custody_0513,
  "terminal remained hostage to stale 0513 mode or bypassed real ore mining")
-- 1171: Native source initially held two ore, but another real miner
-- depleted it to one before this courier's LuaEntity.mine. Real resources
-- have nil unit_number and can be invalidated after exactly one output.
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
ore.unit_number=nil
ore.valid=true;ore.amount=1
ore.mine=function(args)
  mine_calls=mine_calls+1
  assert(ore.valid and ore.amount==1
    and args.inventory.insert({name="iron-ore",count=1})==1)
  ore.amount=0;ore.valid=false
  return true
end
game.tick=2680
local depleted,why_depleted=Courier.service(root)
local vanished=root.resource_expansion_0259.chain_0820.return_courier_0837
local position={x=94,y=0}
assert(depleted and why_depleted=="physical-ore-mined"
  and vanished and vanished.phase=="carrying"
  and vanished.ore_amount_before==1 and vanished.ore_unit==nil
  and vanished.ore_source_position_1171.x==94
  and vanished.ore_source_position_1171.y==0
  and vanished.ore_source_name_1171=="iron-ore"
  and vanished.ore_source_surface_index_1171==1
  and not ore.valid and vanished.inventory.get_item_count("iron-ore")==1,
  "concurrent real depletion lost provenance or single physical ore")
local ok1171,reason1171=Courier.verify_natural_ore_source_1171(
  vanished,ore,2,position,1)
assert(ok1171 and reason1171=="native-source-entity-fully-mined",
  "fully mined native resource was rejected")
assert(not Courier.verify_natural_ore_source_1171(
    vanished,ore,2,{x=95,y=0},1)
  and not Courier.verify_natural_ore_source_1171(
    vanished,ore,2,position,2)
  and not Courier.verify_natural_ore_source_1171(
    vanished,ore,0,position,1),
  "foreign source position/surface or invalid initial amount accepted")
vanished.ore_amount_before=3
assert(not Courier.verify_natural_ore_source_1171(
    vanished,ore,2,position,1),
  "ore sourced after an impossible pre-mine amount was accepted")
vanished.ore_amount_before=1;vanished.quantity=2
assert(not Courier.verify_natural_ore_source_1171(
    vanished,ore,2,position,1),
  "multiple items passed one-item physical provenance")
vanished.quantity=1;ore.valid=true;ore.amount=1
assert(not Courier.verify_natural_ore_source_1171(
    vanished,ore,2,position,1),
  "unchanged source passed physical ore-depletion proof")
ore.amount=0
assert(Courier.verify_natural_ore_source_1171(
    vanished,ore,2,position,1),
  "real decrement was rejected")
-- 1248: after 0513 has finished and 0647 has retired, a stale
-- direct-acquisition travel/failure label with NO other live owner is not
-- authority to block the next exact natural-ore courier forever. Every
-- real task, request, queue and 0418 movement must still refuse.
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
terminal.mode="direct-acquisition-movement-failed"
terminal.infrastructure_recipe_request_0647=nil
terminal.active_task=nil
terminal.active_task_0285=nil
terminal.current_task=nil
terminal.active_order_0469=nil
terminal.order_queue_0469=nil
terminal.requested_item=nil
terminal.logistic_requested_item=nil
terminal.local_infrastructure_gate_0640=nil
terminal.direct_acquisition_custody_0513=nil
terminal.direct_acquisition_task_0336=nil
terminal.test_live_movement=nil
local orphan_ok,orphan_why=Courier.probe_dormant_direct_relay_0973(terminal)
assert(orphan_ok and orphan_why=="dormant-direct-orphan-no-live-owner-1248",
  "ownerless, fully completed 0513 label still froze terminal")
terminal.requested_item="copper-plate"
assert(not Courier.probe_dormant_direct_relay_0973(terminal),
  "foreign material request yielded to the terminal courier")
terminal.requested_item=nil
terminal.order_queue_0469={current={kind="assignment",status="active"}}
assert(not Courier.probe_dormant_direct_relay_0973(terminal),
  "foreign active 0469 order yielded to the courier")
terminal.order_queue_0469=nil
terminal.direct_acquisition_custody_0513={item="coal",count=1}
assert(not Courier.probe_dormant_direct_relay_0973(terminal),
  "real 0513 cargo was seized from the dormant miner")
terminal.direct_acquisition_custody_0513=nil
terminal.test_live_movement=true
assert(not Courier.probe_dormant_direct_relay_0973(terminal),
  "live 0418 motion was seized from the incumbent")
terminal.test_live_movement=nil
ore.valid=true
ore.amount=1
terminal.priest.position={x=94,y=0}
game.tick=2740
local returned,return_reason=Courier.service(root)
local orphan_state=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(returned and return_reason=="physical-ore-mined"
  and orphan_state and orphan_state.phase=="carrying"
  and orphan_state.source_kind_0991=="natural-ore"
  and orphan_state.inventory and orphan_state.inventory.valid
  and orphan_state.inventory.get_item_count("iron-ore")==1
  and ore.amount==0 and not ore.valid
  and terminal.infrastructure_recipe_request_0647==nil
  and not terminal.direct_acquisition_custody_0513,
  "fully ownerless 0513 label failed to mine real ore with original custody")
-- No item is delivered by this unit stage; the existing 0838 fixture
-- separately proves physical destination receipts and busy-upstream refusal.
package.loaded["scripts.core.resource_station_chain_0820"]=saved_chain
print("[resource-return-courier-0837] PASS non-preemptive duty, reload, real ore, direct orphan terminal with no active owner, cargo/order/motion refusals and counted relay")
