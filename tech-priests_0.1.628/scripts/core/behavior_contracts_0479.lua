-- scripts/core/behavior_contracts_0479.lua
-- Tech Priests 0.1.479
--
-- A late-loaded execution contract layer for the current stabilization pass.
-- The logs showed the 0.1.477 watchdog could see an active lower surface, so it
-- did not re-arm movement even when the visible priest stood near the station and
-- the mining beam reached out to a distant target.  This module makes that illegal:
-- non-hostile acquisition visuals may only fire when the priest is already close,
-- and otherwise the movement request is reissued and the beam is suppressed.

local M = {}
M.version = "0.1.479"
M.storage_key = "behavior_contracts_0479"
M.close_distance_sq = 4.0
M.tick_interval = 31
M.move_ttl_ticks = 60 * 10

local previous_scan_line = nil
local previous_fire_laser = nil

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
local function stat(name, delta) local r=root(); r.stats[name]=(r.stats[name] or 0)+(delta or 1) end
local function enabled() return root().enabled ~= false end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function pair_key(pair) return pair and valid(pair.station) and pair.station.unit_number or pair and pair.station_unit or "?" end

local function current_order(pair)
  local q = pair and pair.order_queue_0469
  return pair and (pair.active_order_0469 or (q and q.current)) or nil
end

local function kind_of(pair, order)
  local k = lower(order and (order.kind or order.type or order.source) or pair and pair.mode)
  if k:find("combat",1,true) or k:find("defend",1,true) or k:find("weapon",1,true) or k:find("point%-blank") then return "combat" end
  if k:find("repair",1,true) then return "repair" end
  if k:find("consecr",1,true) or k:find("sanct",1,true) then return "consecration" end
  if k:find("assign",1,true) then return "assignment" end
  if k:find("logistic",1,true) or k:find("supply",1,true) then return "logistics" end
  if k:find("scav",1,true) then return "scavenge" end
  if k:find("mine",1,true) or k:find("acqui",1,true) or k:find("gather",1,true) or k:find("resource",1,true) or k:find("laser%-fallback") then return "acquisition" end
  if k:find("craft",1,true) or k:find("emergency",1,true) then return "emergency_craft" end
  return k ~= "" and k or "idle"
end

local acquisition_kinds = { acquisition=true, scavenge=true, logistics=true, assignment=true, gather=true, direct_mine=true }

local function item_from(t)
  if type(t) ~= "table" then return nil end
  return t.item or t.item_name or t.output_item or t.wanted_item or t.requested_item or t.resource or t.name
end
local function order_item(order)
  return order and (order.item or order.wanted_item or order.requested_item or item_from(order.task or {})) or nil
end

local function entity_or_pos(v, seen)
  if valid(v) then return v, v.position end
  if type(v) ~= "table" then return nil, nil end
  seen = seen or {}
  if seen[v] then return nil, nil end
  seen[v] = true
  if v.x and v.y then return nil, v end
  if v.position and v.position.x and v.position.y then return nil, v.position end
  for _, key in ipairs({"target","source","entity","resource_entity","mining_target","candidate","current","selected","node","resource","destination"}) do
    local e,p = entity_or_pos(v[key], seen)
    if e or p then return e,p end
  end
  return nil,nil
end

