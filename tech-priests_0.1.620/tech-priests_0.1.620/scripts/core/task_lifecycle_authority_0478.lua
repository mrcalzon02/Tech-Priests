-- scripts/core/task_lifecycle_authority_0478.lua
-- Tech Priests 0.1.478
--
-- Stabilizes incomplete behavior trees seen after 0.1.477:
--   * A priest may hold a gather/mining title while standing by the station.
--   * The mining beam may still fire from the station toward a distant target.
--   * A supplied item may satisfy the writ while older planners keep asking for it.
--
-- This authority does not try to replace the full scheduler.  It enforces the
-- missing lifecycle boundary: distant quarry work must move first, current writs
-- must finish when the station already holds their item, and diagnostics must say
-- which limb of the task tree is currently awake.

local M = {}
M.version = "0.1.478"
M.storage_key = "task_lifecycle_authority_0478"
M.tick_interval = 29
M.close_distance_sq = 4.0
M.move_ttl_ticks = 60 * 8
M.satisfaction_cooldown_ticks = 60

local original_fire_laser = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function dist_sq(a,b) if not (a and b) then return nil end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end
local function enabled() return root().enabled ~= false end
local function stat(name, delta) local r=root(); r.stats[name]=(r.stats[name] or 0)+(delta or 1) end

local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and valid(pair.station) and pair.station.unit_number or nil end

local function pair_for_priest(priest)
  if not (valid(priest) and storage and storage.tech_priests) then return nil end
  local by_priest = storage.tech_priests.pairs_by_priest or {}
  local pair = by_priest[priest.unit_number]
  if valid_pair(pair) then return pair end
  for _, p in pairs(pair_map()) do if valid_pair(p) and p.priest == priest then return p end end
  return nil
end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return pair and (pair.active_order_0469 or (q and q.current)) or nil
end

local function normalize_kind(kind)
  local k = lower(kind)
  if k:find("combat",1,true) or k:find("defend",1,true) or k:find("laser%-fallback") then return "combat" end
  if k:find("repair",1,true) then return "repair" end
  if k:find("consecr",1,true) or k:find("sanct",1,true) then return "consecration" end
  if k:find("assign",1,true) then return "assignment" end
  if k:find("logistic",1,true) or k:find("supply",1,true) then return "logistics" end
  if k:find("scavenge",1,true) then return "scavenge" end
  if k:find("mine",1,true) or k:find("acqui",1,true) or k:find("gather",1,true) or k:find("resource",1,true) then return "acquisition" end
  if k:find("emergency",1,true) or k:find("craft",1,true) then return "emergency_craft" end
  if k == "" then return "idle" end
  return k
end

local low_kinds = { logistics=true, acquisition=true, gather=true, direct_mine=true, scavenge=true, emergency_craft=true, assignment=true }

local function order_item(order)
  if not order then return nil end
  return order.item or order.wanted_item or order.requested_item or order.output_item or order.kind
end

local function entity_position(t)
  if valid(t) then return t.position end
  if type(t)=="table" and t.entity and valid(t.entity) then return t.entity.position end
  if type(t)=="table" and t.x and t.y then return t end
  return nil
end

local function current_target(pair, order)
  if not pair then return nil, nil end
  if order and valid(order.target) then return order.target, order.target.position end
  if pair.emergency_craft then
    local cur = pair.emergency_craft.current or pair.emergency_craft
    if cur then
      if valid(cur.entity) then return cur.entity, cur.entity.position end
      if cur.position then return nil, cur.position end
    end
  end
  if pair.direct_acquisition_task_0336 then
    local cur = pair.direct_acquisition_task_0336.current or pair.direct_acquisition_task_0336
    if cur then
      if valid(cur.entity) then return cur.entity, cur.entity.position end
      if cur.position then return nil, cur.position end
    end
  end
  if pair.scavenge then
    if valid(pair.scavenge.source) then return pair.scavenge.source, pair.scavenge.source.position end
    if valid(pair.scavenge.entity) then return pair.scavenge.entity, pair.scavenge.entity.position end
    if pair.scavenge.position then return nil, pair.scavenge.position end
  end
  if pair.active_task then
    local t = pair.active_task
    if valid(t.target) then return t.target, t.target.position end
    if valid(t.source) then return t.source, t.source.position end
    if t.position then return nil, t.position end
  end
  if valid(pair.target) then return pair.target, pair.target.position end
  if order and order.target then return nil, entity_position(order.target) end
  return nil, nil
