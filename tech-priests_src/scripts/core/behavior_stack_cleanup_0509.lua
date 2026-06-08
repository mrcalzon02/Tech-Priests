-- scripts/core/behavior_stack_cleanup_0509.lua
-- Tech Priests 0.1.509
--
-- Second legacy cleanup pass.  0.1.508 proved that valid-priest recall was mostly
-- suppressed, but the live log still showed native units becoming invalid during
-- movement and the old 0.1.502 station-side quarantine continuing to deposit
-- resources from afar.  This module decommissions that quarantine as an executor,
-- routes direct acquisition through the physical executor again, and debounces
-- debug/overview order refreshes so they cannot reset active work every time the
-- UI or mouse-over logic twitches.

local M = {}
M.version = "0.1.509"
M.storage_key = "behavior_stack_cleanup_0509"
M.close_distance_sq = 2.25      -- 1.5 tiles: close enough to begin visible work
M.travel_reissue_ticks = 120    -- do not spam command refreshes every pulse
M.refresh_debounce_ticks = 600  -- debug/UI refreshes should not reset active work every second
M.cascade_debounce_ticks = 900
M.log_interval = 300

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["dirt"] = true,
  ["direct-mine-0336"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    decommission_0502_executor = true,
    physical_direct = true,
    refresh_debounce = true,
    cascade_debounce = true,
    stats = {},
    recent = {},
    last_log = {},
    last_travel = {},
    last_refresh = {},
    last_cascade = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.decommission_0502_executor == nil then r.decommission_0502_executor = true end
  if r.physical_direct == nil then r.physical_direct = true end
  if r.refresh_debounce == nil then r.refresh_debounce = true end
  if r.cascade_debounce == nil then r.cascade_debounce = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  r.last_travel = r.last_travel or {}
  r.last_refresh = r.last_refresh or {}
  r.last_cascade = r.last_cascade or {}
  return r
end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function record(action, pair, detail, force)
  local r = M.root()
  action = tostring(action or "event")
  stat(action)
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 128 do table.remove(r.recent, 1) end
  local key = action .. ":" .. safe(rec.station)
  local last = r.last_log[key] or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.509] " .. action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. safe(detail)) end
  end
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = task and (task.current or task) or nil
    if cur and DIRECT_KINDS[tostring(cur.kind or "")] then return task, cur end
  end
  return nil, nil
end

local function target_position(pair, cur)
  if cur and valid(cur.entity) then return cur.entity.position end
  if cur and valid(cur.target) then return cur.target.position end
  if cur and valid(cur.source) then return cur.source.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end

local function target_name(cur)
  local e = target_entity(cur)
  if e then return e.name end
  return cur and (cur.item_name or cur.output_item or cur.wanted_item or cur.kind) or "nil"
end

local function clear_direct_due(task)
  if not task then return end
  task.direct_due_tick_0273 = nil
  task.direct_due_tick_0312 = nil
  task.direct_due_tick_0315 = nil
  task.direct_due_tick_0336 = nil
  task.next_direct_laser_tick_0315 = nil
  task.direct_last_visual_tick_0306 = nil
  task.direct_last_visual_tick_0336 = nil
end

local function repair_reverse_maps(pair, reason)
  if not valid_pair(pair) then return false end
  storage.tech_priests = storage.tech_priests or {}
  local tp = storage.tech_priests
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  pair.priest_name = pair.priest.name
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.lifecycle_0509 = pair.lifecycle_0509 or {}
  pair.lifecycle_0509.last_valid_tick = now()
  pair.lifecycle_0509.last_valid_reason = tostring(reason or "valid")
  pair.lifecycle_0509.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function request_movement(pair, pos, reason)
  if not (valid_pair(pair) and pos) then return false end
  clear_direct_due(select(1, current_direct_task(pair)))
  pair.mode = "travelling-to-direct-acquisition"
  local _, cur = current_direct_task(pair)
  pair.target = target_entity(cur)
  pair.remote_direct_blocked_0505 = nil
  pair.station_side_acquisition_0502 = nil
  pair.movement_controller_reason_0418 = "physical-direct-0509"
  if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "movement", "behavior_stack_cleanup_0509", reason or "physical-direct") end
  local ok = false
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      ok = _G.tech_priests_request_movement_0418(pair, pos, "physical-direct-acquisition-0509", { radius = 0.75, owner = "physical-direct-acquisition-0509", priority = 150, ttl = 60 * 10, distraction = defines.distraction.none })
    elseif pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.none })
      ok = true
    elseif pair.priest.set_command then
      pair.priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.none })
      ok = true
    end
  end)
  return ok
