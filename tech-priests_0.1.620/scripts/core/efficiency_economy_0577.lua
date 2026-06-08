-- scripts/core/efficiency_economy_0577.lua
-- Tech Priests 0.1.577
--
-- Budget-enforcement economy pass. This module consumes the budget scaffold
-- introduced in 0.1.576 and applies it to high-cost runtime surfaces without
-- becoming a behavior controller. It never chooses work, completes work, mines,
-- repairs, consecrates, crafts, or changes station intent. It only defers
-- non-critical pulses and low-priority movement requests into bounded queues so
-- megabase-sized priest populations do not synchronize into a single tick slam.

local M = {}
M.version = "0.1.577"
M.storage_key = "efficiency_economy_0577"
M.deferred_move_ttl = 60 * 5
M.deferred_move_service_interval = 7
M.deferred_move_budget = 3
M.queue_keep_ticks = 60 * 10

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function pair_key(pair)
  return tostring((pair and (pair.station_unit or unit(pair.station))) or "?") .. ":" .. tostring((pair and (pair.priest_unit or unit(pair.priest))) or "?")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      executor_budgets_enabled = true,
      movement_budget_enabled = true,
      deferred_moves = {},
      deferred_cursor = 0,
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.executor_budgets_enabled == nil then r.executor_budgets_enabled = true end
  if r.movement_budget_enabled == nil then r.movement_budget_enabled = true end
  r.deferred_moves = r.deferred_moves or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 64 do table.remove(r.recent, 1) end
end

local function budget_take(bucket, amount)
  local fn = rawget(_G, "tech_priests_0576_budget_take")
  if type(fn) == "function" then
    local ok, allowed = pcall(fn, bucket, amount or 1)
    if ok then return allowed ~= false end
  end
  return true
end

local function active_or_critical_reason(reason)
  local s = lower(reason)
  return s:find("combat",1,true) or s:find("retreat",1,true) or s:find("hostile",1,true)
    or s:find("manual",1,true) or s:find("player",1,true) or s:find("death",1,true)
    or s:find("respawn",1,true) or s:find("vanish",1,true) or s:find("recovery",1,true)
end

local function bucket_for_module(path)
  if path:find("consecration",1,true) then return "sanctity_checks_per_tick" end
  if path:find("repair",1,true) then return "scans_per_tick" end
  if path:find("movement_enforcement",1,true) or path:find("authority_corridor_pathing",1,true) then return "path_corrections_per_tick" end
  if path:find("direct_acquisition",1,true) or path:find("logistics",1,true) or path:find("emergency_production",1,true) then return "priests_per_tick" end
  if path:find("ground_item_hoover",1,true) or path:find("construction",1,true) then return "scans_per_tick" end
  return "priests_per_tick"
end

local service_pair_targets = {
  "scripts.core.consecration_executor_0515",
  "scripts.core.repair_executor_0516",
  "scripts.core.combat_repair_doctrine_0517",
  "scripts.core.direct_acquisition_executor_0513",
  "scripts.core.emergency_production_executor_0514",
  "scripts.core.logistics_fetch_executor_0526",
  "scripts.core.logistics_fetch_executor_0527",
  "scripts.core.logistics_machine_fulfillment_0528",
  "scripts.core.ground_item_hoover_0529",
  "scripts.core.construction_planner",
  "scripts.core.movement_enforcement_0566",
  "scripts.core.authority_corridor_pathing_0574",
}

local function wrap_service_pair(path)
  local ok, mod = pcall(require, path)
  if not (ok and mod and type(mod.service_pair) == "function") then return false end
  local flag = "efficiency_economy_0577_wrapped"
  if mod[flag] then return false end
  local prev = mod.service_pair
  local bucket = bucket_for_module(path)
  mod[flag] = true
  mod.TECH_PRIESTS_0577_PRE_SERVICE_PAIR = prev
  mod.service_pair = function(pair, reason, ...)
    local r = M.root()
    if r.enabled == false or r.executor_budgets_enabled == false or active_or_critical_reason(reason) then
      return prev(pair, reason, ...)
    end
    if not budget_take(bucket, 1) then
      stat("deferred_" .. bucket)
      return false, "budget-deferred-0577:" .. bucket
    end
    stat("ran_" .. bucket)
    return prev(pair, reason, ...)
  end
  remember("wrapped-service-pair", path .. " -> " .. bucket)
  return true
end

local function queue_movement(pair, destination, reason, opts)
  local r = M.root()
  local key = pair_key(pair)
  if key == "?:?" or not destination then return false end
  r.deferred_moves[key] = {
    pair = pair,
    destination = { x = destination.x or (destination[1]), y = destination.y or (destination[2]) },
    reason = tostring(reason or "movement"),
    opts = opts,
    expires_tick = now() + M.deferred_move_ttl,
    tick = now(),
  }
  stat("movement_deferred")
  return true
