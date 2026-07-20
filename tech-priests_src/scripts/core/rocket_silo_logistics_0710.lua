-- scripts/core/rocket_silo_logistics_0710.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical physical manual rocket-silo item logistics owner. Broker work is
-- discovery only; action_state_arbiter_0488 recommends cached work and
-- single_dispatcher_0510 alone calls service_pair. Removed items retain custody.

local M = {
  version = "0.1.674-dev",
  storage_key = "rocket_silo_logistics_0710",
  pickup_reach_sq = 2.56,
  target_reach_sq = 2.56,
  return_reach_sq = 2.56,
  move_priority = 975,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  discovery_interval = 197,
  max_pairs_per_discovery = 6,
  max_input_transfer = 20,
  max_trash_transfer = 50,
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
  if not(a and b)then return 999999999 end
  local dx=(a.x or 0)-(b.x or 0);local dy=(a.y or 0)-(b.y or 0)
  return dx*dx+dy*dy
end
function M.root()
  storage.tech_priests=storage.tech_priests or{}
  local state=storage.tech_priests[M.storage_key]or{
    version=M.version,enabled=true,dispatcher_owned=true,
    discovery_only_broker=true,live_ownership_integrated=true,
    stats={},recent={},discovery_due={},cursor=0,
  }
  storage.tech_priests[M.storage_key]=state;state.version=M.version
  if state.enabled==nil then state.enabled=true end
  if state.dispatcher_owned==nil then state.dispatcher_owned=true end
  if state.discovery_only_broker==nil then state.discovery_only_broker=true end
  if state.live_ownership_integrated==nil then state.live_ownership_integrated=true end
  state.stats=state.stats or{};state.recent=state.recent or{}
  state.discovery_due=state.discovery_due or{};state.cursor=tonumber(state.cursor)or 0
  return state
end
local function stat(name,amount)
  local state=M.root();state.stats[name]=(tonumber(state.stats[name])or 0)+(tonumber(amount)or 1)
end
local function record(pair,action,detail,force_log)
  local state=M.root();stat(action)
  local event={tick=now(),action=tostring(action or"event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or"")}
  state.recent[#state.recent+1]=event;while #state.recent>180 do table.remove(state.recent,1)end
  if pair then pair.rocket_silo_logistics_last_0710=event end
  if force_log and log then log("[Tech-Priests recovery] rocket-silo "..event.action.." station="..event.station.." priest="..event.priest.." "..event.detail)end
end
local function contents(inv)
  local out={};if not(inv and inv.valid)then return out end
  local ok,values=pcall(function()return inv.get_contents()end);if not(ok and type(values)=="table")then return out end
  for key,value in pairs(values)do
    local name,count
    if type(key)=="string"then name=key;count=type(value)=="table"and tonumber(value.count or value.amount or value[2])or tonumber(value)
    elseif type(value)=="table"then name=value.name or value.item or value[1];count=tonumber(value.count or value.amount or value[2])end
    if type(name)=="string"and(tonumber(count)or 0)>0 then out[#out+1]={name=name,count=tonumber(count)or 1}end
  end
  table.sort(out,function(a,b)return a.name<b.name end);return out
end
local function item_count(inv,item)
  if not(inv and inv.valid and item)then return 0 end
  local ok,count=pcall(function()return inv.get_item_count(item)end)
  return ok and(tonumber(count)or 0)or 0
end
local function inv_remove(inv,item,count)
  if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end
  local ok,removed=pcall(function()return inv.remove({name=item,count=count})end)
  return ok and(tonumber(removed)or 0)or 0
end
local function inv_insert(inv,item,count)
  if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end
  local ok,inserted=pcall(function()return inv.insert({name=item,count=count})end)
  return ok and(tonumber(inserted)or 0)or 0
end
local function inv_can_insert(inv,item,count)
  if not(inv and inv.valid and item and(tonumber(count)or 1)>0)then return false end
  local ok,accepted=pcall(function()return inv.can_insert({name=item,count=count or 1})end)
  return ok and accepted==true
end
local function readiness()
  return rawget(_G,"TechPriestsRocketSiloReadiness0709")or package.loaded["scripts.core.rocket_silo_readiness_0709"]
end
local function storage_authority()
  return rawget(_G,"TechPriestsStorageRoleAuthority0686")or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function service_radius(pair)
  local radius=tonumber(pair and pair.radius)or 28
  if valid_pair(pair)and type(_G.get_station_operating_radius)=="function"then local ok,value=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(value)then radius=tonumber(value)end end
  return math.max(8,math.min(radius,96))
end
local function home_sources(pair)
  local out,seen={},{};if not valid_pair(pair)then return out end
  local radius=service_radius(pair);local home=station_unit(pair)
  local function add(source)
    local inv=source and source.inv;local entity=source and source.entity
    if not(inv and inv.valid and valid(entity))then return end
    if entity.surface~=pair.station.surface or entity.force~=pair.station.force then return end
    if source.authority_source_station_0573 and tostring(source.authority_source_station_0573)~=tostring(home)then return end
    if dist_sq(entity.position,pair.station.position)>radius*radius then return end
    local key=safe(inv);if seen[key]then return end;seen[key]=true
    out[#out+1]={inv=inv,entity=entity,label=source.source or source.inventory_id or"home-source"}
  end
  local source_fn=rawget(_G,"tech_priests_inventory_steward_sources_for_pair")
  if type(source_fn)=="function"then local ok,sources=pcall(source_fn,pair);if ok and type(sources)=="table"then for _,source in ipairs(sources)do add(source)end end end
  if defines and defines.inventory and pair.station.get_inventory then
    local ok,inv=pcall(function()return pair.station.get_inventory(defines.inventory.chest)end)
    if ok and inv and inv.valid then add({inv=inv,entity=pair.station,source="station-chest"})end
  end
  return out
end
local function source_for_item(pair,item,target_inv)
  local best
  for _,source in ipairs(home_sources(pair))do
    local count=item_count(source.inv,item)
    if count>0 and inv_can_insert(target_inv,item,1)then
      local score=dist_sq(pair.priest.position,source.entity.position)-math.min(count,100)
      if not best or score<best.score then best={item=item,count=count,inv=source.inv,entity=source.entity,label=source.label,score=score}end
    end
  end
  return best
end
local function reservations_module()
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"]
  if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations");if ok then reservations=module end end
  return reservations
end
local function ensure_reservation_category()
  local reservations=reservations_module();if not reservations then return nil end
  local category="rocket-silo-logistics";local found=false
  for _,value in ipairs(reservations.categories or{})do if value==category then found=true break end end
  if not found then reservations.categories=reservations.categories or{};reservations.categories[#reservations.categories+1]=category end
  local state=type(reservations.root)=="function"and reservations.root()or nil
  if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end
  return reservations
end
local function claim_target(pair,task)
  local reservations=ensure_reservation_category()
  if not(reservations and type(reservations.claim)=="function"and valid(task.target))then return false,"reservation-unavailable"end
  local ok,why=reservations.claim("rocket-silo-logistics",task.target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family=task.family,item=task.item,source="rocket-silo-logistics-0710"})
  task.reserved_0710=ok==true;return ok==true,why
end
local function release_target(pair,task)
  if not(task and valid(task.target))then return false end
  local reservations=reservations_module()
  if reservations and type(reservations.release)=="function"then local ok,released=pcall(reservations.release,"rocket-silo-logistics",task.target,pair);return ok and released==true end
  return false
end
local function request_move(pair,target,reason)
  if not(valid_pair(pair)and valid(target))then return false end
  local request=rawget(_G,"tech_priests_request_movement_0418");if type(request)~="function"then return false end
  local ok,accepted=pcall(request,pair,target.position,reason or"rocket-silo-logistics-0710",{owner="rocket-silo-logistics-0710",priority=M.move_priority,ttl=M.move_ttl,radius=1.2,distraction=defines and defines.distraction and defines.distraction.none or nil})
  return ok and accepted==true
end
local function matching_request(request,task)
  return type(request)=="table"and request.source=="rocket-silo-logistics-0710"and request.item==task.item and(not request.target_unit or tostring(request.target_unit)==tostring(task.target_unit))
end
local function clear_requests(pair,task)
  for _,field in ipairs({"active_supply_request","logistic_requested_item"})do if matching_request(pair[field],task)then pair[field]=nil end end
end
local function create_request(pair,task)
  pair.active_supply_request={item=task.item,count=task.count,source="rocket-silo-logistics-0710",purpose="rocket-silo-input",target_unit=task.target_unit,target_name=task.target_name,tick=now()}
  pair.logistic_requested_item={item=task.item,count=task.count,source="rocket-silo-logistics-0710",purpose="rocket-silo-input",target_unit=task.target_unit}
  task.phase="waiting-source";task.request_tick=task.request_tick or now();stat("input-item-requests")
end
local function sync_custody(pair,task,reason)
  local carried=task and task.carried
  if carried and carried.item and(tonumber(carried.count)or 0)>0 then
    pair.rocket_silo_custody_0710={version=M.version,tick=now(),family=task.family,item=carried.item,count=carried.count,target=task.target,target_unit=task.target_unit,target_name=task.target_name,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,reason=reason or task.phase}
    return true
  end
  pair.rocket_silo_custody_0710=nil;return false
end
local function finish_task(pair,task,reason)
  release_target(pair,task);clear_requests(pair,task);pair.rocket_silo_custody_0710=nil
  task.phase="complete";task.completed_tick=now();task.result=reason or"complete"
  pair.rocket_silo_logistics_last_task_0710=task;pair.rocket_silo_logistics_0710=nil
  record(pair,"silo-task-finished",safe(task.family).." "..safe(reason))
  return{processed=1,acted=1,detail=reason or"complete"}
end
local function abort_without_custody(pair,task,reason)
  release_target(pair,task);clear_requests(pair,task)
  task.phase="aborted";task.completed_tick=now();task.result=reason
  pair.rocket_silo_logistics_last_task_0710=task;pair.rocket_silo_logistics_0710=nil
  record(pair,"silo-task-aborted",safe(task.family).." "..safe(reason))
  return{processed=1,blocked=1,detail=reason}
end
local function restore_orphan_custody(pair)
  local custody=pair.rocket_silo_custody_0710
  if pair.rocket_silo_logistics_0710 or type(custody)~="table"or not custody.item or(tonumber(custody.count)or 0)<=0 then return false end
  pair.rocket_silo_logistics_0710={version=M.version,family=custody.family or"custody-recovery",phase="return-custody",item=custody.item,count=custody.count,carried={item=custody.item,count=custody.count},target=custody.target,target_unit=custody.target_unit,target_name=custody.target_name,source_entity=custody.source_entity,source_inv=custody.source_inv,source_label=custody.source_label,started_tick=now(),custody_recovery=true}
  record(pair,"silo-orphan-custody-restored",custody.item.." x"..safe(custody.count),true);return true
end
local function deposit_exact(pair,item,count,reason)
  local authority=storage_authority()
  if authority and type(authority.deposit_exact)=="function"then return authority.deposit_exact(pair,item,count,reason,{})end
  return false,"storage-authority-unavailable",0
end
local function return_custody(pair,task)
  local carried=task.carried
  if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return finish_task(pair,task,"empty-custody")end
  local return_source=task.family=="rocket-silo-input"and valid(task.source_entity)and task.source_entity or nil
  local target=return_source or pair.station
  if dist_sq(pair.priest.position,target.position)>M.return_reach_sq then
    task.phase="return-custody";sync_custody(pair,task,return_source and"returning-source"or"returning-station")
    if not request_move(pair,target,"rocket-silo-custody-return-0710")then return{processed=1,blocked=1,detail="return-movement-blocked"}end
    return{processed=1,waiting=1,detail="returning-custody"}
  end
  if return_source and task.source_inv and task.source_inv.valid then
    local inserted=inv_insert(task.source_inv,carried.item,carried.count);if inserted>0 then carried.count=carried.count-inserted end
    if carried.count<=0 then return finish_task(pair,task,"custody-returned-source")end
    task.source_entity=nil;task.source_inv=nil;task.source_label="station-storage";sync_custody(pair,task,"source-return-partial")
    if not request_move(pair,pair.station,"rocket-silo-custody-station-fallback-0710")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end
    return{processed=1,waiting=1,detail="returning-station"}
  end
  local accepted,why,inserted=deposit_exact(pair,carried.item,carried.count,task.family=="rocket-silo-trash"and"rocket-silo-trash-retention-0710"or"rocket-silo-input-return-0710")
  inserted=tonumber(inserted)or 0
  if accepted==true and inserted==carried.count then carried.count=0;return finish_task(pair,task,"custody-stored")end
  sync_custody(pair,task,"station-storage-blocked")
  record(pair,"silo-custody-storage-blocked",carried.item.." remaining="..safe(carried.count).." reason="..safe(why))
  return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
local function refresh_reports(pair)
  local doctrine=readiness()
  if doctrine and type(doctrine.scan_pair)=="function"then local ok,result=pcall(doctrine.scan_pair,pair,true);if not ok then record(pair,"readiness-refresh-error",result,true)end end
  return pair.rocket_silo_reports_0709 or{}
end
local function manual_report(report)
  return type(report)=="table"and valid(report.silo)and report.automation_owned~=true and report.launch_sequence_active~=true
end
local function source_current(pair,task)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity)and item_count(task.source_inv,task.item)>0 then return{inv=task.source_inv,entity=task.source_entity,count=item_count(task.source_inv,task.item),label=task.source_label}end
  if task.family~="rocket-silo-input"or not task.report then return nil end
  return source_for_item(pair,task.item,task.report.input_inventory)
end
local function candidate_from_reports(pair)
  local reports=pair.rocket_silo_reports_0709;if type(reports)~="table"then reports=refresh_reports(pair)end
  local trash,supply
  for _,report in ipairs(reports or{})do
    if manual_report(report)then
      for _,source in ipairs({{inv=report.crafter_trash_inventory,label="crafter-trash"},{inv=report.silo_trash_inventory,label="silo-trash"}})do
        local entry=contents(source.inv)[1]
        if entry then local score=dist_sq(pair.priest.position,report.silo.position);if not trash or score<trash.score then trash={family="rocket-silo-trash",target=report.silo,target_name=report.silo_name,target_unit=report.silo_unit,item=entry.name,count=math.min(entry.count,M.max_trash_transfer),source_inv=source.inv,source_entity=report.silo,source_label=source.label,report=report,score=score}end end
      end
      if report.state=="manual-input-service-eligible"and report.input_inventory and report.input_inventory.valid then
        local missing=report.item_ingredients_missing and report.item_ingredients_missing[1]
        if missing and missing.name and(tonumber(missing.missing)or 0)>0 then
          local source=source_for_item(pair,missing.name,report.input_inventory);local score=dist_sq(pair.priest.position,report.silo.position)
          if not supply or score<supply.score then supply={family="rocket-silo-input",target=report.silo,target_name=report.silo_name,target_unit=report.silo_unit,item=missing.name,count=math.min(math.max(1,missing.missing),M.max_input_transfer),source=source,report=report,score=score}end
        end
      end
    end
  end
  return trash or supply
end
local function revalidate_target(pair,task)
  if not valid(task.target)then return nil,"target-invalid"end
  local doctrine=readiness();if not(doctrine and type(doctrine.inspect_silo)=="function")then return nil,"readiness-unavailable"end
  local report=doctrine.inspect_silo(pair,task.target,true);task.report=report
  if not report then return nil,"readiness-failed"end
  if report.launch_sequence_active then return report,"launch-sequence-active"end
  if report.automation_owned then return report,"external-logistics-owned"end
  if task.family=="rocket-silo-input"then
    if report.state~="manual-input-service-eligible"then return report,"target-not-eligible:"..safe(report.state)end
    local still_missing=false
    for _,missing in ipairs(report.item_ingredients_missing or{})do if missing.name==task.item and(tonumber(missing.missing)or 0)>0 then still_missing=true break end end
    if not still_missing then return report,"ingredient-already-satisfied"end
    if not inv_can_insert(report.input_inventory,task.item,1)then return report,"input-inventory-rejects-item"end
  elseif task.family=="rocket-silo-trash"then
    local count=item_count(task.source_inv,task.item)
    if count<=0 then return report,"trash-already-cleared"end
  end
  return report,"ready"
end
local function candidate_valid(pair,selected)
  if not(valid_pair(pair)and type(selected)=="table"and valid(selected.target)and selected.target.type=="rocket-silo")then return false end
  if selected.target.surface~=pair.station.surface or selected.target.force~=pair.station.force then return false end
  local doctrine=readiness();local report=doctrine and type(doctrine.inspect_silo)=="function"and doctrine.inspect_silo(pair,selected.target,true)or nil
  if not manual_report(report)then return false end
  if selected.family=="rocket-silo-trash"then return selected.source_inv and selected.source_inv.valid and item_count(selected.source_inv,selected.item)>0 end
  if selected.family=="rocket-silo-input"then
    local missing=false;for _,entry in ipairs(report.item_ingredients_missing or{})do if entry.name==selected.item and(tonumber(entry.missing)or 0)>0 then missing=true break end end
    return missing and report.input_inventory and report.input_inventory.valid and inv_can_insert(report.input_inventory,selected.item,1)
  end
  return false
end
local function discover_pair(pair)
  if not valid_pair(pair)then return false,"invalid-pair"end
  if pair.rocket_silo_logistics_0710 or pair.rocket_silo_custody_0710 then pair.rocket_silo_candidate_0710=nil;return false,"active-task"end
  local state=M.root();local key=tostring(station_unit(pair)or"?");local existing=pair.rocket_silo_candidate_0710
  if candidate_valid(pair,existing)then return false,"candidate-retained"end
  pair.rocket_silo_candidate_0710=nil
  if(tonumber(state.discovery_due[key])or 0)>now()then return false,"cooldown"end
  state.discovery_due[key]=now()+M.discovery_interval;refresh_reports(pair)
  local selected=candidate_from_reports(pair);if not selected then stat("discovery-empty");return false,"no-candidate"end
  selected.version=M.version;selected.discovered_tick=now();pair.rocket_silo_candidate_0710=selected
  record(pair,"silo-candidate-discovered",selected.family.." "..safe(selected.item).." -> "..safe(selected.target_name))
  return true,"candidate-discovered"
end
local function begin_task(pair,selected,reason)
  local task={version=M.version,family=selected.family,phase="new",target=selected.target,target_name=selected.target_name,target_unit=selected.target_unit,item=selected.item,count=math.max(1,tonumber(selected.count)or 1),source_inv=selected.source_inv or(selected.source and selected.source.inv),source_entity=selected.source_entity or(selected.source and selected.source.entity),source_label=selected.source_label or(selected.source and selected.source.label),report=selected.report,started_tick=now(),reason=reason}
  local claimed,why=claim_target(pair,task);if not claimed then return{processed=1,blocked=1,detail="target-reserved:"..safe(why)}end
  pair.rocket_silo_candidate_0710=nil;pair.rocket_silo_logistics_0710=task
  if task.family=="rocket-silo-trash"then
    task.phase="move-to-source"
    if not request_move(pair,task.target,"rocket-silo-trash-pickup-0710")then return{processed=1,blocked=1,detail="source-movement-blocked"}end
    record(pair,"silo-trash-task-began",task.item.." x"..safe(task.count).." from "..safe(task.target_name))
    return{processed=1,waiting=1,detail="moving-to-silo-trash"}
  end
  if not valid(task.source_entity)then create_request(pair,task);record(pair,"silo-input-waiting-source",task.item.." -> "..safe(task.target_name));return{processed=1,waiting=1,detail="waiting-source"}end
  task.phase="move-to-source"
  if not request_move(pair,task.source_entity,"rocket-silo-input-source-0710")then return{processed=1,blocked=1,detail="source-movement-blocked"}end
  record(pair,"silo-input-task-began",task.item.." x"..safe(task.count).." -> "..safe(task.target_name))
  return{processed=1,waiting=1,detail="moving-to-input-source"}
end
local function continue_task(pair,task)
  if TERMINAL[lower(task.phase)]then return finish_task(pair,task,task.phase)end
  if task.phase=="return-custody"then return return_custody(pair,task)end
  if valid(pair.combat_target)then
    if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,"combat-suspended");return return_custody(pair,task)end
    return abort_without_custody(pair,task,"combat-priority")
  end
  if not valid(task.target)then
    if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";return return_custody(pair,task)end
    return abort_without_custody(pair,task,"target-invalid")
  end
  local report,ownership_reason=revalidate_target(pair,task)
  if ownership_reason=="launch-sequence-active"or ownership_reason=="external-logistics-owned"then
    if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,ownership_reason);record(pair,"unsafe-silo-custody-return",ownership_reason);return return_custody(pair,task)end
    record(pair,"unsafe-silo-task-aborted",ownership_reason);return abort_without_custody(pair,task,ownership_reason)
  end
  if task.phase=="waiting-source"then
    if now()-(tonumber(task.request_tick)or now())>=M.request_timeout then return abort_without_custody(pair,task,"input-source-timeout")end
    local source=source_current(pair,task);if not source then create_request(pair,task);return{processed=1,waiting=1,detail="waiting-source"}end
    task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label;task.phase="move-to-source"
    if not request_move(pair,source.entity,"rocket-silo-input-source-ready-0710")then return{processed=1,blocked=1,detail="source-movement-blocked"}end
    return{processed=1,waiting=1,detail="source-ready"}
  end
  if task.phase=="move-to-source"then
    local source
    if task.family=="rocket-silo-trash"then source={inv=task.source_inv,entity=task.target,count=item_count(task.source_inv,task.item),label=task.source_label}else source=source_current(pair,task)end
    if not(source and source.inv and source.inv.valid and valid(source.entity)and(tonumber(source.count)or 0)>0)then
      if task.family=="rocket-silo-input"then task.phase="waiting-source";task.request_tick=now();create_request(pair,task);return{processed=1,waiting=1,detail="source-lost"}end
      return abort_without_custody(pair,task,"silo-trash-source-empty")
    end
    if dist_sq(pair.priest.position,source.entity.position)>M.pickup_reach_sq then
      if not request_move(pair,source.entity,"rocket-silo-item-source-0710")then return{processed=1,blocked=1,detail="source-movement-blocked"}end
      return{processed=1,waiting=1,detail="moving-to-source"}
    end
    local cap=task.family=="rocket-silo-input"and M.max_input_transfer or M.max_trash_transfer
    local want=math.max(1,math.min(task.count,source.count,cap));local removed=inv_remove(source.inv,task.item,want)
    if removed<=0 then return abort_without_custody(pair,task,"source-remove-failed")end
    task.carried={item=task.item,count=removed};task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label
    clear_requests(pair,task);sync_custody(pair,task,"picked-up");record(pair,"silo-item-picked-up",task.family.." "..task.item.." x"..safe(removed))
    if task.family=="rocket-silo-trash"then
      task.phase="return-custody"
      if not request_move(pair,pair.station,"rocket-silo-trash-return-0710")then return{processed=1,acted=1,blocked=1,detail="return-movement-blocked"}end
      return{processed=1,acted=1,waiting=1,detail="returning-silo-trash"}
    end
    task.phase="move-to-target"
    if not request_move(pair,task.target,"rocket-silo-input-delivery-0710")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,acted=1,blocked=1,detail="target-movement-blocked"}end
    return{processed=1,acted=1,waiting=1,detail="delivering-silo-input"}
  end
  if task.phase=="move-to-target"then
    if dist_sq(pair.priest.position,task.target.position)>M.target_reach_sq then
      if not request_move(pair,task.target,"rocket-silo-input-delivery-0710")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,blocked=1,detail="target-movement-blocked"}end
      sync_custody(pair,task,"moving-to-target");return{processed=1,waiting=1,detail="moving-to-target"}
    end
    local fresh,why=revalidate_target(pair,task)
    if not fresh or why~="ready"then task.phase="return-custody";sync_custody(pair,task,why);record(pair,"silo-target-became-ineligible",safe(why));return return_custody(pair,task)end
    local carried=task.carried;if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return abort_without_custody(pair,task,"custody-missing")end
    local inserted=inv_insert(fresh.input_inventory,carried.item,carried.count)
    if inserted>0 then carried.count=carried.count-inserted;stat("input-items-delivered",inserted);record(pair,"silo-input-delivered",carried.item.." x"..safe(inserted).." -> "..safe(task.target_name))end
    if carried.count<=0 then return finish_task(pair,task,"input-delivered")end
    task.phase="return-custody";sync_custody(pair,task,inserted>0 and"input-partial"or"input-insert-blocked")
    return{processed=1,acted=inserted>0 and 1 or 0,blocked=inserted<=0 and 1 or 0,waiting=inserted>0 and 1 or 0,detail=inserted>0 and"partial-input-delivery"or"input-insert-blocked"}
  end
  return{processed=1,failed=1,detail="unknown-phase:"..safe(task.phase)}
end
function M.abort_pair(pair,reason)
  if not valid_pair(pair)then return{processed=0,failed=1,detail="invalid-pair"}end
  restore_orphan_custody(pair);local task=pair.rocket_silo_logistics_0710
  if not task then return{processed=1,detail="no-task"}end
  if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,reason or"abort");return return_custody(pair,task)end
  return abort_without_custody(pair,task,reason or"aborted")
