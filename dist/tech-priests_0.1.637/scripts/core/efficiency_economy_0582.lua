-- scripts/core/efficiency_economy_0582.lua
-- Tech Priests 0.1.582
--
-- Grand behavior-tree economy pass.  This is deliberately a governor/shim,
-- not a new behavior controller.  It wraps the dispatcher and the oldest
-- legacy tick_pair route so repeated idle/no-work decisions can be cached for a
-- short window.  Active orders, combat, repair, consecration, acquisition,
-- crafting, manual/recovery pulses, and visible work still flow through the
-- existing authority chain.

local M = {}
M.version = "0.1.582"
M.storage_key = "efficiency_economy_0582"
M.idle_skip_ticks = 97
M.no_work_skip_ticks = 61
M.legacy_idle_skip_ticks = 131
M.cleanup_interval = 60 * 37

local wrapped_dispatcher = nil
local original_dispatch_service_pair = nil
local original_legacy_tick_pair = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      dispatcher_idle_cache = true,
      legacy_idle_gate = true,
      pair = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_idle_cache == nil then r.dispatcher_idle_cache = true end
  if r.legacy_idle_gate == nil then r.legacy_idle_gate = true end
  r.pair = r.pair or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 60 do table.remove(r.recent, 1) end
end

local function station_key(pair)
  if type(pair) ~= "table" then return nil end
  return tostring(pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "")
end

local function has_active_order(pair)
  if type(pair) ~= "table" then return false end
  -- Current/pending queue work.
  local oq = pair.order_queue_0469 or pair.orders_0469 or pair.order_queue or pair.orders
  if type(oq) == "table" then
    if oq.current or oq.active or oq.current_order then return true end
    if type(oq.pending) == "table" and next(oq.pending) ~= nil then return true end
    if type(oq.queue) == "table" and next(oq.queue) ~= nil then return true end
  end
  -- Common active work fields from legacy/generated fragments and current executors.
  local active_keys = {
    "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333",
    "construction_task", "combat_target", "repair_target", "consecration_target",
    "active_consecration_0515", "active_repair_0516", "combat_repair_0517",
    "logistics_fetch_task", "active_logistics_fetch", "machine_fulfillment_task",
  }
  for _, k in ipairs(active_keys) do
    local v = pair[k]
    if valid(v) then return true end
    if type(v) == "table" then
      if v.current or v.target or v.entity or v.item or v.item_name or v.output_item or v.status == "active" then return true end
    elseif v then
      return true
    end
  end
  local mode = lower(pair.mode)
  if mode ~= "" and mode ~= "idle" and mode ~= "returning" and mode ~= "no-managed-priority-claimed" then
    if mode:find("combat",1,true) or mode:find("repair",1,true) or mode:find("consecr",1,true) or mode:find("gather",1,true) or mode:find("craft",1,true) or mode:find("construct",1,true) or mode:find("mine",1,true) or mode:find("acquir",1,true) then return true end
  end
  return false
end

local function should_never_skip(reason)
  local rs = lower(reason or "")
  if rs:find("manual",1,true) or rs:find("combat",1,true) or rs:find("recovery",1,true) or rs:find("repair",1,true) or rs:find("force",1,true) or rs:find("debug",1,true) then return true end
  return false
end

local function cache_record(pair)
  local key = station_key(pair)
  if not key or key == "" then return nil end
  local r=M.root()
  r.pair[key] = r.pair[key] or {}
  return r.pair[key]
end

local function dispatcher_cache_allows_skip(pair, reason)
  local r = M.root()
  if r.enabled == false or r.dispatcher_idle_cache == false then return false end
  if should_never_skip(reason) or has_active_order(pair) then return false end
  local rec = cache_record(pair)
  if not rec then return false end
  local d = pair and pair.dispatcher_0510 or nil
  local family = lower(d and d.family or "idle")
  local result = lower(d and d.result or "")
  local mode = lower(pair and pair.mode or "idle")
  local skip_until = tonumber(rec.next_dispatch_after or 0) or 0
  if skip_until > now() then
    stat("dispatcher_idle_skipped")
    return true
  end
  -- If the last dispatcher pass saw only idle/no-claim/no executor work, allow
  -- the next identical calm pulse to sleep.  Active work will clear this through
  -- has_active_order/dirty invalidation before it can suppress useful action.
  if family == "idle" or result == "legacy-leaf-family" or result == "classified" or result:find("no%-claim",1,false) or mode == "idle" then
    rec.next_dispatch_after = now() + M.idle_skip_ticks
    rec.last_family = family
    rec.last_result = result
    stat("dispatcher_idle_armed")
  end
  return false
end

local function wrap_dispatcher()
  local ok, Dispatcher = pcall(require, "scripts.core.single_dispatcher_0510")
  if not (ok and Dispatcher and type(Dispatcher.service_pair) == "function") then return false end
  if wrapped_dispatcher then return true end
  wrapped_dispatcher = Dispatcher
  original_dispatch_service_pair = Dispatcher.service_pair
  Dispatcher.service_pair = function(pair, reason)
    if dispatcher_cache_allows_skip(pair, reason) then return false, "behavior-idle-cache-0582" end
    local acted, why = original_dispatch_service_pair(pair, reason)
    local rec = cache_record(pair)
    if rec then
      if acted or has_active_order(pair) then
        rec.next_dispatch_after = now()
        stat("dispatcher_active_passthrough")
      else
        local d = pair and pair.dispatcher_0510 or nil
        local family = lower(d and d.family or "idle")
        local result = lower(why or (d and d.result) or "")
        if family == "idle" or result:find("no",1,true) or result == "legacy-leaf-family" then
          rec.next_dispatch_after = now() + M.no_work_skip_ticks
          stat("dispatcher_no_work_sleep")
        end
      end
    end
    return acted, why
  end
  remember("wrap", "single_dispatcher_0510.service_pair")
  return true
