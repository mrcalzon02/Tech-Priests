-- Remote resource acquisition: ranked, physical Cogitator relay chain.
-- Planning/verification only: existing station-expansion executor owns ghosts,
-- inventory removal, movement and real construction. No scripted spawning,
-- deconstruction, invented inventory or autonomous ownership transfer.
local M={
  version="0.1.674-dev.0820",
  -- Existing known-resource search extends to 2048 tiles; bound the
  -- worst-case short-range Junior relay without an infinite station flood.
  max_segments=96,
  service_interval=60*5,
  pair_wait_interval=60*5,
  min_progress=4,
}
local function tick() return game and game.tick or 0 end
local function valid(pair)
  return pair and pair.station and pair.station.valid
    and pair.priest and pair.priest.valid
end
local function unit(pair)
  return valid(pair) and pair.station.unit_number or nil
end
local function dist2(a,b)
  local x=a.x-b.x
  local y=a.y-b.y
  return x*x+y*y
end
local function root()
  return storage and storage.tech_priests or nil
end
local function pair_by_unit(id)
  local t=root()
  local m=t and t.pairs_by_station or {}
  return m[id] or m[tostring(id)]
end
local function rank(pair)
  local h=rawget(_G,"TechPriestsCommandHierarchy0480")
  if h and type(h.rank)=="function" then return h.rank(pair) end
  if type(_G.tech_priests_0252_rank_number)=="function" then
    return _G.tech_priests_0252_rank_number(pair)
  end
  return 0
end
local function radius(pair)
  local get=rawget(_G,"refresh_pair_radius")
  local r=tonumber(pair.radius or pair.base_radius) or 20
  if type(get)=="function" then
    local ok,result=pcall(get,pair)
    if ok and tonumber(result) then r=tonumber(result) end
  end
  return math.max(8,r)
end
local function objective(pair)
  return pair and pair.resource_expansion_0259
    and pair.resource_expansion_0259.chain_0820 or nil
end
function M.start(pair,item,resource_position,resource_name)
  if not (valid(pair) and rank(pair)>=4
      and type(item)=="string" and #item>0
      and resource_position and tonumber(resource_position.x)
      and tonumber(resource_position.y) and root()) then
    return false,"invalid-root-or-patch"
  end
  local state=pair.resource_expansion_0259 or {}
  pair.resource_expansion_0259=state
  local old=state.chain_0820
  if old and old.status~="reached-resource" and old.status~="cancelled" then
    return false,"chain-already-active"
  end
  local pos={x=tonumber(resource_position.x),y=tonumber(resource_position.y)}
  if dist2(pair.station.position,pos)<=radius(pair)^2 then
    return false,"resource-within-root-radius"
  end
  state.chain_0820={
    status="planning",need=item,resource_name=resource_name,
    target=pos,root_station_unit=unit(pair),
    current_station_unit=unit(pair),current_rank=rank(pair),
    segments=0,pending_expansion_id=nil,
    created_tick=tick(),updated_tick=tick(),next_tick=tick(),
    last_reason="target-identified",
  }
  return true,"mission-created"
end
local function chain_fail(mission,reason)
  mission.status="blocked"
  mission.last_reason=reason
  mission.updated_tick=tick()
  return false,reason
end
local function child_at_ghost(parent,rec,expected)
  local t=root()
  if not (rec and rec.ghost_position and t and t.pairs_by_station) then return nil end
  local best=nil
  for _,candidate in pairs(t.pairs_by_station) do
    if valid(candidate) and candidate~=parent
        and candidate.station.force==parent.station.force
        and candidate.station.surface==parent.station.surface
        and rank(candidate)==expected
        and dist2(candidate.station.position,rec.ghost_position)<=2.25 then
      best=candidate
      break
    end
  end
  return best
