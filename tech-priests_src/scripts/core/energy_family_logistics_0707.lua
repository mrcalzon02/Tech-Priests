-- Tech Priests 0.1.673 physical energy-family logistics.
--
-- Operates only on 0705 readiness reports. Existing burnt results are evacuated
-- first. Fuel is selected only when the exact target fuel inventory accepts it
-- and the exact fuel burnt result can be accepted. Every item transfer visits the
-- physical source before removal, persists custody, visits the target/destination,
-- and returns leftovers. Fluid, heat, electrical, and capacity prerequisites are
-- revalidated immediately before fuel insertion.
--
-- Ordinary generators without a legitimate item-fuel inventory remain untouched.

local M = {
  version = "0.1.673",
  storage_key = "energy_family_logistics_0707",
  pickup_reach_sq = 2.56,
  target_reach_sq = 2.56,
  station_reach_sq = 2.56,
  move_priority = 977,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  target_fuel_count = 2,
  max_fuel_transfer = 4,
  max_burnt_transfer = 50,
}

local previous_leaf_truth

local FUEL_PREFERENCE = {
  "coal",
  "wood",
  "solid-fuel",
  "rocket-fuel",
  "nuclear-fuel",
  "uranium-fuel-cell",
}

local TERMINAL = {
  complete=true, completed=true, done=true, aborted=true, failed=true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail,force_log)
  local r=root(); stat(action)
  local event={tick=now(),action=tostring(action),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  r.recent[#r.recent+1]=event; while #r.recent>180 do table.remove(r.recent,1) end
  pair.energy_family_logistics_last_0707=event
  if force_log and log then log("[Tech-Priests 0.1.673] "..event.action.." station="..event.station.." priest="..event.priest.." "..event.detail) end
end

local function inventory_count(inv,item)
  if not (inv and inv.valid) then return 0 end
  if item then local ok,n=pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
  local total=0; local ok,contents=pcall(function() return inv.get_contents() end)
  if ok and type(contents)=="table" then for _,value in pairs(contents) do total=total+(type(value)=="table" and (tonumber(value.count or value.amount or value[2]) or 0) or (tonumber(value) or 0)) end end
  return total
end
local function contents(inv)
  local out={}; if not (inv and inv.valid) then return out end
  local ok,raw=pcall(function() return inv.get_contents() end); if not (ok and type(raw)=="table") then return out end
  for key,value in pairs(raw) do local name,count; if type(key)=="string" then name=key; count=type(value)=="table" and tonumber(value.count or value.amount or value[2]) or tonumber(value) elseif type(value)=="table" then name=value.name or value.item or value[1]; count=tonumber(value.count or value.amount or value[2]) end; if type(name)=="string" and (tonumber(count) or 0)>0 then out[#out+1]={name=name,count=tonumber(count) or 1} end end
  return out
end
local function inv_remove(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end local ok,n=pcall(function() return inv.remove({name=item,count=count}) end); return ok and (tonumber(n) or 0) or 0 end
local function inv_insert(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end local ok,n=pcall(function() return inv.insert({name=item,count=count}) end); return ok and (tonumber(n) or 0) or 0 end
local function inv_can_insert(inv,item,count) if not (inv and inv.valid and item) then return false end local ok,yes=pcall(function() return inv.can_insert({name=item,count=count or 1}) end); return ok and yes==true end

local function readiness()
  local module=rawget(_G,"TechPriestsEnergyFamilyReadiness0705")
  if module then return module end
  local ok,loaded=pcall(require,"scripts.core.energy_family_readiness_0705")
  return ok and loaded or nil
end
local function storage_authority()
  local module=rawget(_G,"TechPriestsStorageRoleAuthority0686")
  if module then return module end
  local ok,loaded=pcall(require,"scripts.core.storage_role_authority_0686")
  return ok and loaded or nil
end

local function home_sources(pair)
  local out,seen={},{}
  if not valid_pair(pair) then return out end
  local radius=tonumber(pair.radius) or 28
  if type(_G.get_station_operating_radius)=="function" then local ok,value=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(value) then radius=tonumber(value) end end
  local home=station_unit(pair)
  local function add(source)
    local inv=source and source.inv; local entity=source and source.entity
    if not (inv and inv.valid and valid(entity)) then return end
    if entity.surface~=pair.station.surface or entity.force~=pair.station.force then return end
    if source.authority_source_station_0573 and tostring(source.authority_source_station_0573)~=tostring(home) then return end
    if dist_sq(entity.position,pair.station.position)>math.max(8,radius)^2 then return end
    local key=safe(inv); if seen[key] then return end; seen[key]=true
    out[#out+1]={inv=inv,entity=entity,label=source.source or source.inventory_id or "home-source"}
  end
  if type(_G.tech_priests_inventory_steward_sources_for_pair)=="function" then local ok,sources=pcall(_G.tech_priests_inventory_steward_sources_for_pair,pair); if ok and type(sources)=="table" then for _,source in ipairs(sources) do add(source) end end end
  return out
end

local function item_prototype(item) return prototypes and prototypes.item and prototypes.item[item] or nil end
local function fuel_value(item) local prototype=item_prototype(item); if not prototype then return 0 end local value=0; pcall(function() value=tonumber(prototype.fuel_value) or 0 end); return value end
local function burnt_result(item) local prototype=item_prototype(item); if not prototype then return nil end local result; pcall(function() result=prototype.burnt_result end); if type(result)=="table" then return result.name end; return type(result)=="string" and result or nil end
local function preference(item) for index,name in ipairs(FUEL_PREFERENCE) do if item==name then return index end end return 1000 end

local function selected_fuel_compatible(report,item)
  if not (report and report.fuel_inventory and report.fuel_inventory.valid and fuel_value(item)>0 and inv_can_insert(report.fuel_inventory,item,1)) then return false,"fuel-incompatible" end
  local result=burnt_result(item)
  if result then
    if not (report.burnt_inventory and report.burnt_inventory.valid) then return false,"missing-burnt-inventory" end
    if not inv_can_insert(report.burnt_inventory,result,1) then return false,"burnt-result-incompatible:"..result end
  end
  return true,"compatible"
end

local function source_for_fuel(pair,report,item)
  local best
  for _,source in ipairs(home_sources(pair)) do
    local count=inventory_count(source.inv,item)
    if count>0 then
      local compatible=selected_fuel_compatible(report,item)
      if compatible then local score=dist_sq(pair.priest.position,source.entity.position)-math.min(count,100); if not best or score<best.score then best={item=item,count=count,inv=source.inv,entity=source.entity,label=source.label,score=score} end end
    end
  end
  return best
end

local function compatible_fuel_names(report)
  local names={}; local seen={}
  local function add(item)
    if seen[item] then return end
    seen[item]=true
    local compatible=selected_fuel_compatible(report,item)
    if compatible then names[#names+1]=item end
  end
  for _,item in ipairs(FUEL_PREFERENCE) do if item_prototype(item) then add(item) end end
  local other={}
  for item_name in pairs(prototypes and prototypes.item or {}) do if fuel_value(item_name)>0 and not seen[item_name] then other[#other+1]=item_name end end
  table.sort(other,function(a,b) local av,bv=fuel_value(a),fuel_value(b); if av~=bv then return av<bv end return a<b end)
  for _,item in ipairs(other) do add(item) end
  return names
end

local function select_fuel(pair,report)
  local current=report and report.burner and report.burner.currently_burning
  if current then local source=source_for_fuel(pair,report,current); if source then return source end end
  for _,item in ipairs(compatible_fuel_names(report)) do local source=source_for_fuel(pair,report,item); if source then source.preference=preference(item); return source end end
  local names=compatible_fuel_names(report)
  return nil,names[1]
end

local function reservation_authority()
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations"); if ok then reservations=module end end
  return reservations
end
local function claim_target(pair,task)
  local reservations=reservation_authority(); if not (reservations and type(reservations.claim)=="function" and valid(task.target)) then return false,"reservation-unavailable" end
  return reservations.claim("machine-logistics",task.target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family=task.family,item=task.item,source="energy-family-logistics-0707"})
end
local function release_target(pair,task) local reservations=reservation_authority(); if reservations and type(reservations.release)=="function" and task and valid(task.target) then pcall(reservations.release,"machine-logistics",task.target,pair) end end

local function candidate_from_reports(pair)
  local reports=pair.energy_family_reports_0705
  if type(reports)~="table" then local doctrine=readiness(); if doctrine and type(doctrine.scan_pair)=="function" then pcall(doctrine.scan_pair,pair,true); reports=pair.energy_family_reports_0705 end end
  local burnt_candidate,fuel_candidate
  for _,report in ipairs(type(reports)=="table" and reports or {}) do
    if valid(report.entity) and report.burnt_inventory and report.burnt_inventory.valid and report.burnt_count>0 then
      local entries=contents(report.burnt_inventory); table.sort(entries,function(a,b) return a.name<b.name end)
      if entries[1] then local score=dist_sq(pair.priest.position,report.entity.position); if not burnt_candidate or score<burnt_candidate.score then burnt_candidate={family="burnt-result-clear",target=report.entity,target_name=report.entity_name,target_unit=report.entity_unit,item=entries[1].name,count=math.min(entries[1].count,M.max_burnt_transfer),source_inv=report.burnt_inventory,source_entity=report.entity,report=report,score=score} end end
    end
    if report.state=="fuel-service-eligible" and report.fuel_inventory and report.fuel_inventory.valid then
      local source,request_item=select_fuel(pair,report)
      local item=source and source.item or request_item
      if item then local missing=math.max(1,M.target_fuel_count-(tonumber(report.fuel_count) or 0)); local score=dist_sq(pair.priest.position,report.entity.position); if not fuel_candidate or score<fuel_candidate.score then fuel_candidate={family="energy-fuel",target=report.entity,target_name=report.entity_name,target_unit=report.entity_unit,item=item,count=math.min(missing,M.max_fuel_transfer),source=source,report=report,score=score} end end
    end
  end
  return burnt_candidate or fuel_candidate
end

local function request_move(pair,target,reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  pair.target=target
  if type(_G.tech_priests_request_movement_0418)=="function" then local ok,result=pcall(_G.tech_priests_request_movement_0418,pair,target.position,reason or "energy-family-logistics-0707",{owner="energy-family-logistics-0707",priority=M.move_priority,ttl=M.move_ttl,radius=1.2,distraction=defines and defines.distraction and defines.distraction.none or nil}); if ok and result~=false then return true end end
  return false
end

local function clear_requests(pair,task)
  for _,field in ipairs({"active_supply_request","logistic_requested_item"}) do local request=pair[field]; if type(request)=="table" and request.source=="energy-family-logistics-0707" and (not task or request.target_unit==task.target_unit) then pair[field]=nil end end
end
local function create_request(pair,task)
  pair.active_supply_request={item=task.item,count=task.count,source="energy-family-logistics-0707",purpose="energy-fuel",target_unit=task.target_unit,target_name=task.target_name,tick=now()}
  pair.logistic_requested_item={item=task.item,count=task.count,source="energy-family-logistics-0707",purpose="energy-fuel",target_unit=task.target_unit}
  task.phase="waiting-source"; task.request_tick=task.request_tick or now(); stat("fuel_item_requests")
end

local function sync_custody(pair,task,reason)
  if task and task.carried and task.carried.item and (tonumber(task.carried.count) or 0)>0 then pair.energy_family_custody_0707={version=M.version,tick=now(),family=task.family,item=task.carried.item,count=task.carried.count,target_unit=task.target_unit,target_name=task.target_name,source_entity=task.source_entity,source_label=task.source_label,reason=reason or task.phase}; return true end
  pair.energy_family_custody_0707=nil; return false
end

local function finish(pair,task,reason)
  release_target(pair,task); clear_requests(pair,task); pair.energy_family_custody_0707=nil; task.phase="complete"; task.completed_tick=now(); task.result=reason; pair.energy_family_logistics_last_task_0707=task; pair.energy_family_logistics_0707=nil
  local leaf=pair.active_leaf_task_0655; if type(leaf)=="table" and leaf.source=="energy_family_logistics_0707" then pair.active_leaf_task_0655=nil; pair.actual_task_status_0655=nil; pair.current_work_target_0655=nil end
  if lower(pair.mode):find("energy%-family",1,false) then pair.mode="idle" end
  record(pair,"energy-task-finished",safe(task.family).." "..safe(reason)); return true,reason
end
local function abort(pair,task,reason) release_target(pair,task); clear_requests(pair,task); task.phase="aborted"; task.result=reason; pair.energy_family_logistics_last_task_0707=task; pair.energy_family_logistics_0707=nil; record(pair,"energy-task-aborted",safe(task.family).." "..safe(reason)); return false,reason end

local function restore_orphan(pair)
  local custody=pair.energy_family_custody_0707
  if not (type(custody)=="table" and custody.item and (tonumber(custody.count) or 0)>0) or pair.energy_family_logistics_0707 then return false end
  pair.energy_family_logistics_0707={version=M.version,family=custody.family or "custody-recovery",phase="return-custody",item=custody.item,count=custody.count,carried={item=custody.item,count=custody.count},source_entity=custody.source_entity,source_label=custody.source_label,started_tick=now(),custody_recovery=true}
  pair.mode="energy-family-custody-recovery"; record(pair,"energy-orphan-custody-restored",custody.item.." x"..safe(custody.count),true); return true
end

local function return_to_station(pair,task)
  local carried=task.carried; if not (carried and carried.item and carried.count>0) then return finish(pair,task,"empty-custody") end
  if dist_sq(pair.priest.position,pair.station.position)>M.station_reach_sq then task.phase="return-custody"; pair.mode="energy-family-returning"; request_move(pair,pair.station,"energy-custody-return-0707"); sync_custody(pair,task,"returning-station"); return true,"returning-station" end
  local authority=storage_authority(); local ok,why,inserted=false,"no-storage-authority",0
  if authority and type(authority.deposit_exact)=="function" then ok,why,inserted=authority.deposit_exact(pair,carried.item,carried.count,task.family=="burnt-result-clear" and "energy-burnt-result-retention" or "energy-fuel-return",{}) end
  inserted=tonumber(inserted) or 0
  if ok and inserted>0 then carried.count=carried.count-inserted end
  if carried.count<=0 then return finish(pair,task,"custody-stored") end
  sync_custody(pair,task,"station-storage-blocked"); record(pair,"energy-custody-storage-blocked",carried.item.." remaining="..safe(carried.count).." reason="..safe(why)); return true,"storage-blocked"
end

local function source_current(pair,task)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity) and inventory_count(task.source_inv,task.item)>0 then return {inv=task.source_inv,entity=task.source_entity,item=task.item,count=inventory_count(task.source_inv,task.item),label=task.source_label} end
  if task.family~="energy-fuel" then return nil end
  local report=task.report; if not report then return nil end
  return source_for_fuel(pair,report,task.item)
end

local function revalidate_target(pair,task)
  if not valid(task.target) then return nil,"target-invalid" end
  local doctrine=readiness(); if not (doctrine and type(doctrine.inspect_entity)=="function") then return nil,"readiness-unavailable" end
  local report=doctrine.inspect_entity(pair,task.target,true)
  task.report=report
  if not report then return nil,"readiness-failed" end
  if task.family=="energy-fuel" then
    if report.state~="fuel-service-eligible" then return report,"target-not-eligible:"..safe(report.state) end
    local compatible,why=selected_fuel_compatible(report,task.item); if not compatible then return report,why end
  end
  return report,"ready"
end

local function begin(pair,candidate,reason)
  local task={version=M.version,family=candidate.family,phase="new",target=candidate.target,target_name=candidate.target_name,target_unit=candidate.target_unit,item=candidate.item,count=math.max(1,tonumber(candidate.count) or 1),source_inv=candidate.source_inv or candidate.source and candidate.source.inv or nil,source_entity=candidate.source_entity or candidate.source and candidate.source.entity or nil,source_label=candidate.source and candidate.source.label or candidate.family=="burnt-result-clear" and "burnt-result-inventory" or nil,report=candidate.report,started_tick=now(),reason=reason}
  local claimed,why=claim_target(pair,task); if not claimed then return false,"target-reserved:"..safe(why) end
  pair.energy_family_logistics_0707=task; pair.mode="energy-family-logistics"
  if task.family=="burnt-result-clear" then task.phase="move-to-source"; request_move(pair,task.target,"energy-burnt-result-pickup-0707"); record(pair,"burnt-result-task-began",task.item.." x"..safe(task.count).." from "..safe(task.target_name)); return true,"moving-to-burnt-result" end
  if not task.source_entity then create_request(pair,task); record(pair,"fuel-task-waiting-source",task.item.." -> "..safe(task.target_name)); return false,"waiting-source" end
  task.phase="move-to-source"; request_move(pair,task.source_entity,"energy-fuel-source-0707"); record(pair,"fuel-task-began",task.item.." x"..safe(task.count).." -> "..safe(task.target_name)); return true,"moving-to-fuel-source"
end

local function continue(pair,task)
  if TERMINAL[lower(task.phase)] then return finish(pair,task,task.phase) end
  if valid(pair.combat_target) then if task.carried then sync_custody(pair,task,"combat-suspended"); return false,"combat-suspended" end; return abort(pair,task,"combat-priority") end
  if task.carried and task.phase=="return-custody" then return return_to_station(pair,task) end
  if not valid(task.target) then if task.carried then task.phase="return-custody"; return return_to_station(pair,task) end; return abort(pair,task,"target-invalid") end

  if task.phase=="waiting-source" then
    if now()-(tonumber(task.request_tick) or now())>=M.request_timeout then return abort(pair,task,"fuel-source-timeout") end
    local source=source_current(pair,task); if not source then create_request(pair,task); return false,"waiting-source" end
    task.source_inv=source.inv; task.source_entity=source.entity; task.source_label=source.label; task.phase="move-to-source"; request_move(pair,source.entity,"energy-fuel-source-ready-0707"); return true,"source-ready"
  end

  if task.phase=="move-to-source" then
    local source
    if task.family=="burnt-result-clear" then source={inv=task.source_inv,entity=task.target,item=task.item,count=inventory_count(task.source_inv,task.item),label="burnt-result-inventory"} else source=source_current(pair,task) end
    if not (source and source.inv and source.inv.valid and valid(source.entity) and source.count>0) then if task.family=="energy-fuel" then task.phase="waiting-source"; task.request_tick=now(); create_request(pair,task); return false,"source-lost" end; return abort(pair,task,"burnt-result-source-empty") end
    if dist_sq(pair.priest.position,source.entity.position)>M.pickup_reach_sq then request_move(pair,source.entity,"energy-item-source-0707"); return true,"moving-to-source" end
    local want=math.max(1,math.min(task.count,source.count,task.family=="energy-fuel" and M.max_fuel_transfer or M.max_burnt_transfer)); local removed=inv_remove(source.inv,task.item,want)
    if removed<=0 then return abort(pair,task,"source-remove-failed") end
    task.carried={item=task.item,count=removed}; clear_requests(pair,task); sync_custody(pair,task,"picked-up"); record(pair,"energy-item-picked-up",task.family.." "..task.item.." x"..safe(removed))
    if task.family=="burnt-result-clear" then task.phase="return-custody"; request_move(pair,pair.station,"energy-burnt-return-0707"); return true,"returning-burnt-result" end
    task.phase="move-to-target"; request_move(pair,task.target,"energy-fuel-delivery-0707"); return true,"delivering-fuel"
  end

  if task.phase=="move-to-target" then
    if dist_sq(pair.priest.position,task.target.position)>M.target_reach_sq then request_move(pair,task.target,"energy-fuel-delivery-0707"); sync_custody(pair,task,"moving-to-target"); return true,"moving-to-target" end
    local report,why=revalidate_target(pair,task); if not report then task.phase="return-custody"; record(pair,"fuel-target-revalidation-failed",safe(why)); return return_to_station(pair,task) end
    if why~="ready" then task.phase="return-custody"; record(pair,"fuel-target-became-ineligible",safe(why)); return return_to_station(pair,task) end
    local carried=task.carried; local inserted=inv_insert(report.fuel_inventory,carried.item,carried.count)
    if inserted>0 then carried.count=carried.count-inserted; stat("fuel_items_delivered",inserted); record(pair,"fuel-delivered",carried.item.." x"..safe(inserted).." -> "..safe(task.target_name)) end
    if carried.count<=0 then return finish(pair,task,"fuel-delivered") end
    task.phase="return-custody"; sync_custody(pair,task,"fuel-partial"); request_move(pair,pair.station,"energy-fuel-leftover-return-0707"); return true,inserted>0 and "partial-fuel-delivery" or "fuel-insert-blocked"
  end

  if task.phase=="return-custody" then return return_to_station(pair,task) end
  return false,"unknown-phase:"..safe(task.phase)
end

local function blocker(pair)
  if valid(pair.combat_target) then return "combat" end
  if pair.item_family_logistics_0702 or pair.item_family_custody_0702 then return "item-family" end
  if pair.machine_logistics_0528 or pair.machine_logistics_custody_0682 then return "machine-logistics" end
  if pair.construction_task_0338 or pair.fluid_pipe_plan_0691 or pair.fluid_output_pipe_plan_0696 then return "construction" end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  for _,field in ipairs({"repair_0516","combat_repair_0517","consecration_0515"}) do local state=pair[field]; local phase=lower(type(state)=="table" and state.phase or ""); if phase~="" and phase~="complete" and phase~="completed" and phase~="done" then return field end end
  local leaf=pair.active_leaf_task_0655; if type(leaf)=="table" and leaf.source~="energy_family_logistics_0707" and now()-(tonumber(leaf.tick) or -1000000)<60*8 then return "leaf:"..safe(leaf.source) end
  return nil
end

function M.service_pair(pair,reason)
  if root().enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  restore_orphan(pair)
  local task=pair.energy_family_logistics_0707
  if task then return continue(pair,task) end
  local blocked=blocker(pair); if blocked then return false,"blocked:"..blocked end
  local candidate=candidate_from_reports(pair); if not candidate then return false,"no-energy-task" end
  return begin(pair,candidate,reason or "service")
end

local function energy_truth(pair)
  local task=pair and pair.energy_family_logistics_0707
  if not (type(task)=="table" and valid_pair(pair)) then return nil end
  local target,label,phase
  if task.phase=="move-to-source" and valid(task.source_entity or task.target) then target=task.source_entity or task.target; phase="collect-energy-item"; label="Collecting "..safe(task.item).." for "..safe(task.target_name)
  elseif task.phase=="move-to-target" and valid(task.target) then target=task.target; phase="deliver-fuel"; label="Delivering "..safe(task.item).." to "..safe(task.target_name)
  elseif task.phase=="return-custody" then target=pair.station; phase="return-energy-custody"; label="Returning "..safe(task.item).." to Cogitator"
  else return nil end
  return {family="logistics",phase=phase,entity=target,position={x=target.position.x,y=target.position.y},item=task.item,label=label,owner="energy-family-logistics-0707",priority=M.move_priority,radius=1.2,color={r=1,g=0.55,b=0.12,a=0.95},can_move=true,source="energy_family_logistics_0707"}
end

local function patch_leaf_truth()
  local ok,truth=pcall(require,"scripts.core.active_leaf_task_truth_0655")
  if not (ok and truth and type(truth.truth)=="function") or truth.energy_family_logistics_0707_wrapped then return false end
  truth.energy_family_logistics_0707_wrapped=true; previous_leaf_truth=truth.truth; truth.truth=function(pair) return previous_leaf_truth(pair) or energy_truth(pair) end; return true
end

function M.service_all(reason,budget)
  local count=0
  for _,pair in pairs(pair_map()) do if valid_pair(pair) then local ok,acted=pcall(M.service_pair,pair,reason or "pulse"); if ok and acted then count=count+1 end; if count>=(tonumber(budget) or 8) then break end end end
  return count
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.energy_family_logistics_0707_wrapped then return false end
  diag.energy_family_logistics_0707_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root(); local rr=storage and storage.tech_priests and storage.tech_priests.energy_family_readiness_0705 or {stats={}}; local rs=rr.stats or {}
    lines[#lines+1]="PAIR-DUMP-0468 ENERGY-FAMILY-LOGISTICS-0707 enabled="..safe(r.enabled).." readiness_eligible="..safe(rs["state_fuel-service-eligible"] or 0).." readiness_sufficient="..safe(rs["state_fuel-sufficient"] or 0).." requests="..safe(r.stats.fuel_item_requests or 0).." picked_up="..safe(r.stats["energy-item-picked-up"] or 0).." fuel_delivered="..safe(r.stats.fuel_items_delivered or 0).." burnt_cleared="..safe(r.stats["burnt-result-task-began"] or 0).." custody_restored="..safe(r.stats["energy-orphan-custody-restored"] or 0).." remote_removals=0 fluid_mutations=0 heat_mutations=0"
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then local task=pair.energy_family_logistics_0707 or {}; local custody=pair.energy_family_custody_0707 or {}; lines[#lines+1]="PAIR-DUMP-0468 energy-family["..safe(station_unit(pair)).."] family="..safe(task.family or "none").." phase="..safe(task.phase or "none").." item="..safe(task.item or custody.item or "none").." target="..safe(task.target_name or custody.target_name or "none").." custody="..safe(custody.count or 0) end end
    for i=math.max(1,#r.recent-10),#r.recent do local event=r.recent[i]; if event then lines[#lines+1]="PAIR-DUMP-0468 energy-family.recent["..safe(i).."] tick="..safe(event.tick).." action="..safe(event.action).." station="..safe(event.station).." priest="..safe(event.priest).." "..safe(event.detail) end end
    return lines
  end
  return true
end

function M.install()
  root(); patch_leaf_truth(); patch_diagnostics(); _G.TechPriestsEnergyFamilyLogistics0707=M
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="energy_family_logistics_0707",category="machine-logistics",interval=29,priority=58,budget=8,note="physical fuel delivery and burnt-result evacuation for readiness-approved energy entities",fn=function(_,budget) local n=M.service_all("broker",budget); return n>0,"acted="..safe(n) end}) end
  if log then log("[Tech-Priests 0.1.673] physical fuel and burnt-result energy-family logistics armed") end
  return true
end

return M
