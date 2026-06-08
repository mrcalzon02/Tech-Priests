-- scripts/core/task_pair_audit_0498.lua
-- Tech Priests 0.1.498
--
-- Audit / quarantine pass for the current disappearing-priest failure family.
-- This does three things deliberately:
--   1. records every Tech-Priest/Cogitator entity removal and every priest-unit
--      change so the next log can tell us what actually removed the body;
--   2. freezes lower execution surfaces whenever a pair has no valid priest so
--      invisible work cannot keep running against a nil/mobile body;
--   3. prevents legacy direct emergency gathering from treating a different raw
--      source as the requested item.  Copper must come from copper ore. Stone is
--      not copper, coal, ammo, or plate.  The Omnissiah is patient, not gullible.

local M = {}
M.version = "0.1.498"
M.storage_key = "task_pair_audit_0498"
M.tick_interval = 37
M.position_jump_sq = 36 * 36
M.strict_direct_gather = true

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(s) return string.lower(tostring(s or "")) end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() local t = storage and storage.tech_priests; return t and t.pairs_by_station or {} end

local function root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, priest_last = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.strict_direct_gather == nil then r.strict_direct_gather = M.strict_direct_gather end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.priest_last = r.priest_last or {}
  return r
end

local function stat(name, n)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (n or 1)
end

local function pair_station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function pair_priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function pair_rank(pair)
  local n = valid(pair and pair.station) and pair.station.name or tostring(pair and pair.station_name_0495 or pair and pair.station_name or "")
  if tostring(n):find("planetary%-magos", 1, false) then return "planetary-magos" end
  if tostring(n):find("senior", 1, false) then return "senior" end
  if tostring(n):find("intermediate", 1, false) then return "intermediate" end
  if tostring(n):find("junior", 1, false) then return "junior" end
  return tostring(pair and (pair.tier or pair.rank) or "unknown")
end

local function record(action, pair, detail)
  local r = root()
  stat(action)
  local rec = {
    tick = now(),
    action = tostring(action or "event"),
    station = pair_station_unit(pair),
    priest = pair_priest_unit(pair),
    detail = tostring(detail or "")
  }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 42 do table.remove(r.recent, 1) end
  if log then
    log("[Tech-Priests 0.1.498] " .. rec.action .. " station=" .. tostring(rec.station) .. " priest=" .. tostring(rec.priest) .. " " .. rec.detail)
  end
end

local function is_priest_name(name)
  name = tostring(name or "")
  return name:find("tech%-priest", 1, false) ~= nil
end

local function is_station_name(name)
  name = tostring(name or "")
  return name:find("cogitator%-station", 1, false) ~= nil
end

local function is_mod_entity(e)
  return valid(e) and (is_priest_name(e.name) or is_station_name(e.name))
end

local function find_pair_for_entity(e)
  if not valid(e) then return nil end
  local tp = storage and storage.tech_priests or nil
  if tp then
    if tp.pairs_by_priest and e.unit_number and tp.pairs_by_priest[e.unit_number] then return tp.pairs_by_priest[e.unit_number] end
    if tp.pairs_by_station and e.unit_number and tp.pairs_by_station[e.unit_number] then return tp.pairs_by_station[e.unit_number] end
    if tp.station_by_priest and e.unit_number and tp.station_by_priest[e.unit_number] and tp.pairs_by_station then return tp.pairs_by_station[tp.station_by_priest[e.unit_number]] end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.priest == e or pair.station == e or pair.priest_unit == e.unit_number or pair.station_unit == e.unit_number) then return pair end
  end
  return nil
end

local function force_name(f)
  if not f then return "nil" end
  if type(f) == "string" then return f end
  return f.name or tostring(f)
end

local function event_name(event)
  if not event then return "nil" end
  if defines and defines.events then
    for k, v in pairs(defines.events) do if v == event.name then return k end end
  end
  return tostring(event.name)
end

local function describe_entity(e)
  if not valid(e) then return "invalid" end
  local pos = e.position or {}
  return tostring(e.name) .. "#" .. tostring(e.unit_number or "?") .. " type=" .. tostring(e.type) .. " force=" .. force_name(e.force) .. " @" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)
