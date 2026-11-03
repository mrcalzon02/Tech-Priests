-- Exact original 0953 movement authority: no physical custody or work preemption.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local old_chain=package.loaded["scripts.core.resource_station_chain_0820"]
local old_0953=package.loaded["scripts.core.resource_return_movement_0953"]
package.loaded["scripts.core.resource_station_chain_0820"]={
 return_route=function()return {102,101,100},"verified" end,
 operating_radius=function()return 30 end,
}
package.loaded["scripts.core.resource_return_movement_0953"]=nil
local M=require("scripts.core.resource_return_movement_0953")
game={tick=1000}
local force,surface={index=1},{index=1}
local function make_pair(id,x)
 return {station={valid=true,unit_number=id,position={x=x,y=0},
 force=force,surface=surface},priest={valid=true,unit_number=id+1000,
 position={x=x,y=0},force=force,surface=surface},mode="idle"}
end
local root,senior,terminal=make_pair(100,0),make_pair(101,30),make_pair(102,60)
senior.remote_resource_assignment_0820={root_station_unit=100}
terminal.remote_resource_assignment_0820={root_station_unit=100}
local station_ore=1
local inv={valid=true,get_item_count=function(item)
 if item==nil or item=="iron-ore" then return station_ore end return 0 end}
local previous_inventory=rawget(_G,"get_station_inventory")
get_station_inventory=function(station)
 assert(station==senior.station)
 return inv
end
local state={phase="to-upstream-pickup",hop_index=2,source_station_unit=101,
 destination_station_unit=100,carrier_priest_unit=1101,item="iron-ore",
 quantity=1,delivered_count=1,delivered_station_unit=101,
 station_custody_unit=101,receipt_hop=1,hops_completed=1,inventory=nil}
root.resource_expansion_0259={chain_0820={
 status="reached-resource",root_station_unit=100,current_station_unit=102,
 need="iron-ore",return_courier_0837=state}}
storage={tech_priests={pairs_by_station={
 [100]=root,[101]=senior,[102]=terminal}}}
local request={owner="resource-return-courier-0953",
 reason="resource-return-upstream-pickup-0953",priority=72,x=30,y=0}
assert(M.authorized(senior,request)==true)
local function deny(reason)
 assert(M.authorized(senior,request)==false,
  "unsafe courier movement was authorized: "..reason)
 local detail=senior.resource_return_movement_refusal_1152
 assert(detail and detail.reason==reason and detail.tick==game.tick,
  "missing exact real-movement refusal: "..reason)
end
senior.active_task={kind="existing-duty"}
deny("live-task-owned-by-another-authority")
senior.active_task=nil
senior.machine_logistics_custody_0528={item="copper-ore",count=1}
deny("live-physical-custody")
senior.machine_logistics_custody_0528=nil
station_ore=0
deny("counted-upstream-ore-not-in-station-inventory")
station_ore=1
state.station_custody_unit=nil
deny("courier-phase-or-deposited-custody-not-eligible")
state.station_custody_unit=101
state.destination_station_unit=999
deny("ranked-route-or-hop-identity-invalid")
state.destination_station_unit=100
request.priority=73
deny("courier-movement-reason-priority-or-lease-invalid")
request.priority=72
request.x=31
deny("courier-movement-destination-mismatch")
request.x=30
senior.remote_resource_assignment_0820.root_station_unit=999
deny("courier-mission-root-or-carrier-identity-invalid")
senior.remote_resource_assignment_0820.root_station_unit=100
assert(M.authorized(senior,request)==true
  and senior.resource_return_movement_refusal_1152==nil
  and station_ore==1 and state.inventory==nil
  and state.phase=="to-upstream-pickup",
 "valid physical relay did not recover when authentic guards restored")
get_station_inventory=previous_inventory
package.loaded["scripts.core.resource_station_chain_0820"]=old_chain
package.loaded["scripts.core.resource_return_movement_0953"]=old_0953
print("[resource-return-movement-refusal-1152] PASS exact 0953 safety reasons with unchanged ore custody")
