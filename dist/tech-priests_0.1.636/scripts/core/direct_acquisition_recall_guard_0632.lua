-- scripts/core/direct_acquisition_recall_guard_0632.lua
-- Tech Priests 0.1.632
--
-- When movement enforcement orders a priest home, direct acquisition must not
-- immediately reissue the same ore/resource trip. This guard wraps the 0513
-- direct acquisition executor and pauses it during the recall lease.

local M = {}
M.version = "0.1.632"
M.storage_key = "direct_acquisition_recall_guard_0632"
M.recall_ticks = 60 * 12
M.log_interval = 600

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, last_log={} }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.last_log=r.last_log or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair, action, detail, force)
  local r=M.root(); stat(action)
  local ev={tick=now(), action=tostring(action or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>80 do table.remove(r.recent,1) end
  local key=ev.action..":"..ev.station
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.632] "..ev.action.." station="..ev.station.." priest="..ev.priest.." "..safe(detail)) end
  end
  return ev
end

function M.recall_active(pair)
  if not valid_pair(pair) then return false end
  local mode = lower(pair.mode or "")
  if mode:find("returning%-movement%-enforcement%-0566", 1, false) then return true, "returning-movement-enforcement-0566" end
  if mode:find("movement%-target%-rejected%-0566", 1, false) then return true, "movement-target-rejected-0566" end
  local rej = pair.movement_rejected_0566
  local tick = type(rej)=="table" and tonumber(rej.tick) or nil
  if tick and now() - tick < M.recall_ticks then
    return true, tostring(rej.reason or "movement-recall")
  end
  return false
end

function M.wrap_direct_executor()
  local ok, Direct = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if not (ok and Direct and type(Direct.service_pair)=="function") then return false, "missing-direct-executor" end
  if Direct.TECH_PRIESTS_0632_RECALL_GUARD_WRAPPED then return true, "already-wrapped" end
  Direct.TECH_PRIESTS_0632_RECALL_GUARD_WRAPPED = true
  Direct.TECH_PRIESTS_0632_PRE_SERVICE_PAIR = Direct.service_pair
  Direct.service_pair = function(pair, reason, ...)
    if M.root().enabled ~= false then
      local recall, why = M.recall_active(pair)
      if recall then
        if pair then
          pair.dispatcher_direct_0513 = pair.dispatcher_direct_0513 or {}
          pair.dispatcher_direct_0513.phase = "paused-by-movement-enforcement"
          pair.dispatcher_direct_0513.detail = tostring(why or "movement-recall")
          pair.dispatcher_direct_0513.tick = now()
        end
        record(pair, "direct-paused-by-enforcement-0513", tostring(why or "movement-recall"))
        return false, "movement-enforcement-recall"
      end
    end
    return Direct.TECH_PRIESTS_0632_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true, "wrapped"
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-direct-recall-0632") end end)
  commands.add_command("tp-direct-recall-0632", "Tech Priests 0.1.632: direct acquisition movement-enforcement recall guard diagnostics.", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local r=M.root()
    local msg="[tp-direct-recall-0632] enabled="..safe(r.enabled).." paused="..safe(r.stats["direct-paused-by-enforcement-0513"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  M.wrap_direct_executor()
  install_command()
  _G.TechPriestsDirectAcquisitionRecallGuard0632 = M
  if log then log("[Tech-Priests 0.1.632] direct acquisition recall guard installed; movement-enforcement return-home suppresses direct mining retargets") end
  return true
end

return M