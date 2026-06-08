-- scripts/core/movement_bounds_contract_0511.lua
-- Tech Priests 0.1.511
--
-- Dispatcher follow-up: make outbound direct acquisition bounded and explainable.
-- 0.1.510 proved that dispatcher ownership helps, but the Planetary Magos could
-- still accept an old legacy direct-gather target far outside a sensible work
-- envelope and run into the wilds. This module turns direct acquisition movement
-- into a bounded travel contract: choose a local target, walk to it, work only
-- when adjacent, and return rather than chase unbounded fallback candidates.

local M = {}
M.version = "0.1.511"
M.storage_key = "movement_bounds_contract_0511"
M.log_interval = 600
M.service_interval = 47

-- These values are intentionally conservative while direct acquisition is being
-- migrated. Planetary Magi should coordinate and delegate more than personally
-- sprint into the wilderness. Subordinates may forage a little farther.
M.default_direct_radius = 32
M.default_hard_leash = 48
M.direct_radius_by_tier = {
  ["planetary-magos"] = 24,
  ["planetary_magos"] = 24,
  ["planetary"] = 24,
  ["senior"] = 32,
  ["intermediate"] = 34,
  ["junior"] = 36,
}
M.hard_leash_by_tier = {
  ["planetary-magos"] = 36,
  ["planetary_magos"] = 36,
  ["planetary"] = 36,
  ["senior"] = 48,
  ["intermediate"] = 52,
  ["junior"] = 56,
}
M.direct_kinds = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["dirt"] = true,
  ["direct-mine-0336"] = true,
}
M.direct_reason_needles = {
  "direct", "acquisition", "gather", "mine", "emergency", "physical-direct", "legacy-direct"
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a,b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx*dx + dy*dy
end
local function dist(a,b) local d2 = dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    bound_direct_targets = true,
    bound_direct_movement = true,
    decommission_legacy_direct_nth_guard = true,
    return_overleashed_priests = true,
    stats = {}, recent = {}, last_log = {}, blocked_targets = {}, last_return = {}, removed_routes = 0,
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.bound_direct_targets == nil then r.bound_direct_targets = true end
  if r.bound_direct_movement == nil then r.bound_direct_movement = true end
  if r.decommission_legacy_direct_nth_guard == nil then r.decommission_legacy_direct_nth_guard = true end
  if r.return_overleashed_priests == nil then r.return_overleashed_priests = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}; r.blocked_targets = r.blocked_targets or {}; r.last_return = r.last_return or {}
  return r
end

local function stat(k, n) local r = M.root(); r.stats[k] = (r.stats[k] or 0) + (n or 1) end
local function record(action, pair, detail, force)
  local r = M.root(); action = tostring(action or "event")
  stat(action)
  local rec = { tick = now(), action = action, station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent+1] = rec; while #r.recent > 160 do table.remove(r.recent, 1) end
  local key = action .. ":" .. safe(rec.station)
  local last = r.last_log[key] or -1000000
  if force or now() - last >= M.log_interval then
    r.last_log[key] = now()
    if log then log("[Tech-Priests 0.1.511] " .. action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. safe(detail)) end
  end
  return rec
end

local function tier_key(pair)
  local t = lower(pair and (pair.tier or pair.rank or pair.station_tier or pair.priest_name or (valid(pair.station) and pair.station.name) or ""))
  if t:find("planetary", 1, true) or t:find("magos", 1, true) then return "planetary-magos" end
  if t:find("senior", 1, true) then return "senior" end
  if t:find("intermediate", 1, true) then return "intermediate" end
  if t:find("junior", 1, true) then return "junior" end
  return "default"
end

local function radius_from_runtime(pair)
  local r = tonumber(pair and pair.radius) or nil
  if _G.refresh_pair_radius and pair then local ok, got = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(got) then r = tonumber(got) end end
  if (not r) and _G.get_station_operating_radius and valid(pair and pair.station) then local ok, got = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(got) then r = tonumber(got) end end
  return r
end

