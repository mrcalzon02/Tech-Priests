-- scripts/core/artillery_logistics_0713.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical physical artillery ammunition owner. Broker work is discovery only;
-- the action arbiter recommends cached work and the dispatcher alone executes it.

local M={version="0.1.674-dev",storage_key="artillery_logistics_0713",pickup_reach_sq=2.56,target_reach_sq=3.24,return_reach_sq=2.56,move_priority=974,move_ttl=60*10,reservation_ttl=60*15,request_timeout=60*14,discovery_interval=223,max_pairs_per_discovery=6,max_transfer=10}
local AMMO_PREFERENCE={"artillery-shell"}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function priest_unit(p)return p and(p.priest_unit or(valid(p.priest)and p.priest.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return 999999999 end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,dispatcher_owned=true,discovery_only_broker=true,train_validity_integrated=true,stats={},recent={},discovery_due={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;if r.dispatcher_owned==nil then r.dispatcher_owned=true end;if r.discovery_only_broker==nil then r.discovery_only_broker=true end;if r.train_validity_integrated==nil then r.train_validity_integrated=true end
 r.stats=r.stats or{};r.recent=r.recent or{};r.discovery_due=r.discovery_due or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail,force_log)
 local r=M.root();stat(action);local ev={tick=now(),action=tostring(action or"event"),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or"")};r.recent[#r.recent+1]=ev;while #r.recent>160 do table.remove(r.recent,1)end;if pair then pair.artillery_logistics_last_0713=ev end
 if force_log and log then log("[Tech-Priests recovery] artillery "..ev.action.." station="..ev.station.." priest="..ev.priest.." "..ev.detail)end
end
local function inventory(entity)
 if not(valid(entity)and defines and defines.inventory)then return nil end;local id=entity.type=="artillery-wagon"and defines.inventory.artillery_wagon_ammo or defines.inventory.artillery_turret_ammo;if not id then return nil end
 local ok,inv=pcall(function()return entity.get_inventory(id)end);return ok and inv and inv.valid and inv or nil
end
local function item_count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,n=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(n)or 0)or 0 end
local function inv_remove(inv,item,n)if not(inv and inv.valid and item and(tonumber(n)or 0)>0)then return 0 end;local ok,v=pcall(function()return inv.remove({name=item,count=n})end);return ok and(tonumber(v)or 0)or 0 end
local function inv_insert(inv,item,n)if not(inv and inv.valid and item and(tonumber(n)or 0)>0)then return 0 end;local ok,v=pcall(function()return inv.insert({name=item,count=n})end);return ok and(tonumber(v)or 0)or 0 end
local function inv_can_insert(inv,item)if not(inv and inv.valid and item)then return false end;local ok,v=pcall(function()return inv.can_insert({name=item,count=1})end);return ok and v==true end
local function readiness()return rawget(_G,"TechPriestsArtilleryReadiness0712")or package.loaded["scripts.core.artillery_readiness_0712"]end
local function storage_authority()return rawget(_G,"TechPriestsStorageRoleAuthority0686")or package.loaded["scripts.core.storage_role_authority_0686"]end
local function service_radius(pair)
 local radius=tonumber(pair and pair.radius)or 28;if valid_pair(pair)and type(_G.get_station_operating_radius)=="function"then local ok,v=pcall(_G.get_station_operating_radius,pair.station);if ok and tonumber(v)then radius=tonumber(v)end end;return math.max(8,math.min(radius,96))
end
local function home_sources(pair)
 local out,seen={},{};if not valid_pair(pair)then return out end;local radius=service_radius(pair);local home=station_unit(pair)
 local function add(src)local inv=src and src.inv;local entity=src and src.entity;if not(inv and inv.valid and valid(entity))then return end;if entity.surface~=pair.station.surface or entity.force~=pair.station.force then return end;if src.authority_source_station_0573 and tostring(src.authority_source_station_0573)~=tostring(home)then return end;if dist_sq(entity.position,pair.station.position)>radius*radius then return end;local key=safe(inv);if seen[key]then return end;seen[key]=true;out[#out+1]={inv=inv,entity=entity,label=src.source or src.inventory_id or"home-source"}end
 local f=rawget(_G,"tech_priests_inventory_steward_sources_for_pair");if type(f)=="function"then local ok,sources=pcall(f,pair);if ok and type(sources)=="table"then for _,src in ipairs(sources)do add(src)end end end
 if defines and defines.inventory and pair.station.get_inventory then local ok,inv=pcall(function()return pair.station.get_inventory(defines.inventory.chest)end);if ok and inv and inv.valid then add({inv=inv,entity=pair.station,source="station-chest"})end end;return out
end
local function source_for_item(pair,item,target_inv)
 local best;for _,src in ipairs(home_sources(pair))do local count=item_count(src.inv,item);if count>0 and inv_can_insert(target_inv,item)then local score=dist_sq(pair.priest.position,src.entity.position)-math.min(count,100);if not best or score<best.score then best={item=item,count=count,inv=src.inv,entity=src.entity,label=src.label,score=score}end end end;return best
end
local function choose_ammo(pair,report)
 local inv=report and report.ammo_inventory;if not(inv and inv.valid)then return nil,nil end
 for _,entry in ipairs(report.ammo_contents or{})do local src=source_for_item(pair,entry.name,inv);if src then return src,entry.name end end
 for _,name in ipairs(AMMO_PREFERENCE)do local src=source_for_item(pair,name,inv);if src then return src,name end end
 for _,name in ipairs(report.compatible_ammo or{})do local src=source_for_item(pair,name,inv);if src then return src,name end end
 local request=AMMO_PREFERENCE[1];if not inv_can_insert(inv,request)then request=(report.compatible_ammo or{})[1]end;return nil,request
end
local function reservations_module()
 local r=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not r then local ok,m=pcall(require,"scripts.core.work_reservations");if ok then r=m end end;return r
end
local function ensure_reservation_category()
 local r=reservations_module();if not r then return nil end;local category="artillery-logistics";local found=false;for _,v in ipairs(r.categories or{})do if v==category then found=true break end end;if not found then r.categories=r.categories or{};r.categories[#r.categories+1]=category end
 local state=type(r.root)=="function"and r.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return r
end
local function claim_target(pair,task)
 local r=ensure_reservation_category();if not(r and type(r.claim)=="function"and valid(task.target))then return false,"reservation-unavailable"end
 local ok,why=r.claim("artillery-logistics",task.target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family="artillery-ammo",item=task.item,source="artillery-logistics-0713"});task.reserved_0713=ok==true;return ok==true,why
end
local function release_target(pair,task)
 if not(task and valid(task.target))then return false end;local r=reservations_module();if r and type(r.release)=="function"then local ok,v=pcall(r.release,"artillery-logistics",task.target,pair);return ok and v==true end;return false
end
local function request_move(pair,target,reason)
 if not(valid_pair(pair)and valid(target))then return false end;local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function"then return false end
 local ok,accepted=pcall(f,pair,target.position,reason or"artillery-logistics-0713",{owner="artillery-logistics-0713",priority=M.move_priority,ttl=M.move_ttl,radius=1.5,distraction=defines and defines.distraction and defines.distraction.none or nil});return ok and accepted==true
end
local function matching_request(req,task)return type(req)=="table"and req.source=="artillery-logistics-0713"and req.item==task.item and(not req.target_unit or tostring(req.target_unit)==tostring(task.target_unit))end
local function clear_requests(pair,task)for _,field in ipairs({"active_supply_request","logistic_requested_item"})do if matching_request(pair[field],task)then pair[field]=nil end end end
local function create_request(pair,task)
 pair.active_supply_request={item=task.item,count=task.count,source="artillery-logistics-0713",purpose="artillery-ammo",target_unit=task.target_unit,target_name=task.target_name,tick=now()};pair.logistic_requested_item={item=task.item,count=task.count,source="artillery-logistics-0713",purpose="artillery-ammo",target_unit=task.target_unit};task.phase="waiting-source";task.request_tick=task.request_tick or now();stat("ammo-item-requests")
end
local function sync_custody(pair,task,reason)
 local carried=task and task.carried;if carried and carried.item and(tonumber(carried.count)or 0)>0 then pair.artillery_custody_0713={version=M.version,tick=now(),item=carried.item,count=carried.count,target=task.target,target_unit=task.target_unit,target_name=task.target_name,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,reason=reason or task.phase};return true end;pair.artillery_custody_0713=nil;return false
end
local function finish_task(pair,task,reason)
 release_target(pair,task);clear_requests(pair,task);pair.artillery_custody_0713=nil;task.phase="complete";task.completed_tick=now();task.result=reason or"complete";pair.artillery_logistics_last_task_0713=task;pair.artillery_logistics_0713=nil;record(pair,"artillery-task-finished",safe(reason));return{processed=1,acted=1,detail=reason or"complete"}
end
local function abort_without_custody(pair,task,reason)
 release_target(pair,task);clear_requests(pair,task);task.phase="aborted";task.completed_tick=now();task.result=reason;pair.artillery_logistics_last_task_0713=task;pair.artillery_logistics_0713=nil;record(pair,"artillery-task-aborted",safe(reason));return{processed=1,blocked=1,detail=reason}
end
local function restore_orphan_custody(pair)
 local c=pair.artillery_custody_0713;if pair.artillery_logistics_0713 or type(c)~="table"or not c.item or(tonumber(c.count)or 0)<=0 then return false end
 pair.artillery_logistics_0713={version=M.version,phase="return-custody",item=c.item,count=c.count,carried={item=c.item,count=c.count},target=c.target,target_unit=c.target_unit,target_name=c.target_name,source_entity=c.source_entity,source_inv=c.source_inv,source_label=c.source_label,started_tick=now(),custody_recovery=true};record(pair,"artillery-orphan-custody-restored",c.item.." x"..safe(c.count),true);return true
end
local function deposit_exact(pair,item,count,reason)
 local a=storage_authority();if a and type(a.deposit_exact)=="function"then return a.deposit_exact(pair,item,count,reason,{})end;return false,"storage-authority-unavailable",0
end
local function return_custody(pair,task)
 local carried=task.carried;if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return finish_task(pair,task,"empty-custody")end
 local source_target=valid(task.source_entity)and task.source_entity or nil;local target=source_target or pair.station
 if dist_sq(pair.priest.position,target.position)>M.return_reach_sq then task.phase="return-custody";sync_custody(pair,task,source_target and"returning-source"or"returning-station");if not request_move(pair,target,"artillery-custody-return-0713")then return{processed=1,blocked=1,detail="return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-custody"}end
 if source_target and task.source_inv and task.source_inv.valid then local inserted=inv_insert(task.source_inv,carried.item,carried.count);if inserted>0 then carried.count=carried.count-inserted end;if carried.count<=0 then return finish_task(pair,task,"custody-returned-source")end;task.source_entity=nil;task.source_inv=nil;sync_custody(pair,task,"source-return-partial");if not request_move(pair,pair.station,"artillery-station-return-0713")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-station"}end
 local accepted,why,inserted=deposit_exact(pair,carried.item,carried.count,"artillery-ammo-return-0713");inserted=tonumber(inserted)or 0;if accepted==true and inserted==carried.count then carried.count=0;return finish_task(pair,task,"custody-stored")end;sync_custody(pair,task,"station-storage-blocked");record(pair,"artillery-custody-storage-blocked",carried.item.." remaining="..safe(carried.count).." reason="..safe(why));return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
local function refresh_reports(pair)
 local d=readiness();if d and type(d.scan_pair)=="function"then local ok,v=pcall(d.scan_pair,pair,true);if not ok then record(pair,"readiness-refresh-error",v,true)end end;return pair.artillery_reports_0712 or{}
end
local function report_safe(report)return type(report)=="table"and valid(report.entity)and report.state=="manual-ammo-service-eligible"end
local function source_current(pair,task)
 if task.source_inv and task.source_inv.valid and valid(task.source_entity)and item_count(task.source_inv,task.item)>0 then return{inv=task.source_inv,entity=task.source_entity,count=item_count(task.source_inv,task.item),label=task.source_label}end
 if not task.report then return nil end;return source_for_item(pair,task.item,task.report.ammo_inventory)
end
local function candidate_from_reports(pair)
 local reports=pair.artillery_reports_0712;if type(reports)~="table"then reports=refresh_reports(pair)end;local best
 for _,report in ipairs(reports or{})do if report_safe(report)then local source,item=choose_ammo(pair,report);if item then local score=dist_sq(pair.priest.position,report.entity.position);if not best or score<best.score then best={target=report.entity,target_name=report.entity_name,target_unit=report.entity_unit,item=item,count=math.min(math.max(1,tonumber(report.missing_ammo_count)or 1),M.max_transfer),source=source,report=report,score=score}end end end end;return best
end
local function revalidate_target(pair,task)
 if not valid(task.target)then return nil,"target-invalid"end;local d=readiness();if not(d and type(d.inspect_entity)=="function")then return nil,"readiness-unavailable"end
 local report=d.inspect_entity(pair,task.target,true);task.report=report;if not report then return nil,"readiness-failed"end;if report.state~="manual-ammo-service-eligible"then return report,"target-not-eligible:"..safe(report.state)end;if not inv_can_insert(report.ammo_inventory,task.item)then return report,"ammo-inventory-rejects-item"end;return report,"ready"
end
local function candidate_valid(pair,selected)
 if not(valid_pair(pair)and type(selected)=="table"and valid(selected.target)and(selected.target.type=="artillery-turret"or selected.target.type=="artillery-wagon"))then return false end;if selected.target.surface~=pair.station.surface or selected.target.force~=pair.station.force then return false end
 local d=readiness();local report=d and type(d.inspect_entity)=="function"and d.inspect_entity(pair,selected.target,true)or nil;return report_safe(report)and report.ammo_inventory and report.ammo_inventory.valid and inv_can_insert(report.ammo_inventory,selected.item)
end
local function discover_pair(pair)
 if not valid_pair(pair)then return false,"invalid-pair"end;if pair.artillery_logistics_0713 or pair.artillery_custody_0713 then pair.artillery_candidate_0713=nil;return false,"active-task"end
 local state=M.root();local key=tostring(station_unit(pair)or"?");local existing=pair.artillery_candidate_0713;if candidate_valid(pair,existing)then return false,"candidate-retained"end;pair.artillery_candidate_0713=nil;if(tonumber(state.discovery_due[key])or 0)>now()then return false,"cooldown"end
 state.discovery_due[key]=now()+M.discovery_interval;refresh_reports(pair);local selected=candidate_from_reports(pair);if not selected then stat("discovery-empty");return false,"no-candidate"end;selected.version=M.version;selected.discovered_tick=now();pair.artillery_candidate_0713=selected;record(pair,"artillery-candidate-discovered",safe(selected.item).." -> "..safe(selected.target_name));return true,"candidate-discovered"
end
local function begin_task(pair,selected,reason)
 local task={version=M.version,phase="new",target=selected.target,target_name=selected.target_name,target_unit=selected.target_unit,item=selected.item,count=math.max(1,tonumber(selected.count)or 1),source_inv=selected.source and selected.source.inv or nil,source_entity=selected.source and selected.source.entity or nil,source_label=selected.source and selected.source.label or nil,report=selected.report,started_tick=now(),reason=reason}
 local claimed,why=claim_target(pair,task);if not claimed then return{processed=1,blocked=1,detail="target-reserved:"..safe(why)}end;pair.artillery_candidate_0713=nil;pair.artillery_logistics_0713=task
 if not valid(task.source_entity)then create_request(pair,task);record(pair,"artillery-waiting-source",task.item.." -> "..safe(task.target_name));return{processed=1,waiting=1,detail="waiting-source"}end;task.phase="move-to-source";if not request_move(pair,task.source_entity,"artillery-ammo-source-0713")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;record(pair,"artillery-task-began",task.item.." x"..safe(task.count).." -> "..safe(task.target_name));return{processed=1,waiting=1,detail="moving-to-source"}
end
local function continue_task(pair,task)
 if task.phase=="return-custody"then return return_custody(pair,task)end
 if valid(pair.combat_target)then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,"combat-suspended");return return_custody(pair,task)end;return abort_without_custody(pair,task,"combat-priority")end
 if not valid(task.target)then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";return return_custody(pair,task)end;return abort_without_custody(pair,task,"target-invalid")end
 local report,safety_reason=revalidate_target(pair,task)
 if not report or safety_reason~="ready"then if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,safety_reason);record(pair,"unsafe-artillery-custody-return",safety_reason);return return_custody(pair,task)end;record(pair,"unsafe-artillery-task-aborted",safety_reason);return abort_without_custody(pair,task,safety_reason)end
 if task.phase=="waiting-source"then if now()-(tonumber(task.request_tick)or now())>=M.request_timeout then return abort_without_custody(pair,task,"ammo-source-timeout")end;local source=source_current(pair,task);if not source then create_request(pair,task);return{processed=1,waiting=1,detail="waiting-source"}end;task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label;task.phase="move-to-source";if not request_move(pair,source.entity,"artillery-ammo-source-ready-0713")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="source-ready"}end
 if task.phase=="move-to-source"then local source=source_current(pair,task);if not source then task.phase="waiting-source";task.request_tick=now();create_request(pair,task);return{processed=1,waiting=1,detail="source-lost"}end;if dist_sq(pair.priest.position,source.entity.position)>M.pickup_reach_sq then if not request_move(pair,source.entity,"artillery-ammo-source-0713")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="moving-to-source"}end
  local want=math.max(1,math.min(task.count,source.count,M.max_transfer));local removed=inv_remove(source.inv,task.item,want);if removed<=0 then return abort_without_custody(pair,task,"source-remove-failed")end;task.carried={item=task.item,count=removed};task.source_inv=source.inv;task.source_entity=source.entity;task.source_label=source.label;clear_requests(pair,task);sync_custody(pair,task,"picked-up");record(pair,"artillery-ammo-picked-up",task.item.." x"..safe(removed));task.phase="move-to-target";if not request_move(pair,task.target,"artillery-ammo-delivery-0713")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,acted=1,blocked=1,detail="target-movement-blocked"}end;return{processed=1,acted=1,waiting=1,detail="delivering-ammo"}
 end
 if task.phase=="move-to-target"then if dist_sq(pair.priest.position,task.target.position)>M.target_reach_sq then if not request_move(pair,task.target,"artillery-ammo-delivery-0713")then task.phase="return-custody";sync_custody(pair,task,"target-movement-blocked");return{processed=1,blocked=1,detail="target-movement-blocked"}end;sync_custody(pair,task,"moving-to-target");return{processed=1,waiting=1,detail="moving-to-target"}end
  local fresh,why=revalidate_target(pair,task);if not fresh or why~="ready"then task.phase="return-custody";sync_custody(pair,task,why);record(pair,"artillery-target-became-ineligible",safe(why));return return_custody(pair,task)end;local carried=task.carried;if not(carried and carried.item and(tonumber(carried.count)or 0)>0)then return abort_without_custody(pair,task,"custody-missing")end;local inserted=inv_insert(fresh.ammo_inventory,carried.item,carried.count);if inserted>0 then carried.count=carried.count-inserted;stat("ammo-items-delivered",inserted);record(pair,"artillery-ammo-delivered",carried.item.." x"..safe(inserted).." -> "..safe(task.target_name))end;if carried.count<=0 then return finish_task(pair,task,"ammo-delivered")end;task.phase="return-custody";sync_custody(pair,task,inserted>0 and"ammo-partial"or"ammo-insert-blocked");return{processed=1,acted=inserted>0 and 1 or 0,blocked=inserted<=0 and 1 or 0,waiting=inserted>0 and 1 or 0,detail=inserted>0 and"partial-ammo-delivery"or"ammo-insert-blocked"}
 end
 return{processed=1,failed=1,detail="unknown-phase:"..safe(task.phase)}
