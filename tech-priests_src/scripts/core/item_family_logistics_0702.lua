-- Tech Priests 0.1.671 family-specific physical item logistics.
--
-- Extends station-bound service to three item-only families without folding them
-- into the assembler/furnace executor:
--   * paired hidden proxy weapon ammunition;
--   * visible unautomated ammunition turrets;
--   * visible unautomated laboratories using current research ingredients.
--
-- Every transfer is physical and two-legged: walk to the exact home-local source,
-- remove the exact item into persistent custody, walk to the exact destination,
-- insert the exact count, and physically return leftovers. Missing items are
-- handed to the existing 0527/acquisition/production chain. No remote station
-- removal, direct target insertion, or deposit-first transfer is permitted.

local M = {
  version = "0.1.671",
  storage_key = "item_family_logistics_0702",
  pickup_reach_sq = 2.56,
  target_reach_sq = 2.56,
  return_reach_sq = 2.56,
  move_priority = 978,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  scan_interval = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 160,
  proxy_batch = 10,
  turret_target_count = 10,
  lab_cycles = 5,
  max_transfer = 50,
}

local previous_proxy_load
local previous_leaf_truth

local AMMO_ORDER = {
  "uranium-rounds-magazine",
  "piercing-rounds-magazine",
  "firearm-magazine",
}

local TERMINAL = {
  complete = true,
  completed = true,
  done = true,
  aborted = true,
  failed = true,
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
  local r=storage.tech_priests[M.storage_key] or {
    version=M.version,enabled=true,stats={},recent={},scan_due={}
  }
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.scan_due=r.scan_due or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail,force_log)
  local r=root(); stat(action)
  local event={tick=now(),action=tostring(action),station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),detail=tostring(detail or "")}
  r.recent[#r.recent+1]=event; while #r.recent>180 do table.remove(r.recent,1) end
  pair.item_family_logistics_last_0702=event
  if force_log and log then log("[Tech-Priests 0.1.671] "..event.action.." station="..event.station.." priest="..event.priest.." "..event.detail) end
end

local function inventory(entity,id)
  if not (valid(entity) and id and entity.get_inventory) then return nil end
  local ok,inv=pcall(function() return entity.get_inventory(id) end)
  return ok and inv and inv.valid and inv or nil
end
local function inv_count(inv,item) if not (inv and inv.valid and item) then return 0 end local ok,n=pcall(function() return inv.get_item_count(item) end); return ok and (tonumber(n) or 0) or 0 end
local function inv_remove(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end local ok,n=pcall(function() return inv.remove({name=item,count=count}) end); return ok and (tonumber(n) or 0) or 0 end
local function inv_insert(inv,item,count) if not (inv and inv.valid and item and count and count>0) then return 0 end local ok,n=pcall(function() return inv.insert({name=item,count=count}) end); return ok and (tonumber(n) or 0) or 0 end
local function inv_can_insert(inv,item,count) if not (inv and inv.valid and item) then return false end local ok,yes=pcall(function() return inv.can_insert({name=item,count=count or 1}) end); return ok and yes==true end

local function service_radius(pair)
  local radius=tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius)=="function" then local ok,value=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(value) then radius=tonumber(value) end end
  return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))
end