function M.direct_radius(pair)
  local key = tier_key(pair)
  local max_for_tier = M.direct_radius_by_tier[key] or M.default_direct_radius
  local runtime = radius_from_runtime(pair) or max_for_tier
  -- Never expand above the role cap in this pass; we are debugging runaway travel.
  return math.max(8, math.min(runtime, max_for_tier))
end

function M.hard_leash(pair)
  local key = tier_key(pair)
  local cap = M.hard_leash_by_tier[key] or M.default_hard_leash
  local runtime = radius_from_runtime(pair) or cap
  return math.max(M.direct_radius(pair) + 6, math.min(math.max(runtime, M.direct_radius(pair) + 6), cap))
end

local function current_direct_task(pair)
  if not pair then return nil, nil end
  for _, key in ipairs({"emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333"}) do
    local task = pair[key]
    local cur = task and (task.current or task) or nil
    if cur and M.direct_kinds[tostring(cur.kind or "")] then return task, cur end
  end
  return nil, nil
end

local function target_entity(cur)
  if cur and valid(cur.entity) then return cur.entity end
  if cur and valid(cur.target) then return cur.target end
  if cur and valid(cur.source) then return cur.source end
  return nil
end
local function target_position(pair, cur)
  local e = target_entity(cur); if e then return e.position end
  if cur and cur.position then return cur.position end
  if pair and valid(pair.target) then return pair.target.position end
  return nil
end
local function target_label(cur)
  local e = target_entity(cur); if e then return safe(e.name) .. "#" .. safe(e.unit_number or "?") end
  return safe(cur and (cur.output_item or cur.item_name or cur.wanted_item or cur.kind) or "nil")
end

local function is_direct_reason(reason, opts)
  local s = lower(reason or "") .. " " .. lower(opts and opts.owner or "")
  for _, n in ipairs(M.direct_reason_needles) do if s:find(n, 1, true) then return true end end
  return false
end

local function station_distance(pair, pos)
  return valid(pair and pair.station) and pos and dist(pair.station.position, pos) or nil
end

function M.target_within_bounds(pair, pos)
  if not (valid(pair and pair.station) and pos) then return true, nil, nil end
  -- 0.1.574: direct-acquisition movement may be outside the home station
  -- radius only when an active authority corridor writ allows the destination.
  -- The pathing guard still owns rejection/decomposition; this older direct
  -- bounds contract must not pre-empt authorized superior-corridor movement.
  if type(_G.tech_priests_0574_position_allowed) == "function" then
    local ok_call, allowed = pcall(_G.tech_priests_0574_position_allowed, pair, pos, "movement-bounds-0511", { owner = "movement-bounds-0511" })
    if ok_call and allowed then return true, nil, nil end
  end
  local d = station_distance(pair, pos) or 0
  local maxd = M.direct_radius(pair)
  return d <= maxd, d, maxd
end

local function clear_current_direct(pair, reason)
  local task, cur = current_direct_task(pair)
  if task and cur then
    task.current = nil
    task.direct_due_tick_0273 = nil; task.direct_due_tick_0312 = nil; task.direct_due_tick_0315 = nil; task.direct_due_tick_0336 = nil
    task.scan_due_tick = nil
    pair.target = nil
    pair.movement_request_0418 = nil
    pair.movement_mode = nil
    pair.mode = "direct-acquisition-target-rejected"
    pair.direct_target_rejected_0511 = { tick = now(), reason = tostring(reason or "out-of-bounds"), target = target_label(cur) }
    return true
  end
  return false
end

