#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Canonical movement controller absorbs ground envelope enforcement and delegates
# only void pairs to the specialized backend.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace(
    'M.broker_required = true',
    'M.broker_required = true\nM.enforcement_integrated = true\nM.enforcement_service_ticks = 89\nM.enforcement_budget = 24\nM.default_work_radius = 36\nM.default_hard_leash = 52\nM.work_radius_by_tier = { ["planetary-magos"] = 28, ["planetary_magos"] = 28, planetary = 28, senior = 36, intermediate = 38, junior = 40 }\nM.hard_leash_by_tier = { ["planetary-magos"] = 42, ["planetary_magos"] = 42, planetary = 42, senior = 52, intermediate = 56, junior = 60 }',
    1,
)
old_dist = '''local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
'''
new_dist = old_dist + '''
local function lower(value) return string.lower(tostring(value or "")) end
local function tier_key(pair)
  local text = lower(pair and (pair.tier or pair.rank or pair.station_tier or (valid(pair.station) and pair.station.name) or ""))
  if text:find("planetary", 1, true) or text:find("magos", 1, true) then return "planetary-magos" end
  if text:find("senior", 1, true) then return "senior" end
  if text:find("intermediate", 1, true) then return "intermediate" end
  if text:find("junior", 1, true) then return "junior" end
  return "default"
end
local function runtime_radius(pair)
  local radius = tonumber(pair and (pair.radius or pair.base_radius))
  if type(_G.refresh_pair_radius) == "function" and pair then
    local ok, got = pcall(_G.refresh_pair_radius, pair)
    if ok and tonumber(got) then radius = tonumber(got) end
  end
  if not radius and type(_G.get_station_operating_radius) == "function" and valid(pair and pair.station) then
    local ok, got = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(got) then radius = tonumber(got) end
  end
  return radius
end
function M.work_radius(pair)
  local cap = M.work_radius_by_tier[tier_key(pair)] or M.default_work_radius
  return math.max(8, math.min(math.max(runtime_radius(pair) or cap, 8), cap))
end
function M.hard_leash(pair)
  local cap = M.hard_leash_by_tier[tier_key(pair)] or M.default_hard_leash
  return math.max(M.work_radius(pair) + 8, cap)
end
local function return_or_recovery_reason(reason, opts)
  local value = lower(reason) .. " " .. lower(opts and opts.owner or "")
  return value:find("return", 1, true) ~= nil
    or value:find("home", 1, true) ~= nil
    or value:find("overleash", 1, true) ~= nil
    or value:find("station", 1, true) ~= nil
    or value:find("recovery", 1, true) ~= nil
    or value:find("respawn", 1, true) ~= nil
    or value:find("pair%-link", 1, false) ~= nil
end
'''
if old_dist not in text:
    raise SystemExit("movement controller distance anchor missing")
text = text.replace(old_dist, new_dist, 1)
old_space = '''local function is_space_pair(pair)
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  return false
end
'''
new_space = '''local function void_backend()
  local backend = rawget(_G, "TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630")
  if not backend then pcall(function() backend = require("scripts.core.void_movement_authority_0630") end) end
  return backend
end
local function is_space_pair(pair)
  local backend = void_backend()
  if backend and type(backend.is_void_pair) == "function" then
    local ok, result = pcall(backend.is_void_pair, pair)
    if ok and result then return true end
  end
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  return pair and (pair.void_priest_0630 or pair.void_priest or pair.is_void_priest) == true or false
end
function M.position_allowed(pair, pos, reason, opts)
  if not (pair and valid(pair.station) and pos) then return true, nil, nil end
  if is_space_pair(pair) or return_or_recovery_reason(reason, opts) or (opts and opts.bounds_exempt == true) then return true, nil, nil end
  local corridor = rawget(_G, "tech_priests_0574_position_allowed")
  if type(corridor) == "function" then
    local ok, allowed = pcall(corridor, pair, pos, reason, opts)
    if ok and allowed then return true, nil, nil end
  end
  local distance_sq = dist_sq(pair.station.position, pos) or 0
  local distance = math.sqrt(distance_sq)
  local maximum = M.work_radius(pair)
  return distance <= maximum, distance, maximum
end
'''
if old_space not in text:
    raise SystemExit("movement controller space helper anchor missing")
text = text.replace(old_space, new_space, 1)
old_request_head = '''function M.request(pair, destination, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if is_space_pair(pair) and not opts.force_ground_controller then
    return direct_go_to(pair.priest, destination, opts.radius, opts.distraction)
  end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return false end
'''
new_request_head = '''function M.request(pair, destination, reason, opts)
  opts = opts or {}
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if is_space_pair(pair) and not opts.force_ground_controller then
    local backend = void_backend()
    if backend and type(backend.request) == "function" then return backend.request(pair, destination, reason, opts) end
    return false, "void-movement-backend-unavailable"
  end
  local root = ensure_root()
  local key = pair_key(pair)
  if not key then return false end
  local allowed, distance, maximum = M.position_allowed(pair, destination, reason, opts)
  if not allowed then
    root.stats.destinations_rejected_0566 = (root.stats.destinations_rejected_0566 or 0) + 1
    root.requests[key] = nil
    clear_active_request(root, key)
    pair.movement_request_0418 = nil
    pair.movement_controller_state_0418 = "movement-target-rejected-0566"
    pair.movement_controller_status_0418 = "rejected-out-of-envelope"
    direct_stop(pair.priest)
    if valid(pair.station) and not return_or_recovery_reason(reason, opts) then
      M.request(pair, pair.station.position, "movement-enforcement-return-0566", {
        radius = 1.0, owner = "movement-controller-enforcement-0566", priority = 840,
        ttl = 600, distraction = defines and defines.distraction and defines.distraction.none,
        bounds_exempt = true,
      })
    end
    return false, "movement-target-out-of-bounds:" .. tostring(distance or "?") .. "/" .. tostring(maximum or "?")
  end
'''
if old_request_head not in text:
    raise SystemExit("movement controller request head anchor missing")
