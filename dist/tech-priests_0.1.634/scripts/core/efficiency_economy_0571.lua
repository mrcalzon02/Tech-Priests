-- scripts/core/efficiency_economy_0571.lua
-- Tech Priests 0.1.571
--
-- Third clean megabase-efficiency step.  This module adds maintenance-scan
-- no-work cooldowns for dispatcher-owned repair and consecration executors and
-- adds damage events to the dirty-region cache.  It is a governor only: it does
-- not choose work, move priests, repair, consecrate, mine, construct, or finish
-- orders.  It merely avoids re-running expensive local maintenance searches
-- when a station already proved there was no work nearby and no local entity
-- changed afterward.

local M = {}
M.version = "0.1.571"
M.storage_key = "efficiency_economy_0571"

M.maintenance_no_work_cooldown_ticks = 60 * 3
M.no_supplies_cooldown_ticks = 60 * 5
M.cache_prune_ticks = 60 * 60
M.skip_keep_ticks = 60 * 60 * 8
M.dirty_cell_size = 32

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      repair_skip_enabled = true,
      consecration_skip_enabled = true,
      damage_dirty_enabled = true,
      skip_until = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.repair_skip_enabled == nil then r.repair_skip_enabled = true end
  if r.consecration_skip_enabled == nil then r.consecration_skip_enabled = true end
  if r.damage_dirty_enabled == nil then r.damage_dirty_enabled = true end
  r.skip_until = r.skip_until or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = { tick=now(), action=tostring(action or "event"), detail=tostring(detail or "") }
  while #r.recent > 48 do table.remove(r.recent, 1) end
end

local function surface_key(surface)
  if not surface then return "nil" end
  return tostring(surface.index or surface.name or "surface")
end

local function dirty_root()
  storage.tech_priests = storage.tech_priests or {}
  local econ = storage.tech_priests.efficiency_economy_0569
  if type(econ) ~= "table" then return nil end
  econ.dirty_regions = econ.dirty_regions or {}
  return econ.dirty_regions
end

local function mark_dirty_entity(entity, reason)
  if not valid(entity) then return false end
  local dirty = dirty_root()
  if not dirty then return false end
  local pos = entity.position or {x=0,y=0}
  local cx = math.floor((pos.x or 0) / M.dirty_cell_size)
  local cy = math.floor((pos.y or 0) / M.dirty_cell_size)
  local key = surface_key(entity.surface) .. ":" .. tostring(cx) .. ":" .. tostring(cy)
  local rec = dirty[key] or { count = 0 }
  rec.last_tick = now()
  rec.reason = tostring(reason or "dirty")
  rec.count = (tonumber(rec.count or 0) or 0) + 1
  rec.entity = tostring(entity.name or entity.type or "entity")
  dirty[key] = rec
  stat("dirty_damage_marks")
  return true
end

local function dirty_near(pair, since_tick)
  local fn = rawget(_G, "tech_priests_efficiency_0570_dirty_near_pair")
  if type(fn) ~= "function" then return true end
  local ok, result = pcall(fn, pair, pair and (pair.radius or 32) or 32, since_tick or 0)
  if not ok then return true end
  return result == true
end

local function explicit_order_kind(pair)
  local q = pair and pair.order_queue_0469
  local order = pair and ((q and q.current) or pair.active_order_0469) or nil
  return lower(order and (order.kind or order.type or order.key or order.source) or "")
end

local function active_phase(pair, key)
  local s = pair and pair[key]
  if type(s) ~= "table" then return false end
  if valid(s.target) then return true end
  local phase = lower(s.phase)
  return phase:find("walk",1,true) or phase:find("repair",1,true) or phase:find("rite",1,true) or phase:find("target",1,true)
end

local function skip_key(pair, family)
  return tostring(family or "maintenance") .. ":" .. safe(station_unit(pair))
end

local function should_skip(pair, family, enabled)
  local r = M.root()
  if r.enabled == false or enabled == false or not valid_pair(pair) then return false, nil end
  local k = skip_key(pair, family)
  local rec = r.skip_until[k]
  if type(rec) ~= "table" then return false, nil end
  local until_tick = tonumber(rec.until_tick or 0) or 0
  if until_tick <= now() then r.skip_until[k] = nil; return false, nil end
  if dirty_near(pair, tonumber(rec.since_tick or 0) or 0) then
    r.skip_until[k] = nil
    stat(family .. "_skip_cleared_dirty")
    return false, nil
  end
  stat(family .. "_scan_skipped")
  return true, rec.reason or "maintenance-no-work-cooldown-0571"
end

local function record_skip(pair, family, why, cooldown)
  if not valid_pair(pair) then return end
  local r = M.root()
  local k = skip_key(pair, family)
  local jitter = (tonumber(station_unit(pair) or 0) or 0) % 90
  r.skip_until[k] = {
    until_tick = now() + (tonumber(cooldown) or M.maintenance_no_work_cooldown_ticks) + jitter,
    since_tick = now(),
    reason = tostring(why or "no-work"),
  }
  stat(family .. "_skip_recorded")
end

local function is_no_work_reason(why)
  local w = lower(why)
  return w == "no-target" or w == "no-eligible-target" or w == "no-consecration-target" or w:find("no%-eligible",1,false) or w:find("no%-target",1,false)
end

local function is_no_supplies_reason(why)
  local w = lower(why)
  return w:find("no%-consecration%-item",1,false) or w:find("no%-useful%-item",1,false) or w:find("need%-item",1,false) or w:find("missing",1,true)
end