local function home_sources(pair)
  local out,seen={},{}
  if not valid_pair(pair) then return out end
  local home=station_unit(pair); local radius=service_radius(pair)
  local function add(source)
    local inv=source and source.inv; local entity=source and source.entity
    if not (inv and inv.valid and valid(entity)) then return end
    if entity.surface~=pair.station.surface or entity.force~=pair.station.force then return end
    if source.authority_source_station_0573 and tostring(source.authority_source_station_0573)~=tostring(home) then return end
    if dist_sq(entity.position,pair.station.position)>radius*radius then return end
    local key=safe(inv); if seen[key] then return end; seen[key]=true
    out[#out+1]={inv=inv,entity=entity,label=source.source or source.inventory_id or "home-source"}
  end
  if type(_G.tech_priests_inventory_steward_sources_for_pair)=="function" then
    local ok,sources=pcall(_G.tech_priests_inventory_steward_sources_for_pair,pair)
    if ok and type(sources)=="table" then for _,source in ipairs(sources) do add(source) end end
  end
  local d=defines and defines.inventory
  if d then
    local station_inv=inventory(pair.station,d.chest)
    if station_inv then add({inv=station_inv,entity=pair.station,source="station-chest"}) end
  end
  return out
end

local function item_prototype(item) return prototypes and prototypes.item and prototypes.item[item] or nil end
local function is_ammo(item)
  local prototype=item_prototype(item); if not prototype then return false end
  local typ; pcall(function() typ=prototype.type end)
  if typ=="ammo" then return true end
  local category; pcall(function() category=prototype.ammo_category end)
  return category~=nil
end

local function contents(inv)
  local result={}; if not (inv and inv.valid) then return result end
  local ok,raw=pcall(function() return inv.get_contents() end); if not (ok and type(raw)=="table") then return result end
  for key,value in pairs(raw) do
    local name,count
    if type(key)=="string" then name=key; count=type(value)=="table" and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value)=="table" then name=value.name or value.item or value[1]; count=tonumber(value.count or value.amount or value[2]) end
    if type(name)=="string" and (tonumber(count) or 0)>0 then result[#result+1]={name=name,count=tonumber(count) or 1} end
  end
  return result
end

local function source_for_item(pair,item,target_inv)
  local best
  for _,source in ipairs(home_sources(pair)) do
    local count=inv_count(source.inv,item)
    if count>0 and (not target_inv or inv_can_insert(target_inv,item,1)) then
      local distance=dist_sq(pair.priest.position,source.entity.position)
      if not best or distance<best.distance then best={item=item,count=count,inv=source.inv,entity=source.entity,label=source.label,distance=distance} end
    end
  end
  return best
end

local function ammo_rank(item)
  for index,name in ipairs(AMMO_ORDER) do if item==name then return index end end
  return 100
end

local function best_ammo_source(pair,target_inv)
  local best
  for _,source in ipairs(home_sources(pair)) do
    for _,entry in ipairs(contents(source.inv)) do
      if is_ammo(entry.name) and inv_can_insert(target_inv,entry.name,1) then
        local rank=ammo_rank(entry.name)
        local score=rank*100000+dist_sq(pair.priest.position,source.entity.position)-math.min(entry.count,1000)
        if not best or score<best.score then best={item=entry.name,count=entry.count,inv=source.inv,entity=source.entity,label=source.label,score=score} end
      end
    end
  end
  return best
end

local function target_inventory(task)
  if not (task and valid(task.target) and defines and defines.inventory) then return nil end
  if task.family=="lab-science" then return inventory(task.target,defines.inventory.lab_input) end
  if task.family=="turret-ammo" or task.family=="proxy-ammo" then return inventory(task.target,defines.inventory.turret_ammo) end
  return nil
end

local function ensure_machine_reservation_category()
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations"); if ok then reservations=module end end
  if not reservations then return nil end
  local found=false; for _,category in ipairs(reservations.categories or {}) do if category=="machine-logistics" then found=true break end end
  if not found then reservations.categories=reservations.categories or {}; reservations.categories[#reservations.categories+1]="machine-logistics" end
  local r=type(reservations.root)=="function" and reservations.root() or nil
  if r then r.reservations=r.reservations or {}; r.reservations["machine-logistics"]=r.reservations["machine-logistics"] or {} end
  return reservations
end

local function claim_target(pair,task)
  if task.family=="proxy-ammo" then return true,"paired-proxy" end
  local reservations=ensure_machine_reservation_category()
  if not (reservations and type(reservations.claim)=="function" and valid(task.target)) then return false,"reservation-unavailable" end
  local ok,why=reservations.claim("machine-logistics",task.target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family=task.family,item=task.item,source="item-family-logistics-0702"})
  task.reserved_0702=ok==true
  return ok,why
end
local function release_target(pair,task)
  if not task or task.family=="proxy-ammo" then return end
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if reservations and type(reservations.release)=="function" and valid(task.target) then pcall(reservations.release,"machine-logistics",task.target,pair) end
end

local function connected_automation(entity)
  if not valid(entity) then return false end
  local box; pcall(function() box=entity.bounding_box end)
  local p=entity.position; local pad=3
  local area=box and {{box.left_top.x-pad,box.left_top.y-pad},{box.right_bottom.x+pad,box.right_bottom.y+pad}} or {{p.x-pad,p.y-pad},{p.x+pad,p.y+pad}}
  local entities={}; pcall(function() entities=entity.surface.find_entities_filtered({area=area,force=entity.force,type={"inserter","loader","loader-1x1"},limit=64}) or {} end)
  for _,candidate in pairs(entities) do
    if candidate.type=="inserter" then
      local pickup,drop; pcall(function() pickup=candidate.pickup_target end); pcall(function() drop=candidate.drop_target end)
      if pickup==entity or drop==entity then return true,candidate end
      local pickup_pos,drop_pos; pcall(function() pickup_pos=candidate.pickup_position end); pcall(function() drop_pos=candidate.drop_position end)
      if box and ((pickup_pos and pickup_pos.x>=box.left_top.x-0.25 and pickup_pos.x<=box.right_bottom.x+0.25 and pickup_pos.y>=box.left_top.y-0.25 and pickup_pos.y<=box.right_bottom.y+0.25) or (drop_pos and drop_pos.x>=box.left_top.x-0.25 and drop_pos.x<=box.right_bottom.x+0.25 and drop_pos.y>=box.left_top.y-0.25 and drop_pos.y<=box.right_bottom.y+0.25)) then return true,candidate end
    else
      local container; pcall(function() container=candidate.loader_container end)
      if container==entity or math.sqrt(dist_sq(candidate.position,entity.position))<=1.65 then return true,candidate end
    end
  end
  return false,nil
end

local function proxy_entity(pair)
  if not pair then return nil end
  for _,key in ipairs({"proxy","proxy_turret","combat_proxy","hidden_proxy_0293","proxy_0293"}) do if valid(pair[key]) then pair.proxy=pair[key]; return pair[key] end end
  local hardener=rawget(_G,"TechPriestsProxyAmmoHardener0649")
  if hardener and type(hardener.ensure_proxy)=="function" then local ok,proxy=pcall(hardener.ensure_proxy,pair); if ok and valid(proxy) then return proxy end end
  return nil
end

local function proxy_candidate(pair)
  local proxy=proxy_entity(pair); if not valid(proxy) then return nil end
  local inv=defines and defines.inventory and inventory(proxy,defines.inventory.turret_ammo) or nil
  if not inv then return nil end
  local total=0; for _,entry in ipairs(contents(inv)) do if is_ammo(entry.name) then total=total+entry.count end end
  if total>0 then return nil end
  local source=best_ammo_source(pair,inv)
  local item=source and source.item or "firearm-magazine"
  return {family="proxy-ammo",target=proxy,target_inv=inv,item=item,count=M.proxy_batch,source=source,priority=1000,label="proxy weapon"}
end

local function turret_candidate(pair,entity)
  if not valid(entity) or entity==pair.proxy or entity==proxy_entity(pair) then return nil end
  local automated=connected_automation(entity); if automated then return nil end
  local inv=defines and defines.inventory and inventory(entity,defines.inventory.turret_ammo) or nil
  if not inv then return nil end
  local total=0; for _,entry in ipairs(contents(inv)) do if is_ammo(entry.name) then total=total+entry.count end end
  if total>=M.turret_target_count then return nil end
  local source=best_ammo_source(pair,inv)
  local item=source and source.item or "firearm-magazine"
  return {family="turret-ammo",target=entity,target_inv=inv,item=item,count=math.max(1,M.turret_target_count-total),source=source,priority=800-total*10,label=entity.name,total=total}
end

local function research_ingredients(force)
  local out={}; local technology=force and force.current_research
  if not (technology and technology.valid) then return out,nil end
  local ingredients={}; pcall(function() ingredients=technology.research_unit_ingredients or {} end)
  for _,ingredient in pairs(ingredients or {}) do
    local name=ingredient.name or ingredient[1]; local amount=tonumber(ingredient.amount or ingredient[2]) or 1
    if type(name)=="string" and name~="" then out[#out+1]={name=name,amount=math.max(1,amount)} end
  end
  return out,technology
end

local function lab_candidate(pair,entity)
  if not valid(entity) then return nil end
  local automated=connected_automation(entity); if automated then return nil end
  local inv=defines and defines.inventory and inventory(entity,defines.inventory.lab_input) or nil
  if not inv then return nil end
  local ingredients,technology=research_ingredients(entity.force)
  if #ingredients==0 then return nil end
  local best
  for _,ingredient in ipairs(ingredients) do
    if inv_can_insert(inv,ingredient.name,1) or inv_count(inv,ingredient.name)>0 then
      local have=inv_count(inv,ingredient.name)
      local target=math.max(ingredient.amount,math.min(10,ingredient.amount*M.lab_cycles))
      if have<target then
        local source=source_for_item(pair,ingredient.name,inv)
        local missing=target-have
        local score=have*100+dist_sq(pair.priest.position,entity.position)
        if not best or score<best.score then best={family="lab-science",target=entity,target_inv=inv,item=ingredient.name,count=missing,source=source,priority=400-have*5,label=entity.name,research=technology.name,score=score} end
      end
    end
  end
  return best
end

local function routed_find(surface,filters,category,key,ttl)
  local scanner=rawget(_G,"TechPriestsScanRouting0610")
  if not scanner then local ok,module=pcall(require,"scripts.core.scan_routing_0610"); if ok then scanner=module end end
  if scanner and type(scanner.find_entities)=="function" then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*3})); return entities or {} end
  local ok,entities=pcall(function() return surface.find_entities_filtered(filters) end); return ok and entities or {}
