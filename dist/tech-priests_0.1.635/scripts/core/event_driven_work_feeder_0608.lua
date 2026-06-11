-- scripts/core/event_driven_work_feeder_0608.lua
-- Tech Priests 0.1.608
-- Future Efficiency Candidate E, bounded pass:
-- Events feed existing authorities; they do not execute priest work.
--
-- Authority boundary:
--   - Work Queue finds/records jobs.
--   - Reservation claims jobs.
--   - Order Queue executes jobs.
-- This module is a leaf feeder beneath the event registry. It only converts
-- high-signal world events into work-queue submissions and telemetry counters.

local M = {}
M.version = "0.1.616"
M.storage_key = "event_driven_work_feeder_0608"
M.repair_event_ttl = 900
M.max_event_damage_per_tick = 48
M.directed_wake_radius = 128
M.directed_wake_ttl = 900
M.construction_event_ttl = 60 * 10
M.sanctify_event_ttl = 60 * 20
M.pickup_event_ttl = 60 * 6

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function metric(k,n)
  local fn = rawget(_G, "tech_priests_runtime_metric_0606")
  if fn then pcall(fn, k, n or 1) end
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      repair_damage_enabled = true,
      dirty_event_enabled = true,
      construction_event_enabled = true,
      sanctify_event_enabled = true,
      pickup_event_enabled = true,
      stats = {},
      recent = {},
      damage_tick = -1,
      damage_count_this_tick = 0,
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.repair_damage_enabled == nil then r.repair_damage_enabled = true end
  if r.dirty_event_enabled == nil then r.dirty_event_enabled = true end
  if r.construction_event_enabled == nil then r.construction_event_enabled = true end
  if r.sanctify_event_enabled == nil then r.sanctify_event_enabled = true end
  if r.pickup_event_enabled == nil then r.pickup_event_enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function remember(action, detail)
  local r = M.root()
  r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), detail = tostring(detail or "") }
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function missing_health(entity)
  if not (valid(entity) and entity.health and entity.max_health) then return 0 end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end

local function is_repair_candidate(entity)
  if not (valid(entity) and entity.health and entity.max_health) then return false end
  if missing_health(entity) <= 0.01 then return false end
  local name = lower(entity.name)
  if name:find("tech%-priest") or name:find("tech_priest") or name == "tech-priest-proxy-turret" then return false end
  return true
end

local function repair_priority(entity)
  local missing = missing_health(entity)
  local maxh = tonumber(entity.max_health) or 1
  local ratio = maxh > 0 and missing / maxh or 0
  local type_bonus = 0
  local t = lower(entity.type)
  local n = lower(entity.name)
  if t:find("turret",1,true) or n:find("turret",1,true) then type_bonus = 220
  elseif t == "wall" or t == "gate" or n:find("wall",1,true) then type_bonus = 200
  elseif t:find("assembling",1,true) or t:find("furnace",1,true) then type_bonus = 100
  elseif t:find("generator",1,true) or t:find("boiler",1,true) or t:find("reactor",1,true) then type_bonus = 90 end
  return math.floor(ratio * 10000 + missing * 2 + type_bonus)
end

local function target_force_index(target)
  if valid(target) and target.force then return target.force.index end
  return 0
end

local function target_surface_index(target)
  if valid(target) and target.surface then return target.surface.index end
  return 0
end

local function event_submit(category, target, opts)
  opts = opts or {}
  local okQ, Q = pcall(require, "scripts.core.work_queue_authority")
  if not (okQ and Q and type(Q.submit) == "function") then
    stat("event_submit_unavailable")
    metric("event_submit_unavailable", 1)
    return false, "queue-unavailable"
  end
  local ok, why = Q.submit(category, target, opts)
  stat("event_" .. tostring(category) .. "_seen")
  metric("event_" .. tostring(category) .. "_seen", 1)
  if ok then
    stat("event_" .. tostring(category) .. "_submitted")
    metric("event_" .. tostring(category) .. "_submitted", 1)
    if why == "duplicate" then
      stat("event_" .. tostring(category) .. "_duplicate_folded")
      metric("event_" .. tostring(category) .. "_duplicate_folded", 1)
    end
  else
    stat("event_" .. tostring(category) .. "_submit_failed")
    metric("event_" .. tostring(category) .. "_submit_failed", 1)
  end
  return ok, why