end
function M.service_pair(pair,reason)
  if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end
  restore_orphan_custody(pair);local task=pair.rocket_silo_logistics_0710
  if task then return continue_task(pair,task)end
  if valid(pair.combat_target)then return{processed=1,blocked=1,detail="blocked:combat"}end
  local selected=pair.rocket_silo_candidate_0710
  if not candidate_valid(pair,selected)then pair.rocket_silo_candidate_0710=nil;return{processed=1,detail="no-silo-task"}end
  return begin_task(pair,selected,reason or"dispatcher")
end
local function action_target(pair,task)
  if task.phase=="move-to-source"and valid(task.source_entity or task.target)then local target=task.source_entity or task.target;return target,"collect-silo-item","Collecting "..safe(task.item).." for "..safe(task.target_name)end
  if task.phase=="move-to-target"and valid(task.target)then return task.target,"deliver-silo-input","Delivering "..safe(task.item).." to "..safe(task.target_name)end
  if task.phase=="return-custody"then local target=task.family=="rocket-silo-input"and valid(task.source_entity)and task.source_entity or pair.station;return target,"return-silo-custody","Returning "..safe(task.item)end
  if task.phase=="waiting-source"and valid(task.target)then return task.target,"waiting-silo-source","Waiting for "..safe(task.item)end
  return valid(task.target)and task.target or pair.station,task.phase or"silo-logistics","Rocket silo logistics"