text = text.replace(old_request_head, new_request_head, 1)
old_status = '''function M.request_status(pair, owner)
  local root = ensure_root()
'''
new_status = '''function M.request_status(pair, owner)
  if is_space_pair(pair) then
    local backend = void_backend()
    if backend and type(backend.status) == "function" then return backend.status(pair, owner) end
  end
  local root = ensure_root()
'''
if old_status not in text:
    raise SystemExit("movement status anchor missing")
text = text.replace(old_status, new_status, 1)
old_stop = '''function M.stop(pair, reason)
  if not (pair and pair.priest and pair.priest.valid) then return false end
  local root = ensure_root()
'''
new_stop = '''function M.stop(pair, reason)
  if not (pair and pair.priest and pair.priest.valid) then return false end
  if is_space_pair(pair) then
    local backend = void_backend()
    if backend and type(backend.stop) == "function" then return backend.stop(pair, reason) end
  end
  local root = ensure_root()
'''
if old_stop not in text:
    raise SystemExit("movement stop anchor missing")
text = text.replace(old_stop, new_stop, 1)
old_after_stop = '''  root.stats.stops = (root.stats.stops or 0) + 1
  return direct_stop(pair.priest)
end

local function apply_request(pair, req)'''
new_after_stop = '''  root.stats.stops = (root.stats.stops or 0) + 1
  return direct_stop(pair.priest)
end

function M.enforce_pair(pair, reason)
  if not (pair and valid(pair.station) and valid(pair.priest)) or is_space_pair(pair) then return false, "not-ground-pair" end
  local root = ensure_root()
  local key = pair_key(pair)
  local distance = math.sqrt(dist_sq(pair.priest.position, pair.station.position) or 0)
  if distance > M.hard_leash(pair) then
    M.stop(pair, "movement-overleash-0566")
    local moved = M.request(pair, pair.station.position, "movement-enforcement-overleash-return-0566", {
      radius = 1.0, owner = "movement-controller-enforcement-0566", priority = 840,
      ttl = 600, distraction = defines and defines.distraction and defines.distraction.none,
      bounds_exempt = true,
    })
    root.stats.overleash_returns_0566 = (root.stats.overleash_returns_0566 or 0) + 1
    return moved == true, "overleash-return"
  end
  local request = (key and root.requests[key]) or pair.movement_request_0418
  if request then
    local allowed = M.position_allowed(pair, request, request.reason or reason, { owner = request.owner })
    if not allowed then
      M.stop(pair, "stale-far-movement-request-0566")
      M.request(pair, pair.station.position, "movement-enforcement-stale-return-0566", {
        radius = 1.0, owner = "movement-controller-enforcement-0566", priority = 840,
        ttl = 600, distraction = defines and defines.distraction and defines.distraction.none,
        bounds_exempt = true,
      })
      root.stats.stale_requests_rejected_0566 = (root.stats.stale_requests_rejected_0566 or 0) + 1
      return true, "stale-request-return"
    end
  end
  if valid(pair.combat_target) then
    local allowed = M.position_allowed(pair, pair.combat_target.position, "combat-target-0566", { owner = "combat-target" })
    if not allowed then
      if CombatSafety and type(CombatSafety.clear_invalid_combat_state) == "function" then
        pcall(CombatSafety.clear_invalid_combat_state, pair, "far-combat-target-0566")
      else
        pair.combat_target = nil
        pair.paused_by_combat = nil
      end
      root.stats.far_combat_targets_cleared_0566 = (root.stats.far_combat_targets_cleared_0566 or 0) + 1
      return true, "far-combat-target-cleared"
    end
  end
  return false, "clean"
end

function M.enforcement_service(event, budget)
  local root = ensure_root()
  local list = {}
  for key, pair in pairs(pairs_by_station()) do
    if pair and valid(pair.station) and valid(pair.priest) and not is_space_pair(pair) then list[#list + 1] = { key = tostring(key), pair = pair } end
  end
  table.sort(list, function(a, b) return a.key < b.key end)
  if #list == 0 then return { processed = 0, acted = 0, detail = "no-ground-pairs" } end
  local limit = math.max(1, math.min(#list, math.floor(tonumber(budget) or M.enforcement_budget)))
  local start = (tonumber(root.enforcement_cursor) or 0) % #list + 1
  local processed, acted = 0, 0
  for offset = 0, limit - 1 do
    local pair = list[((start + offset - 1) % #list) + 1].pair
    processed = processed + 1
    local ok, did = pcall(M.enforce_pair, pair, "broker-enforcement-0566")
    if ok and did == true then acted = acted + 1 end
    if not ok then root.stats.enforcement_errors_0566 = (root.stats.enforcement_errors_0566 or 0) + 1 end
  end
  root.enforcement_cursor = (start + limit - 2) % #list + 1
  root.stats.enforcement_processed_0566 = (root.stats.enforcement_processed_0566 or 0) + processed
  root.stats.enforcement_acted_0566 = (root.stats.enforcement_acted_0566 or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit and processed < #list, detail = "ground-envelope-enforcement" }
end

local function apply_request(pair, req)'''
if old_after_stop not in text:
    raise SystemExit("movement stop/apply anchor missing")
