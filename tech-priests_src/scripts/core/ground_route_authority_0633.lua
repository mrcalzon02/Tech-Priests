-- scripts/core/ground_route_authority_0633.lua
-- Tech Priests 0.1.642
--
-- Phase 1 wrapper-only Ground Route Authority. This module treats Factorio's
-- go_to_location command as an actuator, not as task truth. It wraps the existing
-- movement request API after 0566/0572/0574 are installed, records route leases,
-- refuses Void Priest ownership, preserves unobserved/corridor/enforcement
-- wrappers downstream, and chunks long visible ground moves into bounded
-- waypoints before they reach the engine pathing actuator.

local M = {}
M.version = "0.1.642"
M.storage_key = "ground_route_authority_0633"
M.max_visible_waypoint = 18.0
M.default_radius = 0.75
M.default_ttl = 60 * 8
M.log_interval = 600

local pre_request = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function dist_sq(a,b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a,b) local d2=dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version=M.version,
    enabled=true,
    chunk_visible_moves=true,
    stats={},
    recent={},
    leases={},
    sequence_by_pair={},
    last_log={},
  }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  if r.chunk_visible_moves == nil then r.chunk_visible_moves=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.leases=r.leases or {}; r.sequence_by_pair=r.sequence_by_pair or {}; r.last_log=r.last_log or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, pair, detail, force)
  local r=M.root(); action=tostring(action or "event"); stat(action)
  local ev={tick=now(), action=action, station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>120 do table.remove(r.recent,1) end
  local key=action..":"..ev.station
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.642] "..ev.action.." station="..ev.station.." priest="..ev.priest.." "..safe(detail)) end
  end
  return ev
end

local function pair_key(pair)
  local su=station_unit(pair)
  if su then return tostring(su) end
  local pu=priest_unit(pair)
  if pu then return "p"..tostring(pu) end
  return nil
end

local function is_void_pair(pair)
  if _G.tech_priests_void_pair_0630 then local ok,res=pcall(_G.tech_priests_void_pair_0630,pair); if ok and res then return true end end
  if _G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630 and _G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630.is_void_pair then local ok,res=pcall(_G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630.is_void_pair,pair); if ok and res then return true end end
  return false
end