end
function M.recommend_action(pair)
  if M.root().enabled==false or not valid_pair(pair)then return nil end
  local task=pair.rocket_silo_logistics_0710;local custody=pair.rocket_silo_custody_0710
  if type(task)=="table"then local target,phase,label=action_target(pair,task);return{kind="rocket-silo-logistics",family="rocket-silo-logistics",active=true,target=target,position=valid(target)and target.position or nil,item=task.item,phase=phase,label=label,reason=task.reason or task.phase,source="rocket_silo_logistics_0710"}end
  if type(custody)=="table"and custody.item and(tonumber(custody.count)or 0)>0 then local target=custody.family=="rocket-silo-input"and valid(custody.source_entity)and custody.source_entity or pair.station;return{kind="rocket-silo-logistics",family="rocket-silo-logistics",active=true,target=target,position=target.position,item=custody.item,phase="return-silo-custody",label="Returning silo custody",reason=custody.reason or"orphan-custody",source="rocket_silo_logistics_0710"}end
  local selected=pair.rocket_silo_candidate_0710;if not candidate_valid(pair,selected)then return nil end
  return{kind="rocket-silo-logistics",family="rocket-silo-logistics",active=false,target=selected.target,position=selected.target.position,item=selected.item,phase="candidate",label=selected.family=="rocket-silo-input"and"Rocket silo input delivery"or"Rocket silo trash evacuation",reason="broker-discovered-candidate",source="rocket_silo_logistics_0710"}
