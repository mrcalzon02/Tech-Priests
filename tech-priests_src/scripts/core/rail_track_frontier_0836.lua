-- Autonomous rail frontier: physically construct one connected segment at a
-- time using the EXISTING 0338 construction executor and its exact item ledger.
-- Never build remotely, spawn stock, bypass the dispatcher or use an uncharted
-- railway destination. Terrain-routing and a runnable railway remain later gates.
local RouteChoice1403=require("scripts.core.rail_route_choice_1403")
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
  -- The indexed construction scan can lag a freshly built original rail.
  -- Admit only a REAL native entity in this exact bounded tile, never a
  -- planned route, ghost, cached positive, or arbitrary nearby rail.
  local surface=pair and pair.station and pair.station.surface
  if not(valid(surface) and type(point)=="table")then return nil end
  local function exact_native_rail(entities)
    if type(entities)~="table"then return nil end
    for _,e in ipairs(entities)do
      if valid(e) and e.name=="straight-rail"
          and close(e.position,point) and e.direction==direction
          and e.force==pair.station.force and e.surface==surface then
        return e
      end
    end
  end
  local scan=rawget(_G,"TechPriestsScanRouting0610")
  if scan and type(scan.find_entities)=="function" then
    local ok,entities=pcall(scan.find_entities,surface,{
      name="straight-rail",position=point,radius=0.25,
      force=pair.station.force,limit=4},
      {category="construction",limit=4,record_negative=false,
        require_fresh=true})
    if ok then
      local indexed=exact_native_rail(entities)
      if indexed then return indexed end
    end
  end
  -- Factorio itself is the ultimate physical authority. A tiny native
  -- lookup closes the index-refresh race without weakening any ledger,
  -- original 0338 item debit, entity identity, or connected-graph gate.
  local ok,native=pcall(function()
    return surface.find_entities_filtered{
      name="straight-rail",position=point,radius=0.25,
      force=pair.station.force,limit=4}
  end)
  if ok then return exact_native_rail(native) end
end
M.track_at=track_at
-- Factorio 2.1.24 normalized the original 0338 placement request
-- (12,-206) to an actual eastbound straight-rail center at (13,-205).
-- Request the 2x2 native rail center from the outset. Never relabel a
-- differently snapped physical entity as matching the original 0836 writ.
-- Preserve the even-X station corridor and the original two-tile cadence.
local function native_first_rail_center(start)
  return pos(start.x+M.start_offset+1,math.floor(start.y/2)*2+1)
end
-- Single physical geometry contract shared with the 0835 natural-ore
-- observer. Range counts must use the very same native rail centers
-- that 0338 receives, not a hypothetical unsnapped builder coordinate.
function M.required_segments_for_target(start,target)
  if not(start and target and type(start.x)=="number"
      and type(start.y)=="number" and type(target.x)=="number"
      and type(target.y)=="number")then return nil end
  local first=native_first_rail_center(start)
  local forward=target.x-first.x
  local lateral=math.abs(target.y-first.y)
  if forward<=0 or math.abs(target.y-start.y)>M.max_lateral_error
      or lateral>M.destination_clearance then return nil end
  local x_clearance=math.sqrt(M.destination_clearance^2-lateral^2)
  return math.max(1,math.ceil(
    (forward-x_clearance)/M.segment_step)+1)
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
-- Fueling the ORIGINAL paid locomotive requires a real physical walk along
-- already-item-debited 0836 rail. 0528 remains the sole station-debit, cargo,
-- movement-request and machine-insertion owner; this is read-only corridor
-- evidence for canonical 0418/0566, never bounds_exempt or item creation.
-- The narrow exception expires with its exact live COAL custody transaction.
function M.authorized_original_train_fuel_walk_0836(pair,point,movement)
  if not(eligible(pair,pair and pair.remote_rail_outpost_0835)
      and type(point)=="table" and type(point.x)=="number"
      and type(point.y)=="number" and type(movement)=="table"
      and movement.owner=="logistics_machine_fulfillment_0528"
      and movement.reason=="machine-logistics-move-to-machine-0528"
      and storage and storage.tech_priests
      and type(storage.tech_priests.pairs_by_station)=="table"
      and storage.tech_priests.pairs_by_station[pair.station.unit_number]==pair
      and pair.priest.force==pair.station.force
      and pair.priest.surface==pair.station.surface)then return false end
  local mission=pair.remote_rail_outpost_0835
  local route=mission.rail_frontier_0836
  local lead=mission.first_locomotive_0836
  local wagon=mission.first_wagon_0836
  local state=pair.machine_logistics_0528
  local custody=state and state.custody
  local source=state and state.fuel_source_receipt_1013
  local locomotive=lead and lead.built_entity
  if not(mission.status=="rail-track-established"
      and route and route.chain_audit_completed_tick_0836
      and type(route.start_position)=="table"
      and type(route.built_units)=="table"
      and route.segment==#route.built_units and route.segment>=16
      and route.direction==defines.direction.east
      and lead and lead.phase=="native-paid-locomotive-verified"
      and lead.paid_completion_0836
      and lead.paid_completion_0836.native_0338_paid==true
      and valid(locomotive) and locomotive.unit_number==lead.built_unit
      and locomotive.force==pair.station.force
      and locomotive.surface==pair.station.surface
      and wagon and wagon.phase=="native-paid-wagon-verified"
      and wagon.paid_completion_0836
      and wagon.paid_completion_0836.native_0338_paid==true
      and valid(wagon.built_entity)
      and locomotive.train and locomotive.train.valid
      and wagon.built_entity.train and wagon.built_entity.train.valid
      and locomotive.train.id==wagon.built_entity.train.id
      and state and state.phase=="move-to-machine"
      and state.original_train_fuel_0836==true
      and state.action=="supply-fuel" and state.item=="coal"
      and state.machine==locomotive
      and state.machine_unit==locomotive.unit_number
      and custody and custody==pair.machine_logistics_custody_0528
      and custody.item=="coal" and custody.kind=="supply"
      and type(custody.count)=="number" and custody.count>=1
      and source and source.item=="coal"
      and source.station_unit==pair.station.unit_number
      and source.priest_unit==pair.priest.unit_number
      and source.count==custody.count
      and type(source.source_before)=="number"
      and type(source.source_after)=="number"
      and source.source_before-source.source_after==custody.count)then
    return false
  end
  local goal=movement.ground_route_final_destination or movement
  if not(type(goal)=="table" and type(goal.x)=="number"
      and type(goal.y)=="number")then return false end
  local gx=goal.x-locomotive.position.x
  local gy=goal.y-locomotive.position.y
  -- Actual 0528 collision-clear machine contact must remain inside 1.5
  -- tiles of this exact paid machine. No arbitrary mining/scouting leash.
  if gx*gx+gy*gy>2.25 then return false end
  if math.abs(point.y-route.start_position.y)>4
      or point.x<route.start_position.x-8
      or point.x>locomotive.position.x+4 then return false end
  local index=math.floor((point.x-route.start_position.x)/M.segment_step+1.5)
  if index<2 or index+1>route.segment then return false end
  local rail_point=pos(route.start_position.x+(index-1)*M.segment_step,
    route.start_position.y)
  local dx=point.x-rail_point.x
  local dy=point.y-rail_point.y
  if dx*dx+dy*dy>20.25 then return false end
  local before=track_at(pair,pos(rail_point.x-M.segment_step,
    rail_point.y),route.direction)
  local center=track_at(pair,rail_point,route.direction)
  local after=track_at(pair,pos(rail_point.x+M.segment_step,
    rail_point.y),route.direction)
  return before and center and after
    and before.unit_number==route.built_units[index-1]
    and center.unit_number==route.built_units[index]
    and after.unit_number==route.built_units[index+1]
    and connected_straight_rails(before,center)
    and connected_straight_rails(center,after) or false
end
-- 0836 train stops extend the SAME physical rail corridor narrowly, not
-- station command radius: the original paid 0338 builder may approach ONE
-- authenticated stop adjoining the audited, item-debited native railway.
-- This read-only check grants no movement to a foreign task or unsupplied
-- stop, never builds an entity and never changes inventory or pair custody.
local function authorized_paid_stop_contact_0836(pair,point)
  local mission=pair.remote_rail_outpost_0835
  local route=mission and mission.rail_frontier_0836
  local task=pair.construction_task_0338
  local role=task and task.request_value and task.request_value.rail_stop_role_0836
  if role~=nil and role~="home" and role~="remote" then return false end
  -- The remote build cannot borrow the original home-stop movement writ.
  -- A nil remote state must fail closed, not fall back to the home receipt.
  local stop
  if mission then
    if role=="remote" then stop=mission.remote_stop_0836
    else stop=mission.first_stop_0836 end
  end
  local debit=task and task.original_stop_debit_0836
  if not(mission and mission.status=="rail-track-established"
    and stop and stop.phase=="awaiting-original-0338"
    and stop.request and stop.request.rail_stop_role_0836==role
    and (role~="remote" or (mission.first_stop_0836
      and mission.first_stop_0836.phase=="native-paid-original-train-stop-verified"
      and valid(mission.first_stop_0836.built_entity)
      and mission.first_stop_0836.built_entity.unit_number==mission.first_stop_0836.built_unit))
    and route and route.chain_audit_completed_tick_0836
    and type(route.built_units)=="table"
    and route.segment==#route.built_units and route.segment>=24
    and route.direction and route.start_position
    and task and task.phase=="move-site"
    and task.request_field=="construction_request"
    and task.request_value==stop.request
    and pair.construction_request==stop.request
    and task.site_reason=="original-first-train-stop-0836"
    and task.item_name=="train-stop" and task.entity_name=="train-stop"
    and task.creative_build~=true
    and stop.request.rail_mission_station_unit_0836==pair.station.unit_number
    and task.position and stop.position
    and close(task.position,stop.position)
    and close(stop.request.position,stop.position)
    and task.direction==stop.request.direction
    and task.carried and task.carried.item_name=="train-stop"
    and task.carried.count==1
    and debit and type(debit.before)=="number"
    and type(debit.after)=="number"
    and debit.before>=1 and debit.before-debit.after==1
    and task.source_inv and task.source_inv.valid
    and valid(task.source_entity)
    and task.source_entity.unit_number==debit.source_unit)then
    return false
  end
  local dx=point.x-stop.position.x
  local dy=point.y-stop.position.y
  if dx*dx+dy*dy>9 then return false end
  -- A planned line, a ghost or an arbitrary nearby rail is insufficient:
  -- require the exact original native anchor AND both connected neighbors,
  -- each matching the conserved original rail construction-unit ledger.
  local indices=role=="remote"
    and {route.segment-16,route.segment-18,route.segment-14,
         route.segment-20,route.segment-12,route.segment-22}
    or {16,18,20,14,22,12}
  for _,index in ipairs(indices)do
    if index>=2 and index+1<=route.segment then
      local anchor=pos(route.start_position.x+(index-1)*M.segment_step,
        route.start_position.y)
      if math.abs(stop.position.x-anchor.x)<0.25
        and math.abs(stop.position.y-anchor.y)<=3 then
        local rail=track_at(pair,anchor,route.direction)
        local before=track_at(pair,pos(anchor.x-M.segment_step,anchor.y),
          route.direction)
        local after=track_at(pair,pos(anchor.x+M.segment_step,anchor.y),
          route.direction)
        local rx=point.x-anchor.x
        local ry=point.y-anchor.y
        if rx*rx+ry*ry<=25
          and rail and rail.unit_number==route.built_units[index]
          and before and before.unit_number==route.built_units[index-1]
          and after and after.unit_number==route.built_units[index+1]
          and connected_straight_rails(before,rail)
          and connected_straight_rails(rail,after) then
          return true
        end
      end
    end
  end
  return false
