-- scripts/core/energy_family_logistics_0707.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical physical energy-item logistics owner. Broker work is discovery only;
-- action_state_arbiter_0488 recommends cached work and single_dispatcher_0510
-- alone calls service_pair. Every removed item remains in persistent custody.

local M = {
  version = "0.1.674-dev",
  storage_key = "energy_family_logistics_0707",
  pickup_reach_sq = 2.56,
  target_reach_sq = 2.56,
  return_reach_sq = 2.56,
  move_priority = 977,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  discovery_interval = 181,
  max_pairs_per_discovery = 8,
  target_fuel_count = 2,
  max_fuel_transfer = 4,
  max_burnt_transfer = 50,
}

local FUEL_PREFERENCE = {
  "uranium-fuel-cell", "nuclear-fuel", "rocket-fuel",
  "solid-fuel", "coal", "wood",
}
local TERMINAL = { complete=true,completed=true,done=true,failed=true,aborted=true }
local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a,b)
  if not(a and b) then return 999999999 end
  local dx=(a.x or 0)-(b.x or 0);local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end
function M.root()
  storage.tech_priests=storage.tech_priests or{}
  local state=storage.tech_priests[M.storage_key]or{
    version=M.version,enabled=true,dispatcher_owned=true,
    discovery_only_broker=true,external_automation_integrated=true,
    fusion_readiness_integrated=true,stats={},recent={},discovery_due={},cursor=0,
  }
  storage.tech_priests[M.storage_key]=state;state.version=M.version
  if state.enabled==nil then state.enabled=true end
  if state.dispatcher_owned==nil then state.dispatcher_owned=true end
  if state.discovery_only_broker==nil then state.discovery_only_broker=true end
  if state.external_automation_integrated==nil then state.external_automation_integrated=true end
  if state.fusion_readiness_integrated==nil then state.fusion_readiness_integrated=true end
  state.stats=state.stats or{};state.recent=state.recent or{}
  state.discovery_due=state.discovery_due or{};state.cursor=tonumber(state.cursor)or 0
  return state