end

local function current_order_summary(pair)
  local q = pair and pair.order_queue_0469 or nil
  local cur = q and q.current or pair and pair.active_order_0469 or nil
  if not cur then return "order=none" end
  return "order=" .. tostring(cur.key or "?") .. " kind=" .. tostring(cur.kind) .. " item=" .. tostring(cur.item)
end

local function active_surface_summary(pair)
  if not pair then return "surface=nil" end
  local t = pair.emergency_craft or pair.active_task or pair.active_task_0285 or pair.scavenge or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333
  if not t then return "lower=none" end
  local item = t.item or t.item_name or t.output_item or t.requested_item or t.name
  local cur = t.current
  local c = cur and (tostring(cur.kind or "?") .. ":" .. tostring(cur.item_name or cur.output_item or (valid(cur.entity) and cur.entity.name) or "?")) or "none"
  return "lower_item=" .. tostring(item) .. " current=" .. c
end

local function entity_proto_type(name)
  if not name then return nil end
  if prototypes and prototypes.entity and prototypes.entity[name] then return prototypes.entity[name].type end
  if game and game.entity_prototypes and game.entity_prototypes[name] then return game.entity_prototypes[name].type end
  return nil
end

local function item_exists(name)
  if not name then return false end
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if game and game.item_prototypes and game.item_prototypes[name] then return true end
  return false
end

local function literal_output_from_candidate(cand)
  if not cand then return nil end
  local e = cand.entity
  if valid(e) then
    if e.type == "resource" then return item_exists(e.name) and e.name or nil end
    if e.type == "tree" then return item_exists("wood") and "wood" or nil end
    if e.type == "simple-entity" or e.type == "simple-entity-with-owner" or e.type == "rock" then return item_exists("stone") and "stone" or nil end
  end
  if cand.kind == "direct-dirt-0273" or cand.kind == "dirt" then return item_exists("stone") and "stone" or nil end
  if item_exists(cand.item_name) then return cand.item_name end
  return nil
end

local function direct_gather_allowed(target, cand)
  if not target then return false, "no-target" end
  local actual = literal_output_from_candidate(cand)
  if not actual then return false, "no-literal-output" end
  if actual == target then return true, "literal-match" end
  -- Direct emergency mining is only literal. Recipe decomposition may ask for
  -- plates, circuits, repair packs, or buildings, but that must go through the
  -- recipe/writ layer, not through rock transmutation.
  return false, "literal-mismatch actual=" .. tostring(actual) .. " wanted=" .. tostring(target)
end