end
-- A physical railway has a narrow, temporary construction contact outside
-- the stationary Magos' work sphere.  Only its ORIGINAL item-debited 0338
-- builder may walk beside the LAST genuinely connected rail to place exactly
-- the NEXT pending original rail.  0574/0566 remain the movement authorities;
-- this read-only predicate supplies evidence, not a command or leash override.
function M.authorized_paid_rail_contact_0836(pair,point,reason,opts)
  if reason~="construction-site-standoff-0338"
    or not(opts and opts.owner=="construction-planner-0338")
    or not(eligible(pair,pair and pair.remote_rail_outpost_0835))
    or type(point)~="table" or type(point.x)~="number"
    or type(point.y)~="number" then return false end
  if authorized_paid_stop_contact_0836(pair,point) then return true end
  local mission=pair.remote_rail_outpost_0835
  local pending=mission.pending_rail_0836
  local route=mission.rail_frontier_0836
  local task=pair.construction_task_0338
  local debit=task and task.original_rail_source_debit_0836
  if mission.status~="building-physical-rail"
    or not(pending and route and task and debit)
    or task.request_field~="construction_request"
    or task.request_value~=pending.request
    or pair.construction_request~=pending.request
    or task.site_reason~="remote-rail-physical-frontier-0836"
    or task.item_name~="rail" or task.entity_name~="straight-rail"
    or task.phase~="move-site"
    or not(task.carried and task.carried.item_name=="rail"
      and task.carried.count==1)
    or not(task.source_inv and task.source_inv.valid)
    or not(valid(task.source_entity)
      and task.source_entity.unit_number==debit.source_unit)
    or debit.item~="rail" or type(debit.before)~="number"
    or type(debit.after)~="number" or debit.before-debit.after~=1
    or task.position.x~=pending.position.x
    or task.position.y~=pending.position.y
    or task.direction~=pending.direction
    or route.direction~=pending.direction
    or type(route.segment)~="number" or route.segment<1
    or route.segment~=math.floor(route.segment)
    or pending.segment~=route.segment+1
    or type(route.last_position)~="table"
    or type(route.built_units)~="table"
    or #route.built_units~=route.segment
    or math.abs(point.x-pending.position.x)>3
    or math.abs(point.y-pending.position.y)>3 then return false end
  local site_dx=point.x-pending.position.x
  local site_dy=point.y-pending.position.y
  if site_dx*site_dx+site_dy*site_dy>9 then return false end
  local last=track_at(pair,route.last_position,route.direction)
  if not(last and last.unit_number
    and last.unit_number==route.built_units[route.segment]) then
    return false
  end
  local dx=point.x-last.position.x
  local dy=point.y-last.position.y
  if dx*dx+dy*dy>25 then return false end
  if route.segment>1 then
    local preceding=pos(
      route.last_position.x-M.segment_step,route.last_position.y)
    local before=track_at(pair,preceding,route.direction)
    if not(before and before.unit_number
      and before.unit_number==route.built_units[route.segment-1]
      and connected_straight_rails(before,last)) then return false end
  end
  return true
