-- Source fixture: counted natural ore across three distinct physical hops.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local old_chain=package.loaded["scripts.core.resource_station_chain_0820"]
local route={103,102,101,100}
package.loaded["scripts.core.resource_station_chain_0820"]={
  return_route=function() return route,"verified-physical-upstream-route" end,
}
package.loaded["scripts.core.resource_return_courier_0837"]=nil
local Courier=require("scripts.core.resource_return_courier_0837")
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
    priest={valid=true,unit_number=id+1000,position={x=x,y=0}},
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
}
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
ok,reason=step(405)
assert(ok and reason=="next-physical-upstream-hop-reserved"
  and state.source_station_unit==102 and state.destination_station_unit==101
  and state.pending_upstream_station_unit==nil
  and state.pending_upstream_priest_unit==nil
  and Courier.worker_reserved(intermediate))
ok,reason=step(466)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[102].get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1
  and Courier.reserved_at_station(intermediate,"iron-ore")==0)
ok,reason=step(527)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[101].get_item_count("iron-ore")==0)
intermediate.priest.position={x=31,y=0}
ok,reason=step(588)
assert(ok and reason=="first-physical-upstream-hop-delivered"
  and invs[101].get_item_count("iron-ore")==1
  and Courier.reserved_at_station(senior,"iron-ore")==1
  and not Courier.worker_reserved(intermediate))
-- A completed mining duty may leave "returning" set while the reserved
-- dispatcher withholds legacy idle transitions. Remote pickup remains denied.
senior.mode="returning"
senior.priest.position={x=38,y=0}
local prior_senior_commands=#commands
ok,reason=step(649)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and #commands==prior_senior_commands
  and invs[101].get_item_count("iron-ore")==1
  and state.phase=="first-hop-delivered",
  "returning priest was seized away from its home station")
senior.priest.position={x=30,y=0}
senior.active_task={kind="legitimate-prior-duty"}
ok,reason=step(650)
assert(not ok and reason=="upstream-priest-has-existing-duty"
  and senior.active_task.kind=="legitimate-prior-duty"
  and invs[101].get_item_count("iron-ore")==1,
  "home arrival bypassed a still-active duty")
senior.active_task=nil
ok,reason=step(651)
assert(ok and reason=="next-physical-upstream-hop-reserved"
  and state.source_station_unit==101 and state.destination_station_unit==100
  and Courier.worker_reserved(senior)
  and invs[101].get_item_count("iron-ore")==1,
  "completed returning mode blocked safe local relay pickup")
ok,reason=step(710)
assert(ok and reason=="physical-upstream-item-picked-up"
  and invs[101].get_item_count("iron-ore")==0
  and state.inventory.get_item_count("iron-ore")==1
  and Courier.reserved_at_station(senior,"iron-ore")==0)
package.loaded["scripts.core.resource_return_courier_0837"]=nil
Courier=require("scripts.core.resource_return_courier_0837")
assert(Courier.worker_reserved(senior),"reload lost upstream carrier custody")
ok,reason=step(771)
assert(not ok and reason=="walking-to-upstream-station"
  and invs[100].get_item_count("iron-ore")==0)
senior.priest.position={x=2,y=0}
ok,reason=step(832)
assert(ok and reason=="counted-natural-ore-received-by-magos"
  and state.phase=="magos-delivered" and state.hops_completed==3
  and mission.delivered_to_magos_count==1
  and invs[100].get_item_count("iron-ore")==1
  and mines==1 and ore.amount==7
  and not Courier.worker_reserved(senior))
ok,reason=step(893)
assert(not ok and reason=="natural-ore-already-delivered-to-magos"
  and mission.delivered_to_magos_count==1
  and invs[100].get_item_count("iron-ore")==1
  and mines==1,"duplicate Magos delivery")
-- Route mutation after mining quarantines the real carried inventory.
mission.return_courier_0837=nil
terminal.priest.position={x=94,y=0}
ok,reason=step(954)
assert(ok and reason=="physical-ore-mined")
local stranded=mission.return_courier_0837
route={103,101,102,100}
ok,reason=step(1015)
assert(not ok and reason=="return-route-changed-during-custody"
  and stranded.phase=="custody-blocked"
  and stranded.inventory.get_item_count("iron-ore")==1
  and invs[100].get_item_count("iron-ore")==1
  and mission.delivered_to_magos_count==1,
  "changed route stole or fabricated physical cargo")
package.loaded["scripts.core.resource_station_chain_0820"]=old_chain
print("[resource-return-multihop-0838] PASS three physical inventory hops, non-preemptive upstream reservation, full storage, reload, Magos receipt, route quarantine")