function M.return_to_station_if_overleashed(pair, reason)
  local r = M.root()
  if r.enabled == false or r.return_overleashed_priests == false then return false end
  if not valid_pair(pair) then return false end
  local d = dist(pair.priest.position, pair.station.position) or 0
  local maxd = M.hard_leash(pair)
  if d <= maxd then return false end
  local key = tostring(station_unit(pair) or "nil")
  local last = r.last_return[key] or -1000000
  if now() - last < 180 then return true end
  r.last_return[key] = now()
  record("overleash-return-0511", pair, "dist=" .. safe(string.format("%.1f", d)) .. " max=" .. safe(maxd) .. " reason=" .. safe(reason))
  pcall(function()
    if _G.tech_priests_request_movement_0418 then
      _G.tech_priests_request_movement_0418(pair, pair.station.position, "overleash-return-0511", { radius = 1.0, owner = "movement-bounds-0511", priority = 760, ttl = 600, distraction = defines.distraction.none })
    elseif pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.go_to_location, destination = pair.station.position, radius = 1.0, distraction = defines.distraction.none })
    else
      pair.priest.set_command({ type = defines.command.go_to_location, destination = pair.station.position, radius = 1.0, distraction = defines.distraction.none })
    end
  end)
  pair.mode = "returning-overleash-0511"
  pair.target = pair.station
  return true
end

function M.sanitize_direct_target(pair, reason)
  local r = M.root()
  if r.enabled == false or r.bound_direct_targets == false then return false end
  local task, cur = current_direct_task(pair)
  if not (valid_pair(pair) and task and cur) then return false end
  local pos = target_position(pair, cur)
  if not pos then return false end
  local ok, d, maxd = M.target_within_bounds(pair, pos)
  if ok then return false end
  local detail = "target=" .. target_label(cur) .. " dist=" .. safe(string.format("%.1f", d or 0)) .. " max=" .. safe(maxd) .. " reason=" .. safe(reason)
  r.blocked_targets[safe(station_unit(pair))] = { tick = now(), target = target_label(cur), dist = d, max = maxd, reason = tostring(reason or "sanitize") }
  clear_current_direct(pair, detail)
  record("direct-target-rejected-0511", pair, detail)
  M.return_to_station_if_overleashed(pair, "target-rejected")
  return true
end

local function wrap_target_finder()
  if type(_G.tech_priests_0273_find_direct_target) ~= "function" or rawget(_G, "TECH_PRIESTS_0511_PRE_FIND_DIRECT_TARGET") then return false end
  local prev = _G.tech_priests_0273_find_direct_target
  _G.TECH_PRIESTS_0511_PRE_FIND_DIRECT_TARGET = prev
  _G.tech_priests_0273_find_direct_target = function(pair, output, ...)
    local cand = prev(pair, output, ...)
    local r = M.root()
    if r.enabled == false or r.bound_direct_targets == false then return cand end
    if cand then
      local pos = target_position(pair, cand)
      local ok, d, maxd = M.target_within_bounds(pair, pos)
      if not ok then
        r.blocked_targets[safe(station_unit(pair))] = { tick = now(), target = target_label(cand), dist = d, max = maxd, reason = "finder" }
        record("finder-target-rejected-0511", pair, "output=" .. safe(output) .. " target=" .. target_label(cand) .. " dist=" .. safe(string.format("%.1f", d or 0)) .. " max=" .. safe(maxd))
        return nil
      end
    end
    return cand
  end
  return true
end

local function wrap_movement_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" or rawget(_G, "TECH_PRIESTS_0511_PRE_REQUEST_MOVEMENT_0418") then return false end
  local prev = _G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0511_PRE_REQUEST_MOVEMENT_0418 = prev
  _G.tech_priests_request_movement_0418 = function(pair, pos, reason, opts, ...)
    local r = M.root()
    if r.enabled ~= false and r.bound_direct_movement ~= false and valid_pair(pair) and pos and is_direct_reason(reason, opts) and lower(opts and opts.owner or "") ~= "movement-bounds-0511" then
      local ok, d, maxd = M.target_within_bounds(pair, pos)
      if not ok then
        record("movement-target-rejected-0511", pair, "dist=" .. safe(string.format("%.1f", d or 0)) .. " max=" .. safe(maxd) .. " reason=" .. safe(reason) .. " owner=" .. safe(opts and opts.owner))
        M.sanitize_direct_target(pair, "movement-request")
        M.return_to_station_if_overleashed(pair, "movement-target-rejected")
        return false
      end
    end
    return prev(pair, pos, reason, opts, ...)
  end
  return true
end