end
local function stat(name,amount)local state=M.root();state.stats[name]=(tonumber(state.stats[name])or 0)+(tonumber(amount)or 1)end
local function record(pair,action,detail,force_log)
  local state=M.root();stat(action)
  local event={tick=now(),action=tostring(action or"event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or"")}
  state.recent[#state.recent+1]=event;while #state.recent>180 do table.remove(state.recent,1)end
  if pair then pair.energy_family_logistics_last_0707=event end
  if force_log and log then log("[Tech-Priests recovery] energy-family "..event.action.." station="..event.station.." priest="..event.priest.." "..event.detail)end
end
local function contents(inv)
  local out={};if not(inv and inv.valid)then return out end
  local ok,values=pcall(function()return inv.get_contents()end);if not(ok and type(values)=="table")then return out end
  for key,value in pairs(values)do local name,count;if type(key)=="string"then name=key;count=type(value)=="table"and tonumber(value.count or value.amount or value[2])or tonumber(value)elseif type(value)=="table"then name=value.name or value.item or value[1];count=tonumber(value.count or value.amount or value[2])end;if type(name)=="string"and(tonumber(count)or 0)>0 then out[#out+1]={name=name,count=tonumber(count)or 1}end end
  table.sort(out,function(a,b)return a.name<b.name end);return out
end
local function item_count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,count=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(count)or 0)or 0 end
local function inv_remove(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,removed=pcall(function()return inv.remove({name=item,count=count})end);return ok and(tonumber(removed)or 0)or 0 end
local function inv_insert(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,inserted=pcall(function()return inv.insert({name=item,count=count})end);return ok and(tonumber(inserted)or 0)or 0 end
local function inv_can_insert(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 1)>0)then return false end;local ok,accepted=pcall(function()return inv.can_insert({name=item,count=count or 1})end);return ok and accepted==true end
local function readiness()return rawget(_G,"TechPriestsEnergyFamilyReadiness0705")or package.loaded["scripts.core.energy_family_readiness_0705"]end
local function storage_authority()return rawget(_G,"TechPriestsStorageRoleAuthority0686")or package.loaded["scripts.core.storage_role_authority_0686"]end
local function service_radius(pair)local radius=tonumber(pair and pair.radius)or 28;if valid_pair(pair)and type(_G.get_station_operating_radius)=="function"then local ok,value=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(value)then radius=tonumber(value)end end;return math.max(8,math.min(radius,96))end
local function home_sources(pair)
  local out,seen={},{};if not valid_pair(pair)then return out end;local radius=service_radius(pair);local home=station_unit(pair)
  local function add(source)local inv=source and source.inv;local entity=source and source.entity;if not(inv and inv.valid and valid(entity))then return end;if entity.surface~=pair.station.surface or entity.force~=pair.station.force then return end;if source.authority_source_station_0573 and tostring(source.authority_source_station_0573)~=tostring(home)then return end;if dist_sq(entity.position,pair.station.position)>radius*radius then return end;local key=safe(inv);if seen[key]then return end;seen[key]=true;out[#out+1]={inv=inv,entity=entity,label=source.source or source.inventory_id or"home-source"}end
  local source_fn=rawget(_G,"tech_priests_inventory_steward_sources_for_pair");if type(source_fn)=="function"then local ok,sources=pcall(source_fn,pair);if ok and type(sources)=="table"then for _,source in ipairs(sources)do add(source)end end end
  if defines and defines.inventory and pair.station.get_inventory then local ok,inv=pcall(function()return pair.station.get_inventory(defines.inventory.chest)end);if ok and inv and inv.valid then add({inv=inv,entity=pair.station,source="station-chest"})end end
  return out
end
local function item_prototype(item)return prototypes and prototypes.item and prototypes.item[item]or nil end
local function fuel_value(item)local prototype=item_prototype(item);if not prototype then return 0 end;local value=0;pcall(function()value=tonumber(prototype.fuel_value)or 0 end);return value end
local function burnt_result(item)local prototype=item_prototype(item);if not prototype then return nil end;local result;pcall(function()result=prototype.burnt_result end);if type(result)=="table"then return result.name end;return type(result)=="string"and result or nil end
local function fuel_compatible(report,item)
  if not(report and report.fuel_inventory and report.fuel_inventory.valid)then return false,"missing-fuel-inventory"end
  if fuel_value(item)<=0 or not inv_can_insert(report.fuel_inventory,item,1)then return false,"fuel-incompatible"end
  local result=burnt_result(item);if result then if not(report.burnt_inventory and report.burnt_inventory.valid)then return false,"missing-burnt-result-inventory"end;if not inv_can_insert(report.burnt_inventory,result,1)then return false,"burnt-result-incompatible:"..result end end
  return true,"compatible"
end
local function source_for_item(pair,report,item)
  if not fuel_compatible(report,item)then return nil end;local best
  for _,source in ipairs(home_sources(pair))do local count=item_count(source.inv,item);if count>0 then local score=dist_sq(pair.priest.position,source.entity.position)-math.min(count,100);if not best or score<best.score then best={item=item,count=count,inv=source.inv,entity=source.entity,label=source.label,score=score}end end end
  return best
end
local function compatible_request_item(report)
  for _,item in ipairs(FUEL_PREFERENCE)do if item_prototype(item)and fuel_compatible(report,item)then return item end end
  local names={};for name in pairs(prototypes and prototypes.item or{})do if fuel_value(name)>0 and fuel_compatible(report,name)then names[#names+1]=name end end;table.sort(names);return names[1]
end
local function select_fuel(pair,report)
  local current=report and report.burner and report.burner.currently_burning;if current then local source=source_for_item(pair,report,current);if source then return source,current end end
  for _,item in ipairs(FUEL_PREFERENCE)do local source=source_for_item(pair,report,item);if source then return source,item end end
  local requested=compatible_request_item(report);return requested and source_for_item(pair,report,requested)or nil,requested
end
local function reservations_module()
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations");if ok then reservations=module end end;return reservations
end
local function ensure_reservation_category()
  local reservations=reservations_module();if not reservations then return nil end;local category="energy-family-logistics";local found=false;for _,value in ipairs(reservations.categories or{})do if value==category then found=true break end end;if not found then reservations.categories=reservations.categories or{};reservations.categories[#reservations.categories+1]=category end;local state=type(reservations.root)=="function"and reservations.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return reservations
end
local function claim_target(pair,task)
  local reservations=ensure_reservation_category();if not(reservations and type(reservations.claim)=="function"and valid(task.target))then return false,"reservation-unavailable"end
  local ok,why=reservations.claim("energy-family-logistics",task.target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family=task.family,item=task.item,source="energy-family-logistics-0707"});task.reserved_0707=ok==true;return ok==true,why
end
local function release_target(pair,task)if not(task and valid(task.target))then return false end;local reservations=reservations_module();if reservations and type(reservations.release)=="function"then local ok,released=pcall(reservations.release,"energy-family-logistics",task.target,pair);return ok and released==true end;return false end
local function refresh_reports(pair)local doctrine=readiness();if doctrine and type(doctrine.scan_pair)=="function"then local ok,result=pcall(doctrine.scan_pair,pair,true);if not ok then record(pair,"readiness-refresh-error",result,true)end end;return pair.energy_family_reports_0705 or{}end
local function candidate_from_reports(pair)
  local reports=pair.energy_family_reports_0705;if type(reports)~="table"then reports=refresh_reports(pair)end;local burnt,fuel
  for _,report in ipairs(reports or{})do if valid(report.entity)and report.connected_item_automation~=true then
    if report.burnt_inventory and report.burnt_inventory.valid and(tonumber(report.burnt_count)or 0)>0 then local entries=contents(report.burnt_inventory);local entry=entries[1];if entry then local score=dist_sq(pair.priest.position,report.entity.position);if not burnt or score<burnt.score then burnt={family="burnt-result-clear",target=report.entity,target_name=report.entity_name,target_unit=report.entity_unit,item=entry.name,count=math.min(entry.count,M.max_burnt_transfer),source_inv=report.burnt_inventory,source_entity=report.entity,source_label="burnt-result-inventory",report=report,score=score}end end end
    if report.state=="fuel-service-eligible"and report.fuel_inventory and report.fuel_inventory.valid then local source,item=select_fuel(pair,report);if item then local score=dist_sq(pair.priest.position,report.entity.position);if not fuel or score<fuel.score then fuel={family="energy-fuel",target=report.entity,target_name=report.entity_name,target_unit=report.entity_unit,item=item,count=math.min(math.max(1,M.target_fuel_count-(tonumber(report.fuel_count)or 0)),M.max_fuel_transfer),source=source,report=report,score=score}end end end
  end end;return burnt or fuel
end
local function request_move(pair,target,reason)
  if not(valid_pair(pair)and valid(target))then return false end;local request=rawget(_G,"tech_priests_request_movement_0418");if type(request)~="function"then return false end
  local ok,accepted=pcall(request,pair,target.position,reason or"energy-family-logistics-0707",{owner="energy-family-logistics-0707",priority=M.move_priority,ttl=M.move_ttl,radius=1.2,distraction=defines and defines.distraction and defines.distraction.none or nil});return ok and accepted==true
end
local function matching_request(request,task)return type(request)=="table"and request.source=="energy-family-logistics-0707"and request.item==task.item and(not request.target_unit or tostring(request.target_unit)==tostring(task.target_unit))end
local function clear_requests(pair,task)for _,field in ipairs({"active_supply_request","logistic_requested_item"})do if matching_request(pair[field],task)then pair[field]=nil end end end
local function create_request(pair,task)
  pair.active_supply_request={item=task.item,count=task.count,source="energy-family-logistics-0707",purpose="energy-fuel",target_unit=task.target_unit,target_name=task.target_name,tick=now()}
  pair.logistic_requested_item={item=task.item,count=task.count,source="energy-family-logistics-0707",purpose="energy-fuel",target_unit=task.target_unit}
  task.phase="waiting-source";task.request_tick=task.request_tick or now();stat("fuel-item-requests")
end
local function sync_custody(pair,task,reason)
  local carried=task and task.carried;if carried and carried.item and(tonumber(carried.count)or 0)>0 then pair.energy_family_custody_0707={version=M.version,tick=now(),family=task.family,item=carried.item,count=carried.count,target=task.target,target_unit=task.target_unit,target_name=task.target_name,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,reason=reason or task.phase};return true end;pair.energy_family_custody_0707=nil;return false
end
local function finish_task(pair,task,reason)
  release_target(pair,task);clear_requests(pair,task);pair.energy_family_custody_0707=nil;task.phase="complete";task.completed_tick=now();task.result=reason or"complete";pair.energy_family_logistics_last_task_0707=task;pair.energy_family_logistics_0707=nil;record(pair,"energy-task-finished",safe(task.family).." "..safe(reason));return{processed=1,acted=1,detail=reason or"complete"}
end
local function abort_without_custody(pair,task,reason)
  release_target(pair,task);clear_requests(pair,task);task.phase="aborted";task.completed_tick=now();task.result=reason;pair.energy_family_logistics_last_task_0707=task;pair.energy_family_logistics_0707=nil;record(pair,"energy-task-aborted",safe(task.family).." "..safe(reason));return{processed=1,blocked=1,detail=reason}
end
local function restore_orphan_custody(pair)
  local custody=pair.energy_family_custody_0707;if pair.energy_family_logistics_0707 or type(custody)~="table"or not custody.item or(tonumber(custody.count)or 0)<=0 then return false end
  pair.energy_family_logistics_0707={version=M.version,family=custody.family or"custody-recovery",phase="return-custody",item=custody.item,count=custody.count,carried={item=custody.item,count=custody.count},target=custody.target,target_unit=custody.target_unit,target_name=custody.target_name,source_entity=custody.source_entity,source_inv=custody.source_inv,source_label=custody.source_label,started_tick=now(),custody_recovery=true};record(pair,"energy-orphan-custody-restored",custody.item.." x"..safe(custody.count),true);return true
end
local function source_current(pair,task)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity)and item_count(task.source_inv,task.item)>0 then return{inv=task.source_inv,entity=task.source_entity,item=task.item,count=item_count(task.source_inv,task.item),label=task.source_label}end
  if task.family~="energy-fuel"or not task.report then return nil end;return source_for_item(pair,task.report,task.item)
end
local function deposit_exact(pair,item,count,reason)local authority=storage_authority();if authority and type(authority.deposit_exact)=="function"then return authority.deposit_exact(pair,item,count,reason,{})end;return false,"storage-authority-unavailable",0 end
local function return_custody(pair,task)
  local carried=task.carried;if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return finish_task(pair,task,"empty-custody")end
  local return_source=task.family=="energy-fuel"and valid(task.source_entity)and task.source_entity or nil;local target=return_source or pair.station
  if dist_sq(pair.priest.position,target.position)>M.return_reach_sq then task.phase="return-custody";sync_custody(pair,task,return_source and"returning-source"or"returning-station");if not request_move(pair,target,"energy-custody-return-0707")then return{processed=1,blocked=1,detail="return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-custody"}end
  if return_source and task.source_inv and task.source_inv.valid then local inserted=inv_insert(task.source_inv,carried.item,carried.count);if inserted>0 then carried.count=carried.count-inserted end;if carried.count<=0 then return finish_task(pair,task,"custody-returned-source")end;task.source_entity=nil;task.source_inv=nil;task.source_label="station-storage";sync_custody(pair,task,"source-return-partial");if not request_move(pair,pair.station,"energy-custody-station-fallback-0707")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-station"}end
  local accepted,why,inserted=deposit_exact(pair,carried.item,carried.count,task.family=="burnt-result-clear"and"energy-burnt-result-retention-0707"or"energy-fuel-return-0707");inserted=tonumber(inserted)or 0;if accepted==true and inserted==carried.count then carried.count=0;return finish_task(pair,task,"custody-stored")end;sync_custody(pair,task,"station-storage-blocked");record(pair,"energy-custody-storage-blocked",carried.item.." remaining="..safe(carried.count).." reason="..safe(why));return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
local function revalidate_target(pair,task)
  if not valid(task.target)then return nil,"target-invalid"end;local doctrine=readiness();if not(doctrine and type(doctrine.inspect_entity)=="function")then return nil,"readiness-unavailable"end
  local report=doctrine.inspect_entity(pair,task.target,true);task.report=report;if not report then return nil,"readiness-failed"end;if report.connected_item_automation==true or report.state=="external-item-automation-owned"then return report,"external-item-automation-owned"end;if report.state~="fuel-service-eligible"then return report,"target-not-eligible:"..safe(report.state)end;local compatible,why=fuel_compatible(report,task.item);if not compatible then return report,why end;return report,"ready"
end
local function candidate_valid(pair,selected)
  if not(valid_pair(pair)and type(selected)=="table"and valid(selected.target))then return false end;if selected.target.surface~=pair.station.surface or selected.target.force~=pair.station.force then return false end
  if selected.family=="burnt-result-clear"then return selected.source_inv and selected.source_inv.valid and item_count(selected.source_inv,selected.item)>0 end
  if selected.family=="energy-fuel"then local doctrine=readiness();local report=doctrine and type(doctrine.inspect_entity)=="function"and doctrine.inspect_entity(pair,selected.target,true)or nil;return report and report.state=="fuel-service-eligible"and report.connected_item_automation~=true and fuel_compatible(report,selected.item)end;return false
end
local function discover_pair(pair)
  if not valid_pair(pair)then return false,"invalid-pair"end;if pair.energy_family_logistics_0707 or pair.energy_family_custody_0707 then pair.energy_family_candidate_0707=nil;return false,"active-task"end
  local state=M.root();local key=tostring(station_unit(pair)or"?");local existing=pair.energy_family_candidate_0707;if candidate_valid(pair,existing)then return false,"candidate-retained"end;pair.energy_family_candidate_0707=nil;if(tonumber(state.discovery_due[key])or 0)>now()then return false,"cooldown"end;state.discovery_due[key]=now()+M.discovery_interval;refresh_reports(pair);local selected=candidate_from_reports(pair);if not selected then stat("discovery-empty");return false,"no-candidate"end;selected.version=M.version;selected.discovered_tick=now();pair.energy_family_candidate_0707=selected;record(pair,"energy-candidate-discovered",selected.family.." "..safe(selected.item).." -> "..safe(selected.target_name));return true,"candidate-discovered"
end
local function begin_task(pair,selected,reason)
  local task={version=M.version,family=selected.family,phase="new",target=selected.target,target_name=selected.target_name,target_unit=selected.target_unit,item=selected.item,count=math.max(1,tonumber(selected.count)or 1),source_inv=selected.source_inv or(selected.source and selected.source.inv),source_entity=selected.source_entity or(selected.source and selected.source.entity),source_label=selected.source_label or(selected.source and selected.source.label),report=selected.report,started_tick=now(),reason=reason}
  local claimed,why=claim_target(pair,task);if not claimed then return{processed=1,blocked=1,detail="target-reserved:"..safe(why)}end;pair.energy_family_candidate_0707=nil;pair.energy_family_logistics_0707=task
  if task.family=="burnt-result-clear"then task.phase="move-to-source";if not request_move(pair,task.target,"energy-burnt-result-pickup-0707")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;record(pair,"burnt-result-task-began",task.item.." x"..safe(task.count).." from "..safe(task.target_name));return{processed=1,waiting=1,detail="moving-to-burnt-result"}end
  if not valid(task.source_entity)then create_request(pair,task);record(pair,"fuel-task-waiting-source",task.item.." -> "..safe(task.target_name));return{processed=1,waiting=1,detail="waiting-source"}end
  task.phase="move-to-source";if not request_move(pair,task.source_entity,"energy-fuel-source-0707")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;record(pair,"fuel-task-began",task.item.." x"..safe(task.count).." -> "..safe(task.target_name));return{processed=1,waiting=1,detail="moving-to-fuel-source"}
end
local function continue_task(pair,task)
  if TERMINAL[lower(task.phase)]then return finish_task(pair,task,task.phase)end;if task.phase=="return-custody"then return return_custody(pair,task)end
  if valid(pair.combat_target)then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,"combat-suspended");return return_custody(pair,task)end;return abort_without_custody(pair,task,"combat-priority")end
  if not valid(task.target)then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";return return_custody(pair,task)end;return abort_without_custody(pair,task,"target-invalid")end
  local doctrine=readiness();if doctrine and type(doctrine.connected_item_automation)=="function"then local automated=doctrine.connected_item_automation(task.target);if automated then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,"external-item-automation-owned");return return_custody(pair,task)end;return abort_without_custody(pair,task,"external-item-automation-owned")end end
  if task.phase=="waiting-source"then if now()-(tonumber(task.request_tick)or now())>=M.request_timeout then return abort_without_custody(pair,task,"fuel-source-timeout")end;local source=source_current(pair,task);if not source then create_request(pair,task);return{processed=1,waiting=1,detail="waiting-source"}end;task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label;task.phase="move-to-source";if not request_move(pair,source.entity,"energy-fuel-source-ready-0707")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="source-ready"}end
  if task.phase=="move-to-source"then local source;if task.family=="burnt-result-clear"then source={inv=task.source_inv,entity=task.target,count=item_count(task.source_inv,task.item),label="burnt-result-inventory"}else source=source_current(pair,task)end;if not(source and source.inv and source.inv.valid and valid(source.entity)and(tonumber(source.count)or 0)>0)then if task.family=="energy-fuel"then task.phase="waiting-source";task.request_tick=now();create_request(pair,task);return{processed=1,waiting=1,detail="source-lost"}end;return abort_without_custody(pair,task,"burnt-result-source-empty")end;if dist_sq(pair.priest.position,source.entity.position)>M.pickup_reach_sq then if not request_move(pair,source.entity,"energy-item-source-0707")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="moving-to-source"}end;local cap=task.family=="energy-fuel"and M.max_fuel_transfer or M.max_burnt_transfer;local want=math.max(1,math.min(task.count,source.count,cap));local removed=inv_remove(source.inv,task.item,want);if removed<=0 then return abort_without_custody(pair,task,"source-remove-failed")end;task.carried={item=task.item,count=removed};task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label;clear_requests(pair,task);sync_custody(pair,task,"picked-up");record(pair,"energy-item-picked-up",task.family.." "..task.item.." x"..safe(removed));if task.family=="burnt-result-clear"then task.phase="return-custody";if not request_move(pair,pair.station,"energy-burnt-return-0707")then return{processed=1,acted=1,blocked=1,detail="return-movement-blocked"}end;return{processed=1,acted=1,waiting=1,detail="returning-burnt-result"}end;task.phase="move-to-target";if not request_move(pair,task.target,"energy-fuel-delivery-0707")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,acted=1,blocked=1,detail="target-movement-blocked"}end;return{processed=1,acted=1,waiting=1,detail="delivering-fuel"}end
  if task.phase=="move-to-target"then if dist_sq(pair.priest.position,task.target.position)>M.target_reach_sq then if not request_move(pair,task.target,"energy-fuel-delivery-0707")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,blocked=1,detail="target-movement-blocked"}end;sync_custody(pair,task,"moving-to-target");return{processed=1,waiting=1,detail="moving-to-target"}end;local report,why=revalidate_target(pair,task);if not report or why~="ready"then task.phase="return-custody";sync_custody(pair,task,why);record(pair,"fuel-target-became-ineligible",safe(why));return return_custody(pair,task)end;local carried=task.carried;if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return abort_without_custody(pair,task,"custody-missing")end;local inserted=inv_insert(report.fuel_inventory,carried.item,carried.count);if inserted>0 then carried.count=carried.count-inserted;stat("fuel-items-delivered",inserted);record(pair,"fuel-delivered",carried.item.." x"..safe(inserted).." -> "..safe(task.target_name))end;if carried.count<=0 then return finish_task(pair,task,"fuel-delivered")end;task.phase="return-custody";sync_custody(pair,task,inserted>0 and"fuel-partial"or"fuel-insert-blocked");return{processed=1,acted=inserted>0 and 1 or 0,blocked=inserted>0 and 0 or 1,detail=inserted>0 and"partial-fuel-delivery"or"fuel-insert-blocked"}end
  return{processed=1,failed=1,detail="unknown-phase:"..safe(task.phase)}