end

local function scan_candidate(pair)
  local proxy=proxy_candidate(pair); if proxy then return proxy end
  local key=tostring(station_unit(pair) or "?"); local r=root()
  if (r.scan_due[key] or 0)>now() then return nil end
  r.scan_due[key]=now()+M.scan_interval
  local radius=service_radius(pair); local p=pair.station.position
  local entities=routed_find(pair.station.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type={"ammo-turret","lab"},limit=M.max_scan_entities},"item-family-logistics","item-family-logistics:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..key,60*3)
  local best
  for _,entity in pairs(entities) do
    local candidate=entity.type=="ammo-turret" and turret_candidate(pair,entity) or entity.type=="lab" and lab_candidate(pair,entity) or nil
    if candidate then
      candidate.distance=dist_sq(pair.priest.position,entity.position)
      local score=(tonumber(candidate.priority) or 0)*100000-candidate.distance
      if not best or score>best.score then candidate.score=score; best=candidate end
    end
  end
  return best
end

local function request_move(pair,target,reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  pair.target=target
  if type(_G.tech_priests_request_movement_0418)=="function" then local ok,result=pcall(_G.tech_priests_request_movement_0418,pair,target.position,reason or "item-family-logistics-0702",{owner="item-family-logistics-0702",priority=M.move_priority,ttl=M.move_ttl,radius=1.2,distraction=defines and defines.distraction and defines.distraction.none or nil}); if ok and result~=false then return true end end
  return false
end

local function matching_request(request,task)
  return type(request)=="table" and request.source=="item-family-logistics-0702" and request.item==task.item and (not request.target_unit or tostring(request.target_unit)==tostring(task.target_unit))
end
local function clear_requests(pair,task)
  for _,field in ipairs({"active_supply_request","logistic_requested_item"}) do if matching_request(pair[field],task) then pair[field]=nil end end
end
local function create_request(pair,task)
  pair.active_supply_request={item=task.item,count=task.count,source="item-family-logistics-0702",purpose=task.family,target_unit=task.target_unit,target_name=task.target_name,tick=now()}
  pair.logistic_requested_item={item=task.item,count=task.count,source="item-family-logistics-0702",purpose=task.family,target_unit=task.target_unit}
  task.phase="waiting-source"; task.request_tick=task.request_tick or now(); stat("item_requests_created")
end

local function sync_custody(pair,task,reason)
  if task and task.carried and task.carried.item and (tonumber(task.carried.count) or 0)>0 then
    pair.item_family_custody_0702={version=M.version,tick=now(),family=task.family,item=task.carried.item,count=task.carried.count,target_unit=task.target_unit,target_name=task.target_name,source_entity=task.source_entity,source_label=task.source_label,reason=reason or task.phase}
    return true
  end
  pair.item_family_custody_0702=nil; return false
end

local function finish_task(pair,task,reason)
  release_target(pair,task); clear_requests(pair,task); pair.item_family_custody_0702=nil
  task.phase="complete"; task.completed_tick=now(); task.result=reason or "complete"; pair.item_family_logistics_last_task_0702=task; pair.item_family_logistics_0702=nil
  local leaf=pair.active_leaf_task_0655; if type(leaf)=="table" and leaf.source=="item_family_logistics_0702" then pair.active_leaf_task_0655=nil; pair.actual_task_status_0655=nil; pair.current_work_target_0655=nil end
  if lower(pair.mode):find("item%-family",1,false) then pair.mode="idle" end
  record(pair,"family-task-finished",safe(task.family).." "..safe(reason))
  return true,reason or "complete"
end

local function abort_without_custody(pair,task,reason)
  release_target(pair,task); clear_requests(pair,task); task.phase="aborted"; task.result=reason; pair.item_family_logistics_last_task_0702=task; pair.item_family_logistics_0702=nil; record(pair,"family-task-aborted",safe(task.family).." "..safe(reason)); return false,reason
end

local function restore_orphan_custody(pair)
  local custody=pair.item_family_custody_0702
  if not (valid_pair(pair) and type(custody)=="table" and custody.item and (tonumber(custody.count) or 0)>0) or pair.item_family_logistics_0702 then return false end
  pair.item_family_logistics_0702={version=M.version,family=custody.family or "custody-recovery",phase="return-custody",item=custody.item,count=custody.count,carried={item=custody.item,count=custody.count},source_entity=custody.source_entity,source_label=custody.source_label,started_tick=now(),custody_recovery=true}
  pair.mode="item-family-custody-recovery"; record(pair,"orphan-custody-restored",custody.item.." x"..safe(custody.count),true); return true
end

local function source_current(task,pair)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity) and inv_count(task.source_inv,task.item)>0 then return {inv=task.source_inv,entity=task.source_entity,item=task.item,count=inv_count(task.source_inv,task.item),label=task.source_label} end
  return source_for_item(pair,task.item,target_inventory(task))