local function is_return_or_recovery(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("return",1,true) or s:find("home",1,true) or s:find("overleash",1,true) or s:find("station",1,true)
      or s:find("recovery",1,true) or s:find("respawn",1,true) or s:find("pair%-link",1,false)
end

local function is_route_internal(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("ground%-route%-waypoint%-0633",1,false) or s:find("corridor%-waypoint%-0574",1,false)
end

local function final_allowed(pair, pos, reason, opts)
  if not (valid_pair(pair) and pos) then return false, "invalid" end
  if is_return_or_recovery(reason, opts) or is_route_internal(reason, opts) then return true, "exempt" end
  if type(_G.tech_priests_0574_authorization_for_destination)=="function" then
    local ok, allowed, rec, source = pcall(_G.tech_priests_0574_authorization_for_destination, pair, pos, reason, opts)
    if ok then return allowed == true, source or (allowed and "allowed" or "rejected"), rec end
  end
  if type(_G.TechPriestsMovementEnforcement0566)=="table" and type(_G.TechPriestsMovementEnforcement0566.position_allowed)=="function" then
    local ok, allowed, d, maxd = pcall(_G.TechPriestsMovementEnforcement0566.position_allowed, pair, pos, reason, opts)
    if ok then return allowed ~= false, allowed ~= false and "0566" or ("0566 dist="..safe(d).." max="..safe(maxd)) end
  end
  return true, "fallback"
end

local function next_sequence(pair)
  local r=M.root(); local key=pair_key(pair) or "?"
  r.sequence_by_pair[key]=(tonumber(r.sequence_by_pair[key]) or 0)+1
  return r.sequence_by_pair[key]
end

local function remember_lease(pair, final_pos, waypoint, reason, opts, state)
  local r=M.root(); local key=pair_key(pair); if not key then return nil end
  local seq=next_sequence(pair)
  local lease={
    tick=now(), sequence=seq, state=state or "planned", owner=tostring(opts and opts.owner or reason or "movement"), reason=tostring(reason or "movement"),
    final_x=final_pos and final_pos.x, final_y=final_pos and final_pos.y, waypoint_x=waypoint and waypoint.x, waypoint_y=waypoint and waypoint.y,
    radius=tonumber(opts and opts.radius) or M.default_radius, ttl=tonumber(opts and opts.ttl) or M.default_ttl,
  }
  r.leases[key]=lease
  if pair then pair.ground_route_0633=lease end
  return lease
end

local function compute_waypoint(pair, pos)
  if not (valid_pair(pair) and pos and pos.x and pos.y) then return nil, 0 end
  local d=dist(pair.priest.position,pos) or 0
  if d <= M.max_visible_waypoint then return pos, d end
  local ratio=M.max_visible_waypoint / math.max(d,0.0001)
  return { x=pair.priest.position.x + ((pos.x or 0)-pair.priest.position.x)*ratio, y=pair.priest.position.y + ((pos.y or 0)-pair.priest.position.y)*ratio }, d
end

local function route_request(pair, pos, reason, opts, ...)
  opts=opts or {}
  local r=M.root()
  if r.enabled == false then return pre_request(pair,pos,reason,opts,...) end
  if not (valid_pair(pair) and pos and pos.x and pos.y) then return pre_request(pair,pos,reason,opts,...) end
  if is_void_pair(pair) then stat("void-skipped-0633"); return pre_request(pair,pos,reason,opts,...) end

  local allowed, why = final_allowed(pair,pos,reason,opts)
  if not allowed then
    remember_lease(pair,pos,nil,reason,opts,"rejected")
    record("ground-route-final-rejected-0633", pair, "why="..safe(why).." reason="..safe(reason).." dest="..safe(string.format("%.1f,%.1f",pos.x or 0,pos.y or 0)), true)
    return false
  end

  if is_return_or_recovery(reason, opts) or is_route_internal(reason, opts) or r.chunk_visible_moves == false then
    remember_lease(pair,pos,pos,reason,opts,"pass-through")
    stat("ground-route-pass-through-0633")
    return pre_request(pair,pos,reason,opts,...)
  end

  local waypoint, d = compute_waypoint(pair,pos)
  if not waypoint then return pre_request(pair,pos,reason,opts,...) end
  if d > M.max_visible_waypoint and (math.abs((waypoint.x or 0)-(pos.x or 0)) > 0.01 or math.abs((waypoint.y or 0)-(pos.y or 0)) > 0.01) then
    local new_opts={}
    for k,v in pairs(opts or {}) do new_opts[k]=v end
    new_opts.owner="ground-route-authority-0633"
    new_opts.radius=tonumber(opts.radius) or M.default_radius
    new_opts.ttl=tonumber(opts.ttl) or M.default_ttl
    if defines and defines.distraction then new_opts.distraction=defines.distraction.none end
    remember_lease(pair,pos,waypoint,reason,new_opts,"moving-waypoint")
    record("ground-route-waypoint-0633", pair, "owner="..safe(opts.owner or reason).." final="..safe(string.format("%.1f,%.1f",pos.x or 0,pos.y or 0)).." waypoint="..safe(string.format("%.1f,%.1f",waypoint.x or 0,waypoint.y or 0)).." dist="..safe(string.format("%.1f",d)))
    return pre_request(pair, waypoint, "ground-route-waypoint-0633", new_opts, ...)
  end

  remember_lease(pair,pos,pos,reason,opts,"moving-final")
  stat("ground-route-final-0633")
  return pre_request(pair,pos,reason,opts,...)
end

function M.wrap_request()
  if type(_G.tech_priests_request_movement_0418) ~= "function" or pre_request then return false end
  pre_request = _G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0633_PRE_REQUEST_MOVEMENT_0418 = pre_request
  _G.tech_priests_request_movement_0418 = function(pair,pos,reason,opts,...)
    return route_request(pair,pos,reason,opts,...)
  end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-ground-route-0633") end end)
  commands.add_command("tp-ground-route-0633", "Tech Priests 0.1.642: Ground Route Authority diagnostics. Params: on/off/chunk-on/chunk-off/status", function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local p=lower(event and event.parameter or "status")
    local r=M.root()
    if p=="on" then r.enabled=true elseif p=="off" then r.enabled=false elseif p=="chunk-on" then r.chunk_visible_moves=true elseif p=="chunk-off" then r.chunk_visible_moves=false end
    local active=0; for _ in pairs(r.leases or {}) do active=active+1 end
    local msg="[tp-ground-route-0633] enabled="..safe(r.enabled).." chunk_visible="..safe(r.chunk_visible_moves).." leases="..safe(active).." waypoints="..safe(r.stats["ground-route-waypoint-0633"] or 0).." final="..safe(r.stats["ground-route-final-0633"] or 0).." rejected="..safe(r.stats["ground-route-final-rejected-0633"] or 0).." void_skips="..safe(r.stats["void-skipped-0633"] or 0)
    if player and player.valid then
      player.print(msg)
      for i=math.max(1,#r.recent-6),#r.recent do local ev=r.recent[i]; if ev then player.print("  ["..safe(ev.tick).."] "..safe(ev.action).." station="..safe(ev.station).." priest="..safe(ev.priest).." "..safe(ev.detail)) end end
    elseif game and game.print then game.print(msg) end
  end)
end

local function install_0634_0635_0637_0638_0639_0640_0642_repairs()
  local ok_inv, Inv0634 = pcall(require, "scripts.core.station_area_change_invalidator_0634")
  if ok_inv and Inv0634 and type(Inv0634.install)=="function" then pcall(Inv0634.install) end
  local ok_struct, Gui0635 = pcall(require, "scripts.core.gui_nested_frame_repair_0635")
  if ok_struct and Gui0635 and type(Gui0635.install)=="function" then pcall(Gui0635.install) end
  -- 0.1.638: install the generic deposit safety guard before the disabled
  -- bootstrap governor is registered, so direct-acquisition deposit calls cannot
  -- fall through into machine/furnace/result inventories.
  local ok_safety, Deposit0638 = pcall(require, "scripts.core.inventory_deposit_safety_0638")
  if ok_safety and Deposit0638 and type(Deposit0638.install)=="function" then pcall(Deposit0638.install) end
  local ok_supply, Supply0639 = pcall(require, "scripts.core.station_supply_satisfaction_0639")
  if ok_supply and Supply0639 and type(Supply0639.install)=="function" then pcall(Supply0639.install) end
  local ok_infra, Infra0640 = pcall(require, "scripts.core.infrastructure_first_governor_0640")
  if ok_infra and Infra0640 and type(Infra0640.install)=="function" then pcall(Infra0640.install) end
  local ok_monitor, Monitor0642 = pcall(require, "scripts.core.behavior_tree_monitor_0642")
  if ok_monitor and Monitor0642 and type(Monitor0642.install)=="function" then pcall(Monitor0642.install) end
  local ok_bootstrap, Bootstrap0637 = pcall(require, "scripts.core.bootstrap_resource_governor_0637")
  if ok_bootstrap and Bootstrap0637 and type(Bootstrap0637.install)=="function" then pcall(Bootstrap0637.install) end
end

function M.install()
  M.root()
  M.wrap_request()
  install_0634_0635_0637_0638_0639_0640_0642_repairs()
  install_command()
  _G.TechPriestsGroundRouteAuthority0633 = M
  if log then log("[Tech-Priests 0.1.642] Ground Route Authority installed; movement leases, deposit safety, stale supply clearing, infrastructure-first gating, and behavior-tree monitoring active") end
  return true
end

return M