end

local function is_construction_ghost(entity)
  return valid(entity) and (entity.type == "entity-ghost" or entity.type == "tile-ghost")
end

local function is_sanctify_candidate(entity)
  if not valid(entity) then return false end
  if is_construction_ghost(entity) then return false end
  if _G.is_consecration_target then local ok, res = pcall(_G.is_consecration_target, entity); if ok then return res == true end end
  local t = lower(entity.type)
  return t:find("assembling",1,true) or t:find("furnace",1,true) or t:find("mining",1,true) or t:find("generator",1,true) or t == "boiler" or t == "reactor" or t == "lab" or t == "rocket-silo"
end

local function is_pickup_candidate(entity)
  return valid(entity) and (entity.type == "item-entity" or entity.type == "simple-entity-with-owner")
end


local function budget_damage_event()
  local r = M.root()
  local tick = now()
  if r.damage_tick ~= tick then
    r.damage_tick = tick
    r.damage_count_this_tick = 0
  end
  r.damage_count_this_tick = (r.damage_count_this_tick or 0) + 1
  if r.damage_count_this_tick > M.max_event_damage_per_tick then
    stat("damage_events_budget_skipped")
    metric("event_repair_budget_skipped", 1)
    return false
  end
  return true
end


local function same_surface_force(pair, entity)
  if not (valid(pair and pair.station) and valid(entity)) then return false end
  if pair.station.surface ~= entity.surface then return false end
  if pair.station.force and entity.force and pair.station.force.name ~= entity.force.name then return false end
  return true
end

local function find_nearest_pair(entity, radius)
  if not valid(entity) then return nil, "invalid-entity" end
  local pair_map_table = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  local best, best_d2
  local pos = entity.position or { x = 0, y = 0 }
  local r2 = (tonumber(radius or M.directed_wake_radius) or M.directed_wake_radius) ^ 2
  for _, pair in pairs(pair_map_table) do
    if same_surface_force(pair, entity) and valid(pair.priest) then
      local spos = pair.station.position or { x = 0, y = 0 }
      local dx, dy = (spos.x or 0) - (pos.x or 0), (spos.y or 0) - (pos.y or 0)
      local d2 = dx * dx + dy * dy
      if d2 <= r2 and (not best_d2 or d2 < best_d2) then
        best, best_d2 = pair, d2
      end
    end
  end
  if best then return best, best_d2 end
  return nil, "none-in-radius"
end

local function clear_repair_negative_knowledge(entity)
  -- This is intentionally a best-effort hook into existing negative/dirty authorities.
  -- It does not create a new cache. A damage event proves that the local region is no
  -- longer "nothing useful here" for repair-style work, so stale cool-downs should not
  -- suppress the next targeted pass.
  local cleared = 0
  local ok570, Neg = pcall(require, "scripts.core.efficiency_economy_0570")
  if ok570 and Neg and type(Neg.clear_near_entity) == "function" then
    local ok, n = pcall(Neg.clear_near_entity, entity, "repair-damage-event-0608")
    if ok then cleared = cleared + (tonumber(n) or 0) end
  end
  local ok579, Index = pcall(require, "scripts.core.efficiency_economy_0579")
  if ok579 and Index and type(Index.mark_entity_dirty) == "function" then
    pcall(Index.mark_entity_dirty, entity, "repair-damage-event-0608")
  end
  stat("negative_clears_attempted")
  if cleared > 0 then stat("negative_cleared", cleared); metric("negative_cache_clears_from_event", cleared) end
  return cleared
end

