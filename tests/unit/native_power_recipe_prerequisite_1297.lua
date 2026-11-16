package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.native_power_recipe_prerequisite_1297")
game={tick=1000}
local force={index=1,recipes={["steam-engine"]={enabled=true}}}
local surface={index=2};local installed={}
surface.find_entities_filtered=function(q)assert(q.name=="steam-engine"and q.force==force);return installed end
local station={valid=true,unit_number=3,force=force,surface=surface,position={x=0,y=0}}
local parent={output_item="lab",strict_recipe_0647=true,facility_only_0647=true,infrastructure_first_0640=true,
 target_stock_0647=3,facility_started_tick_0514=20,current={marker="original native parent"}}
local gate={item="lab",tick=20}
local function fixture()
 installed={}
 return{station=station,priest={valid=true,force=force,surface=surface},radius=40,
 independent_emergency_operation_0184={enabled=true},emergency_craft=parent,local_infrastructure_gate_0640=gate,
 power_setup_observation_1252={tick=game.tick,load_unit=5,reason="equipment-shortage:steam-engine"}}
end
local p=fixture()
assert(M.begin(p,"equipment-shortage:steam-engine")and p.emergency_craft==nil)
local record=p.native_power_recipe_prerequisite_1297
assert(record.parent_task==parent and record.parent_gate==gate and M.request_owned(p))
local root=p.infrastructure_recipe_request_0647
assert(root.item=="steam-engine"and root.target_stock_0647==1)
assert(not M.begin(p,"equipment-shortage:steam-engine"),"nested suspension replaced native parent")
assert(not M.restore(p),"loose/absent power kit resumed the parent before construction")
p.infrastructure_recipe_request_0647={item="iron-gear-wheel",parent_request_0647=root}
assert(M.request_owned(p),"power ancestry was lost across an ordinary child recipe")
p.emergency_craft={output_item="iron-gear-wheel"}
installed={{valid=true,name="steam-engine",force=force,surface=surface}}
p.power_setup_observation_1252.reason="shared-native-electric-network-await-fuel-or-generation"
assert(not M.restore(p),"native parent overwrote an unfinished ingredient transaction")
p.emergency_craft=nil;p.construction_custody_0338={count=1}
assert(not M.restore(p),"parent displaced actual construction custody")
p.construction_custody_0338=nil
local owned=p.infrastructure_recipe_request_0647;p.infrastructure_recipe_request_0647={item="pipe"}
assert(not M.restore(p),"parent displaced a foreign request")
p.infrastructure_recipe_request_0647=owned
assert(M.restore(p)and p.emergency_craft==parent and p.local_infrastructure_gate_0640==gate)
assert(parent.target_stock_0647==3 and parent.facility_started_tick_0514==20 and parent.current.marker=="original native parent")
assert(not p.native_power_recipe_prerequisite_1297 and not p.infrastructure_recipe_request_0647)
assert(p.native_power_recipe_last_1297.parent_item=="lab")
for _,field in ipairs{"active_task","active_task_0285","construction_request","supply_request","direct_acquisition_custody_0513","construction_task_0338","emergency_facility_feed_custody_0357","movement_request_0418","item_family_custody_0702"}do
 local q=fixture();local held={count=3};q[field]=held
 assert(not M.begin(q,"equipment-shortage:steam-engine")and q[field]==held and q.emergency_craft==parent,field)
end
local q=fixture();q.active_order_0469={status="active",kind="assignment"}
assert(not M.begin(q,"equipment-shortage:steam-engine"),"active user order was suspended")
q=fixture();q.independent_emergency_operation_0184.enabled=false
assert(not M.begin(q,"equipment-shortage:steam-engine"),"maintenance force began independent kit manufacture")
q=fixture();q.infrastructure_recipe_request_0647={item="iron-plate"}
assert(not M.begin(q,"equipment-shortage:steam-engine"),"foreign parent request was replaced")
q=fixture();q.power_setup_observation_1252.tick=999
assert(not M.begin(q,"equipment-shortage:steam-engine"),"stale shortage was admitted")
q=fixture();force.recipes["steam-engine"].enabled=false
assert(not M.begin(q,"equipment-shortage:steam-engine"),"locked engine recipe was scheduled")
force.recipes["steam-engine"].enabled=true
q=fixture();surface.platform={valid=true}
assert(not M.begin(q,"equipment-shortage:steam-engine"),"terrestrial power dependency reached a platform")
surface.platform=nil
print("PASS missing native power kit retains exact science parent; real installation, ancestry, context, order, custody and maintenance guards")