end
local function discover_pairs(budget)
  local state=M.root();if state.enabled==false then return{processed=0,acted=0,detail="disabled"}end
  local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end
  table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return{processed=0,acted=0,detail="no-pairs"}end
  local limit=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_discovery)));local start=state.cursor%#list+1
  local processed,discovered,failed=0,0,0
  for index=0,limit-1 do local pair=list[((start+index-1)%#list)+1].pair;processed=processed+1;local ok,changed=pcall(discover_pair,pair);if ok and changed==true then discovered=discovered+1 elseif not ok then failed=failed+1;record(pair,"silo-discovery-error",changed,true)end end
  state.cursor=(start+limit-2)%#list+1
  return{processed=processed,acted=discovered,failed=failed,exhausted=#list>limit,detail="discovered="..discovered.." failed="..failed}
end
local function patch_diagnostics()
  local diagnostics=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not(diagnostics and type(diagnostics.pair_dump_lines)=="function")then return false end
  if diagnostics.rocket_silo_logistics_0710_wrapped then return true end
  diagnostics.rocket_silo_logistics_0710_wrapped=true;local previous=diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines=function(...)
    local lines=previous(...);lines=type(lines)=="table"and lines or{};local state=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 ROCKET-SILO-LOGISTICS-0710 version="..M.version.." dispatcher_owned="..safe(state.dispatcher_owned).." discovery_only="..safe(state.discovery_only_broker).." live_ownership=integrated requests="..safe(state.stats["input-item-requests"]or 0).." pickups="..safe(state.stats["silo-item-picked-up"]or 0).." delivered="..safe(state.stats["input-items-delivered"]or 0).." custody_restored="..safe(state.stats["silo-orphan-custody-restored"]or 0).." direct_timing=0 leaf_authority=0 loose_movement_success=0"
    return lines
  end
  return true
end
function M.install()
  M.root();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(broker and type(broker.register_service)=="function")then return false end
  local service=broker.register_service({name="rocket_silo_discovery_0710",category="discovery",interval=M.discovery_interval,priority=57,budget=M.max_pairs_per_discovery,note="discovery only for manual rocket-silo input and trash work",fn=function(_,budget)return discover_pairs(budget)end})
  if not service then return false end
  patch_diagnostics();_G.TechPriestsRocketSiloLogistics0710=M
  if log then log("[Tech-Priests recovery] dispatcher-owned rocket-silo logistics installed")end
  return true
end
return M
