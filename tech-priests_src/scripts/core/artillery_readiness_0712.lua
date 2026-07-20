-- scripts/core/artillery_readiness_0712.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical read-only artillery readiness and train-validity doctrine.

local M = {
  version = "0.1.674-dev",
  storage_key = "artillery_readiness_0712",
  scan_interval = 211,
  entity_cache_ticks = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 96,
  max_pairs_per_scan = 6,
  fallback_target_ammo = 5,
}

local ARTILLERY_TYPES = { "artillery-turret", "artillery-wagon" }
local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  return tostring(entity.surface and entity.surface.index or "?") .. ":"
    .. tostring(entity.name or "artillery") .. ":"
    .. tostring(math.floor((p.x or 0) * 10)) .. ":"
    .. tostring(math.floor((p.y or 0) * 10))
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    train_validity_integrated = true,
    automation_ownership_integrated = true,
    structured_scan_truth = true,
    stats = {}, recent = {}, scan_due = {}, entity_due = {}, reports = {}, cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.read_only == nil then state.read_only = true end
  if state.train_validity_integrated == nil then state.train_validity_integrated = true end
  if state.automation_ownership_integrated == nil then state.automation_ownership_integrated = true end
  if state.structured_scan_truth == nil then state.structured_scan_truth = true end
  state.stats = state.stats or {}; state.recent = state.recent or {}
  state.scan_due = state.scan_due or {}; state.entity_due = state.entity_due or {}
  state.reports = state.reports or {}; state.cursor = tonumber(state.cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root(); state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root(); stat(action)
  state.recent[#state.recent + 1] = {tick=now(),action=tostring(action or "event"),station=safe(station_unit(pair)),detail=tostring(detail or "")}
  while #state.recent > 120 do table.remove(state.recent, 1) end
end

local function inventory(entity)
  if not (valid(entity) and defines and defines.inventory) then return nil end
  local id = entity.type == "artillery-wagon" and defines.inventory.artillery_wagon_ammo or defines.inventory.artillery_turret_ammo
  if not id then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  return ok and inv and inv.valid and inv or nil
end
local function contents(inv)
  local out = {}; if not (inv and inv.valid) then return out end
  local ok, raw = pcall(function() return inv.get_contents() end); if not (ok and type(raw) == "table") then return out end
  for key, value in pairs(raw) do
    local name, count
    if type(key) == "string" then name=key; count=type(value)=="table" and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value)=="table" then name=value.name or value.item or value[1]; count=tonumber(value.count or value.amount or value[2]) end
    if type(name)=="string" and (tonumber(count) or 0)>0 then out[#out+1]={name=name,count=tonumber(count) or 1} end
  end
  table.sort(out,function(a,b)return a.name<b.name end); return out
end
local function total_count(inv) local total=0; for _,entry in ipairs(contents(inv)) do total=total+entry.count end; return total end
local function is_ammo(name)
  local prototype=prototypes and prototypes.item and prototypes.item[name]; if not prototype then return false end
  local typ; pcall(function() typ=prototype.type end); if typ=="ammo" then return true end
  local category; pcall(function() category=prototype.ammo_category end); return category~=nil
end
local function can_insert(inv,name)
  if not(inv and inv.valid and name) then return false end
  local ok,accepted=pcall(function() return inv.can_insert({name=name,count=1}) end); return ok and accepted==true
end
local function compatible_ammo(inv)
  local out={}; for name in pairs(prototypes and prototypes.item or {}) do if is_ammo(name) and can_insert(inv,name) then out[#out+1]=name end end
  table.sort(out); return out
end
local function target_count(entity)
  local automated,stack_limit; pcall(function() automated=tonumber(entity.prototype.automated_ammo_count) end); pcall(function() stack_limit=tonumber(entity.prototype.ammo_stack_limit) end)
  local target=automated or M.fallback_target_ammo; if stack_limit and stack_limit>0 then target=math.min(target,stack_limit) end
  return math.max(1,math.floor(target or M.fallback_target_ammo))
end
local function position_inside_box(position,box,padding)
  if not(position and box and box.left_top and box.right_bottom) then return false end
  padding=tonumber(padding) or 0.25
  return position.x>=box.left_top.x-padding and position.x<=box.right_bottom.x+padding and position.y>=box.left_top.y-padding and position.y<=box.right_bottom.y+padding
end
function M.connected_item_automation(entity)
  if not valid(entity) then return false,{} end
  local reasons={}; local box; pcall(function() box=entity.bounding_box end); local p=entity.position; local pad=3
  local area=box and {{box.left_top.x-pad,box.left_top.y-pad},{box.right_bottom.x+pad,box.right_bottom.y+pad}} or {{p.x-pad,p.y-pad},{p.x+pad,p.y+pad}}
  local nearby={}; pcall(function() nearby=entity.surface.find_entities_filtered({area=area,force=entity.force,type={"inserter","loader","loader-1x1"},limit=64}) or {} end)
  for _,candidate in pairs(nearby) do
    if candidate.type=="inserter" then
      local pickup,drop,pickup_position,drop_position
      pcall(function() pickup=candidate.pickup_target end); pcall(function() drop=candidate.drop_target end)
      pcall(function() pickup_position=candidate.pickup_position end); pcall(function() drop_position=candidate.drop_position end)
      if pickup==entity or drop==entity or position_inside_box(pickup_position,box,0.25) or position_inside_box(drop_position,box,0.25) then reasons[#reasons+1]="connected-inserter:"..safe(candidate.unit_number) end
    else
      local container; pcall(function() container=candidate.loader_container end)
      if container==entity or dist_sq(candidate.position,entity.position)<=2.7225 then reasons[#reasons+1]="connected-loader:"..safe(candidate.unit_number) end
    end
  end
  return #reasons>0,reasons
end
local function train_state_name(state)
  if not(defines and defines.train_state) then return safe(state) end
  for name,value in pairs(defines.train_state) do if value==state then return name end end; return safe(state)
end
function M.train_status(entity)
  if not(valid(entity) and entity.type=="artillery-wagon") then return{applicable=false,train=nil,valid=true,stationary=true,manual_mode=true,safe_for_manual_service=true,reason="not-wagon",speed=0} end
  local train; pcall(function() train=entity.train end)
  if not(train and train.valid) then return{applicable=true,train=nil,valid=false,stationary=true,manual_mode=false,safe_for_manual_service=false,reason="invalid-or-detached-train",state_name="invalid-or-detached-train",speed=0} end
  local speed,state,manual,station,schedule
  pcall(function() speed=tonumber(train.speed) or 0 end); pcall(function() state=train.state end); pcall(function() manual=train.manual_mode==true end); pcall(function() station=train.station end); pcall(function() schedule=train.schedule end)
  local stationary=math.abs(speed or 0)<0.001
  local reason=not stationary and "train-moving" or manual~=true and "train-not-manual" or "stationary-manual-train"
  return{applicable=true,train=train,valid=true,speed=speed or 0,stationary=stationary,manual_mode=manual==true,state=state,state_name=train_state_name(state),station=station,station_name=valid(station) and station.backer_name or nil,has_schedule=schedule~=nil,safe_for_manual_service=stationary and manual==true,reason=reason}
end
local function runtime_status(entity)
  local status,target,orientation,damage
  pcall(function() status=entity.status end); pcall(function() target=entity.shooting_target end); pcall(function() orientation=entity.turret_orientation end); pcall(function() damage=tonumber(entity.damage_dealt) or 0 end)
  return{status=status,shooting_target=target,shooting=valid(target),turret_orientation=orientation,damage_dealt=damage or 0}
end
function M.inspect_entity(pair,entity,force)
  if not(valid_pair(pair) and valid(entity) and (entity.type=="artillery-turret" or entity.type=="artillery-wagon")) then return nil,"invalid" end
  local key=entity_key(entity); local state=M.root()
  if not force and key and (tonumber(state.entity_due[key]) or 0)>now() then return state.reports[key],"cached" end
  if key then state.entity_due[key]=now()+M.entity_cache_ticks end
  local inv=inventory(entity); local ammo=contents(inv); local count=total_count(inv); local accepted=compatible_ammo(inv); local target=target_count(entity)
  local automated,automation_reasons=M.connected_item_automation(entity); local train=M.train_status(entity); local runtime=runtime_status(entity)
  local readiness_state,severity
  if not inv then readiness_state,severity="ammo-inventory-unavailable","blocked"
  elseif #accepted==0 then readiness_state,severity="no-compatible-artillery-ammo","blocked"
  elseif entity.type=="artillery-wagon" and train.valid~=true then readiness_state,severity="invalid-train-monitor","monitor"
  elseif entity.type=="artillery-wagon" and train.stationary~=true then readiness_state,severity="moving-train-monitor","monitor"
  elseif entity.type=="artillery-wagon" and train.manual_mode~=true then readiness_state,severity="automatic-train-owned","monitor"
  elseif automated then readiness_state,severity="external-item-automation-owned","monitor"
  elseif count>=target then readiness_state,severity="ammo-sufficient","ready"
  else readiness_state,severity="manual-ammo-service-eligible","eligible" end
  local report={version=M.version,tick=now(),read_only=true,train_validity_integrated=true,automation_ownership_integrated=true,entity=entity,entity_name=entity.name,entity_unit=entity.unit_number,entity_type=entity.type,station_unit=station_unit(pair),state=readiness_state,severity=severity,ammo_inventory=inv,ammo_contents=ammo,ammo_count=count,target_ammo_count=target,missing_ammo_count=math.max(0,target-count),compatible_ammo=accepted,connected_item_automation=automated,automation_reasons=automation_reasons,train=train,runtime=runtime}
  if key then state.reports[key]=report end; stat("entities-inspected"); stat("state-"..readiness_state); return report,"inspected"
end
local function service_radius(pair)
  local radius=tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius)=="function" then local ok,value=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(value) then radius=tonumber(value) end end
  return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))
end
local function routed_find(surface,filters,category,key,ttl)
  local scanner=rawget(_G,"TechPriestsScanRouting0610") or package.loaded["scripts.core.scan_routing_0610"]
  if not scanner then local ok,module=pcall(require,"scripts.core.scan_routing_0610"); if ok then scanner=module end end
  if scanner and type(scanner.find_entities)=="function" then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*4})); return entities or {} end
  local ok,entities=pcall(function() return surface.find_entities_filtered(filters) end); return ok and entities or {}
