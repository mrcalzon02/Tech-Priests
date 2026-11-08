-- Autonomous rail frontier: physically construct one connected segment at a
-- time using the EXISTING 0338 construction executor and its exact item ledger.
-- Never build remotely, spawn stock, bypass the dispatcher or use an uncharted
-- railway destination. Terrain-routing and a runnable railway remain later gates.
local M={version="0.1.676.0836",start_offset=12,segment_step=2,
  destination_clearance=16,max_segments=320,max_lateral_error=6,
  pending_admission_timeout_ticks=60*120}
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
-- Single physical geometry contract shared with the 0835 natural-ore
-- observer. Rail credit uses Euclidean last-RAIL clearance, not the X
-- coordinate of a hypothetical next segment.
function M.required_segments_for_target(start,target)
  if not(start and target and type(start.x)=="number"
      and type(start.y)=="number" and type(target.x)=="number"
      and type(target.y)=="number")then return nil end
  local forward=target.x-start.x
  local lateral=math.abs(target.y-start.y)
  if forward<=M.start_offset or lateral>M.max_lateral_error
      or lateral>M.destination_clearance then return nil end
  local x_clearance=math.sqrt(M.destination_clearance^2-lateral^2)
  return math.max(1,math.ceil(
    (forward-M.start_offset-x_clearance)/M.segment_step)+1)
end
function M.last_rail_reaches_target(rail,target)
  if not(rail and target and type(rail.x)=="number"
      and type(rail.y)=="number" and type(target.x)=="number"
      and type(target.y)=="number")then return false end
  local dx=target.x-rail.x
  local dy=target.y-rail.y
  return dx>=0 and dx*dx+dy*dy<=M.destination_clearance^2
end
-- A completed 0338 debit and correct coordinates do not prove a traversable
-- railway. Verify Factorio's own straight-through rail edge.
local function connected_straight_rails(from,to)
  local rd=defines and defines.rail_direction
  local cd=defines and defines.rail_connection_direction
  if not (valid(from) and valid(to) and rd and cd
      and cd.straight~=nil
      and type(from.get_connected_rail)=="function") then return false end
  for _,direction in ipairs({rd.front,rd.back}) do
    local ok,neighbor=pcall(from.get_connected_rail,{
      rail_direction=direction,rail_connection_direction=cd.straight})
    if ok and neighbor==to then return true end
  end
  return false
end
local function reject(objective,reason)
  objective.status="rail-track-blocked"
  objective.stage="blocked"
  objective.last_blocker=reason
  objective.last_update_tick=now()
  return false,reason
