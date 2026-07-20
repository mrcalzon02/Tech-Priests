-- scripts/core/authority_corridor_pathing_0574.lua
-- Tech Priests 0.1.674-dev canonical corridor route planner.
--
-- Movement half of the authority-corridor model.  This module does not choose
-- work and does not complete work.  It guards the existing movement request
-- API so priests normally path only inside home station coverage; while carrying
-- a valid superior writ/order, subordinates may also path inside authorized
-- superior station spheres.  Long authorized moves can be decomposed into a
-- station-corridor waypoint instead of one wilderness path request.

local M = {}
M.version = "0.1.674-dev"
M.storage_key = "authority_corridor_pathing_0574"

M.default_radius = 32
M.default_chunk = 36
M.log_interval = 900
M.chunk_radius = 1.2

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return nil end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function dist(a,b) local d2=dist_sq(a,b); return d2 and math.sqrt(d2) or nil end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      planner_enabled = true,
      decompose_long_moves = true,
      stats = {}, recent = {}, last_log = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.planner_enabled == nil then r.planner_enabled = true end
  if r.decompose_long_moves == nil then r.decompose_long_moves = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}; r.last_log = r.last_log or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(action, pair, detail, force)
  local r=M.root(); action=tostring(action or "event")
  stat(action)
  local rec={tick=now(), action=action, station=station_unit(pair), priest=priest_unit(pair), detail=tostring(detail or "")}
  r.recent[#r.recent+1]=rec
  while #r.recent>96 do table.remove(r.recent,1) end
  local key=action..":"..safe(rec.station)
  local last=tonumber(r.last_log[key] or -1000000) or -1000000
  if force or now()-last >= M.log_interval then
    r.last_log[key]=now()
    if log then log("[Tech-Priests 0.1.574] "..action.." station="..safe(rec.station).." priest="..safe(rec.priest).." "..safe(detail)) end
  end
  return rec
end

local function runtime_radius(pair)
  local r = tonumber(pair and pair.radius) or tonumber(pair and pair.base_radius) or nil
  if _G.refresh_pair_radius and pair then local ok, got = pcall(_G.refresh_pair_radius, pair); if ok and tonumber(got) then r = tonumber(got) end end
  if (not r) and _G.get_station_operating_radius and valid(pair and pair.station) then local ok, got = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(got) then r = tonumber(got) end end
  return r or M.default_radius
end

local function is_return_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("return",1,true) or s:find("home",1,true) or s:find("overleash",1,true) or s:find("station",1,true)
end
local function is_recovery_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  return s:find("recovery",1,true) or s:find("respawn",1,true) or s:find("pair%-link",1,false)
end
local function is_exempt_reason(reason, opts)
  local s=lower(reason).." "..lower(opts and opts.owner or "")
  if is_return_reason(reason, opts) or is_recovery_reason(reason, opts) then return true end
  if s:find("combat",1,true) or s:find("retreat",1,true) or s:find("flee",1,true) then return true end
  if s:find("conversation",1,true) or s:find("approach%-player",1,false) then return true end
  if s:find("corridor%-waypoint%-0574",1,false) then return true end
  return false
end

local function authorized_pairs(pair)
  if type(_G.tech_priests_0573_authorized_pairs) == "function" then
    local ok, list, order, source = pcall(_G.tech_priests_0573_authorized_pairs, pair)
    if ok and type(list)=="table" and #list>0 then return list, order, source end
  end
  return valid_pair(pair) and {{pair=pair, role="home", station_unit=station_unit(pair)}} or {}, nil, "fallback-home"
end

local function station_rec_contains(rec, pos)
  local p = rec and rec.pair
  if not (valid_pair(p) and pos and p.station.surface == (pos.surface or p.station.surface)) then return false, nil, nil end
  local radius = runtime_radius(p)
  local d = dist(p.station.position, pos) or 0
  return d <= radius, d, radius
end

local function destination_surface(pair, pos)
  if pos and pos.surface then return pos.surface end
  return valid(pair and pair.station) and pair.station.surface or nil
end

function M.authorization_for_destination(pair, pos, reason, opts)
  if not (valid_pair(pair) and pos) then return true, nil, "invalid-or-no-pos" end
  if is_exempt_reason(reason, opts) then return true, {pair=pair, role="exempt", station_unit=station_unit(pair)}, "exempt" end
  local surface = destination_surface(pair, pos)
  local auth, order, source = authorized_pairs(pair)
  local best, best_d = nil, nil
  for _, rec in ipairs(auth or {}) do
    local p = rec.pair
    if valid_pair(p) and p.station.surface == surface and p.station.force == pair.station.force then
      local ok, d, radius = station_rec_contains(rec, pos)
      if ok then return true, rec, source or "authorized" end
      if d and (not best_d or d < best_d) then best, best_d = rec, d end
    end
  end
  return false, best, source or "not-authorized"
end

function M.position_allowed(pair, pos, reason, opts)
  local ok = M.authorization_for_destination(pair, pos, reason, opts)
  return ok
end


function M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
  local r=M.root()
  if r.enabled == false or r.decompose_long_moves == false then return nil end
  if not (valid_pair(pair) and pos and rec and valid_pair(rec.pair)) then return nil end
  if rec.role == "home" or rec.role == "exempt" then return nil end
  if pair.priest.surface ~= rec.pair.station.surface then return nil end
  local pd = dist(pair.priest.position, pos) or 0
  local in_auth_now = (dist(pair.priest.position, rec.pair.station.position) or 0) <= runtime_radius(rec.pair)
  if pd <= M.default_chunk or in_auth_now then return nil end
  -- Do not issue one long visible path.  Send the priest to the superior station
  -- first; the existing executor will reissue the work movement once corridor
  -- coverage has been entered.
  return rec.pair.station.position, rec
end

function M.plan_request(pair, pos, reason, opts)
  local r=M.root()
  if r.enabled == false or r.planner_enabled == false then return true, pos, nil end
  if not (valid_pair(pair) and pos) then return true, pos, nil end
  local ok, rec, source = M.authorization_for_destination(pair, pos, reason, opts)
  if not ok then
    record("corridor-move-rejected-0574", pair, "source="..safe(source).." dest="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)).." nearest="..safe(rec and rec.station_unit or "none").." reason="..safe(reason).." owner="..safe(opts and opts.owner))
    return false, pos, { source=source, nearest_station_unit=rec and rec.station_unit or nil }
  end
  if rec and rec.role and rec.role ~= "home" and rec.role ~= "exempt" then stat("authorized_superior_move") end
  local waypoint, waypoint_rec = M.maybe_corridor_waypoint(pair, pos, reason, opts, rec)
  if waypoint then
    record("corridor-waypoint-0574", pair, "role="..safe(waypoint_rec.role).." via="..safe(waypoint_rec.station_unit).." final="..safe(string.format("%.1f,%.1f", pos.x or 0, pos.y or 0)))
    return true, waypoint, {
      radius=M.chunk_radius,
      priority=math.max(tonumber(opts and opts.priority or 0) or 0, 700),
      ttl=tonumber(opts and opts.ttl or 600) or 600,
      distraction=opts and opts.distraction,
      corridor_waypoint=true,
      corridor_role=waypoint_rec.role,
      corridor_station_unit=waypoint_rec.station_unit,
      corridor_final_destination={x=pos.x,y=pos.y},
    }
  end
  return true, pos, nil
end

function M.install()
  M.root()
  _G.TECH_PRIESTS_AUTHORITY_CORRIDOR_PATHING_0574 = M
  _G.tech_priests_0574_position_allowed = M.position_allowed
  _G.tech_priests_0574_authorization_for_destination = M.authorization_for_destination
  _G.tech_priests_0574_plan_request = M.plan_request
  record("install", nil, "observer-only corridor route planner installed", true)
  if log then log("[Tech-Priests 0.1.674-dev] observer-only Cogitator corridor route planner installed") end
  return true
end

return M