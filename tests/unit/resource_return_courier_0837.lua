-- Fixture regression: actual ore entity mutation and one counted upstream
-- station transfer, without remote inventory credit or synthetic stock.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local saved_chain=package.loaded["scripts.core.resource_station_chain_0820"]
package.loaded["scripts.core.resource_station_chain_0820"]={
  return_route=function() return {103,102,101,100},"verified-physical-upstream-route" end,
}
package.loaded["scripts.core.resource_return_courier_0837"]=nil
local Courier=require("scripts.core.resource_return_courier_0837")
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
local parent=pair(102,60,2)
local terminal=pair(103,90,1)
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
_G.issue_priest_command=function(priest,command)
  commands[#commands+1]={priest=priest,command=command}
end
_G.defines={command={go_to_location=1},distraction={none=0}}
_G.prototypes={item={["iron-ore"]={}}}
_G.game={tick=100,create_inventory=function() return inventory(0,100) end}
root.resource_expansion_0259={chain_0820={
  status="reached-resource",root_station_unit=100,
  current_station_unit=103,target={x=94,y=0},
  resource_name="iron-ore",need="iron-ore"}}
_G.storage={tech_priests={pairs_by_station={
  [100]=root,[102]=parent,[103]=terminal}}}
terminal.active_task={kind="existing-miner"}
local denied,duty=Courier.service(root)
local pending=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(not denied and duty=="terminal-priest-has-existing-duty"
  and pending and pending.phase=="awaiting-terminal-duty"
  and pending.inventory==nil and pending.quantity==0
  and Courier.worker_reserved(terminal)
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
local ok,why=Courier.service(root)
assert(ok and why=="physical-ore-mined"
  and ore.amount==7 and mine_calls==1
  and pending.phase=="carrying"
  and Courier.worker_reserved(terminal),"real mining did not reserve courier")
local state=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(state.inventory.valid and state.inventory.get_item_count("iron-ore")==1)
game.tick=161
ok,why=Courier.service(root)
assert(not ok and why=="walking-to-upstream-station"
  and #commands==1 and upstream.get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1,
  "distant upstream received remote inventory credit")
terminal.priest.position={x=62,y=0}
game.tick=222
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
game.tick=283
ok,why=Courier.service(root)
assert(ok and why=="first-physical-upstream-hop-delivered"
  and state.delivered_count==1 and state.delivered_station_unit==102
  and upstream.get_item_count("iron-ore")==1
  and ore.amount==7 and mine_calls==1
  and not Courier.worker_reserved(terminal),
  "counted physical delivery or conservation failed")
game.tick=344
assert(Courier.service(root) and state.phase=="to-upstream-pickup"
  and state.source_station_unit==102 and upstream.get_item_count("iron-ore")==1
  and mine_calls==1,"first-hop handoff duplicated ore or skipped local pickup")
-- Wrong priest identity must fail closed without losing the physical item.
root.resource_expansion_0259.chain_0820.return_courier_0837=nil
terminal.priest.position={x=94,y=0}
game.tick=405
assert(Courier.service(root),"second real ore mine did not start")
local second=root.resource_expansion_0259.chain_0820.return_courier_0837
assert(second.inventory.get_item_count("iron-ore")==1)
terminal.priest.unit_number=9999
game.tick=466
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
game.tick=527
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