local function mark_existing_dirty_authorities(entity, reason)
  -- 0.1.613: Generic event-driven dirty invalidation. This is deliberately a
  -- feeder into the existing 0579/0570 authorities, not a new cache or scheduler.
  if not valid(entity) then return 0 end
  local touched = 0
  local ok579, Index = pcall(require, "scripts.core.efficiency_economy_0579")
  if ok579 and Index and type(Index.mark_entity_dirty) == "function" then
    local ok = pcall(Index.mark_entity_dirty, entity, tostring(reason or "event-dirty-0613"))
    if ok then touched = touched + 1 end
  end
  local ok570, Neg = pcall(require, "scripts.core.efficiency_economy_0570")
  if ok570 and Neg and type(Neg.clear_near_entity) == "function" then
    local ok, n = pcall(Neg.clear_near_entity, entity, tostring(reason or "event-dirty-0613"))
    if ok and (tonumber(n) or 0) > 0 then
      touched = touched + (tonumber(n) or 0)
      stat("dirty_event_negative_cleared", tonumber(n) or 0)
    end
  end
  return touched
end

function M.handle_entity_changed(event, reason)
  local r = M.root()
  if r.enabled == false or r.dirty_event_enabled == false then return end
  local entity = event and event.entity
  if not valid(entity) then stat("dirty_event_invalid"); return end
  stat("dirty_event_seen")
  metric("event_dirty_seen", 1)
  local touched = mark_existing_dirty_authorities(entity, reason or "entity-changed-0613")
  if touched > 0 then
    stat("dirty_event_touched", touched)
    metric("event_dirty_touched_existing_authorities", touched)
  end
  remember("dirty-event", tostring(reason or "entity-changed-0613") .. " " .. safe(entity.name) .. "#" .. safe(entity.unit_number) .. " touched=" .. safe(touched))
end

function M.directed_wake_for_repair(entity)
  if not valid(entity) then return false, "invalid-entity" end
  local pair, why = find_nearest_pair(entity, M.directed_wake_radius)
  if not pair then
    stat("directed_wake_no_pair")
    metric("directed_wake_no_pair", 1)
    return false, why or "no-pair"
  end
  local tick = now()
  if tonumber(pair._tp_repair_wake_until_0608 or 0) > tick then
    stat("directed_wake_already_awake")
    metric("directed_wake_already_awake", 1)
    return true, "already-awake"
  end
  pair._tp_repair_wake_until_0608 = tick + M.directed_wake_ttl
  pair._tp_bucket_dirty_0600 = true
  pair.last_directed_repair_wake_0608 = {
    tick = tick,
    target = valid(entity) and entity.unit_number or nil,
    name = valid(entity) and entity.name or nil,
  }
  local okB, Buckets = pcall(require, "scripts.core.pair_bucket_registry")
  if okB and Buckets then
    if type(Buckets.mark_dirty) == "function" then pcall(Buckets.mark_dirty, pair, "repair-damage-event-0608") end
    if type(Buckets.force_bucket) == "function" then pcall(Buckets.force_bucket, pair, "repair", M.directed_wake_ttl, "repair-damage-event-0608") end
  end
  local ok599, Sleep = pcall(require, "scripts.core.efficiency_economy_0599")
  if ok599 and Sleep and type(Sleep.wake_pair) == "function" then pcall(Sleep.wake_pair, pair, "repair-damage-event-0608") end
  stat("directed_wake_issued")
  metric("directed_wake_issued", 1)
  return true, "issued"
end


function M.directed_wake_for_category(entity, category, reason)
  if category == "repair" then return M.directed_wake_for_repair(entity) end
  if not valid(entity) then return false, "invalid-entity" end
  local pair, why = find_nearest_pair(entity, M.directed_wake_radius)
  if not pair then
    stat("directed_wake_" .. tostring(category) .. "_no_pair")
    metric("directed_wake_" .. tostring(category) .. "_no_pair", 1)
    return false, why or "no-pair"
  end
  local Buckets = rawget(_G, "TechPriestsPairBucketRegistry0600")
  if not Buckets then pcall(function() Buckets = require("scripts.core.pair_bucket_registry") end) end
  if Buckets and type(Buckets.force_bucket) == "function" then pcall(Buckets.force_bucket, pair, category, M.directed_wake_ttl, tostring(reason or category .. "-event-0616")) end
  if Buckets and type(Buckets.mark_dirty) == "function" then pcall(Buckets.mark_dirty, pair, tostring(reason or category .. "-event-0616")) end
  local ok599, Sleep = pcall(require, "scripts.core.efficiency_economy_0599")
  if ok599 and Sleep and type(Sleep.wake_pair) == "function" then pcall(Sleep.wake_pair, pair, tostring(reason or category .. "-event-0616")) end
  stat("directed_wake_" .. tostring(category) .. "_issued")
  metric("directed_wake_" .. tostring(category) .. "_issued", 1)
  return true, "issued"