end

local function request_move(pair, pos, reason, priority)
  if not (valid_pair(pair) and pos) then return false end
  local ok = false
  if _G.tech_priests_request_movement_0418 then
    local ok_call, result = pcall(_G.tech_priests_request_movement_0418, pair, pos, reason or "task-lifecycle-0478", { radius = 0.75, owner = "task-lifecycle-0478", priority = priority or 640, ttl = M.move_ttl_ticks, distraction = defines and defines.distraction and defines.distraction.by_enemy or nil })
    ok = ok_call and result ~= false
  elseif pair.priest.set_command and defines and defines.command then
    ok = pcall(function() pair.priest.set_command{ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy } end)
  end
  if ok then
    pair.lifecycle_0478 = pair.lifecycle_0478 or {}
    pair.lifecycle_0478.last_move_request_tick = now()
    pair.lifecycle_0478.last_move_reason = reason
    pair.lifecycle_0478.last_move_x = pos.x
    pair.lifecycle_0478.last_move_y = pos.y
    stat("movement_requests")
  end
  return ok
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  local Work = rawget(_G, "TECH_PRIESTS_STATION_WORK_INVENTORY_0358")
  if Work and type(Work.station_item_count)=="function" then
    local ok,c=pcall(Work.station_item_count, pair, item)
    if ok then return tonumber(c) or 0 end
  end
  if pair.station and pair.station.get_inventory and defines and defines.inventory then
    local total=0
    for _,id in ipairs({defines.inventory.chest, defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.furnace_source, defines.inventory.furnace_result, defines.inventory.fuel}) do
      local ok,inv=pcall(function() return pair.station.get_inventory(id) end)
      if ok and inv and inv.valid then local okc,c=pcall(function() return inv.get_item_count(item) end); if okc then total=total+(tonumber(c) or 0) end end
    end
    return total
  end
  return 0
end

local function surface_item_matches(tbl, item)
  if not (type(tbl)=="table" and item) then return false end
  local cur = tbl.current or tbl
  local it = cur.item or cur.item_name or cur.output_item or cur.wanted_item or cur.requested_item or tbl.item or tbl.item_name or tbl.output_item
  return tostring(it or "") == tostring(item)
end

local function clear_matching_low_surfaces(pair, item)
  if not (pair and item) then return end
  if surface_item_matches(pair.emergency_craft, item) then pair.emergency_craft = nil end
  if surface_item_matches(pair.direct_acquisition_task_0336, item) then pair.direct_acquisition_task_0336 = nil end
  if surface_item_matches(pair.scavenge, item) then pair.scavenge = nil end
  if surface_item_matches(pair.active_task, item) then pair.active_task = nil end
  if tostring(pair.logistic_requested_item or "") == tostring(item) then pair.logistic_requested_item = nil end
  if pair.mode and lower(pair.mode):find("gather",1,true) then pair.mode = "returning" end
end

local function pop_next(q)
  if not q then return nil end
  while #(q.pending or {}) > 0 do
    local order = table.remove(q.pending, 1)
    if order and order.key and q.pending_keys then q.pending_keys[order.key] = nil end
    if order and order.key and order.status ~= "complete" and order.status ~= "failed" and order.status ~= "cancelled" then return order end
  end
  return nil
end

