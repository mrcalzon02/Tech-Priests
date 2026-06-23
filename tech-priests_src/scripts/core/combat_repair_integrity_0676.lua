-- Tech Priests 0.1.662 combat-repair integrity hardener.
-- Preserves combat_repair_doctrine_0517 as the tactical selector and
-- repair_executor_0516 as the physical repair executor. This layer tightens
-- diplomatic/cover truth, verifies task handoff, releases stale cluster and
-- exact-target reservations, completes/aborts all connected state, compacts
-- noisy diagnostics, and removes the legacy runtime command.

local M = {
  version = "0.1.662",
  storage_key = "combat_repair_integrity_0676",
  history_window = 60,
}

local previous_find
local previous_recommend
local previous_service
local previous_abort
local previous_active
local previous_install

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function lower(value) return string.lower(tostring(value or "")) end
local function safe(value) if value == nil then return "nil" end local ok,text=pcall(tostring,value); return ok and text or "?" end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function dist_sq(a,b) if not(a and b) then return 999999999 end local dx=(a.x or a[1] or 0)-(b.x or b[1] or 0); local dy=(a.y or a[2] or 0)-(b.y or b[2] or 0); return dx*dx+dy*dy end
local function distance(a,b) return math.sqrt(dist_sq(a,b)) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function load_module(name, global_name)
  local ok,module=pcall(require,name)
  if ok then return module end
  return rawget(_G,global_name)
end

local function Doctrine() return load_module("scripts.core.combat_repair_doctrine_0517","TechPriestsCombatRepairDoctrine0517") end
local function Repair() return load_module("scripts.core.repair_executor_0516","TechPriestsRepairExecutor0516") end
local function Reservations() return load_module("scripts.core.work_reservations","TechPriestsWorkReservations0601") end
local function OrderQueue() return load_module("scripts.core.order_queue_0469","TECH_PRIESTS_ORDER_QUEUE_0469") end
local function Ammo() return rawget(_G,"TechPriestsProxyAmmoHardener0649") end

function M.root()
  storage.tech_priests=storage.tech_priests or {}
  local root=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=root
  root.version=M.version
  if root.enabled==nil then root.enabled=true end
  root.stats=root.stats or {}
  root.recent=root.recent or {}
  return root
end

local function stat(name,amount)
  local root=M.root()
  root.stats[name]=(root.stats[name] or 0)+(amount or 1)
end