end

function M.hold_or_route_direct(pair, task, reason)
  local r = M.root()
  if r.enabled == false or r.physical_direct == false then return false end
  if not valid_pair(pair) then return false end
  repair_reverse_maps(pair, "direct-route-0509")
  local found_task, cur = current_direct_task(pair)
  task = task or found_task
  if not (task and cur) then return false end
  local pos = target_position(pair, cur)
  if not pos then return false end
  local d2 = dist_sq(pair.priest.position, pos) or 0
  if d2 <= M.close_distance_sq then
    stat("physical-direct-adjacent-0509")
    -- Adjacent means the original physical executor may run.  Do not station-side
    -- deposit here; do not return true.
    return false
  end
  local key = tostring(station_unit(pair) or "nil")
  local last = r.last_travel[key] or -1000000
  if now() - last >= M.travel_reissue_ticks then
    r.last_travel[key] = now()
    request_movement(pair, pos, reason or "direct")
    record("physical-direct-travel-0509", pair, "target=" .. safe(target_name(cur)) .. " dist=" .. safe(string.format("%.1f", math.sqrt(d2))) .. " reason=" .. safe(reason))
  else
    stat("physical-direct-held-0509")
    pair.mode = "travelling-to-direct-acquisition"
  end
  return true
end

local function decommission_0502()
  local g = rawget(_G, "TechPriestsPriestVanishGuard0502")
  if not g then return false end
  local ok, r = pcall(function()
    if type(g.root) == "function" then return g.root() end
    return storage and storage.tech_priests and storage.tech_priests.priest_vanish_guard_0502 or nil
  end)
  if ok and r then
    r.station_side_direct_acquisition = false
    r.suppress_far_acquisition_movement = false
    r.tether_visible_priest = false
    r.log_station_side_working = false
    r.log_movement_suppression = false
  end
  if not g.decommissioned_0509 then
    g.decommissioned_0509 = true
    g.TECH_PRIESTS_0509_PRE_SERVICE_PAIR = g.service_pair
    g.TECH_PRIESTS_0509_PRE_SERVICE_ALL = g.service_all
    g.service_pair = function(pair)
      -- 0.1.502/0504 remains diagnostic only. It may report missing priests, but
      -- it must not tether valid priests or perform remote station-side work.
      if pair and valid(pair.station) and not valid(pair.priest) and type(g.TECH_PRIESTS_0509_PRE_SERVICE_PAIR) == "function" then
        return g.TECH_PRIESTS_0509_PRE_SERVICE_PAIR(pair)
      end
      return false
    end
    g.service_all = function() return false end
    record("station-side-0502-decommissioned-0509", nil, "0502 no longer owns movement or deposits", true)
  end
  return true
end