local function wrap_acquisition_executor()
  local ok, Exec = pcall(require, "scripts.core.acquisition_executor")
  if not (ok and Exec and type(Exec.service_pair) == "function") or Exec.movement_bounds_0511_wrapped then return false end
  Exec.movement_bounds_0511_wrapped = true
  Exec.TECH_PRIESTS_0511_PRE_SERVICE_PAIR = Exec.service_pair
  Exec.service_pair = function(pair, reason, ...)
    if M.sanitize_direct_target(pair, reason or "acquisition-executor") then return false, "target-out-of-bounds-0511" end
    M.return_to_station_if_overleashed(pair, reason or "acquisition-executor")
    return Exec.TECH_PRIESTS_0511_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

local function wrap_legacy_direct_functions()
  local function wrap(name)
    local fn = _G[name]
    if type(fn) ~= "function" or rawget(_G, "TECH_PRIESTS_0511_PRE_" .. string.upper(name)) then return end
    _G["TECH_PRIESTS_0511_PRE_" .. string.upper(name)] = fn
    _G[name] = function(pair, task, ...)
      if M.sanitize_direct_target(pair, name) then return true end
      M.return_to_station_if_overleashed(pair, name)
      return fn(pair, task, ...)
    end
  end
  wrap("tech_priests_0273_service_direct_current")
  wrap("tech_priests_0312_service_direct_current")
  wrap("tech_priests_0315_service_direct_current")
end