local function current_target(pair, order)
  if not pair then return nil,nil end
  local probes = {}
  local function add_probe(v) if v ~= nil then probes[#probes + 1] = v end end
  add_probe(order and order.target)
  add_probe(order and order.task)
  add_probe(pair.active_task)
  add_probe(pair.active_task_0285)
  add_probe(pair.direct_acquisition_task_0336)
  add_probe(pair.emergency_craft)
  add_probe(pair.scavenge)
  add_probe(pair.target)
  add_probe(pair.mining_target)
  add_probe(pair.current_resource_target)
  add_probe(pair.assignment_worker_0273)
  for _, probe in ipairs(probes) do
    local e,p = entity_or_pos(probe)
    if e or p then return e,p end
  end
  return nil,nil
end

local function is_hostile(priest, target)
  if not (valid(priest) and valid(target) and priest.force and target.force) then return false end
  if priest.force == target.force then return false end
  local ok, enemy = pcall(function() return priest.force.is_enemy and priest.force.is_enemy(target.force) end)
  return ok and enemy == true
end

local function should_force_movement(pair, target, pos, reason)
  if not (enabled() and valid_pair(pair) and pos) then return false end
  if target and target == pair.station then return false end
  if target and is_hostile(pair.priest, target) then return false end
  local k = kind_of(pair, current_order(pair))
  if k == "combat" or k == "repair" or k == "consecration" then return false end
  if not acquisition_kinds[k] and not lower(reason):find("mine",1,true) and not lower(reason):find("gather",1,true) and not lower(reason):find("scan",1,true) then return false end
  local d2 = dist_sq(pair.priest.position, pos) or 0
  return d2 > M.close_distance_sq
end

local function destroy_object(obj) if not obj then return end; pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end) end
local function clear_scan(pair)
  if not pair then return end
  destroy_object(pair.scan_line_render); pair.scan_line_render = nil
  destroy_object(pair.mining_beam_render); pair.mining_beam_render = nil
end

local function request_move(pair, pos, reason, priority)
  if not (valid_pair(pair) and pos) then return false end
  local ok = false
  if _G.tech_priests_request_movement_0418 then
    local ok_call, result = pcall(_G.tech_priests_request_movement_0418, pair, pos, reason or "behavior-contract-0479", { radius = 0.75, owner = "behavior-contract-0479", priority = priority or 690, ttl = M.move_ttl_ticks, distraction = defines and defines.distraction and defines.distraction.by_enemy or nil })
    ok = ok_call and result ~= false
  elseif pair.priest.set_command and defines and defines.command then
    ok = pcall(function() pair.priest.set_command{ type=defines.command.go_to_location, destination=pos, radius=0.75, distraction=defines.distraction.by_enemy } end)
  end
  pair.behavior_contract_0479 = pair.behavior_contract_0479 or {}
  pair.behavior_contract_0479.last_move_tick = now()
  pair.behavior_contract_0479.last_move_reason = reason
  pair.behavior_contract_0479.last_move_x = pos.x
  pair.behavior_contract_0479.last_move_y = pos.y
  if ok then stat("move_requests") end
  return ok
end

local function suppress_remote_action(pair, target, pos, reason)
  if not should_force_movement(pair, target, pos, reason) then return false end
  request_move(pair, pos, reason or "suppressed-remote-acquisition", 700)
  clear_scan(pair)
  pair.behavior_contract_0479 = pair.behavior_contract_0479 or {}
  pair.behavior_contract_0479.remote_suppressed = (pair.behavior_contract_0479.remote_suppressed or 0) + 1
  pair.behavior_contract_0479.last_suppressed_tick = now()
  pair.behavior_contract_0479.last_suppressed_target = target and (safe(target.name) .. "#" .. safe(target.unit_number or "?")) or ("pos:" .. safe(pos.x) .. "," .. safe(pos.y))
  stat("remote_suppressed")
  return true
end

function M.service_pair(pair)
  if not (enabled() and valid_pair(pair)) then return false end
  local order = current_order(pair)
  local target, pos = current_target(pair, order)
  if suppress_remote_action(pair, target, pos, "behavior-contract-0479-service") then return true end
  return false
end

function M.tick_all()
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do pcall(M.service_pair, pair) end
end

function M.wrap_scan_line()
  if type(_G.draw_emergency_craft_scan_line) ~= "function" or previous_scan_line then return false end
  previous_scan_line = _G.draw_emergency_craft_scan_line
  _G.draw_emergency_craft_scan_line = function(pair, target_entity)
    if valid_pair(pair) and valid(target_entity) then
      if suppress_remote_action(pair, target_entity, target_entity.position, "behavior-contract-0479-scan-line") then return false end
    end
    return previous_scan_line(pair, target_entity)
  end
  return true
end

