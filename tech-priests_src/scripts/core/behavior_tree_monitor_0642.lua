-- scripts/core/behavior_tree_monitor_0642.lua
-- Tech Priests 0.1.642
--
-- Canonical behavior-tree observability monitor.
--
-- This module does not choose targets, move priests, clear work, or change
-- priority. It samples the existing behavior surfaces and writes one bounded
-- audit record to pair.behavior_tree_0642 so a selected station can answer:
-- what node am I in, why am I there, what phase owns me, what item/target is
-- involved, what proves progress, and what is blocking me?

local M = {}
M.version = "0.1.642"
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
local function dist_sq(a, b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1)
end

local function remember_global(pair, rec, event)
  local r = root()
  r.recent[#r.recent + 1] = {
    tick = now(),
    event = tostring(event or "sample"),
    station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)),
    node = safe(rec and rec.node),
    phase = safe(rec and rec.phase),
    owner = safe(rec and rec.owner),
    item = safe(rec and rec.item),
    target = safe(rec and rec.target),
    blocked = safe(rec and rec.blocked_reason),
  }
  while #r.recent > 80 do table.remove(r.recent, 1) end
end

local function entity_label(e)
  if not valid(e) then return nil end
  return safe(e.name or "entity") .. "#" .. safe(e.unit_number or "?")
end

