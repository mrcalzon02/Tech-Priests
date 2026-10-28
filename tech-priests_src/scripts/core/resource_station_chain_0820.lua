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
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
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
    -- Only real paired links enter this persistent, primitive-ID return path.
    route_station_units={unit(pair)},
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
-- Physical upstream route proof for future counted ore delivery. This does
-- not mine or credit items; it validates actual paired station custody.
-- Older saves without route IDs are reconstructed only from unique segments.
function M.return_route(root_pair)
  local m=objective(root_pair)
  local tp=root()
  if not (m and tp and valid(root_pair)
      and unit(root_pair)==m.root_station_unit) then
    return nil,"return-route-root-unavailable"
  end
  if m.pending_expansion_id then
    return nil,"return-route-construction-pending"
  end
  if type(m.segments)~="number" or m.segments<0
      or m.segments>M.max_segments then
    return nil,"return-route-segment-count-invalid"
  end
  local forward=m.route_station_units
  local reconstructed=false
  if forward==nil then
    -- Compatibility with old saves: never guess among competing station
    -- pairs or infer physical ownership from a planned ghost position.
    local found={}
    for _,candidate in pairs(tp.pairs_by_station or {}) do
      local assignment=candidate and candidate.remote_resource_assignment_0820
      local segment=assignment and assignment.segment
      if valid(candidate) and assignment
          and assignment.root_station_unit==m.root_station_unit
          and type(segment)=="number" and segment>=1
          and segment<=m.segments and segment==math.floor(segment) then
        if found[segment] then
          return nil,"return-route-ambiguous-legacy-segment"
        end
        found[segment]=unit(candidate)
      end
    end
    forward={m.root_station_unit}
    for i=1,m.segments do
      if not found[i] then return nil,"return-route-legacy-segment-missing" end
      forward[#forward+1]=found[i]
    end
    reconstructed=true
  end
  if type(forward)~="table" or #forward~=m.segments+1
      or forward[1]~=m.root_station_unit
      or forward[#forward]~=m.current_station_unit then
    return nil,"return-route-identity-sequence-invalid"
  end
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not h then return nil,"return-route-hierarchy-unavailable" end
  local seen,upstream={},{}
  local previous=nil
  for i,id in ipairs(forward) do
    if type(id)~="number" or seen[id] then
      return nil,"return-route-duplicate-or-invalid-station"
    end
    seen[id]=true
    local current=pair_by_unit(id)
    if not valid(current) or current.station.force~=root_pair.station.force
        or current.station.surface~=root_pair.station.surface then
      return nil,"return-route-physical-station-missing-or-foreign"
    end
    if previous then
      local assignment=current.remote_resource_assignment_0820
      if not (assignment and assignment.root_station_unit==m.root_station_unit
          and assignment.segment==i-1
          and (assignment.parent_station_unit==nil
            or assignment.parent_station_unit==unit(previous))) then
        return nil,"return-route-assignment-parent-mismatch"
      end
      if rank(current)~=math.max(1,rank(previous)-1)
          or dist2(previous.station.position,current.station.position)
            >radius(previous)^2 then
        return nil,"return-route-rank-or-command-range-invalid"
      end
      local linked=false
      if rank(previous)>1 and type(h.is_direct_subordinate)=="function" then
        linked=h.is_direct_subordinate(previous,current)==true
      elseif rank(previous)==1 and type(h.peers)=="function" then
        for _,peer in ipairs(h.peers(previous) or {}) do
          if peer==current then linked=true; break end
        end
      end
      if not linked then return nil,"return-route-hierarchy-edge-missing" end
    end
    upstream[#upstream+1]=id
    previous=current
  end
  if reconstructed then m.route_station_units=forward end
  local reversed={}
  for i=#upstream,1,-1 do reversed[#reversed+1]=upstream[i] end
  return reversed,"verified-physical-upstream-route"
end

-- 0949: a starvation reversal has one original root writ but four real
-- descendants rebuilt from physically recovered station items. The ordinary
-- 0820 single-child advance must NOT issue a competing ghost while 0851-0948
-- are still carrying those original items. Reconcile only after every native
-- build, original-priest re-pair, empty depot and hierarchy edge is observable.
function M.reconcile_reversed_chain(root_pair,rec)
  local m=objective(root_pair)
  local tp=root()
  if not(m and tp and valid(root_pair) and rec
      and rec.reversal_plan_0850 and rec.id==m.pending_expansion_id
      and rec.worker_station_unit==unit(root_pair)
      and m.root_station_unit==unit(root_pair)
      and rec.status=="complete"
      and type(m.target)=="table" and type(m.need)=="string"
      and type(m.resource_name)=="string"
      and not m.return_courier_0837) then
    return false,"reversal-original-writ-or-mission-not-ready"
  end
  local stages={rec.reversal_stage_0855,rec.reversal_stage_0854,
    rec.reversal_stage_0853,rec.reversal_stage_0851}
  local next_step=rec.reversal_next_0911
  local junior_step=rec.reversal_junior_0919
  local peer_step=rec.reversal_second_junior_0943
  local records={rec,
    next_step and tp.station_expansion_0256
      and tp.station_expansion_0256[next_step.child_writ_id],
    junior_step and tp.station_expansion_0256
      and tp.station_expansion_0256[junior_step.child_writ_id],
    peer_step and tp.station_expansion_0256
      and tp.station_expansion_0256[peer_step.child_writ_id]}
  local names={"senior-cogitator-station",
    "intermediate-cogitator-station","junior-cogitator-station",
    "junior-cogitator-station"}
  local h=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not(h and type(h.rank)=="function"
      and type(h.is_direct_subordinate)=="function"
      and type(h.peers)=="function" and tp.pairs_by_priest
      and tp.pairs_by_station and tp.station_reversal_depot_0852) then
    return false,"reversal-hierarchy-or-custody-authority-unavailable"
  end
  local chain={root_pair}
  if h.rank(root_pair)~=4 then
    return false,"reversal-original-magos-rank-invalid"
  end
  local seen={[unit(root_pair)]=true}
  local inventories={}
  for i=1,4 do
    local stage,child=stages[i],records[i]
    local expected_rank=math.max(1,4-i)
    local paired=stage and tp.pairs_by_priest[stage.leaf_priest_unit]
    local depot=stage and tp.station_reversal_depot_0852[stage.id]
    local parent=chain[i]
    if not(stage and type(stage.leaf_station_unit)=="number"
        and type(stage.leaf_priest_unit)=="number"
        and child and child.status=="complete"
        and child.station_item==names[i]
        and child.worker_station_unit==unit(parent)
        and child.requester_station_unit==unit(parent)
        and paired and valid(paired)
        and paired.priest.unit_number==stage.leaf_priest_unit
        and paired.station.name==names[i]
        and not seen[unit(paired)]
        and unit(paired)~=stage.leaf_station_unit
        and tp.pairs_by_station[unit(paired)]==paired
        and tp.pairs_by_station[stage.leaf_station_unit]==nil
        and paired.station.force==root_pair.station.force
        and paired.station.surface==root_pair.station.surface
        and h.rank(paired)==expected_rank
        and child.ghost_position
        and dist2(paired.station.position,child.ghost_position)<=0.01
        and dist2(parent.station.position,paired.station.position)
          <=radius(parent)^2
        and depot and depot.status=="outbound"
        and depot.inventory and depot.inventory.valid
        and not inventories[depot.inventory]
        and not(tp.station_cargo_0824
          and tp.station_cargo_0824[child.id])
        and not(tp.station_relocation_0823
          and tp.station_relocation_0823[stage.leaf_station_unit])) then
      return false,"reversal-original-station-priest-or-item-not-verified:"..i
    end
    local ok,n=pcall(function()
      return depot.inventory.get_item_count(names[i])
    end)
    local empty,all=pcall(function()
      return depot.inventory.get_item_count()
    end)
    if not(ok and n==0 and empty and all==0) then
      return false,"reversal-original-depot-not-empty:"..i
    end
    inventories[depot.inventory]=true
    if i<=3 then
      if h.is_direct_subordinate(parent,paired)~=true then
        return false,"reversal-original-hierarchy-edge-missing:"..i
      end
    else
      local linked=false
      for _,peer in ipairs(h.peers(parent) or {}) do
        if peer==paired then linked=true;break end
      end
      if not linked then return false,"reversal-original-junior-peer-missing" end
    end
    seen[unit(paired)]=true
    chain[#chain+1]=paired
  end
  if tp.station_cargo_0824 and tp.station_cargo_0824[rec.id] then
    return false,"reversal-original-senior-cargo-not-retired"
  end
  local terminal=chain[5]
  if dist2(terminal.station.position,m.target)>radius(terminal)^2 then
    return false,"reversal-natural-ore-not-in-terminal-radius"
  end
  local scans=rawget(_G,"TechPriestsScanRouting0610")
  if not(scans and type(scans.find_entities)=="function") then
    return false,"reversal-natural-resource-scan-unavailable"
  end
  local ok,ores=pcall(scans.find_entities,terminal.station.surface,{
    name=m.resource_name,type="resource",
    area={{m.target.x-4,m.target.y-4},{m.target.x+4,m.target.y+4}},
    limit=8},{category="resource",limit=8,require_fresh=true})
  local natural=false
  if ok then
    for _,ore in ipairs(ores or {}) do
      if ore.valid and ore.type=="resource"
          and ore.name==m.resource_name and ore.surface==terminal.station.surface
          and tonumber(ore.amount) and ore.amount>0
          and dist2(ore.position,terminal.station.position)
            <=radius(terminal)^2 then natural=true;break end
    end
  end
  if not natural then return false,"reversal-natural-ore-not-observed" end
  local prior={}
  local route={unit(root_pair)}
  for i=2,5 do
    local p=chain[i]
    prior[i]=p.remote_resource_assignment_0820
    route[i]=unit(p)
    p.remote_resource_assignment_0820={
      root_station_unit=unit(root_pair),parent_station_unit=route[i-1],
      need=m.need,resource_name=m.resource_name,
      target={x=m.target.x,y=m.target.y},segment=i-1,
      assigned_tick=tick()}
  end
  local old={status=m.status,segments=m.segments,
    route_station_units=m.route_station_units,
    current_station_unit=m.current_station_unit,current_rank=m.current_rank,
    pending_expansion_id=m.pending_expansion_id}
  m.segments=4
  m.route_station_units=route
  m.current_station_unit=route[5]
  m.current_rank=1
  m.pending_expansion_id=nil
  local verified,reason=M.return_route(root_pair)
  if not(verified and #verified==5 and verified[1]==route[5]
      and verified[5]==route[1]) then
    for i=2,5 do chain[i].remote_resource_assignment_0820=prior[i] end
    for k,v in pairs(old) do m[k]=v end
    -- nil fields must be restored too; pairs() intentionally skips nil.
    m.pending_expansion_id=old.pending_expansion_id
    return false,"reversal-counted-return-route-not-verified:"..tostring(reason)
  end
  m.status="reached-resource"
  m.return_route_hops=4
  m.return_route_verified_tick=tick()
  m.completed_tick=tick()
  m.updated_tick=tick()
  m.last_reason="original-five-station-reversal-physical-route-reconciled"
  return true,"reversal-original-five-station-route-and-natural-ore-verified"
end

function M.service_pair(pair)
  local m=objective(pair)
  if not m or m.status=="reached-resource"
      or m.status=="cancelled" then
    return false,"no-active-chain"
  end
  if not (valid(pair) and unit(pair)==m.root_station_unit and root()) then
    return false,"not-chain-root"
  end
  if tick()<(m.next_tick or 0) then return false,"interval" end
  m.next_tick=tick()+M.service_interval
  -- A reversal's original writ is not a single new child. The ordinary
  -- chain owner can have marked its mission blocked while four physical
  -- stations were still being recovered. A valid original reversal writ must
  -- still be eligible for the STRICT readback of all four native builds,
  -- inventories, original priests, hierarchy edges and natural ore. This
  -- never clears a block merely because a ghost or plan exists.
  if m.pending_expansion_id then
    local tp=root()
    local rec=tp and tp.station_expansion_0256
      and tp.station_expansion_0256[m.pending_expansion_id]
    if rec and rec.reversal_plan_0850 then
      return M.reconcile_reversed_chain(pair,rec)
    end
  end
  -- Non-reversal blocked missions retain their original fail-closed state.
  if m.status=="blocked" then return false,"no-active-chain" end
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
    local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
    if hierarchy then
      local linked=false
      if rank(commander)>1 and
          type(hierarchy.is_direct_subordinate)=="function" then
        linked=hierarchy.is_direct_subordinate(commander,child)==true
      elseif rank(commander)==1
          and type(hierarchy.peers)=="function" then
        for _,peer in ipairs(hierarchy.peers(commander) or {}) do
          if peer==child then linked=true;break end
        end
      end
      if not linked then
        m.status="awaiting-command-hierarchy"
        m.last_reason="physical-child-not-yet-under-parent-command"
        m.updated_tick=tick()
        return false,"awaiting-hierarchy"
      end
    end
    local prior=dist2(commander.station.position,m.target)
    local after=dist2(child.station.position,m.target)
    if after>=(math.sqrt(prior)-M.min_progress)^2 then
      return chain_fail(m,"built-station-did-not-approach-resource")
    end
    if m.route_station_units~=nil then
      if type(m.route_station_units)~="table"
          or #m.route_station_units~=m.segments+1
          or m.route_station_units[#m.route_station_units]~=unit(commander) then
        return chain_fail(m,"persisted-return-route-out-of-sync")
      end
      m.route_station_units[#m.route_station_units+1]=unit(child)
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
      root_station_unit=m.root_station_unit,
      parent_station_unit=unit(commander),need=m.need,
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
    local return_route,route_reason=M.return_route(pair)
    if not return_route then
      m.status="awaiting-return-route"
      m.last_reason=route_reason
      m.updated_tick=tick()
      return false,"return-route-unverified"
    end
    m.return_route_hops=#return_route-1
    m.return_route_verified_tick=tick()
    m.status="reached-resource"
    m.last_reason="real-patch-within-child-operating-radius"
    m.completed_tick=tick()
    m.updated_tick=tick()
    return true,"resource-in-range"
  end
  if m.segments>=M.max_segments then
    return chain_fail(m,"max-physical-station-segments")
  end
  -- Do not plant a child station that the authoritative command topology
  -- cannot own. A full parent must free/relocate a slot first; ghost spam is
  -- never a substitute for a valid superior-child or Junior-peer link.
  local hierarchy=rawget(_G,"TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if hierarchy then
    local parent_rank=rank(commander)
    local free=true
    if parent_rank>1 and
        type(hierarchy.direct_capacity_remaining)=="function" then
      free=hierarchy.direct_capacity_remaining(commander)>0
    elseif parent_rank==1 and type(hierarchy.peers)=="function"
        and type(hierarchy.peer_limit_for)=="function" then
      free=#(hierarchy.peers(commander) or {})
          <hierarchy.peer_limit_for(commander)
    end
    if not free then
      m.status="awaiting-command-capacity"
      m.last_reason="hierarchy-subordinate-or-peer-capacity-full"
      m.updated_tick=tick()
      return false,"command-capacity-full"
    end
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
-- One engine-authoritative range calculation for route verification and
-- ore courier eligibility. Do not let a cached pair.radius drift from the
-- live station operating radius when a chain reaches its last ore patch.
M.operating_radius=radius
function M.status(pair)
  return objective(pair)
end
_G.TechPriestsResourceStationChain0820=M
return M