end

local function return_custody(pair,task)
  local carried=task.carried
  if not (carried and carried.item and (tonumber(carried.count) or 0)>0) then return finish_task(pair,task,"empty-custody") end
  local destination=valid(task.source_entity) and task.source_entity or pair.station
  if dist_sq(pair.priest.position,destination.position)>M.return_reach_sq then task.phase="return-custody"; pair.mode="item-family-returning-custody"; sync_custody(pair,task,"returning"); request_move(pair,destination,"item-family-return-custody-0702"); return true,"returning-custody" end
  local inserted=0
  if valid(task.source_entity) and task.source_inv and task.source_inv.valid then inserted=inv_insert(task.source_inv,carried.item,carried.count) end
  if inserted<carried.count and destination==pair.station then
    local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    if authority and type(authority.deposit_exact)=="function" then local ok,_,exact=authority.deposit_exact(pair,carried.item,carried.count-inserted,"item-family-custody-return",{}); if ok then inserted=inserted+(tonumber(exact) or 0) end end
  end
  if inserted>0 then carried.count=carried.count-inserted end
  if carried.count<=0 then return finish_task(pair,task,"custody-returned") end
  if destination~=pair.station then task.source_entity=pair.station; task.source_inv=nil; task.phase="return-custody"; request_move(pair,pair.station,"item-family-return-station-0702"); sync_custody(pair,task,"source-return-blocked"); return true,"returning-to-station" end
  sync_custody(pair,task,"return-blocked"); record(pair,"custody-return-blocked",carried.item.." remaining="..safe(carried.count)); return true,"custody-return-blocked"
