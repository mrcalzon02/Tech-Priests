-- Autonomous rail frontier: physically construct one connected segment at a
-- time using the EXISTING 0338 construction executor and its exact item ledger.
-- Never build remotely, spawn stock, bypass the dispatcher or use an uncharted
-- railway destination. Terrain-routing and a runnable railway remain later gates.
local M={version="0.1.676.0836",start_offset=12,segment_step=2,
  destination_clearance=16,max_segments=320}
local function valid(e)return e and e.valid==true end
local function now()return game and game.tick or 0 end
local function pos(x,y)return{x=x,y=y}end
local function close(a,b)
  return a and b and math.abs(a.x-b.x)<0.25
    and math.abs(a.y-b.y)<0.25
end
local function eligible(pair,objective)
  return valid(pair and pair.station) and valid(pair.priest)
    and pair.station.name=="planetary-magos-cogitator-station"
    and type(objective)=="table"
    and objective.root_station_unit==pair.station.unit_number
    and objective.surface_index==pair.station.surface.index
    and objective.force_index==pair.station.force.index
    and type(objective.target)=="table"
    and tonumber(objective.target.x) and tonumber(objective.target.y)
end
local function track_at(pair,point,direction)
  -- An item request, ghost or ledger entry is not proof of physical track.
  local scan=rawget(_G,"TechPriestsScanRouting0610")
  if not(scan and type(scan.find_entities)=="function")then return nil end
  local ok,entities=pcall(scan.find_entities,pair.station.surface,{
    name="straight-rail",position=point,radius=0.25,
    force=pair.station.force,limit=4},
    {category="construction",limit=4,record_negative=false})
  if not ok or type(entities)~="table"then return nil end
  for _,e in ipairs(entities)do
    if valid(e) and close(e.position,point)
        and e.direction==direction and e.force==pair.station.force then
      return e
    end
  end
end
M.track_at=track_at
local function reject(objective,reason)
  objective.status="rail-track-blocked"
  objective.stage="blocked"
  objective.last_blocker=reason
  objective.last_update_tick=now()
  return false,reason
end
function M.plan_next(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,m)then return false,"not-authorized-rail-mission"end
  if m.status=="rail-track-blocked"then return false,m.last_blocker or"blocked"end
  if m.status=="rail-track-established" or m.status=="completed"then
    return false,"rail-frontier-ended"
  end
  if m.status~="starvation-confirmed"
      and m.status~="building-physical-rail"then
    return false,"not-in-track-phase"
  end
  if m.pending_rail_0836 then return true,"pending-physical-builder"end
  if pair.construction_task_0338 or pair.construction_custody_0338
      or pair.construction_candidate_0338 or pair.construction_request then
    return false,"other-physical-construction-active"
  end
  local start=pair.station.position
  local target=m.target
  if math.abs(target.y-start.y)>6 or target.x<=start.x+M.start_offset
      or math.abs(start.x-math.floor(start.x/2)*2)>0.01 then
    -- The first corridor is deliberately straight and eastbound.
    -- Do not silently place disconnected or diagonal track while claiming
    -- a train route. A terrain-aware planner is a separate development stage.
    return reject(m,"terrain-route-planner-required")
  end
  local rail_prototype=prototypes and prototypes.entity
      and prototypes.entity["straight-rail"]
  if not (rail_prototype and prototypes.item
      and prototypes.item["rail"] and defines and defines.direction)then
    return reject(m,"rail-prototypes-or-direction-unavailable")
  end
  local direction=defines.direction.east
  if type(direction)~="number"then
    return reject(m,"cardinal-rail-direction-unavailable")
  end
  m.rail_frontier_0836=m.rail_frontier_0836 or{
    segment=0,last_position=nil,direction=direction,
    start_position=pos(start.x+M.start_offset,start.y),
    initial_stock_tick=now(),built_units={},started_tick=now(),
  }
  local route=m.rail_frontier_0836
  if route.segment>=M.max_segments then
    return reject(m,"maximum-verified-rail-segments")
  end
  local next_pos=route.last_position
    and pos(route.last_position.x+M.segment_step,route.last_position.y)
    or pos(route.start_position.x,route.start_position.y)
  if next_pos.x>=target.x-M.destination_clearance then
    if route.segment>0 then
      m.status="rail-track-established"
      m.stage="physical-rail-frontier-reached"
      m.next_step="validate-train-route-connectivity"
      m.last_update_tick=now()
      return false,"physical-frontier-reached"
    end
    return reject(m,"no-physical-rail-placed")
  end
  if route.last_position then
    if not track_at(pair,route.last_position,direction)then
      return reject(m,"previous-physical-rail-missing")
    end
    if next_pos.x-route.last_position.x~=M.segment_step then
      return reject(m,"disconnected-rail-step")
    end
  end
  -- Do not claim an existing foreign rail as ours; all segments must be
  -- built by our counted physical construction task.
  if track_at(pair,next_pos,direction)then
    return reject(m,"rail-site-occupied-without-custody-proof")
  end
  local can,allowed=pcall(function()
    return pair.station.surface.can_place_entity{
      name="straight-rail",position=next_pos,
      direction=direction,force=pair.station.force}
  end)
  if not (can and allowed==true)then
    return reject(m,"rail-site-not-engine-placeable")
  end
  local request={item_name="rail",entity_name="straight-rail",
    category="rail",position=next_pos,direction=direction,
    site_reason="remote-rail-physical-frontier-0836",
    rail_mission_station_unit_0836=m.root_station_unit,
    rail_segment_0836=route.segment+1}
  pair.construction_request=request
  m.pending_rail_0836={
    position=next_pos,direction=direction,
    request=request,segment=route.segment+1,
    started_tick=now()}
  m.status="building-physical-rail"
  m.stage="awaiting-existing-construction-executor"
  m.next_step="build-physical-rail-segment"
  m.last_update_tick=now()
  return true,"rail-segment-requested"
