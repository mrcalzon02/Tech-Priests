-- Remote rail outposts: first autonomous strategic gate (0835).
-- Detect physical local ore starvation, confirmed remote ore and real rail
-- supplies. This module only publishes a durable objective; it does not
-- synthesize rails, train movement, inventory or a station at the destination.
local Frontier=require("scripts.core.rail_track_frontier_0836")
local OutpostLayout1404=require("scripts.core.rail_outpost_layout_1404")
local JustInTime1405=require("scripts.core.rail_outpost_just_in_time_1405")
local M={version="0.1.676.0835",scan_interval=900,
  local_radius=64,remote_min=192,remote_max=1024,
  stock_floor=4,resource_item="iron-ore",
  storage_key="remote_rail_outpost_0835"}
local function tick() return game and game.tick or 0 end
local function valid(e) return e and e.valid==true end
local function dist2(a,b)
  local x=a.x-b.x;local y=a.y-b.y
  return x*x+y*y
end
local function stock(inv,item)
  if not(inv and inv.valid) then return 0 end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and math.max(0,tonumber(n) or 0) or 0
end
local function count(pair,item)
  local authority=rawget(_G,"TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
  if authority and type(authority.generic_item_count)=="function" then
    local ok,n=pcall(authority.generic_item_count,pair,item)
    if ok and type(n)=="number" and n>=0 then return n end
  end
  local ok,inv=pcall(function()
    return pair.station.get_inventory(defines.inventory.chest)
  end)
  return ok and stock(inv,item) or 0
end
local function charted(force,surface,pos)
  if not (force and force.is_chunk_charted) then return false end
  local ok,yes=pcall(function()
    return force.is_chunk_charted(surface,{
      x=math.floor(pos.x/32),y=math.floor(pos.y/32)})
  end)
  return ok and yes==true
end
-- The existing scan router is the only authoritative world reader.
-- Fail CLOSED if it is unavailable: never declare starvation from a missing
-- scan, or add new unbudgeted world-scan sites to the UPS-critical dispatcher.
local function scan_resources(surface,filters)
  local routing=rawget(_G,"TechPriestsScanRouting0610")
  if not (routing and type(routing.find_entities)=="function") then
    return nil,"canonical-scan-unavailable"
  end
  local ok,entities=pcall(routing.find_entities,surface,filters,{
    category="resource",limit=filters.limit,record_negative=false})
  if not ok or type(entities)~="table" then
    return nil,"canonical-resource-scan-failed"
  end
  return entities
end
local function ore_near(surface,item,pos,radius)
  local found,why=scan_resources(surface,{
    type="resource",name=item,position=pos,radius=radius,limit=1})
  if not found then return nil,why end
  local e=found[1]
  return e and e.valid and (tonumber(e.amount) or 0)>0 or false
end
local REQUIRED={
  rail=64,locomotive=1,["cargo-wagon"]=1,coal=20,
  ["burner-mining-drill"]=1,["train-stop"]=2
}
function M.assess(pair)
  if not(valid(pair and pair.station) and valid(pair.priest)
      and pair.station.name=="planetary-magos-cogitator-station") then
    return nil,"not-live-planetary-magos"
  end
  local surface,force=pair.station.surface,pair.station.force
  if not(surface and force and force.technologies
    and force.technologies["railway"]
    and force.technologies["railway"].researched
    and force.technologies["automated-rail-transportation"]
    and force.technologies["automated-rail-transportation"].researched) then
    return nil,"railway-technology-locked"
  end
  local item=M.resource_item
  local available=count(pair,item)
  if available>=M.stock_floor then return nil,"stock-available" end
  local nearby,scan_reason=ore_near(
    surface,item,pair.station.position,M.local_radius)
  if nearby==nil then return nil,scan_reason end
  if nearby then return nil,"local-patch-available" end
  for name,minimum in pairs(REQUIRED) do
    if count(pair,name)<minimum then
      return nil,"missing-physical-rail-supplies:"..name
    end
  end
  -- The current 0836 constructor only builds a straight eastbound railway.
  -- Bound discovery to that physically buildable corridor; otherwise the
  -- nearest charted ore can create a permanently unbuildable rail mission.
  -- Share the construction owner's exact lateral constraint and keep
  -- canonical, budget-limited scans. No terrain or items are fabricated.
  local at=pair.station.position
  local lateral=Frontier.max_lateral_error
  local offset=Frontier.start_offset
  local step=Frontier.segment_step
  local capacity=Frontier.max_segments
  local clearance=Frontier.destination_clearance
  if type(lateral)~="number" or lateral<0
      or type(offset)~="number" or offset<0
      or type(step)~="number" or step<=0
      or type(capacity)~="number" or capacity<1
      or type(clearance)~="number" or clearance<0 then
    return nil,"rail-corridor-geometry-unavailable"
  end
  -- 0836 stops after its MAXIMUM counted builder segments. A farther
  -- charted patch must not steal a mission that cannot ever reach it.
  -- Only an ACTUALLY CREDITED last rail can complete the frontier.
  -- Do not include a future unbuilt candidate in the reachable bound.
  local reachable=offset+(capacity-1)*step+clearance
  local max_target=math.min(M.remote_max,reachable)
  if max_target<M.remote_min then
    return nil,"rail-corridor-geometry-unavailable"
  end
  local resources,why=scan_resources(surface,{
    type="resource",name=item,
    area={{at.x+M.remote_min,at.y-lateral},
          {at.x+max_target,at.y+lateral}},limit=512})
  if not resources then return nil,why end
  local best,best_distance
  for _,entity in pairs(resources) do
    if valid(entity) and (tonumber(entity.amount) or 0)>0
        and entity.surface==surface then
      local d=dist2(entity.position,at)
      local needed=Frontier.required_segments_for_target(at,entity.position)
      if entity.position.x>=at.x+M.remote_min
          and entity.position.x<=at.x+max_target
          and math.abs(entity.position.y-at.y)<=lateral
          and d>=M.remote_min*M.remote_min
          and d<=max_target*max_target
          and charted(force,surface,entity.position)
          and needed and needed<=capacity
          and (not best_distance or d<best_distance) then
        best=entity;best_distance=d
      end
    end
  end
  if not best then return nil,"no-charted-rail-corridor-ore" end
  -- The 64-item initial-readiness floor cannot supply the entire line:
  -- the closest admissible patch (192 east) needs 83 real rail items.
  -- The shared 0836 geometry accounts for BOTH east and lateral distance;
  -- a charted diagonal ore patch cannot steal an impossible rail mission.
  -- 0338 still owns and removes every actual item, one by one.
  local needed_segments=Frontier.required_segments_for_target(
    at,best.position)
  if not needed_segments or needed_segments>capacity then
    return nil,"rail-destination-exceeds-segment-capacity"
  end
  if count(pair,"rail")<needed_segments then
    return nil,"insufficient-physical-rails-to-reach-ore"
  end
  return {item=item,position={x=best.position.x,y=best.position.y},
    resource_unit=best.unit_number,resource_name=best.name,
    distance=math.sqrt(best_distance),
    station_unit=pair.station.unit_number,
    station_surface=surface.index,force_index=force.index,
    observed_stock=available},"starved-charted-patch"
end
function M.observe_pair(pair)
  if not(valid(pair and pair.station) and valid(pair.priest)) then
    return false,"invalid-pair"
  end
  if pair.station.name~="planetary-magos-cogitator-station" then
    return false,"not-root-rank"
  end
  local last=pair.remote_rail_outpost_probe_0835 or 0
  if tick()<last+M.scan_interval then return false,"interval" end
  pair.remote_rail_outpost_probe_0835=tick()
  local result,why=M.assess(pair)
  pair.remote_rail_outpost_diagnosis_0835={tick=tick(),reason=why,
    local_ore_stock=result and result.observed_stock}
  if not result then return false,why end
  local objective=pair.remote_rail_outpost_0835
  if objective and objective.status~="cancelled"
      and objective.status~="completed" then
    -- Do not reissue or redirect a live train/track mission every scan.
    objective.last_observed_tick=tick()
    return false,"mission-already-owned"
  end
  pair.remote_rail_outpost_0835={
    version=M.version,status="starvation-confirmed",
    stage="surveyed-remote-patch",item=result.item,
    target=result.position,resource_name=result.resource_name,
    resource_unit=result.resource_unit,
    distance=result.distance,root_station_unit=result.station_unit,
    surface_index=result.station_surface,force_index=result.force_index,
    initial_stock=result.observed_stock,created_tick=tick(),
    last_observed_tick=tick(),next_step="plan-physical-track-route",
    outpost_layout_status_1404="awaiting-native-throughput-and-site-observations",
    -- Deliberately no created buildings or cargo: independent executors
    -- must debit stocked rail before claiming a constructed track segment.
  }
  if log then log("[Tech-Priests rail-0835] resource-starved station="..
    tostring(result.station_unit).." item="..result.item..
    " charted_target="..result.position.x..","..result.position.y..
    " distance="..math.floor(result.distance)..
    " next=plan-physical-track-route") end
  return true,"starvation-objective-created"
end
-- The remote station complex has its own read-only engineering plan.
-- The station/Cogitator architect sizes mining/loading; the 0836 planner
-- only draws native track. 0510 -> 0338 is still the SOLE physical builder.
-- Missing native capacity/prototype data fails closed; no stock or ghosts.
function M.propose_outpost_capacity_1404(pair, measurements)
  if not(valid(pair and pair.station) and valid(pair.priest)
    and pair.station.name=="planetary-magos-cogitator-station"
    and pair.priest.force==pair.station.force
    and pair.priest.surface==pair.station.surface
    and storage and storage.tech_priests
    and type(storage.tech_priests.pairs_by_station)=="table"
    and storage.tech_priests.pairs_by_station[pair.station.unit_number]==pair
    and type(measurements)=="table")then
    return nil,"outpost-magos-or-measurements-missing"
  end
  local mission=pair.remote_rail_outpost_0835
  if not(mission and mission.root_station_unit==pair.station.unit_number
    and mission.force_index==pair.station.force.index
    and mission.surface_index==pair.station.surface.index
    and type(mission.target)=="table"
    and type(mission.item)=="string")then
    return nil,"outpost-original-rail-mission-unavailable"
  end
  -- A capacity estimate is a planning *input*, not a repeated work order.
  -- While exactly one object is pending, do not run any new sizing scan.
  -- Relevant world changes become a dirty flag until current custody ends.
  local stored=mission.outpost_layout_1404
  local revision=measurements.observation_revision
  if revision~=nil and (type(revision)~="number"
      or revision<0 or revision~=math.floor(revision))then
    return nil,"invalid-capacity-observation-revision"
  end
  local prior=mission.outpost_layout_revision_1404 or 0
  local changed=revision~=nil and revision>prior
  local pending=mission.outpost_jit_1405
    and mission.outpost_jit_1405.ticket
  if stored and (pending or pair.construction_task_0338
      or pair.construction_custody_0338)then
    if changed then mission.outpost_capacity_dirty_1404=true end
    return stored,"current-physical-object-must-finish"
  end
  if stored and not changed and not mission.outpost_capacity_dirty_1404 then
    return stored,"unchanged-capacity-no-recomputation"
  end
  local proto_item=prototypes and prototypes.item
    and prototypes.item[mission.item]
  local entities=prototypes and prototypes.entity
  local cargo=entities and entities["cargo-wagon"]
  local chest_name=measurements.chest_entity_name or "steel-chest"
  local belt_name=measurements.belt_entity_name or "transport-belt"
  local chest=entities and entities[chest_name]
  local belt=entities and entities[belt_name]
  if not(proto_item and cargo and chest and belt
    and defines and defines.inventory
    and defines.inventory.cargo_wagon and defines.inventory.chest
    and cargo.get_inventory_size and chest.get_inventory_size)then
    return nil,"outpost-native-prototypes-unobservable"
  end
  if belt.type~="transport-belt" then
    return nil,"outpost-belt-prototype-not-transport-belt"
  end
  local wagon_ok,slots=pcall(function()
    return cargo.get_inventory_size(defines.inventory.cargo_wagon)end)
  local chest_ok,buffer_slots=pcall(function()
    return chest.get_inventory_size(defines.inventory.chest)end)
  local stack=tonumber(proto_item.stack_size)
  local native_belt_speed=tonumber(belt.belt_speed)
  if not(wagon_ok and chest_ok
    and type(slots)=="number"and slots>0
    and type(buffer_slots)=="number"and buffer_slots>0
    and type(stack)=="number"and stack>0
    and type(native_belt_speed)=="number"
    and native_belt_speed>0)then
    return nil,"outpost-native-capacity-readback-invalid"
  end
  -- This vanilla unstacked belt throughput (2 lanes*4 items/tile*
  -- 60 ticks/sec) is a CAPACITY ESTIMATE, not measured item delivery.
  -- Actual inserter transfer and drill rates MUST be supplied as
  -- measured or conservative forecasts; we never invent them here.
  local requested={
    item=mission.item,item_type="item",
    item_stack_size=stack,wagon_slots=slots,chest_slots=buffer_slots,
    belt_items_per_second=native_belt_speed*480,
    demand_items_per_second=measurements.demand_items_per_second,
    drill_items_per_second=measurements.drill_items_per_second,
    ore_drill_sites=measurements.ore_drill_sites,
    train_travel_seconds=measurements.train_travel_seconds,
    loading_seconds=measurements.loading_seconds,
    unloading_seconds=measurements.unloading_seconds,
    inserter_items_per_second=measurements.inserter_items_per_second,
    train_direction_policy=measurements.train_direction_policy,
    max_wagons=measurements.max_wagons,
    max_loaders_per_wagon=measurements.max_loaders_per_wagon,
    max_chests_per_wagon=measurements.max_chests_per_wagon,
    max_train_vehicles=measurements.max_train_vehicles,
    reserve_factor=measurements.reserve_factor,
    transfer_efficiency=measurements.transfer_efficiency,
  }
  local plan,why=OutpostLayout1404.plan(requested)
  if not plan then
    mission.outpost_layout_refusal_1404={tick=tick(),reason=why}
    mission.outpost_layout_status_1404="capacity-layout-blocked"
    return nil,why
  end
  plan.root_station_unit=mission.root_station_unit
  plan.surface_index=mission.surface_index
  plan.force_index=mission.force_index
  plan.destination={x=mission.target.x,y=mission.target.y}
  plan.belt_entity_name=belt_name
  plan.chest_entity_name=chest_name
  plan.metric_authority="supplied-capacity-estimates-native-prototypes-only"
  plan.rail_construction_plan_owner="rail-track-frontier-0836"
  plan.outpost_build_authority="existing-0510-0338-only"
  -- One bounded primitive snapshot per mission. It is NOT a progress
  -- receipt: railway and outpost physical commissioning remain unverified.
  mission.outpost_layout_1404=plan
  mission.outpost_layout_revision_1404=revision or prior
  mission.outpost_capacity_dirty_1404=nil
  mission.outpost_layout_status_1404="provisional-capacity-layout"
  mission.outpost_layout_refusal_1404=nil
  return plan,why
end

-- Just-in-time outpost planning. An exact original mission, a usable
-- capacity estimate, and one native site candidate are necessary to offer
-- ONE non-physical object intent. No pending ghost or item may be created.
function M.propose_next_outpost_object_1405(pair,observation)
  if not(valid(pair and pair.station) and valid(pair.priest)
    and pair.station.name=="planetary-magos-cogitator-station"
    and pair.priest.force==pair.station.force
    and pair.priest.surface==pair.station.surface
    and storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station
    and storage.tech_priests.pairs_by_station[pair.station.unit_number]==pair
    and type(observation)=="table")then
    return nil,"outpost-planner-unregistered-magos"
  end
  local mission=pair.remote_rail_outpost_0835
  if not(mission and mission.root_station_unit==pair.station.unit_number
    and mission.force_index==pair.station.force.index
    and mission.surface_index==pair.station.surface.index
    and mission.status=="rail-track-established"
    and mission.outpost_layout_1404)then
    return nil,"outpost-planning-awaiting-physical-rail-and-capacity"
  end
  local current=JustInTime1405.current_stage(mission)
  local given=observation.native_entity
  local state=mission.outpost_jit_1405
  -- Revisit a single stage only on an explicit request, and only when
  -- no original ticket is waiting or material is carried. This picks up
  -- previously player-built infrastructure at the next relevant stage.
  -- Never scan 10 future construction stages or the entire map.
  if not given and observation.reinspect_stage==true and current
    and not(state and state.ticket)
    and not(pair.construction_task_0338 or pair.construction_custody_0338)
    and tick()>=(state and state.next_think_tick or 0)then
    local center=current.key=="home-unloaders"
      and pair.station.position or mission.target
    local radius=current.key=="home-unloaders" and 64 or 96
    local ok,observed=pcall(function()
      return pair.station.surface.find_entities_filtered{
        name=current.name,force=pair.station.force,
        position=center,radius=radius,limit=8}end)
    if ok and type(observed)=="table"then
      for _,candidate in ipairs(observed)do
        if candidate.valid and candidate.unit_number
          and not(state and state.accepted_units
            and state.accepted_units[candidate.unit_number])then
          given=candidate;break
        end
      end
    end
  end
  local verified=false
  if given and current and given.valid and given.name==current.name
    and given.force==pair.station.force
    and given.surface==pair.station.surface
    and given.position then
    -- Do not count an arbitrary claimant or a ghost with matching name.
    -- Re-query ONE exact native location, only on a material completion
    -- event or explicitly supplied observation (not on every broker tick).
    local ok,found=pcall(function()
      return pair.station.surface.find_entities_filtered{
        name=given.name,position=given.position,
        force=pair.station.force,radius=0.3,limit=4}
    end)
    if ok and type(found)=="table"then
      for _,entity in ipairs(found)do
        if entity==given and entity.unit_number==given.unit_number then
          verified=true;break
        end
      end
    end
    if verified and current.key=="outpost-stop" then
      local rail=given.connected_rail
      verified=rail and rail.valid and rail.force==given.force
        and rail.surface==given.surface or false
    elseif verified and current.key=="command-anchor"then
      local child=storage.tech_priests.pairs_by_station[given.unit_number]
      verified=child and child.station==given and valid(child.priest)
        or false
    elseif verified and current.key=="cargo-wagons"then
      verified=given.train and given.train.valid or false
    end
  end
  local candidate=observation.candidate
  local prepared=nil
  if candidate and current and not(state and state.ticket)then
    local proto=prototypes and prototypes.item
      and prototypes.item[candidate.item_name or current.name]
    local named=proto and proto.place_result
    local native_name=named and named.name
    local point=candidate.position
    if candidate.role==current.key
      and candidate.entity_name==current.name
      and native_name==current.name
      and point and type(point.x)=="number"
      and type(point.y)=="number"then
      local clear,allowed=pcall(function()
        return pair.station.surface.can_place_entity{
          name=current.name,position=point,
          direction=candidate.direction or 0,
          force=pair.station.force}
      end)
      if clear and allowed==true then
        local stock=rawget(_G,"TechPriestsStorageRoleAuthority0686")
        local counted,available=false,0
        if stock and type(stock.generic_item_count)=="function"then
          counted,available=pcall(stock.generic_item_count,pair,
            candidate.item_name or current.name)
        end
        prepared={
          role=current.key,entity_name=current.name,
          item_name=candidate.item_name or current.name,
          position={x=point.x,y=point.y},
          direction=candidate.direction,
          native_site_verified=true,
          real_item_available=counted and
            type(available)=="number" and available>=1,
        }
      end
    end
  end
  -- Every cycle sees the current mission's revision, not an external
  -- caller-provided optimistic revision. A built object can be adopted at
  -- an alternative valid native site without invalidating real cargo.
  return JustInTime1405.next(mission,mission.outpost_layout_1404,{
    world_revision=mission.outpost_world_revision_1405 or 0,
    stage_required_objects=observation.stage_required_objects,
    native_role=current and current.key,
    native_entity=verified and given or nil,
    role_verified=verified==true,
    physical_custody_active=pair.construction_custody_0338~=nil
      or pair.construction_task_0338~=nil,
    candidate=prepared,
  },tick())
end

-- Player and robot construction changes invalidate virtual intent by event.
-- This is O(registered Magos) only at a physical mutation, NEVER a tick scan.
-- A changed site cannot erase another executor's physical item custody.
function M.observe_relevant_world_change_1405(event)
  local entity=event and (event.created_entity or event.entity
    or event.destination)
  local tp=storage and storage.tech_priests
  if not(entity and entity.position and entity.force and entity.surface
    and tp and tp.pairs_by_station
    and type(entity.position.x)=="number"
    and type(entity.position.y)=="number")then return 0 end
  if entity.name=="entity-ghost" then return 0 end
  local count=0
  for _,pair in pairs(tp.pairs_by_station)do
    local mission=pair and pair.remote_rail_outpost_0835
    if mission and mission.outpost_layout_1404
      and valid(pair.station) and valid(pair.priest)
      and pair.station.name=="planetary-magos-cogitator-station"
      and mission.root_station_unit==pair.station.unit_number
      and mission.status=="rail-track-established"
      and pair.station.force==entity.force
      and pair.station.surface==entity.surface
      and mission.force_index==entity.force.index
      and mission.surface_index==entity.surface.index then
      local target=mission.target
      local dx=target.x-entity.position.x
      local dy=target.y-entity.position.y
      local stage=JustInTime1405.current_stage(mission)
      local near_outpost=dx*dx+dy*dy<=96*96
      local pending=mission.outpost_jit_1405
        and mission.outpost_jit_1405.ticket
      local close_ticket=pending and
        (pending.position.x-entity.position.x)^2
        +(pending.position.y-entity.position.y)^2<=16*16
      local near_home=stage and stage.key=="home-unloaders"
        and (pair.station.position.x-entity.position.x)^2
          +(pair.station.position.y-entity.position.y)^2<=64*64
      if near_outpost or close_ticket or near_home then
        local active_cargo=pair.construction_custody_0338~=nil
          or pair.construction_task_0338~=nil
        if entity.valid==false and entity.unit_number then
          local removed=JustInTime1405.native_removed(mission,
            entity.unit_number,tick(),active_cargo)
          if removed then
            mission.outpost_world_revision_1405=
              (mission.outpost_world_revision_1405 or 0)+1
            count=count+1
          end
        end
        local interested=stage and entity.name==stage.name
        if interested or close_ticket then
          mission.outpost_world_revision_1405=
            (mission.outpost_world_revision_1405 or 0)+1
          count=count+1
          if entity.valid then
            -- Existing native callback only; never create a ghost or a
            -- replacement construction request in the event handler.
            M.propose_next_outpost_object_1405(pair,{
              native_entity=entity})
          elseif entity.unit_number then
            JustInTime1405.native_removed(mission,entity.unit_number,
              tick(),pair.construction_custody_0338~=nil
                or pair.construction_task_0338~=nil)
          end
        end
      end
    end
  end
  return count
end

-- Run the existing strategic observer and existing 0338 rail constructor
-- through the canonical budgeted broker.  No new on_tick handler or
-- independent movement/inventory owner is installed.
function M.service_pair(pair)
  if not(valid(pair and pair.station) and valid(pair.priest)
      and pair.station.name=="planetary-magos-cogitator-station") then
    return false,"not-live-planetary-magos"
  end
  local mission=pair.remote_rail_outpost_0835
  if not mission then
    local created,why=M.observe_pair(pair)
    if not created then return false,why end
    mission=pair.remote_rail_outpost_0835
  end
  if not mission or (mission.status~="starvation-confirmed"
      and mission.status~="building-physical-rail") then
    return false,"no-active-physical-rail-stage"
  end
  return Frontier.service_pair(pair)
end
function M.service_budgeted(_,budget)
  local tp=storage and storage.tech_priests
  if not tp then return {processed=0,acted=0,detail="no-tech-priests"} end
  local list={}
  for id,pair in pairs(tp.pairs_by_station or {}) do
    if valid(pair and pair.station) and valid(pair.priest)
        and pair.station.name=="planetary-magos-cogitator-station"
        and pair.station.unit_number==id then
      list[#list+1]={id=id,pair=pair}
    end
  end
  table.sort(list,function(a,b)return a.id<b.id end)
  if #list==0 then return {processed=0,acted=0,detail="no-magos"} end
  local state=tp.remote_rail_broker_0835 or {cursor=0}
  tp.remote_rail_broker_0835=state
  local count=math.min(#list,math.max(0,math.floor(tonumber(budget)or 2)))
  if count==0 then return {processed=0,acted=0,detail="zero-budget"} end
  local start=(state.cursor%#list)+1
  local changed,errors=0,0
  for i=0,count-1 do
    local pair=list[((start+i-1)%#list)+1].pair
    local ok,advanced=pcall(M.service_pair,pair)
    if not ok then errors=errors+1
    elseif advanced==true then changed=changed+1 end
  end
  state.cursor=(start+count-1)%#list
  -- "acted" is reserved for genuine completed physical work: observing or
  -- requesting a rail segment is NOT a completed build or delivery.
  return {processed=count,acted=0,failed=errors,
    exhausted=#list>count,detail="missions-or-pending-requests="..changed}
end
local function install_native_outpost_invalidation_1405()
  if not(script and type(script.on_event)=="function")then
    return true -- Unit fixtures without Factorio event APIs.
  end
  local ev=defines and defines.events
  if not ev then return false end
  local ok,registry=pcall(require,"scripts.core.runtime_event_registry")
  if not(ok and registry and type(registry.on_event)=="function")
    then return false end
  for _,name in ipairs({
    "on_built_entity","on_robot_built_entity","script_raised_built",
    "on_player_mined_entity","on_robot_mined_entity",
    "on_entity_died","script_raised_destroy",
  })do
    local id=ev[name]
    if id then
      local called,route=pcall(registry.on_event,id,function(event)
        -- Destroyed entities can become invalid during engine callbacks;
        -- never let a notification exception abort another owner's work.
        local processed,reason=pcall(M.observe_relevant_world_change_1405,
          event)
        if not processed and log then
          log("[Tech-Priests 1405] native outpost invalidation: "..
            tostring(reason))
        end
      end,nil,{owner="remote-rail-outpost-0835",
        route="outpost-physical-change-1405:"..name,priority=84})
      if not(called and route~=nil and route~=false)then return false end
    end
  end
  return true
end
function M.install()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not(broker and type(broker.register_service)=="function") then
    return false,"canonical-runtime-broker-unavailable"
  end
  local registered=broker.register_service{
    name="remote_rail_outpost_0835",category="construction",
    interval=115,priority=57,budget=2,
    note="charted Magos starvation and counted 0338 physical rail requests only",
    fn=M.service_budgeted}
  if not registered then return false,"rail-discovery-broker-registration-failed" end
  if not install_native_outpost_invalidation_1405()then
    return false,"rail-outpost-native-change-route-unavailable"
  end
  return true
end
_G.TechPriestsRemoteRailOutpost0835=M
return M