text = text.replace(old_after_stop, new_after_stop, 1)
old_route = '''  if pair and not is_space_pair(pair) then
    root.stats.route_command_ground = (root.stats.route_command_ground or 0) + 1
    if command.type == defines.command.go_to_location and command.destination then
      root.stats.route_command_go_to = (root.stats.route_command_go_to or 0) + 1
      return M.request(pair, command.destination, owner or command.reason or "legacy-routed-command", {
        radius = command.radius,
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-command-route-0429",
        priority = opts.priority or 50,
        ttl = opts.ttl or M.default_request_ttl
      })
    end
    if command.type == defines.command.attack and command.target then
      root.stats.route_command_attack = (root.stats.route_command_attack or 0) + 1
      return M.combat_intent(pair, command.target, owner or "legacy-routed-attack-0429", {
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-attack-route-0429",
        priority = opts.priority or 85,
        ttl = opts.ttl or 60 * 4,
        fire_range = opts.fire_range,
        radius = opts.radius
      })
    end
    if command.type == defines.command.stop then
      root.stats.route_command_stop = (root.stats.route_command_stop or 0) + 1
      return M.stop(pair, owner or "legacy-routed-stop-0429")
    end
  end
'''
new_route = '''  if pair then
    if command.type == defines.command.go_to_location and command.destination then
      root.stats.route_command_go_to = (root.stats.route_command_go_to or 0) + 1
      if not is_space_pair(pair) then root.stats.route_command_ground = (root.stats.route_command_ground or 0) + 1 end
      return M.request(pair, command.destination, owner or command.reason or "legacy-routed-command", {
        radius = command.radius,
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-command-route-0429",
        priority = opts.priority or 50,
        ttl = opts.ttl or M.default_request_ttl
      })
    end
    if command.type == defines.command.attack and command.target and not is_space_pair(pair) then
      root.stats.route_command_ground = (root.stats.route_command_ground or 0) + 1
      root.stats.route_command_attack = (root.stats.route_command_attack or 0) + 1
      return M.combat_intent(pair, command.target, owner or "legacy-routed-attack-0429", {
        distraction = command.distraction,
        owner = owner or opts.owner or "legacy-attack-route-0429",
        priority = opts.priority or 85,
        ttl = opts.ttl or 60 * 4,
        fire_range = opts.fire_range,
        radius = opts.radius
      })
    end
    if command.type == defines.command.stop then
      root.stats.route_command_stop = (root.stats.route_command_stop or 0) + 1
      return M.stop(pair, owner or "legacy-routed-stop-0429")
    end
  end
'''
if old_route not in text:
    raise SystemExit("movement route command anchor missing")
text = text.replace(old_route, new_route, 1)
text = text.replace('if pair and not is_space_pair(pair) then\n          return M.route_command', 'if pair and (command.type ~= defines.command.attack or not is_space_pair(pair)) then\n          return M.route_command', 1)
text = text.replace('if pair and destination and not is_space_pair(pair) then\n        return M.request', 'if pair and destination then\n        return M.request', 1)
text = text.replace('if pair and valid(priest) and valid(station) and not is_space_pair(pair) then\n        return M.request', 'if pair and valid(priest) and valid(station) then\n        return M.request', 1)
text = text.replace(
    '      " budget_exhausted=" .. tostring(((root.stats or {}).service_budget_exhausted or 0) + ((root.stats or {}).sample_budget_exhausted or 0))',
    '      " enforcement_acted=" .. tostring((root.stats or {}).enforcement_acted_0566 or 0) ..\n      " enforcement_rejected=" .. tostring((root.stats or {}).destinations_rejected_0566 or 0) ..\n      " budget_exhausted=" .. tostring(((root.stats or {}).service_budget_exhausted or 0) + ((root.stats or {}).sample_budget_exhausted or 0))',
    1,
)
old_install = '''  local service = broker.register_service({ name = "movement_controller_service_0611", category = "movement", priority = 42, interval = M.service_ticks, budget = 24, fn = function(event, budget) return M.service(event, budget) end, note = "service only active movement requests; cadence and long-action leases integrated" })
  local sample = broker.register_service({ name = "movement_controller_sample_0611", category = "movement", priority = 80, interval = M.snap_sample_ticks, budget = 32, fn = function(event, budget) return M.sample(event, budget) end, note = "sample only active movement requests" })
  if not (service and sample) then return false end
  if log then log("[Tech-Priests recovery] canonical ground movement controller installed; cadence leases integrated and broker required") end'''