local function wrap_consecration()
  local ok, Cons = pcall(require, "scripts.core.consecration_executor_0515")
  if not (ok and Cons and type(Cons.service_pair)=="function") or Cons.efficiency_economy_0571_wrapped then return false end
  Cons.efficiency_economy_0571_wrapped = true
  Cons.TECH_PRIESTS_0571_PRE_SERVICE_PAIR = Cons.service_pair
  Cons.service_pair = function(pair, reason, forced_target, ...)
    local order_kind = explicit_order_kind(pair)
    local explicit = order_kind:find("consecr",1,true) or forced_target ~= nil or active_phase(pair, "consecration_0515")
    if not explicit then
      local skip, why = should_skip(pair, "consecration", M.root().consecration_skip_enabled)
      if skip then return false, why end
    end
    local acted, why = Cons.TECH_PRIESTS_0571_PRE_SERVICE_PAIR(pair, reason, forced_target, ...)
    if not explicit and acted == false then
      if is_no_work_reason(why) then record_skip(pair, "consecration", why, M.maintenance_no_work_cooldown_ticks)
      elseif is_no_supplies_reason(why) then record_skip(pair, "consecration", why, M.no_supplies_cooldown_ticks) end
    end
    return acted, why
  end
  remember("wrap-consecration", "no-work cooldown="..safe(M.maintenance_no_work_cooldown_ticks))
  return true
end

local function wrap_repair()
  local ok, Repair = pcall(require, "scripts.core.repair_executor_0516")
  if not (ok and Repair and type(Repair.service_pair)=="function") or Repair.efficiency_economy_0571_wrapped then return false end
  Repair.efficiency_economy_0571_wrapped = true
  Repair.TECH_PRIESTS_0571_PRE_SERVICE_PAIR = Repair.service_pair
  Repair.service_pair = function(pair, reason, forced_target, ...)
    local order_kind = explicit_order_kind(pair)
    local explicit = order_kind:find("repair",1,true) or forced_target ~= nil or active_phase(pair, "repair_0516")
    if not explicit then
      local skip, why = should_skip(pair, "repair", M.root().repair_skip_enabled)
      if skip then return false, why end
    end
    local acted, why = Repair.TECH_PRIESTS_0571_PRE_SERVICE_PAIR(pair, reason, forced_target, ...)
    if not explicit and acted == false then
      if is_no_work_reason(why) then record_skip(pair, "repair", why, M.maintenance_no_work_cooldown_ticks)
      elseif is_no_supplies_reason(why) then record_skip(pair, "repair", why, M.no_supplies_cooldown_ticks) end
    end
    return acted, why
  end
  remember("wrap-repair", "no-work cooldown="..safe(M.maintenance_no_work_cooldown_ticks))
  return true
end

local function install_dirty_damage_events()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  local events = defines and defines.events or nil
  if not (R and R.on_event and events and events.on_entity_damaged) then return false end
  R.on_event(events.on_entity_damaged, function(event)
    local r = M.root()
    if r.enabled == false or r.damage_dirty_enabled == false then return end
    local e = event and event.entity
    if valid(e) then mark_dirty_entity(e, "entity-damaged") end
  end, nil, { owner="efficiency_economy_0571", category="dirty-region", note="mark dirty cells when repair-relevant entities are damaged" })
  remember("dirty-damage-events", "installed")
  return true
end

function M.service()
  local r = M.root()
  local removed = 0
  for k,rec in pairs(r.skip_until or {}) do
    if type(rec) ~= "table" or (tonumber(rec.until_tick or 0) or 0) < now() - M.skip_keep_ticks then
      r.skip_until[k] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then stat("skip_cache_pruned", removed) end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0571") end end)
  commands.add_command("tp-efficiency-economy-0571", "Tech Priests 0.1.571 maintenance scan economy. Params: on/off/repair-on/repair-off/consecration-on/consecration-off/damage-on/damage-off/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = M.root()
    if param == "on" then r.enabled = true elseif param == "off" then r.enabled = false
    elseif param == "repair-on" then r.repair_skip_enabled = true elseif param == "repair-off" then r.repair_skip_enabled = false
    elseif param == "consecration-on" then r.consecration_skip_enabled = true elseif param == "consecration-off" then r.consecration_skip_enabled = false
    elseif param == "damage-on" then r.damage_dirty_enabled = true elseif param == "damage-off" then r.damage_dirty_enabled = false end
    local entries = 0; for _ in pairs(r.skip_until or {}) do entries = entries + 1 end
    local msg = "[tp-efficiency-economy-0571] enabled="..safe(r.enabled)
      .." repair_skip="..safe(r.repair_skip_enabled).." consecration_skip="..safe(r.consecration_skip_enabled)
      .." damage_dirty="..safe(r.damage_dirty_enabled).." skip_entries="..safe(entries)
      .." repair_skipped="..safe(r.stats.repair_scan_skipped or 0)
      .." consecration_skipped="..safe(r.stats.consecration_scan_skipped or 0)
      .." dirty_damage_marks="..safe(r.stats.dirty_damage_marks or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  _G.TechPriestsEfficiencyEconomy0571 = M
  wrap_consecration()
  wrap_repair()
  install_dirty_damage_events()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.cache_prune_ticks, function() M.service() end, { owner="efficiency_economy_0571", category="economy", note="prune maintenance no-work scan cooldowns" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.cache_prune_ticks, function() M.service() end)
  end
  install_command()
  if log then log("[Tech-Priests 0.1.571] maintenance scan economy installed; repair/consecration no-work cooldowns and damage dirty-region marks enabled") end
  return true
end

return M