local function pos_label(pos)
  if not (pos and pos.x and pos.y) then return nil end
  return string.format("pos:%.1f,%.1f", tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

local function entity_or_position(v, seen)
  if valid(v) then return v, v.position end
  if type(v) ~= "table" then return nil, nil end
  seen = seen or {}
  if seen[v] then return nil, nil end
  seen[v] = true
  if v.x and v.y then return nil, v end
  if v.position and v.position.x and v.position.y then return nil, v.position end
  for _, key in ipairs({ "target", "source", "entity", "resource_entity", "mining_target", "candidate", "current", "selected", "node", "resource", "destination" }) do
    local e, p = entity_or_position(v[key], seen)
    if e or p then return e, p end
  end
  return nil, nil
end

local function target_from_pair(pair)
  if not pair then return nil, nil end
  local q = pair.order_queue_0469
  local order = q and q.current or pair.active_order_0469
  for _, v in ipairs({
    order and order.target,
    order and order.task,
    pair.target,
    pair.combat_target,
    pair.repair_target,
    pair.consecration_target,
    pair.construction_task_0338,
    pair.construction_task_0359,
    pair.construction_task,
    pair.direct_acquisition_task_0336,
    pair.active_acquisition_0333,
    pair.emergency_craft,
    pair.scavenge,
    pair.inventory_scan,
    pair.machine_logistics_0528,
  }) do
    local e, p = entity_or_position(v)
    if e or p then return e, p end
  end
  return nil, nil
end

local function target_label(pair)
  local e, p = target_from_pair(pair)
  if valid(e) then return entity_label(e) end
  return pos_label(p)
end

local function distance_to_target(pair)
  if not valid_pair(pair) then return nil end
  local _, p = target_from_pair(pair)
  if not p then return nil end
  local d2 = dist_sq(pair.priest.position, p)
  if not d2 then return nil end
  return math.sqrt(d2)
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  local cur = v.current or v.request or v.task or v
  if type(cur) ~= "table" then return nil end
  return cur.item or cur.item_name or cur.output_item or cur.wanted_item or cur.requested_item or cur.resource or cur.name or cur.target_item or cur.craft or cur.kind
end

local function order_item(pair)
  local q = pair and pair.order_queue_0469
  local o = q and q.current or pair and pair.active_order_0469
  return o and (o.item or o.wanted_item or o.requested_item or item_from(o.task)) or nil
end

local function first_item(pair)
  if not pair then return nil end
  for _, v in ipairs({
    pair.local_infrastructure_gate_0640,
    pair.machine_logistics_0528,
    pair.active_supply_request,
    pair.supply_request,
    pair.logistic_requested_item,
    pair.requested_item,
    pair.direct_acquisition_task_0336,
    pair.active_acquisition_0333,
    pair.emergency_craft,
    pair.station_crafting_task_0337,
    pair.active_craft_0479,
    pair.scavenge,
    pair.inventory_scan,
    pair.construction_task_0338,
    pair.construction_task_0359,
    pair.construction_task,
    order_item(pair),
  }) do
    local item = item_from(v)
    if item and item ~= "" then return item end
  end
  return nil
end

local function direct_current(pair)
  local direct_kinds = { ["direct-mine-0273"] = true, ["direct-dirt-0273"] = true, ["dirt"] = true, ["direct-mine-0336"] = true }
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair and pair[key]
    local cur = type(task) == "table" and (task.current or task) or nil
    if cur and direct_kinds[tostring(cur.kind or "")] then return task, cur, key end
  end
  return nil, nil, nil
end

local function phase_not_done(phase)
  phase = lower(phase)
  return phase ~= "" and phase ~= "none" and phase ~= "complete" and phase ~= "idle" and phase ~= "target-invalid" and phase ~= "invalid-item"
end

local function direct_counts(pair)
  local task = direct_current(pair)
  if type(task) ~= "table" then return nil end
  local gathered = tonumber(task.gathered_units) or 0
  local required = tonumber(task.required_count or task.count) or 1
  return safe(gathered) .. "/" .. safe(required)
end

local function infer_invalid(pair)
  if type(pair) ~= "table" then
    return {
      node = "BT-020",
      phase = "invalid-pair",
      owner = "behavior_tree_monitor_0642",
      entry_reason = "sampled non-table pair",
      ongoing = "no valid pair table",
      blocked_reason = "invalid-pair-table",
    }
  end
  if not valid(pair.station) then
    return {
      node = "BT-020",
      phase = "station-invalid",
      owner = "pair-validation",
      entry_reason = "station handle invalid",
      ongoing = "awaiting pair recovery or cleanup",
      blocked_reason = "station-invalid",
    }
  end
  if not valid(pair.priest) then
    return {
      node = "BT-020",
      phase = "priest-invalid",
      owner = "pair-validation",
      entry_reason = "priest handle invalid",
      ongoing = "awaiting priest recovery/reimprint",
      blocked_reason = "priest-invalid",
    }
  end
  return nil
end

local function infer_pair(pair)
  local invalid = infer_invalid(pair)
  if invalid then return invalid end

  local mode = lower(pair.mode)
  local d = pair.dispatcher_0510 or {}
  local family = lower(d.family or d.action or "")
  local item = first_item(pair)
  local target = target_label(pair)
  local distance = distance_to_target(pair)
  local ongoing_distance = distance and ("dist=" .. string.format("%.1f", distance)) or nil

  if pair.local_infrastructure_gate_0640 or mode:find("infrastructure%-first", 1, false) then
    local g = pair.local_infrastructure_gate_0640 or {}
    return {
      node = "BT-200",
      phase = safe(g.why or "infrastructure-first"),
      owner = "infrastructure_first_governor_0640",
      entry_reason = "local fabrication spine required before higher-tier work",
      ongoing = "needed=" .. safe(g.item or item) .. " blocked=" .. safe(g.blocked_item),
      blocked_reason = g.blocked_item and ("deferred high-tier " .. safe(g.blocked_item)) or nil,
      item = g.item or item,
      target = target,
      next_node = "BT-220/BT-240",
    }
  end

  local direct_phase = pair.dispatcher_direct_0513 and pair.dispatcher_direct_0513.phase or nil
  if phase_not_done(direct_phase) or direct_current(pair) then
    local s = pair.dispatcher_direct_0513 or {}
    local blocked = nil
    if lower(s.phase):find("failed", 1, true) or lower(s.phase):find("blocked", 1, true) or lower(s.phase):find("rejected", 1, true) then blocked = safe(s.detail or s.phase) end
    return {
      node = "BT-260",
      phase = safe(s.phase or "direct-task"),
      owner = "direct_acquisition_executor_0513",
      entry_reason = "direct acquisition task/current exists",
      ongoing = (ongoing_distance or "target-distance=?") .. " count=" .. safe(direct_counts(pair) or "?"),
      blocked_reason = blocked,
      item = s.item or item,
      target = s.target or target,
      next_node = "BT-240 or return-to-station",
    }
  end

  local prod_phase = pair.dispatcher_emergency_production_0514 and pair.dispatcher_emergency_production_0514.phase or nil
  if phase_not_done(prod_phase) or pair.emergency_craft or pair.station_crafting_task_0337 or pair.active_craft_0479 then
    local s = pair.dispatcher_emergency_production_0514 or {}
    local blocked = nil
    if lower(s.phase):find("failed", 1, true) or lower(s.phase):find("blocked", 1, true) or lower(s.phase):find("need", 1, true) then blocked = safe(s.detail or s.phase) end
    return {
      node = "BT-240",
      phase = safe(s.phase or "production-task"),
      owner = "emergency_production_executor_0514",
      entry_reason = "station/emergency production task exists",
      ongoing = safe(s.detail or "production task active"),
      blocked_reason = blocked,
      item = s.item or item,
      target = target,
      next_node = "BT-230/BT-260/complete",
    }
  end

  if pair.construction_task_0338 or pair.construction_task_0359 or pair.construction_task then
    return {
      node = "BT-280",
      phase = safe((pair.construction_task_0338 or pair.construction_task_0359 or pair.construction_task or {}).phase or "construction-task"),
      owner = "construction_planner",
      entry_reason = "construction task present",
      ongoing = ongoing_distance or "construction target active",
      item = item,
      target = target,
      next_node = "BT-220 or idle",
    }
  end

  local ml = pair.machine_logistics_0528
  if type(ml) == "table" and phase_not_done(ml.phase) then
    return {
      node = "BT-300",
      phase = safe(ml.phase),
      owner = "machine_logistics_0528",
      entry_reason = "machine logistics phase active",
      ongoing = safe(ml.detail or ml.reason or "machine logistics active"),
      blocked_reason = ml.blocked_reason,
      item = item_from(ml) or item,
      target = target,
      next_node = "BT-260/BT-240/complete",
    }
  end

  local cons = pair.consecration_0515
  if type(cons) == "table" and phase_not_done(cons.phase) then
    return {
      node = "BT-320",
      phase = safe(cons.phase),
      owner = "consecration_executor_0515",
      entry_reason = "consecration phase active",
      ongoing = safe(cons.detail or cons.reason or "consecration active"),
      blocked_reason = cons.blocked_reason,
      item = item or "sacred-machine-oil",
      target = target,
      next_node = "complete or BT-240",
    }
  end

  if family:find("combat", 1, true) or mode:find("combat", 1, true) or mode:find("defend", 1, true) then
    return {
      node = "BT-100",
      phase = safe(d.action or pair.mode or "combat"),
      owner = "single_dispatcher_0510/combat_doctrine",
      entry_reason = safe(d.reason or "combat-like family/mode"),
      ongoing = target and ("target=" .. target) or "combat target unknown",
      item = item,
      target = target,
      next_node = "resume prior work or idle",
    }
  end

  if family == "repair" or mode:find("repair", 1, true) then
    return {
      node = "BT-120",
      phase = safe(d.action or pair.mode or "repair"),
      owner = "repair_executor_0516",
      entry_reason = safe(d.reason or "repair family/mode"),
      ongoing = target and ("target=" .. target) or "repair target unknown",
      item = item or "repair-pack",
      target = target,
      next_node = "complete or BT-240",
    }
  end

  if pair.last_supply_satisfied_0639 and now() - (tonumber(pair.last_supply_satisfied_0639.tick) or 0) < 180 then
    return {
      node = "BT-140",
      phase = "recently-satisfied",
      owner = "station_supply_satisfaction_0639",
      entry_reason = "critical supply request already satisfied",
      ongoing = "item=" .. safe(pair.last_supply_satisfied_0639.item),
      item = pair.last_supply_satisfied_0639.item,
      target = target,
      next_node = "resume previous work or idle",
    }
  end

  if family == "direct-acquisition" or family == "acquisition" or pair.active_supply_request or pair.supply_request or pair.logistic_requested_item or pair.scavenge or pair.inventory_scan then
    return {
      node = "BT-260",
      phase = safe(d.action or pair.mode or "acquisition-intent"),
      owner = "single_dispatcher_0510/acquisition doctrine",
      entry_reason = safe(d.reason or "acquisition-like state present"),
      ongoing = ongoing_distance or "acquisition target not yet selected",
      item = item,
      target = target,
      blocked_reason = target and nil or "acquisition-intent-without-target",
      next_node = "direct target selection or production",
    }
  end

  if family == "station-craft" or family == "crafting" or mode:find("craft", 1, true) then
    return {
      node = "BT-240",
      phase = safe(d.action or pair.mode or "crafting"),
      owner = "single_dispatcher_0510/emergency_production_executor_0514",
      entry_reason = safe(d.reason or "crafting-like state present"),
      ongoing = "craft state without active production phase",
      item = item,
      target = target,
      blocked_reason = "craft-family-without-production-phase",
      next_node = "BT-240 audit required",
    }
  end

  if family == "consecration" or mode:find("consecr", 1, true) or mode:find("sanct", 1, true) then
    return {
      node = "BT-320",
      phase = safe(d.action or pair.mode or "consecration"),
      owner = "single_dispatcher_0510/consecration",
      entry_reason = safe(d.reason or "consecration-like state present"),
      ongoing = target and ("target=" .. target) or "consecration target unknown",
      item = item or "sacred-machine-oil",
      target = target,
      next_node = "complete or audit stale state",
    }
  end

  if pair.idle_player_conversation_0181 or pair.idle_conversation or family == "conversation" then
    return {
      node = "BT-900",
      phase = "conversation",
      owner = "chatter/idle",
      entry_reason = "conversation state active",
      ongoing = "flavor only",
      target = target,
      next_node = "yield to any work claim",
    }
  end

  return {
    node = "BT-900",
    phase = "idle",
    owner = "idle/chatter",
    entry_reason = safe(d.reason or "no active task visible"),
    ongoing = "waiting at station",
    item = item,
    target = target,
    next_node = "first valid work claim",
  }
end

local function progress_key(rec)
  return table.concat({
    safe(rec.node), safe(rec.phase), safe(rec.owner), safe(rec.item), safe(rec.target), safe(rec.ongoing), safe(rec.blocked_reason)
  }, "|")
end

local function apply_record(pair, rec, reason)
  if not pair then return rec end
  local prev = pair.behavior_tree_0642
  rec.version = M.version
  rec.tick = now()
  rec.station = safe(station_unit(pair))
  rec.priest = safe(priest_unit(pair))
  rec.reason = safe(reason or "sample")

  local pkey = progress_key(rec)
  local node_changed = not prev or prev.node ~= rec.node
  local phase_changed = not prev or prev.phase ~= rec.phase
  local progress_changed = not prev or prev.progress_key ~= pkey

  rec.previous_node = prev and prev.node or nil
  rec.previous_phase = prev and prev.phase or nil
  rec.started_tick = node_changed and now() or (prev and prev.started_tick) or now()
  rec.last_progress_tick = (node_changed or phase_changed or progress_changed) and now() or (prev and prev.last_progress_tick) or now()
  rec.progress_key = pkey
  rec.age_ticks = now() - (tonumber(rec.started_tick) or now())
  rec.since_progress_ticks = now() - (tonumber(rec.last_progress_tick) or now())

  pair.behavior_tree_0642_history = pair.behavior_tree_0642_history or {}
  if node_changed or phase_changed or progress_changed then
    pair.behavior_tree_0642_history[#pair.behavior_tree_0642_history + 1] = {
      tick = now(), node = rec.node, phase = rec.phase, owner = rec.owner,
      item = rec.item, target = rec.target, blocked = rec.blocked_reason, from_node = rec.previous_node, from_phase = rec.previous_phase,
    }
    while #pair.behavior_tree_0642_history > M.history_limit do table.remove(pair.behavior_tree_0642_history, 1) end
    remember_global(pair, rec, node_changed and "node-change" or "phase/progress")
    if node_changed then stat("node_changes") else stat("phase_or_progress_changes") end
  end

  pair.behavior_tree_0642 = rec
  stat("samples")
  return rec
end

function M.sample_pair(pair, reason)
  local rec = infer_pair(pair)
  return apply_record(pair, rec, reason or "sample")
end

function M.mark(pair, node, phase, owner, opts)
  opts = opts or {}
  local rec = {
    node = tostring(node or "BT-900"),
    phase = tostring(phase or "unknown"),
    owner = tostring(owner or "external"),
    entry_reason = tostring(opts.entry_reason or opts.reason or "explicit mark"),
    ongoing = tostring(opts.ongoing or "explicit mark"),
    exit_reason = opts.exit_reason,
    blocked_reason = opts.blocked_reason,
    item = opts.item,
    target = opts.target,
    next_node = opts.next_node,
  }
  return apply_record(pair, rec, opts.reason or "explicit-mark")
end

function M.service_pair(pair, reason)
  local r = root()
  if r.enabled == false then return false, "disabled" end
  if type(pair) ~= "table" then return false, "invalid" end
  M.sample_pair(pair, reason or "service")
  return true, "sampled"
end

function M.service_all(reason)
  local r = root()
  if r.enabled == false then return 0 end
  local n = 0
  for _, pair in pairs(pair_map()) do
    if n >= M.max_pairs_per_pulse then break end
    if type(pair) == "table" then
      local ok = pcall(M.service_pair, pair, reason or "pulse")
      if ok then n = n + 1 end
    end
  end
  r.last_service_tick = now()
  return n
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    local unit = selected.unit_number
    if unit and tp.pairs_by_station and tp.pairs_by_station[unit] then return tp.pairs_by_station[unit] end
    if unit and tp.pairs_by_priest and tp.pairs_by_priest[unit] then return tp.pairs_by_priest[unit] end
  end
  return nil
end

local function rec_lines(pair)
  local rec = pair and pair.behavior_tree_0642 or nil
  if not rec then return { "[tp-behavior-tree-0642] no behavior sample yet; run /tp-behavior-tree-0642 kick" } end
  local lines = {}
  lines[#lines + 1] = "[tp-behavior-tree-0642] station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " node=" .. safe(rec.node) .. " phase=" .. safe(rec.phase) .. " owner=" .. safe(rec.owner)
  lines[#lines + 1] = "  item=" .. safe(rec.item) .. " target=" .. safe(rec.target) .. " next=" .. safe(rec.next_node)
  lines[#lines + 1] = "  entry=" .. safe(rec.entry_reason)
  lines[#lines + 1] = "  ongoing=" .. safe(rec.ongoing)
  lines[#lines + 1] = "  blocked=" .. safe(rec.blocked_reason) .. " exit=" .. safe(rec.exit_reason)
  lines[#lines + 1] = "  age=" .. safe(rec.age_ticks or 0) .. " ticks since_progress=" .. safe(rec.since_progress_ticks or 0) .. " prev=" .. safe(rec.previous_node) .. "/" .. safe(rec.previous_phase)
  return lines
end

local function history_lines(pair)
  local out = {}
  local h = pair and pair.behavior_tree_0642_history or {}
  for i = math.max(1, #h - 8), #h do
    local ev = h[i]
    if ev then out[#out + 1] = "  [" .. safe(ev.tick) .. "] " .. safe(ev.from_node) .. "/" .. safe(ev.from_phase) .. " -> " .. safe(ev.node) .. "/" .. safe(ev.phase) .. " owner=" .. safe(ev.owner) .. " item=" .. safe(ev.item) .. " blocked=" .. safe(ev.blocked) end
  end
  return out
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-tree-0642") end end)
  commands.add_command("tp-behavior-tree-0642", "Tech Priests 0.1.642: selected station behavior-tree audit. Params: status/kick/all/on/off/recent", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false elseif p == "all" then M.service_all("command-all") end
    local pair = selected_pair(player)
    if p == "kick" and pair then M.service_pair(pair, "command-kick") end
    local lines = {}
    lines[#lines + 1] = "[tp-behavior-tree-0642] enabled=" .. safe(r.enabled) .. " samples=" .. safe(r.stats.samples or 0) .. " node_changes=" .. safe(r.stats.node_changes or 0) .. " phase_progress=" .. safe(r.stats.phase_or_progress_changes or 0)
    if pair then
      if not pair.behavior_tree_0642 then M.service_pair(pair, "command-status-sample") end
      for _, line in ipairs(rec_lines(pair)) do lines[#lines + 1] = line end
      if p == "recent" or p == "kick" then for _, line in ipairs(history_lines(pair)) do lines[#lines + 1] = line end end
    else
      lines[#lines + 1] = "  select a Cogitator Station or Tech-Priest for pair details"
    end
    if player and player.valid then for _, line in ipairs(lines) do player.print(line) end elseif game and game.print then for _, line in ipairs(lines) do game.print(line) end end
  end)
end

function M.install()
  root()
  _G.TechPriestsBehaviorTreeMonitor0642 = M
  _G.tech_priests_behavior_tree_0642_mark = M.mark
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({ name = "behavior_tree_monitor_0642", category = "diagnostics", interval = M.tick_interval, priority = 990, budget = 10, dynamic_budget = false, fn = function(event, budget) M.service_all("broker") return true end, note = "sample canonical behavior-tree node/phase per station pair" })
  else
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then R.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end, { owner = "behavior_tree_monitor_0642", category = "diagnostics", priority = "late" })
    elseif script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, function() M.service_all("nth-tick") end) end
  end
  if log then log("[Tech-Priests 0.1.642] behavior tree monitor installed; /tp-behavior-tree-0642 shows selected station node, phase, owner, target, item, blocker, and progress age") end
  return true
end

return M
