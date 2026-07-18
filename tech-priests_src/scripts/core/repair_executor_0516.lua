-- scripts/core/repair_executor_0516.lua
-- Tech Priests 0.1.674-dev recovery.
-- Dispatcher-owned repair executor with literal movement acceptance, shared
-- reservation ownership, exact repair-pack custody, atomic refund, verified
-- health mutation, and canonical order-queue terminal transitions.

local M = {
  version = "0.1.674-dev",
  storage_key = "repair_executor_0516",
  repair_range_sq = 16,
  pack_interval_ticks = 45,
  pair_cooldown_ticks = 20,
  target_cooldown_ticks = 120,
  reservation_ttl_ticks = 240,
  max_candidates = 160,
  max_pairs_per_service = 24,
}

local original_repair_target
local original_scheduler_try_repair

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function lower(value) return string.lower(tostring(value or "")) end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function result(fields)
  fields = fields or {}
  return {
    processed = tonumber(fields.processed) or 1,
    acted = tonumber(fields.acted) or 0,
    blocked = tonumber(fields.blocked) or 0,
    waiting = tonumber(fields.waiting) or 0,
    failed = tonumber(fields.failed) or 0,
    exhausted = fields.exhausted == true,
    detail = safe(fields.detail or ""),
  }
end

local function load_module(name, global_name)
  local loaded = rawget(_G, global_name)
  if loaded then return loaded end
  local ok, module = pcall(require, name)
  return ok and module or nil
end
local function order_queue()
  return load_module("scripts.core.order_queue_0469", "TECH_PRIESTS_ORDER_QUEUE_0469")
end
local function reservations()
  return load_module("scripts.core.work_reservations", "TechPriestsWorkReservations0601")
