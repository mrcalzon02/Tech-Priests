-- scripts/core/consecration_executor_0515.lua
-- Tech Priests 0.1.515
--
-- Dispatcher-owned Tech-Priest consecration executor.  The old station-rite
-- function may remain as a legacy helper, but once this module is installed it
-- may no longer directly apply sanctity.  Consecration becomes a visible phased
-- priest action: choose eligible machine -> walk within rite/capsule range ->
-- spend ritual time -> consume a consecration capsule item from the Cogitator
-- Station -> apply sanctity with explicit priest/station source context.

local M = {}
M.version = "0.1.610"
M.storage_key = "consecration_executor_0515"
M.service_time_ticks = 90
M.pair_cooldown_ticks = 45
M.target_cooldown_ticks = 60 * 8
M.urgent_ratio = 0.35
M.maintenance_ratio = 0.50
M.routine_ratio = 0.70
M.idle_ratio = 0.92
M.max_candidates = 96
M.tick_interval = 31
-- 0.1.518: consecration is local machine maintenance, not a reason for
-- priests to crawl halfway across the surface or churn the scheduler every
-- ten ticks while the station lacks oil/litanies.
M.no_item_retry_ticks = 60 * 5
M.travel_limit_by_tier = {
  junior = 18,
  intermediate = 24,
  senior = 30,
  ["planetary-magos"] = 22,
  planetary = 22,
}

local original_sanctify = nil
local original_scheduler_try_consecration = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number) or "nil") or "nil" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function tier_key(pair)
  local n = lower((pair and (pair.tier or pair.rank or pair.priest_name)) or (valid(pair and pair.priest) and pair.priest.name) or "")
  if n:find("planetary",1,true) or n:find("magos",1,true) then return "planetary-magos" end
  if n:find("senior",1,true) then return "senior" end
  if n:find("intermediate",1,true) then return "intermediate" end
  return "junior"
end
local function travel_limit(pair) return tonumber(M.travel_limit_by_tier[tier_key(pair)] or 22) or 22 end
local function within_travel_limit(pair, entity)
  if not (valid_pair(pair) and valid(entity)) then return false, "invalid" end
  local lim = travel_limit(pair)
  local ds_station = dist_sq(pair.station.position, entity.position) or 999999
  if ds_station > lim * lim then return false, "target-too-far-from-station:" .. string.format("%.1f", math.sqrt(ds_station)) .. ">" .. tostring(lim) end
  return true, nil
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    wrap_legacy = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_owned == nil then r.dispatcher_owned = true end
  if r.wrap_legacy == nil then r.wrap_legacy = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
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

local function claims_root()
  local r = M.root()
  r.target_claims = r.target_claims or {}
  return r.target_claims
end

local function target_claim_key(entity)
  if not valid(entity) then return nil end
  local surface = entity.surface and entity.surface.name or "unknown-surface"
  return surface .. ":" .. safe(entity.unit_number or entity.name or "target")
end

local function cleanup_claims()
  local claims = claims_root()
  for key, claim in pairs(claims) do
    if type(claim) ~= "table" or (tonumber(claim.expires_tick) and tonumber(claim.expires_tick) < now()) then
      claims[key] = nil
    end
  end
end

local function pair_claim_id(pair)
  return safe(station_unit(pair) or "?") .. ":" .. safe(priest_unit(pair) or "?")
end

local function claim_owner_for_target(entity)
  local key = target_claim_key(entity)
  if not key then return nil, nil end
  local claims = claims_root()
  local claim = claims[key]
  if claim and tonumber(claim.expires_tick) and tonumber(claim.expires_tick) < now() then
    claims[key] = nil
    claim = nil
  end
  return claim, key
end

local function target_claimed_by_other(pair, entity)
  local claim = claim_owner_for_target(entity)
  if not claim then return false, nil end
  local owner = pair_claim_id(pair)
  if claim.owner == owner then return false, claim end
  return true, claim
end

local function claim_target(pair, entity, reason)
  local claim, key = claim_owner_for_target(entity)
  if not key then return false, "no-key" end
  local owner = pair_claim_id(pair)
  if claim and claim.owner ~= owner then return false, "claimed-by:" .. safe(claim.owner) end
  local claims = claims_root()
  claims[key] = {
    owner = owner,
    station = station_unit(pair),
    priest = priest_unit(pair),
    target = safe(entity.name) .. "#" .. safe(entity.unit_number),
    reason = tostring(reason or "consecration"),
    tick = now(),
    expires_tick = now() + 60 * 12,
  }
  return true, nil