local function complete_current(pair, why)
  if not valid_pair(pair) then return false end
  pair.order_queue_0469 = pair.order_queue_0469 or { current = pair.active_order_0469, pending = {}, pending_keys = {}, history = {}, stats = {} }
  local q = pair.order_queue_0469
  q.pending = q.pending or {}
  q.pending_keys = q.pending_keys or {}
  q.history = q.history or {}
  q.stats = q.stats or {}
  local cur = q.current or pair.active_order_0469
  if not cur then return false end
  cur.status = "complete"
  cur.finished_tick = now()
  cur.finish_reason = why or "satisfied-by-station-reliquary"
  q.history = q.history or {}
  q.history[#q.history + 1] = { key = cur.key, kind = cur.kind, item = cur.item, status = "complete", reason = cur.finish_reason, tick = now() }
  while #q.history > 12 do table.remove(q.history, 1) end
  q.current = nil
  pair.active_order_0469 = nil
  local next_order = pop_next(q)
  if next_order then
    next_order.status = "active"
    next_order.activated_tick = now()
    q.current = next_order
    pair.active_order_0469 = next_order
    local oq = rawget(_G, "TECH_PRIESTS_ORDER_QUEUE_0469")
    if oq and type(oq.reactivate_current)=="function" then pcall(oq.reactivate_current, pair, "task-lifecycle-0478-promotion") end
  end
  stat("orders_completed_by_reliquary")
  return true
end

local function satisfy_current_if_stocked(pair)
  if not valid_pair(pair) then return false end
  local order = current_order(pair)
  if not order then return false end
  local kind = normalize_kind(order.kind or order.type or order.source)
  if not low_kinds[kind] then return false end
  local item = order_item(order)
  if not item or item == "none" then return false end
  local need = math.max(1, tonumber(order.count or 1) or 1)
  local have = station_count(pair, item)
  if have < need then return false end
  if pair.lifecycle_0478 and now() < (pair.lifecycle_0478.next_satisfaction_tick or 0) then return false end
  pair.lifecycle_0478 = pair.lifecycle_0478 or {}
  pair.lifecycle_0478.next_satisfaction_tick = now() + M.satisfaction_cooldown_ticks
  pair.lifecycle_0478.last_satisfied_item = item
  pair.lifecycle_0478.last_satisfied_have = have
  clear_matching_low_surfaces(pair, item)
  return complete_current(pair, "reliquary-already-holds-" .. tostring(item))
end

local function enforce_move_before_remote_work(pair)
  if not valid_pair(pair) then return false end
  local order = current_order(pair)
  local kind = normalize_kind(order and (order.kind or order.type or order.source) or pair.mode)
  if not low_kinds[kind] then return false end
  local target, pos = current_target(pair, order)
  if not pos then return false end
  local d2 = dist_sq(pair.priest.position, pos) or 0
  if d2 <= M.close_distance_sq then return false end
  local req = pair.movement_request_0418
  if type(req)=="table" and (not req.expires_tick or req.expires_tick >= now()) then return false end
  return request_move(pair, pos, "task-lifecycle-0478-remote-work", 660)
end

function M.service_pair(pair)
  if not enabled() or not valid_pair(pair) then return false end
  local changed = false
  if satisfy_current_if_stocked(pair) then changed = true end
  if enforce_move_before_remote_work(pair) then changed = true end
  return changed
end

function M.tick_all()
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do pcall(M.service_pair, pair) end
end

local function is_hostile_target(priest, target)
  if not (valid(priest) and valid(target)) then return false end
  if not (target.force and priest.force) then return false end
  if target.force == priest.force then return false end
  local ok, enemy = pcall(function() return priest.force.is_enemy and priest.force.is_enemy(target.force) end)
  return ok and enemy == true
end

local function allow_remote_laser(reason, priest, target)
  local r = lower(reason)
  if r:find("combat",1,true) or r:find("defend",1,true) or r:find("fallback",1,true) or r:find("weapon",1,true) or r:find("point%-blank",1,false) then return true end
  if is_hostile_target(priest, target) then return true end
  local t = valid(target) and tostring(target.type or "") or ""
  if t == "unit" or t == "spider-unit" then return true end
  return false
end

function M.wrap_laser()
  if type(_G.tech_priests_0312_fire_laser) ~= "function" then return false end
  if original_fire_laser then return true end
  original_fire_laser = _G.tech_priests_0312_fire_laser
  _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
    if valid(priest) and valid(target) and not allow_remote_laser(reason, priest, target) then
      local pair = pair_for_priest(priest)
      if valid_pair(pair) then
        local d2 = dist_sq(priest.position, target.position) or 0
        if d2 > M.close_distance_sq then
          request_move(pair, target.position, "task-lifecycle-0478-before-mining-beam", 680)
          pair.lifecycle_0478 = pair.lifecycle_0478 or {}
          pair.lifecycle_0478.remote_beam_suppressed = (pair.lifecycle_0478.remote_beam_suppressed or 0) + 1
          pair.lifecycle_0478.last_suppressed_target = safe(target.name) .. "#" .. safe(target.unit_number or "?")
          pair.lifecycle_0478.last_suppressed_distance = math.sqrt(d2)
          pair.lifecycle_0478.last_suppressed_tick = now()
          stat("remote_beams_suppressed")
          return false
        end
      end
    end
    return original_fire_laser(priest, target, damage, reason, color)
  end
  return true
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") then return false end
  if diag.task_lifecycle_wrapped_0478 then return true end
  local prev = diag.pair_dump_lines
  diag.task_lifecycle_wrapped_0478 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "TASK-LIFECYCLE-0478 BEGIN enabled=" .. safe(r.enabled) .. " completed_by_reliquary=" .. safe(r.stats.orders_completed_by_reliquary or 0) .. " remote_beams_suppressed=" .. safe(r.stats.remote_beams_suppressed or 0) .. " move_requests=" .. safe(r.stats.movement_requests or 0)
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local order = current_order(pair)
        local target, pos = current_target(pair, order)
        local lc = pair.lifecycle_0478 or {}
        local d = pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        lines[#lines+1] = "lifecycle[" .. safe(key) .. "] current=" .. safe(order and order.key or "none") .. " item=" .. safe(order_item(order)) .. " mode=" .. safe(pair.mode) .. " target=" .. safe(target and (target.name .. "#" .. tostring(target.unit_number or "?")) or (pos and ("pos:" .. tostring(pos.x) .. "," .. tostring(pos.y)) or "none")) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil") .. " last_satisfied=" .. safe(lc.last_satisfied_item) .. " remote_suppressed=" .. safe(lc.remote_beam_suppressed or 0)
      end
    end
    lines[#lines+1] = "TASK-LIFECYCLE-0478 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  if not (player and player.valid and storage and storage.tech_priests) then return nil end
  local e = player.selected
  if valid(e) then return (storage.tech_priests.pairs_by_station or {})[e.unit_number] or (storage.tech_priests.pairs_by_priest or {})[e.unit_number] end
  return nil
end

function M.describe(pair)
  local r = root()
  local lines = { "enabled=" .. safe(r.enabled) .. " completed_by_reliquary=" .. safe(r.stats.orders_completed_by_reliquary or 0) .. " remote_beams_suppressed=" .. safe(r.stats.remote_beams_suppressed or 0) .. " movement_requests=" .. safe(r.stats.movement_requests or 0) }
  if pair and valid_pair(pair) then
    local order = current_order(pair)
    local target, pos = current_target(pair, order)
    local d = pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
    local lc = pair.lifecycle_0478 or {}
    lines[#lines+1] = "current=" .. safe(order and order.key or "none") .. " item=" .. safe(order_item(order)) .. " mode=" .. safe(pair.mode)
    lines[#lines+1] = "target=" .. safe(target and (target.name .. "#" .. tostring(target.unit_number or "?")) or (pos and ("pos:" .. tostring(pos.x) .. "," .. tostring(pos.y)) or "none")) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil") .. " move=" .. safe(pair.movement_request_0418 and pair.movement_request_0418.reason or "none")
    lines[#lines+1] = "last-satisfied=" .. safe(lc.last_satisfied_item) .. " have=" .. safe(lc.last_satisfied_have) .. " remote-beam-suppressed=" .. safe(lc.remote_beam_suppressed or 0) .. " last-target=" .. safe(lc.last_suppressed_target)
  end
  return lines
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-task-lifecycle-0478") end end)
  commands.add_command("tp-task-lifecycle-0478", "Tech Priests 0.1.478: inspect/toggle task lifecycle authority. Usage: status|all|on|off|kick", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = root()
    if param == "off" or param == "disable" then r.enabled = false end
    if param == "on" or param == "enable" then r.enabled = true end
    local pair = selected_pair(player)
    if param == "kick" and pair then M.service_pair(pair) end
    if player and player.valid then
      if param == "all" then
        for _, p in pairs(pair_map()) do for _, line in ipairs(M.describe(p)) do player.print("[tp-task-lifecycle-0478] " .. line) end end
      else
        for _, line in ipairs(M.describe(pair)) do player.print("[tp-task-lifecycle-0478] " .. line) end
        if not pair then player.print("[tp-task-lifecycle-0478] select a Cogitator Station or Tech-Priest for pair-local status.") end
      end
    end
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.wrap_laser()
  M.wrap_diagnostics()
  _G.TECH_PRIESTS_TASK_LIFECYCLE_AUTHORITY_0478 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick_all() end, { owner = "task_lifecycle_authority_0478", category = "scheduler", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.tick_all() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.478] task lifecycle authority installed; remote mining beams require movement and stocked writs can complete") end
  return true
end

return M
