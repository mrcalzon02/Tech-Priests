-- scripts/core/scan_routing_0610.lua
-- Tech Priests 0.1.610
-- Cache-first scan routing helper. This is not a new cache authority: it routes
-- repeated discovery through the existing indexed catalog 0579 and records
-- short negative knowledge for callers that opt in. Direct surface scans remain
-- the fallback when indexed cells are dirty, unknown, or disabled.

local M = {}
M.version = "0.1.612"
M.storage_key = "scan_routing_0610"
M.default_negative_ttl = 60 * 8

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function list_contains(v, needle)
  if v == nil then return true end
  if type(v) == "table" then for _,x in pairs(v) do if x == needle then return true end end; return false end
  return v == needle
end
local function force_matches(filter_force, entity)
  if filter_force == nil then return true end
  if not (valid(entity) and entity.force) then return false end
  if type(filter_force) == "string" then return entity.force.name == filter_force end
  if type(filter_force) == "table" then
    if filter_force.name then return entity.force.name == filter_force.name end
    if filter_force.index then return entity.force.index == filter_force.index end
  end
  return entity.force == filter_force
end
local function area_from_filters(filters)
  if filters.area then return filters.area end
  local p = filters.position
  local r = tonumber(filters.radius)
  if p and r then return {{(p.x or p[1] or 0)-r,(p.y or p[2] or 0)-r},{(p.x or p[1] or 0)+r,(p.y or p[2] or 0)+r}} end
  return nil
end
local function in_radius(entity, filters)
  if not (valid(entity) and filters.position and filters.radius) then return true end
  local p=filters.position; local ep=entity.position or {x=0,y=0}; local dx=(ep.x or 0)-(p.x or p[1] or 0); local dy=(ep.y or 0)-(p.y or p[2] or 0)
  local r=tonumber(filters.radius) or 0
  return dx*dx+dy*dy <= r*r
end
local function matches(entity, filters)
  if not valid(entity) then return false end
  if filters.name ~= nil and not list_contains(filters.name, entity.name) then return false end
  if filters.type ~= nil and not list_contains(filters.type, entity.type) then return false end
  if not force_matches(filters.force, entity) then return false end
  if not in_radius(entity, filters) then return false end
  return true
end
function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then r = { version=M.version, enabled=true, stats={}, negative_until={} }; storage.tech_priests[M.storage_key]=r end
  r.version=M.version; if r.enabled==nil then r.enabled=true end; r.stats=r.stats or {}; r.negative_until=r.negative_until or {}; return r
end
local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function negative_key(category, key) return tostring(category or "scan") .. ":" .. tostring(key or "global") end
function M.should_skip_negative(category, key)
  local r=M.root(); local k=negative_key(category,key); local until_tick=tonumber(r.negative_until[k] or 0) or 0
  if until_tick > now() then stat("negative_skip_"..tostring(category or "scan")); metric("scan_routing_negative_skips",1); metric("negative_cache_skips",1); return true, until_tick end
  if r.negative_until[k] then r.negative_until[k]=nil end
  return false
end
function M.record_negative(category, key, ttl)
  local r=M.root(); r.negative_until[negative_key(category,key)] = now() + (tonumber(ttl) or M.default_negative_ttl); stat("negative_recorded_"..tostring(category or "scan")); return true
end
function M.clear_negative(category, key)
  local r=M.root(); local n=0
  if key then local k=negative_key(category,key); if r.negative_until[k] then r.negative_until[k]=nil; n=1 end
  else for k in pairs(r.negative_until or {}) do if tostring(k):find(tostring(category or "scan")..":",1,true)==1 then r.negative_until[k]=nil; n=n+1 end end end
  if n>0 then stat("negative_cleared", n); metric("scan_routing_negative_clears", n) end
  return n
end
local function indexed_entities(surface, area)
  local fn=rawget(_G,"tech_priests_efficiency_0579_entities_for_area")
  if type(fn)=="function" then local ok,ents=pcall(fn,surface,area); if ok and type(ents)=="table" then return ents end end
  local okM, Index=pcall(require,"scripts.core.efficiency_economy_0579")
  if okM and Index and type(Index.entities_for_area)=="function" then local ok,ents=pcall(Index.entities_for_area,surface,area); if ok and type(ents)=="table" then return ents end end
  return nil
end
local function note_area_scan(surface, area, ents)
  local fn=rawget(_G,"tech_priests_efficiency_0579_note_area_scan")
  if type(fn)=="function" then pcall(fn,surface,area,ents); return end
  local okM, Index=pcall(require,"scripts.core.efficiency_economy_0579")
  if okM and Index and type(Index.note_area_scan)=="function" then pcall(Index.note_area_scan,surface,area,ents) end
end
function M.find_entities(surface, filters, opts)
  opts=opts or {}; filters=filters or {}
  local r=M.root(); if r.enabled == false then return nil,"disabled" end
  if not (surface and surface.valid) then return nil,"invalid-surface" end
  local area=area_from_filters(filters)
  local category=opts.category or "generic"
  local neg_key=opts.negative_key
  if neg_key then local skip=select(1,M.should_skip_negative(category,neg_key)); if skip then return {},"negative-skip" end end
  metric("scans_attempted",1); metric("scan_routing_attempted",1); stat("attempted_"..tostring(category))
  local out, source = nil, nil
  if area then
    local cached=indexed_entities(surface, area)
    if cached then
      out={}
      local limit=tonumber(filters.limit or opts.limit) or nil
      for _,e in pairs(cached) do if matches(e,filters) then out[#out+1]=e; if limit and #out>=limit then break end end end
      source="indexed-0579"; stat("cache_hit_"..tostring(category)); metric("scan_routing_cache_hits",1)
    end
  end
  if not out then
    local ok, ents=pcall(function() return surface.find_entities_filtered(filters) end)
    if not ok or not ents then stat("direct_failed_"..tostring(category)); return nil,"direct-scan-failed" end
    out=ents; source="direct-scan"; stat("direct_scan_"..tostring(category)); metric("direct_surface_scans",1); metric("scan_routing_direct_scans",1)
    if area then note_area_scan(surface, area, ents) end
  else
    metric("scans_redirected_to_cache",1)
  end
  if neg_key and #out == 0 and opts.record_negative ~= false then M.record_negative(category, neg_key, opts.negative_ttl) end
  return out, source
end
function M.report_lines()
  local r=M.root(); local n=0; for _ in pairs(r.negative_until or {}) do n=n+1 end
  local s=r.stats or {}
  local attempted,hits,direct,neg = 0,0,0,0
  for k,v in pairs(s) do
    local nval = tonumber(v) or 0
    if tostring(k):find("attempted_", 1, true) == 1 then attempted = attempted + nval end
    if tostring(k):find("cache_hit_", 1, true) == 1 then hits = hits + nval end
    if tostring(k):find("direct_scan_", 1, true) == 1 then direct = direct + nval end
    if tostring(k):find("negative_skip_", 1, true) == 1 then neg = neg + nval end
  end
  return {"[tp-runtime-report] scan-routing-0610 enabled="..safe(r.enabled).." negative_entries="..safe(n).." attempted="..safe(attempted).." cache_hits="..safe(hits).." direct_scans="..safe(direct).." neg_skips="..safe(neg)}
end
function M.install()
  M.root(); _G.TechPriestsScanRouting0610=M; return true
end
return M