end
-- On completion, prove the ENTIRE originally item-debited chain still exists
-- and is traversable. The previous 0338 receipts only proved neighboring rails
-- at the moment each segment was built; an earlier rail may since be destroyed.
-- Sweep a bounded number of native graph edges per existing broker pulse.
-- Persist only primitive progress: never store entity references in the audit.
local function audit_original_chain(pair,route,direction)
  local n=tonumber(route.segment)
  if not(n and n>=2 and n==math.floor(n) and n<=M.max_segments
      and type(route.built_units)=="table"
      and type(route.start_position)=="table"
      and type(route.last_position)=="table"
      and route.direction==direction
      and close(route.last_position,pos(
        route.start_position.x+(n-1)*M.segment_step,
        route.start_position.y)))then
    return false,"rail-chain-ledger-incomplete"
  end
  local first=tonumber(route.chain_audit_index_0836) or 1
  if first<1 or first>n or first~=math.floor(first)then
    return false,"rail-chain-audit-cursor-invalid"
  end
  local last=math.min(n,first+8)
  local previous=nil
  for i=first,last do
    local point=pos(route.start_position.x+(i-1)*M.segment_step,
      route.start_position.y)
    local rail=track_at(pair,point,direction)
    if not rail then
      return false,"rail-chain-segment-missing:"..i
    end
    if not(rail.unit_number and rail.unit_number==route.built_units[i])then
      return false,"rail-chain-identity-changed:"..i
    end
    if previous and not connected_straight_rails(previous,rail)then
      return false,"rail-chain-disconnected:"..i
    end
    previous=rail
  end
  if last==n then
    route.chain_audit_index_0836=nil
    route.chain_audit_completed_tick_0836=now()
    return true,"native-original-rail-chain-connected"
  end
  -- Revisit this last, real rail as the predecessor of the next slice.
  route.chain_audit_index_0836=last
  return nil,"rail-chain-audit-in-progress"
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
  if math.abs(target.y-start.y)>M.max_lateral_error
      or target.x<=start.x+M.start_offset
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
  local next_pos=route.last_position
    and pos(route.last_position.x+M.segment_step,route.last_position.y)
    or pos(route.start_position.x,route.start_position.y)
  -- Reconfirm the original item-debited rail even when the next step
  -- would finish the frontier. A persisted count cannot certify a
  -- missing or same-position substituted physical segment.
  if route.last_position then
    local predecessor=track_at(pair,route.last_position,direction)
    if not predecessor then
      return reject(m,"previous-physical-rail-missing")
    end
    if not (route.built_units
        and predecessor.unit_number==route.built_units[route.segment]) then
      return reject(m,"previous-physical-rail-identity-changed")
    end
    if next_pos.x-route.last_position.x~=M.segment_step then
      return reject(m,"disconnected-rail-step")
    end
  end
  -- Completion requires the LAST ACTUALLY BUILT rail to lie within
  -- the true 2D destination clearance. At capacity the last rail is
  -- (650,0): (666,0) is reachable, but (665,6) is NOT. A hypothetical
  -- next candidate is never credited as a real item-debited rail.
  if route.segment>0 and route.last_position
      and M.last_rail_reaches_target(route.last_position,target) then
    local accepted,why=audit_original_chain(pair,route,direction)
    if accepted==nil then
      m.stage="verifying-original-native-rail-chain"
      m.next_step="audit-connected-item-debited-rail"
      m.last_update_tick=now()
      return true,why
    end
    if not accepted then return reject(m,why) end
    m.status="rail-track-established"
    m.stage="connected-original-physical-rail-frontier"
    m.next_step="validate-train-route-connectivity"
    m.last_update_tick=now()
    return false,"physical-frontier-reached"
  end
  if route.segment==0
      and next_pos.x>=target.x-M.destination_clearance then
    return reject(m,"no-physical-rail-placed")
  end
  if route.segment>=M.max_segments then
    return reject(m,"maximum-verified-rail-segments")
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
    -- A pending candidate is not permanent physical custody. 0338 may
    -- refuse admission (no source, invalid reservation or stale candidate)
    -- without producing a terminal task. Do not leave the first rail
    -- pending forever: retain the original request and all counted items,
    -- and fail closed after bounded waiting. Active 0338 task/cargo is
    -- handled above and retains its own travel/refund deadlines.
    if pair.construction_request~=pending.request then
      return reject(m,"pending-original-rail-request-lost")
    end
    local started=tonumber(pending.started_tick)
    if not started or started<0 or started>now() then
      return reject(m,"pending-rail-start-tick-invalid")
    end
    if now()-started>M.pending_admission_timeout_ticks then
      return reject(m,"pending-physical-rail-admission-timeout")
    end
    return false,"waiting-for-construction-proof"
  end
  local actual=track_at(pair,pending.position,pending.direction)
  if not (actual and actual==previous.built_entity)then
    return reject(m,"physical-rail-not-at-committed-site")
  end
  local route=m.rail_frontier_0836
  -- An interrupted or migrated save may retain a paid 0338 receipt but
  -- lose/corrupt the 0836 primitive ledger. Fail closed before indexing or
  -- appending it: never reconstruct counted rail identities from geometry.
  if not (type(route)=="table" and type(route.segment)=="number"
      and route.segment>=0 and route.segment<M.max_segments
      and route.segment==math.floor(route.segment)
      and type(pending.segment)=="number"
      and pending.segment==route.segment+1)then
    return reject(m,"out-of-order-physical-rail")
  end
  if type(route.built_units)~="table"
      or #route.built_units~=route.segment
      or (route.segment>0 and type(route.last_position)~="table") then
    return reject(m,"rail-chain-ledger-incomplete")
  end
  if pending.segment>1 then
    local predecessor=route.last_position
      and track_at(pair,route.last_position,pending.direction)
    if not (valid(predecessor) and route.built_units
        and predecessor.unit_number==route.built_units[route.segment]) then
      -- Keep the real builder debit; refuse identity substitution.
      return reject(m,"previous-physical-rail-identity-changed")
    end
    if not connected_straight_rails(predecessor,actual)then
      -- Keep the physical item debit and built entity, but do not advance
      -- an untraversable frontier or claim a completed train route.
      return reject(m,"physical-rail-segments-disconnected")
    end
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
  -- The strategic ore observer runs in the broker as well as 0510. Neither
  -- path may issue a NEW rail construction writ while the original Magos
  -- is completing an incumbent duty or carrying someone else's real goods.
  -- A 0338 task/cargo already admitted for this EXACT original pending rail
  -- retains its own movement, debit, timeout and refund authority.
  local pending=m.pending_rail_0836
  local task=pair.construction_task_0338
  local custody=pair.construction_custody_0338
  local original_builder=pending and (
    (task and task.request_value==pending.request)
    or (custody and custody.request_value==pending.request))
  local incumbent=pair.active_task or pair.current_task
    or pair.active_order_0469
    or (pair.order_queue_0469 and pair.order_queue_0469.current)
    or pair.active_acquisition_0333 or pair.direct_acquisition_task_0336
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.construction_task_0340
  if incumbent and not original_builder then
    -- An original 0338 rail may finish before this broker pulse while a
    -- separate incumbent duty is already active. Reconcile its completed
    -- physical receipt without admitting or planning the NEXT rail: otherwise
    -- an actually built/paid segment can stay uncredited indefinitely.
    -- The exact existing request, entity, unit and native predecessor proof
    -- remain mandatory inside verify_pending; no competing item is debited.
    local previous=pair.construction_last_task_0338
    if pending and not task and not custody
        and previous and previous.request_value==pending.request
        and previous.phase=="complete" then
      local credited,why=M.verify_pending(pair)
      if credited then
        return true,"physical-rail-receipt-reconciled-while-occupied"
      end
      return false,why
    end
    return false,"original-magos-incumbent-duty"
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
