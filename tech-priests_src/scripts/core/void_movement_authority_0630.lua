-- scripts/core/void_movement_authority_0630.lua
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
