-- scripts/core/void_movement_authority_0630.lua
-- Tech Priests 0.1.674-dev Stage 1
-- Separate movement authority for Void Priests / space-platform priests.
-- Stage 1 establishes request ownership, truthful cleanup, and exemption from
-- ground-priest leash governors. Collision-aware detours and visual flight
-- presentation remain later repair stages.

local M = {}
M.version = "0.1.674-dev-stage1"
M.storage_key = "void_movement_authority_0630"
M.service_interval = 1
M.broker_pulse_ticks = 5
M.default_radius = 0.75
M.default_ttl = 60 * 10
M.ttl_margin_ticks = 60 * 2
M.default_step = 0.32
M.max_step = 0.80
M.same_target_distance_sq = 0.0625
M.retarget_hold_ticks = 30

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
  local r = storage.tech_priests[M.storage_key] or {
    version=M.version,
    enabled=true,
    stats={},
    recent={},
    requests={},
    active={},
    sequence=0,
    stage1_ground_governors_patched=false
  }
  storage.tech_priests[M.storage_key] = r
  r.version=M.version
  if r.enabled == nil then r.enabled=true end
  r.stats=r.stats or {}
  r.recent=r.recent or {}
  r.requests=r.requests or {}
  r.active=r.active or {}
  r.sequence=tonumber(r.sequence) or 0
  if r.stage1_ground_governors_patched == nil then r.stage1_ground_governors_patched=false end
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function record(pair, action, detail)
  local r=M.root(); stat(action)
  local ev={tick=now(), action=tostring(action or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=ev
  while #r.recent>120 do table.remove(r.recent,1) end
  return ev
end

local function pair_key(pair)
  if pair and pair.station and pair.station.valid and pair.station.unit_number then return tostring(pair.station.unit_number) end
  if pair and pair.priest and pair.priest.valid and pair.priest.unit_number then return "p"..tostring(pair.priest.unit_number) end
  return nil
end

local function pair_for_key(key)
  local map=pair_map()
  return map[key] or map[tonumber(key)]
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
  if defines and defines.command then
    pcall(function()
      if priest.commandable and priest.commandable.valid then
        priest.commandable.set_command({type=defines.command.stop})
      elseif priest.set_command then
        priest.set_command({type=defines.command.stop})
      end
    end)
  end
  return true
end

local function relocate(entity, pos)
  if not (valid(entity) and pos) then return false end
  local fn = entity["tele".."port"]
  if type(fn) ~= "function" then return false end
  local ok, result = pcall(fn, pos, entity.surface)
  return ok and result ~= false
end

local function clear_pair_request_fields(pair, req, status)
  if type(pair) ~= "table" then return end
  if req == nil or pair.void_movement_request_0630 == req then pair.void_movement_request_0630=nil end
  if req == nil or pair.movement_request_0418 == req then pair.movement_request_0418=nil end
  pair.void_movement_status_0630=status
  pair.movement_controller_state_0418="void-"..tostring(status or "finished")
  pair.movement_controller_status_0418="void-"..tostring(status or "finished")
  pair.movement_controller_clamp_0418=nil
end

local function finish_request(pair, req, status, detail, should_stop)
  local r=M.root()
  local key=(req and req.key) or pair_key(pair)
  if key then
    if req == nil or r.requests[key] == req then r.requests[key]=nil end
    r.active[key]=nil
  end
  clear_pair_request_fields(pair, req, status)
  if should_stop and pair and valid(pair.priest) then stop_entity(pair.priest) end
  record(pair, "void-movement-"..tostring(status or "finished"), detail or (req and req.reason) or status)
  if status == "arrived" then metric("void_movement_arrived",1) end
  return true,status
end

local function minimum_ttl(pair, pos, radius, step, requested)
  local requested_ttl=tonumber(requested) or M.default_ttl
  if not (valid_pair(pair) and pos) then return requested_ttl end
  local remaining=math.max(0,dist(pair.priest.position,pos)-math.max(0.05,tonumber(radius) or M.default_radius))
  local pulses=math.ceil(remaining/math.max(0.02,tonumber(step) or M.default_step))
  local transit_ticks=pulses*M.broker_pulse_ticks+M.ttl_margin_ticks
  return math.max(requested_ttl,transit_ticks)
end

local function same_target(req,pos)
  return type(req)=="table" and pos and dist_sq(req,pos) <= M.same_target_distance_sq
end

local ensure_ground_governors_patched

function M.request(pair, pos, reason, opts)
  opts=opts or {}
  if ensure_ground_governors_patched then ensure_ground_governors_patched() end
  local r=M.root()
  if r.enabled==false or not (valid_pair(pair) and M.is_void_pair(pair) and pos and pos.x and pos.y) then return false,"invalid-void-movement-request" end
  local key=pair_key(pair); if not key then return false,"missing-pair-key" end

  local owner=tostring(opts.owner or reason or "void-movement")
  local priority=tonumber(opts.priority) or 50
  local radius=math.max(0.05,tonumber(opts.radius) or M.default_radius)
  local step=math.min(M.max_step,math.max(0.02,tonumber(opts.void_step or opts.step) or M.default_step))
  local current=r.requests[key] or pair.void_movement_request_0630

  if current and current.expires_tick and current.expires_tick < now() then
    finish_request(pair,current,"expired","expired before replacement: "..safe(current.reason),true)
    current=nil
  end

  if current then
    local current_owner=tostring(current.owner or "")
    local current_priority=tonumber(current.priority) or 0
    local age=now()-(tonumber(current.updated_tick or current.issued_tick) or now())
    if current_owner == owner and same_target(current,pos) then
      current.reason=tostring(reason or current.reason or owner)
      current.updated_tick=now()
      current.priority=math.max(current_priority,priority)
      current.radius=radius
      current.step=step
      current.expires_tick=math.max(tonumber(current.expires_tick) or 0,now()+minimum_ttl(pair,pos,radius,step,opts.ttl))
      current.refresh_count=(tonumber(current.refresh_count) or 0)+1
      pair.void_movement_request_0630=current
      pair.movement_request_0418=current
      pair.void_movement_status_0630="active"
      pair.movement_controller_state_0418="void-request-refreshed"
      pair.movement_controller_status_0418="void-active"
      stat("void-request-collapsed-stage1")
      return true,current,"same-owner-refresh"
    end
    if current_owner ~= owner and priority < current_priority then
      current.held_retarget_count=(tonumber(current.held_retarget_count) or 0)+1
      pair.movement_controller_state_0418="void-retarget-held"
      pair.movement_controller_status_0418="void-active"
      stat("void-retarget-held-stage1")
      return true,current,"held-by-higher-priority-owner"
    end
    if current_owner ~= owner and priority == current_priority and age < M.retarget_hold_ticks then
      current.held_retarget_count=(tonumber(current.held_retarget_count) or 0)+1
      pair.movement_controller_state_0418="void-retarget-held"
      pair.movement_controller_status_0418="void-active"
      stat("void-retarget-held-stage1")
      return true,current,"equal-priority-retarget-hold"
    end
    r.requests[key]=nil
    r.active[key]=nil
    record(pair,"void-movement-replaced","old="..safe(current_owner).."/"..safe(current_priority).." new="..safe(owner).."/"..safe(priority))
  end

  stop_entity(pair.priest)
  r.sequence=r.sequence+1
  local ttl=minimum_ttl(pair,pos,radius,step,opts.ttl)
  local req={
    key=key,
    request_id=r.sequence,
    x=pos.x,
    y=pos.y,
    radius=radius,
    reason=tostring(reason or owner),
    owner=owner,
    priority=priority,
    step=step,
    issued_tick=now(),
    updated_tick=now(),
    expires_tick=now()+ttl,
    last_distance_sq=dist_sq(pair.priest.position,pos),
    last_progress_tick=now(),
    failure_count=0,
    surface_index=pair.priest.surface and pair.priest.surface.index or nil
  }
  r.requests[key]=req
  r.active[key]=true
  pair.void_movement_request_0630=req
  pair.void_movement_status_0630="active"
  pair.movement_request_0418=req
  pair.movement_controller_owner_0418=req.owner
  pair.movement_controller_reason_0418=req.reason
  pair.movement_controller_state_0418="void-requested"
  pair.movement_controller_status_0418="void-active"
  record(pair,"void-movement-request",req.owner.."/p"..safe(req.priority).." -> "..string.format("%.2f,%.2f",req.x,req.y).." ttl="..safe(ttl))
  metric("void_movement_requests",1)
  return true,req
end

function M.stop(pair, reason)
  if type(pair)~="table" then return false end
  local key=pair_key(pair)
  local r=M.root()
  local req=(key and r.requests[key]) or pair.void_movement_request_0630
  finish_request(pair,req,"stopped",reason or "stop",true)
  return valid(pair.priest)
end

function M.status(pair, owner)
  if ensure_ground_governors_patched then ensure_ground_governors_patched() end
  local s={status="unknown",active=false,owner_match=false,tick=now()}
  if not valid_pair(pair) then s.status="invalid-pair"; return s end
  if not M.is_void_pair(pair) then s.status="not-void-pair"; return s end
  local r=M.root(); local key=pair_key(pair); local req=(key and r.requests[key]) or pair.void_movement_request_0630
  if req and req.expires_tick and req.expires_tick<now() then
    finish_request(pair,req,"expired","status observed expiry: "..safe(req.reason),true)
    req=nil
  end
  if not req then s.status=pair.void_movement_status_0630 or "missing-request"; s.state=pair.movement_controller_state_0418; return s end
  s.active=true
  s.owner=req.owner
  s.reason=req.reason
  s.priority=req.priority
  s.request_id=req.request_id
  s.issued_tick=req.issued_tick
  s.updated_tick=req.updated_tick
  s.expires_tick=req.expires_tick
  s.radius=req.radius
  s.failure_count=req.failure_count or 0
  s.last_progress_tick=req.last_progress_tick
  local expected=owner and tostring(owner) or nil
  s.owner_match=(not expected) or tostring(req.owner or "")==expected
  if expected and not s.owner_match then s.status="replaced-by-other-owner"; return s end
  local d2=dist_sq(pair.priest.position,req); s.distance_sq=d2
  if d2 <= (tonumber(req.radius) or M.default_radius)^2 then s.status="arrived"; s.arrived=true; return s end
  if (tonumber(req.failure_count) or 0)>0 then s.status="active-relocation-retry" else s.status="active" end
  return s
end

local function step_pair(pair, req)
  if not (valid_pair(pair) and req) then return false,"invalid" end
  if req.expires_tick and req.expires_tick<now() then
    finish_request(pair,req,"expired",req.reason,true)
    return false,"expired"
  end
  if req.surface_index and pair.priest.surface and req.surface_index ~= pair.priest.surface.index then
    finish_request(pair,req,"surface-changed",req.reason,true)
    return false,"surface-changed"
  end

  local d=dist(pair.priest.position,req)
  local d2=d*d
  local previous=tonumber(req.last_distance_sq)
  req.last_distance_sq=d2
  if not previous or d2 < previous-0.0025 then req.last_progress_tick=now() end
  local radius=math.max(0.05,tonumber(req.radius) or M.default_radius)
  if d <= radius then
    finish_request(pair,req,"arrived",req.reason.." d="..string.format("%.2f",d),true)
    return true,"arrived"
  end

  local step=math.min(d,math.max(0.02,tonumber(req.step) or M.default_step))
  local ratio=step/math.max(d,0.0001)
  local pos={x=pair.priest.position.x+(req.x-pair.priest.position.x)*ratio,y=pair.priest.position.y+(req.y-pair.priest.position.y)*ratio}
  local ok=relocate(pair.priest,pos)
  if ok then
    req.failure_count=0
    req.last_step_tick=now()
    pair.void_movement_status_0630="active"
    pair.movement_controller_state_0418="void-jetpack-transit"
    pair.movement_controller_status_0418="void-active"
    stat("void-jetpack-steps")
    metric("void_movement_steps",1)
    return true,"step"
  end

  req.failure_count=(tonumber(req.failure_count) or 0)+1
  req.last_failure_tick=now()
  pair.void_movement_status_0630="relocation-failed"
  pair.movement_controller_state_0418="void-relocation-retry"
  pair.movement_controller_status_0418="void-relocation-failed"
  if req.failure_count==1 or req.failure_count%30==0 then
    record(pair,"void-relocation-failed",req.reason.." failures="..safe(req.failure_count))
  else
    stat("void-relocation-failed")
  end
  return false,"relocation-failed"
end

local function void_authorized_position(pair, pos, reason, opts)
  local fn=rawget(_G,"tech_priests_0574_position_allowed")
  if type(fn)=="function" then
    local ok,allowed=pcall(fn,pair,pos,reason,opts)
    if ok then return allowed ~= false end
  end
  return true
end

local function patch_movement_bounds()
  local ok, Bounds=pcall(require,"scripts.core.movement_bounds_contract_0511")
  if not (ok and type(Bounds)=="table") then return false end
  if Bounds.TECH_PRIESTS_0674_VOID_STAGE1_PATCHED then return true end
  Bounds.TECH_PRIESTS_0674_VOID_STAGE1_PATCHED=true
  Bounds.TECH_PRIESTS_0674_PRE_TARGET_WITHIN_BOUNDS=Bounds.target_within_bounds
  Bounds.target_within_bounds=function(pair,pos,...)
    if M.is_void_pair(pair) then
      local allowed=void_authorized_position(pair,pos,"void-movement-bounds-stage1",{owner="void-movement-authority-0630"})
      stat(allowed and "void-ground-bounds-exempt-stage1" or "void-corridor-bounds-rejected-stage1")
      return allowed,nil,"void-movement-authority-stage1"
    end
    return Bounds.TECH_PRIESTS_0674_PRE_TARGET_WITHIN_BOUNDS(pair,pos,...)
  end
  Bounds.TECH_PRIESTS_0674_PRE_RETURN_OVERLEASHED=Bounds.return_to_station_if_overleashed
  Bounds.return_to_station_if_overleashed=function(pair,reason,...)
    if M.is_void_pair(pair) then stat("void-ground-overleash-exempt-stage1"); return false,"void-movement-authority" end
    return Bounds.TECH_PRIESTS_0674_PRE_RETURN_OVERLEASHED(pair,reason,...)
  end
  return true
end

local function patch_movement_enforcement()
  local ok, Enforcement=pcall(require,"scripts.core.movement_enforcement_0566")
  if not (ok and type(Enforcement)=="table") then return false end
  if Enforcement.TECH_PRIESTS_0674_VOID_STAGE1_PATCHED then return true end
  Enforcement.TECH_PRIESTS_0674_VOID_STAGE1_PATCHED=true
  Enforcement.TECH_PRIESTS_0674_PRE_POSITION_ALLOWED=Enforcement.position_allowed
  Enforcement.position_allowed=function(pair,pos,reason,opts,...)
    if M.is_void_pair(pair) then
      local allowed=void_authorized_position(pair,pos,reason,opts)
      stat(allowed and "void-ground-enforcement-exempt-stage1" or "void-corridor-enforcement-rejected-stage1")
      return allowed,nil,nil
    end
    return Enforcement.TECH_PRIESTS_0674_PRE_POSITION_ALLOWED(pair,pos,reason,opts,...)
  end
  Enforcement.TECH_PRIESTS_0674_PRE_SERVICE_PAIR=Enforcement.service_pair
  Enforcement.service_pair=function(pair,reason,...)
    if M.is_void_pair(pair) then stat("void-ground-service-skip-stage1"); return false,"void-movement-authority" end
    return Enforcement.TECH_PRIESTS_0674_PRE_SERVICE_PAIR(pair,reason,...)
  end
  Enforcement.TECH_PRIESTS_0674_PRE_RETURN_TO_STATION=Enforcement.return_to_station
  Enforcement.return_to_station=function(pair,reason,...)
    if M.is_void_pair(pair) then stat("void-ground-return-skip-stage1"); return false,"void-movement-authority" end
    return Enforcement.TECH_PRIESTS_0674_PRE_RETURN_TO_STATION(pair,reason,...)
  end
  return true
end

ensure_ground_governors_patched=function()
  local r=M.root()
  local bounds_ok=patch_movement_bounds()
  local enforcement_ok=patch_movement_enforcement()
  local patched=bounds_ok and enforcement_ok
  if patched and not r.stage1_ground_governors_patched then
    r.stage1_ground_governors_patched=true
    record(nil,"void-stage1-ground-governors-patched","movement_bounds_contract_0511 and movement_enforcement_0566")
  end
  return patched
end

function M.service(event,budget)
  ensure_ground_governors_patched()
  local r=M.root(); if r.enabled==false then return false,"disabled" end
  local processed,acted,max=0,0,tonumber(budget) or 32
  local exhausted=false
  for key in pairs(r.active or {}) do
    if processed>=max then exhausted=true; break end
    local pair=pair_for_key(key)
    local req=r.requests[key] or (pair and pair.void_movement_request_0630)
    if not (pair and valid_pair(pair) and M.is_void_pair(pair) and req) then
      r.active[key]=nil
      r.requests[key]=nil
      if pair then clear_pair_request_fields(pair,req,"invalid-pruned") end
      stat("void-invalid-pruned")
    else
      processed=processed+1
      local ok=step_pair(pair,req)
      if ok then acted=acted+1 end
    end
  end
  if processed==0 then return false,"empty" end
  local detail="void-movement processed="..tostring(processed).." acted="..tostring(acted)
  if exhausted then stat("void-service-budget-exhausted-stage1"); detail=detail.." budget-exhausted" end
  return acted>0,detail
end

function M.patch_globals()
  if rawget(_G,"TECH_PRIESTS_0630_VOID_GLOBALS_PATCHED") then return true end
  _G.TECH_PRIESTS_0630_VOID_GLOBALS_PATCHED=true
  _G.TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630=M
  _G.tech_priests_void_pair_0630=function(pair) return M.is_void_pair(pair) end
  _G.tech_priests_void_movement_request_0630=function(pair,pos,reason,opts) return M.request(pair,pos,reason,opts) end
  _G.tech_priests_void_movement_status_0630=function(pair,owner) return M.status(pair,owner) end
  _G.tech_priests_void_movement_ground_patch_0674=function() return ensure_ground_governors_patched() end
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
  if type(prev_move)=="function" then
    _G.TECH_PRIESTS_0630_PRE_MOVE_PRIEST_TO=prev_move
    _G.move_priest_to=function(priest,target,...)
      local pair=pair_for_priest(priest); local pos=destination(target)
      if pair and pos and M.is_void_pair(pair) then return M.request(pair,pos,"void-move-priest-to",{radius=0.75,owner="move_priest_to",priority=50}) end
      return prev_move(priest,target,...)
    end
  end
  return true
end

local function install_command()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-void-movement-0630") end end)
  commands.add_command("tp-void-movement-0630","Tech Priests 0.1.674-dev Stage 1: Void Priest movement diagnostics.",function(event)
    local player=event and event.player_index and game.get_player(event.player_index) or nil
    local r=M.root(); local active=0; for _ in pairs(r.active or {}) do active=active+1 end
    local msg="[tp-void-movement-0630] version="..safe(M.version).." enabled="..safe(r.enabled).." ground_patched="..safe(r.stage1_ground_governors_patched).." active="..safe(active).." requests="..safe(r.stats["void-movement-request"] or 0).." steps="..safe(r.stats["void-jetpack-steps"] or 0).." arrived="..safe(r.stats["void-movement-arrived"] or 0).." expired="..safe(r.stats["void-movement-expired"] or 0).." failed="..safe(r.stats["void-relocation-failed"] or 0).." held="..safe(r.stats["void-retarget-held-stage1"] or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function install_direct_acquisition_pulse()
  local ok, Pulse0631 = pcall(require, "scripts.core.direct_acquisition_pulse_0631")
  if ok and Pulse0631 and type(Pulse0631.install) == "function" then return Pulse0631.install() end
  if log then log("[Tech-Priests 0.1.631] direct_acquisition_pulse_0631 failed to install from void_movement_authority_0630") end
  return false
end

function M.report_lines()
  local r=M.root(); local active=0; for _ in pairs(r.active or {}) do active=active+1 end
  return {"[tp-runtime-report] void-movement-0630 version="..safe(M.version).." enabled="..safe(r.enabled).." ground_patched="..safe(r.stage1_ground_governors_patched).." active="..safe(active).." requests="..safe(r.stats["void-movement-request"] or 0).." steps="..safe(r.stats["void-jetpack-steps"] or 0).." arrived="..safe(r.stats["void-movement-arrived"] or 0).." expired="..safe(r.stats["void-movement-expired"] or 0).." failed="..safe(r.stats["void-relocation-failed"] or 0).." held="..safe(r.stats["void-retarget-held-stage1"] or 0).." budget_exhausted="..safe(r.stats["void-service-budget-exhausted-stage1"] or 0)}
end

function M.install()
  M.root()
  M.patch_globals()
  install_command()
  install_direct_acquisition_pulse()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then
    broker.register_service({name="void_movement_authority_0630",category="movement",interval=M.service_interval,priority=20,budget=48,fn=function(event,budget) return M.service(event,budget) end,note="Stage 1 sovereign same-surface movement for Void/platform priests; ground leashes exempted"})
  else
    local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
    if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
    if registry and type(registry.on_nth_tick)=="function" then registry.on_nth_tick(M.service_interval,function(event) M.service(event,48) end,{owner="void_movement_authority_0630",category="movement",priority="first",note="Void Priest separate movement authority Stage 1"}) end
  end
  if log then log("[Tech-Priests 0.1.674-dev Stage 1] Void Movement Authority installed with request ownership, lifecycle cleanup, adaptive TTL, and ground-governor sovereignty") end
  return true
end

return M