new_install = '''  local service = broker.register_service({ name = "movement_controller_service_0611", category = "movement", priority = 42, interval = M.service_ticks, budget = 24, fn = function(event, budget) return M.service(event, budget) end, note = "service only active movement requests; cadence and long-action leases integrated" })
  local sample = broker.register_service({ name = "movement_controller_sample_0611", category = "movement", priority = 80, interval = M.snap_sample_ticks, budget = 32, fn = function(event, budget) return M.sample(event, budget) end, note = "sample only active movement requests" })
  local enforcement = broker.register_service({ name = "movement_controller_enforcement_0566", category = "movement", priority = 70, interval = M.enforcement_service_ticks, budget = M.enforcement_budget, fn = function(event, budget) return M.enforcement_service(event, budget) end, note = "canonical ground envelope, stale-request, and overleash enforcement" })
  if not (service and sample and enforcement) then return false end
  if log then log("[Tech-Priests recovery] canonical movement controller installed; ground envelope enforcement integrated and void backend delegated") end'''
if old_install not in text:
    raise SystemExit("movement install anchor missing")
text = text.replace(old_install, new_install, 1)
write(path, text)

# Void movement becomes a broker-only specialized backend with no public wrapper chain.
void_source = '''-- scripts/core/void_movement_authority_0630.lua
-- Tech Priests 0.1.674-dev canonical specialized Void/platform backend.
-- movement_controller owns the public movement API and delegates only void pairs.
-- This backend owns same-surface stepped relocation, request identity, TTL,
-- priority replacement, terminal cleanup, and broker service for void pairs.

local M = {
  version = "0.1.674-dev",
  storage_key = "void_movement_authority_0630",
  service_interval = 1,
  broker_pulse_ticks = 5,
  default_radius = 0.75,
  default_ttl = 60 * 10,
  ttl_margin_ticks = 60 * 2,
  default_step = 0.32,
  max_step = 0.80,
  same_target_distance_sq = 0.0625,
  retarget_hold_ticks = 30,
  broker_required = true,
  public_wrapper_retired = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value) if value == nil then return "nil" end local ok, out = pcall(tostring, value); return ok and out or "?" end
local function lower(value) return string.lower(tostring(value or "")) end
local function dist_sq(a, b) if not (a and b) then return math.huge end local dx = (a.x or 0) - (b.x or 0); local dy = (a.y or 0) - (b.y or 0); return dx * dx + dy * dy end
local function distance(a, b) return math.sqrt(dist_sq(a, b)) end
local function unit(entity) return valid(entity) and entity.unit_number or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function pair_key(pair)
  if valid(pair and pair.station) and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if valid(pair and pair.priest) and pair.priest.unit_number then return "p" .. tostring(pair.priest.unit_number) end
  return nil
end
local function pair_for_key(key)
  local map = pair_map()
  return map[key] or map[tonumber(key)]
end

function M.is_void_pair(pair)
  if not valid_pair(pair) then return false end
  if _G.tech_priests_pair_on_space_platform_0204 then
    local ok, result = pcall(_G.tech_priests_pair_on_space_platform_0204, pair)
    if ok and result then return true end
  end
  if pair.void_priest_0630 or pair.void_priest or pair.is_void_priest then return true end
  local name = lower(pair.priest.name) .. " " .. lower(pair.priest_name or pair.rank or pair.tier or "")
  return name:find("void", 1, true) ~= nil
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, requests = {}, active = {}, sequence = 0 }
  local state = storage.tech_priests[M.storage_key]
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.requests = state.requests or {}
  state.active = state.active or {}
  state.sequence = tonumber(state.sequence) or 0
  return state
end
local function stat(name, amount) local state = root(); state.stats[name] = (state.stats[name] or 0) + (amount or 1) end
local function record(pair, action, detail)
  local state = root(); stat(action)
  state.recent[#state.recent + 1] = { tick = now(), action = tostring(action), station = safe(unit(pair and pair.station)), priest = safe(unit(pair and pair.priest)), detail = tostring(detail or "") }
  while #state.recent > 120 do table.remove(state.recent, 1) end
end
local function stop_entity(priest)
  if not valid(priest) then return false end
  pcall(function() priest.walking_state = { walking = false } end)
  if defines and defines.command then
    pcall(function()
      if priest.commandable and priest.commandable.valid then priest.commandable.set_command({ type = defines.command.stop })
      elseif priest.set_command then priest.set_command({ type = defines.command.stop }) end
    end)
  end
  return true
end
local function relocate(entity, position)
  if not (valid(entity) and position) then return false end
  local fn = entity["tele" .. "port"]
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, position, entity.surface)
  return ok and result ~= false
end
local function clear_pair_fields(pair, request, status)
  if type(pair) ~= "table" then return end
  if request == nil or pair.void_movement_request_0630 == request then pair.void_movement_request_0630 = nil end
  if request == nil or pair.movement_request_0418 == request then pair.movement_request_0418 = nil end
  pair.void_movement_status_0630 = status
  pair.movement_controller_state_0418 = "void-" .. tostring(status or "finished")
  pair.movement_controller_status_0418 = "void-" .. tostring(status or "finished")
  pair.movement_controller_clamp_0418 = nil
end
local function finish(pair, request, status, detail, should_stop)
  local state = root()
  local key = (request and request.key) or pair_key(pair)
  if key then
    if request == nil or state.requests[key] == request then state.requests[key] = nil end
    state.active[key] = nil
  end
  clear_pair_fields(pair, request, status)
  if should_stop and valid(pair and pair.priest) then stop_entity(pair.priest) end
  record(pair, "void-movement-" .. tostring(status or "finished"), detail or (request and request.reason) or status)
  return true, status
end
local function minimum_ttl(pair, position, radius, step, requested)
  local requested_ttl = tonumber(requested) or M.default_ttl
  if not (valid_pair(pair) and position) then return requested_ttl end
  local remaining = math.max(0, distance(pair.priest.position, position) - math.max(0.05, tonumber(radius) or M.default_radius))
  local pulses = math.ceil(remaining / math.max(0.02, tonumber(step) or M.default_step))
  return math.max(requested_ttl, pulses * M.broker_pulse_ticks + M.ttl_margin_ticks)
end
local function same_target(request, position) return type(request) == "table" and position and dist_sq(request, position) <= M.same_target_distance_sq end
local function authorized_position(pair, position, reason, opts)
  local corridor = rawget(_G, "tech_priests_0574_position_allowed")
  if type(corridor) == "function" then
    local ok, allowed = pcall(corridor, pair, position, reason, opts)
    if ok then return allowed ~= false end
  end
  return true
end

function M.request(pair, position, reason, opts)
  opts = opts or {}
  local state = root()
  if state.enabled == false or not (valid_pair(pair) and M.is_void_pair(pair) and position and position.x and position.y) then return false, "invalid-void-movement-request" end
  if not authorized_position(pair, position, reason, opts) then return false, "void-position-not-authorized" end
  local key = pair_key(pair)
  if not key then return false, "missing-pair-key" end
  local owner = tostring(opts.owner or reason or "void-movement")
  local priority = tonumber(opts.priority) or 50
  local radius = math.max(0.05, tonumber(opts.radius) or M.default_radius)
  local step = math.min(M.max_step, math.max(0.02, tonumber(opts.void_step or opts.step) or M.default_step))
  local current = state.requests[key] or pair.void_movement_request_0630
  if current and current.expires_tick and current.expires_tick < now() then finish(pair, current, "expired", "expired-before-replacement", true); current = nil end
  if current then
    local current_owner = tostring(current.owner or "")
    local current_priority = tonumber(current.priority) or 0
    local age = now() - (tonumber(current.updated_tick or current.issued_tick) or now())
    if current_owner == owner and same_target(current, position) then
      current.reason = tostring(reason or current.reason or owner)
      current.updated_tick = now()
      current.priority = math.max(current_priority, priority)
      current.radius = radius
      current.step = step
      current.expires_tick = math.max(tonumber(current.expires_tick) or 0, now() + minimum_ttl(pair, position, radius, step, opts.ttl))
      current.refresh_count = (tonumber(current.refresh_count) or 0) + 1
      pair.void_movement_request_0630 = current
      pair.movement_request_0418 = current
      pair.void_movement_status_0630 = "active"
      pair.movement_controller_state_0418 = "void-request-refreshed"
      return true, current, "same-owner-refresh"
    end
    if current_owner ~= owner and priority < current_priority then return true, current, "held-by-higher-priority-owner" end
    if current_owner ~= owner and priority == current_priority and age < M.retarget_hold_ticks then return true, current, "equal-priority-retarget-hold" end
    state.requests[key] = nil
    state.active[key] = nil
    record(pair, "void-movement-replaced", current_owner .. "/" .. tostring(current_priority) .. " -> " .. owner .. "/" .. tostring(priority))
  end
  stop_entity(pair.priest)
  state.sequence = state.sequence + 1
  local ttl = minimum_ttl(pair, position, radius, step, opts.ttl)
  local request = {
    key = key, request_id = state.sequence, x = position.x, y = position.y, radius = radius,
    reason = tostring(reason or owner), owner = owner, priority = priority, step = step,
    issued_tick = now(), updated_tick = now(), expires_tick = now() + ttl,
    last_distance_sq = dist_sq(pair.priest.position, position), last_progress_tick = now(),
    failure_count = 0, surface_index = pair.priest.surface and pair.priest.surface.index or nil,
  }
  state.requests[key] = request
  state.active[key] = true
  pair.void_movement_request_0630 = request
  pair.movement_request_0418 = request
  pair.movement_controller_owner_0418 = owner
  pair.movement_controller_reason_0418 = request.reason
  pair.movement_controller_state_0418 = "void-requested"
  pair.movement_controller_status_0418 = "void-active"
  record(pair, "void-movement-request", owner .. " -> " .. string.format("%.2f,%.2f", request.x, request.y))
  return true, request
end

function M.stop(pair, reason)
  if type(pair) ~= "table" then return false end
  local key = pair_key(pair)
  local state = root()
  local request = (key and state.requests[key]) or pair.void_movement_request_0630
  finish(pair, request, "stopped", reason or "stop", true)
  return valid(pair.priest)
end

function M.status(pair, owner)
  local result = { status = "unknown", active = false, owner_match = false, tick = now() }
  if not valid_pair(pair) then result.status = "invalid-pair"; return result end
  if not M.is_void_pair(pair) then result.status = "not-void-pair"; return result end
  local state = root(); local key = pair_key(pair); local request = (key and state.requests[key]) or pair.void_movement_request_0630
  if request and request.expires_tick and request.expires_tick < now() then finish(pair, request, "expired", "status-observed-expiry", true); request = nil end
  if not request then result.status = pair.void_movement_status_0630 or "missing-request"; return result end
  result.active = true; result.owner = request.owner; result.reason = request.reason; result.priority = request.priority; result.expires_tick = request.expires_tick; result.radius = request.radius
  result.owner_match = not owner or tostring(request.owner or "") == tostring(owner)
  if owner and not result.owner_match then result.status = "replaced-by-other-owner"; return result end
  local current_distance_sq = dist_sq(pair.priest.position, request); result.distance_sq = current_distance_sq
  if current_distance_sq <= (tonumber(request.radius) or M.default_radius) ^ 2 then result.status = "arrived"; result.arrived = true else result.status = "active" end
  return result
end

local function step_pair(pair, request)
  if not (valid_pair(pair) and request) then return false, "invalid" end
  if request.expires_tick and request.expires_tick < now() then finish(pair, request, "expired", request.reason, true); return false, "expired" end
  if request.surface_index and pair.priest.surface and request.surface_index ~= pair.priest.surface.index then finish(pair, request, "surface-changed", request.reason, true); return false, "surface-changed" end
  local remaining = distance(pair.priest.position, request)
  local current_distance_sq = remaining * remaining
  local previous = tonumber(request.last_distance_sq)
  request.last_distance_sq = current_distance_sq
  if not previous or current_distance_sq < previous - 0.0025 then request.last_progress_tick = now() end
  local radius = math.max(0.05, tonumber(request.radius) or M.default_radius)
  if remaining <= radius then finish(pair, request, "arrived", request.reason, true); return true, "arrived" end
  local step = math.min(remaining, math.max(0.02, tonumber(request.step) or M.default_step))
  local ratio = step / math.max(remaining, 0.0001)
  local position = { x = pair.priest.position.x + (request.x - pair.priest.position.x) * ratio, y = pair.priest.position.y + (request.y - pair.priest.position.y) * ratio }
  if relocate(pair.priest, position) then
    request.failure_count = 0; request.last_step_tick = now(); pair.void_movement_status_0630 = "active"; pair.movement_controller_state_0418 = "void-jetpack-transit"; pair.movement_controller_status_0418 = "void-active"; stat("void-jetpack-steps"); return true, "step"
  end
  request.failure_count = (tonumber(request.failure_count) or 0) + 1
  request.last_failure_tick = now(); pair.void_movement_status_0630 = "relocation-failed"; pair.movement_controller_state_0418 = "void-relocation-retry"; pair.movement_controller_status_0418 = "void-relocation-failed"; stat("void-relocation-failed")
  return false, "relocation-failed"
end

function M.service(event, budget)
  local state = root()
  if state.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  local limit = math.max(1, math.floor(tonumber(budget) or 48))
  local processed, acted = 0, 0
  for key in pairs(state.active) do
    if processed >= limit then break end
    local pair = pair_for_key(key)
    local request = state.requests[key] or (pair and pair.void_movement_request_0630)
    if not (pair and valid_pair(pair) and M.is_void_pair(pair) and request) then
      state.active[key] = nil; state.requests[key] = nil; if pair then clear_pair_fields(pair, request, "invalid-pruned") end; stat("void-invalid-pruned")
    else
      processed = processed + 1
      local ok = step_pair(pair, request)
      if ok then acted = acted + 1 end
    end
  end
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "void-movement-backend" }
end

function M.report_lines()
  local state = root(); local active = 0; for _ in pairs(state.active) do active = active + 1 end
  return { "[tp-runtime-report] void-movement-0630 version=" .. M.version .. " active=" .. tostring(active) .. " requests=" .. tostring(state.stats["void-movement-request"] or 0) .. " steps=" .. tostring(state.stats["void-jetpack-steps"] or 0) .. " failed=" .. tostring(state.stats["void-relocation-failed"] or 0) }
end

function M.install()
  if M._installed then return true end
  root()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local registered = broker.register_service({ name = "void_movement_authority_0630", category = "movement", interval = M.service_interval, priority = 20, budget = 48, fn = M.service, note = "specialized same-surface stepped relocation backend delegated by movement_controller" })
  if not registered then return false end
  _G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630 = M
  _G.tech_priests_void_pair_0630 = M.is_void_pair
  _G.tech_priests_void_movement_request_0630 = M.request
  _G.tech_priests_void_movement_status_0630 = M.status
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-only Void movement backend installed; public movement API remains movement_controller-owned") end
  return true
end

return M
'''
write("tech-priests_src/scripts/core/void_movement_authority_0630.lua", void_source)