end

local function release_target_claim(pair, entity, reason)
  local key = target_claim_key(entity)
  if not key then return false end
  local claims = claims_root()
  local claim = claims[key]
  if claim and claim.owner == pair_claim_id(pair) then
    claims[key] = nil
    record(pair, "claim-release", tostring(reason or "release") .. " target=" .. safe(claim.target))
    return true
  end
  return false
end

local function get_order(pair)
  local q=pair and pair.order_queue_0469
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end

local function order_kind(order) return lower(order and (order.kind or order.type or order.key or order.source) or "") end
local function order_is_consecration(order)
  local k=order_kind(order)
  return k:find("consecr",1,true) or k:find("sanct",1,true)
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

local function record_for(entity)
  if not (valid(entity) and _G.get_consecration_record) then return nil end
  local ok, rec = pcall(_G.get_consecration_record, entity)
  if ok then return rec end
  return nil
end

local function is_target(entity)
  if not valid(entity) then return false end
  if _G.is_consecration_target then local ok,res=pcall(_G.is_consecration_target, entity); return ok and res == true end
  return false
end

local function max_for(record, entity)
  if record and record.max_sanctification then return record.max_sanctification end
  if _G.get_base_sanctification_max then
    local force = entity and entity.valid and entity.force or nil
    local ok,v = pcall(_G.get_base_sanctification_max, force)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return 100
end

local function item_for(station, missing)
  if _G.get_available_station_consecration_item then
    local ok,item = pcall(_G.get_available_station_consecration_item, station, missing)
    if ok then return item end
  end
  return nil
end

local function has_station_item(station)
  if _G.station_has_consecration_item then local ok,res=pcall(_G.station_has_consecration_item, station); return ok and res == true end
  return false
end

local function consume_station_item(station, item_name)
  if _G.consume_consecration_item_from_station then
    local ok,res=pcall(_G.consume_consecration_item_from_station, station, item_name)
    return ok and res == true
  end
  local inv = station and station.valid and _G.get_station_inventory and _G.get_station_inventory(station) or nil
  return inv and inv.remove({name=item_name,count=1}) > 0
end

local function service_threshold(pair, order)
  if order_is_consecration(order) then return M.idle_ratio end
  local mode = lower(pair and pair.mode)
  if mode:find("idle",1,true) or mode == "" then return M.routine_ratio end
  return M.maintenance_ratio
end

local function eligible(pair, entity, order)
  if not (valid_pair(pair) and is_target(entity)) then return false, "not-target", nil end
  local within, range_why = within_travel_limit(pair, entity)
  if not within then return false, range_why or "target-out-of-bounds", nil end
  local record = record_for(entity)
  if not record then return false, "no-record", nil end
  local maximum = max_for(record, entity)
  local current = tonumber(record.sanctification) or 0
  if maximum <= 0 then return false, "bad-max", nil end
  if current >= maximum then return false, "full", nil end
  if tonumber(record.next_priest_consecration_tick_0515 or 0) > now() then return false, "target-cooldown", nil end
  local claimed, claim = target_claimed_by_other(pair, entity)
  if claimed then return false, "claimed-by-other:" .. safe(claim and claim.owner), nil end
  local missing = maximum - current
  local item = item_for(pair.station, missing)
  if not item then return false, "no-useful-item", nil end
  local ratio = current / maximum
  local threshold = service_threshold(pair, order)
  if ratio > threshold and not order_is_consecration(order) then return false, "above-threshold", nil end
  return true, nil, { record=record, current=current, maximum=maximum, missing=missing, item=item, ratio=ratio }
end

