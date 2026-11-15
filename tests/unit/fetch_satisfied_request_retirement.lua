package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={}}
defines={inventory={chest=1}};prototypes={item={["firearm-magazine"]={}}}
local scans=0
local force,surface={index=1},{index=1,find_entities_filtered=function()scans=scans+1;return{}end}
local pair={station={valid=true,unit_number=1,force=force,surface=surface,position={x=0,y=0},
 get_inventory=function()return{valid=true,get_item_count=function()return 0 end}end},
 priest={valid=true,unit_number=2,force=force,surface=surface,position={x=0,y=0}},
 independent_emergency_operation_0184={enabled=true,phase="survival-satisfied",last_item="firearm-magazine"}}
local M=require("scripts.core.logistics_fetch_executor_0527")
local acted,why=M.service_pair(pair,"completed-survival")
assert(not acted and scans==0,"completed survival history restarted physical ammo collection: "..tostring(why))
pair.requested_item="firearm-magazine"
TechPriestsStorageRoleAuthority0686={generic_item_count=function(p,n)
 assert(p==pair and n=="firearm-magazine");return 1 end}
acted,why=M.service_pair(pair,"physical-general-stock")
assert(not acted and scans==0,
 "accessible real ammunition was fetched and deposited back into the same general-storage source")
print("PASS completed survival history does not create new fetches and actual general stock satisfies physical requests")
local source={valid=true,position={x=4,y=0}}
pair.mode="moving-to-scavenge";pair.scavenge={item_name="firearm-magazine",source=source};pair.target=source
M.service_pair(pair,"satisfied-scavenge")
assert(not pair.scavenge and not pair.target and pair.mode=="idle",
 "satisfied unladen legacy scavenge kept monopolizing the independent priest")
pair.scavenge={item_name="firearm-magazine",source=source}
pair.machine_logistics_custody_0528={item="firearm-magazine",count=1}
M.service_pair(pair,"held-cargo")
assert(pair.scavenge and pair.machine_logistics_custody_0528.count==1,
 "held physical work was retired with a planning-only scavenge")
print("PASS satisfied independent scavenge intent retires while actual held cargo remains owned")
prototypes.item["repair-pack"]={}
TechPriestsStorageRoleAuthority0686.generic_item_count=function(_,item)
 return item=="repair-pack"and 5 or 0 end
local Supply=require("scripts.core.station_supply_satisfaction_0639")
local Reserve=require("scripts.core.emergency_supply_reserve_0497")
pair.requested_item="repair-pack"
local supply_order={kind="logistics",source="emergency_acquire",status="active",item="repair-pack"}
pair.order_queue_0469={current=supply_order,pending={}}
assert(Supply.item_satisfied(pair,"repair-pack"),"real canonical repair stock was invisible")
Supply.service_pair(pair,"canonical-repair-stock")
assert(not pair.order_queue_0469.current and supply_order.status=="complete",
 "already-funded maintenance supply request retained factory ownership")
local repair_order={kind="repair",source="repair_executor_0516",status="active",item="repair-pack",
 target={valid=true,health=50,max_health=100}}
pair.order_queue_0469.current=repair_order;pair.requested_item="repair-pack"
Supply.service_pair(pair,"actual-repair-not-supply")
assert(pair.order_queue_0469.current==repair_order and repair_order.status=="active",
 "available repair ingredients falsely completed an actual machine repair")
pair.requested_item="repair-pack";Reserve.service_pair(pair)
assert(pair.order_queue_0469.current==repair_order and repair_order.target.health==50,
 "emergency stock reconciliation completed a repair without real health change")
print("PASS canonical repair stock resolves supply intents while actual repair orders await real health change")
