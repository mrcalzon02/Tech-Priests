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
  and Courier.worker_reserved(terminal),"real mining did not reserve courier")
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
package.loaded["scripts.core.resource_station_chain_0820"]=saved_chain
print("[resource-return-courier-0837] PASS non-preemptive duty reservation, reload, ore mutation, real carry, full storage refusal and counted upstream delivery")
