-- Yield only this planner's unstarted, engine-refused optional capacity.
-- The strategic ratio deficit remains and the same group retries later.
local M={}
local function now()return game and game.tick or 0 end
function M.yield_blocked(pair)
 local op=pair and pair.independent_emergency_operation_0184
 local req=pair and pair.construction_requested_item
 if not(op and op.enabled==true and type(req)=="table"
   and req.source=="magos-stocked-ratio-capacity"
   and req.site_reason=="physical-miners-capacity-shortfall"
   and pair.construction_blocked_reason_0338=="no-miner-site")then return false end
 if pair.construction_task_0338 or pair.construction_custody_0338
   or pair.construction_candidate_0338 then return false end
 local order=pair.order_queue_0469 and pair.order_queue_0469.current or pair.active_order_0469
 if order and order.status=="active"then return false end
 pair.magos_deferred_capacity_request_1282={request=req,group="miners",
   reason="no-miner-site",tick=now(),retry_tick=now()+3600}
 pair.construction_requested_item=nil
 return true
end
function M.retry_allowed(pair,group)
 local d=pair and pair.magos_deferred_capacity_request_1282
 return not(d and d.group==group and now()<(tonumber(d.retry_tick)or 0))
end
return M