end
function M.verify_pending(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,m)then return false,"not-authorized-rail-mission"end
  local pending=m.pending_rail_0836
  if not pending then return false,"no-pending-rail"end
  if pair.construction_task_0338 or pair.construction_custody_0338 then
    return false,"physical-builder-in-progress"
  end
  local previous=pair.construction_last_task_0338
  if not(previous and previous.request_value==pending.request
      and previous.phase=="complete" and valid(previous.built_entity)
      and previous.built_entity.name=="straight-rail"
      and close(previous.built_entity.position,pending.position)
      and previous.built_entity.direction==pending.direction
      and pair.construction_request==nil)then
    -- A builder that failed or dropped its request has not laid track.
    if previous and previous.request_value==pending.request
        and previous.phase=="aborted"then
      return reject(m,"physical-rail-builder-aborted:"..
        tostring(previous.result))
    end
    return false,"waiting-for-construction-proof"
  end
  local actual=track_at(pair,pending.position,pending.direction)
  if not (actual and actual==previous.built_entity)then
    return reject(m,"physical-rail-not-at-committed-site")
  end
  local route=m.rail_frontier_0836
  if not (route and pending.segment==route.segment+1)then
    return reject(m,"out-of-order-physical-rail")
  end
  route.segment=pending.segment
  route.last_position=pos(pending.position.x,pending.position.y)
  route.last_built_unit=actual.unit_number
  route.built_units[#route.built_units+1]=actual.unit_number
  m.pending_rail_0836=nil
  m.last_update_tick=now()
  m.stage="real-track-segment-verified"
  m.next_step="plan-next-physical-rail"
  -- The 0338 construction executor debited the actual rail BEFORE
  -- producing the engine rail; no duplicate inventory mutation here.
  return true,"physical-rail-segment-verified"
end
function M.service_pair(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not m then return false,"no-rail-mission"end
  if not eligible(pair,m)then return false,"not-authorized-rail-mission"end
  if m.status=="rail-track-blocked" or m.status=="rail-track-established"then
    return false,m.status
  end
  if m.pending_rail_0836 then
    local done,why=M.verify_pending(pair)
    if m.status=="rail-track-blocked" then return false,why end
    if not done then return true,why end
  end
  return M.plan_next(pair)
end
_G.TechPriestsRailTrackFrontier0836=M
return M
