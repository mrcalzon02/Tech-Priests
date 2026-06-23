-- Tech Priests 0.1.662 combat-repair terminal cleanup.
-- Final narrow guard for invalid-target reservation keys and stale mirrors after
-- the 0676 integrity wrapper has completed or aborted tactical repair.

local M = { version = "0.1.662" }
local previous_abort
local previous_service
local previous_install

local function valid(entity) return entity and entity.valid end
local function safe(value) if value == nil then return "nil" end local ok,text=pcall(tostring,value); return ok and text or "?" end
local function lower(value) return string.lower(tostring(value or "")) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil" end
local function Doctrine() local ok,module=pcall(require,"scripts.core.combat_repair_doctrine_0517"); return ok and module or rawget(_G,"TechPriestsCombatRepairDoctrine0517") end
local function Reservations() local ok,module=pcall(require,"scripts.core.work_reservations"); return ok and module or rawget(_G,"TechPriestsWorkReservations0601") end

local function release_stored_unit(pair, unit)
  if not unit then return false end
  local reservations=Reservations()
  if not(reservations and type(reservations.root)=="function") then return false end
  local ok,root=pcall(reservations.root)
  local bucket=ok and root and root.reservations and root.reservations.repair
  local key="unit:"..safe(unit)
  local reservation=bucket and bucket[key]
  if not reservation then return false end
  local pair_id=reservations.pair_id and reservations.pair_id(pair) or station_unit(pair)
  if safe(reservation.pair_id)~=safe(pair_id) then return false end
  bucket[key]=nil
  return true
end

local function wallish(entity)
  if not valid(entity) then return false end
  local typ=lower(entity.type)
  local name=lower(entity.name)
  return typ=="wall" or typ=="gate" or name:find("wall",1,true)~=nil or name:find("gate",1,true)~=nil
end

local function terminal_cleanup(pair, captured)
  if not pair then return end
  local state=pair.combat_repair_0517 or {}
  local phase=lower(state.phase)
  local terminal=phase=="complete" or phase=="failed" or phase=="no-target"
  if not terminal then return end

  release_stored_unit(pair, captured and captured.unit)
  pair.combat_repair_target_0517=nil
  if captured and pair.target==captured.target then pair.target=nil end
  if wallish(pair.target) then pair.target=nil end

  local repair=pair.repair_0516
  if repair and (not repair.target or (captured and repair.target==captured.target)) then
    for _,field in ipairs({"target","target_name","target_unit","target_source","started_tick","due_tick","packs_used","distance","missing","max_health","last_restore","integrity_target_key_0673"}) do repair[field]=nil end
    if phase~="complete" then repair.phase="none" end
  end

  if lower(pair.mode):find("repair",1,true) then
    pair.mode=valid(pair.combat_target) and "combat" or "idle"
  end
end

local function capture(pair)
  local state=pair and pair.combat_repair_0517 or {}
  local target=valid(state.target) and state.target or (pair and valid(pair.combat_repair_target_0517) and pair.combat_repair_target_0517 or nil)
  return { target=target, unit=state.target_unit or (valid(target) and target.unit_number) }
end

local function patch(doctrine)
  if not previous_abort and type(doctrine.abort_pair)=="function" then
    previous_abort=doctrine.abort_pair
    doctrine.abort_pair=function(pair,reason)
      local captured=capture(pair)
      local result=previous_abort(pair,reason)
      terminal_cleanup(pair,captured)
      return result
    end
  end

  if not previous_service and type(doctrine.service_pair)=="function" then
    previous_service=doctrine.service_pair
    doctrine.service_pair=function(pair,...)
      local captured=capture(pair)
      local acted,why=previous_service(pair,...)
      terminal_cleanup(pair,captured)
      return acted,why
    end
  end

  if not previous_install and type(doctrine.install)=="function" then
    previous_install=doctrine.install
    doctrine.install=function(...)
      local result=previous_install(...)
      M.install()
      return result
    end
  end
end

function M.install()
  local doctrine=Doctrine()
  if not doctrine then return false end
  patch(doctrine)
  _G.TechPriestsCombatRepairTerminalCleanup0677=M
  if log then log("[Tech-Priests 0.1.662] combat repair terminal cleanup installed") end
  return true
end

return M