end

local function begin_task(pair,candidate,reason)
  local task={version=M.version,family=candidate.family,phase="new",target=candidate.target,target_unit=valid(candidate.target) and candidate.target.unit_number or nil,target_name=valid(candidate.target) and candidate.target.name or nil,item=candidate.item,count=math.max(1,math.min(M.max_transfer,tonumber(candidate.count) or 1)),source_inv=candidate.source and candidate.source.inv or nil,source_entity=candidate.source and candidate.source.entity or nil,source_label=candidate.source and candidate.source.label or nil,started_tick=now(),reason=reason or "candidate",research=candidate.research}
  local claimed,why=claim_target(pair,task); if not claimed then return false,"target-reserved:"..safe(why) end
  pair.item_family_logistics_0702=task; pair.mode="item-family-logistics"
  if not candidate.source then create_request(pair,task); record(pair,"family-task-waiting-source",task.family.." "..task.item.." -> "..safe(task.target_name)); return false,"waiting-source" end
  task.phase="move-to-source"; request_move(pair,task.source_entity,"item-family-source-0702"); record(pair,"family-task-began",task.family.." "..task.item.." x"..safe(task.count).." -> "..safe(task.target_name)); return true,"moving-to-source"
end

local function continue_task(pair,task)
  if not valid_pair(pair) then return false,"invalid-pair" end
  if TERMINAL[lower(task.phase)] then return finish_task(pair,task,task.phase) end
  if task.family~="proxy-ammo" and valid(pair.combat_target) then
    if task.carried then sync_custody(pair,task,"combat-suspended"); return false,"combat-suspended" end
    return abort_without_custody(pair,task,"combat-priority")
  end
  if task.carried and not valid(task.target) then task.phase="return-custody"; return return_custody(pair,task) end
  if not task.carried and not valid(task.target) then return abort_without_custody(pair,task,"target-invalid") end

  if task.phase=="waiting-source" then
    if now()-(tonumber(task.request_tick) or now())>=M.request_timeout then return abort_without_custody(pair,task,"source-timeout") end
    local source=source_current(task,pair)
    if not source then create_request(pair,task); return false,"waiting-source" end
    task.source_inv=source.inv; task.source_entity=source.entity; task.source_label=source.label; task.phase="move-to-source"; request_move(pair,source.entity,"item-family-source-ready-0702"); return true,"source-ready"
  end

  if task.phase=="move-to-source" then
    local source=source_current(task,pair)
    if not source then task.phase="waiting-source"; task.request_tick=now(); create_request(pair,task); return false,"source-lost" end
    task.source_inv=source.inv; task.source_entity=source.entity; task.source_label=source.label
    if dist_sq(pair.priest.position,source.entity.position)>M.pickup_reach_sq then request_move(pair,source.entity,"item-family-source-0702"); return true,"moving-to-source" end
    local want=math.max(1,math.min(task.count,source.count,M.max_transfer)); local removed=inv_remove(source.inv,task.item,want)
    if removed<=0 then task.phase="waiting-source"; task.request_tick=now(); create_request(pair,task); return false,"source-remove-failed" end
    task.carried={item=task.item,count=removed}; task.phase="move-to-target"; clear_requests(pair,task); sync_custody(pair,task,"picked-up"); pair.mode="item-family-delivery"; request_move(pair,task.target,"item-family-delivery-0702"); record(pair,"family-item-picked-up",task.item.." x"..safe(removed).." source="..safe(source.label)); return true,"picked-up"
  end

  if task.phase=="move-to-target" then
    if dist_sq(pair.priest.position,task.target.position)>M.target_reach_sq then request_move(pair,task.target,"item-family-delivery-0702"); sync_custody(pair,task,"moving-to-target"); return true,"moving-to-target" end
    local inv=target_inventory(task); if not inv then task.phase="return-custody"; return return_custody(pair,task) end
    local carried=task.carried; if not carried then return abort_without_custody(pair,task,"custody-missing") end
    local inserted=inv_insert(inv,carried.item,carried.count)
    if inserted>0 then carried.count=carried.count-inserted; stat("family_items_delivered",inserted); record(pair,"family-item-delivered",task.family.." "..carried.item.." x"..safe(inserted).." -> "..safe(task.target_name)) end
    if carried.count<=0 then return finish_task(pair,task,"delivered") end
    task.phase="return-custody"; sync_custody(pair,task,"target-partial"); request_move(pair,valid(task.source_entity) and task.source_entity or pair.station,"item-family-leftover-return-0702"); return true,inserted>0 and "partial-delivery" or "target-insert-blocked"
  end

  if task.phase=="return-custody" then return return_custody(pair,task) end
  return false,"unknown-phase:"..safe(task.phase)