end

function M.handle_entity_built_for_work(event, reason)
  local r = M.root()
  if r.enabled == false then return end
  local entity = event and (event.created_entity or event.entity or event.destination)
  if not valid(entity) then return end
  if is_construction_ghost(entity) and r.construction_event_enabled ~= false then
    local ok, why = event_submit("construction", entity, { priority = 260, ttl = M.construction_event_ttl, source = "event_driven_work_feeder_0608:" .. tostring(reason or "ghost-built") })
    if ok then M.directed_wake_for_category(entity, "construction", "construction-ghost-event-0616") end
    remember("construction-submit", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(why))
    return
  end
  if is_sanctify_candidate(entity) and r.sanctify_event_enabled ~= false then
    local ok, why = event_submit("sanctify", entity, { priority = 80, ttl = M.sanctify_event_ttl, source = "event_driven_work_feeder_0608:" .. tostring(reason or "machine-built") })
    if ok then M.directed_wake_for_category(entity, "sanctify", "sanctify-machine-event-0616") end
    remember("sanctify-submit", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(why))
  end
end

function M.handle_pickup_candidate(event, reason)
  local r = M.root()
  if r.enabled == false or r.pickup_event_enabled == false then return end
  local entity = event and (event.entity or event.created_entity)
  if not is_pickup_candidate(entity) then stat("pickup_event_ignored"); return end
  local ok, why = event_submit("pickup", entity, { priority = 120, ttl = M.pickup_event_ttl, source = "event_driven_work_feeder_0608:" .. tostring(reason or "pickup-event") })
  if ok then M.directed_wake_for_category(entity, "pickup", "pickup-event-0616") end
  remember("pickup-submit", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(why))
end

function M.handle_entity_damaged(event)
  local r = M.root()
  if r.enabled == false or r.repair_damage_enabled == false then return end
  if not budget_damage_event() then return end
  local entity = event and event.entity
  if not is_repair_candidate(entity) then stat("damage_ignored"); return end
  local okQ, Q = pcall(require, "scripts.core.work_queue_authority")
  if not (okQ and Q and type(Q.submit) == "function") then stat("submit_unavailable"); return end
  local ok, why = Q.submit("repair", entity, {
    priority = repair_priority(entity),
    ttl = M.repair_event_ttl,
    source = "event_driven_work_feeder_0608:on_entity_damaged",
  })
  stat("damage_events_seen")
  metric("event_repair_candidates", 1)
  local negative_cleared = clear_repair_negative_knowledge(entity)
  local woke, wake_why = M.directed_wake_for_repair(entity)
  if woke then remember("directed-wake", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(wake_why) .. " negative_cleared=" .. safe(negative_cleared)) end
  if ok then
    stat("repair_event_submitted")
    metric("event_repair_submitted", 1)
    if why == "duplicate" then
      stat("repair_event_duplicate_folded")
      metric("event_repair_duplicate_folded", 1)
    end
    remember("repair-submit", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(why))
  else
    stat("repair_event_submit_failed")
    metric("event_repair_submit_failed", 1)
    remember("repair-submit-failed", safe(entity.name) .. "#" .. safe(entity.unit_number) .. " why=" .. safe(why))
  end
end