end
function M.service_pair(pair)
  local m=objective(pair)
  if not m or m.status=="reached-resource"
      or m.status=="blocked" or m.status=="cancelled" then
    return false,"no-active-chain"
  end
  if not (valid(pair) and unit(pair)==m.root_station_unit and root()) then
    return false,"not-chain-root"
  end
  if tick()<(m.next_tick or 0) then return false,"interval" end
  m.next_tick=tick()+M.service_interval
  local commander=pair_by_unit(m.current_station_unit)
  if not valid(commander) then return chain_fail(m,"current-station-or-priest-missing") end
  if commander.station.force~=pair.station.force
      or commander.station.surface~=pair.station.surface then
    return chain_fail(m,"current-station-left-origin-domain")
  end
  if m.pending_expansion_id then
    local t=root()
    local rec=t.station_expansion_0256 and
      t.station_expansion_0256[m.pending_expansion_id]
    if not rec then return chain_fail(m,"expansion-record-lost") end
    if rec.status=="failed" then
      return chain_fail(m,"station-construction-failed:"..tostring(rec.note))
    end
    if rec.status~="complete" then
      m.status="building-station"
      m.last_reason=tostring(rec.phase or "awaiting-physical-construction")
      m.updated_tick=tick()
      return false,"waiting-physical-station"
    end
    local expected=math.max(1,rank(commander)-1)
    local child=child_at_ghost(commander,rec,expected)
    if not child then
      m.status="awaiting-new-station-pair"
      m.last_reason="station-built-awaiting-registered-priest"
      m.updated_tick=tick()
      return false,"awaiting-child-pair"
    end
    local prior=dist2(commander.station.position,m.target)
    local after=dist2(child.station.position,m.target)
    if after>=(math.sqrt(prior)-M.min_progress)^2 then
      return chain_fail(m,"built-station-did-not-approach-resource")
    end
    m.current_station_unit=unit(child)
    m.current_rank=rank(child)
    m.pending_expansion_id=nil
    m.segments=m.segments+1
    m.status="planning"
    m.last_reason="next-ranked-station-paired"
    m.updated_tick=tick()
    -- The child has a real station/priest and may now plan its own machines.
    child.remote_resource_assignment_0820={
      root_station_unit=m.root_station_unit,need=m.need,
      resource_name=m.resource_name,
      target={x=m.target.x,y=m.target.y},
      segment=m.segments,assigned_tick=tick(),
    }
    commander=child
  end
  if dist2(commander.station.position,m.target)<=radius(commander)^2 then
    -- A ghost reaching the stored coordinates is not resource acquisition.
    -- Verify an actual mineable resource still exists in the final child's
    -- operating area; depleted/disappeared ore must trigger a new search.
    local surface=commander.station.surface
    local scans=rawget(_G,"TechPriestsScanRouting0610")
    if not (scans and type(scans.find_entities)=="function") then
      m.status="awaiting-resource-confirmation"
      m.last_reason="canonical-resource-scan-unavailable"
      return false,"resource-coverage-unconfirmed"
    end
    local ok,entities=pcall(scans.find_entities,surface,{
      name=m.resource_name,type="resource",
      area={{m.target.x-4,m.target.y-4},
        {m.target.x+4,m.target.y+4}},limit=1},
      {category="resource",limit=1})
    if not ok or not (entities and entities[1] and entities[1].valid) then
      return chain_fail(m,"physical-resource-depleted-or-missing")
    end
    m.status="reached-resource"
    m.last_reason="real-patch-within-child-operating-radius"
    m.completed_tick=tick()
    m.updated_tick=tick()
    return true,"resource-in-range"
  end
  if m.segments>=M.max_segments then
    return chain_fail(m,"max-physical-station-segments")
  end
  local Expansion=rawget(_G,"TECH_PRIESTS_STATION_EXPANSION_0256")
  if not (Expansion and type(Expansion.request_station_expansion)=="function") then
    return false,"physical-expansion-executor-unavailable"
  end
  local delta_x=m.target.x-commander.station.position.x
  local delta_y=m.target.y-commander.station.position.y
  local angle=math.atan2(delta_y,delta_x)
  local name="resource:"..m.need
  local ok=Expansion.request_station_expansion(
    commander,name,nil,"ranked-remote-resource-chain",angle)
  if not ok then
    m.status="awaiting-site-or-item"
    m.last_reason="resource-station-ghost-not-available"
    m.updated_tick=tick()
    return false,"expansion-waiting"
  end
  -- Requesting a ghost must result in a REAL owner-keyed active record.
  -- An existing deduplicated request is legitimate; an unrelated ghost is not.
  local selected
  local t=root()
  for id,rec in pairs(t.station_expansion_0256 or {}) do
    if rec.status=="active" and rec.requester_station_unit==unit(commander)
        and rec.blocked_item==name then
      if not selected or id<selected.id then selected=rec end
    end
  end
  if not selected then return chain_fail(m,"requested-ghost-has-no-physical-record") end
  if selected.ghost_position and
      dist2(selected.ghost_position,m.target)
      >=dist2(commander.station.position,m.target) then
    return chain_fail(m,"station-ghost-points-away-from-resource")
  end
  m.pending_expansion_id=selected.id
  m.status="building-station"
  m.last_reason="physical-child-station-requested"
  m.updated_tick=tick()
  return true,"station-ghost-assigned"
end
function M.status(pair)
  return objective(pair)
end
_G.TechPriestsResourceStationChain0820=M
return M