end

local function concrete_blocker(pair,urgent_proxy)
  if not valid_pair(pair) then return "invalid" end
  if pair.item_family_logistics_0702 then return nil end
  if not urgent_proxy and valid(pair.combat_target) then return "combat" end
  if pair.machine_logistics_0528 or pair.machine_logistics_custody_0682 then return "machine-logistics" end
  if pair.construction_task_0338 or pair.fluid_pipe_plan_0691 or pair.fluid_output_pipe_plan_0696 then return "construction" end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  for _,field in ipairs({"repair_0516","combat_repair_0517","consecration_0515"}) do local state=pair[field]; local phase=lower(type(state)=="table" and state.phase or ""); if phase~="" and phase~="complete" and phase~="completed" and phase~="done" then return field end end
  local leaf=pair.active_leaf_task_0655
  if type(leaf)=="table" and leaf.source~="item_family_logistics_0702" and now()-(tonumber(leaf.tick) or -1000000)<60*8 then return "leaf:"..safe(leaf.source) end
  return nil
end

function M.service_pair(pair,reason)
  if root().enabled==false or not valid_pair(pair) then return false,"disabled-or-invalid" end
  restore_orphan_custody(pair)
  local task=pair.item_family_logistics_0702
  if task then return continue_task(pair,task) end
  local candidate=scan_candidate(pair); if not candidate then return false,"no-family-task" end
  local urgent=candidate.family=="proxy-ammo"
  local blocked=concrete_blocker(pair,urgent); if blocked then return false,"blocked:"..blocked end
  return begin_task(pair,candidate,reason or "service")
