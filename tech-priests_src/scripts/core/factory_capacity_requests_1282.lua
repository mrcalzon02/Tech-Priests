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
-- A long, explicitly planned raw batch must be able to install its stocked
-- native mining capacity instead of excluding construction until hand mining
-- finishes the entire reserve. This publishes intent only; 0338 still owns
-- native siting, source pickup, exact item debit and placement.
function M.request_raw_capacity(pair,yield_fn)
 local op=pair and pair.independent_emergency_operation_0184
 local plan=op and op.magos_ratio_plan_0257
 local task=pair and(pair.direct_acquisition_task_0336 or pair.emergency_craft)
 if not(op and op.enabled==true and type(task)=="table"
   and task.bootstrap_resource_0637==true and not task.direct_due_tick_0513
   and not task.direct_remaining_ticks_0513 and type(plan)=="table")then return false end
 local item=task.output_item or task.item_name
 if item~="stone"and item~="iron-ore"and item~="copper-ore"and item~="coal"then return false end
 local rate=tonumber(plan.raw_items and plan.raw_items[item])or 0
 if rate<=0 or (tonumber(task.required_count or task.count)or 0)<8 then return false end
 M.yield_blocked(pair)
 if not M.retry_allowed(pair,"miners")then return false end
 if pair.combat_target and pair.combat_target.valid then return false end
 for _,field in ipairs{"direct_acquisition_custody_0513","construction_task_0338",
   "construction_custody_0338","construction_candidate_0338","construction_requested_item",
   "construction_request","structure_construction_requested_item","pending_construction","build_request",
   "machine_logistics_custody_0528","item_family_custody_0702","energy_family_custody_0707",
   "inventory_transfer_custody_0687","emergency_production_custody_0514",
   "emergency_facility_feed_custody_0357","station_cargo_custody_0824",
   "repair_pack_custody_0516","consecration_refund_custody_0515",
   "rocket_silo_custody_0710","artillery_custody_0713","roboport_repair_custody_0715",
   "defense_task_0259","remote_drill_request_1011","robot_network_request_0338"}do
  if pair[field]then return false end
 end
 if pair.machine_logistics_0528 and pair.machine_logistics_0528.custody then return false end
 local order=pair.order_queue_0469 and pair.order_queue_0469.current or pair.active_order_0469
 if order and order.status=="active"then return false end
 local station=pair.station
 if not(station and station.valid and station.surface and station.force
   and pair.priest and pair.priest.valid and pair.priest.force==station.force
   and pair.priest.surface==station.surface)then return false end
 if type(yield_fn)~="function"then return false end
 local read,yield=pcall(yield_fn,item)
 if not(read and type(yield)=="number"and yield>0)then return false end
 local ok,miners=pcall(function()return station.surface.find_entities_filtered{
   position=station.position,radius=math.max(8,tonumber(pair.radius)or 28),
   force=station.force,type="mining-drill",limit=256}end)
 if not(ok and type(miners)=="table")then return false end
 local capacity=0
 for _,miner in pairs(miners)do
  if miner.valid and miner.force==station.force and miner.surface==station.surface then
   local inspected,matching,speed=pcall(function()
    local target=miner.mining_target
    local matches=target and target.valid and target.name==item
    if not target and miner.bounding_box then
     local found=station.surface.find_entities_filtered{
       area=miner.bounding_box,type="resource",name=item,limit=1}
     matches=found and #found>0
    end
    return matches,miner.prototype.mining_speed
   end)
   if not inspected then return false end
   if matching then
    if type(speed)~="number"or speed<=0 then return false end
    capacity=capacity+speed*yield
   end
  end
 end
 if capacity>=rate then return false end
 local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
 if not(authority and type(authority.generic_item_count)=="function")then return false end
 for _,name in ipairs{"burner-mining-drill","electric-mining-drill"}do
  local recipe=station.force.recipes and station.force.recipes[name]
  local proto=prototypes and prototypes.entity and prototypes.entity[name]
  local stocked,n=pcall(authority.generic_item_count,pair,name)
  if recipe and recipe.enabled==true and proto and proto.type=="mining-drill"
    and stocked and type(n)=="number"and n>0 then
   pair.construction_requested_item={item_name=name,entity_name=name,category="miner",
    source="magos-stocked-ratio-capacity",site_reason="physical-miners-capacity-shortfall",
    resource_name=item,raw_prerequisite_1282=true}
   return true,"stocked-raw-mining-capacity-requested"
  end
 end
 return false
end
return M