end
function M.abort_pair(pair,reason)
  if not valid_pair(pair)then return false,"invalid-pair"end;restore_orphan_custody(pair);local task=pair.energy_family_logistics_0707;if type(task)~="table"then return false,"no-task"end;if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,reason or"abort");local result=return_custody(pair,task);return(tonumber(result.acted)or 0)>0,result.detail end;local result=abort_without_custody(pair,task,reason or"aborted");return false,result.detail
end
function M.service_pair(pair,reason)
  local state=M.root();if state.enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;restore_orphan_custody(pair);local task=pair.energy_family_logistics_0707;if type(task)=="table"then return continue_task(pair,task)end;local selected=pair.energy_family_candidate_0707;if not candidate_valid(pair,selected)then pair.energy_family_candidate_0707=nil;return{processed=1,waiting=1,detail="no-energy-candidate"}end;return begin_task(pair,selected,reason or"dispatcher")
end
local function action_target(pair,task)
  if task.phase=="move-to-source"and valid(task.source_entity or task.target)then local target=task.source_entity or task.target;return target,"collect-energy-item","Collecting "..safe(task.item).." for "..safe(task.target_name)end
  if task.phase=="move-to-target"and valid(task.target)then return task.target,"deliver-energy-fuel","Delivering "..safe(task.item).." to "..safe(task.target_name)end
  if task.phase=="return-custody"then local target=task.family=="energy-fuel"and valid(task.source_entity)and task.source_entity or pair.station;return target,"return-energy-custody","Returning "..safe(task.item)end
  if task.phase=="waiting-source"and valid(task.target)then return task.target,"waiting-energy-source","Waiting for "..safe(task.item).." for "..safe(task.target_name)end
  return valid(task.target)and task.target or pair.station,task.phase or"energy-family","Energy-family logistics"