end

local function family_truth(pair)
  local task=pair and pair.item_family_logistics_0702
  if not (type(task)=="table" and valid_pair(pair)) then return nil end
  local target,label,phase
  if task.phase=="move-to-source" and valid(task.source_entity) then target=task.source_entity; phase="collect-family-item"; label="Collecting "..safe(task.item).." for "..safe(task.target_name)
  elseif task.phase=="move-to-target" and valid(task.target) then target=task.target; phase="deliver-family-item"; label="Delivering "..safe(task.item).." to "..safe(task.target_name)
  elseif task.phase=="return-custody" then target=valid(task.source_entity) and task.source_entity or pair.station; phase="return-family-custody"; label="Returning unused "..safe(task.item)
  else return nil end
  return {family="logistics",phase=phase,entity=target,position={x=target.position.x,y=target.position.y},item=task.item,label=label,owner="item-family-logistics-0702",priority=M.move_priority,radius=1.2,color={r=1,g=0.72,b=0.18,a=0.95},can_move=true,source="item_family_logistics_0702"}
end

local function patch_leaf_truth()
  local ok,truth=pcall(require,"scripts.core.active_leaf_task_truth_0655")
  if not (ok and truth and type(truth.truth)=="function") or truth.item_family_logistics_0702_wrapped then return false end
  truth.item_family_logistics_0702_wrapped=true; previous_leaf_truth=truth.truth
  truth.truth=function(pair) return previous_leaf_truth(pair) or family_truth(pair) end
  return true
