-- Tech Priests 0.1.669 surface-scoped positional reservation keys.
--
-- Shared work reservations historically keyed plain table positions as x,y only.
-- Two unrelated construction plans at the same coordinates on different surfaces
-- could therefore deny one another. This compatibility hardener adds the surface
-- index to positional keys whenever callers provide it directly or in claim meta.
-- Entity/unit reservation keys remain unchanged.

local M = {
  version = "0.1.669",
  storage_key = "reservation_position_scope_0697",
}

local previous_target_key
local previous_claim

local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={}}
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end

local function position_of(target)
  if type(target)~="table" then return nil end
  if target.position and target.position.x and target.position.y then return target.position end
  if target.x and target.y then return target end
  return nil
end

local function scoped_position_key(target)
  local position=position_of(target)
  local surface_index=type(target)=="table" and tonumber(target.surface_index) or nil
  if not (position and surface_index) then return nil end
  return "surface:"..tostring(surface_index)..":pos:"
    ..string.format("%.1f,%.1f",tonumber(position.x) or 0,tonumber(position.y) or 0)
end

local function patch_reservations(reservations)
  if not reservations or reservations.reservation_position_scope_0697_active then return false end
  if type(reservations.target_key)~="function" or type(reservations.claim)~="function" then return false end
  reservations.reservation_position_scope_0697_active=true

  previous_target_key=reservations.target_key
  reservations.target_key=function(target)
    local scoped=scoped_position_key(target)
    if scoped then stat("scoped_position_keys"); return scoped end
    return previous_target_key(target)
  end

  previous_claim=reservations.claim
  reservations.claim=function(category,target,pair_or_id,ttl,meta)
    if type(target)=="table" and position_of(target) and meta then
      if target.surface_index==nil and meta.surface_index~=nil then target.surface_index=meta.surface_index end
      if target.force_index==nil and meta.force_index~=nil then target.force_index=meta.force_index end
    end
    return previous_claim(category,target,pair_or_id,ttl,meta)
  end
  return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.reservation_position_scope_0697_wrapped then return false end
  diag.reservation_position_scope_0697_wrapped=true
  local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 RESERVATION-SCOPE-0697 enabled="..safe(r.enabled).." surface_scoped_keys="..safe(r.stats.scoped_position_keys or 0)
    return lines
  end
  return true
end

function M.install()
  root()
  local reservations=rawget(_G,"TechPriestsWorkReservations0601")
  if not reservations then local ok,module=pcall(require,"scripts.core.work_reservations"); if ok then reservations=module end end
  if not reservations then return false end
  patch_reservations(reservations)
  patch_diagnostics()
  _G.TechPriestsReservationPositionScope0697=M
  if log then log("[Tech-Priests 0.1.669] positional work reservations are now surface-scoped") end
  return true
end

return M
