-- scripts/core/repair_executor_0516.lua
-- Tech Priests 0.1.603
--
-- Dispatcher-owned repair executor. The old repair_target path optimized for
-- repair-pack usefulness and could make priests look lazy, leave machines partly
-- damaged, and allow multiple priests to pile onto one wall section. This module
-- turns repair into a visible phased action: select a damaged target by urgency,
-- reserve it, walk to repair range, spend timed repair ticks, consume repair
-- packs, and keep repairing until the target is fully repaired or supplies fail.

local M = {}
M.version = "0.1.603"
M.storage_key = "repair_executor_0516"
M.repair_range_sq = 16
M.pack_interval_ticks = 45
M.pair_cooldown_ticks = 20
M.target_cooldown_ticks = 120
M.reservation_ttl_ticks = 240
M.max_candidates = 160
M.tick_interval = 29

local original_repair_target = nil
local original_scheduler_try_repair = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function work_reservations()
  local ok, R = pcall(require, "scripts.core.work_reservations")
  if ok and R then return R end
  return rawget(_G, "TechPriestsWorkReservations0601")
end

local function work_queues()
  local ok, Q = pcall(require, "scripts.core.work_queue_authority")
  if ok and Q then return Q end
  return rawget(_G, "TechPriestsWorkQueueAuthority0601")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    wrap_legacy = true,
    full_repair = true,
    spread_targets = true,
    stats = {},
    recent = {},
    reservations = {},
    cooldowns = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_owned == nil then r.dispatcher_owned = true end
  if r.wrap_legacy == nil then r.wrap_legacy = true end
  if r.full_repair == nil then r.full_repair = true end
  if r.spread_targets == nil then r.spread_targets = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.reservations = r.reservations or {}
  r.cooldowns = r.cooldowns or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, action, detail)
  local r=M.root(); stat(action)
  local ev={tick=now(), action=tostring(action or "event"), station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>180 do table.remove(r.recent,1) end
  return ev
end

local function get_order(pair)
  local q=pair and pair.order_queue_0469
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end

local function order_kind(order) return lower(order and (order.kind or order.type or order.key or order.source) or "") end
local function order_is_repair(order)
  local k=order_kind(order)
  return k == "repair" or k:find("repair",1,true)
end

local function target_from(v, seen)
  if valid(v) then return v end
  if type(v) ~= "table" then return nil end
  seen = seen or {}; if seen[v] then return nil end; seen[v]=true
  for _, key in ipairs({"target","entity","machine","source","selected","current","task"}) do
    local t = target_from(v[key], seen)
    if t then return t end
  end
  return nil
end

local function order_target(pair)
  local order=get_order(pair)
  return target_from(order) or target_from(pair and pair.active_task) or target_from(pair and pair.active_task_0285) or (valid(pair and pair.target) and pair.target or nil)
end

local function amount_per_pack()
  return tonumber(rawget(_G, "REPAIR_AMOUNT_PER_PACK")) or 75
end

local function missing_health(entity)
  if _G.get_repair_pack_useful_missing_health then
    local ok,v=pcall(_G.get_repair_pack_useful_missing_health, entity)
    if ok and tonumber(v) then return tonumber(v) end
  end
  if not (valid(entity) and entity.health and entity.max_health) then return 0 end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end

local function damaged(entity)
  return valid(entity) and entity.health and entity.max_health and (tonumber(entity.max_health) or 0) > 0 and missing_health(entity) > 0.01
end

local function is_priest_entity(entity)
  if not valid(entity) then return false end
  if _G.is_priest then local ok,res=pcall(_G.is_priest, entity); if ok and res then return true end end
  local n=lower(entity.name)
  return n:find("tech%-priest") ~= nil or n:find("tech_priest") ~= nil
end

local function proxy_name()
  return rawget(_G, "PROXY_NAME") or "tech-priest-proxy-turret"
end

local function station_has_pack(station)
  if _G.station_has_repair_pack then local ok,res=pcall(_G.station_has_repair_pack, station); return ok and res == true end
  local inv = station and station.valid and _G.get_station_inventory and _G.get_station_inventory(station) or nil
  return inv and inv.get_item_count("repair-pack") > 0
end

local function consume_pack(station)
  if _G.consume_repair_pack then local ok,res=pcall(_G.consume_repair_pack, station); return ok and res == true end
  local inv = station and station.valid and _G.get_station_inventory and _G.get_station_inventory(station) or nil
  return inv and inv.remove({name="repair-pack",count=1}) > 0
end

local function target_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return tostring(entity.unit_number) end
  local p=entity.position or {x=0,y=0}
  return tostring(entity.name).."@"..string.format("%.1f,%.1f", p.x or 0, p.y or 0)
end

local function cleanup_reservations(r)
  local t=now()
  for k,res in pairs(r.reservations or {}) do
    if not res or (tonumber(res.until_tick) or 0) < t then r.reservations[k]=nil end
  end
  for k,until_tick in pairs(r.cooldowns or {}) do
    if (tonumber(until_tick) or 0) < t then r.cooldowns[k]=nil end
  end
end

local function reserved_by_other(r, entity, pair)
  if not r.spread_targets then return false end
  local R = work_reservations()
  if R and R.is_claimed then
    local claimed = R.is_claimed("repair", entity, pair)
    if claimed then stat("shared_reservation_blocked") end
    return claimed == true
  end
  local k=target_key(entity); if not k then return false end
  cleanup_reservations(r)
  local res=r.reservations[k]
  if not res then return false end
  return tostring(res.station or "") ~= tostring(station_unit(pair) or "")
end

local function reserve_target(r, pair, entity)
  local R = work_reservations()
  if R and R.claim then
    local ok = R.claim("repair", entity, pair, M.reservation_ttl_ticks, { surface_index = entity.surface and entity.surface.index, force_index = entity.force and entity.force.index })
    if ok then stat("shared_reservation_claimed"); return true end
    stat("shared_reservation_denied")
    return false
  end
  local k=target_key(entity); if not k then return false end
  r.reservations[k] = { station=station_unit(pair), priest=priest_unit(pair), until_tick=now()+M.reservation_ttl_ticks, name=entity.name }
  return true
end

local function release_target(r, entity, pair)
  local R = work_reservations()
  if R and R.release then pcall(R.release, "repair", entity, pair) end
  local k=target_key(entity); if k then r.reservations[k]=nil end
end

local function target_type_bonus(entity)
  local t = lower(entity.type)
  local n = lower(entity.name)
  if t:find("turret",1,true) or n:find("turret",1,true) then return 220 end
  if t == "wall" or n:find("wall",1,true) or t == "gate" then return 200 end
  if t:find("ammo",1,true) or n:find("ammo",1,true) then return 120 end
  if t:find("assembling",1,true) or n:find("assembling",1,true) then return 100 end
  if t:find("furnace",1,true) or n:find("furnace",1,true) then return 100 end
  if t:find("generator",1,true) or t:find("boiler",1,true) or t:find("reactor",1,true) then return 90 end
  if t:find("container",1,true) or n:find("cogitator",1,true) then return 70 end
  return 0
end

local function eligible(pair, entity, allow_reserved)
  if not (valid_pair(pair) and damaged(entity)) then return false, "not-damaged" end
  if is_priest_entity(entity) or entity.name == proxy_name() then return false, "excluded" end
  if entity.force and pair.station.force and entity.force.name ~= pair.station.force.name then return false, "wrong-force" end
  local radius = tonumber(pair.radius) or 32
  local sds = dist_sq(pair.station.position, entity.position) or 999999
  if sds > radius*radius then return false, "outside-radius" end
  local r=M.root()
  local k=target_key(entity)
  if k and r.cooldowns[k] and (tonumber(r.cooldowns[k]) or 0) > now() and not allow_reserved then return false, "target-cooldown" end
  if not allow_reserved and reserved_by_other(r, entity, pair) then return false, "reserved" end
  return true
end

local function score_target(pair, entity)
  local missing = missing_health(entity)
  local maxh = tonumber(entity.max_health) or 1
  local ratio = maxh > 0 and (missing / maxh) or 0
  local pds = valid(pair.priest) and (dist_sq(pair.priest.position, entity.position) or 0) or 0
  local sds = dist_sq(pair.station.position, entity.position) or pds
  -- Damage is king, then class urgency, then proximity.  This makes priests
  -- repair heavily damaged walls/machines instead of chasing tiny scratches, but
  -- still prefers closer targets when damage is comparable.
  return ratio*10000 + missing*2 + target_type_bonus(entity) - math.sqrt(pds)*12 - math.sqrt(sds)*2
end

local function find_target(pair, explicit)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  if not station_has_pack(pair.station) then return nil, "no-repair-pack" end
  if valid(explicit) then
    local ok, why = eligible(pair, explicit, true)
    if ok then return explicit, "explicit" end
  end
  local Q = work_queues()
  if Q and Q.claim_nearest then
    local order = select(1, Q.claim_nearest(pair, "repair", { ttl = M.reservation_ttl_ticks }))
    if order and valid(order.target) then
      local ok = eligible(pair, order.target, true)
      if ok then stat("work_queue_claimed_repair"); return order.target, "work-queue" end
    end
    if Q.discover_repair_near then
      local discovered = select(1, Q.discover_repair_near(pair, { limit = M.max_candidates, ttl = 900, source = "repair_executor_0516_requested_discovery" }))
      if tonumber(discovered or 0) > 0 then
        local claimed = select(1, Q.claim_nearest(pair, "repair", { ttl = M.reservation_ttl_ticks }))
        if claimed and valid(claimed.target) then stat("work_queue_discovered_then_claimed"); return claimed.target, "work-queue-discovered" end
      end
    end
  end
  -- If every damaged target is reserved/cooldown, let this pair continue its own target if possible.
  return nil, "no-eligible-target"
end

local function request_move(pair, target, reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  local pos=target.position
  if _G.tech_priests_request_movement_0418 then
    local ok,res=pcall(_G.tech_priests_request_movement_0418, pair, pos, reason or "repair-executor-0516", { radius=1.4, owner="repair_executor_0516", priority=820, ttl=900, distraction=defines and defines.distraction and defines.distraction.none })
    if ok and res ~= false then return true end
  end
  if _G.move_priest_to then local ok=pcall(_G.move_priest_to, pair.priest, target); if ok then return true end end
  if pair.priest and pair.priest.valid and defines and defines.command then
    local command = { type=defines.command.go_to_location, destination=pos, radius=1.4, distraction=defines.distraction.none }
    if _G.tech_priests_route_ground_command_0429 then
      local ok,res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "repair-executor-fallback-0616", { pair = pair, priority = 820, ttl = 900 })
      if ok and res ~= false then return true end
    elseif pair.priest.set_command then
      local ok=pcall(function() pair.priest.set_command(command) end)
      if ok then return true end
    end
  end
  return false
end

local function play_feedback(pair, target)
  pcall(function() if _G.play_repair_feedback then _G.play_repair_feedback(pair.station.surface, target.position) end end)
end

local function complete_order(pair, reason)
  local q=pair and pair.order_queue_0469
  if q and q.current and order_is_repair(q.current) then
    q.current.status="complete"
    q.current.finished_tick=now()
    q.current.finish_reason=reason or "repair-complete-0516"
    q.current=nil
    pair.active_order_0469=nil
  end
end

function M.active(pair)
  if not pair then return false end
  local s=pair.repair_0516
  if s and s.phase and s.phase ~= "none" and s.phase ~= "complete" then return true end
  local order=get_order(pair)
  if order_is_repair(order) then return true end
  local mode=lower(pair.mode)
  return mode:find("repair",1,true) ~= nil
end

function M.submit_or_assign_repair_task(pair, target, reason)
  if not valid_pair(pair) then return false end
  if not valid(target) then target = select(1, find_target(pair, order_target(pair))) end
  if not valid(target) then return false end
  local task={ type="repair", kind="repair", phase="repair-service", key="repair", visual="repairing", target=target, priority=800, owner_system="repair-executor-0516" }
  local okS, Scheduler = pcall(require, "scripts.core.task_scheduler")
  if okS and Scheduler and type(Scheduler.assign_task)=="function" then
    pcall(Scheduler.assign_task, pair, task, reason or "repair-0516")
  else
    pair.active_task=task; pair.active_task_0285=task; pair.target=target; pair.mode="repairing"
  end
  local submit=rawget(_G,"tech_priests_0469_submit_order")
  if type(submit)=="function" then
    pcall(submit, pair, { kind="repair", item="repair-pack", target=target, priority=800, source="repair_executor_0516", task=task })
  end
  return true
end

function M.service_pair(pair, reason, forced_target)
  local r=M.root()
  if r.enabled == false then return false, "disabled" end
  if not valid_pair(pair) then return false, "invalid-pair" end
  cleanup_reservations(r)
  local order=get_order(pair)
  local state=pair.repair_0516 or { phase="none" }
  pair.repair_0516=state
  state.version=M.version
  state.last_service_tick=now()
  state.last_reason=tostring(reason or "service")

  if tonumber(pair.next_repair_tick_0516 or 0) > now() and not valid(state.target) then
    state.phase="cooldown"
    pair.mode="repair-cooldown"
    return true, "cooldown"
  end

  local target=forced_target or (valid(state.target) and state.target or nil) or order_target(pair)
  if target then
    local ok,why=eligible(pair,target,true)
    if not ok then target=nil; state.phase="target-invalid"; state.last_blocker=why end
  end
  if not target then
    local found, why=find_target(pair, nil)
    target=found
    state.target_source=why
    if not target then
      state.phase = station_has_pack(pair.station) and "no-target" or "need-item"
      state.last_blocker=tostring(why or "no-target")
      pair.mode = station_has_pack(pair.station) and "no-repair-target" or "missing-repair-supplies"
      record(pair, "no-target", state.last_blocker)
      return false, state.last_blocker
    end
  end

  state.target=target
  state.target_unit=target.unit_number
  state.target_name=target.name
  pair.target=target
  if not reserve_target(r,pair,target) then
    state.phase="target-reserved"
    state.last_blocker="shared-reservation-denied"
    record(pair,"reservation-denied",safe(target.name).."#"..safe(target.unit_number or "?"))
    return false,"target-reserved"
  end

  if not station_has_pack(pair.station) then
    state.phase="need-item"
    state.last_blocker="no-repair-pack"
    pair.mode="missing-repair-supplies"
    record(pair,"need-item",state.last_blocker)
    return false,"no-repair-pack"
  end

  local ds=dist_sq(pair.priest.position,target.position) or 999999
  if ds > M.repair_range_sq then
    request_move(pair,target,"repair-executor-0516-walk-to-target")
    state.phase="walk-to-target"
    state.distance=math.sqrt(ds)
    pair.mode="moving-to-repair"
    record(pair,"walk",target.name.."#"..safe(target.unit_number or "?").." dist="..string.format("%.1f",state.distance))
    return true,"walk-to-target"
  end

  state.phase="repair-target"
  state.started_tick=state.started_tick or now()
  state.due_tick=state.due_tick or (now()+M.pack_interval_ticks)
  pair.mode="repairing"
  local missing=missing_health(target)
  state.missing=missing
  state.max_health=target.max_health
  if missing <= 0.01 then
    state.phase="complete"
    state.completed_tick=now()
    release_target(r,target,pair)
    local k=target_key(target); if k then r.cooldowns[k]=now()+M.target_cooldown_ticks end
    pair.next_repair_tick_0516=now()+M.pair_cooldown_ticks
    pair.target=nil
    pair.mode="idle"
    complete_order(pair,"repair-complete-0516")
    record(pair,"complete","already-full")
    return true,"complete"
  end
  if now() < state.due_tick then
    record(pair,"repair-progress","missing="..safe(math.floor(missing)).." due="..safe(state.due_tick))
    return true,"repair-progress"
  end

  if not consume_pack(pair.station) then
    state.phase="need-item"
    state.last_blocker="consume-failed"
    pair.mode="missing-repair-supplies"
    record(pair,"consume-failed","repair-pack")
    return false,"consume-failed"
  end

  local amount=amount_per_pack()
  local before=tonumber(target.health) or 0
  local after=math.min(tonumber(target.max_health) or before, before + amount)
  pcall(function() target.health=after end)
  play_feedback(pair,target)
  state.packs_used=(state.packs_used or 0)+1
  state.last_restore=after-before
  state.last_pack_tick=now()
  state.due_tick=now()+M.pack_interval_ticks
  record(pair,"pack-used","target="..safe(target.name).." restored="..safe(math.floor(after-before)).." health="..safe(math.floor(after)).."/"..safe(math.floor(tonumber(target.max_health) or 0)))

  if missing_health(target) <= 0.01 then
    state.phase="complete"
    state.completed_tick=now()
    local k=target_key(target); if k then r.cooldowns[k]=now()+M.target_cooldown_ticks end
    release_target(r,target,pair)
    pair.next_repair_tick_0516=now()+M.pair_cooldown_ticks
    pair.target=nil
    pair.mode="idle"
    complete_order(pair,"repair-complete-0516")
    record(pair,"complete","packs="..safe(state.packs_used or 0))
    state.target=nil; state.started_tick=nil; state.due_tick=nil; state.packs_used=nil
    return true,"complete"
  end
  return true,"repair-pack-applied"
end

function M.service_repair_bucket(reason, budget)
  local okB, Buckets = pcall(require, "scripts.core.pair_bucket_registry")
  if okB and Buckets and Buckets.rebuild and Buckets.each then
    Buckets.rebuild(reason or "repair-executor-0516")
    local acted, checked = Buckets.each("repair", budget or 8, function(pair)
      local ok = M.service_pair(pair, reason or "repair-bucket-0516")
      return ok
    end)
    local r = M.root()
    r.stats.bucket_checked = (r.stats.bucket_checked or 0) + (checked or 0)
    r.stats.bucket_acted = (r.stats.bucket_acted or 0) + (acted or 0)
    if (checked or 0) <= 0 then return false, "empty-repair-bucket" end
    return true, "repair-bucket checked=" .. tostring(checked or 0) .. " acted=" .. tostring(acted or 0)
  end

  local checked, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and M.active(pair) then
      checked = checked + 1
      local ok = M.service_pair(pair, reason or "repair-fallback-bucket")
      if ok then acted = acted + 1 end
      if budget and checked >= budget then break end
    end
  end
  if checked <= 0 then return false, "empty-repair-fallback" end
  return true, "repair-fallback checked=" .. tostring(checked) .. " acted=" .. tostring(acted)
end

local function wrap_legacy_repair_target()
  if type(_G.repair_target) ~= "function" or original_repair_target then return false end
  original_repair_target=_G.repair_target
  _G.TECH_PRIESTS_0516_PRE_REPAIR_TARGET=original_repair_target
  _G.repair_target=function(pair,target,...)
    local r=M.root()
    if r.enabled ~= false and r.wrap_legacy ~= false and valid_pair(pair) then
      M.submit_or_assign_repair_task(pair,target,"legacy-repair-adopted-0516")
      local acted,why=M.service_pair(pair,"legacy-repair-adopted-0516",target)
      return acted ~= false, why
    end
    return original_repair_target(pair,target,...)
  end
  return true
end

local function wrap_scheduler()
  local okS,Scheduler=pcall(require,"scripts.core.task_scheduler")
  if not (okS and Scheduler and type(Scheduler.try_repair)=="function") or original_scheduler_try_repair then return false end
  original_scheduler_try_repair=Scheduler.try_repair
  Scheduler.TECH_PRIESTS_0516_PRE_TRY_REPAIR=original_scheduler_try_repair
  Scheduler.try_repair=function(pair)
    local r=M.root()
    if r.enabled == false or not valid_pair(pair) then return original_scheduler_try_repair(pair) end
    local target=order_target(pair)
    if not (target and target.valid) then target=select(1,find_target(pair,nil)) end
    if not (target and target.valid) then return false end
    M.submit_or_assign_repair_task(pair,target,"scheduler-try-repair-0516")
    return true
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected=player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp=storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-repair-executor-0516") end end)
  commands.add_command("tp-repair-executor-0516", "Tech Priests 0.1.603: dispatcher-owned repair executor. Params: on/off/all/spread-on/spread-off", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local param=lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true end
    if param=="off" then r.enabled=false end
    if param=="spread-on" then r.spread_targets=true end
    if param=="spread-off" then r.spread_targets=false end
    if param=="all" then for _,p in pairs(pair_map()) do pcall(M.service_pair,p,"manual-all") end end
    local pair=selected_pair(player)
    local lines={}
    lines[#lines+1]="[tp-repair-executor-0516] enabled="..safe(r.enabled).." dispatcher_owned="..safe(r.dispatcher_owned).." wrap_legacy="..safe(r.wrap_legacy).." spread="..safe(r.spread_targets).." complete="..safe(r.stats.complete or 0).." packs="..safe(r.stats["pack-used"] or 0).." walk="..safe(r.stats.walk or 0).." need_item="..safe(r.stats["need-item"] or 0)
    if pair then
      local s=pair.repair_0516 or {}
      lines[#lines+1]="selected station="..safe(station_unit(pair)).." priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." missing="..safe(s.missing).." packs="..safe(s.packs_used).." blocker="..safe(s.last_blocker).." due="..safe(s.due_tick)
    end
    local msg=table.concat(lines,"\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag=rawget(_G,"TechPriestsEmergencyDiagnostics0468") or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.repair_executor_0516_wrapped then return false end
  local prev=diag.pair_dump_lines; diag.repair_executor_0516_wrapped=true
  diag.pair_dump_lines=function()
    local lines=prev(); local r=M.root()
    lines[#lines+1]="PAIR-DUMP-0468 REPAIR-EXECUTOR-0516 BEGIN enabled="..safe(r.enabled).." full_repair="..safe(r.full_repair).." spread="..safe(r.spread_targets).." complete="..safe(r.stats.complete or 0).." packs="..safe(r.stats["pack-used"] or 0).." walk="..safe(r.stats.walk or 0).." no_target="..safe(r.stats["no-target"] or 0)
    for _,pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local s=pair.repair_0516 or {}
        lines[#lines+1]="PAIR-DUMP-0468 repair0516["..safe(station_unit(pair)).."] priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." missing="..safe(s.missing).." packs="..safe(s.packs_used).." blocker="..safe(s.last_blocker).." due="..safe(s.due_tick).." distance="..safe(s.distance)
      end
    end
    for i=math.max(1,#r.recent-10),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 repair0516.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail) end end
    lines[#lines+1]="PAIR-DUMP-0468 REPAIR-EXECUTOR-0516 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_legacy_repair_target()
  wrap_scheduler()
  wrap_pair_dump()
  install_command()
  _G.TechPriestsRepairExecutor0516=M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "repair_executor_0516",
      category = "repair",
      interval = M.tick_interval,
      priority = 45,
      budget = 8,
      note = "repair executor services only pair bucket repair members and shared repair work reservations",
      fn = function(event, budget)
        return M.service_repair_bucket("broker-repair-bucket", budget or 8)
      end
    })
  elseif TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(M.tick_interval, function() M.service_repair_bucket("registry-repair-bucket", 8) end, { owner = "repair_executor_0516", category = "repair" })
  end
  if log then log("[Tech-Priests 0.1.516/0.1.601] repair executor installed; periodic service registered through runtime broker and constrained to repair pair bucket") end
  return true
end

return M
