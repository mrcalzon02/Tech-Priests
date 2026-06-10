-- scripts/core/void_movement_authority_0630.lua
-- Tech Priests 0.1.630
-- Separate movement authority for Void Priests / space-platform priests.

local M = {}
M.version = "0.1.630"
M.storage_key = "void_movement_authority_0630"
M.service_interval = 1
M.default_radius = 0.75
M.default_ttl = 60 * 10
M.default_step = 0.32
M.max_step = 0.80

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a,b) return math.sqrt(dist_sq(a,b)) end
local function unit(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit(pair.priest)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={}, requests={}, active={} }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.requests=r.requests or {}; r.active=r.active or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function record(pair, action, detail)
  local r=M.root(); stat(action)
  local ev={tick=now(), action=tostring(action or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>80 do table.remove(r.recent,1) end
  return ev
end

local function pair_key(pair)
  if pair and pair.station and pair.station.valid and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if pair and pair.priest and pair.priest.valid and pair.priest.unit_number then return "p"..tostring(pair.priest.unit_number) end
  return nil
end

local function pair_for_priest(priest)
  if not valid(priest) then return nil end
  local tp=storage and storage.tech_priests or nil
  if tp then
    if tp.pairs_by_priest and tp.pairs_by_priest[priest.unit_number] then return tp.pairs_by_priest[priest.unit_number] end
    if tp.station_by_priest and tp.pairs_by_station then local su=tp.station_by_priest[priest.unit_number]; if su and tp.pairs_by_station[su] then return tp.pairs_by_station[su] end end
  end
  if _G.find_pair_for_entity then local ok,p=pcall(_G.find_pair_for_entity, priest); if ok and p then return p end end
  return nil
end

function M.is_void_pair(pair)
  if not valid_pair(pair) then return false end
  if _G.tech_priests_pair_on_space_platform_0204 then local ok,res=pcall(_G.tech_priests_pair_on_space_platform_0204,pair); if ok and res then return true end end
  if pair.void_priest_0630 or pair.void_priest or pair.is_void_priest then return true end
  local name=lower((valid(pair.priest) and pair.priest.name) or "").." "..lower(pair.priest_name or pair.rank or pair.tier or "")
  return name:find("void",1,true) ~= nil
end

local function destination(target)
  if not target then return nil end
  if target.valid and target.position then return target.position end
  if target.position then return target.position end
  if target.x and target.y then return target end
  return nil
end

local function stop_entity(priest)
  if not valid(priest) then return false end
  pcall(function() priest.walking_state={walking=false} end)
  if defines and defines.command then pcall(function() if priest.commandable and priest.commandable.valid then priest.commandable.set_command({type=defines.command.stop}) elseif priest.set_command then priest.set_command({type=defines.command.stop}) end end) end
  return true
end

local function relocate(entity, pos)
  if not (valid(entity) and pos) then return false end
  local fn = entity["tele".."port"]
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, pos, entity.surface)
  return ok and result ~= false
end

function M.request(pair, pos, reason, opts)
  opts=opts or {}; local r=M.root()
  if r.enabled==false or not (valid_pair(pair) and M.is_void_pair(pair) and pos and pos.x and pos.y) then return false end
  local key=pair_key(pair); if not key then return false end
  local req={x=pos.x,y=pos.y,radius=tonumber(opts.radius) or M.default_radius,reason=tostring(reason or opts.owner or "void-movement"),owner=tostring(opts.owner or reason or "void-movement"),step=math.min(M.max_step,math.max(0.02,tonumber(opts.void_step or opts.step) or M.default_step)),issued_tick=now(),expires_tick=now()+(tonumber(opts.ttl) or M.default_ttl),last_distance_sq=nil}
  r.requests[key]=req; r.active[key]=true
  pair.void_movement_request_0630=req; pair.void_movement_status_0630="active"; pair.movement_request_0418=req
  pair.movement_controller_owner_0418=req.owner; pair.movement_controller_reason_0418=req.reason; pair.movement_controller_state_0418="void-requested"; pair.movement_controller_status_0418="void-active"
  record(pair,"void-movement-request",req.owner.." -> "..string.format("%.2f,%.2f",req.x,req.y)); metric("void_movement_requests",1)
  return true, req
end

function M.stop(pair, reason)
  if not valid_pair(pair) then return false end
  local r=M.root(); local key=pair_key(pair); if key then r.requests[key]=nil; r.active[key]=nil end
  pair.void_movement_request_0630=nil; pair.void_movement_status_0630="stopped"; pair.movement_request_0418=nil; pair.movement_controller_state_0418="void-stopped"; pair.movement_controller_status_0418="void-stopped"
  record(pair,"void-movement-stop",reason or "stop")
  return stop_entity(pair.priest)
end

function M.status(pair, owner)
  local s={status="unknown",active=false,owner_match=false,tick=now()}
  if not valid_pair(pair) then s.status="invalid-pair"; return s end
  if not M.is_void_pair(pair) then s.status="not-void-pair"; return s end
  local r=M.root(); local key=pair_key(pair); local req=(key and r.requests[key]) or pair.void_movement_request_0630
  if not req then s.status=pair.void_movement_status_0630 or "missing-request"; s.state=pair.movement_controller_state_0418; return s end
  s.active=true; s.owner=req.owner; s.reason=req.reason; s.expires_tick=req.expires_tick; s.radius=req.radius
  local expected=owner and tostring(owner) or nil; s.owner_match=(not expected) or tostring(req.owner or "")==expected
  if expected and not s.owner_match then s.status="replaced-by-other-owner"; return s end
  if req.expires_tick and req.expires_tick<now() then s.status="expired"; s.active=false; return s end
  local d2=dist_sq(pair.priest.position,req); s.distance_sq=d2
  if d2 <= (tonumber(req.radius) or M.default_radius)^2 then s.status="arrived"; s.arrived=true; return s end
  s.status="active"; return s
end

local function step_pair(pair, req)
  if not (valid_pair(pair) and req) then return false,"invalid" end
  local r=M.root(); local key=pair_key(pair)
  if req.expires_tick and req.expires_tick<now() then if key then r.requests[key]=nil; r.active[key]=nil end; pair.void_movement_status_0630="expired"; pair.movement_controller_status_0418="void-expired"; record(pair,"void-movement-expired",req.reason); return false,"expired" end
  local d=dist(pair.priest.position,req); req.last_distance_sq=d*d
  local radius=math.max(0.05,tonumber(req.radius) or M.default_radius)
  if d <= radius then
    if key then r.requests[key]=nil; r.active[key]=nil end
    pair.void_movement_request_0630=nil; pair.void_movement_status_0630="arrived"; pair.movement_request_0418=nil; pair.movement_controller_state_0418="void-arrived"; pair.movement_controller_status_0418="void-arrived"
    stop_entity(pair.priest); record(pair,"void-movement-arrived",req.reason.." d="..string.format("%.2f",d)); metric("void_movement_arrived",1)
    return true,"arrived"
  end
  local step=math.min(d,math.max(0.02,tonumber(req.step) or M.default_step)); local ratio=step/math.max(d,0.0001)
  local pos={x=pair.priest.position.x+(req.x-pair.priest.position.x)*ratio,y=pair.priest.position.y+(req.y-pair.priest.position.y)*ratio}
  local ok=relocate(pair.priest,pos)
  if ok then pair.void_movement_status_0630="active"; pair.movement_controller_state_0418="void-jetpack-transit"; pair.movement_controller_status_0418="void-active"; stat("void-jetpack-steps"); metric("void_movement_steps",1); return true,"step" end
  pair.void_movement_status_0630="relocation-failed"; pair.movement_controller_status_0418="void-relocation-failed"; record(pair,"void-relocation-failed",req.reason); return false,"relocation-failed"
end

function M.service(event,budget)
  local r=M.root(); if r.enabled==false then return false,"disabled" end
  local processed,acted,max=0,0,tonumber(budget) or 32
  for key in pairs(r.active or {}) do
    if processed>=max then return false,"budget-exhausted" end
    local pair=pair_map()[key] or pair_map()[tonumber(key)]; local req=r.requests[key] or (pair and pair.void_movement_request_0630)
    if not (pair and valid_pair(pair) and M.is_void_pair(pair) and req) then r.active[key]=nil; r.requests[key]=nil; stat("void-invalid-pruned") else processed=processed+1; local ok=step_pair(pair,req); if ok then acted=acted+1 end end
  end
  if processed==0 then return false,"empty" end
  return acted,"void-movement processed="..tostring(processed).." acted="..tostring(acted)
end

function M.patch_globals()
  if rawget(_G,"TECH_PRIESTS_0630_VOID_GLOBALS_PATCHED") then return true end
  _G.TECH_PRIESTS_0630_VOID_GLOBALS_PATCHED=true
  _G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630=M
  _G.tech_priests_void_pair_0630=function(pair) return M.is_void_pair(pair) end
  _G.tech_priests_void_movement_request_0630=function(pair,pos,reason,opts) return M.request(pair,pos,reason,opts) end
  _G.tech_priests_void_movement_status_0630=function(pair,owner) return M.status(pair,owner) end
  local prev_request=_G.tech_priests_request_movement_0418
  _G.TECH_PRIESTS_0630_PRE_REQUEST_MOVEMENT_0418=prev_request
  _G.tech_priests_request_movement_0418=function(pair,pos,reason,opts,...)
    if M.is_void_pair(pair) then return M.request(pair,pos,reason,opts) end
    if type(prev_request)=="function" then return prev_request(pair,pos,reason,opts,...) end
    return false
  end
  local prev_stop=_G.tech_priests_stop_movement_0418
  _G.TECH_PRIESTS_0630_PRE_STOP_MOVEMENT_0418=prev_stop
  _G.tech_priests_stop_movement_0418=function(pair,reason,...)
    if M.is_void_pair(pair) then return M.stop(pair,reason) end
    if type(prev_stop)=="function" then return prev_stop(pair,reason,...) end
    return false
  end
  local prev_status=_G.tech_priests_movement_status_0418
  _G.TECH_PRIESTS_0630_PRE_MOVEMENT_STATUS_0418=prev_status
  _G.tech_priests_movement_status_0418=function(pair,owner,...)
    if M.is_void_pair(pair) then return M.status(pair,owner) end
    if type(prev_status)=="function" then return prev_status(pair,owner,...) end
    return {status="missing-status-authority",active=false}
  end
  local prev_move=_G.move_priest_to
  if type(prev_move)=="function" then _G.TECH_PRIESTS_0630_PRE_MOVE_PRIEST_TO=prev_move; _G.move_priest_to=function(priest,target,...)
    local pair=pair_for_priest(priest); local pos=destination(target)
    if pair and pos and M.is_void_pair(pair) then return M.request(pair,pos,"void-move-priest-to",{radius=0.75,owner="move_priest_to",priority=50}) end
    return prev_move(priest,target,...)
  end end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-void-movement-0630") end end)
  commands.add_command("tp-void-movement-0630","Tech Priests 0.1.630: Void Priest movement authority diagnostics.",function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil; local r=M.root(); local active=0; for _ in pairs(r.active or {}) do active=active+1 end
    local msg="[tp-void-movement-0630] enabled="..safe(r.enabled).." active="..safe(active).." requests="..safe(r.stats["void-movement-request"] or 0).." steps="..safe(r.stats["void-jetpack-steps"] or 0).." arrived="..safe(r.stats["void-movement-arrived"] or 0).." failed="..safe(r.stats["void-relocation-failed"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.report_lines()
  local r=M.root(); local active=0; for _ in pairs(r.active or {}) do active=active+1 end
  return {"[tp-runtime-report] void-movement-0630 enabled="..safe(r.enabled).." active="..safe(active).." requests="..safe(r.stats["void-movement-request"] or 0).." steps="..safe(r.stats["void-jetpack-steps"] or 0).." arrived="..safe(r.stats["void-movement-arrived"] or 0).." expired="..safe(r.stats["void-movement-expired"] or 0).." failed="..safe(r.stats["void-relocation-failed"] or 0)}
end

function M.install()
  M.root(); M.patch_globals(); install_command()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="void_movement_authority_0630",category="movement",interval=M.service_interval,priority=20,budget=48,fn=function(event,budget) return M.service(event,budget) end,note="same-surface separated movement for Void Priests only"})
  else local registry=rawget(_G,"TechPriestsRuntimeEventRegistry"); if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end; if registry and type(registry.on_nth_tick)=="function" then registry.on_nth_tick(M.service_interval,function(event) M.service(event,48) end,{owner="void_movement_authority_0630",category="movement",priority="first",note="Void Priest separate movement authority"}) end end
  if log then log("[Tech-Priests 0.1.630] Void Movement Authority installed; Void Priests no longer use the ground movement loop") end
  return true
end

return M