function M.report_lines()
  local r = M.root()
  return {
    "[tp-runtime-report] event-driven-feeder-0608 enabled=" .. safe(r.enabled)
      .. " repair_damage=" .. safe(r.repair_damage_enabled)
      .. " dirty_events=" .. safe(r.dirty_event_enabled)
      .. " damage_seen=" .. safe(r.stats.damage_events_seen or 0)
      .. " repair_submitted=" .. safe(r.stats.repair_event_submitted or 0)
      .. " duplicate_folded=" .. safe(r.stats.repair_event_duplicate_folded or 0)
      .. " failed=" .. safe(r.stats.repair_event_submit_failed or 0)
      .. " budget_skipped=" .. safe(r.stats.damage_events_budget_skipped or 0)
      .. " directed_wake=" .. safe(r.stats.directed_wake_issued or 0)
      .. " wake_already=" .. safe(r.stats.directed_wake_already_awake or 0)
      .. " wake_no_pair=" .. safe(r.stats.directed_wake_no_pair or 0)
      .. " negative_cleared=" .. safe(r.stats.negative_cleared or 0)
      .. " dirty_seen=" .. safe(r.stats.dirty_event_seen or 0)
      .. " dirty_touched=" .. safe(r.stats.dirty_event_touched or 0)
      .. " dirty_invalid=" .. safe(r.stats.dirty_event_invalid or 0)
      .. " construction_submitted=" .. safe(r.stats.event_construction_submitted or 0)
      .. " sanctify_submitted=" .. safe(r.stats.event_sanctify_submitted or 0)
      .. " pickup_submitted=" .. safe(r.stats.event_pickup_submitted or 0)
      .. " wake_construction=" .. safe(r.stats.directed_wake_construction_issued or 0)
      .. " wake_sanctify=" .. safe(r.stats.directed_wake_sanctify_issued or 0)
      .. " wake_pickup=" .. safe(r.stats.directed_wake_pickup_issued or 0)
  }
end

function M.install()
  M.root()
  _G.TechPriestsEventDrivenWorkFeeder0608 = M
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local events = defines and defines.events or nil
  local registered = 0
  if R and R.on_event and events and events.on_entity_damaged then
    R.on_event(events.on_entity_damaged, function(event) M.handle_entity_damaged(event) end, nil, {
      owner = "event_driven_work_feeder_0608",
      category = "event-fed-work",
      note = "submit repair work candidates to existing shared work queue on damage events"
    })
    registered = registered + 1
  end
  local dirty_events = {
    { key = "on_built_entity", reason = "built-entity-0613" },
    { key = "on_robot_built_entity", reason = "robot-built-entity-0613" },
    { key = "script_raised_built", reason = "script-raised-built-0613" },
    { key = "on_player_mined_entity", reason = "player-mined-entity-0613" },
    { key = "on_robot_mined_entity", reason = "robot-mined-entity-0613" },
    { key = "on_entity_died", reason = "entity-died-0613" },
    { key = "script_raised_destroy", reason = "script-raised-destroy-0613" },
  }
  if R and R.on_event and events then
    for _, rec in ipairs(dirty_events) do
      local event_key = rec.key
      local event_id = events[event_key]
      local reason = rec.reason
      if event_id then
        R.on_event(event_id, function(event)
          M.handle_entity_changed(event, reason)
          if event_key == "on_built_entity" or event_key == "on_robot_built_entity" or event_key == "script_raised_built" then M.handle_entity_built_for_work(event, reason) end
        end, nil, {
          owner = "event_driven_work_feeder_0608",
          category = "event-fed-dirty",
          note = "mark existing dirty/negative authorities from world-change events and feed high-signal built/ghost work"
        })
        registered = registered + 1
      end
    end
  end

  if R and R.on_event and events and events.on_player_dropped_item then
    R.on_event(events.on_player_dropped_item, function(event) M.handle_pickup_candidate(event, "player-dropped-item-0616") end, nil, {
      owner = "event_driven_work_feeder_0608",
      category = "event-fed-work",
      note = "submit dropped item pickup work to existing shared work queue"
    })
    registered = registered + 1
  end
  if registered > 0 then
    remember("install", "event feeder registered handlers=" .. safe(registered))
    return true
  end
  remember("install-deferred", "runtime event registry or event defines unavailable")
  return false
end

return M