end
function M.abort_pair(pair,reason)
 if not valid_pair(pair)then return{processed=0,failed=1,detail="invalid-pair"}end;restore_orphan_custody(pair);local task=pair.artillery_logistics_0713;if not task then return{processed=1,detail="no-task"}end;if task.carried and(tonumber(task.carried.count)or 0)>0 then task.phase="return-custody";sync_custody(pair,task,reason or"abort");return return_custody(pair,task)end;return abort_without_custody(pair,task,reason or"aborted")
end
function M.service_pair(pair,reason)
 if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;restore_orphan_custody(pair);local task=pair.artillery_logistics_0713;if task then return continue_task(pair,task)end;if valid(pair.combat_target)then return{processed=1,blocked=1,detail="blocked:combat"}end;local selected=pair.artillery_candidate_0713;if not candidate_valid(pair,selected)then pair.artillery_candidate_0713=nil;return{processed=1,detail="no-artillery-task"}end;return begin_task(pair,selected,reason or"dispatcher")
end
local function action_target(pair,task)
 if task.phase=="move-to-source"and valid(task.source_entity)then return task.source_entity,"collect-artillery-ammo","Collecting "..safe(task.item).." for "..safe(task.target_name)end;if task.phase=="move-to-target"and valid(task.target)then return task.target,"deliver-artillery-ammo","Delivering "..safe(task.item).." to "..safe(task.target_name)end;if task.phase=="return-custody"then local target=valid(task.source_entity)and task.source_entity or pair.station;return target,"return-artillery-custody","Returning "..safe(task.item)end;if task.phase=="waiting-source"and valid(task.target)then return task.target,"waiting-artillery-source","Waiting for "..safe(task.item)end;return valid(task.target)and task.target or pair.station,task.phase or"artillery-logistics","Artillery logistics"