end

local function patch_proxy_hardener()
  local hardener=rawget(_G,"TechPriestsProxyAmmoHardener0649")
  if not hardener then local ok,module=pcall(require,"scripts.core.proxy_ammo_hardener_0649"); if ok then hardener=module end end
  if not (hardener and type(hardener.load_proxy_from_station)=="function") or hardener.item_family_logistics_0702_wrapped then return false end
  hardener.item_family_logistics_0702_wrapped=true; previous_proxy_load=hardener.load_proxy_from_station
  hardener.load_proxy_from_station=function(pair,reason)
    if not valid_pair(pair) then return false end
    if type(hardener.proxy_has_ammo)=="function" and hardener.proxy_has_ammo(pair) then return true end
    local task=pair.item_family_logistics_0702
    if task and task.family=="proxy-ammo" then M.service_pair(pair,reason or "proxy-load"); return type(hardener.proxy_has_ammo)=="function" and hardener.proxy_has_ammo(pair) or false end
    local candidate=proxy_candidate(pair); if not candidate then return false end
    local blocked=concrete_blocker(pair,true); if blocked then return false end
    begin_task(pair,candidate,reason or "proxy-load")
    return false
  end
  return true
end

function M.service_all(reason,budget)
  local count=0
  for _,pair in pairs(pair_map()) do if valid_pair(pair) then local ok,acted=pcall(M.service_pair,pair,reason or "pulse"); if ok and acted then count=count+1 end; if count>=(tonumber(budget) or 8) then break end end end
  return count
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.item_family_logistics_0702_wrapped then return false end
  diag.item_family_logistics_0702_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 ITEM-FAMILY-LOGISTICS-0702 enabled="..safe(r.enabled).." requests="..safe(r.stats.item_requests_created or 0).." picked_up="..safe(r.stats["family-item-picked-up"] or 0).." delivered="..safe(r.stats.family_items_delivered or 0).." custody_restored="..safe(r.stats["orphan-custody-restored"] or 0).." remote_station_removals=0 deposit_first_transfers=0"
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then local task=pair.item_family_logistics_0702 or {}; local custody=pair.item_family_custody_0702 or {}; lines[#lines+1]="PAIR-DUMP-0468 item-family["..safe(station_unit(pair)).."] family="..safe(task.family or "none").." phase="..safe(task.phase or "none").." item="..safe(task.item or custody.item or "none").." target="..safe(task.target_name or custody.target_name or "none").." custody="..safe(custody.count or 0) end end
    for i=math.max(1,#r.recent-10),#r.recent do local event=r.recent[i]; if event then lines[#lines+1]="PAIR-DUMP-0468 item-family.recent["..safe(i).."] tick="..safe(event.tick).." action="..safe(event.action).." station="..safe(event.station).." priest="..safe(event.priest).." "..safe(event.detail) end end
    return lines
  end
  return true
end

function M.install()
  root(); patch_proxy_hardener(); patch_leaf_truth(); patch_diagnostics(); _G.TechPriestsItemFamilyLogistics0702=M
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="item_family_logistics_0702",category="machine-logistics",interval=23,priority=56,budget=8,note="physical proxy ammo, visible turret ammo, and lab science-pack logistics",fn=function(_,budget) patch_proxy_hardener(); local n=M.service_all("broker",budget); return n>0,"acted="..safe(n) end}) end
  if log then log("[Tech-Priests 0.1.671] physical proxy, turret, and laboratory item logistics armed") end
  return true
end

return M