local function wrap_direct_globals()
  local function wrap(name)
    local current = _G[name]
    if type(current) ~= "function" or rawget(_G, "TECH_PRIESTS_0509_PRE_" .. string.upper(name)) then return end
    _G["TECH_PRIESTS_0509_PRE_" .. string.upper(name)] = current
    local original_before_station_side = rawget(_G, "TECH_PRIESTS_0502_PRE_" .. string.upper(name))
    _G[name] = function(pair, task, ...)
      if M.hold_or_route_direct(pair, task, name) then return true end
      if type(original_before_station_side) == "function" then return original_before_station_side(pair, task, ...) end
      return current(pair, task, ...)
    end
  end
  wrap("tech_priests_0273_service_direct_current")
  wrap("tech_priests_0312_service_direct_current")
  wrap("tech_priests_0315_service_direct_current")

  if type(_G.handle_emergency_desperation_craft) == "function" and not rawget(_G, "TECH_PRIESTS_0509_PRE_HANDLE_EMERGENCY_CRAFT") then
    local current = _G.handle_emergency_desperation_craft
    _G.TECH_PRIESTS_0509_PRE_HANDLE_EMERGENCY_CRAFT = current
    _G.handle_emergency_desperation_craft = function(pair, ...)
      if M.hold_or_route_direct(pair, nil, "handle-emergency-craft") then return true end
      return current(pair, ...)
    end
  end
end

local function wrap_acquisition_executor()
  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if not (ok and Exec and type(Exec.service_pair) == "function") or Exec.behavior_stack_cleanup_0509_wrapped then return false end
  Exec.behavior_stack_cleanup_0509_wrapped = true
  Exec.TECH_PRIESTS_0509_PRE_SERVICE_PAIR = Exec.service_pair
  local original_before_station_side = Exec.TECH_PRIESTS_0502_PRE_SERVICE_PAIR
  Exec.service_pair = function(pair, reason)
    if M.hold_or_route_direct(pair, nil, reason or "acquisition-executor") then return true end
    if type(original_before_station_side) == "function" then return original_before_station_side(pair, reason) end
    return Exec.TECH_PRIESTS_0509_PRE_SERVICE_PAIR(pair, reason)
  end
  return true
end

local function active_work(pair)
  if not pair then return false end
  local mode = tostring(pair.mode or "")
  if mode == "travelling-to-direct-acquisition" or mode == "emergency-gathering" or mode == "moving-to-scavenge" or mode == "returning-to-station-for-craft" or mode == "emergency-crafting" or mode == "crafting" then return true end
  local task, cur = current_direct_task(pair)
  if task and cur then return true end
  if pair.emergency_craft and (pair.emergency_craft.station_craft_pending_0337 or pair.emergency_craft.craft_due_tick or pair.emergency_craft.current) then return true end
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "active" then return true end
  return false
end

local function wrap_order_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0509_PRE_REFRESH_ORDERS") then return false end
  local prev = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0509_PRE_REFRESH_ORDERS = prev
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local r = M.root()
    source = tostring(source or "unknown")
    local passive = source == "mouse-over" or source == "radar-priest-scan" or source == "overview-ui" or source:find("overview", 1, true)
    if r.enabled ~= false and r.refresh_debounce ~= false and passive and valid_pair(pair) and active_work(pair) then
      local key = tostring(station_unit(pair) or "nil") .. ":" .. source
      local last = r.last_refresh[key] or -1000000
      if now() - last < M.refresh_debounce_ticks then
        stat("order-refresh-suppressed-0509")
        return false
      end
      r.last_refresh[key] = now()
    end
    return prev(pair, source, ...)
  end
  return true
end