local function decommission_legacy_direct_nth_guard()
  local r = M.root()
  if r.enabled == false or r.decommission_legacy_direct_nth_guard == false or r.route_decommissioned then return false end
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local route = R and R.nth_tick_routes and R.nth_tick_routes["61"]
  if type(route) ~= "table" then return false end
  local kept, removed = {}, 0
  for _, entry in ipairs(route) do
    local src = tostring(entry.source or "")
    local line = tonumber(entry.line or 0) or 0
    -- This is the old 0.1.273 one-second hard direct-gather kick in generated
    -- control part 016. It bypasses the dispatcher by selecting/servicing a new
    -- target every 61 ticks. Leave other 61-tick legacy helpers in place for now.
    if src:find("control_legacy_part_016.lua", 1, true) and line >= 820 and line <= 850 then
      removed = removed + 1
    else
      kept[#kept+1] = entry
    end
  end
  if removed > 0 then
    R.nth_tick_routes["61"] = kept
    r.removed_routes = (r.removed_routes or 0) + removed
    r.route_decommissioned = true
    record("legacy-direct-nth-guard-disabled-0511", nil, "removed=" .. safe(removed), true)
  end
  return removed > 0
end

function M.service_all(reason)
  if M.root().enabled == false then return false end
  decommission_legacy_direct_nth_guard()
  wrap_target_finder(); wrap_movement_request(); wrap_acquisition_executor(); wrap_legacy_direct_functions()
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      M.sanitize_direct_target(pair, reason or "service")
      M.return_to_station_if_overleashed(pair, reason or "service")
    end
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
  pcall(function() if commands.remove_command then commands.remove_command("tp-movement-bounds-0511") end end)
  commands.add_command("tp-movement-bounds-0511", "Tech Priests 0.1.511: bounded movement/direct acquisition status. Params: on/off/all/bounds-on/bounds-off/route-on/route-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "bounds-on" then r.bound_direct_targets = true; r.bound_direct_movement = true end
    if p == "bounds-off" then r.bound_direct_targets = false; r.bound_direct_movement = false end
    if p == "route-on" then r.decommission_legacy_direct_nth_guard = true; r.route_decommissioned = nil; decommission_legacy_direct_nth_guard() end
    if p == "route-off" then r.decommission_legacy_direct_nth_guard = false end
    if p == "all" then M.service_all("manual-all") end
    local pair = selected_pair(player)
    local lines = {}
    lines[#lines+1] = "[tp-movement-bounds-0511] enabled=" .. safe(r.enabled) .. " bound_targets=" .. safe(r.bound_direct_targets) .. " bound_movement=" .. safe(r.bound_direct_movement) .. " removed_legacy61=" .. safe(r.removed_routes or 0)
      .. " rejected=" .. safe((r.stats["direct-target-rejected-0511"] or 0) + (r.stats["finder-target-rejected-0511"] or 0) + (r.stats["movement-target-rejected-0511"] or 0))
      .. " overleash_returns=" .. safe(r.stats["overleash-return-0511"] or 0)
    if pair then
      local _, cur = current_direct_task(pair); local pos = target_position(pair, cur)
      local sd = station_distance(pair, pos); local pd = valid(pair.priest) and dist(pair.priest.position, pair.station.position) or nil
      lines[#lines+1] = "selected station=" .. safe(station_unit(pair)) .. " priest=" .. safe(priest_unit(pair)) .. " tier=" .. safe(tier_key(pair)) .. " mode=" .. safe(pair.mode)
        .. " station_to_priest=" .. safe(pd and string.format("%.1f", pd) or "nil") .. " direct_radius=" .. safe(M.direct_radius(pair)) .. " hard_leash=" .. safe(M.hard_leash(pair))
        .. " direct=" .. safe(cur and cur.kind or "nil") .. " target=" .. target_label(cur) .. " station_to_target=" .. safe(sd and string.format("%.1f", sd) or "nil")
    end
    local msg = table.concat(lines, "\n")
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.movement_bounds_0511_wrapped then return false end
  diag.movement_bounds_0511_wrapped = true
  local prev = diag.pair_dump_lines
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines+1] = "PAIR-DUMP-0468 MOVEMENT-BOUNDS-0511 BEGIN enabled=" .. safe(r.enabled) .. " bound_targets=" .. safe(r.bound_direct_targets) .. " removed_legacy61=" .. safe(r.removed_routes or 0)
      .. " rejected=" .. safe((r.stats["direct-target-rejected-0511"] or 0) + (r.stats["finder-target-rejected-0511"] or 0) + (r.stats["movement-target-rejected-0511"] or 0))
      .. " returns=" .. safe(r.stats["overleash-return-0511"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local _, cur = current_direct_task(pair); local pos = target_position(pair, cur)
        local sd = station_distance(pair, pos); local pd = valid(pair.priest) and dist(pair.priest.position, pair.station.position) or nil
        local blocked = r.blocked_targets[safe(station_unit(pair))]
        lines[#lines+1] = "PAIR-DUMP-0468 mb0511[" .. safe(station_unit(pair)) .. "] priest=" .. safe(priest_unit(pair)) .. " valid=" .. safe(valid(pair.priest))
          .. " tier=" .. safe(tier_key(pair)) .. " mode=" .. safe(pair.mode) .. " station_to_priest=" .. safe(pd and string.format("%.1f", pd) or "nil")
          .. " direct_radius=" .. safe(M.direct_radius(pair)) .. " hard_leash=" .. safe(M.hard_leash(pair)) .. " target=" .. target_label(cur)
          .. " station_to_target=" .. safe(sd and string.format("%.1f", sd) or "nil") .. " last_blocked=" .. safe(blocked and (blocked.target .. "@" .. tostring(blocked.tick)) or "nil")
      end
    end
    for i = math.max(1, #r.recent - 10), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 mb0511.recent[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 MOVEMENT-BOUNDS-0511 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  wrap_target_finder(); wrap_movement_request(); wrap_acquisition_executor(); wrap_legacy_direct_functions(); decommission_legacy_direct_nth_guard(); wrap_pair_dump(); install_commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and type(registry.on_nth_tick) == "function" then
    registry.on_nth_tick(M.service_interval, function() M.service_all("nth-tick-0511") end, { owner = "movement_bounds_contract_0511", category = "movement", priority = "first", note = "bounded direct acquisition movement and Planetary Magos leash" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.service_interval, function() M.service_all("nth-tick-0511") end)
  end
  _G.TechPriestsMovementBounds0511 = M
  if log then log("[Tech-Priests 0.1.511] movement bounds contract installed; direct targets are bounded, legacy 0273 hard-kick is decommissioned, overleashed priests walk home") end
  return true
end

return M