end

local original_movement_request
local function wrap_movement_request()
  if original_movement_request or type(_G.tech_priests_request_movement_0418) ~= "function" then return false end
  original_movement_request = _G.tech_priests_request_movement_0418
  _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
    local r = M.root()
    if r.enabled == false or r.movement_budget_enabled == false or active_or_critical_reason(reason) then
      return original_movement_request(pair, destination, reason, opts)
    end
    local priority = opts and tonumber(opts.priority or 0) or 0
    if priority >= 900 then return original_movement_request(pair, destination, reason, opts) end
    if budget_take("path_corrections_per_tick", 1) then
      stat("movement_budget_run")
      return original_movement_request(pair, destination, reason, opts)
    end
    if queue_movement(pair, destination, reason, opts) then
      return false, "movement-budget-deferred-0577"
    end
    return false, "movement-budget-denied-0577"
  end
  remember("wrapped-movement-request", "low-priority movement can spill into deferred queue")
  return true
end

function M.service_deferred_moves()
  local r = M.root()
  if r.enabled == false or r.movement_budget_enabled == false then return end
  local keys = {}
  local t = now()
  for k,rec in pairs(r.deferred_moves or {}) do
    if type(rec) ~= "table" or (tonumber(rec.expires_tick or 0) or 0) < t or not (rec.pair and valid(rec.pair.priest)) then
      r.deferred_moves[k] = nil
      stat("movement_deferred_pruned")
    else
      keys[#keys+1] = k
    end
  end
  table.sort(keys)
  local n = #keys
  if n == 0 then return end
  local cursor = tonumber(r.deferred_cursor or 0) or 0
  local serviced = 0
  local visited = 0
  while visited < n and serviced < M.deferred_move_budget do
    cursor = (cursor % n) + 1
    visited = visited + 1
    local k = keys[cursor]
    local rec = r.deferred_moves[k]
    if rec and rec.pair and rec.destination and original_movement_request and budget_take("path_corrections_per_tick", 1) then
      r.deferred_moves[k] = nil
      local ok = pcall(original_movement_request, rec.pair, rec.destination, rec.reason .. ":deferred-0577", rec.opts)
      if ok then serviced = serviced + 1; stat("movement_deferred_serviced") else stat("movement_deferred_failed") end
    end
  end
  r.deferred_cursor = cursor
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0577") end end)
  commands.add_command("tp-efficiency-economy-0577", "Tech Priests 0.1.577 enforced global budgets. Params: on/off/executors-on/executors-off/movement-on/movement-off/clear/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false
    elseif p == "executors-on" then r.executor_budgets_enabled = true elseif p == "executors-off" then r.executor_budgets_enabled = false
    elseif p == "movement-on" then r.movement_budget_enabled = true elseif p == "movement-off" then r.movement_budget_enabled = false
    elseif p == "clear" then r.deferred_moves = {}; r.deferred_cursor = 0 end
    local q=0; for _ in pairs(r.deferred_moves or {}) do q=q+1 end
    local msg = "[tp-efficiency-economy-0577] enabled="..safe(r.enabled).." executors="..safe(r.executor_budgets_enabled).." movement="..safe(r.movement_budget_enabled).." deferred_moves="..safe(q)
      .." move_deferred="..safe(r.stats.movement_deferred or 0).." move_serviced="..safe(r.stats.movement_deferred_serviced or 0).." path_deferred="..safe(r.stats.deferred_path_corrections_per_tick or 0)
      .." scan_deferred="..safe(r.stats.deferred_scans_per_tick or 0).." sanctity_deferred="..safe(r.stats.deferred_sanctity_checks_per_tick or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  local wrapped = 0
  for _,path in ipairs(service_pair_targets) do if wrap_service_pair(path) then wrapped = wrapped + 1 end end
  wrap_movement_request()
  install_command()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.deferred_move_service_interval, function() M.service_deferred_moves() end, { owner="efficiency_economy_0577", category="economy", priority="last", note="service deferred low-priority movement within path budget" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.deferred_move_service_interval, function() M.service_deferred_moves() end)
  end
  _G.TechPriestsEfficiencyEconomy0577 = M
  remember("install", "wrapped_service_pair="..safe(wrapped).." movement_queue=true")
  if log then log("[Tech-Priests 0.1.577] enforced global budget economy installed; wrapped service pairs="..safe(wrapped).." and low-priority movement spills into deferred queue") end
  return true
end

return M