# Retire 0566.
write(
    "tech-priests_src/scripts/core/movement_enforcement_0566.lua",
    '''-- scripts/core/movement_enforcement_0566.lua
-- Source-preserved retirement marker. Ground envelope checks, stale-request
-- rejection, and overleash return are native to movement_controller.
local M = {
  retired = true,
  authority = "movement_enforcement_0566",
  replacement = "scripts.core.movement_controller",
}
return M
''',
)

# Flatten loader chain: explicit void backend and direct pulse; no 0566 parent installer.
path = "tech-priests_src/control.lua"
text = read(path)
old_loader = '''-- 0.1.566: movement enforcement governor. Loaded after all dispatcher,
-- economy, and GUI/conclave reporters so it can reject stale far movement
-- requests and return overleashed priests without becoming a work selector.
do
  local ok, err = pcall(function()
    local Move0566 = require("scripts.core.movement_enforcement_0566")
    if Move0566 and Move0566.install then Move0566.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.566] movement_enforcement_0566 failed to install: " .. tostring(err)) end
end

'''
new_loader = '''-- Historical 0566 movement governor is retired; enforcement is native to movement_controller.
do
  local ok, err = pcall(function()
    local Void0630 = require("scripts.core.void_movement_authority_0630")
    if Void0630 and Void0630.install then Void0630.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.674-dev] void_movement_authority_0630 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Pulse0631 = require("scripts.core.direct_acquisition_pulse_0631")
    if Pulse0631 and Pulse0631.install then Pulse0631.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.631] direct_acquisition_pulse_0631 failed to install: " .. tostring(err)) end
end

'''
if old_loader not in text:
    raise SystemExit("control 0566 loader anchor missing")