local function find_target(pair, order)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  if not has_station_item(pair.station) then return nil, "no-consecration-item" end
  local explicit = order_target(pair)
  if explicit then
    local ok, why, info = eligible(pair, explicit, order)
    if ok then return explicit, info, "explicit" end
  end
  local names = rawget(_G, "CONSECRATION_TARGET_NAME_LIST")
  if not names then return nil, "no-target-list" end
  local radius = tonumber(pair.radius) or (_G.get_station_consecration_radius and _G.get_station_consecration_radius(pair.station)) or 32
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  local entities, source
  if Scan and type(Scan.find_entities) == "function" then
    entities, source = Scan.find_entities(pair.station.surface, { name = names, force = pair.station.force, position = pair.station.position, radius = radius }, { category = "consecration", negative_key = "consecration:" .. safe(pair.station.surface.index) .. ":" .. safe(pair.station.force.index) .. ":" .. safe(station_unit(pair)), negative_ttl = 60 * 5, record_negative = false })
  else
    local ok, scanned = pcall(function()
      return pair.station.surface.find_entities_filtered({ name = names, force = pair.station.force, position = pair.station.position, radius = radius })
    end)
    if ok then entities = scanned end
  end
  if not entities then return nil, "search-failed" end
  local order_current = order
  local best, best_info, best_score
  local checked = 0
  for _, e in pairs(entities) do
    checked = checked + 1
    if checked > M.max_candidates then break end
    local ok2, why, info = eligible(pair, e, order_current)
    if ok2 and info then
      local ds = dist_sq(pair.priest.position, e.position) or dist_sq(pair.station.position, e.position) or 0
      local urgency = 1 - math.min(1, info.ratio or 1)
      local active_bonus = 0
      local status = nil
      pcall(function() status = e.status end)
      if status and status ~= defines.entity_status.no_power and status ~= defines.entity_status.disabled then active_bonus = 0.15 end
      local score = urgency * 1000 + active_bonus * 100 - (ds * 0.01)
      if not best_score or score > best_score then best, best_info, best_score = e, info, score end
    end
  end
  if best then return best, best_info, source or "scan" end
  if Scan and type(Scan.record_negative) == "function" then Scan.record_negative("consecration", "consecration:" .. safe(pair.station.surface.index) .. ":" .. safe(pair.station.force.index) .. ":" .. safe(station_unit(pair)), 60 * 5) end
  return nil, "no-eligible-target"
end