end
local function work_queue()
  return load_module("scripts.core.work_queue_authority", "TechPriestsWorkQueueAuthority0601")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    full_repair = true,
    spread_targets = true,
    stats = {},
    recent = {},
    cooldowns = {},
    cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.dispatcher_owned == nil then state.dispatcher_owned = true end
  if state.full_repair == nil then state.full_repair = true end
  if state.spread_targets == nil then state.spread_targets = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cooldowns = state.cooldowns or {}
  state.cursor = tonumber(state.cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = station_unit(pair),
    priest = priest_unit(pair),
    action = safe(action),
    detail = safe(detail),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function current_order(pair)
  local queue = pair and pair.order_queue_0469
  return pair and ((queue and queue.current) or pair.active_order_0469) or nil
end
local function repair_order(order)
  if type(order) ~= "table" then return false end
  local text = lower(order.kind) .. " " .. lower(order.type) .. " "
    .. lower(order.source) .. " " .. lower(order.purpose) .. " " .. lower(order.reason)
  return text:find("repair", 1, true) ~= nil
end
local function target_from(value, seen)
  if valid(value) then return value end
  if type(value) ~= "table" then return nil end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  for _, key in ipairs({ "target", "entity", "machine", "source", "selected", "current", "task" }) do
    local target = target_from(value[key], seen)
    if target then return target end
  end
  return nil
end
local function order_target(pair)
  local order = current_order(pair)
  if repair_order(order) then return target_from(order) end
  return nil
end
local function target_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  return tostring(entity.surface and entity.surface.index or "?") .. ":"
    .. tostring(entity.name or entity.type) .. ":"
    .. string.format("%.1f,%.1f", position.x or 0, position.y or 0)
end
local function missing_health(entity)
  if not (valid(entity) and entity.health and entity.max_health) then return 0 end
  local helper = rawget(_G, "get_repair_pack_useful_missing_health")
  if type(helper) == "function" then
    local ok, amount = pcall(helper, entity)
    if ok and tonumber(amount) then return math.max(0, tonumber(amount)) end
  end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end
local function damaged(entity)
  return valid(entity) and missing_health(entity) > 0.01
end
local function is_priest(entity)
  if not valid(entity) then return false end
  local helper = rawget(_G, "is_priest")
  if type(helper) == "function" then
    local ok, yes = pcall(helper, entity)
    if ok and yes == true then return true end
  end
  local name = lower(entity.name)
  return name:find("tech%-priest") ~= nil or name:find("tech_priest") ~= nil
end
local function eligible(pair, entity, allow_owned)
  if not (valid_pair(pair) and damaged(entity)) then return false, "not-damaged" end
  if is_priest(entity) then return false, "priest-excluded" end
  local proxy = rawget(_G, "PROXY_NAME") or "tech-priest-proxy-turret"
  if entity.name == proxy then return false, "proxy-excluded" end
  if entity.force and pair.station.force and entity.force ~= pair.station.force then
    return false, "wrong-force"
  end
  local radius = math.max(8, tonumber(pair.radius or pair.base_radius) or 32)
  if dist_sq(pair.station.position, entity.position) > radius * radius then
    return false, "outside-radius"
  end
  local key = target_key(entity)
  local cooldown = key and M.root().cooldowns[key]
  if cooldown and tonumber(cooldown) > now() then return false, "target-cooldown" end
  local shared = reservations()
  if not allow_owned and shared and type(shared.is_claimed) == "function" then
    local ok, claimed = pcall(shared.is_claimed, "repair", entity, pair)
    if ok and claimed == true then return false, "reserved" end
  end
  return true, "eligible"
end
local function score_target(pair, entity)
  local missing = missing_health(entity)
  local maximum = math.max(1, tonumber(entity.max_health) or 1)
  local ratio = missing / maximum
  return ratio * 10000 + missing * 2 - math.sqrt(dist_sq(pair.priest.position, entity.position)) * 12
end
local function find_target(pair, explicit)
  if valid(explicit) then
    local ok = eligible(pair, explicit, true)
    if ok then return explicit, "explicit" end
  end
  local existing = order_target(pair)
  if valid(existing) then
    local ok = eligible(pair, existing, true)
    if ok then return existing, "order" end
  end
  local queue = work_queue()
  if queue and type(queue.claim_nearest) == "function" then
    local ok, claimed = pcall(queue.claim_nearest, pair, "repair", { ttl = M.reservation_ttl_ticks })
    if ok and claimed and valid(claimed.target) then
      local allowed = eligible(pair, claimed.target, true)
      if allowed then return claimed.target, "work-queue" end
    end
  end
  local radius = math.max(8, tonumber(pair.radius or pair.base_radius) or 32)
  local position = pair.station.position
  local ok, entities = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      limit = M.max_candidates,
    })
  end)
  if not (ok and entities) then return nil, "scan-failed" end
  local best, best_score
  for _, entity in ipairs(entities) do
    local allowed = eligible(pair, entity, false)
    if allowed then
      local score = score_target(pair, entity)
      if not best_score or score > best_score then best, best_score = entity, score end
    end
  end
  return best, best and "bounded-scan" or "no-eligible-target"
end