end
-- Railway-expedition travel is exceptional only while the ORIGINAL 0338
-- builder owns a real rail step. 0574 admits the distant *destination*, but
-- 0566 must also recognize the physical journey along previously paid track.
-- No entity ghosts, new dispatcher, free stock, or general leash override.
function M.authorized_paid_rail_transit_0836(pair,point,movement)
  if not(eligible(pair,pair and pair.remote_rail_outpost_0835)
    and type(point)=="table" and type(point.x)=="number"
    and type(point.y)=="number" and type(movement)=="table"
    and movement.owner=="construction-planner-0338"
    and storage and storage.tech_priests
    and type(storage.tech_priests.pairs_by_station)=="table"
    and storage.tech_priests.pairs_by_station[pair.station.unit_number]==pair
    and (movement.expires_tick==nil
      or (type(movement.expires_tick)=="number"
        and movement.expires_tick>=now()))
    and pair.priest.surface==pair.station.surface
    and pair.priest.force==pair.station.force)then return false end
  local goal=movement.ground_route_final_destination or movement
  if not(type(goal)=="table" and type(goal.x)=="number"
      and type(goal.y)=="number")then return false end
  local mission=pair.remote_rail_outpost_0835
  local route=mission.rail_frontier_0836
  local task=pair.construction_task_0338
  local pending=mission.pending_rail_0836
  if not(task and task.creative_build~=true
      and route and type(route.start_position)=="table"
      and type(route.last_position)=="table"
      and type(route.segment)=="number" and route.segment>=1
      and route.segment==math.floor(route.segment)
      and route.segment<=M.max_segments
      and type(route.built_units)=="table"
      and #route.built_units==route.segment
      and defines and defines.direction
      and route.direction==defines.direction.east
      and close(route.start_position,native_first_rail_center(pair.station.position))
      and close(route.last_position,pos(
        route.start_position.x+(route.segment-1)*M.segment_step,
        route.start_position.y)))then return false end
  local reason=movement.reason
  if reason=="construction-site-standoff-0338" then
    if not M.authorized_paid_rail_contact_0836(pair,goal,reason,
        {owner=movement.owner}) then return false end
  elseif reason=="construction-source-0338" then
    -- The outbound rail builder may have to walk HOME to a real source
    -- before it can debit the next rail. Only the exact pending physical
    -- rail writ, its original 0338 worker and an in-range real inventory
    -- can authorize this empty-handed trip. This is not ore scouting.
    local source=task.source_entity
    if not(mission.status=="building-physical-rail"
      and pending and pending.request==pair.construction_request
      and task.request_field=="construction_request"
      and task.request_value==pending.request
      and task.site_reason=="remote-rail-physical-frontier-0836"
      and task.item_name=="rail" and task.entity_name=="straight-rail"
      and task.phase=="move-source"
      and task.position and pending.position
      and close(task.position,pending.position)
      and task.direction==pending.direction
      and pending.segment==route.segment+1
      and pending.request.rail_mission_station_unit_0836
        ==pair.station.unit_number
      and pending.request.rail_segment_0836==pending.segment
      and close(pending.request.position,pending.position)
      and (not task.carried or (tonumber(task.carried.count) or 0)==0)
      and valid(source) and source.position
      and source.force==pair.station.force
      and source.surface==pair.station.surface
      and task.source_inv and task.source_inv.valid
      and type(task.source_inv.get_item_count)=="function")then
      return false
    end
    local supplied,stocked=pcall(function()
      return task.source_inv.get_item_count("rail") end)
    if not(supplied and type(stocked)=="number"
      and stocked>=1)then return false end
    local sx=goal.x-source.position.x
    local sy=goal.y-source.position.y
    local hx=source.position.x-pair.station.position.x
    local hy=source.position.y-pair.station.position.y
    if sx*sx+sy*sy>64 or hx*hx+hy*hy>48*48 then return false end
    -- Check the original physical frontier even before the builder takes
    -- the next rail. No merely planned/foreign/disconnected track qualifies.
    local last=track_at(pair,route.last_position,route.direction)
    if not(last and last.unit_number==route.built_units[route.segment])then
      return false
    end
    if route.segment>1 then
      local before=track_at(pair,pos(
        route.last_position.x-M.segment_step,route.last_position.y),
        route.direction)
      if not(before and before.unit_number==route.built_units[route.segment-1]
        and connected_straight_rails(before,last))then return false end
    end
  else
    return false
  end
  -- For the current straight eastbound baseline, the priest must actually
  -- remain beside item-paid original rails, not merely inside a huge rectangle
  -- stretching to its eventual target. Check one nearby rail and predecessor,
  -- bounded O(1) native scans. Curved routes require a later graph-based lane
  -- validator; they do not inherit this straight-corridor exception.
  local start=route.start_position
  local min_x=math.min(pair.station.position.x,start.x)-6
  local max_x=route.last_position.x+6
  if point.x<min_x or point.x>max_x
    or math.abs(point.y-start.y)>10 then return false end
  local index=math.floor((point.x-start.x)/M.segment_step+0.5)+1
  index=math.max(1,math.min(route.segment,index))
  local at=pos(start.x+(index-1)*M.segment_step,start.y)
  local rail=track_at(pair,at,route.direction)
  if not(rail and rail.unit_number==route.built_units[index])then
    return false
  end
  if index>1 then
    local previous=track_at(pair,pos(at.x-M.segment_step,at.y),
      route.direction)
    if not(previous and previous.unit_number==route.built_units[index-1]
      and connected_straight_rails(previous,rail))then return false end
  end
  return true
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
  -- A previous 0338 discovery may have cached a purely UNFUNDED,
  -- UNSTARTED bootstrap candidate. It owns no material and no site. Ask
  -- the original 0338 owner to yield only that candidate before evaluating
  -- the physically stocked rail writ. Funded candidates, live tasks,
  -- requests, robot work and any physical custody remain untouched.
  if pair.construction_candidate_0338
      and not (pair.construction_task_0338
        or pair.construction_custody_0338 or pair.construction_request) then
    local builder=rawget(_G,"TechPriestsConstructionPlanner0338")
    if builder and type(builder.yield_unfunded_frontier_candidate_0338)
        =="function" then
      -- A successful pcall is not proof that the original 0338 owner
      -- authorized yielding its candidate. The second return value is the
      -- real admission verdict; preserve that owner's funded/robot/task
      -- refusal instead of collapsing it to a generic occupied slot.
      local ok,yielded,reason=pcall(
        builder.yield_unfunded_frontier_candidate_0338,pair)
      if not ok then return false,"rail-unfunded-candidate-yield-error" end
      if yielded~=true then
        return false,"rail-unfunded-candidate-yield-refused:"..tostring(reason)
      end
    end
  end
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
    start_position=native_first_rail_center(start),
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
  -- Retain a small primitive-only inspection of true Factorio rail
  -- extensions once for each credited segment. This never modifies the
  -- original straight-east execution path or creates construction ghosts.
  -- Later curve routing can consume the snapshot after native validation.
  if route.segment>0
    and route.native_probe_segment_1402~=route.segment then
    local options,why=M.inspect_native_rail_extensions_0836(pair)
    route.native_probe_segment_1402=route.segment
    route.native_probe_reason_1402=why
    route.native_probe_options_1402=options or {}
    route.native_probe_tick_1402=now()
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
  -- Only the exact original 0338 request may defer rail verification.
  -- Another physical construction task retains its own cargo while this
  -- unadmitted rail writ must still expire under its existing deadline.
  local builder=pair.construction_task_0338
  local custody=pair.construction_custody_0338
  if (builder and builder.request_value==pending.request)
      or (custody and custody.request_value==pending.request) then
    return false,"physical-builder-in-progress"
  end
  local previous=pair.construction_last_task_0338
  -- The generic last-task slot is shared with normal construction. A prior
  -- ORIGINAL paid rail completion can survive its replacement only if 0338
  -- itself captured the exact native source decrement and built LuaEntity.
  -- The ledger remains attached to this ONE pending request, not global.
  local saved=pending.original_paid_completion_0836
  local saved_matches=not(previous and previous.request_value==pending.request)
    and type(saved)=="table" and saved.request_value==pending.request
    and saved.phase=="complete" and saved.native_0338_paid==true
    and saved.item_name=="rail" and saved.creative_build==false
    and type(saved.source_unit)=="number"
    and type(saved.source_before)=="number"
    and type(saved.source_after)=="number"
    and saved.source_before>=1
    and saved.source_before-saved.source_after==1
    and valid(saved.built_entity)
    and saved.built_entity.unit_number==saved.built_unit
    and saved.built_entity.force==pair.station.force
    and saved.built_entity.surface==pair.station.surface
  if saved_matches then previous=saved end
  -- A saved terminal 0338 receipt can predate the live creative-build guard.
  -- An admin-built rail is a real entity but NOT a physical item debit;
  -- never import that old completion as counted railway after reload.
  if previous and previous.request_value==pending.request
      and previous.phase=="complete" and previous.creative_build==true then
    return reject(m,"physical-rail-creative-receipt-forbidden")
  end
  if not(previous and previous.request_value==pending.request
      and previous.phase=="complete" and valid(previous.built_entity)
      and previous.built_entity.name=="straight-rail"
      and close(previous.built_entity.position,pending.position)
      and previous.built_entity.direction==pending.direction
      -- Normal last-task proof still requires the original request cleared.
      -- A source-debited saved completion may coexist with a NEW unrelated
      -- request; never rewrite, borrow or erase that request/custody.
      and (pair.construction_request==nil
        or (saved_matches and pair.construction_request~=pending.request)))then
    -- A completed, item-debited ORIGINAL rail that is refused here must
    -- disclose WHICH unweakened native predicate failed. This is a one-shot,
    -- read-only receipt: no refund, reconstruction, request mutation or credit.
    if not pending.original_guard_refusal_0836
        and previous and previous.request_value==pending.request
        and previous.phase=="complete" then
      local built=previous.built_entity
      local alive=valid(built)
      local actual_position=alive and built.position or nil
      local native=track_at(pair,pending.position,pending.direction)
      local debit=previous.original_rail_source_debit_0836
      pending.original_guard_refusal_0836={
        tick=now(),built_valid=alive==true,
        built_unit=alive and built.unit_number or nil,
        built_name=alive and built.name or nil,
        built_x=actual_position and actual_position.x or nil,
        built_y=actual_position and actual_position.y or nil,
        built_direction=alive and built.direction or nil,
        requested_x=pending.position.x,requested_y=pending.position.y,
        requested_direction=pending.direction,
        position_matches=alive and close(actual_position,pending.position) or false,
        direction_matches=alive and built.direction==pending.direction or false,
        name_matches=alive and built.name=="straight-rail" or false,
        request_cleared=pair.construction_request==nil,
        same_force=alive and built.force==pair.station.force or false,
        same_surface=alive and built.surface==pair.station.surface or false,
        native_at_requested_unit=native and native.unit_number or nil,
        original_debit_before=debit and debit.before or nil,
        original_debit_after=debit and debit.after or nil,
      }
      local d=pending.original_guard_refusal_0836
      if log then log("[Tech-Priests rail-0836] ORIGINAL_GUARD_REFUSAL"..
        " tick="..tostring(d.tick)..
        " built_valid="..tostring(d.built_valid)..
        " built_unit="..tostring(d.built_unit)..
        " built_name="..tostring(d.built_name)..
        " built="..tostring(d.built_x)..","..tostring(d.built_y)..
        " built_direction="..tostring(d.built_direction)..
        " requested="..tostring(d.requested_x)..","..tostring(d.requested_y)..
        " requested_direction="..tostring(d.requested_direction)..
        " position_matches="..tostring(d.position_matches)..
        " direction_matches="..tostring(d.direction_matches)..
        " name_matches="..tostring(d.name_matches)..
        " request_cleared="..tostring(d.request_cleared)..
        " same_force="..tostring(d.same_force)..
        " same_surface="..tostring(d.same_surface)..
        " native_at_requested_unit="..tostring(d.native_at_requested_unit)..
        " original_debit_before="..tostring(d.original_debit_before)..
        " original_debit_after="..tostring(d.original_debit_after)) end
    end
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
      -- Snapshot FIRST lost original request at the existing physical
      -- verifier boundary. Never silently call a later unrelated 0338
      -- terminal build proof of this rail, or create an item to replace it.
      if not pending.first_loss_snapshot_0836 then
        local foreign=pair.construction_request
        local last=pair.construction_last_task_0338
        local terminal=pending.original_terminal_trace_0836
        pending.first_loss_snapshot_0836={
          tick=now(),
          current_item=type(foreign)=="table" and foreign.item_name or nil,
          current_site=type(foreign)=="table" and foreign.site_reason or nil,
          last_item=last and last.item_name or nil,
          last_result=last and last.result or nil,
          last_phase=last and last.phase or nil,
          last_is_original=last and last.request_value==pending.request or false,
          original_terminal_seen=terminal~=nil,
          original_terminal_phase=terminal and terminal.phase or nil,
          original_terminal_reason=terminal and terminal.result or nil,
          original_debit_before=terminal and terminal.source_before or nil,
          original_debit_after=terminal and terminal.source_after or nil,
          original_source_readback=terminal and terminal.source_readback or nil,
        }
        if log then
          log("[Tech-Priests rail-0836] ORIGINAL_REQUEST_LOST"..
            " tick="..tostring(now())..
            " current_item="..tostring(pending.first_loss_snapshot_0836.current_item)..
            " current_site="..tostring(pending.first_loss_snapshot_0836.current_site)..
            " last_item="..tostring(pending.first_loss_snapshot_0836.last_item)..
            " last_result="..tostring(pending.first_loss_snapshot_0836.last_result)..
            " last_original="..tostring(pending.first_loss_snapshot_0836.last_is_original)..
            " terminal_phase="..tostring(pending.first_loss_snapshot_0836.original_terminal_phase)..
            " original_debit_before="..tostring(pending.first_loss_snapshot_0836.original_debit_before)..
            " original_debit_after="..tostring(pending.first_loss_snapshot_0836.original_debit_after))
        end
      end
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
    -- One primitive-only failure receipt: distinguish a stale scan, a
    -- native snapped position/direction, and a substituted physical rail.
    -- Never claim or rewrite a paid rail on an identity mismatch.
    if not pending.native_site_refusal_0836 then
      local built=previous.built_entity
      pending.native_site_refusal_0836={
        tick=now(),expected_unit=valid(built) and built.unit_number or nil,
        found_unit=valid(actual) and actual.unit_number or nil,
        built_x=valid(built) and built.position.x or nil,
        built_y=valid(built) and built.position.y or nil,
        built_direction=valid(built) and built.direction or nil,
        requested_x=pending.position.x,requested_y=pending.position.y,
        requested_direction=pending.direction}
      if log then log("[Tech-Priests rail-0836] NATIVE_SITE_REFUSAL"..
        " tick="..tostring(now())..
        " expected="..tostring(pending.native_site_refusal_0836.expected_unit)..
        " found="..tostring(pending.native_site_refusal_0836.found_unit)..
        " built="..tostring(pending.native_site_refusal_0836.built_x)..
          ","..tostring(pending.native_site_refusal_0836.built_y)..
        " built_direction="..tostring(pending.native_site_refusal_0836.built_direction)..
        " requested="..tostring(pending.position.x)..","..
          tostring(pending.position.y)..
        " requested_direction="..tostring(pending.direction)) end
    end
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
-- Native Factorio 2.1 railway planning probe. Only a verified, counted
-- frontier rail can be inspected. Its LuaRailEnd extensions are the engine's
-- authoritative NEXT geometry (including curves), not ghosts or build writs.
-- This is a bounded read-only snapshot for later route search; the original
-- straight-east 0836 request/0338 custody remains the ONLY live executor.
function M.inspect_native_rail_extensions_0836(pair)
  local mission=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,mission)then return nil,"no-original-magos-mission"end
  local route=mission.rail_frontier_0836
  if not(route and type(route.segment)=="number" and route.segment>=1
    and route.segment==math.floor(route.segment)
    and route.segment<=M.max_segments
    and type(route.built_units)=="table"
    and #route.built_units==route.segment
    and type(route.last_position)=="table"
    and type(route.direction)=="number")then
    return nil,"no-counted-native-rail-frontier"
  end
  local last=track_at(pair,route.last_position,route.direction)
  if not(last and last.unit_number==route.built_units[route.segment])
    then return nil,"native-frontier-identity-missing" end
  if type(last.get_rail_end)~="function"
    or not(defines and defines.rail_direction)then
    return nil,"native-rail-end-api-unavailable" end
  local options,seen={},{}
  local api_ends=0
  for _,direction in ipairs({defines.rail_direction.front,
      defines.rail_direction.back})do
    if direction~=nil then
      local ok,rail_end=pcall(function()return last.get_rail_end(direction)end)
      if ok and rail_end and rail_end.valid
        and type(rail_end.get_rail_extensions)=="function"then
        local read,extensions=pcall(function()
          return rail_end.get_rail_extensions("rail") end)
        if read and type(extensions)=="table"then
          api_ends=api_ends+1
          -- Bounding this read avoids accidental unbounded work from
          -- external rail planners. Only primitive identifiers are retained.
          for i=1,math.min(#extensions,16)do
            local ext=extensions[i]
            local point=ext and ext.position
            local name=ext and ext.name
            local d=ext and ext.direction
            if type(name)=="string" and type(point)=="table"
              and type(point.x)=="number"and type(point.y)=="number"
              and type(d)=="number"
              and prototypes and prototypes.entity
              and prototypes.entity[name] then
              local key=name..":"..tostring(point.x)..":"..
                tostring(point.y)..":"..tostring(d)
              if not seen[key] then
                seen[key]=true
                local can,placeable=pcall(function()
                  return pair.station.surface.can_place_entity{
                    name=name,position=point,direction=d,
                    force=pair.station.force}end)
                if can and placeable==true then
                  local dx=point.x-mission.target.x
                  local dy=point.y-mission.target.y
                  options[#options+1]={
                    name=name,position={x=point.x,y=point.y},
                    direction=d,from_rail_unit=last.unit_number,
                    rail_end_direction=direction,
                    distance_sq=dx*dx+dy*dy,
                  }
                end
              end
            end
          end
        end
      end
    end
  end
  if api_ends==0 then return nil,"native-rail-extensions-unavailable"end
  -- Score the observed, engine-placeable extensions without trusting
  -- ghosts, distant speculation, foreign rail IDs or backward duplicates.
  -- This pure ranker never issues a 0338 work request or spends a rail.
  local selected,decision=RouteChoice1403.rank({
    unit_number=last.unit_number,position=last.position,
  },options,mission.target)
  if #selected>0 then return selected,"native-rail-options-observed"end
  return selected,decision=="no-progressive-rail-extension-1403"
    and "native-rail-options-no-progress"
    or "native-rail-options-obstructed"
end

-- First rolling-stock transaction. Exactly ONE original locomotive is
-- requested through 0338 after the complete native-rail identity/graph audit.
-- This is never permission to create stock, a train, or Magos passenger state.
function M.service_first_locomotive_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,m) or m.status~="rail-track-established" then
    return false,"not-original-complete-rail-mission"
  end
  local route=m.rail_frontier_0836
  if not(route and type(route.built_units)=="table"
      and route.segment==#route.built_units and route.segment>=16
      and type(route.start_position)=="table"
      and route.chain_audit_completed_tick_0836)then
    return false,"original-rail-audit-not-proven"
  end
  local state=m.first_locomotive_0836
  if state then
    if state.phase=="blocked" then return false,state.blocker end
    local receipt=state.paid_completion_0836
    if receipt then
      local entity=receipt.built_entity
      if not(receipt.request_value==state.request
        and receipt.native_0338_paid==true
        and receipt.source_unit and type(receipt.before)=="number"
        and type(receipt.after)=="number"
        and receipt.before-receipt.after==1
        and valid(entity) and entity==state.built_entity
        and entity.unit_number==receipt.built_unit
        and entity.name=="locomotive"
        and entity.force==pair.station.force
        and entity.surface==pair.station.surface
        and entity.train and entity.train.valid
        and math.abs(entity.position.x-state.position.x)<=2
        and math.abs(entity.position.y-state.position.y)<=2)then
        state.phase="blocked"
        state.blocker="native-paid-locomotive-receipt-invalid"
        return false,state.blocker
      end
      state.phase="native-paid-locomotive-verified"
      state.built_unit=entity.unit_number
      state.train_id=entity.train.id
      state.verified_tick=now()
      m.next_step="construct-paid-wagon-and-fuel-real-train"
      return false,"first-native-paid-locomotive-verified"
    end
    local last=pair.construction_last_task_0338
    if last and last.request_value==state.request and last.phase=="aborted"then
      state.phase="blocked"
      state.blocker="original-0338-locomotive-aborted:"..tostring(last.result)
      return false,state.blocker
    end
    if pair.construction_request~=state.request
      and not(pair.construction_task_0338
        and pair.construction_task_0338.request_value==state.request)
      and not(pair.construction_custody_0338
        and pair.construction_custody_0338.request_value==state.request)then
      state.phase="blocked"
      state.blocker="original-locomotive-request-lost"
      return false,state.blocker
    end
    return false,"original-0338-locomotive-in-progress"
  end
  -- A real, previously refused UNSTARTED local miner has no site or
  -- material lease. Retain its original writ untouched while the already
  -- audited rail mission may borrow the separate construction_request slot.
  -- A funded/placeable miner, another refusal, or any active custody wins.
  local prior=pair.construction_requested_item
  local refusal=pair.construction_site_refusal_0338
  local prior_name=type(prior)=="string" and prior
    or type(prior)=="table" and (prior.entity_name or prior.item_name)
  local proto=prior_name and prototypes and prototypes.entity
    and prototypes.entity[prior_name]
  local age=refusal and tonumber(refusal.tick)
  local refused_miner=prior~=nil and proto and proto.type=="mining-drill"
    and not(type(prior)=="table"
      and (prior.position or prior.site_position))
    and type(refusal)=="table" and refusal.field=="construction_requested_item"
    and refusal.request==prior and refusal.reason=="no-miner-site"
    and age and age<=now() and now()-age<=600
  if (prior and not refused_miner) or pair.construction_request
    or pair.construction_task_0338 or pair.construction_custody_0338
    or pair.robot_network_task_0338 or pair.robot_network_request_0338
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.defense_task_0259
    or (pair.station_expansion_0256
       and pair.station_expansion_0256.status=="active")then
    return false,"incumbent-physical-work"
  end
  local stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if not(stock and type(stock.generic_storage_sources)=="function")then
    return false,"native-locomotive-storage-unavailable"
  end
  local ok,sources=pcall(stock.generic_storage_sources,pair)
  if not(ok and type(sources)=="table")then
    return false,"native-locomotive-sources-unobservable"
  end
  local stocked=false
  for _,source in ipairs(sources)do
    if source.inv and source.inv.valid and valid(source.entity)
      and source.entity.force==pair.station.force
      and source.entity.surface==pair.station.surface then
      local counted,n=pcall(source.inv.get_item_count,"locomotive")
      if counted and type(n)=="number" and n>0 then stocked=true;break end
    end
  end
  if not stocked then return false,"no-real-locomotive-item" end
  local surface=pair.station.surface
  local chosen
  for _,index in ipairs({16,12,8})do
    if index+1<=route.segment then
      local point=pos(route.start_position.x+(index-1)*M.segment_step,
        route.start_position.y)
      local previous=track_at(pair,pos(point.x-M.segment_step,point.y),
        route.direction)
      local rail=track_at(pair,point,route.direction)
      local next_rail=track_at(pair,pos(point.x+M.segment_step,point.y),
        route.direction)
      if previous and rail and next_rail
        and previous.unit_number==route.built_units[index-1]
        and rail.unit_number==route.built_units[index]
        and next_rail.unit_number==route.built_units[index+1]
        and connected_straight_rails(previous,rail)
        and connected_straight_rails(rail,next_rail)then
        local safe,can=pcall(function()
          return surface.can_place_entity{
            name="locomotive",position=point,direction=route.direction,
            force=pair.station.force}
        end)
        if safe and can==true then chosen=point;break end
      end
    end
  end
  if not chosen then
    return false,"native-locomotive-site-not-engine-placeable"
  end
  -- The original 0469 owner, not the frontier, decides whether a live
  -- source-less emergency order may yield. Never cancel or modify it.
  local oq=pair.order_queue_0469
  if pair.active_order_0469 or (oq and oq.current) then
    local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if not(owner and type(owner.can_yield_uncommitted_rail_0836)=="function")then
      return false,"locomotive-order-owner-unavailable"
    end
    local ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,nil)
    if not(ok and allowed==true)then
      return false,"locomotive-incumbent-order-refused"
    end
  end
  local request={item_name="locomotive",entity_name="locomotive",
    category="rail",position=chosen,direction=route.direction,
    site_reason="original-first-locomotive-0836",
    rail_mission_station_unit_0836=m.root_station_unit}
  m.first_locomotive_0836={phase="awaiting-original-0338",
    request=request,position=chosen,issued_tick=now()}
  pair.construction_request=request
  m.next_step="existing-0338-physical-first-locomotive"
  m.last_update_tick=now()
  return true,"first-locomotive-physical-request-issued"