local function request_move(pair, target, reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  local pos = target.position
  if _G.tech_priests_request_movement_0418 then
    local ok,res = pcall(_G.tech_priests_request_movement_0418, pair, pos, reason or "consecration-executor-0515", { radius = 1.25, owner = "consecration_executor_0515", priority = 705, ttl = 900, distraction = defines and defines.distraction and defines.distraction.none })
    if ok and res ~= false then return true end
  end
  if _G.move_priest_to then local ok=pcall(_G.move_priest_to, pair.priest, target); if ok then return true end end
  if pair.priest and pair.priest.valid and defines and defines.command then
    local command = { type=defines.command.go_to_location, destination=pos, radius=1.25, distraction=defines.distraction.none }
    if _G.tech_priests_route_ground_command_0429 then
      local ok,res = pcall(_G.tech_priests_route_ground_command_0429, pair.priest, command, reason or "consecration-executor-fallback-0616", { pair = pair, priority = 705, ttl = 900 })
      if ok and res ~= false then return true end
    elseif pair.priest.set_command then
      local ok=pcall(function() pair.priest.set_command(command) end)
      if ok then return true end
    end
  end
  return false
end

local function make_actor(pair)
  local priest = pair and pair.priest
  local station = pair and pair.station
  local pname = pair and (pair.priest_display_name or pair.display_name or pair.priest_name) or nil
  if not pname and valid(priest) then pname = priest.name .. "#" .. tostring(priest.unit_number or "?") end
  local sname = pair and (pair.station_display_name or pair.station_name) or nil
  if not sname and valid(station) then sname = station.name .. "#" .. tostring(station.unit_number or "?") end
  return pname or "Tech-Priest", sname or "Cogitator Station"
end

local function apply_source(pair, target, item_name, info)
  local priest_label, station_label = make_actor(pair)
  local ctx = {
    source_type = "tech-priest",
    method = "priest-capsule-rite",
    priest_name = valid(pair.priest) and pair.priest.name or pair.priest_name,
    priest_unit = valid(pair.priest) and pair.priest.unit_number or pair.priest_unit,
    priest_label = priest_label,
    station_name = valid(pair.station) and pair.station.name or nil,
    station_unit = valid(pair.station) and pair.station.unit_number or pair.station_unit,
    station_label = station_label,
    item = item_name,
    order_id = get_order(pair) and get_order(pair).key or nil,
    tick = now(),
  }
  if _G.tech_priests_0515_apply_consecration_from_source then
    local ok, did, restored = pcall(_G.tech_priests_0515_apply_consecration_from_source, target, item_name, ctx)
    if ok and did then return true, restored end
    return false, did
  end
  -- Fallback if the enriched API did not install: direct restoration plus legacy source mark.
  local record = info and info.record or record_for(target)
  if not record then return false, "no-record" end
  local current = tonumber(record.sanctification) or 0
  local maximum = max_for(record, target)
  local amount = tonumber(info and info.item and info.item.amount) or (_G.get_player_consecration_item_restore_amount and _G.get_player_consecration_item_restore_amount(item_name)) or 1
  local restored = math.min(amount, maximum - current)
  if restored <= 0 then return false, "full" end
  record.sanctification = current + restored
  if _G.tech_priests_0478_record_consecration_source then pcall(_G.tech_priests_0478_record_consecration_source, record, target, "tech-priest capsule rite", item_name, restored, current, record.sanctification, maximum, nil) end
  return true, restored
end

local function complete_order(pair, reason)
  local q = pair and pair.order_queue_0469
  if q and q.current and order_is_consecration(q.current) then
    q.current.status = "complete"
    q.current.finished_tick = now()
    q.current.finish_reason = reason or "consecration-complete-0515"
    q.current = nil
    pair.active_order_0469 = nil
  end
end

function M.active(pair)
  if not pair then return false end
  local s = pair.consecration_0515
  if s and s.phase and s.phase ~= "none" and s.phase ~= "complete" then return true end
  local order = get_order(pair)
  if order_is_consecration(order) then return true end
  local mode = lower(pair.mode)
  return mode:find("consecr",1,true) or mode:find("sanct",1,true)
end

function M.service_pair(pair, reason, forced_target)
  local r=M.root()
  if r.enabled == false then return false, "disabled" end
  cleanup_claims()
  if not valid_pair(pair) then return false, "invalid-pair" end
  local order = get_order(pair)
  local state = pair.consecration_0515 or { phase = "none" }
  pair.consecration_0515 = state
  state.version = M.version
  state.last_service_tick = now()
  state.last_reason = tostring(reason or "service")
  if state.no_item_retry_until and state.no_item_retry_until > now() and not forced_target then
    return false, "no-consecration-item-cooldown"
  end

  local target = forced_target or (valid(state.target) and state.target or nil)
  local info
  if target then
    local ok, why, i = eligible(pair, target, order)
    if ok then
      info = i
    else
      release_target_claim(pair, target, why or "target-invalid")
      target = nil; state.phase = "target-invalid"; state.last_blocker = why
    end
  end
  if not target then
    target, info, state.target_source = find_target(pair, order)
    if not target then
      state.phase = "need-item"
      state.last_blocker = tostring(info or "no-target")
      pair.mode = has_station_item(pair.station) and "no-consecration-target" or "missing-consecration-supplies"
      if state.last_blocker == "no-consecration-item" or state.last_blocker == "no-useful-item" then
        state.no_item_retry_until = now() + M.no_item_retry_ticks
      end
      if not state.last_no_target_record_tick or (now() - state.last_no_target_record_tick) > 120 then
        record(pair, "no-target", state.last_blocker)
        state.last_no_target_record_tick = now()
      end
      return false, state.last_blocker
    end
    local claimed, why_claim = claim_target(pair, target, "selected-" .. tostring(state.target_source or "scan"))
    if not claimed then
      state.phase = "target-claimed"
      state.last_blocker = why_claim or "claimed"
      record(pair, "claim-blocked", state.last_blocker)
      return false, state.last_blocker
    end
    state.target = target
    state.target_unit = target.unit_number
    state.target_name = target.name
  else
    claim_target(pair, target, "continue-" .. tostring(state.phase or "active"))
  end
  pair.target = target

  if tonumber(pair.next_consecration_tick or 0) > now() then
    state.phase = "cooldown"
    pair.mode = "consecrating-cooldown"
    record(pair, "cooldown", "until=" .. safe(pair.next_consecration_tick))
    return true, "cooldown"
  end

  local reach = tonumber(rawget(_G, "PRIEST_CONSECRATION_REACH_DISTANCE_SQ")) or 16
  local ds = dist_sq(pair.priest.position, target.position) or 999999
  if ds > reach then
    local moved = request_move(pair, target, "consecration-executor-0515-walk-to-target")
    state.distance = math.sqrt(ds)
    if not moved then
      release_target_claim(pair, target, "movement-request-failed")
      state.phase = "movement-request-failed"
      state.last_blocker = "consecration-move-request-failed"
      pair.mode = "consecration-movement-failed"
      record(pair, "movement-request-failed-0515", target.name .. "#" .. safe(target.unit_number or "?") .. " dist=" .. string.format("%.1f", state.distance))
      return false, "movement-request-failed"
    end
    state.phase = "walk-to-target"
    pair.mode = "moving-to-consecrate"
    record(pair, "walk", target.name .. "#" .. safe(target.unit_number or "?") .. " dist=" .. string.format("%.1f", state.distance))
    return true, "walk-to-target"
  end

  local missing = info and info.missing or 1
  local item = info and info.item or item_for(pair.station, missing)
  if not item then
    release_target_claim(pair, target, "no-useful-consecration-item")
    state.phase = "need-item"
    state.last_blocker = "no-useful-consecration-item"
    state.no_item_retry_until = now() + M.no_item_retry_ticks
    pair.mode = "missing-consecration-supplies"
    if not state.last_need_item_record_tick or (now() - state.last_need_item_record_tick) > 120 then
      record(pair, "need-item", state.last_blocker)
      state.last_need_item_record_tick = now()
    end
    return false, state.last_blocker
  end

  state.phase = state.phase == "throw-or-apply-capsule" and state.phase or "prepare-capsule-rite"
  state.item = item.name
  state.started_tick = state.started_tick or now()
  state.due_tick = state.due_tick or (now() + M.service_time_ticks)
  pair.mode = "performing-consecration-rite"

  if now() < state.due_tick then
    record(pair, "rite-progress", tostring(item.name) .. " due=" .. safe(state.due_tick))
    return true, "prepare-capsule-rite"
  end

  state.phase = "throw-or-apply-capsule"
  if not consume_station_item(pair.station, item.name) then
    release_target_claim(pair, target, "consume-failed")
    state.phase = "need-item"
    state.last_blocker = "consume-failed"
    record(pair, "consume-failed", tostring(item.name))
    return false, "consume-failed"
  end

  local ok_apply, restored = apply_source(pair, target, item.name, info)
  if not ok_apply then
    -- Refund if restoration failed after consumption; avoid eating rare rites on bad target/state.
    pcall(function() local inv=_G.get_station_inventory and _G.get_station_inventory(pair.station); if inv then inv.insert({name=item.name,count=1}) end end)
    release_target_claim(pair, target, "apply-failed")
    state.phase = "target-invalid"
    state.last_blocker = "apply-failed:" .. safe(restored)
    record(pair, "apply-failed", state.last_blocker)
    return false, state.last_blocker
  end

  pcall(function() if _G.play_repair_feedback then _G.play_repair_feedback(pair.station.surface, target.position) end end)
  local rec = record_for(target)
  if rec then
    pcall(function() if _G.draw_sanctification_label then _G.draw_sanctification_label(rec) end end)
    pcall(function() if _G.update_sanctification_overlay then _G.update_sanctification_overlay(rec, true) end end)
    rec.next_priest_consecration_tick_0515 = now() + M.target_cooldown_ticks
  end
  pair.next_consecration_tick = now() + M.pair_cooldown_ticks
  release_target_claim(pair, target, "complete")
  state.phase = "complete"
  state.completed_tick = now()
  state.restored = restored
  state.target = nil
  state.started_tick = nil
  state.due_tick = nil
  pair.mode = "idle"
  pair.target = nil
  complete_order(pair, "consecration-complete-0515")
  record(pair, "complete", tostring(item.name) .. " restored=" .. safe(restored))
  return true, "complete"
end

function M.submit_or_assign_consecration_task(pair, target, reason)
  if not valid_pair(pair) then return false end
  if not valid(target) then
    local found, info = find_target(pair, get_order(pair))
    target = found
  end
  if not valid(target) then return false end
  local task = { type="consecration", kind="consecration", phase="sanctification", key="consecration", visual="consecrating", target=target, priority=700, owner_system="consecration-executor-0515" }
  local okS, Scheduler = pcall(require, "scripts.core.task_scheduler")
  if okS and Scheduler and type(Scheduler.assign_task)=="function" then
    pcall(Scheduler.assign_task, pair, task, reason or "consecration-0515")
  else
    pair.active_task = task; pair.active_task_0285 = task; pair.target = target; pair.mode = "consecrating"
  end
  local submit = rawget(_G, "tech_priests_0469_submit_order")
  if type(submit)=="function" then
    pcall(submit, pair, { kind="consecration", item="sacred-machine-oil", target=target, priority=700, source="consecration_executor_0515", task=task })
  end
  return true
end

local function wrap_legacy_sanctify()
  if type(_G.sanctify_target_with_priest) ~= "function" or original_sanctify then return false end
  original_sanctify = _G.sanctify_target_with_priest
  _G.TECH_PRIESTS_0515_PRE_SANCTIFY_TARGET_WITH_PRIEST = original_sanctify
  _G.sanctify_target_with_priest = function(pair, target, ...)
    local r=M.root()
    if r.enabled ~= false and r.wrap_legacy ~= false and valid_pair(pair) then
      M.submit_or_assign_consecration_task(pair, target, "legacy-sanctify-adopted-0515")
      local acted, why = M.service_pair(pair, "legacy-sanctify-adopted-0515", target)
      return acted ~= false, why
    end
    return original_sanctify(pair, target, ...)
  end
  return true
end

local function wrap_scheduler()
  local okS, Scheduler = pcall(require, "scripts.core.task_scheduler")
  if not (okS and Scheduler and type(Scheduler.try_consecration)=="function") or original_scheduler_try_consecration then return false end
  original_scheduler_try_consecration = Scheduler.try_consecration
  Scheduler.TECH_PRIESTS_0515_PRE_TRY_CONSECRATION = original_scheduler_try_consecration
  Scheduler.try_consecration = function(pair)
    local r=M.root()
    if r.enabled == false or not valid_pair(pair) then return original_scheduler_try_consecration(pair) end
    local target = order_target(pair)
    if not (target and target.valid) then
      local found = find_target(pair, get_order(pair))
      target = found
    end
    if not (target and target.valid) then return false end
    M.submit_or_assign_consecration_task(pair, target, "scheduler-try-consecration-0515")
    return true
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp=storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-consecration-executor-0515") end end)
  commands.add_command("tp-consecration-executor-0515", "Tech Priests 0.1.515: dispatcher-owned consecration executor. Params: on/off/all", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true end
    if param=="off" then r.enabled=false end
    if param=="all" then for _,p in pairs(pair_map()) do pcall(M.service_pair,p,"manual-all") end end
    local pair=selected_pair(player)
    local lines={}
    lines[#lines+1]="[tp-consecration-executor-0515] enabled="..safe(r.enabled).." dispatcher_owned="..safe(r.dispatcher_owned).." wrap_legacy="..safe(r.wrap_legacy)
      .." complete="..safe(r.stats.complete or 0).." walk="..safe(r.stats.walk or 0).." need_item="..safe(r.stats["need-item"] or 0)
    if pair then
      local s=pair.consecration_0515 or {}
      lines[#lines+1]="selected station="..safe(station_unit(pair)).." priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." item="..safe(s.item).." blocker="..safe(s.last_blocker).." due="..safe(s.due_tick).." retry="..safe(s.no_item_retry_until)
    end
    local msg=table.concat(lines,"\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468") or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.consecration_executor_0515_wrapped then return false end
  local prev=diag.pair_dump_lines; diag.consecration_executor_0515_wrapped=true
  diag.pair_dump_lines=function()
    local lines=prev(); local r=M.root()
    local claim_count=0; for _ in pairs(r.target_claims or {}) do claim_count=claim_count+1 end
    lines[#lines+1]="PAIR-DUMP-0468 CONSECRATION-EXECUTOR-0515 BEGIN enabled="..safe(r.enabled).." complete="..safe(r.stats.complete or 0).." walk="..safe(r.stats.walk or 0).." no_target="..safe(r.stats["no-target"] or 0).." claims="..safe(claim_count)
    for _,pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local s=pair.consecration_0515 or {}
        lines[#lines+1]="PAIR-DUMP-0468 consecration0515["..safe(station_unit(pair)).."] priest="..safe(priest_unit(pair)).." mode="..safe(pair.mode).." phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." item="..safe(s.item).." blocker="..safe(s.last_blocker).." due="..safe(s.due_tick).." retry="..safe(s.no_item_retry_until).." restored="..safe(s.restored)
      end
    end
    for i=math.max(1,#r.recent-10),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 consecration0515.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail) end end
    lines[#lines+1]="PAIR-DUMP-0468 CONSECRATION-EXECUTOR-0515 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_legacy_sanctify()
  wrap_scheduler()
  wrap_pair_dump()
  install_command()
  _G.TechPriestsConsecrationExecutor0515 = M
  if log then log("[Tech-Priests 0.1.515] consecration executor installed; priest rites now route through dispatcher/phase executor with source-context records") end
  return true
end

return M