end
function M.scan_pair(pair,force)
  if M.root().enabled==false or not valid_pair(pair) then return{processed=0,acted=0,failed=not valid_pair(pair) and 1 or 0,detail="disabled-or-invalid"} end
  local key=tostring(station_unit(pair) or "?"); local state=M.root()
  if not force and (tonumber(state.scan_due[key]) or 0)>now() then return{processed=0,acted=0,detail="cooldown"} end
  state.scan_due[key]=now()+M.scan_interval; local radius=service_radius(pair); local p=pair.station.position
  local entities=routed_find(pair.station.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type=ARTILLERY_TYPES,limit=M.max_scan_entities},"artillery-readiness","artillery-readiness:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..key,60*4)
  local reports={}; local eligible,moving,automatic,invalid,external=0,0,0,0,0
  for _,entity in pairs(entities) do local report=M.inspect_entity(pair,entity,false); if report then reports[#reports+1]=report; if report.state=="manual-ammo-service-eligible" then eligible=eligible+1 end; if report.state=="moving-train-monitor" then moving=moving+1 end; if report.state=="automatic-train-owned" then automatic=automatic+1 end; if report.state=="invalid-train-monitor" then invalid=invalid+1 end; if report.state=="external-item-automation-owned" then external=external+1 end end end
  pair.artillery_reports_0712=reports; pair.artillery_summary_0712={version=M.version,tick=now(),inspected=#reports,eligible=eligible,moving_wagons=moving,automatic_wagons=automatic,invalid_wagons=invalid,external_owned=external,read_only=true}
  stat("pair-scans"); stat("eligible-found",eligible)
  return{processed=#reports,acted=0,failed=0,detail="inspected="..#reports.." eligible="..eligible.." invalid="..invalid}
end
local function scan_pairs(budget)
  local state=M.root(); if state.enabled==false then return{processed=0,acted=0,detail="disabled"} end
  local list={}; for key,pair in pairs(pair_map()) do if valid_pair(pair) then list[#list+1]={key=tostring(key),pair=pair} end end; table.sort(list,function(a,b)return a.key<b.key end)
  if #list==0 then return{processed=0,acted=0,detail="no-pairs"} end
  local limit=math.max(1,math.min(#list,math.floor(tonumber(budget) or M.max_pairs_per_scan))); local start=state.cursor%#list+1; local processed,failed=0,0
  for index=0,limit-1 do local pair=list[((start+index-1)%#list)+1].pair; local ok,result=pcall(M.scan_pair,pair,false); if ok and type(result)=="table" then processed=processed+(tonumber(result.processed) or 0); failed=failed+(tonumber(result.failed) or 0) else failed=failed+1; record(pair,"readiness-scan-error",result) end end
  state.cursor=(start+limit-2)%#list+1; return{processed=processed,acted=0,failed=failed,exhausted=#list>limit,detail="pairs="..limit.." entities="..processed.." failed="..failed}
end
local function patch_diagnostics()
  local diagnostics=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not(diagnostics and type(diagnostics.pair_dump_lines)=="function") then return false end
  if diagnostics.artillery_readiness_0712_wrapped then return true end
  diagnostics.artillery_readiness_0712_wrapped=true; local previous=diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines=function(...) local lines=previous(...); lines=type(lines)=="table" and lines or {}; local state=M.root(); lines[#lines+1]="PAIR-DUMP-0468 ARTILLERY-READINESS-0712 enabled="..safe(state.enabled).." read_only=true train_validity=integrated automation_ownership=integrated ammo_mutations=0 train_mutations=0 inspected="..safe(state.stats["entities-inspected"] or 0).." eligible="..safe(state.stats["state-manual-ammo-service-eligible"] or 0).." invalid="..safe(state.stats["state-invalid-train-monitor"] or 0).." moving="..safe(state.stats["state-moving-train-monitor"] or 0).." automatic="..safe(state.stats["state-automatic-train-owned"] or 0).." external="..safe(state.stats["state-external-item-automation-owned"] or 0); return lines end
  return true
end
function M.install()
  M.root(); local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600"); if not(broker and type(broker.register_service)=="function") then return false end
  local service=broker.register_service({name="artillery_readiness_0712",category="discovery",interval=M.scan_interval,priority=77,budget=M.max_pairs_per_scan,note="read-only artillery readiness and train validity inspection",fn=function(_,budget)return scan_pairs(budget)end})
  if not service then return false end; patch_diagnostics(); _G.TechPriestsArtilleryReadiness0712=M; _G.tech_priests_artillery_inspect_0712=M.inspect_entity
  if log then log("[Tech-Priests recovery] canonical read-only artillery readiness installed") end; return true
end
return M