end
function M.service_return_locomotive_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,m) or m.status~="rail-track-established" then
    return false,"not-original-complete-rail-mission"
  end
  local route=m.rail_frontier_0836
  if not(route and type(route.built_units)=="table"
      and route.segment==#route.built_units and route.segment>=16
      and type(route.start_position)=="table"
      and route.chain_audit_completed_tick_0836)then
    return false,"original-rail-audit-not-proven"
  end
  local lead=m.first_locomotive_0836
  local wagon=m.first_wagon_0836
  if not(lead and lead.phase=="native-paid-locomotive-verified"
    and wagon and wagon.phase=="native-paid-wagon-verified"
    and valid(lead.built_entity) and valid(wagon.built_entity)
    and lead.built_entity.train and lead.built_entity.train.valid
    and wagon.built_entity.train and wagon.built_entity.train.valid
    and lead.built_entity.train.id==wagon.built_entity.train.id)then
    return false,"original-coupled-wagon-unavailable-for-return-traction"
  end
  local state=m.return_locomotive_0836
  if state then
    if state.phase=="blocked" then return false,state.blocker end
    local receipt=state.paid_completion_0836
    if receipt then
      local entity=receipt.built_entity
      if not(receipt.request_value==state.request
        and receipt.native_0338_paid==true
        and receipt.source_unit and type(receipt.before)=="number"
        and type(receipt.after)=="number"
        and receipt.before-receipt.after==1
        and valid(entity) and entity==state.built_entity
        and entity.unit_number==receipt.built_unit
        and entity.name=="locomotive"
        and entity.force==pair.station.force
        and entity.surface==pair.station.surface
        and entity.train and entity.train.valid
        -- Rolling stock uses continuous orientation. LuaEntity.direction
        -- may read north for entities with supports_direction=false, even
        -- when the native east/west locomotive visibly faces otherwise.
        -- Reject any locomotive not physically opposite the original lead.
        and type(entity.orientation)=="number"
        and type(lead.built_entity.orientation)=="number"
        and math.abs(((entity.orientation-lead.built_entity.orientation)%1)-0.5)
          <0.03125
        and lead.built_entity.train and lead.built_entity.train.valid
        and wagon.built_entity.train and wagon.built_entity.train.valid
        and entity.train.id==lead.built_entity.train.id
        and wagon.built_entity.train.id==entity.train.id
        and math.abs(entity.position.x-state.position.x)<=2
        and math.abs(entity.position.y-state.position.y)<=2)then
        state.phase="blocked"
        state.blocker="native-paid-locomotive-receipt-invalid"
        return false,state.blocker
      end
      state.phase="native-paid-return-locomotive-verified"
      state.built_unit=entity.unit_number
      state.train_id=entity.train.id
      state.verified_tick=now()
      m.next_step="construct-paid-wagon-and-fuel-real-train"
      return false,"first-native-paid-return-locomotive-verified"
    end
    local last=pair.construction_last_task_0338
    if last and last.request_value==state.request and last.phase=="aborted"then
      state.phase="blocked"
      state.blocker="original-0338-locomotive-aborted:"..tostring(last.result)
      return false,state.blocker
    end
    if pair.construction_request~=state.request
      and not(pair.construction_task_0338
        and pair.construction_task_0338.request_value==state.request)
      and not(pair.construction_custody_0338
        and pair.construction_custody_0338.request_value==state.request)then
      state.phase="blocked"
      state.blocker="original-locomotive-request-lost"
      return false,state.blocker
    end
    return false,"original-0338-locomotive-in-progress"
  end
  -- A real, previously refused UNSTARTED local miner has no site or
  -- material lease. Retain its original writ untouched while the already
  -- audited rail mission may borrow the separate construction_request slot.
  -- A funded/placeable miner, another refusal, or any active custody wins.
  local prior=pair.construction_requested_item
  local refusal=pair.construction_site_refusal_0338
  local prior_name=type(prior)=="string" and prior
    or type(prior)=="table" and (prior.entity_name or prior.item_name)
  local proto=prior_name and prototypes and prototypes.entity
    and prototypes.entity[prior_name]
  local age=refusal and tonumber(refusal.tick)
  local refused_miner=prior~=nil and proto and proto.type=="mining-drill"
    and not(type(prior)=="table"
      and (prior.position or prior.site_position))
    and type(refusal)=="table" and refusal.field=="construction_requested_item"
    and refusal.request==prior and refusal.reason=="no-miner-site"
    and age and age<=now() and now()-age<=600
  if (prior and not refused_miner) or pair.construction_request
    or pair.construction_task_0338 or pair.construction_custody_0338
    or pair.robot_network_task_0338 or pair.robot_network_request_0338
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.defense_task_0259
    or (pair.station_expansion_0256
       and pair.station_expansion_0256.status=="active")then
    return false,"incumbent-physical-work"
  end
  local stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if not(stock and type(stock.generic_storage_sources)=="function")then
    return false,"native-locomotive-storage-unavailable"
  end
  local ok,sources=pcall(stock.generic_storage_sources,pair)
  if not(ok and type(sources)=="table")then
    return false,"native-locomotive-sources-unobservable"
  end
  local stocked=false
  for _,source in ipairs(sources)do
    if source.inv and source.inv.valid and valid(source.entity)
      and source.entity.force==pair.station.force
      and source.entity.surface==pair.station.surface then
      local counted,n=pcall(source.inv.get_item_count,"locomotive")
      if counted and type(n)=="number" and n>0 then stocked=true;break end
    end
  end
  if not stocked then return false,"no-real-locomotive-item" end
  local surface=pair.station.surface
  local chosen
  for _,offset in ipairs({-7,-6,-8})do
    local point=pos(wagon.built_entity.position.x+offset,
      wagon.built_entity.position.y)
    local index=math.floor((point.x-route.start_position.x)/M.segment_step+1.5)
    if index>=2 and index+1<=route.segment then
      local previous=track_at(pair,pos(point.x-M.segment_step,point.y),
        route.direction)
      local rail=track_at(pair,point,route.direction)
      local next_rail=track_at(pair,pos(point.x+M.segment_step,point.y),
        route.direction)
      if previous and rail and next_rail
        and previous.unit_number==route.built_units[index-1]
        and rail.unit_number==route.built_units[index]
        and next_rail.unit_number==route.built_units[index+1]
        and connected_straight_rails(previous,rail)
        and connected_straight_rails(rail,next_rail)then
        local safe,can=pcall(function()
          return surface.can_place_entity{
            name="locomotive",position=point,direction=(route.direction+8)%16,
            force=pair.station.force}
        end)
        if safe and can==true then chosen=point;break end
      end
    end
  end
  if not chosen then
    return false,"native-locomotive-site-not-engine-placeable"
  end
  -- The original 0469 owner, not the frontier, decides whether a live
  -- source-less emergency order may yield. Never cancel or modify it.
  local oq=pair.order_queue_0469
  if pair.active_order_0469 or (oq and oq.current) then
    local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if not(owner and type(owner.can_yield_uncommitted_rail_0836)=="function")then
      return false,"locomotive-order-owner-unavailable"
    end
    local ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,nil)
    if not(ok and allowed==true)then
      return false,"locomotive-incumbent-order-refused"
    end
  end
  local request={item_name="locomotive",entity_name="locomotive",
    category="rail",position=chosen,direction=(route.direction+8)%16,
    site_reason="original-return-locomotive-0836",
    rail_mission_station_unit_0836=m.root_station_unit}
  m.return_locomotive_0836={phase="awaiting-original-0338",
    request=request,position=chosen,issued_tick=now()}
  pair.construction_request=request
  m.next_step="existing-0338-physical-first-locomotive"
  m.last_update_tick=now()
  return true,"first-locomotive-physical-request-issued"
