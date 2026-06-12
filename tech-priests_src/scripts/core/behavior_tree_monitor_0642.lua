-- scripts/core/behavior_tree_monitor_0642.lua
-- Tech Priests 0.1.653
-- Commandless behavior-tree monitor.

local M = {}
M.version = "0.1.653"
M.storage_key = "behavior_tree_monitor_0642"
M.tick_interval = 17
M.max_pairs_per_pulse = 40
M.history_limit = 24

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}
  return r
end
local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function remember(pair, rec, event) local r=root(); r.recent[#r.recent+1]={tick=now(),event=event or "sample",station=safe(station_unit(pair)),priest=safe(priest_unit(pair)),node=safe(rec.node),phase=safe(rec.phase),owner=safe(rec.owner),item=safe(rec.item),target=safe(rec.target),blocked=safe(rec.blocked_reason)}; while #r.recent>80 do table.remove(r.recent,1) end end

local function target_label(pair)
  if pair and valid(pair.target) then return safe(pair.target.name) .. "#" .. safe(pair.target.unit_number or "?") end
  local lock = pair and pair.direct_acquisition_target_lock_0650
  if lock and valid(lock.entity) then return safe(lock.entity.name) .. "#" .. safe(lock.entity.unit_number or "?") end
  local req = pair and pair.movement_request_0418
  if req and req.x and req.y then return string.format("pos:%.1f,%.1f", req.x, req.y) end
  return nil
end
local function first_item(pair)
  if not pair then return nil end
  local function from(v) if type(v)=="string" then return v end if type(v)~="table" then return nil end local cur=v.current or v.request or v; return cur.output_item or cur.item_name or cur.item or cur.name or cur.wanted_item or cur.requested_item or cur.target_item or cur.craft end
  for _, v in ipairs({ pair.local_infrastructure_gate_0640, pair.machine_logistics_0528, pair.active_supply_request, pair.supply_request, pair.logistic_requested_item, pair.requested_item, pair.direct_acquisition_task_0336, pair.active_acquisition_0333, pair.emergency_craft, pair.station_crafting_task_0337, pair.active_craft_0479, pair.scavenge, pair.inventory_scan, pair.construction_task_0338, pair.construction_task_0359, pair.construction_task }) do local item=from(v); if item and item ~= "" then return item end end
  return nil
end

local function infer_pair(pair)
  if type(pair) ~= "table" then return { node="BT-020", phase="invalid-pair", owner="behavior_tree_monitor_0642", entry_reason="non-table pair", ongoing="invalid", blocked_reason="invalid-pair" } end
  if not valid(pair.station) then return { node="BT-020", phase="station-invalid", owner="pair-validation", entry_reason="station invalid", ongoing="cleanup/recovery", blocked_reason="station-invalid" } end
  if not valid(pair.priest) then return { node="BT-020", phase="priest-invalid", owner="pair-validation", entry_reason="priest invalid", ongoing="recovery", blocked_reason="priest-invalid" } end
  local mode = lower(pair.mode); local d = pair.dispatcher_0510 or {}; local family = lower(d.family or d.action or ""); local item = first_item(pair); local target = target_label(pair)
  if pair.local_infrastructure_gate_0640 or mode:find("infrastructure",1,true) then return { node="BT-200", phase=safe((pair.local_infrastructure_gate_0640 or {}).why or "infrastructure-first"), owner="infrastructure", entry_reason="local fabrication required", ongoing="needed="..safe(item), item=item, target=target } end
  if pair.direct_acquisition_target_lock_0650 or pair.dispatcher_direct_0513 or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333 then return { node="BT-260", phase=safe((pair.dispatcher_direct_0513 or {}).phase or "direct-acquisition"), owner="direct-acquisition", entry_reason="direct acquisition active", ongoing=safe((pair.dispatcher_direct_0513 or {}).detail or "acquiring"), blocked_reason=(pair.dispatcher_direct_0513 or {}).blocked_reason, item=item or (pair.direct_acquisition_target_lock_0650 and pair.direct_acquisition_target_lock_0650.item), target=target } end
  if pair.construction_task_0338 or pair.construction_task_0359 or pair.construction_task or pair.construction_bootstrap_ghost_0645 then return { node="BT-280", phase=safe((pair.construction_bootstrap_ghost_0645 or {}).status or "construction"), owner="construction", entry_reason="construction task/ghost active", ongoing="construction target active", item=item, target=target } end
  if pair.dispatcher_emergency_production_0514 or pair.emergency_craft or pair.station_crafting_task_0337 or pair.active_craft_0479 then return { node="BT-240", phase=safe((pair.dispatcher_emergency_production_0514 or {}).phase or "production"), owner="emergency-production", entry_reason="production task active", ongoing=safe((pair.dispatcher_emergency_production_0514 or {}).detail or "production"), item=item, target=target } end
  if pair.machine_logistics_0528 then return { node="BT-300", phase=safe(pair.machine_logistics_0528.phase or "machine-logistics"), owner="machine-logistics", entry_reason="machine logistics active", ongoing=safe(pair.machine_logistics_0528.detail or "machine logistics"), item=item, target=target } end
  if family:find("combat",1,true) or mode:find("combat",1,true) or mode:find("defend",1,true) then return { node="BT-100", phase=safe(d.action or pair.mode or "combat"), owner="combat", entry_reason=safe(d.reason or "combat"), ongoing=target or "combat target unknown", item=item, target=target } end
  if family == "repair" or mode:find("repair",1,true) then return { node="BT-120", phase=safe(d.action or pair.mode or "repair"), owner="repair", entry_reason=safe(d.reason or "repair"), ongoing=target or "repair target unknown", item=item or "repair-pack", target=target } end
  return { node="BT-900", phase="idle", owner="idle/chatter", entry_reason=safe(d.reason or "no active task visible"), ongoing="waiting", item=item, target=target }
end

local function progress_key(rec) return table.concat({safe(rec.node),safe(rec.phase),safe(rec.owner),safe(rec.item),safe(rec.target),safe(rec.ongoing),safe(rec.blocked_reason)},"|") end
local function apply_record(pair, rec, reason)
  if not pair then return rec end
  local prev = pair.behavior_tree_0642; rec.version=M.version; rec.tick=now(); rec.station=safe(station_unit(pair)); rec.priest=safe(priest_unit(pair)); rec.reason=safe(reason or "sample")
  local pkey=progress_key(rec); local changed = not prev or prev.progress_key ~= pkey
  rec.previous_node = prev and prev.node or nil; rec.previous_phase = prev and prev.phase or nil; rec.started_tick = (not prev or prev.node ~= rec.node) and now() or (prev.started_tick or now()); rec.last_progress_tick = changed and now() or (prev and prev.last_progress_tick) or now(); rec.progress_key = pkey; rec.age_ticks = now() - (tonumber(rec.started_tick) or now()); rec.since_progress_ticks = now() - (tonumber(rec.last_progress_tick) or now())
  pair.behavior_tree_0642_history = pair.behavior_tree_0642_history or {}
  if changed then pair.behavior_tree_0642_history[#pair.behavior_tree_0642_history+1] = { tick=now(), node=rec.node, phase=rec.phase, owner=rec.owner, item=rec.item, target=rec.target, blocked=rec.blocked_reason, from_node=rec.previous_node, from_phase=rec.previous_phase }; while #pair.behavior_tree_0642_history > M.history_limit do table.remove(pair.behavior_tree_0642_history,1) end; remember(pair, rec, "change"); stat("changes") end
  pair.behavior_tree_0642 = rec; stat("samples"); return rec
end

function M.sample_pair(pair, reason) return apply_record(pair, infer_pair(pair), reason or "sample") end
function M.mark(pair, node, phase, owner, opts) opts=opts or {}; return apply_record(pair, { node=tostring(node or "BT-900"), phase=tostring(phase or "unknown"), owner=tostring(owner or "external"), entry_reason=tostring(opts.entry_reason or opts.reason or "explicit mark"), ongoing=tostring(opts.ongoing or "explicit mark"), exit_reason=opts.exit_reason, blocked_reason=opts.blocked_reason, item=opts.item, target=opts.target, next_node=opts.next_node }, opts.reason or "explicit-mark") end
function M.service_pair(pair, reason) local r=root(); if r.enabled == false then return false,"disabled" end if type(pair) ~= "table" then return false,"invalid" end M.sample_pair(pair, reason or "service"); return true,"sampled" end
function M.service_all(reason) local r=root(); if r.enabled == false then return 0 end local n=0; for _, pair in pairs(pair_map()) do if n>=M.max_pairs_per_pulse then break end if type(pair)=="table" then local ok=pcall(M.service_pair,pair,reason or "pulse"); if ok then n=n+1 end end end; r.last_service_tick=now(); return n end

function M.install()
  root(); _G.TechPriestsBehaviorTreeMonitor0642 = M; _G.tech_priests_behavior_tree_0642_mark = M.mark
  local broker = rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({ name="behavior_tree_monitor_0642", category="diagnostics", interval=M.tick_interval, priority=990, budget=10, dynamic_budget=false, fn=function(event,budget) M.service_all("broker"); return true end, note="sample canonical behavior-tree node/phase per station pair" })
  else local R=rawget(_G,"TechPriestsRuntimeEventRegistry"); if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end,{owner="behavior_tree_monitor_0642",category="diagnostics",priority="late"}) elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval,function() M.service_all("nth-tick") end) end end
  if log then log("[Tech-Priests 0.1.653] behavior tree monitor installed") end
  return true
end

return M