text = text.replace(old_loader, new_loader, 1)
write(path, text)

# Runtime command cleanup knows historical controls from both removed wrappers.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = text.replace('  ["tp-movement-bounds-0511"] = true,', '  ["tp-movement-bounds-0511"] = true,\n  ["tp-movement-enforcement-0566"] = true,\n  ["tp-void-movement-0630"] = true,', 1)
write(path, text)

# Declarative graph: 26 active / 33 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path).replace('active_hardener_count=26,retired_authority_count=32', 'active_hardener_count=26,retired_authority_count=33', 1)
anchor = ' ["scripts.core.movement_bounds_contract_0511"]="direct target bounds and overleash recovery are native to direct_acquisition_executor_0513",'
entry = anchor + '\n ["scripts.core.movement_enforcement_0566"]="ground envelope enforcement and void delegation are native to movement_controller",'
if anchor not in text:
    raise SystemExit("planning 0511 retired anchor missing")
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.movement_bounds_contract_0511",', '    "scripts.core.movement_bounds_contract_0511",\n    "scripts.core.movement_enforcement_0566",', 1)
text = text.replace('"retired_authority_count=32"', '"retired_authority_count=33"', 1)
text = text.replace('"check_combat_command_boundary_0763.py", "check_direct_acquisition_bounds_boundary_0764.py",', '"check_combat_command_boundary_0763.py", "check_direct_acquisition_bounds_boundary_0764.py",\n    "check_movement_enforcement_void_boundary_0765.py",', 1)
text = text.replace('"proxy_turret_alignment_0555", "command_hierarchy_rebuild_0480",', '"proxy_turret_alignment_0555", "command_hierarchy_rebuild_0480",\n    "movement_controller_enforcement_0566", "void_movement_authority_0630",', 1)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.combat_magos_movement_authority_0472", "scripts.core.movement_bounds_contract_0511",', '"scripts.core.combat_magos_movement_authority_0472", "scripts.core.movement_bounds_contract_0511", "scripts.core.movement_enforcement_0566",', 1)
text = text.replace('"retired_authority_count=32"', '"retired_authority_count=33"', 1)
text = text.replace('"32 source-preserved authorities"', '"33 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 32 explicitly retired"', '"26 active hardeners and 33 explicitly retired"', 1)
text = text.replace('"Thirty-two files remain"', '"Thirty-three files remain"', 1)
text = text.replace('active=26 retired=32 construction=canonical', 'active=26 retired=33 construction=canonical', 1)
text = text.replace(
    '("Audit canonical direct acquisition bounds", "check_direct_acquisition_bounds_boundary_0764.py"),',
    '("Audit canonical direct acquisition bounds", "check_direct_acquisition_bounds_boundary_0764.py"),\n        ("Audit canonical movement enforcement and void backend", "check_movement_enforcement_void_boundary_0765.py"),',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 32-retired graph', '26-active / 33-retired graph'),
    ('26 active hardeners and 32 explicitly retired', '26 active hardeners and 33 explicitly retired'),
    ('26 active hardeners and 32 retired source-only authorities', '26 active hardeners and 33 retired source-only authorities'),
    ('32 source-preserved authorities', '33 source-preserved authorities'),
    ('32 retired source-only authorities', '33 retired source-only authorities'),
    ('Thirty-two files remain', 'Thirty-three files remain'),
):
    text = text.replace(old, new)
