package.path="tech-priests_src/?.lua;"..package.path
game={tick=100}
local M=require("scripts.core.factory_capacity_requests_1282")
local req={source="magos-stocked-ratio-capacity",site_reason="physical-miners-capacity-shortfall"}
local p={independent_emergency_operation_0184={enabled=true},construction_requested_item=req,
 construction_blocked_reason_0338="no-miner-site"}
p.construction_custody_0338={count=1}
assert(not M.yield_blocked(p)and p.construction_requested_item==req)
p.construction_custody_0338=nil;p.construction_task_0338={}
assert(not M.yield_blocked(p));p.construction_task_0338=nil
p.order_queue_0469={current={status="active",kind="construction"}}
assert(not M.yield_blocked(p));p.order_queue_0469=nil
p.construction_blocked_reason_0338="stock-unavailable"
assert(not M.yield_blocked(p));p.construction_blocked_reason_0338="no-miner-site"
req.source="player";assert(not M.yield_blocked(p));req.source="magos-stocked-ratio-capacity"
p.independent_emergency_operation_0184.enabled=false
assert(not M.yield_blocked(p));p.independent_emergency_operation_0184.enabled=true
assert(M.yield_blocked(p)and p.construction_requested_item==nil)
assert(p.magos_deferred_capacity_request_1282.request==req)
assert(not M.retry_allowed(p,"miners")and M.retry_allowed(p,"smelters"))
game.tick=3700;assert(M.retry_allowed(p,"miners"))
print("PASS engine-refused optional mining capacity yields without cancelling cargo, explicit orders or strategic intent")

local force={recipes={["burner-mining-drill"]={enabled=true},["electric-mining-drill"]={enabled=true}}}
local surface={index=1};local miners={};local supplies=3
surface.find_entities_filtered=function(spec)
 if spec.type=="mining-drill"then return miners end
 if spec.type=="resource"then return{{valid=true,name=spec.name}}end
 error("unexpected capacity scan")
end
prototypes={entity={["burner-mining-drill"]={type="mining-drill"},
 ["electric-mining-drill"]={type="mining-drill"}}}
local function request_capacity(pair)
 return M.request_raw_capacity(pair,function(item)assert(item=="stone");return 1 end)
end
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,name)
 assert(name=="burner-mining-drill"or name=="electric-mining-drill");return supplies end}
local function raw_pair()
 miners={};supplies=3
 return {station={valid=true,unit_number=7,position={x=0,y=0},surface=surface,force=force},
  priest={valid=true,force=force,surface=surface},radius=40,
  independent_emergency_operation_0184={enabled=true,magos_ratio_plan_0257={raw_items={stone=.5}}},
  emergency_craft={bootstrap_resource_0637=true,output_item="stone",required_count=98}}
end
local r=raw_pair();local original=r.emergency_craft
assert(request_capacity(r)and r.emergency_craft==original and supplies==3,
 "long planned raw batch excluded stocked physical mining capacity or spent stock in discovery")
assert(r.construction_requested_item.resource_name=="stone"
 and r.construction_requested_item.raw_prerequisite_1282
 and r.construction_requested_item.item_name=="burner-mining-drill",
 "stone deficit requested another arbitrary iron drill")
assert(not request_capacity(r),"pending original construction was replaced")
for _,field in ipairs{"direct_acquisition_custody_0513","item_family_custody_0702",
 "energy_family_custody_0707","construction_custody_0338","construction_task_0338",
 "emergency_facility_feed_custody_0357","station_cargo_custody_0824"}do
 r=raw_pair();r[field]={count=1}
 assert(not request_capacity(r),"mining proposal displaced custody: "..field)
end
r=raw_pair();r.emergency_craft.direct_due_tick_0513=4000
assert(not request_capacity(r),"mining proposal interrupted an extraction timer")
r=raw_pair();r.order_queue_0469={current={status="active",kind="acquisition"}}
assert(not request_capacity(r),"explicit acquisition order displaced")
r=raw_pair();r.independent_emergency_operation_0184.enabled=false
assert(not request_capacity(r),"player maintenance began autonomous mining capacity")
r=raw_pair();r.independent_emergency_operation_0184.magos_ratio_plan_0257.raw_items.stone=nil
assert(not request_capacity(r),"unplanned reserve acquired factory capacity")
r=raw_pair();supplies=0
assert(not request_capacity(r),"unstocked mining equipment was requested")
r=raw_pair();force.recipes["burner-mining-drill"].enabled=false
assert(request_capacity(r)and r.construction_requested_item.item_name=="electric-mining-drill",
 "locked burner recipe bypassed or available researched alternative ignored")
force.recipes["burner-mining-drill"].enabled=true
r=raw_pair()
local function miner(speed,item)
 return {valid=true,force=force,surface=surface,prototype={mining_speed=speed},
  mining_target={valid=true,name=item or"stone"},bounding_box={{0,0},{2,2}}}
end
miners={miner(.25),miner(.25)}
assert(not request_capacity(r),"sufficient native stone capacity requested redundant drills")
miners={miner(.25),miner(10,"iron-ore")}
assert(request_capacity(r),"unrelated iron mining hid the real stone capacity deficit")
r=raw_pair();local idle=miner(.5);idle.mining_target=nil;miners={idle}
assert(not request_capacity(r),"unpowered drill on real stone was counted as absent")
print("PASS planned raw deficits publish paid resource-specific mining capacity without replacing work, custody or explicit orders")
