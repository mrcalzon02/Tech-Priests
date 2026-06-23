-- Tech Priests 0.1.671 family-logistics integrity guard.
--
-- Ensures ammunition requests are compatible with the exact proxy/turret
-- inventory and prevents stale laboratory deliveries after current research
-- changes. Incompatible carried ammunition is returned physically; it is never
-- relabelled. Stale uncarried lab work is released cleanly.

local M = {
  version = "0.1.671",
  storage_key = "item_family_integrity_0703",
}

local previous_family_install
local previous_family_service

local AMMO_ORDER = {
  "uranium-rounds-magazine",
  "piercing-rounds-magazine",
  "firearm-magazine",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

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
local function record(pair,action,detail)
  local r=root(); stat(action)
  r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>120 do table.remove(r.recent,1) end
end

local function inventory(entity,id)
  if not (valid(entity) and id and entity.get_inventory) then return nil end
  local ok,inv=pcall(function() return entity.get_inventory(id) end)
  return ok and inv and inv.valid and inv or nil
end
local function can_insert(inv,item)
  if not (inv and inv.valid and item) then return false end
  local ok,yes=pcall(function() return inv.can_insert({name=item,count=1}) end)
  return ok and yes==true
end
local function is_ammo(item)
  local prototype=prototypes and prototypes.item and prototypes.item[item]
  if not prototype then return false end
  local typ; pcall(function() typ=prototype.type end)
  if typ=="ammo" then return true end
  local category; pcall(function() category=prototype.ammo_category end)
  return category~=nil
end

local function target_ammo_inventory(task)
  if not (task and valid(task.target) and defines and defines.inventory) then return nil end
  return inventory(task.target,defines.inventory.turret_ammo)
end

local function compatible_ammo(inv)
  for _,item in ipairs(AMMO_ORDER) do
    if prototypes and prototypes.item and prototypes.item[item] and can_insert(inv,item) then return item end
  end
  local names={}
  for item_name in pairs(prototypes and prototypes.item or {}) do
    if is_ammo(item_name) and can_insert(inv,item_name) then names[#names+1]=item_name end
  end
  table.sort(names)
  return names[1]
end

local function clear_family_requests(pair,task)
  for _,field in ipairs({"active_supply_request","logistic_requested_item"}) do
    local request=pair[field]
    if type(request)=="table" and request.source=="item-family-logistics-0702"
      and (not task or not request.target_unit or tostring(request.target_unit)==tostring(task.target_unit))
    then
      pair[field]=nil
    end
  end
end

local function write_family_request(pair,task)
  pair.active_supply_request={
    item=task.item,count=task.count,source="item-family-logistics-0702",
    purpose=task.family,target_unit=task.target_unit,target_name=task.target_name,tick=now()
  }
  pair.logistic_requested_item={
    item=task.item,count=task.count,source="item-family-logistics-0702",
    purpose=task.family,target_unit=task.target_unit
  }
end

local function release_target(pair,task)
  if not task or task.family=="proxy-ammo" or not valid(task.target) then return end
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if reservations and type(reservations.release)=="function" then
    pcall(reservations.release,"machine-logistics",task.target,pair)
  end
end

local function cancel_uncarried_task(pair,task,reason)
  release_target(pair,task)
  clear_family_requests(pair,task)
  task.phase="aborted"
  task.result=reason
  task.completed_tick=now()
  pair.item_family_logistics_last_task_0702=task
  pair.item_family_logistics_0702=nil
  local leaf=pair.active_leaf_task_0655
  if type(leaf)=="table" and leaf.source=="item_family_logistics_0702" then
    pair.active_leaf_task_0655=nil
    pair.actual_task_status_0655=nil
    pair.current_work_target_0655=nil
  end
  record(pair,"stale-family-task-cancelled",safe(task.family).." "..safe(reason))
end

local function current_research_name(pair)
  local force=valid_pair(pair) and pair.station.force or nil
  local technology=force and force.current_research or nil
  return technology and technology.valid and technology.name or nil
end

local function normalize_ammo_task(pair,task)
  if not task or (task.family~="proxy-ammo" and task.family~="turret-ammo") then return true end
  local inv=target_ammo_inventory(task)
  if not inv then
    if task.carried then task.phase="return-custody"; record(pair,"ammo-target-inventory-lost",safe(task.target_name)); return false end
    cancel_uncarried_task(pair,task,"ammo-target-inventory-lost")
    return false
  end
  if can_insert(inv,task.item) then return true end
  if task.carried and (tonumber(task.carried.count) or 0)>0 then
    task.phase="return-custody"
    record(pair,"incompatible-carried-ammo-returned",safe(task.carried.item).." target="..safe(task.target_name))
    return false
  end
  local replacement=compatible_ammo(inv)
  if not replacement then
    cancel_uncarried_task(pair,task,"no-compatible-ammunition")
    return false
  end
  local old=task.item
  clear_family_requests(pair,task)
  task.item=replacement
  task.source_inv=nil
  task.source_entity=nil
  task.source_label=nil
  task.phase="waiting-source"
  task.request_tick=now()
  write_family_request(pair,task)
  record(pair,"ammunition-request-corrected",safe(old).." -> "..safe(replacement).." target="..safe(task.target_name))
  return true
end

local function normalize_lab_task(pair,task)
  if not task or task.family~="lab-science" then return true end
  local current=current_research_name(pair)
  if current and task.research==current then return true end
  if task.carried and (tonumber(task.carried.count) or 0)>0 then
    task.phase="return-custody"
    record(pair,"stale-lab-custody-returned",safe(task.research).." -> "..safe(current or "none"))
    return false
  end
  cancel_uncarried_task(pair,task,"research-changed:"..safe(task.research).."->"..safe(current or "none"))
  return false
end

local function normalize_task(pair)
  local task=pair and pair.item_family_logistics_0702
  if type(task)~="table" then return true end
  if not normalize_lab_task(pair,task) then return false end
  task=pair.item_family_logistics_0702
  if type(task)~="table" then return false end
  return normalize_ammo_task(pair,task)
end

local function patched_service_pair(pair,reason,...)
  if root().enabled==false or not valid_pair(pair) then
    return previous_family_service(pair,reason,...)
  end
  normalize_task(pair)
  local acted,why=previous_family_service(pair,reason,...)
  normalize_task(pair)
  return acted,why
end

local function remove_legacy_command()
  if commands and commands.remove_command then
    pcall(commands.remove_command,"tp-proxy-ammo-0649")
  end
end

local function patch_family(family)
  if not (family and type(family.service_pair)=="function") or family.item_family_integrity_0703_active then return false end
  family.item_family_integrity_0703_active=true
  previous_family_service=family.service_pair
  family.service_pair=patched_service_pair
  remove_legacy_command()
  return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.item_family_integrity_0703_wrapped then return false end
  diag.item_family_integrity_0703_wrapped=true
  local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 ITEM-FAMILY-INTEGRITY-0703 enabled="..safe(r.enabled)
      .." ammo_corrected="..safe(r.stats["ammunition-request-corrected"] or 0)
      .." incompatible_ammo_returned="..safe(r.stats["incompatible-carried-ammo-returned"] or 0)
      .." stale_lab_returned="..safe(r.stats["stale-lab-custody-returned"] or 0)
      .." stale_tasks_cancelled="..safe(r.stats["stale-family-task-cancelled"] or 0)
    return lines
  end
  return true
end

function M.activate(family)
  patch_family(family)
  patch_diagnostics()
  _G.TechPriestsItemFamilyIntegrity0703=M
  return true
end

function M.install()
  root()
  local ok,family=pcall(require,"scripts.core.item_family_logistics_0702")
  if not (ok and family) then return false end
  if not family.item_family_integrity_0703_install_wrapped then
    family.item_family_integrity_0703_install_wrapped=true
    previous_family_install=family.install
    family.install=function(...)
      local result=type(previous_family_install)=="function" and previous_family_install(...) or true
      M.activate(family)
      return result
    end
  end
  if rawget(_G,"TechPriestsItemFamilyLogistics0702") then M.activate(family) end
  remove_legacy_command()
  patch_diagnostics()
  _G.TechPriestsItemFamilyIntegrity0703=M
  if log then log("[Tech-Priests 0.1.671] ammo compatibility and current-research integrity guard armed") end
  return true
end

return M