local function clear_lower_work(pair, reason)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({
    "target", "combat_target", "active_task", "active_task_0285", "current_task", "scavenge",
    "inventory_scan", "direct_acquisition_task_0336", "active_acquisition_0333", "emergency_craft",
    "movement_request_0418", "pathing_target_0418"
  }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  pair.paused_by_missing_priest_0498 = { tick = now(), reason = reason or "missing-priest", order = current_order_summary(pair) }
  if pair.order_queue_0469 and pair.order_queue_0469.current then
    pair.order_queue_0469.current.status = "paused-missing-priest"
    pair.order_queue_0469.current.paused_tick = now()
    pair.order_queue_0469.current.pause_reason = reason or "missing-priest"
  end
  return changed
end

local function sanitize_order_queue(pair)
  local q = pair and pair.order_queue_0469 or nil
  if not q then return false end
  local changed = false
  local function bad(order)
    if not order then return false end
    local item = order.item or order.item_name or order.requested_item
    return item == nil or item == "" or item == "none"
  end
  if bad(q.current) then
    q.history = q.history or {}
    q.history[#q.history + 1] = { key = q.current.key, kind = q.current.kind, item = q.current.item, status = "failed", reason = "nil-item-quarantined-0498", tick = now() }
    while #q.history > 16 do table.remove(q.history, 1) end
    record("nil-order-quarantined", pair, tostring(q.current.key))
    q.current = nil
    pair.active_order_0469 = nil
    changed = true
  end
  local keep = {}
  q.pending_keys = q.pending_keys or {}
  for _, order in ipairs(q.pending or {}) do
    if bad(order) then
      record("nil-pending-order-dropped", pair, tostring(order and order.key))
      changed = true
    else
      keep[#keep + 1] = order
      if order.key then q.pending_keys[order.key] = true end
    end
  end
  if changed then q.pending = keep end
  return changed
end

local function repair_reverse_maps(pair, reason)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  local tp = tp_root()
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.link_0498 = pair.link_0498 or {}
  pair.link_0498.last_valid_tick = now()
  pair.link_0498.last_valid_unit = pair.priest.unit_number
  pair.link_0498.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.link_0498.reason = reason or "repair"
  return true
end

local function scan_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  sanitize_order_queue(pair)
  if valid(pair.priest) then
    if pair.paused_by_missing_priest_0498 then
      record("priest-signal-restored", pair, current_order_summary(pair) .. " " .. active_surface_summary(pair))
      pair.paused_by_missing_priest_0498 = nil
    end
    repair_reverse_maps(pair, "audit-scan")
    local r = root()
    local pu = pair.priest.unit_number
    local last = r.priest_last[pu]
    local pos = pair.priest.position
    if last and last.surface == (pair.priest.surface and pair.priest.surface.name or nil) then
      local dx = (pos.x or 0) - (last.x or 0)
      local dy = (pos.y or 0) - (last.y or 0)
      local d = dx * dx + dy * dy
      if d > M.position_jump_sq then
        record("large-position-jump", pair, "from=" .. string.format("%.1f,%.1f", last.x or 0, last.y or 0) .. " to=" .. string.format("%.1f,%.1f", pos.x or 0, pos.y or 0) .. " dist_sq=" .. tostring(math.floor(d)))
      end
    end
    r.priest_last[pu] = { x = pos.x, y = pos.y, surface = pair.priest.surface and pair.priest.surface.name or nil, station = pair.station.unit_number, tick = now() }
    return true
  end
  if not pair.paused_by_missing_priest_0498 then
    record("missing-priest-quarantine", pair, current_order_summary(pair) .. " " .. active_surface_summary(pair))
  end
  clear_lower_work(pair, "missing-priest-quarantine-0498")
  return false
end

function M.service_all()
  local r = root(); if r.enabled == false then return end
  for _, pair in pairs(pair_map()) do scan_pair(pair) end
end

function M.handle_removed(event)
  local e = event and event.entity
  if not is_mod_entity(e) then return false end
  local pair = find_pair_for_entity(e)
  local cause = event and event.cause
  local force = event and event.force
  local detail = event_name(event) .. " entity=" .. describe_entity(e)
    .. " cause=" .. describe_entity(cause)
    .. " force=" .. force_name(force)
    .. " " .. current_order_summary(pair) .. " " .. active_surface_summary(pair)
  record(is_priest_name(e.name) and "priest-entity-removed" or "station-entity-removed", pair, detail)
  if pair and pair.priest == e then
    pair.priest_removed_0498 = { tick = now(), event = event_name(event), entity = describe_entity(e), cause = describe_entity(cause), order = current_order_summary(pair), lower = active_surface_summary(pair) }
  end
  return false
end

function M.patch_direct_gather()
  if type(_G.tech_priests_0273_find_direct_target) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_FIND_DIRECT_TARGET") then
    _G.TECH_PRIESTS_0498_PRE_FIND_DIRECT_TARGET = _G.tech_priests_0273_find_direct_target
    _G.tech_priests_0273_find_direct_target = function(pair, target)
      if not (pair and valid(pair.station) and valid(pair.priest)) then
        record("direct-target-blocked-missing-priest", pair, "target=" .. tostring(target))
        return nil
      end
      local cand = _G.TECH_PRIESTS_0498_PRE_FIND_DIRECT_TARGET(pair, target)
      if not cand then return nil end
      if root().strict_direct_gather ~= false then
        local ok, why = direct_gather_allowed(target, cand)
        if not ok then
          record("direct-target-rejected", pair, "target=" .. tostring(target) .. " source=" .. tostring(cand.item_name or cand.kind) .. " " .. tostring(why))
          return nil
        end
      end
      return cand
    end
  end

  if type(_G.tech_priests_0273_begin_dirt) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_BEGIN_DIRT") then
    _G.TECH_PRIESTS_0498_PRE_BEGIN_DIRT = _G.tech_priests_0273_begin_dirt
    _G.tech_priests_0273_begin_dirt = function(pair, task, target, reason)
      if root().strict_direct_gather ~= false and target ~= "stone" then
        record("dirt-fallback-rejected", pair, "target=" .. tostring(target) .. " reason=" .. tostring(reason))
        if task then
          task.current = nil
          task.candidates = nil
          task.index = nil
          task.scan_due_tick = now() + 180
          task.direct_due_tick_0273 = nil
        end
        return false
      end
      return _G.TECH_PRIESTS_0498_PRE_BEGIN_DIRT(pair, task, target, reason)
    end
  end

  if type(_G.tech_priests_0273_kick_worker) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_KICK_WORKER") then
    _G.TECH_PRIESTS_0498_PRE_KICK_WORKER = _G.tech_priests_0273_kick_worker
    _G.tech_priests_0273_kick_worker = function(pair, reason)
      if not (pair and valid(pair.station) and valid(pair.priest)) then
        record("kick-worker-quarantined-missing-priest", pair, tostring(reason))
        clear_lower_work(pair, "kick-worker-missing-priest-0498")
        return false
      end
      return _G.TECH_PRIESTS_0498_PRE_KICK_WORKER(pair, reason)
    end
  end

  if type(_G.handle_emergency_desperation_craft) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_HANDLE_EMERGENCY_CRAFT") then
    _G.TECH_PRIESTS_0498_PRE_HANDLE_EMERGENCY_CRAFT = _G.handle_emergency_desperation_craft
    _G.handle_emergency_desperation_craft = function(pair)
      if not (pair and valid(pair.station) and valid(pair.priest)) then
        record("emergency-craft-quarantined-missing-priest", pair, current_order_summary(pair) .. " " .. active_surface_summary(pair))
        clear_lower_work(pair, "emergency-craft-missing-priest-0498")
        return false
      end
      return _G.TECH_PRIESTS_0498_PRE_HANDLE_EMERGENCY_CRAFT(pair)
    end
  end
end

function M.patch_respawn_guards()
  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0498_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if pair and valid(pair.priest) and not (pair.reimprint_0298 and pair.reimprint_0298.active) then
        record("valid-priest-respawn-blocked", pair, "reason=" .. tostring(reason) .. " unit=" .. tostring(pair.priest.unit_number) .. " " .. current_order_summary(pair))
        repair_reverse_maps(pair, "blocked-valid-respawn-0498")
        return true
      end
      local before = pair_priest_unit(pair)
      local ok = _G.TECH_PRIESTS_0498_PRE_RESPAWN_PAIR_PRIEST(pair, reason)
      local after = pair_priest_unit(pair)
      record(ok and "respawn-result" or "respawn-failed", pair, "reason=" .. tostring(reason) .. " before=" .. tostring(before) .. " after=" .. tostring(after))
      if ok and valid(pair and pair.priest) then repair_reverse_maps(pair, "respawn-0498") end
      return ok
    end
  end

  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0498_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0498_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      local before = pair_priest_unit(pair)
      local ok = _G.TECH_PRIESTS_0498_PRE_ENSURE_PAIR_PRIEST(pair, force_recall, immediate)
      local after = pair_priest_unit(pair)
      if before ~= after then record("ensure-priest-unit-changed", pair, "force=" .. tostring(force_recall) .. " immediate=" .. tostring(immediate) .. " before=" .. tostring(before) .. " after=" .. tostring(after)) end
      if ok and valid(pair and pair.priest) then repair_reverse_maps(pair, "ensure-0498") end
      return ok
    end
  end
end

function M.patch_direct_safety_rescue()
  local safety = rawget(_G, "TechPriestsDirectMiningSafety0490")
  if safety and type(safety.rescue_missing_priests) == "function" and not safety.rescue_delegated_0498 then
    safety.rescue_delegated_0498 = true
    local prev = safety.rescue_missing_priests
    safety.rescue_missing_priests = function()
      record("direct-safety-rescue-delegated", nil, "0490 rescue delegated to pair-link/audit authority")
      local link = rawget(_G, "TechPriestsPairLinkHardening0495")
      if link and type(link.service_all) == "function" then return link.service_all() end
      return prev()
    end
  end
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.task_pair_audit_wrapped_0498 then return false end
  local prev = diag.pair_dump_lines
  diag.task_pair_audit_wrapped_0498 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "PAIR-DUMP-0468 TASK-PAIR-AUDIT-0498 BEGIN enabled=" .. tostring(r.enabled)
      .. " strict_direct=" .. tostring(r.strict_direct_gather)
      .. " removed=" .. tostring(r.stats["priest-entity-removed"] or 0)
      .. " quarantined=" .. tostring((r.stats["missing-priest-quarantine"] or 0) + (r.stats["kick-worker-quarantined-missing-priest"] or 0) + (r.stats["emergency-craft-quarantined-missing-priest"] or 0))
      .. " rejected_direct=" .. tostring((r.stats["direct-target-rejected"] or 0) + (r.stats["dirt-fallback-rejected"] or 0))
      .. " blocked_respawn=" .. tostring(r.stats["valid-priest-respawn-blocked"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        lines[#lines+1] = "PAIR-DUMP-0468 audit0498[pair " .. tostring(pair_station_unit(pair)) .. "] rank=" .. pair_rank(pair)
          .. " priest=" .. tostring(valid(pair.priest) and (pair.priest.name .. "#" .. tostring(pair.priest.unit_number)) or "invalid")
          .. " " .. current_order_summary(pair) .. " " .. active_surface_summary(pair)
          .. " removed=" .. tostring(pair.priest_removed_0498 and pair.priest_removed_0498.event or "nil")
          .. " paused=" .. tostring(pair.paused_by_missing_priest_0498 and pair.paused_by_missing_priest_0498.reason or "nil")
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 audit0498[" .. tostring(i) .. "] tick=" .. tostring(ev.tick) .. " action=" .. tostring(ev.action) .. " station=" .. tostring(ev.station) .. " priest=" .. tostring(ev.priest) .. " " .. tostring(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 TASK-PAIR-AUDIT-0498 END"
    return lines
  end
  return true
end

function M.register_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "task_pair_audit_0498", category = "pair-lifecycle", priority = "last" })
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "task_pair_audit_0498", category = "pair-lifecycle", priority = "last" })
  elseif script then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-task-pair-audit-0498") end end)
  commands.add_command("tp-task-pair-audit-0498", "Tech Priests 0.1.498: task/pair state audit. Usage: status|all|on|off|strict-on|strict-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = tostring(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "strict-on" then r.strict_direct_gather = true end
    if p == "strict-off" then r.strict_direct_gather = false end
    if p == "all" then M.service_all() end
    if player and player.valid then
      player.print("[tp-task-pair-audit-0498] enabled=" .. tostring(r.enabled)
        .. " strict_direct=" .. tostring(r.strict_direct_gather)
        .. " removed=" .. tostring(r.stats["priest-entity-removed"] or 0)
        .. " rejected_direct=" .. tostring((r.stats["direct-target-rejected"] or 0) + (r.stats["dirt-fallback-rejected"] or 0))
        .. " blocked_respawn=" .. tostring(r.stats["valid-priest-respawn-blocked"] or 0))
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  _G.TechPriestsTaskPairAudit0498 = M
  M.patch_direct_gather()
  M.patch_respawn_guards()
  M.patch_direct_safety_rescue()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.498] task/pair audit installed; missing priests quarantine work and direct gathering is literal-only") end
  return true
end

return M