end
function M.service_first_wagon_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not eligible(pair,m) or m.status~="rail-track-established" then
    return false,"not-original-complete-rail-mission"
  end
  local route=m.rail_frontier_0836
  if not(route and type(route.built_units)=="table"
      and route.segment==#route.built_units and route.segment>=16
      and type(route.start_position)=="table"
      and route.chain_audit_completed_tick_0836)then
    return false,"original-rail-audit-not-proven"
  end
  local parent=m.first_locomotive_0836
  if not(parent and parent.phase=="native-paid-locomotive-verified"
    and valid(parent.built_entity)
    and parent.built_entity.unit_number==parent.built_unit
    and parent.built_entity.train and parent.built_entity.train.valid
    and parent.built_entity.force==pair.station.force
    and parent.built_entity.surface==pair.station.surface)then
    return false,"original-native-locomotive-not-proven"
  end
  local state=m.first_wagon_0836
  if state then
    if state.phase=="native-paid-wagon-verified"then
      return false,"first-native-paid-wagon-verified"
    end
    if state.phase=="blocked" then return false,state.blocker end
    local receipt=state.paid_completion_0836
    if receipt then
      local entity=receipt.built_entity
      if not(receipt.request_value==state.request
        and receipt.native_0338_paid==true
        and receipt.source_unit and type(receipt.before)=="number"
        and type(receipt.after)=="number"
        and receipt.before-receipt.after==1
        and valid(entity) and entity==state.built_entity
        and entity.unit_number==receipt.built_unit
        and entity.name=="cargo-wagon"
        and entity.force==pair.station.force
        and entity.surface==pair.station.surface
        and entity.train and entity.train.valid
        and parent.built_entity.train and parent.built_entity.train.valid
        and entity.train.id==parent.built_entity.train.id
        and math.abs(entity.position.x-state.position.x)<=2
        and math.abs(entity.position.y-state.position.y)<=2)then
        state.phase="blocked"
        state.blocker="native-paid-wagon-receipt-invalid"
        return false,state.blocker
      end
      local has_loco,has_wagon=false,false
      for _,carriage in ipairs(parent.built_entity.train.carriages)do
        if carriage==parent.built_entity then has_loco=true end
        if carriage==entity then has_wagon=true end
      end
      if not(has_loco and has_wagon)then
        state.phase="blocked"
        state.blocker="native-paid-wagon-not-coupled"
        return false,state.blocker
      end
      state.phase="native-paid-wagon-verified"
      state.built_unit=entity.unit_number
      state.train_id=entity.train.id
      state.verified_tick=now()
      m.next_step="physically-fuel-coupled-locomotive"
      return false,"first-native-paid-wagon-verified"
    end
    local last=pair.construction_last_task_0338
    if last and last.request_value==state.request and last.phase=="aborted"then
      state.phase="blocked"
      state.blocker="original-0338-wagon-aborted:"..tostring(last.result)
      return false,state.blocker
    end
    if pair.construction_request~=state.request
      and not(pair.construction_task_0338
        and pair.construction_task_0338.request_value==state.request)
      and not(pair.construction_custody_0338
        and pair.construction_custody_0338.request_value==state.request)then
      state.phase="blocked"
      state.blocker="original-wagon-request-lost"
      return false,state.blocker
    end
    return false,"original-0338-wagon-in-progress"
  end
  -- A real, previously refused UNSTARTED local miner has no site or
  -- material lease. Retain its original writ untouched while the already
  -- audited rail mission may borrow the separate construction_request slot.
  -- A funded/placeable miner, another refusal, or any active custody wins.
  local prior=pair.construction_requested_item
  local refusal=pair.construction_site_refusal_0338
  local prior_name=type(prior)=="string" and prior
    or type(prior)=="table" and (prior.entity_name or prior.item_name)
  local proto=prior_name and prototypes and prototypes.entity
    and prototypes.entity[prior_name]
  local age=refusal and tonumber(refusal.tick)
  local refused_miner=prior~=nil and proto and proto.type=="mining-drill"
    and not(type(prior)=="table"
      and (prior.position or prior.site_position))
    and type(refusal)=="table" and refusal.field=="construction_requested_item"
    and refusal.request==prior and refusal.reason=="no-miner-site"
    and age and age<=now() and now()-age<=600
  if (prior and not refused_miner) or pair.construction_request
    or pair.construction_task_0338 or pair.construction_custody_0338
    or pair.robot_network_task_0338 or pair.robot_network_request_0338
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.defense_task_0259
    or (pair.station_expansion_0256
       and pair.station_expansion_0256.status=="active")then
    return false,"incumbent-physical-work"
  end
  local stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if not(stock and type(stock.generic_storage_sources)=="function")then
    return false,"native-wagon-storage-unavailable"
  end
  local ok,sources=pcall(stock.generic_storage_sources,pair)
  if not(ok and type(sources)=="table")then
    return false,"native-wagon-sources-unobservable"
  end
  local stocked=false
  for _,source in ipairs(sources)do
    if source.inv and source.inv.valid and valid(source.entity)
      and source.entity.force==pair.station.force
      and source.entity.surface==pair.station.surface then
      local counted,n=pcall(source.inv.get_item_count,"cargo-wagon")
      if counted and type(n)=="number" and n>0 then stocked=true;break end
    end
  end
  if not stocked then return false,"no-real-cargo-wagon-item" end
  local surface=pair.station.surface
  local chosen
  -- Position behind the original locomotive, entirely on its counted native
  -- graph. The engine must independently accept this physical cargo wagon.
  for _,offset in ipairs({-7,-6,-8})do
    local point=pos(parent.built_entity.position.x+offset,parent.built_entity.position.y)
    local index=math.floor((point.x-route.start_position.x)/M.segment_step+1.5)
    if index>=2 and index+1<=route.segment then
      local previous=track_at(pair,pos(route.start_position.x+(index-2)*M.segment_step,route.start_position.y),route.direction)
      local rail=track_at(pair,pos(route.start_position.x+(index-1)*M.segment_step,route.start_position.y),route.direction)
      local following=track_at(pair,pos(route.start_position.x+index*M.segment_step,route.start_position.y),route.direction)
      if previous and rail and following
        and previous.unit_number==route.built_units[index-1]
        and rail.unit_number==route.built_units[index]
        and following.unit_number==route.built_units[index+1]
        and connected_straight_rails(previous,rail)
        and connected_straight_rails(rail,following)then
        local safe,can=pcall(function()
          return surface.can_place_entity{
            name="cargo-wagon",position=point,
            direction=route.direction,force=pair.station.force}
        end)
        if safe and can==true then chosen=point;break end
      end
    end
  end
  if not chosen then
    return false,"native-wagon-site-not-engine-placeable"
  end
  -- The original 0469 owner, not the frontier, decides whether a live
  -- source-less emergency order may yield. Never cancel or modify it.
  local oq=pair.order_queue_0469
  if pair.active_order_0469 or (oq and oq.current) then
    local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if not(owner and type(owner.can_yield_uncommitted_rail_0836)=="function")then
      return false,"wagon-order-owner-unavailable"
    end
    local ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,nil)
    if not(ok and allowed==true)then
      return false,"wagon-incumbent-order-refused"
    end
  end
  local request={item_name="cargo-wagon",entity_name="cargo-wagon",
    category="rail",position=chosen,direction=route.direction,
    site_reason="original-first-wagon-0836",
    rail_mission_station_unit_0836=m.root_station_unit}
  m.first_wagon_0836={phase="awaiting-original-0338",
    request=request,position=chosen,issued_tick=now()}
  pair.construction_request=request
  m.next_step="existing-0338-physical-first-wagon"
  m.last_update_tick=now()
  return true,"first-wagon-physical-request-issued"