end
function M.recommend_action(pair)
 if M.root().enabled==false or not valid_pair(pair)then return nil end;local task=pair.artillery_logistics_0713;local custody=pair.artillery_custody_0713
 if type(task)=="table"then local target,phase,label=action_target(pair,task);return{kind="artillery-logistics",family="artillery-logistics",active=true,target=target,position=valid(target)and target.position or nil,item=task.item,phase=phase,label=label,reason=task.reason or task.phase,source="artillery_logistics_0713"}end
 if type(custody)=="table"and custody.item and(tonumber(custody.count)or 0)>0 then local target=valid(custody.source_entity)and custody.source_entity or pair.station;return{kind="artillery-logistics",family="artillery-logistics",active=true,target=target,position=target.position,item=custody.item,phase="return-artillery-custody",label="Returning artillery custody",reason=custody.reason or"orphan-custody",source="artillery_logistics_0713"}end
 local selected=pair.artillery_candidate_0713;if not candidate_valid(pair,selected)then return nil end;return{kind="artillery-logistics",family="artillery-logistics",active=false,target=selected.target,position=selected.target.position,item=selected.item,phase="candidate",label="Artillery ammunition delivery",reason="broker-discovered-candidate",source="artillery_logistics_0713"}
end
local function discover_pairs(budget)
 local state=M.root();if state.enabled==false then return{processed=0,acted=0,detail="disabled"}end;local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return{processed=0,acted=0,detail="no-pairs"}end
 local limit=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_discovery)));local start=state.cursor%#list+1;local processed,discovered,failed=0,0,0
 for index=0,limit-1 do local pair=list[((start+index-1)%#list)+1].pair;processed=processed+1;local ok,changed=pcall(discover_pair,pair);if ok and changed==true then discovered=discovered+1 elseif not ok then failed=failed+1;record(pair,"artillery-discovery-error",changed,true)end end;state.cursor=(start+limit-2)%#list+1;return{processed=processed,acted=discovered,failed=failed,exhausted=#list>limit,detail="discovered="..discovered.." failed="..failed}
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(d and type(d.pair_dump_lines)=="function")then return false end;if d.artillery_logistics_0713_wrapped then return true end;d.artillery_logistics_0713_wrapped=true;local previous=d.pair_dump_lines
 d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local state=M.root();lines[#lines+1]="PAIR-DUMP-0468 ARTILLERY-LOGISTICS-0713 version="..M.version.." dispatcher_owned="..safe(state.dispatcher_owned).." discovery_only="..safe(state.discovery_only_broker).." train_validity=integrated requests="..safe(state.stats["ammo-item-requests"]or 0).." pickups="..safe(state.stats["artillery-ammo-picked-up"]or 0).." delivered="..safe(state.stats["ammo-items-delivered"]or 0).." custody_restored="..safe(state.stats["artillery-orphan-custody-restored"]or 0).." direct_timing=0 leaf_authority=0 loose_movement_success=0";return lines end;return true
end
function M.install()
 M.root();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="artillery_discovery_0713",category="discovery",interval=M.discovery_interval,priority=55,budget=M.max_pairs_per_discovery,note="discovery only for manual fixed artillery and stationary manual wagons",fn=function(_,budget)return discover_pairs(budget)end});if not service then return false end;patch_diagnostics();_G.TechPriestsArtilleryLogistics0713=M;if log then log("[Tech-Priests recovery] dispatcher-owned artillery logistics installed")end;return true
end
return M