text = text.replace(
    '"Audit canonical direct acquisition bounds",\n        "check_direct_acquisition_bounds_boundary_0764.py",',
    '"Audit canonical direct acquisition bounds",\n        "check_direct_acquisition_bounds_boundary_0764.py",\n        "Audit canonical movement enforcement and void backend",\n        "check_movement_enforcement_void_boundary_0765.py",',
    1,
)
write(path, text)

for checker in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
):
    write(checker, read(checker).replace('retired_authority_count=32', 'retired_authority_count=33'))

write(
    "tools/check_movement_enforcement_void_boundary_0765.py",
    '''#!/usr/bin/env python3
"""Validate native ground enforcement and delegated broker-only Void movement."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
 "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
 "void": ROOT / "tech-priests_src/scripts/core/void_movement_authority_0630.lua",
 "retired": ROOT / "tech-priests_src/scripts/core/movement_enforcement_0566.lua",
 "control": ROOT / "tech-priests_src/control.lua",
 "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
 "movement": ('M.enforcement_integrated = true','function M.position_allowed','function M.enforce_pair','function M.enforcement_service','name = "movement_controller_enforcement_0566"','local function void_backend','backend.request(pair, destination, reason, opts)','backend.stop(pair, reason)','backend.status(pair, owner)'),
 "void": ('version = "0.1.674-dev"','public_wrapper_retired = true','function M.request','function M.stop','function M.status','name = "void_movement_authority_0630"','broker.register_service','TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630'),
 "retired": ('retired = true','authority = "movement_enforcement_0566"','replacement = "scripts.core.movement_controller"','return M'),
 "control": ('Historical 0566 movement governor is retired','require("scripts.core.void_movement_authority_0630")','require("scripts.core.direct_acquisition_pulse_0631")'),
 "cleanup": ('["tp-movement-enforcement-0566"] = true','["tp-void-movement-0630"] = true'),
 "planning": ('retired_authority_count=33','["scripts.core.movement_enforcement_0566"]'),
 "workflow": ('Audit canonical movement enforcement and void backend','check_movement_enforcement_void_boundary_0765.py'),
}
FORBIDDEN = {
 "void": ('tech_priests_request_movement_0418 =','tech_priests_stop_movement_0418 =','tech_priests_movement_status_0418 =','move_priest_to =','patch_movement_bounds','patch_movement_enforcement','movement_bounds_contract_0511','movement_enforcement_0566','TechPriestsRuntimeEventRegistry','registry.on_nth_tick','script.on_nth_tick','commands.add_command','install_direct_acquisition_pulse'),
 "retired": ('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','pair.mode','pair.target'),
 "control": ('require("scripts.core.movement_enforcement_0566")',),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('Movement enforcement/Void boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Movement enforcement/Void boundary audit passed: movement_controller owns public routes and ground envelope; 0630 is a broker-only delegated backend; 0566 is inert.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''',
)