local function inventory_sources(pair)
  local out, seen = {}, {}
  local function add(inv, label)
    if not (inv and inv.valid) then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = { inv = inv, label = label or "station" }
  end
  local steward = rawget(_G, "tech_priests_inventory_steward_sources_for_pair")
  if type(steward) == "function" then
    local ok, sources = pcall(steward, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do
        if source then add(source.inv or source.inventory, source.label or source.source or source.kind) end
      end
    end
  end
  local getter = rawget(_G, "get_station_inventory")
  if type(getter) == "function" then
    local ok, inv = pcall(getter, pair.station)
    if ok then add(inv, "station") end
  end
  if defines and defines.inventory and pair.station.get_inventory then
    local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
    if ok then add(inv, "station-chest") end
  end
  return out
end
local function inventory_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end
local function pack_count(pair)
  local total = 0
  for _, source in ipairs(inventory_sources(pair)) do
    total = total + inventory_count(source.inv, "repair-pack")
  end
  return total
end
local function remove_pack(pair)
  for _, source in ipairs(inventory_sources(pair)) do
    if inventory_count(source.inv, "repair-pack") > 0 then
      local ok, removed = pcall(function() return source.inv.remove({ name = "repair-pack", count = 1 }) end)
      if ok and tonumber(removed) == 1 then return true, source.label end
    end
  end
  return false, "no-pack-source"
end
local function atomic_return(pair, count, reason)
  local deposit = rawget(_G, "tech_priests_safe_deposit_item")
  if type(deposit) ~= "function" then return false, "atomic-storage-unavailable" end
  local ok, accepted, why, inserted = pcall(deposit, pair, "repair-pack", count, reason)
  inserted = tonumber(inserted) or (accepted == true and count or 0)
  return ok and accepted == true and inserted == count, why
end

local function claim_target(pair, target)
  local shared = reservations()
  if not (shared and type(shared.claim) == "function") then
    return false, "reservation-authority-unavailable"
  end
  local ok, accepted = pcall(shared.claim, "repair", target, pair, M.reservation_ttl_ticks, {
    surface_index = target.surface and target.surface.index,
    force_index = target.force and target.force.index,
  })
  return ok and accepted == true, ok and "claimed" or safe(accepted)
end
local function release_target(pair, target)
  local shared = reservations()
  if shared and type(shared.release) == "function" and valid(target) then
    pcall(shared.release, "repair", target, pair)
  end
end
local function request_move(pair, target, reason)
  local move = rawget(_G, "tech_priests_request_movement_0418")
  if type(move) ~= "function" then return false, "movement-authority-unavailable" end
  local ok, accepted = pcall(move, pair, target.position, reason or "repair-executor-0516", {
    radius = 1.4,
    owner = "repair_executor_0516",
    priority = 820,
    ttl = 900,
    distraction = defines and defines.distraction and defines.distraction.none,
  })
  return ok and accepted == true, ok and safe(accepted) or "movement-error:" .. safe(accepted)
end

local function clear_target_state(pair, phase, reason)
  local state = pair.repair_0516 or {}
  local target = valid(state.target) and state.target or nil
  if target then release_target(pair, target) end
  state.phase = phase or "none"
  state.last_blocker = reason
  state.target = nil
  state.target_name = nil
  state.target_unit = nil
  state.target_source = nil
  state.started_tick = nil
  state.due_tick = nil
  state.distance = nil
  state.missing = nil
  pair.repair_0516 = state
  if pair.target == target then pair.target = nil end
end
local function finish_queue(pair, why)
  local order = current_order(pair)
  if not repair_order(order) then return true, "no-repair-order" end
  local queue = order_queue()
  if not (queue and type(queue.complete_current) == "function") then
    return false, "order-queue-unavailable"
  end
  local ok, accepted, result_why = pcall(queue.complete_current, pair, why or "repair-complete-0516", "repair-pack")
  return ok and accepted == true, ok and result_why or accepted
end
local function fail_queue(pair, why)
  local order = current_order(pair)
  if not repair_order(order) then return true, "no-repair-order" end
  local queue = order_queue()
  if not (queue and type(queue.fail_current) == "function") then
    return false, "order-queue-unavailable"
  end
  local ok, accepted, result_why = pcall(queue.fail_current, pair, why or "repair-failed-0516")
  return ok and accepted == true, ok and result_why or accepted
end
local function terminal_complete(pair, target, reason)
  local state = pair.repair_0516 or {}
  release_target(pair, target)
  local key = target_key(target)
  if key then M.root().cooldowns[key] = now() + M.target_cooldown_ticks end
  pair.next_repair_tick_0516 = now() + M.pair_cooldown_ticks
  local queue_ok, queue_why = finish_queue(pair, reason)
  if not queue_ok then
    state.phase = "completion-blocked"
    state.last_blocker = safe(queue_why)
    state.target = target
    pair.repair_0516 = state
    return result({ blocked = 1, detail = "order-completion-blocked:" .. safe(queue_why) })
  end
  clear_target_state(pair, "complete", nil)
  pair.mode = "idle"
  record(pair, "complete", reason)
  return result({ acted = 1, detail = "complete" })
end

local function refund_custody(pair, reason)
  local custody = pair.repair_pack_custody_0516
  if not custody then return true, "no-custody" end
  local ok, why = atomic_return(pair, tonumber(custody.count) or 1, reason or "repair-pack-refund-0516")
  if not ok then
    custody.phase = "return-pack"
    custody.last_blocker = safe(why)
    custody.updated_tick = now()
    record(pair, "refund-blocked", why)
    return false, why
  end
  pair.repair_pack_custody_0516 = nil
  stat("packs-refunded")
  record(pair, "refund-complete", reason)
  return true, "refunded"
end
local function apply_held_pack(pair)
  local custody = pair.repair_pack_custody_0516
  if not custody then return true, "no-custody" end
  if custody.phase == "return-pack" then return refund_custody(pair, "repair-pack-refund-retry-0516") end
  local target = custody.target
  if not valid(target) then
    custody.phase = "return-pack"
    return refund_custody(pair, "repair-pack-target-invalid-0516")
  end
  local expected = tonumber(custody.expected_health) or tonumber(target.health) or 0
  local current = tonumber(target.health) or 0
  if current >= expected - 0.001 then
    pair.repair_pack_custody_0516 = nil
    local state = pair.repair_0516 or {}
    state.packs_used = (tonumber(state.packs_used) or 0) + 1
    state.last_restore = math.max(0, expected - (tonumber(custody.before_health) or expected))
    state.last_pack_tick = now()
    state.due_tick = now() + M.pack_interval_ticks
    pair.repair_0516 = state
    stat("custody-reconciled")
    return true, "already-applied"
  end
  local before = tonumber(custody.before_health) or current
  local ok = pcall(function() target.health = expected end)
  local after = tonumber(target.health) or before
  if not ok or after <= before + 0.001 then
    custody.phase = "return-pack"
    custody.last_blocker = "health-write-failed"
    local refunded = refund_custody(pair, "repair-health-write-failed-0516")
    return false, refunded and "health-write-failed-refunded" or "health-write-failed-refund-blocked"
  end
  pair.repair_pack_custody_0516 = nil
  local state = pair.repair_0516 or {}
  state.packs_used = (tonumber(state.packs_used) or 0) + 1
  state.last_restore = after - before
  state.last_pack_tick = now()
  state.due_tick = now() + M.pack_interval_ticks
  pair.repair_0516 = state
  stat("packs-applied")
  record(pair, "pack-applied", "restored=" .. safe(after - before))
  return true, "pack-applied"
end
local function begin_pack_transaction(pair, target)
  local removed, source = remove_pack(pair)
  if not removed then return false, "consume-failed" end
  local before = tonumber(target.health) or 0
  local expected = math.min(tonumber(target.max_health) or before, before + (tonumber(rawget(_G, "REPAIR_AMOUNT_PER_PACK")) or 75))
  pair.repair_pack_custody_0516 = {
    version = M.version,
    phase = "pack-held",
    item = "repair-pack",
    count = 1,
    target = target,
    target_unit = target.unit_number,
    before_health = before,
    expected_health = expected,
    source = source,
    created_tick = now(),
    updated_tick = now(),
  }
  stat("packs-removed")
  return apply_held_pack(pair)
end

function M.active(pair)
  if not pair then return false end
  if pair.repair_pack_custody_0516 then return true end
  local state = pair.repair_0516
  if state and state.phase and state.phase ~= "none" and state.phase ~= "complete" and state.phase ~= "failed" then
    return true
  end
  return repair_order(current_order(pair))
end

function M.submit_or_assign_repair_task(pair, target, reason)
  if not valid_pair(pair) then return false, "invalid-pair" end
  if not valid(target) then target = select(1, find_target(pair, nil)) end
  if not valid(target) then return false, "no-target" end
  local queue = order_queue()
  if not (queue and type(queue.submit) == "function") then return false, "order-queue-unavailable" end
  local ok_submit, accepted, why, order = pcall(queue.submit, pair, {
    kind = "repair",
    item = "repair-pack",
    target = target,
    priority = 800,
    source = "repair_executor_0516",
    purpose = reason or "repair",
    reason = reason or "repair",
  })
  if not ok_submit then
    record(pair, "order-submit-error", accepted)
    return false, "order-submit-error:" .. safe(accepted)
  end
  if accepted == true or why == "duplicate-merged" then
    record(pair, "order-accepted", why)
    return true, why, order
  end
  record(pair, "order-rejected", why)
  return false, why, order
end

function M.service_pair(pair, reason, forced_target)
  local root = M.root()
  if root.enabled == false then return result({ processed = 0, detail = "disabled" }) end
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  local state = pair.repair_0516 or { phase = "none" }
  pair.repair_0516 = state
  state.version = M.version
  state.last_service_tick = now()
  state.last_reason = safe(reason or "service")

  if pair.repair_pack_custody_0516 then
    local custody_ok, custody_why = apply_held_pack(pair)
    if not custody_ok then
      return result({ blocked = 1, detail = custody_why })
    end
  end

  local target = valid(forced_target) and forced_target or (valid(state.target) and state.target) or order_target(pair)
  if not valid(target) then target, state.target_source = find_target(pair, nil) end
  if not valid(target) then
    state.phase = pack_count(pair) > 0 and "no-target" or "need-item"
    state.last_blocker = state.target_source or "no-target"
    return result({ blocked = state.phase == "need-item" and 1 or 0, waiting = state.phase == "no-target" and 1 or 0, detail = state.last_blocker })
  end

  local allowed, why = eligible(pair, target, true)
  if not allowed then
    local queue_ok = fail_queue(pair, "repair-target-invalid:" .. safe(why))
    clear_target_state(pair, "failed", why)
    pair.mode = "idle"
    return result({ failed = queue_ok and 1 or 0, blocked = queue_ok and 0 or 1, detail = why })
  end

  state.target = target
  state.target_name = target.name
  state.target_unit = target.unit_number
  state.missing = missing_health(target)
  pair.target = target

  if state.phase == "completion-blocked" or state.missing <= 0.01 then
    return terminal_complete(pair, target, state.phase == "completion-blocked" and "repair-completion-retry-0516" or "repair-complete-0516")
  end

  local claimed, claim_why = claim_target(pair, target)
  if not claimed then
    state.phase = "target-reserved"
    state.last_blocker = claim_why
    return result({ blocked = 1, detail = "target-reserved:" .. safe(claim_why) })
  end

  if pack_count(pair) <= 0 then
    release_target(pair, target)
    state.phase = "need-item"
    state.last_blocker = "no-repair-pack"
    pair.mode = "missing-repair-supplies"
    return result({ blocked = 1, detail = "no-repair-pack" })
  end

  local distance = dist_sq(pair.priest.position, target.position)
  state.distance = math.sqrt(distance)
  if distance > M.repair_range_sq then
    local moved, move_why = request_move(pair, target, "repair-executor-0516-walk-to-target")
    if not moved then
      release_target(pair, target)
      state.phase = "movement-request-failed"
      state.last_blocker = move_why
      pair.mode = "repair-movement-failed"
      return result({ failed = 1, detail = "movement-request-failed:" .. safe(move_why) })
    end
    state.phase = "walk-to-target"
    pair.mode = "moving-to-repair"
    return result({ waiting = 1, detail = "walk-to-target" })
  end

  state.phase = "repair-target"
  state.started_tick = state.started_tick or now()
  state.due_tick = state.due_tick or (now() + M.pack_interval_ticks)
  pair.mode = "repairing"
  if now() < state.due_tick then
    return result({ waiting = 1, detail = "repair-progress" })
  end

  local applied, apply_why = begin_pack_transaction(pair, target)
  if not applied then
    release_target(pair, target)
    state.phase = pair.repair_pack_custody_0516 and "refund-blocked" or "health-write-failed"
    state.last_blocker = apply_why
    return result({ blocked = pair.repair_pack_custody_0516 and 1 or 0, failed = pair.repair_pack_custody_0516 and 0 or 1, detail = apply_why })
  end

  state.missing = missing_health(target)
  if state.missing <= 0.01 or root.full_repair == false then
    return terminal_complete(pair, target, "repair-complete-0516")
  end
  return result({ acted = 1, detail = "repair-pack-applied" })
end

function M.service_repair_bucket(reason, budget)
  local pairs = {}
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and M.active(pair) then pairs[#pairs + 1] = pair end
  end
  table.sort(pairs, function(a, b) return (station_unit(a) or 0) < (station_unit(b) or 0) end)
  if #pairs == 0 then return result({ processed = 0, detail = "empty-repair-bucket" }) end
  local root = M.root()
  local limit = math.max(1, math.floor(tonumber(budget) or M.max_pairs_per_service))
  local processed, acted, blocked, waiting, failed = 0, 0, 0, 0, 0
  for offset = 1, math.min(limit, #pairs) do
    local index = ((root.cursor + offset - 1) % #pairs) + 1
    local one = M.service_pair(pairs[index], reason or "repair-bucket")
    processed = processed + (tonumber(one.processed) or 0)
    acted = acted + (tonumber(one.acted) or 0)
    blocked = blocked + (tonumber(one.blocked) or 0)
    waiting = waiting + (tonumber(one.waiting) or 0)
    failed = failed + (tonumber(one.failed) or 0)
  end
  root.cursor = (root.cursor + math.min(limit, #pairs)) % #pairs
  return result({ processed = processed, acted = acted, blocked = blocked, waiting = waiting, failed = failed, exhausted = #pairs > limit, detail = "repair-bucket" })
end

local function wrap_legacy_repair_target()
  if original_repair_target or type(rawget(_G, "repair_target")) ~= "function" then return true end
  original_repair_target = rawget(_G, "repair_target")
  _G.TECH_PRIESTS_0516_PRE_REPAIR_TARGET = original_repair_target
  _G.repair_target = function(pair, target, ...)
    if M.root().enabled == false or not valid_pair(pair) then
      return original_repair_target(pair, target, ...)
    end
    local accepted, why = M.submit_or_assign_repair_task(pair, target, "legacy-repair-adopted-0516")
    if not accepted then return false, why end
    local execution = M.service_pair(pair, "legacy-repair-adopted-0516", target)
    return execution.acted > 0 or execution.waiting > 0, execution.detail
  end
  return true
end
local function wrap_scheduler()
  local ok, scheduler = pcall(require, "scripts.core.task_scheduler")
  if not (ok and scheduler and type(scheduler.try_repair) == "function") or original_scheduler_try_repair then return true end
  original_scheduler_try_repair = scheduler.try_repair
  scheduler.TECH_PRIESTS_0516_PRE_TRY_REPAIR = original_scheduler_try_repair
  scheduler.try_repair = function(pair)
    if M.root().enabled == false or not valid_pair(pair) then return original_scheduler_try_repair(pair) end
    local target = select(1, find_target(pair, nil))
    if not valid(target) then return false end
    local accepted = M.submit_or_assign_repair_task(pair, target, "scheduler-repair-adapter-0516")
    return accepted == true
  end
  return true
end
local function patch_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.repair_executor_0516_recovery_wrapped then return true end
  local previous = diagnostics.pair_dump_lines
  diagnostics.repair_executor_0516_recovery_wrapped = true
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 REPAIR-EXECUTOR-0516 version=" .. M.version
      .. " enabled=" .. safe(root.enabled)
      .. " packs_removed=" .. safe(root.stats["packs-removed"] or 0)
      .. " packs_applied=" .. safe(root.stats["packs-applied"] or 0)
      .. " packs_refunded=" .. safe(root.stats["packs-refunded"] or 0)
      .. " refund_blocked=" .. safe(root.stats["refund-blocked"] or 0)
      .. " complete=" .. safe(root.stats.complete or 0)
    return lines
  end
  return true
end
local function remove_command()
  if commands and commands.remove_command then pcall(commands.remove_command, "tp-repair-executor-0516") end
end

function M.install()
  M.root()
  wrap_legacy_repair_target()
  wrap_scheduler()
  patch_diagnostics()
  remove_command()
  _G.TechPriestsRepairExecutor0516 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] dispatcher-owned repair executor installed; direct cadence and command fallbacks removed")
  end
  return true
end

return M
