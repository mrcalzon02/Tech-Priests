-- scripts/core/direct_acquisition_pulse_0631.lua
-- Tech Priests 0.1.631
--
-- Small lifecycle pulse for dispatcher-owned direct acquisition. Movement can
-- finish after the dispatcher has yielded to the movement owner; this pulse keeps
-- active direct acquisition tasks advancing so a priest that reaches ore/tree/rock
-- transitions into the executor work phase instead of idling on the target tile.

local M = {}
M.version = "0.1.631"
M.storage_key = "direct_acquisition_pulse_0631"
M.service_interval = 7
M.max_pairs_per_pulse = 24

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, action, detail)
  local r=M.root(); stat(action)
  local ev={tick=now(), action=tostring(action or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>80 do table.remove(r.recent,1) end
  return ev
end

local function direct_executor()
  local ok, Direct = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if ok and Direct then return Direct end
  return rawget(_G, "TechPriestsDirectAcquisitionExecutor0513")
end

local function has_direct_task(Direct, pair)
  if not (Direct and valid_pair(pair)) then return false end
  if type(Direct.current_direct_task) == "function" then
    local ok, task, cur = pcall(Direct.current_direct_task, pair)
    return ok and task ~= nil and cur ~= nil
  end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local cur = type(task)=="table" and (task.current or task) or nil
    local kind = cur and tostring(cur.kind or "") or ""
    if kind == "direct-mine-0273" or kind == "direct-dirt-0273" or kind == "dirt" or kind == "direct-mine-0336" then return true end
  end
  return false
end

function M.service_pair(pair, reason)
  local Direct = direct_executor()
  if not (Direct and type(Direct.service_pair)=="function") then return false, "missing-direct-executor" end
  if not has_direct_task(Direct, pair) then return false, "no-direct-task" end
  local ok, acted, why = pcall(Direct.service_pair, pair, reason or "direct-acquisition-pulse-0631")
  if not ok then
    record(pair, "direct-pulse-error-0631", tostring(acted))
    return false, "direct-pulse-error"
  end
  if acted then record(pair, "direct-pulse-acted-0631", tostring(why or "acted")) end
  return acted, why
end

function M.service(event, budget)
  local r=M.root()
  if r.enabled == false then return false, "disabled" end
  local Direct = direct_executor()
  if not Direct then return false, "missing-direct-executor" end
  local processed, acted = 0, 0
  local max_count = tonumber(budget) or M.max_pairs_per_pulse
  for _, pair in pairs(pair_map()) do
    if processed >= max_count then break end
    if valid_pair(pair) and has_direct_task(Direct, pair) then
      processed = processed + 1
      local did = select(1, M.service_pair(pair, "direct-acquisition-pulse-0631"))
      if did then acted = acted + 1 end
    end
  end
  if processed == 0 then return false, "no-active-direct-acquisition" end
  stat("direct-pulse-processed-0631", processed)
  return acted > 0, "direct-acquisition-pulse processed="..safe(processed).." acted="..safe(acted)
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-direct-acquisition-pulse-0631") end end)
  commands.add_command("tp-direct-acquisition-pulse-0631", "Tech Priests 0.1.631: direct acquisition active-task pulse diagnostics.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local r=M.root()
    local msg="[tp-direct-acquisition-pulse-0631] enabled="..safe(r.enabled).." processed="..safe(r.stats["direct-pulse-processed-0631"] or 0).." acted="..safe(r.stats["direct-pulse-acted-0631"] or 0).." errors="..safe(r.stats["direct-pulse-error-0631"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function install_recall_guard()
  local ok, Guard0632 = pcall(require, "scripts.core.direct_acquisition_recall_guard_0632")
  if ok and Guard0632 and type(Guard0632.install)=="function" then return Guard0632.install() end
  if log then log("[Tech-Priests 0.1.632] direct_acquisition_recall_guard_0632 failed to install from direct_acquisition_pulse_0631") end
  return false
end

function M.install()
  M.root()
  install_recall_guard()
  install_command()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then
    broker.register_service({name="direct_acquisition_pulse_0631",category="executor",interval=M.service_interval,priority=68,budget=M.max_pairs_per_pulse,fn=function(event,budget) return M.service(event,budget) end,note="continues active direct acquisition after movement arrival"})
  else
    local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
    if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
    if registry and type(registry.on_nth_tick)=="function" then registry.on_nth_tick(M.service_interval,function(event) M.service(event,M.max_pairs_per_pulse) end,{owner="direct_acquisition_pulse_0631",category="executor",priority="normal",note="continue direct mining after movement arrival"}) end
  end
  _G.TechPriestsDirectAcquisitionPulse0631 = M
  if log then log("[Tech-Priests 0.1.631] direct acquisition active-task pulse installed; reached direct targets continue into work/mining phase") end
  return true
end

return M