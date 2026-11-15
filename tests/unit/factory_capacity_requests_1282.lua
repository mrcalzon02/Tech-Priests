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