end
-- An original coupled train may count as fueled only after the existing
-- 0528 physical station->priest->locomotive transaction has reported exact
-- source and destination deltas, and Factorio still holds that real coal.
function M.service_first_train_fuel_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  local loco=m and m.first_locomotive_0836
  local wagon=m and m.first_wagon_0836
  local entity=loco and loco.built_entity
  if not(eligible(pair,m) and m.status=="rail-track-established"
      and m.rail_frontier_0836
      and m.rail_frontier_0836.chain_audit_completed_tick_0836
      and loco and loco.phase=="native-paid-locomotive-verified"
      and wagon and wagon.phase=="native-paid-wagon-verified"
      and valid(entity) and entity.unit_number==loco.built_unit
      and valid(wagon.built_entity)
      and wagon.built_entity.unit_number==wagon.built_unit
      and entity.train and entity.train.valid
      and wagon.built_entity.train and wagon.built_entity.train.valid
      and entity.train.id==wagon.built_entity.train.id)then
    return false,"original-coupled-train-unavailable"
  end
  local fuel_id=defines and defines.inventory and defines.inventory.fuel
  if not fuel_id then return false,"native-fuel-inventory-id-unavailable"end
  local ok,fuel=pcall(function()return entity.get_inventory(fuel_id)end)
  if not(ok and fuel and fuel.valid)then
    return false,"native-locomotive-fuel-inventory-unavailable"
  end
  local state=m.first_fuel_0836 or {}
  m.first_fuel_0836=state
  if state.phase=="native-paid-locomotive-fueled" then
    return false,"native-paid-locomotive-fueled"
  end
  local receipts=pair.machine_fuel_receipts_1013 or {}
  for i=#receipts,1,-1 do
    local receipt=receipts[i]
    if receipt and receipt.machine_unit==entity.unit_number
        and receipt.station_unit==pair.station.unit_number
        and receipt.priest_unit==pair.priest.unit_number
        and receipt.authority=="physical-machine-fuel-0528"
        and receipt.item=="coal" and tonumber(receipt.count)
        and receipt.count>=1 and receipt.source_before
        and receipt.source_before-receipt.source_after==receipt.count
        and receipt.destination_before
        and receipt.destination_after-receipt.destination_before==receipt.count
        and loco.verified_tick and receipt.tick>=loco.verified_tick
        and wagon.verified_tick and receipt.tick>=wagon.verified_tick then
      local read,n=pcall(fuel.get_item_count,"coal")
      if read and type(n)=="number" and n>=receipt.count then
        state.phase="native-paid-locomotive-fueled"
        state.fuel_item="coal"
        state.fuel_count=receipt.count
        state.receipt_tick=receipt.tick
        state.locomotive_unit=entity.unit_number
        state.wagon_unit=wagon.built_unit
        state.train_id=entity.train.id
        state.verified_tick=now()
        m.next_step="native-route-and-magos-boarding"
        return false,"native-paid-locomotive-fueled"
      end
    end
  end
  local logistics=rawget(_G,"TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
    or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
  if not(logistics and type(logistics.offer_original_locomotive_fuel_0836)=="function")then
    return false,"original-0528-fuel-authority-unavailable"
  end
  local called,accepted,why=pcall(
    logistics.offer_original_locomotive_fuel_0836,pair,entity)
  state.last_attempt_tick=now()
  state.last_attempt_reason=tostring(called and why or accepted)
  return called and accepted==true,state.last_attempt_reason
end

-- First 0836 native Magos boarding. A script receipt is not an onboard
-- passenger: 0418 must move the SAME original priest close to the real train,
-- and Factorio must return that LuaEntity from the locomotive driver socket.
-- First native train stop: one real train-stop item, original 0338
-- physical builder, exact source debit, live connection to counted 0836 rail.
-- This is route infrastructure ONLY, never a claim that a unit Magos boarded.
function M.service_first_train_stop_0836(pair,role)
  -- Two independently paid 0338 stops on the same audited original rail.
  -- A home-only stop cannot prove an outward expedition.
  local remote=role=="remote"
  local m=pair and pair.remote_rail_outpost_0835
  local route=m and m.rail_frontier_0836
  local loco=m and m.first_locomotive_0836
  local wagon=m and m.first_wagon_0836
  local fuel=m and m.first_fuel_0836
  if not(eligible(pair,m) and m.status=="rail-track-established"
    and route and route.chain_audit_completed_tick_0836
    and type(route.built_units)=="table"
    and route.segment==#route.built_units and route.segment>=24
    and loco and loco.phase=="native-paid-locomotive-verified"
    and wagon and wagon.phase=="native-paid-wagon-verified"
    and fuel and fuel.phase=="native-paid-locomotive-fueled"
    and valid(loco.built_entity) and valid(wagon.built_entity)
    and loco.built_entity.train and loco.built_entity.train.valid
    and wagon.built_entity.train and wagon.built_entity.train.valid
    and loco.built_entity.train.id==wagon.built_entity.train.id)then
    return false,"original-paid-fueled-train-and-track-unavailable"
  end
  if remote and not(m.first_stop_0836
    and m.first_stop_0836.phase=="native-paid-original-train-stop-verified"
    and valid(m.first_stop_0836.built_entity)
    and m.first_stop_0836.built_entity.unit_number==m.first_stop_0836.built_unit)then
    return false,"original-home-stop-not-verified"
  end
  -- A missing remote state MUST NOT fall back to the already verified
  -- home stop. Lua's 'a and nil or b' would silently take the home receipt,
  -- declaring the remote stage complete without placing its physical item.
  local state
  if remote then state=m.remote_stop_0836
  else state=m.first_stop_0836 end
  local function connected_original(stop)
    if not(valid(stop) and stop.name=="train-stop"
      and stop.force==pair.station.force
      and stop.surface==pair.station.surface)then return false end
    local ok,rail=pcall(function()return stop.connected_rail end)
    if not(ok and valid(rail) and rail.name=="straight-rail")then
      return false
    end
    for _,unit in ipairs(route.built_units)do
      if unit==rail.unit_number then return true end
    end
    return false
  end
  if state then
    if state.phase=="native-paid-original-train-stop-verified"then
      if connected_original(state.built_entity)
        and state.built_entity.unit_number==state.built_unit then
        return false,"native-paid-original-train-stop-verified"
      end
      state.phase="blocked"
      state.blocker="original-native-train-stop-or-rail-lost"
      return false,state.blocker
    end
    if state.phase=="blocked"then return false,state.blocker end
    local receipt=state.paid_completion_0836
    if receipt then
      local stop=receipt.built_entity
      if not(receipt.request_value==state.request
        and receipt.native_0338_paid==true
        and receipt.source_unit
        and type(receipt.before)=="number"
        and type(receipt.after)=="number"
        and receipt.before-receipt.after==1
        and valid(stop) and stop==state.built_entity
        and stop.unit_number==receipt.built_unit
        and connected_original(stop))then
        state.phase="blocked"
        state.blocker="original-native-paid-train-stop-receipt-or-connection-invalid"
        return false,state.blocker
      end
      state.phase="native-paid-original-train-stop-verified"
      state.built_unit=stop.unit_number
      state.verified_tick=now()
      m.next_step="native-route-and-original-magos-boarding"
      return false,"native-paid-original-train-stop-verified"
    end
    local last=pair.construction_last_task_0338
    if last and last.request_value==state.request and last.phase=="aborted"then
      state.phase="blocked"
      state.blocker="original-0338-train-stop-aborted:"..tostring(last.result)
      return false,state.blocker
    end
    if pair.construction_request~=state.request
      and not(pair.construction_task_0338
        and pair.construction_task_0338.request_value==state.request)
      and not(pair.construction_custody_0338
        and pair.construction_custody_0338.request_value==state.request)then
      state.phase="blocked"
      state.blocker="original-train-stop-request-lost"
      return false,state.blocker
    end
    return false,"original-0338-train-stop-in-progress"
  end
  -- Do not displace funded, physical or identity-owned incumbent work.
  -- A fresh unstarted, legitimately refused no-site miner is not custody.
  local prior=pair.construction_requested_item
  local refusal=pair.construction_site_refusal_0338
  local name=type(prior)=="string" and prior
    or type(prior)=="table" and (prior.entity_name or prior.item_name)
  local proto=name and prototypes and prototypes.entity
    and prototypes.entity[name]
  local age=refusal and tonumber(refusal.tick)
  local refused_miner=prior~=nil and proto and proto.type=="mining-drill"
    and not(type(prior)=="table"
      and (prior.position or prior.site_position))
    and type(refusal)=="table"
    and refusal.field=="construction_requested_item"
    and refusal.request==prior and refusal.reason=="no-miner-site"
    and age and age<=now() and now()-age<=600
  if (prior and not refused_miner) or pair.construction_request
    or pair.construction_task_0338 or pair.construction_custody_0338
    or pair.robot_network_task_0338 or pair.robot_network_request_0338
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.defense_task_0259
    or (pair.station_expansion_0256
      and pair.station_expansion_0256.status=="active")then
    return false,"incumbent-physical-work"
  end
  local stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if not(stock and type(stock.generic_storage_sources)=="function")then
    return false,"original-train-stop-storage-unavailable"
  end
  local observed,sources=pcall(stock.generic_storage_sources,pair)
  if not(observed and type(sources)=="table")then
    return false,"original-train-stop-stock-unobservable"
  end
  local stocked=false
  for _,source in ipairs(sources)do
    if source.inv and source.inv.valid and valid(source.entity)
      and source.entity.force==pair.station.force
      and source.entity.surface==pair.station.surface then
      local ok,n=pcall(source.inv.get_item_count,"train-stop")
      if ok and type(n)=="number" and n>=1 then stocked=true;break end
    end
  end
  if not stocked then return false,"no-real-train-stop-item" end
  -- The 0338 builder alone places a stop. Test cardinal sides and
  -- direction using live engine placeability, never create a trial entity.
  local cardinal=defines and defines.direction
  if not(cardinal and type(cardinal.east)=="number"
    and type(cardinal.west)=="number"
    and (route.direction==cardinal.east or route.direction==cardinal.west))then
    return false,"original-native-train-stop-requires-horizontal-track"
  end
  local chosen,direction
  -- The far stop must lie near the paid distant frontier, not home.
  local indices=remote
    and {route.segment-16,route.segment-18,route.segment-14,
         route.segment-20,route.segment-12,route.segment-22}
    or {16,18,20,14,22,12}
  for _,index in ipairs(indices)do
    if index>=2 and index+1<=route.segment then
      local origin=pos(route.start_position.x+(index-1)*M.segment_step,
        route.start_position.y)
      local rail=track_at(pair,origin,route.direction)
      if rail and rail.unit_number==route.built_units[index] then
        -- The original engine confirmed both paid stops but returned
        -- train.has_path=false for twelve thousand ticks: the generic
        -- north-first search picked a WEST-facing distant stop, impossible
        -- for the original EASTBOUND Magos expedition. Only select the
        -- arrival-side orientation for each role, and fail closed if that
        -- actual Factorio placement is unavailable.
        local offsets=remote and {2,3} or {-2,-3}
        for _,offset in ipairs(offsets)do
          -- A stop sits to the RIGHT of arriving trains. A north-side
          -- stop must face west, and a south-side stop must face east.
          -- can_place_entity checks collisions, NOT connected_rail; the
          -- old arbitrary heading order built a paid but disconnected stop.
          local heading=offset<0 and cardinal.west or cardinal.east
          local site=pos(origin.x,origin.y+offset)
          local ok,placeable=pcall(function()
            return pair.station.surface.can_place_entity{
              name="train-stop",position=site,direction=heading,
              force=pair.station.force}
          end)
          if ok and placeable==true then
            chosen=site;direction=heading;break
          end
        end
      end
    end
    if chosen then break end
  end
  if not chosen then return false,"original-native-train-stop-site-unplaceable"end
  local queue=pair.order_queue_0469
  if pair.active_order_0469 or (queue and queue.current)then
    local owner=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
    if not(owner and type(owner.can_yield_uncommitted_rail_0836)=="function")then
      return false,"original-train-stop-order-owner-unavailable"
    end
    local ok,allowed=pcall(owner.can_yield_uncommitted_rail_0836,pair,nil)
    if not(ok and allowed==true)then
      return false,"original-train-stop-incumbent-order-refused"
    end
  end
  local request={item_name="train-stop",entity_name="train-stop",
    category="rail",position=chosen,direction=direction,
    site_reason="original-first-train-stop-0836",
    rail_stop_role_0836=remote and "remote" or "home",
    rail_mission_station_unit_0836=m.root_station_unit}
  local record={phase="awaiting-original-0338",
    request=request,position=chosen,issued_tick=now()}
  if remote then m.remote_stop_0836=record
  else m.first_stop_0836=record end
  pair.construction_request=request
  m.next_step=remote and "existing-0338-physical-remote-train-stop"
    or "existing-0338-physical-first-train-stop"
  m.last_update_tick=now()
  return true,remote and "original-remote-train-stop-request-issued"
    or "original-first-train-stop-request-issued"
end

function M.service_first_train_board_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  local loco=m and m.first_locomotive_0836
  local wagon=m and m.first_wagon_0836
  local fuel=m and m.first_fuel_0836
  local entity=loco and loco.built_entity
  local priest=pair and pair.priest
  if not(eligible(pair,m) and m.status=="rail-track-established"
      and m.rail_frontier_0836
      and m.rail_frontier_0836.chain_audit_completed_tick_0836
      and loco and loco.phase=="native-paid-locomotive-verified"
      and wagon and wagon.phase=="native-paid-wagon-verified"
      and fuel and fuel.phase=="native-paid-locomotive-fueled"
      and valid(entity) and entity.unit_number==loco.built_unit
      and valid(wagon.built_entity) and wagon.built_entity.unit_number==wagon.built_unit
      and valid(priest) and priest.unit_number==pair.priest.unit_number
      and entity.surface==priest.surface and entity.force==priest.force
      and entity.train and entity.train.valid
      and wagon.built_entity.train and wagon.built_entity.train.valid
      and entity.train.id==wagon.built_entity.train.id)then
    return false,"original-fueled-train-and-priest-unavailable"
  end
  local state=m.first_board_0836 or {phase="awaiting-physical-approach"}
  m.first_board_0836=state
  local train=entity.train
  if math.abs(tonumber(train.speed)or 0)>0.01 then
    state.last_blocker="original-train-not-stationary"
    return false,state.last_blocker
  end
  local ok,driver=pcall(function()return entity.get_driver()end)
  if not ok then
    state.last_blocker="native-train-driver-read-unavailable"
    return false,state.last_blocker
  end
  if driver and driver~=priest then
    state.last_blocker="native-train-driver-occupied"
    return false,state.last_blocker
  end
  if driver==priest then
    state.phase="native-original-magos-boarded"
    state.priest_unit=priest.unit_number
    state.locomotive_unit=entity.unit_number
    state.wagon_unit=wagon.built_unit
    state.train_id=train.id
    state.confirmed_tick=state.confirmed_tick or now()
    pair.train_transport_rail_0835={
      train_id=train.id,boarded_priest_unit=priest.unit_number,
      physical_boarding_confirmed=true,boarded_tick=state.confirmed_tick,
      locomotive_unit=entity.unit_number,wagon_unit=wagon.built_unit}
    m.next_step="native-rail-expedition-outbound"
    return false,"native-original-magos-onboard"
  end
  -- A prior 0528 delivery receipt is historical, not proof of current
  -- traction fuel. Read the ORIGINAL locomotive's live native fuel before
  -- requesting boarding/movement. An already-burning fuel item also counts;
  -- otherwise fail closed with the train and original priest untouched.
  local fuel_slot=defines and defines.inventory and defines.inventory.fuel
  local fuel_read,fuel_now=pcall(function()
    if not fuel_slot then return nil end
    local inv=entity.get_inventory(fuel_slot)
    if not(inv and inv.valid)then return nil end
    local coal=inv.get_item_count("coal")
    if type(coal)~="number" or coal<0 then return nil end
    if coal>0 then return true end
    local burner=entity.burner
    if not(burner and burner.valid)then return nil end
    local energy=tonumber(burner.remaining_burning_fuel)
    if not energy then return nil end
    return energy>0
  end)
  if not fuel_read or fuel_now~=true then
    state.phase="native-boarding-fuel-blocked"
    state.last_blocker=(fuel_read and fuel_now==false)
      and "original-train-out-of-live-fuel"
      or "original-train-live-fuel-unobservable"
    return false,state.last_blocker
  end
  -- Native unit Magos cannot occupy Factorio's character-only train socket.
  -- Diagnose this original prototype before incidental logistics movement:
  -- never cancel a legitimate 0702 duty or change any physical inventory.
  -- Factorio's native driver socket accepts ONLY characters. The original
  -- commandable Cogitator priest is a unit, so attempted driver assignment
  -- never becomes valid. Preserve the identical live priest and train;
  -- do not create a movement lease or fraudulent passenger receipt.
  -- Recheck the actual prototype each call for future compatible migrations.
  if priest.type~="character" then
    state.phase="native-boarding-unsupported-original-unit"
    state.last_priest_type=priest.type
    state.priest_unit=priest.unit_number
    state.unsupported_since_tick=state.unsupported_since_tick or now()
    state.last_blocker="native-driver-requires-original-character:"..priest.type
    return false,state.last_blocker
  end
  if pair.construction_task_0338 or pair.construction_custody_0338
      or pair.machine_logistics_custody_0528
      or pair.direct_acquisition_custody_0513
      or pair.inventory_transfer_custody_0687
      or pair.defense_task_0259 then
    state.last_blocker="boarding-foreign-physical-custody"
    return false,state.last_blocker
  end
  local machine=pair.machine_logistics_0528
  if type(machine)=="table" and machine.phase
      and machine.phase~="complete" and machine.phase~="failed" then
    -- Ask the ORIGINAL 0528 owner to release only its proven abandoned,
    -- unladen fuel approach AFTER counted native train/fuel verification.
    -- It must refuse live movement, explicit machine orders and any cargo.
    -- 0836 never edits another executor's state or inventory directly.
    local logistics=rawget(_G,"TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
      or package.loaded["scripts.core.logistics_machine_fulfillment_0528"]
    if logistics and
        type(logistics.release_abandoned_unladen_train_preboarding_0836)=="function"then
      pcall(logistics.release_abandoned_unladen_train_preboarding_0836,pair,entity)
    end
    machine=pair.machine_logistics_0528
    if type(machine)=="table" and machine.phase
        and machine.phase~="complete" and machine.phase~="failed"then
      state.last_blocker="boarding-machine-logistics-still-active"
      return false,state.last_blocker
    end
  end
  local request=pair.movement_request_0418
  if request and request.owner~="rail-track-frontier-0836" then
    state.last_blocker="boarding-foreign-movement-owned"
    return false,state.last_blocker
  end

  local dx=priest.position.x-entity.position.x
  local dy=priest.position.y-entity.position.y
  local distance_sq=dx*dx+dy*dy
  state.last_distance_sq=distance_sq
  if distance_sq>3.3*3.3 then
    local move=rawget(_G,"tech_priests_request_movement_0418")
    if type(move)~="function"then
      state.last_blocker="boarding-canonical-movement-unavailable"
      return false,state.last_blocker
    end
    local called,accepted,why=pcall(move,pair,entity.position,
      "original-train-physical-boarding-0836",{
        owner="rail-track-frontier-0836",priority=710,
        ttl=60*8,radius=2.5,
        distraction=defines and defines.distraction and defines.distraction.none})
    state.phase="approaching-native-train"
    state.last_blocker=called and tostring(why or accepted)
      or "boarding-canonical-movement-error"
    return called and accepted==true,state.last_blocker
  end
  if now()<(tonumber(state.retry_after_tick)or 0)then
    return false,state.last_blocker or "native-boarding-retry-bounded"
  end
  state.last_priest_type=priest.type
  local boarded,why=pcall(function()entity.set_driver(priest)end)
  local read,actual=pcall(function()return entity.get_driver()end)
  if not(boarded and read and actual==priest and valid(priest)
      and priest.unit_number==pair.priest.unit_number)then
    state.last_blocker=boarded and "native-driver-did-not-bind-original-priest"
      or "native-driver-refused:"..tostring(why)
    state.retry_after_tick=now()+300
    state.phase="native-boarding-refused"
    return false,state.last_blocker
  end
  return M.service_first_train_board_0836(pair)
end

-- First outward expedition: the ORIGINAL Magos must be the native driver of
-- the ORIGINAL counted train. Only a physically paid/connected distant 0338
-- stop is eligible. A schedule is an order, NOT a travel acceptance receipt.
function M.service_first_train_outbound_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  local loco=m and m.first_locomotive_0836
  local wagon=m and m.first_wagon_0836
  local far=m and m.remote_stop_0836
  local home=m and m.first_stop_0836
  local route=m and m.rail_frontier_0836
  local priest=pair and pair.priest
  local engine=loco and loco.built_entity
  local remote=far and far.built_entity
  local origin=home and home.built_entity
  if not(eligible(pair,m) and m.status=="rail-track-established"
    and loco and loco.phase=="native-paid-locomotive-verified"
    and wagon and wagon.phase=="native-paid-wagon-verified"
    and far and far.phase=="native-paid-original-train-stop-verified"
    and home and home.phase=="native-paid-original-train-stop-verified"
    and valid(engine) and engine.unit_number==loco.built_unit
    and valid(wagon.built_entity)
    and wagon.built_entity.unit_number==wagon.built_unit
    and valid(remote) and remote.unit_number==far.built_unit
    and valid(origin) and origin.unit_number==home.built_unit
    and remote~=origin and valid(priest) and route
    and type(route.built_units)=="table"
    and engine.train and engine.train.valid
    and wagon.built_entity.train and wagon.built_entity.train.valid
    and engine.train.id==wagon.built_entity.train.id
    and engine.force==remote.force and engine.force==origin.force
    and engine.surface==remote.surface and engine.surface==origin.surface
    and engine.surface==priest.surface and engine.force==priest.force)then
    return false,"original-outbound-train-stops-or-priest-unavailable"
  end
  local train=engine.train
  local ride=pair.train_transport_rail_0835
  local driver_read,driver=pcall(function()return engine.get_driver()end)
  if not(driver_read and driver==priest
    and ride and ride.train_id==train.id
    and ride.boarded_priest_unit==priest.unit_number
    and ride.physical_boarding_confirmed==true
    and ride.disembark_confirmed~=true)then
    return false,"original-magos-not-native-driver-for-outbound"
  end
  -- The independently paid stop must still touch an original 0836-built
  -- native rail. Merely preserving its Lua completion record is insufficient.
  local connected,remote_rail=pcall(function()return remote.connected_rail end)
  local counted=false
  if connected and valid(remote_rail)then
    for _,unit in ipairs(route.built_units)do
      if unit==remote_rail.unit_number then counted=true;break end
    end
  end
  if not counted then return false,"original-remote-stop-no-longer-on-paid-rail"end
  local state=m.first_outbound_0836
  if not state then
    state={phase="awaiting-original-native-schedule",train_id=train.id,
      priest_unit=priest.unit_number,locomotive_unit=engine.unit_number,
      remote_stop_unit=remote.unit_number,home_stop_unit=origin.unit_number,
      origin_x=engine.position.x,highest_x=engine.position.x}
    m.first_outbound_0836=state
  end
  if state.train_id~=train.id or state.priest_unit~=priest.unit_number
      or state.locomotive_unit~=engine.unit_number
      or state.remote_stop_unit~=remote.unit_number
      or state.home_stop_unit~=origin.unit_number then
    state.last_blocker="original-outbound-identity-changed"
    return false,state.last_blocker
  end
  local schedule_ok,schedule=pcall(function()return train.get_schedule()end)
  if not(schedule_ok and schedule and schedule.valid)then
    state.last_blocker="original-native-schedule-unavailable"
    return false,state.last_blocker
  end
  local unique="TP-0836-remote-"..tostring(m.root_station_unit)
    .."-"..tostring(remote.unit_number)
  local read,records=pcall(function()return schedule.get_records()end)
  if not(read and type(records)=="table")then
    state.last_blocker="original-native-schedule-records-unobservable"
    return false,state.last_blocker
  end
  -- Reject an existing operator/other-train schedule BEFORE renaming the
  -- stop. In particular, do not invalidate another train's destination.
  if not state.schedule_write_attempted and #records~=0 then
    state.last_blocker="original-train-has-foreign-schedule"
    return false,state.last_blocker
  end
  local fuel_slot=defines and defines.inventory and defines.inventory.fuel
  local live,has_fuel=pcall(function()
    if not fuel_slot then return nil end
    local inv=engine.get_inventory(fuel_slot)
    if not(inv and inv.valid)then return nil end
    local coal=inv.get_item_count("coal")
    if type(coal)~="number" or coal<0 then return nil end
    if coal>0 then return true end
    local burner=engine.burner
    if not(burner and burner.valid)then return nil end
    local energy=tonumber(burner.remaining_burning_fuel)
    return energy and energy>0 or nil
  end)
  if not(live and has_fuel==true)then
    state.last_blocker="original-outbound-no-observed-native-fuel"
    return false,state.last_blocker
  end
  local name_ok,name=pcall(function()return remote.backer_name end)
  if not name_ok then
    state.last_blocker="original-remote-stop-name-unreadable"
    return false,state.last_blocker
  end
  -- No new material or entity is created: this only names the original
  -- paid physical stop. Never replace another train's existing schedule.
  if name~=unique then
    if state.schedule_write_attempted then
      state.last_blocker="original-remote-stop-name-changed-after-order"
      return false,state.last_blocker
    end
    local renamed=pcall(function()remote.backer_name=unique end)
    local verified,new_name=pcall(function()return remote.backer_name end)
    if not(renamed and verified and new_name==unique)then
      state.last_blocker="original-remote-stop-rename-unverified"
      return false,state.last_blocker
    end
  end
  if not state.schedule_write_attempted then
    -- Set this BEFORE mutating the engine: an exception after the native
    -- write must not cause duplicate records or overwrite a foreign order.
    state.schedule_write_attempted=true
    local written=pcall(function()
      schedule.add_record{station=unique,
        wait_conditions={{type="time",ticks=3600,compare_type="and"}}}
    end)
    if not written then
      state.last_blocker="original-native-schedule-write-unconfirmed"
      return false,state.last_blocker
    end
  end
  local verified,observed=pcall(function()return schedule.get_records()end)
  if not(verified and type(observed)=="table"
    and #observed==1 and observed[1].station==unique)then
    state.last_blocker="original-outbound-schedule-readback-mismatch"
    return false,state.last_blocker
  end
  if not state.departure_order_issued then
    state.departure_order_issued=true
    local issued=pcall(function()schedule.go_to_station(1)end)
    if not issued then
      state.last_blocker="original-native-departure-order-unconfirmed"
      return false,state.last_blocker
    end
  end
  state.schedule_confirmed_tick=state.schedule_confirmed_tick or now()
  state.highest_x=math.max(tonumber(state.highest_x)or state.origin_x,
    engine.position.x)
  local at_remote=(train.station==remote)
  if at_remote and state.highest_x>state.origin_x+32 then
    state.phase="native-original-outbound-arrived-at-paid-remote-stop"
    state.arrived_tick=state.arrived_tick or now()
    state.last_blocker=nil
    m.next_step="native-remote-station-and-ore-acquisition"
    return false,"native-original-outbound-arrival-confirmed"
  end
  if state.highest_x>state.origin_x+32 then
    state.phase="native-original-outbound-movement-observed"
  else
    state.phase="native-original-outbound-schedule-admitted"
  end
  state.last_train_state=train.state
  state.last_has_path=train.has_path
  state.last_path_stop_unit=valid(train.path_end_stop)
    and train.path_end_stop.unit_number or nil
  return false,"native-original-outbound-awaiting-physical-arrival"
end

-- Only the same original Magos/native train at the independently paid
-- remote stop may ask Factorio to take it home. A schedule or route receipt is
-- never evidence of a return journey; single-headed trains may have no path.
function M.service_first_train_return_0836(pair)
  local m=pair and pair.remote_rail_outpost_0835
  local outward=m and m.first_outbound_0836
  local loco=m and m.first_locomotive_0836
  local wagon=m and m.first_wagon_0836
  local far=m and m.remote_stop_0836
  local home=m and m.first_stop_0836
  local route=m and m.rail_frontier_0836
  local engine=loco and loco.built_entity
  local remote=far and far.built_entity
  local origin=home and home.built_entity
  local priest=pair and pair.priest
  if not(eligible(pair,m) and m.status=="rail-track-established"
    and outward and outward.phase=="native-original-outbound-arrived-at-paid-remote-stop"
    and outward.highest_x and outward.highest_x>outward.origin_x+32
    and loco and loco.phase=="native-paid-locomotive-verified"
    and wagon and wagon.phase=="native-paid-wagon-verified"
    and far and far.phase=="native-paid-original-train-stop-verified"
    and home and home.phase=="native-paid-original-train-stop-verified"
    and route and route.chain_audit_completed_tick_0836
    and valid(engine) and engine.unit_number==loco.built_unit
    and valid(wagon.built_entity) and wagon.built_entity.unit_number==wagon.built_unit
    and valid(remote) and remote.unit_number==far.built_unit
    and valid(origin) and origin.unit_number==home.built_unit
    and remote~=origin and valid(priest) and engine.train and engine.train.valid
    and wagon.built_entity.train and wagon.built_entity.train.valid
    and engine.train.id==wagon.built_entity.train.id
    and engine.train.id==outward.train_id
    and engine.surface==remote.surface and engine.surface==origin.surface
    and engine.force==remote.force and engine.force==origin.force)then
    return false,"native-homeward-original-identity-or-outward-gate-missing"
  end
  local train=engine.train
  local read_driver,driver=pcall(function()return engine.get_driver()end)
  local ride=pair.train_transport_rail_0835
  if not(read_driver and driver==priest and ride
    and ride.boarded_priest_unit==priest.unit_number
    and ride.physical_boarding_confirmed==true
    and ride.train_id==train.id and ride.disembark_confirmed~=true)then
    return false,"native-homeward-original-magos-not-driver"
  end
  local paid={}
  for _,unit in ipairs(route.built_units)do paid[unit]=true end
  for _,stop in ipairs({remote,origin})do
    local observed,rail=pcall(function()return stop.connected_rail end)
    if not(observed and valid(rail) and paid[rail.unit_number])then
      return false,"native-homeward-paid-stop-disconnected"
    end
  end
  local state=m.first_return_0836
  if not state then
    if train.station~=remote then
      return false,"native-homeward-original-remote-arrival-not-live"
    end
    state={phase="awaiting-native-home-order",train_id=train.id,
      priest_unit=priest.unit_number,locomotive_unit=engine.unit_number,
      remote_stop_unit=remote.unit_number,home_stop_unit=origin.unit_number,
      remote_x=engine.position.x,lowest_x=engine.position.x,
      departure_tick=now()}
    m.first_return_0836=state
  end
  if state.train_id~=train.id or state.priest_unit~=priest.unit_number
    or state.locomotive_unit~=engine.unit_number
    or state.remote_stop_unit~=remote.unit_number
    or state.home_stop_unit~=origin.unit_number then
    state.last_blocker="native-homeward-original-identity-changed"
    return false,state.last_blocker
  end
  local ok,schedule=pcall(function()return train.get_schedule()end)
  local read,records=pcall(function()
    return schedule and schedule.valid and schedule.get_records()
  end)
  local remote_name="TP-0836-remote-"..tostring(m.root_station_unit)..
    "-"..tostring(remote.unit_number)
  local home_name="TP-0836-home-"..tostring(m.root_station_unit)..
    "-"..tostring(origin.unit_number)
  if not(ok and schedule and schedule.valid and read and type(records)=="table"
    and records[1] and records[1].station==remote_name
    and (state.home_order_written or #records==1))then
    state.last_blocker="native-homeward-schedule-foreign-or-unreadable"
    return false,state.last_blocker
  end
  local renamed,name=pcall(function()return origin.backer_name end)
  if not renamed then return false,"native-homeward-home-stop-unreadable" end
  if name~=home_name then
    if state.home_order_written then
      state.last_blocker="native-homeward-stop-renamed-after-order"
      return false,state.last_blocker
    end
    local changed=pcall(function()origin.backer_name=home_name end)
    local reread,actual=pcall(function()return origin.backer_name end)
    if not(changed and reread and actual==home_name)then
      return false,"native-homeward-stop-rename-refused"
    end
  end
  if not state.home_order_written then
    -- Set before the native call: a post-write exception must not double-add
    -- the stop or overwrite another train's schedule.
    state.home_order_written=true
    local written=pcall(function()
      schedule.add_record{station=home_name,
        wait_conditions={{type="time",ticks=3600,compare_type="and"}}}
    end)
    if not written then
      state.last_blocker="native-homeward-schedule-write-uncertain"
      return false,state.last_blocker
    end
  end
  local checked,after=pcall(function()return schedule.get_records()end)
  if not(checked and type(after)=="table" and #after==2
    and after[1].station==remote_name and after[2].station==home_name)then
    state.last_blocker="native-homeward-two-stop-readback-failed"
    return false,state.last_blocker
  end
  if not state.home_departure_issued then
    state.home_departure_issued=true
    local issued=pcall(function()schedule.go_to_station(2)end)
    if not issued then
      state.last_blocker="native-homeward-departure-native-refusal"
      return false,state.last_blocker
    end
  end
  state.lowest_x=math.min(tonumber(state.lowest_x)or state.remote_x,
    engine.position.x)
  state.last_train_state=train.state
  state.last_has_path=train.has_path
  state.last_station_unit=valid(train.station)
    and train.station.unit_number or nil
  if train.station==origin
    and state.lowest_x<state.remote_x-32
    and engine.position.x<=origin.position.x+12 then
    state.phase="native-original-home-arrived-after-roundtrip"
    state.arrival_tick=state.arrival_tick or now()
    state.last_blocker=nil
    m.next_step="native-returned-original-train-awaiting-natural-ore"
    return false,"native-original-homeward-arrival-confirmed"
  end
  state.phase="native-homeward-order-issued-awaiting-real-travel"
  if train.has_path==false and train.station~=origin then
    state.last_blocker="native-homeward-no-physical-path"
    return false,state.last_blocker
  end
  state.last_blocker=nil
  return false,"native-homeward-travel-not-yet-confirmed"
end

function M.service_pair(pair)
  local m=pair and pair.remote_rail_outpost_0835
  if not m then return false,"no-rail-mission"end
  if not eligible(pair,m)then return false,"not-authorized-rail-mission"end
  -- Bounded evidence that the original broker actually serviced this
  -- specific mission; a stale prewrite refusal is not a live verdict.
  if now()-(tonumber(m.last_service_sample_tick_0836)or -600)>=600 then
    m.last_service_sample_tick_0836=now()
    m.last_service_sample_pending_0836=m.pending_rail_0836~=nil
  end
  if m.status=="rail-track-blocked" then return false,m.status end
  if m.status=="rail-track-established" then
    local loco=m.first_locomotive_0836
    if loco and loco.phase=="native-paid-locomotive-verified"then
      local wagon=m.first_wagon_0836
      if wagon and wagon.phase=="native-paid-wagon-verified" then
        local reverse=m.return_locomotive_0836
        if not(reverse and reverse.phase=="native-paid-return-locomotive-verified")then
          return M.service_return_locomotive_0836(pair)
        end
        local fuel=m.first_fuel_0836
        if fuel and fuel.phase=="native-paid-locomotive-fueled" then
          local stop=m.first_stop_0836
          if not(stop and stop.phase=="native-paid-original-train-stop-verified")then
            return M.service_first_train_stop_0836(pair)
          end
          local far=m.remote_stop_0836
          if not(far and far.phase=="native-paid-original-train-stop-verified")then
            return M.service_first_train_stop_0836(pair,"remote")
          end
          -- A recorded remote stop is not a durable connection guarantee:
          -- revalidate it natively before every boarding/departure pulse.
          M.service_first_train_stop_0836(pair,"remote")
          if far.phase~="native-paid-original-train-stop-verified"then
            return false,far.blocker or "original-remote-stop-lost"
          end
          local boarded=m.first_board_0836
          if boarded and boarded.phase=="native-original-magos-boarded"then
            local outward=m.first_outbound_0836
            if outward and outward.phase==
                "native-original-outbound-arrived-at-paid-remote-stop"then
              return M.service_first_train_return_0836(pair)
            end
            return M.service_first_train_outbound_0836(pair)
          end
          return M.service_first_train_board_0836(pair)
        end
        return M.service_first_train_fuel_0836(pair)
      end
      return M.service_first_wagon_0836(pair)
    end
    return M.service_first_locomotive_0836(pair)
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
  -- The 0469 queue alone can recognize an uncommitted, source-less
  -- automatic emergency order. Preserve it unchanged while the EXISTING
  -- 0510->0338 physical dispatcher receives the original pending rail.
  -- Any live task, movement, cargo or nonmatching request still blocks.
  local order_authority=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
  local yielding=false
  -- Ask the original 0469 owner for read-only permission even between
  -- completed rails. This does not cancel an ammo order: it admits only a
  -- genuine next 0836 planning writ with no current physical duty/cargo.
  if order_authority
    and type(order_authority.can_yield_uncommitted_rail_0836)=="function"then
    local original_request=pending and pending.request or nil
    local ok,allowed=pcall(
      order_authority.can_yield_uncommitted_rail_0836,pair,original_request)
    yielding=ok and allowed==true
    if yielding and not pair.rail_order_yield_observed_0836 then
      pair.rail_order_yield_observed_0836={
        -- A read-only 0469 yield is legal BETWEEN paid rails, where no
        -- pending request exists. Never index a nil pending receipt: this
        -- otherwise aborts the original 0836 broker service before rail N+1.
        tick=now(),request_segment=pending and pending.segment or nil,
        kind="uncommitted-automatic-ammo",queue_owner="0469",
      }
    end
  end
  local incumbent=pair.active_task or pair.current_task
    or (not yielding and (pair.active_order_0469
      or (pair.order_queue_0469 and pair.order_queue_0469.current)))
    or pair.active_acquisition_0333 or pair.direct_acquisition_task_0336
    or pair.direct_acquisition_custody_0513
    or pair.machine_logistics_custody_0528
    or pair.inventory_transfer_custody_0687
    or pair.construction_task_0340
    or (task and not original_builder)
    or (custody and not original_builder)
  if incumbent and not original_builder then
    -- Identify the actual live authority rejecting the next original
    -- writ, rather than blaming a historical 0338 candidate refusal.
    -- Observation only: no order/task, custody or movement is cleared.
    local owner=pair.active_task and "active_task"
      or pair.current_task and "current_task"
      or (not yielding and (pair.active_order_0469
        or (pair.order_queue_0469 and pair.order_queue_0469.current)))
        and "0469-current-order"
      or pair.active_acquisition_0333 and "0333-acquisition"
      or pair.direct_acquisition_task_0336 and "0336-direct-acquisition"
      or pair.direct_acquisition_custody_0513 and "0513-direct-custody"
      or pair.machine_logistics_custody_0528 and "0528-machine-custody"
      or pair.inventory_transfer_custody_0687 and "0687-transfer-custody"
      or pair.construction_task_0340 and "0340-construction-task"
      or task and "0338-other-builder"
      or custody and "0338-other-custody"
      or "unidentified-incumbent"
    local previous=m.last_incumbent_refusal_0836
    if not previous or previous.reason~=owner
        or now()-(tonumber(previous.tick)or 0)>=600 then
      m.last_incumbent_refusal_0836={
        tick=now(),reason=owner,pending=pending~=nil,yielding=yielding}
    end
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
    -- The unadmitted original rail's deadline must still be serviced
    -- if an unrelated Magos task acquires custody after planning. Read and
    -- refuse that stale original writ without touching live physical duty.
    if pending and not original_builder then
      -- Preserve the unrelated builder or its item custody, but enforce
      -- the original, unadmitted railway request's finite waiting bound.
      local _,why=M.verify_pending(pair)
      if m.status=="rail-track-blocked" then return false,why end
    end
    return false,"original-magos-incumbent-duty"
  end
  if m.pending_rail_0836 then
    local done,why=M.verify_pending(pair)
    if m.status=="rail-track-blocked" then return false,why end
    if not done then return true,why end
  end
  local planned,reason=M.plan_next(pair)
  -- One bounded, save-safe observation of the LIVE planning decision.
  -- Do not infer admission from an old prewrite refusal, or alter any
  -- construction, movement, queue or material ownership here.
  local prior_plan=m.last_plan_trace_0836
  if not prior_plan or prior_plan.reason~=tostring(reason)
      or now()-(tonumber(prior_plan.tick)or 0)>=600 then
    m.last_plan_trace_0836={
      tick=now(),reason=tostring(reason),planned=planned==true,
      segment=m.rail_frontier_0836 and m.rail_frontier_0836.segment,
      pending=m.pending_rail_0836~=nil,
      request=pair.construction_request~=nil,
      candidate=pair.construction_candidate_0338
        and pair.construction_candidate_0338.item_name,
    }
  end
  if planned~=true then
    -- A nil/pending-free construction gap previously vanished from the
    -- diagnostic trail because 0510 logs only admitted pending requests.
    -- Retain one bounded scalar refusal from the original 0836/0338 owner;
    -- no item, candidate, task, queue or physical acceptance is modified.
    local previous=m.last_prewrite_refusal_0836
    local refusal=tostring(reason)
    if not previous or previous.reason~=refusal
        or now()-(tonumber(previous.tick)or 0)>=600 then
      m.last_prewrite_refusal_0836={
        tick=now(),reason=refusal,
        segment=m.rail_frontier_0836 and m.rail_frontier_0836.segment,
      }
    end
  end
  return planned,reason
end
_G.TechPriestsRailTrackFrontier0836=M
return M