end

local function legacy_tick_allows_skip(pair, reason)
  local r=M.root()
  if r.enabled == false or r.legacy_idle_gate == false then return false end
  if should_never_skip(reason) or has_active_order(pair) then return false end
  local rec = cache_record(pair)
  if not rec then return false end
  if (tonumber(rec.next_legacy_after or 0) or 0) > now() then
    stat("legacy_idle_skipped")
    return true
  end
  rec.next_legacy_after = now() + M.legacy_idle_skip_ticks
  stat("legacy_idle_armed")
  return false
end

local function wrap_legacy_tick_pair()
  if type(_G.tick_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0582_PRE_TICK_PAIR") then return false end
  original_legacy_tick_pair = _G.tick_pair
  _G.TECH_PRIESTS_0582_PRE_TICK_PAIR = original_legacy_tick_pair
  _G.tick_pair = function(pair, ...)
    local reason = select(1, ...)
    if legacy_tick_allows_skip(pair, reason) then return true end
    return original_legacy_tick_pair(pair, ...)
  end
  remember("wrap", "global tick_pair idle gate")
  return true
end

function M.invalidate_pair(pair, reason)
  local key = station_key(pair)
  if not key then return end
  local r=M.root()
  r.pair[key] = nil
  stat("invalidated_pair")
end

function M.invalidate_all(reason)
  local r=M.root()
  r.pair = {}
  stat("invalidated_all")
  remember("invalidate-all", reason or "unknown")
end

local function invalidate_from_entity(entity, reason)
  if not valid(entity) then return end
  local tp = storage and storage.tech_priests or nil
  if tp then
    local pair = nil
    local u = entity.unit_number
    if u and tp.pairs_by_station then pair = tp.pairs_by_station[u] end
    if not pair and u and tp.pairs_by_priest then pair = tp.pairs_by_priest[u] end
    if pair then return M.invalidate_pair(pair, reason) end
  end
  -- World changes can create new work for nearby idle priests, so clear the
  -- short cache globally instead of risking a stale calm window.
  M.invalidate_all(reason or "entity-change")
end

local function install_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local events = defines and defines.events or nil
  if not (R and R.on_event and events) then return false end
  R.on_event({ events.on_built_entity, events.on_robot_built_entity, events.script_raised_built, events.script_raised_revive }, function(event)
    local e = event and (event.entity or event.created_entity)
    invalidate_from_entity(e, "built")
  end, nil, { owner="efficiency_economy_0582", category="behavior-cache", note="wake calm behavior cache after construction" })
  R.on_event({ events.on_player_mined_entity, events.on_robot_mined_entity, events.on_entity_died, events.script_raised_destroy }, function(event)
    invalidate_from_entity(event and event.entity, "removed")
  end, nil, { owner="efficiency_economy_0582", category="behavior-cache", note="wake calm behavior cache after removals/death" })
  R.on_event({ events.on_entity_damaged }, function(event)
    invalidate_from_entity(event and event.entity, "damaged")
  end, nil, { owner="efficiency_economy_0582", category="behavior-cache", note="wake calm behavior cache after damage" })
  return true
end

function M.cleanup()
  local r=M.root()
  local removed=0
  for key, rec in pairs(r.pair or {}) do
    if type(rec) ~= "table" or (tonumber(rec.next_dispatch_after or 0) or 0) + 60*10 < now() then
      r.pair[key] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then stat("cleanup_removed", removed) end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0582") end end)
  commands.add_command("tp-efficiency-economy-0582", "Tech Priests 0.1.582 behavior-tree economy. Params: on/off/dispatcher-on/dispatcher-off/legacy-on/legacy-off/clear/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r=M.root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false
    elseif p == "dispatcher-on" then r.dispatcher_idle_cache = true elseif p == "dispatcher-off" then r.dispatcher_idle_cache = false
    elseif p == "legacy-on" then r.legacy_idle_gate = true elseif p == "legacy-off" then r.legacy_idle_gate = false
    elseif p == "clear" then M.invalidate_all("command") end
    local tracked=0; for _ in pairs(r.pair or {}) do tracked=tracked+1 end
    local msg = "[tp-efficiency-economy-0582] enabled="..safe(r.enabled).." dispatcher_cache="..safe(r.dispatcher_idle_cache).." legacy_idle_gate="..safe(r.legacy_idle_gate).." tracked="..safe(tracked).." dispatcher_skipped="..safe(r.stats.dispatcher_idle_skipped or 0).." legacy_skipped="..safe(r.stats.legacy_idle_skipped or 0).." active_passthrough="..safe(r.stats.dispatcher_active_passthrough or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  wrap_dispatcher()
  wrap_legacy_tick_pair()
  install_events()
  install_command()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0582", category="economy", priority="last", note="prune behavior-tree calm cache" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.cleanup_interval, function() M.cleanup() end)
  end
  _G.TechPriestsEfficiencyEconomy0582 = M
  if log then log("[Tech-Priests 0.1.582] behavior-tree idle/cache economy installed") end
  return true
end

return M