local function record(pair,action,detail)
  local root=M.root()
  stat(action)
  root.recent[#root.recent+1]={tick=now(),station=station_unit(pair),priest=priest_unit(pair),action=tostring(action or "event"),detail=tostring(detail or "")}
  while #root.recent>140 do table.remove(root.recent,1) end
end

local function is_wallish(entity)
  if not valid(entity) then return false end
  local typ=lower(entity.type)
  local name=lower(entity.name)
  return typ=="wall" or typ=="gate" or name:find("wall",1,true)~=nil or name:find("gate",1,true)~=nil
end

local function missing_health(entity)
  if not(valid(entity) and entity.health and entity.max_health) then return 0 end
  return math.max(0,(tonumber(entity.max_health) or 0)-(tonumber(entity.health) or 0))
end

local function missing_ratio(entity)
  local maximum=valid(entity) and tonumber(entity.max_health) or 0
  if not maximum or maximum<=0 then return 0 end
  return missing_health(entity)/maximum
end

local function force_is_enemy(force, other)
  if not(force and other) or force==other or safe(force.name)==safe(other.name) then return false end
  if safe(other.name)=="neutral" then return false end
  if type(force.is_enemy)=="function" then
    local ok,result=pcall(function() return force.is_enemy(other) end)
    if ok then return result==true end
  end
  if type(force.get_friend)=="function" then
    local ok,result=pcall(function() return force.get_friend(other) end)
    if ok and result==true then return false end
  end
  if type(force.get_cease_fire)=="function" then
    local ok,result=pcall(function() return force.get_cease_fire(other) end)
    if ok and result==true then return false end
  end
  return true
end

local function enemyish(pair,entity)
  if not(valid_pair(pair) and valid(entity) and entity.force and pair.station.force) then return false end
  if not force_is_enemy(pair.station.force,entity.force) then return false end
  local typ=lower(entity.type)
  if typ=="unit" or typ=="unit-spawner" or typ=="turret" or typ=="spider-unit" then return true end
  return entity.health and entity.max_health and (typ:find("unit",1,true) or typ:find("biter",1,true) or typ:find("spitter",1,true))~=nil
end

local function area(position,radius)
  return {{(position.x or 0)-radius,(position.y or 0)-radius},{(position.x or 0)+radius,(position.y or 0)+radius}}
end

local function entities(surface,position,radius,force)
  if not(surface and position) then return {} end
  local ok,found=pcall(function()
    local spec={area=area(position,radius)}
    if force then spec.force=force end
    return surface.find_entities_filtered(spec)
  end)
  return ok and found or {}
end

local function enemy_context(pair,position,radius)
  local count=0
  local nearest=nil
  for _,entity in ipairs(entities(pair.station.surface,position,radius,nil)) do
    if enemyish(pair,entity) then
      count=count+1
      local d=distance(position,entity.position)
      nearest=not nearest and d or math.min(nearest,d)
    end
  end
  return count,nearest
end

local function blocked_status(entity)
  if not valid(entity) then return true end
  local status=nil
  pcall(function() status=entity.status end)
  local values=defines and defines.entity_status
  if not(values and status) then return false end
  for _,name in ipairs({"disabled","disabled_by_control_behavior","no_power","no_fuel","no_input_fluid","not_connected_to_rail","marked_for_deconstruction"}) do
    if values[name] and status==values[name] then return true end
  end
  return false
end

local function ammo_loaded(turret)
  if not(valid(turret) and defines and defines.inventory and defines.inventory.turret_ammo) then return false end
  local ok,inventory=pcall(function() return turret.get_inventory(defines.inventory.turret_ammo) end)
  if not(ok and inventory and inventory.valid) then return false end
  local ok_empty,empty=pcall(function() return inventory.is_empty() end)
  if ok_empty then return empty==false end
  local ok_contents,contents=pcall(function() return inventory.get_contents() end)
  if ok_contents and contents then for _,count in pairs(contents) do if (tonumber(count) or 0)>0 then return true end end end
  return false
end

local function turret_ready(pair,turret)
  if not(valid_pair(pair) and valid(turret) and turret.force==pair.station.force) then return false,"not-allied" end
  if lower(turret.type):find("turret",1,true)==nil then return false,"not-turret" end
  if blocked_status(turret) then return false,"disabled-status" end
  local active=nil
  pcall(function() active=turret.active end)
  if active==false then return false,"inactive" end
  local target=nil
  pcall(function() target=turret.shooting_target end)
  if valid(target) and enemyish(pair,target) then return true,"shooting" end
  if ammo_loaded(turret) then return true,"ammo-loaded" end
  local energy=0
  pcall(function() energy=tonumber(turret.energy) or 0 end)
  if energy>1000 then return true,"energized" end
  local fluidbox=nil
  pcall(function() fluidbox=turret.fluidbox end)
  if fluidbox then
    local ok_length,length=pcall(function() return #fluidbox end)
    if ok_length then for index=1,length do local fluid=nil; pcall(function() fluid=fluidbox[index] end); if fluid and (tonumber(fluid.amount) or 0)>0 then return true,"fluid-ready" end end end
  end
  return false,"not-ready"
end

local function strict_turret_cover(pair,wall)
  local ready=0
  local total=0
  local labels={}
  local doctrine=Doctrine()
  local radius=tonumber(doctrine and doctrine.wall_turret_radius) or 8
  for _,entity in ipairs(entities(wall.surface,wall.position,radius,pair.station.force)) do
    if valid(entity) and lower(entity.type):find("turret",1,true) then
      total=total+1
      local ok,why=turret_ready(pair,entity)
      if ok then ready=ready+1; labels[#labels+1]=safe(entity.name)..":"..safe(why) end
    end
  end
  return ready>0,ready,total,table.concat(labels,",")
end

local function proxy_ready(pair)
  local ammo=Ammo()
  if ammo and type(ammo.proxy_has_ammo)=="function" then
    local ok,result=pcall(ammo.proxy_has_ammo,pair)
    if ok then return result==true end
  end
  local helper=rawget(_G,"tech_priests_0293_proxy_has_ammo")
  if type(helper)=="function" then local ok,result=pcall(helper,pair); if ok then return result==true end end
  return false
end

local function strict_priest_cover(pair,wall)
  local ready=0
  local doctrine=Doctrine()
  local radius=tonumber(doctrine and doctrine.priest_cover_radius) or 12
  for _,other in pairs(pair_map()) do
    if other~=pair and valid_pair(other) and other.priest.surface==wall.surface and other.station.force==pair.station.force then
      if dist_sq(other.priest.position,wall.position)<=radius*radius then
        local mode=lower(other.mode)
        local target=(valid(other.combat_target) and other.combat_target) or (valid(other.target) and other.target) or nil
        local engaged=mode:find("combat",1,true)~=nil or mode:find("defend",1,true)~=nil or enemyish(pair,target)
        if engaged and proxy_ready(other) then ready=ready+1 end
      end
    end
  end
  return ready>0,ready
end

local function cluster_key(entity)
  if not valid(entity) then return nil end
  local doctrine=Doctrine()
  local size=tonumber(doctrine and doctrine.cluster_size) or 3
  local position=entity.position or {x=0,y=0}
  local cx=math.floor(((position.x or 0)/size)+0.5)*size
  local cy=math.floor(((position.y or 0)/size)+0.5)*size
  return tostring(entity.surface.index)..":"..tostring(entity.force and entity.force.name or "?")..":"..cx..":"..cy
end

local function target_key(entity,state)
  if valid(entity) then
    if entity.unit_number then return tostring(entity.unit_number) end
    local position=entity.position or {x=0,y=0}
    return tostring(entity.name).."@"..string.format("%.1f,%.1f",position.x or 0,position.y or 0)
  end
  return state and state.target_unit and tostring(state.target_unit) or nil
end

local function cluster_owned_by_other(pair,wall)
  local doctrine=Doctrine()
  local root=doctrine and doctrine.root and doctrine.root() or nil
  if not(root and root.reserve_clusters) then return false end
  local key=cluster_key(wall)
  local reservation=key and root.cluster_reservations and root.cluster_reservations[key]
  if reservation and (tonumber(reservation.until_tick) or 0)<=now() then root.cluster_reservations[key]=nil; reservation=nil end
  return reservation and safe(reservation.station)~=safe(station_unit(pair)) or false
end

local function station_has_pack(pair)
  local helper=rawget(_G,"station_has_repair_pack")
  if type(helper)=="function" then local ok,result=pcall(helper,pair.station); if ok then return result==true end end
  return false
end

local function safe_candidate(pair,wall)
  local doctrine=Doctrine()
  if not(valid_pair(pair) and valid(wall) and wall.force==pair.station.force and is_wallish(wall) and missing_health(wall)>0.01) then return false,"not-damaged-wall" end
  if missing_ratio(wall)<(tonumber(doctrine and doctrine.min_wall_missing_ratio) or 0.04) then return false,"minor-damage" end
  if not station_has_pack(pair) then return false,"no-repair-pack" end
  local station_radius=tonumber(pair.radius) or 32
  if dist_sq(pair.station.position,wall.position)>station_radius*station_radius then return false,"outside-station-radius" end
  local root=doctrine.root()
  local key=target_key(wall)
  if key and root.target_cooldowns[key] and (tonumber(root.target_cooldowns[key]) or 0)>now() then return false,"target-cooldown" end
  if cluster_owned_by_other(pair,wall) then return false,"cluster-reserved" end
  local enemy_radius=tonumber(doctrine.wall_enemy_radius) or 9
  local enemy_count,nearest=enemy_context(pair,wall.position,enemy_radius)
  if enemy_count<=0 then return false,"no-enemy-pressure" end
  local turret_ok,active_turrets,turret_count,turret_labels=strict_turret_cover(pair,wall)
  local priest_ok,active_priests=strict_priest_cover(pair,wall)
  local covered=turret_ok or priest_ok
  if root.require_cover and not covered then return false,"uncovered-under-fire" end
  local danger_radius=math.sqrt(tonumber(doctrine.personal_danger_radius_sq) or 16)
  local personal_enemies=enemy_context(pair,pair.priest.position,danger_radius)
  local critical=tonumber(doctrine.critical_wall_missing_ratio) or 0.35
  if personal_enemies>0 and not covered and missing_ratio(wall)<critical then return false,"priest-personal-danger" end
  return true,{enemies=enemy_count,nearest_enemy=nearest,active_turrets=active_turrets,turret_count=turret_count,turret_labels=turret_labels,active_priests=active_priests,covered=covered,personal_enemies=personal_enemies,integrity_checked=true}
end

local function score_candidate(pair,wall,context)
  local doctrine=Doctrine()
  local nearest=(context and context.nearest_enemy) or (tonumber(doctrine.wall_enemy_radius) or 9)
  return missing_ratio(wall)*15000
    + missing_health(wall)*3
    + ((context and context.enemies) or 0)*450
    + ((context and context.active_turrets) or 0)*900
    + ((context and context.active_priests) or 0)*650
    - nearest*40
    - distance(pair.priest.position,wall.position)*35
    - distance(pair.station.position,wall.position)*4
end

local function candidate_entities(pair)
  local doctrine=Doctrine()
  local radius=math.min(tonumber(pair.radius) or 32,tonumber(doctrine.search_radius) or 26)
  local output={}
  local seen={}
  local function append_from(position)
    for _,entity in ipairs(entities(pair.station.surface,position,radius,pair.station.force)) do
      if is_wallish(entity) then
        local key=target_key(entity)
        if key and not seen[key] then seen[key]=true; output[#output+1]=entity end
      end
    end
  end
  append_from(pair.priest.position)
  append_from(pair.station.position)
  return output
end

local function find_safe_target(pair)
  local doctrine=Doctrine()
  local best,best_context,best_score=nil,nil,-math.huge
  local checked=0
  for _,wall in ipairs(candidate_entities(pair)) do
    checked=checked+1
    if checked>(tonumber(doctrine.max_candidates) or 120) then break end
    local ok,context=safe_candidate(pair,wall)
    if ok then
      local score=score_candidate(pair,wall,context)
      if score>best_score then best,best_context,best_score=wall,context,score end
    end
  end
  if not best then return nil,"no-defended-damaged-wall",nil,checked end
  return best,best_context,best_score,checked
end

local function release_cluster_owned(pair,state,target)
  local doctrine=Doctrine()
  local root=doctrine and doctrine.root and doctrine.root() or nil
  if not root then return false end
  local released=false
  local keys={state and state.cluster_key,cluster_key(target)}
  for _,key in ipairs(keys) do
    if key and root.cluster_reservations then
      local reservation=root.cluster_reservations[key]
      if reservation and safe(reservation.station)==safe(station_unit(pair)) then root.cluster_reservations[key]=nil; released=true end
    end
  end
  if released then stat("cluster_released") end
  return released
end

local function release_exact_reservation(pair,target,state)
  local reservations=Reservations()
  if reservations and type(reservations.release)=="function" and valid(target) then pcall(reservations.release,"repair",target,pair); return end
  if reservations and type(reservations.root)=="function" then
    local ok,root=pcall(reservations.root)
    local bucket=ok and root and root.reservations and root.reservations.repair
    local key=reservations.target_key and reservations.target_key(target) or (state and state.target_unit and "unit:"..safe(state.target_unit))
    local reservation=bucket and key and bucket[key]
    if reservation and safe(reservation.pair_id)==safe(reservations.pair_id and reservations.pair_id(pair) or station_unit(pair)) then bucket[key]=nil end
  end
end

local function repair_order_matches(order,target)
  if type(order)~="table" then return false end
  local kind=lower(order.kind or order.type or order.key or order.source)
  if kind:find("repair",1,true)==nil then return false end
  local source=lower(order.source or order.reason)
  if source:find("combat-repair",1,true)~=nil then return true end
  local order_target=order.target or (type(order.task)=="table" and order.task.target)
  return valid(target) and order_target==target
end

local function append_history(pair,order,status,why)
  local queue=pair.order_queue_0469
  if not(queue and order) then return end
  queue.history=queue.history or {}
  queue.history[#queue.history+1]={tick=now(),key=order.key,kind=order.kind,item=order.item,status=status,why=why,source="combat-repair-integrity-0676"}
  while #queue.history>200 do table.remove(queue.history,1) end
end

local function clear_repair_scheduler(pair,target,status,reason)
  local repair_state=pair.repair_0516 or {}
  release_exact_reservation(pair,target,repair_state)
  if not target or repair_state.target==target or (repair_state.target_unit and target_key(target,repair_state)==safe(repair_state.target_unit)) then
    for _,field in ipairs({"target","target_name","target_unit","target_source","started_tick","due_tick","packs_used","distance","missing","max_health","last_restore","integrity_target_key_0673"}) do repair_state[field]=nil end
    repair_state.phase=status=="complete" and "complete" or "none"
    repair_state.last_blocker=reason
    pair.repair_0516=repair_state
  end
  for _,field in ipairs({"active_task","active_task_0285"}) do
    local task=pair[field]
    if repair_order_matches(task,target) then pair[field]=nil end
  end
  local queue=pair.order_queue_0469
  local current=queue and queue.current or pair.active_order_0469
  if repair_order_matches(current,target) then
    current.status=status
    current.finished_tick=now()
    current.finish_reason=reason
    append_history(pair,current,status,reason)
    if queue and queue.current==current then queue.current=nil end
    if pair.active_order_0469==current then pair.active_order_0469=nil end
  end
  if queue and type(queue.pending)=="table" then
    local kept={}
    queue.pending_keys={}
    for _,pending in ipairs(queue.pending) do
      if repair_order_matches(pending,target) then
        pending.status=status
        pending.finished_tick=now()
        pending.finish_reason=reason
        append_history(pair,pending,status,reason)
      else
        kept[#kept+1]=pending
        if pending.key then queue.pending_keys[pending.key]=true end
      end
    end
    queue.pending=kept
  end
  local order_queue=OrderQueue()
  if order_queue and type(order_queue.tick_pair)=="function" then pcall(order_queue.tick_pair,pair,"combat-repair-handoff-0676") end
end

local function finalize_pair(pair,target,status,reason)
  local state=pair.combat_repair_0517 or {}
  release_cluster_owned(pair,state,target)
  clear_repair_scheduler(pair,target,status,reason)
  local last_name=valid(target) and target.name or state.target_name
  local last_unit=valid(target) and target.unit_number or state.target_unit
  pair.combat_repair_0517={version=M.version,phase=status,completed_tick=status=="complete" and now() or nil,failed_tick=status~="complete" and now() or nil,last_blocker=reason,last_target_name=last_name,last_target_unit=last_unit}
  if pair.combat_repair_target_0517==target or not valid(pair.combat_repair_target_0517) then pair.combat_repair_target_0517=nil end
  if pair.target==target then pair.target=nil end
  pair.mode=valid(pair.combat_target) and "combat" or "idle"
  record(pair,status=="complete" and "completed" or "aborted",reason)
end

local function task_installed(pair,target)
  for _,field in ipairs({"active_task","active_task_0285"}) do if repair_order_matches(pair[field],target) then return true end end
  local queue=pair.order_queue_0469
  if repair_order_matches(queue and queue.current or pair.active_order_0469,target) then return true end
  for _,pending in ipairs(queue and queue.pending or {}) do if repair_order_matches(pending,target) then return true end end
  return false
end

local function compact_history()
  local doctrine=Doctrine()
  if not(doctrine and doctrine.root) then return 0 end
  local root=doctrine.root()
  local newest={}
  local removed=0
  local noisy={service=true,["no-combat-repair-target"]=true}
  for index=#root.recent,1,-1 do
    local event=root.recent[index]
    local action=event and tostring(event.action or "") or ""
    if noisy[action] then
      local key=action..":"..safe(event.station)
      local tick=tonumber(event.tick) or 0
      if newest[key] and newest[key]-tick<M.history_window then table.remove(root.recent,index); removed=removed+1 else newest[key]=tick end
    end
  end
  if removed>0 then stat("history_compacted",removed) end
  return removed
end

local function patch_find(doctrine)
  if previous_find or type(doctrine.find_combat_repair_target)~="function" then return end
  previous_find=doctrine.find_combat_repair_target
  doctrine.find_combat_repair_target=function(pair)
    if M.root().enabled==false then return previous_find(pair) end
    local target,context,score,checked=find_safe_target(pair)
    if not target then record(pair,"no_safe_target","checked="..safe(checked)); compact_history() end
    return target,context,score
  end
end

local function patch_active(doctrine)
  if previous_active or type(doctrine.active)~="function" then return end
  previous_active=doctrine.active
  doctrine.active=function(pair)
    if M.root().enabled==false then return previous_active(pair) end
    local state=pair and pair.combat_repair_0517
    return state and state.phase=="repair-via-0516" and valid(state.target)
  end
end

local function patch_abort(doctrine)
  if previous_abort or type(doctrine.abort_pair)~="function" then return end
  previous_abort=doctrine.abort_pair
  doctrine.abort_pair=function(pair,reason)
    if M.root().enabled==false then return previous_abort(pair,reason) end
    if not pair then return false end
    local state=pair.combat_repair_0517 or {}
    local target=valid(state.target) and state.target or (valid(pair.combat_repair_target_0517) and pair.combat_repair_target_0517 or nil)
    finalize_pair(pair,target,"failed",tostring(reason or "combat-repair-aborted"))
    return true
  end
end

local function patch_recommend(doctrine)
  if previous_recommend or type(doctrine.recommend_action)~="function" then return end
  previous_recommend=doctrine.recommend_action
  doctrine.recommend_action=function(pair)
    if M.root().enabled==false then return previous_recommend(pair) end
    local root=doctrine.root()
    if root.enabled==false or root.dispatcher_owned==false or not valid_pair(pair) then return nil end
    local state=pair.combat_repair_0517
    if state and state.phase=="repair-via-0516" then
      if not valid(state.target) then doctrine.abort_pair(pair,"invalid-active-target-0676"); return nil end
      local ok,context=safe_candidate(pair,state.target)
      if not ok then doctrine.abort_pair(pair,"cover-lost:"..safe(context)); return nil end
      return {kind="combat-repair",target=state.target,item="repair-pack",reason="defended-wall-under-attack-0676",priority=920,score=score_candidate(pair,state.target,context),context=context}
    end
    local target,context,score=find_safe_target(pair)
    if not valid(target) then return nil end
    return {kind="combat-repair",target=target,item="repair-pack",reason="defended-wall-under-attack-0676",priority=920,score=score,context=context}
  end
end

local function patch_service(doctrine)
  if previous_service or type(doctrine.service_pair)~="function" then return end
  previous_service=doctrine.service_pair
  doctrine.service_pair=function(pair,reason,forced_target)
    if M.root().enabled==false then return previous_service(pair,reason,forced_target) end
    if not valid_pair(pair) then return false,"invalid-pair" end
    local root=doctrine.root()
    if root.dispatcher_owned==false and lower(reason):find("dispatcher",1,true) then return false,"dispatcher-ownership-disabled" end

    local state=pair.combat_repair_0517 or {}
    local old_target=valid(state.target) and state.target or nil
    local target=valid(forced_target) and forced_target or nil
    local context=nil
    if target then local ok,ctx=safe_candidate(pair,target); if ok then context=ctx else target=nil end end
    if not target then target,context=find_safe_target(pair) end

    if not valid(target) then
      if old_target or state.cluster_key then finalize_pair(pair,old_target,"failed","no-safe-combat-repair-target-0676")
      else pair.combat_repair_0517={version=M.version,phase="no-target",last_service_tick=now(),last_blocker="no-safe-combat-repair-target-0676"} end
      compact_history()
      return false,"no-safe-combat-repair-target"
    end

    if old_target and old_target~=target then
      release_cluster_owned(pair,state,old_target)
      clear_repair_scheduler(pair,old_target,"failed","combat-repair-target-changed-0676")
      stat("target_changed_cleanup")
    end

    if cluster_owned_by_other(pair,target) then
      finalize_pair(pair,target,"failed","cluster-reserved-0676")
      return false,"cluster-reserved"
    end

    local repair=Repair()
    if not(repair and type(repair.submit_or_assign_repair_task)=="function" and type(repair.service_pair)=="function") then
      finalize_pair(pair,target,"failed","repair-executor-missing-0676")
      return false,"repair-executor-missing"
    end

    local ok_submit,accepted=pcall(repair.submit_or_assign_repair_task,pair,target,"combat-repair-0676")
    if not ok_submit or accepted==false or not task_installed(pair,target) then
      finalize_pair(pair,target,"failed","repair-task-submit-failed-0676")
      record(pair,"submit_failed",ok_submit and safe(accepted) or safe(accepted))
      return false,"repair-task-submit-failed"
    end

    local ok,acted,why=pcall(previous_service,pair,reason or "combat-repair-0676",target)
    compact_history()
    if not ok then finalize_pair(pair,target,"failed","combat-repair-service-error:"..safe(acted)); return false,"combat-repair-service-error" end

    local current=pair.combat_repair_0517 or {}
    local key=current.cluster_key or cluster_key(target)
    local reservation=key and root.cluster_reservations and root.cluster_reservations[key]
    if not reservation or safe(reservation.station)~=safe(station_unit(pair)) then
      finalize_pair(pair,target,"failed","cluster-claim-missing-0676")
      return false,"cluster-claim-missing"
    end

    local result=tostring(why or "")
    if result=="no-repair-pack" or result=="consume-failed" or result=="movement-request-failed" or result=="health-write-failed" or result=="target-reserved" or result=="repair-executor-error" then
      finalize_pair(pair,target,"failed","ordinary-repair-blocked:"..result)
      return false,result
    end

    local still_safe,blocker=safe_candidate(pair,target)
    if missing_health(target)<=0.01 or result=="complete" or (pair.repair_0516 and pair.repair_0516.phase=="complete") then
      local key_target=target_key(target,current)
      if key_target then root.target_cooldowns[key_target]=now()+(tonumber(doctrine.target_cooldown_ticks) or 90) end
      finalize_pair(pair,target,"complete","combat-repair-complete-0676")
      return true,"complete"
    end
    if not still_safe then
      finalize_pair(pair,target,"failed","cover-lost:"..safe(blocker))
      return false,"cover-lost"
    end

    current.version=M.version
    current.phase="repair-via-0516"
    current.target=target
    current.target_name=target.name
    current.target_unit=target.unit_number
    current.cluster_key=cluster_key(target)
    current.missing=missing_health(target)
    current.ratio=missing_ratio(target)
    current.enemies=context and context.enemies or current.enemies
    current.active_turrets=context and context.active_turrets or current.active_turrets
    current.active_priests=context and context.active_priests or current.active_priests
    current.cover=tostring(context and context.covered or false)
    current.turret_labels=context and context.turret_labels or ""
    pair.combat_repair_0517=current
    pair.combat_repair_target_0517=target
    pair.mode="combat-repair"
    return acted,why or "combat-repair-0676"
  end
end

local function remove_command()
  if commands and commands.remove_command then pcall(commands.remove_command,"tp-combat-repair-0517") end
end

local function patch_install(doctrine)
  if previous_install or type(doctrine.install)~="function" then return end
  previous_install=doctrine.install
  doctrine.install=function(...)
    local result=previous_install(...)
    remove_command()
    return result
  end
end

local function patch_diagnostics()
  local diagnostics=rawget(_G,"TechPriestsEmergencyDiagnostics0468") or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not(diagnostics and type(diagnostics.pair_dump_lines)=="function") or diagnostics.combat_repair_integrity_0676_wrapped then return end
  local previous=diagnostics.pair_dump_lines
  diagnostics.combat_repair_integrity_0676_wrapped=true
  diagnostics.pair_dump_lines=function()
    local lines=previous()
    local root=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 COMBAT-REPAIR-INTEGRITY-0676 enabled="..safe(root.enabled).." completed="..safe(root.stats.completed or 0).." aborted="..safe(root.stats.aborted or 0).." cluster_released="..safe(root.stats.cluster_released or 0).." submit_failed="..safe(root.stats.submit_failed or 0).." target_changed="..safe(root.stats.target_changed_cleanup or 0).." history_compacted="..safe(root.stats.history_compacted or 0).." no_safe_target="..safe(root.stats.no_safe_target or 0)
    return lines
  end
end

function M.install()
  M.root()
  local doctrine=Doctrine()
  if not doctrine then if log then log("[Tech-Priests 0.1.662] combat repair integrity unavailable: combat_repair_doctrine_0517 missing") end return false end
  patch_find(doctrine)
  patch_active(doctrine)
  patch_abort(doctrine)
  patch_recommend(doctrine)
  patch_service(doctrine)
  patch_install(doctrine)
  remove_command()
  patch_diagnostics()
  _G.TechPriestsCombatRepairIntegrity0676=M
  if log then log("[Tech-Priests 0.1.662] combat repair integrity installed; diplomatic enemy truth, strict cover, task verification, full abort/completion cleanup, bounded diagnostics, and commandless runtime active") end
  return true
end

return M