function M.wrap_laser()
  if type(_G.tech_priests_0312_fire_laser) ~= "function" or previous_fire_laser then return false end
  previous_fire_laser = _G.tech_priests_0312_fire_laser
  _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
    if valid(priest) and valid(target) and not is_hostile(priest, target) then
      local pair = storage and storage.tech_priests and (storage.tech_priests.pairs_by_priest or {})[priest.unit_number]
      if valid_pair(pair) and suppress_remote_action(pair, target, target.position, reason or "behavior-contract-0479-laser") then return false end
    end
    return previous_fire_laser(priest, target, damage, reason, color)
  end
  return true
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines)=="function") then return false end
  if diag.behavior_contract_wrapped_0479 then return true end
  local prev = diag.pair_dump_lines
  diag.behavior_contract_wrapped_0479 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "BEHAVIOR-CONTRACT-0479 BEGIN enabled=" .. safe(r.enabled) .. " remote_suppressed=" .. safe(r.stats.remote_suppressed or 0) .. " move_requests=" .. safe(r.stats.move_requests or 0)
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local order = current_order(pair)
        local target,pos = current_target(pair, order)
        local d = pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
        local bc = pair.behavior_contract_0479 or {}
        lines[#lines+1] = "contract[" .. safe(key) .. "] current=" .. safe(order and order.key or "none") .. " item=" .. safe(order_item(order)) .. " mode=" .. safe(pair.mode) .. " target=" .. safe(target and (target.name .. "#" .. tostring(target.unit_number or "?")) or (pos and ("pos:" .. tostring(pos.x) .. "," .. tostring(pos.y)) or "none")) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil") .. " suppressed=" .. safe(bc.remote_suppressed or 0) .. " last=" .. safe(bc.last_suppressed_target)
      end
    end
    lines[#lines+1] = "BEHAVIOR-CONTRACT-0479 END"
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
  local lines = { "enabled=" .. safe(r.enabled) .. " remote_suppressed=" .. safe(r.stats.remote_suppressed or 0) .. " move_requests=" .. safe(r.stats.move_requests or 0) }
  if valid_pair(pair) then
    local order = current_order(pair)
    local target,pos = current_target(pair, order)
    local d = pos and math.sqrt(dist_sq(pair.priest.position, pos) or 0) or nil
    local bc = pair.behavior_contract_0479 or {}
    lines[#lines+1] = "pair=" .. safe(pair_key(pair)) .. " current=" .. safe(order and order.key or "none") .. " item=" .. safe(order_item(order)) .. " mode=" .. safe(pair.mode)
    lines[#lines+1] = "target=" .. safe(target and (target.name .. "#" .. tostring(target.unit_number or "?")) or (pos and ("pos:" .. tostring(pos.x) .. "," .. tostring(pos.y)) or "none")) .. " dist=" .. safe(d and string.format("%.1f", d) or "nil") .. " last-suppressed=" .. safe(bc.last_suppressed_target)
  end
  return lines
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-contract-0479") end end)
  commands.add_command("tp-behavior-contract-0479", "Tech Priests 0.1.479: inspect movement-before-action contracts. Usage: status|all|on|off|kick", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = root()
    if param == "off" or param == "disable" then r.enabled = false end
    if param == "on" or param == "enable" then r.enabled = true end
    local pair = selected_pair(player)
    if param == "kick" and pair then M.service_pair(pair) end
    if player and player.valid then
      if param == "all" then
        for _, p in pairs(pair_map()) do for _, line in ipairs(M.describe(p)) do player.print("[tp-behavior-contract-0479] " .. line) end end
      else
        for _, line in ipairs(M.describe(pair)) do player.print("[tp-behavior-contract-0479] " .. line) end
        if not pair then player.print("[tp-behavior-contract-0479] select a Cogitator Station or Tech-Priest for pair-local contract state.") end
      end
    end
  end)
end

function M.install()
  if M._installed then return true end
  M._installed = true
  root()
  M.wrap_scan_line()
  M.wrap_laser()
  M.wrap_diagnostics()
  _G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick_all() end, { owner = "behavior_contracts_0479", category = "scheduler", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.tick_all() end) end)
  end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.479] behavior contracts installed; distant non-hostile acquisition must move before beams") end
  return true
end

return M