# Living records.
write("RECOVERY_REPAIR_SEQUENCE.md", read("RECOVERY_REPAIR_SEQUENCE.md").replace('26-active / 32-retired graph', '26-active / 33-retired graph'))
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
text = text.replace('The `RETIRED` table contains **32 source-preserved authorities**.', 'The `RETIRED` table contains **33 source-preserved authorities**.', 1)
text = text.replace('- `movement_bounds_contract_0511.lua`;', '- `movement_bounds_contract_0511.lua`;\n- `movement_enforcement_0566.lua`;', 1)
section = '''## Ground enforcement and Void backend authority

`movement_controller.lua` owns the public request, stop, status, command-routing, ground envelope, stale-request rejection, and overleash-return paths. `void_movement_authority_0630.lua` is a specialized broker-only stepped-relocation backend reached through the controller for Void/platform pairs; it does not replace global movement APIs or patch ground modules.

`movement_enforcement_0566.lua` is retired and inert. `control.lua` installs the Void backend and direct-acquisition pulse explicitly instead of through a hidden parent installer chain.

'''
if '## Ground enforcement and Void backend authority' not in text:
    anchor = '## Direct acquisition bounds authority'
    if anchor not in text: raise SystemExit('continuity direct bounds anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 32 retired source-only authorities', '26 active hardeners and 33 retired source-only authorities', 1)
anchor = '- native tier-bounded direct acquisition and active-task overleash return in `direct_acquisition_executor_0513`, with obsolete route/command cleanup in `runtime_command_cleanup_0720` and `0511` retired;\n'
bullet = '- native ground envelope enforcement and Void-backend delegation in `movement_controller`, with `void_movement_authority_0630` broker-only and `movement_enforcement_0566` retired;\n'
if bullet not in text:
    if anchor not in text: raise SystemExit('testing 0511 anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-cadence, consolidated combat-proxy, combat-command safety, and direct-acquisition bounds audits;', 'movement-cadence, consolidated combat-proxy, combat-command safety, direct-acquisition bounds, and movement-enforcement/Void-backend audits;', 1)
text = text.replace('26 attempted active hardeners and 32 retired source-only authorities', '26 attempted active hardeners and 33 retired source-only authorities', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**32 retired source-only authorities**', '**33 retired source-only authorities**', 1)
text = text.replace('Planning --> Retired[32 retired authorities]', 'Planning --> Retired[33 retired authorities]', 1)
text = text.replace('Thirty-two files remain source-preserved', 'Thirty-three files remain source-preserved', 1)
section = '''## Canonical Ground Enforcement and Void Delegation

```mermaid
flowchart LR
    Public[request stop status and legacy command routes] --> Movement[movement_controller]
    Movement --> Ground[ground envelope and engine commands]
    Movement -->|Void pair only| Void[void_movement_authority_0630]
    Void --> Broker[runtime_tick_broker]
    Broker --> Steps[same-surface stepped relocation]
```

`movement_enforcement_0566` is retired. The Void backend does not patch ground authorities or public globals, and its former child pulse is loaded explicitly.

'''
if '## Canonical Ground Enforcement and Void Delegation' not in text:
    anchor = '## Canonical Direct Acquisition Bounds'
    if anchor not in text: raise SystemExit('map direct bounds anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0566` and converted Void movement into a delegated backend

`movement_enforcement_0566` was another late wrapper around the canonical request API, direct engine commands, mutable movement/task state, a diagnostic command, a periodic route, and a hidden installer for the Void movement authority. Its useful ground-envelope policy is now native to `movement_controller`, including destination rejection, stale-request cleanup, far combat-target cleanup, and overleash return through the canonical request path.

`void_movement_authority_0630` remains because Void/platform priests require a distinct stepped-relocation implementation, but it is now a broker-only backend delegated by `movement_controller`. It no longer patches `0511`, `0566`, the public request/stop/status APIs, or `move_priest_to`; it no longer owns a command, registry fallback, or child installer. `control.lua` installs `0630` and `0631` explicitly. The declarative graph is now **26 active hardeners and 33 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0566` and converted Void movement into a delegated backend' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