end
function M.recommend_action(pair)
  if M.root().enabled==false or not valid_pair(pair)then return nil end;local task=pair.energy_family_logistics_0707;local custody=pair.energy_family_custody_0707
  if type(task)=="table"then local target,phase,label=action_target(pair,task);return{kind="energy-family-logistics",family="energy-family-logistics",active=true,target=target,position=valid(target)and target.position or nil,item=task.item,phase=phase,label=label,reason=task.reason or task.phase,source="energy_family_logistics_0707"}end
  if type(custody)=="table"and custody.item and(tonumber(custody.count)or 0)>0 then local target=custody.family=="energy-fuel"and valid(custody.source_entity)and custody.source_entity or pair.station;return{kind="energy-family-logistics",family="energy-family-logistics",active=true,target=target,position=target.position,item=custody.item,phase="return-energy-custody",label="Returning energy custody",reason=custody.reason or"orphan-custody",source="energy_family_logistics_0707"}end
  local selected=pair.energy_family_candidate_0707;if not candidate_valid(pair,selected)then return nil end;return{kind="energy-family-logistics",family="energy-family-logistics",active=false,target=selected.target,position=selected.target.position,item=selected.item,phase="candidate",label=selected.family=="energy-fuel"and"Energy fuel delivery"or"Burnt-result evacuation",reason="broker-discovered-candidate",source="energy_family_logistics_0707"}