local function wrap_cascade()
  local ok, Cascade = pcall(require, "scripts.core.emergency_cascade")
  if not (ok and Cascade and type(Cascade.cascade_from) == "function") or Cascade.behavior_stack_cleanup_0509_wrapped then return false end
  Cascade.behavior_stack_cleanup_0509_wrapped = true
  Cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM = Cascade.cascade_from
  Cascade.cascade_from = function(leader, reason)
    local r = M.root()
    if r.enabled ~= false and r.cascade_debounce ~= false and leader and valid(leader.station) then
      local key = tostring(station_unit(leader) or "nil") .. ":" .. tostring(reason or "")
      local last = r.last_cascade[key] or -1000000
      if now() - last < M.cascade_debounce_ticks then
        record("cascade-suppressed-0509", leader, "reason=" .. safe(reason))
        return 0
      end
      r.last_cascade[key] = now()
    end
    return Cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM(leader, reason)
  end
  return true
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.behavior_stack_cleanup_0509_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.behavior_stack_cleanup_0509_wrapped = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-STACK-CLEANUP-0509 BEGIN enabled=" .. safe(r.enabled)
      .. " decommission0502=" .. safe(r.decommission_0502_executor)
      .. " physical_direct=" .. safe(r.physical_direct)
      .. " refresh_suppressed=" .. safe(r.stats["order-refresh-suppressed-0509"] or 0)
      .. " travel=" .. safe(r.stats["physical-direct-travel-0509"] or 0)
      .. " held=" .. safe(r.stats["physical-direct-held-0509"] or 0)
      .. " adjacent=" .. safe(r.stats["physical-direct-adjacent-0509"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local _, cur = current_direct_task(pair)
        local pos = target_position(pair, cur)
        local d = valid(pair.priest) and pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 bs0509[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair))
          .. " valid=" .. safe(valid(pair.priest))
          .. " mode=" .. safe(pair.mode)
          .. " direct=" .. safe(cur and cur.kind or "nil")
          .. " target=" .. safe(target_name(cur))
          .. " target_dist=" .. safe(d and string.format("%.1f", d) or "nil")
          .. " move_owner=" .. safe(pair.movement_request_0418 and pair.movement_request_0418.owner or "nil")
      end
    end
    for i = math.max(1, #r.recent - 10), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 bs0509.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-STACK-CLEANUP-0509 END"
    return lines
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local tp = storage and storage.tech_priests or nil
  if selected and selected.valid and tp then
    if tp.pairs_by_station and tp.pairs_by_station[selected.unit_number] then return tp.pairs_by_station[selected.unit_number] end
    if tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number] then return tp.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-cleanup-0509") end end)
  commands.add_command("tp-behavior-cleanup-0509", "Tech Priests 0.1.509: behavior stack cleanup status. Params: on/off/all/refresh-on/refresh-off/direct-on/direct-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "refresh-on" then r.refresh_debounce = true end
    if p == "refresh-off" then r.refresh_debounce = false end
    if p == "direct-on" then r.physical_direct = true end
    if p == "direct-off" then r.physical_direct = false end
    if p == "all" then M.service_all() end
    local pair = selected_pair(player)
    local msg = "[tp-behavior-cleanup-0509] enabled=" .. safe(r.enabled)
      .. " decommission0502=" .. safe(r.decommission_0502_executor)
      .. " physical_direct=" .. safe(r.physical_direct)
      .. " refresh_suppressed=" .. safe(r.stats["order-refresh-suppressed-0509"] or 0)
      .. " travel=" .. safe(r.stats["physical-direct-travel-0509"] or 0)
      .. " held=" .. safe(r.stats["physical-direct-held-0509"] or 0)
    if pair then
      local _, cur = current_direct_task(pair)
      msg = msg .. "\nselected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " valid=" .. safe(valid(pair.priest)) .. " mode=" .. safe(pair.mode) .. " direct=" .. safe(cur and cur.kind or "nil") .. " target=" .. safe(target_name(cur))
    end
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.service_all()
  if M.root().enabled == false then return false end
  decommission_0502()
  wrap_acquisition_executor()
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      repair_reverse_maps(pair, "service-0509")
      M.hold_or_route_direct(pair, nil, "service-0509")
    end
  end
  return true
end

function M.install()
  M.root()
  decommission_0502()
  wrap_direct_globals()
  wrap_acquisition_executor()
  wrap_order_refresh()
  wrap_cascade()
  wrap_pair_dump()
  install_commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(53, function() M.service_all() end, { owner = "behavior_stack_cleanup_0509", category = "authority", note = "decommission 0502 station-side executor; keep direct work physical" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(53, function() M.service_all() end)
  end
  _G.TechPriestsBehaviorStackCleanup0509 = M
  if log then log("[Tech-Priests 0.1.509] behavior stack cleanup installed; 0502 station-side executor disabled, direct acquisition routed through physical movement, UI refreshes debounced") end
  return true
end

return M