end
local function discover_pairs(budget)
  local state=M.root();if state.enabled==false then return{processed=0,acted=0,detail="disabled"}end;local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return{processed=0,acted=0,detail="no-pairs"}end
  local limit=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_discovery)));local start=state.cursor%#list+1;local processed,discovered,failed=0,0,0
  for index=0,limit-1 do local pair=list[((start+index-1)%#list)+1].pair;processed=processed+1;local ok,changed=pcall(discover_pair,pair);if ok and changed==true then discovered=discovered+1 elseif not ok then failed=failed+1;record(pair,"energy-discovery-error",changed,true)end end
  state.cursor=(start+limit-2)%#list+1;return{processed=processed,acted=discovered,failed=failed,exhausted=#list>limit,detail="discovered="..discovered.." failed="..failed}
end
local function patch_diagnostics()
  local diagnostics=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(diagnostics and type(diagnostics.pair_dump_lines)=="function")then return false end;if diagnostics.energy_family_logistics_0707_wrapped then return true end;diagnostics.energy_family_logistics_0707_wrapped=true;local previous=diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local state=M.root();lines[#lines+1]="PAIR-DUMP-0468 ENERGY-FAMILY-LOGISTICS-0707 version="..M.version.." dispatcher_owned="..safe(state.dispatcher_owned).." discovery_only="..safe(state.discovery_only_broker).." requests="..safe(state.stats["fuel-item-requests"]or 0).." pickups="..safe(state.stats["energy-item-picked-up"]or 0).." delivered="..safe(state.stats["fuel-items-delivered"]or 0).." custody_restored="..safe(state.stats["energy-orphan-custody-restored"]or 0).." direct_timing=0 leaf_authority=0 loose_movement_success=0";return lines end;return true
end
function M.install()
  M.root();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(broker and type(broker.register_service)=="function")then return false end
  local service=broker.register_service({name="energy_family_discovery_0707",category="discovery",interval=M.discovery_interval,priority=58,budget=M.max_pairs_per_discovery,note="discovery only for readiness-approved energy fuel and burnt-result work",fn=function(_,budget)return discover_pairs(budget)end})
  if not service then return false end;patch_diagnostics();_G.TechPriestsEnergyFamilyLogistics0707=M;if log then log("[Tech-Priests recovery] dispatcher-owned energy-family logistics installed")end;return true
end
return M
