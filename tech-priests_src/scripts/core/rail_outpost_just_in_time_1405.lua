-- 1405: one physical outpost object of planning intent at a time.
-- This module NEVER creates ghosts, submits 0338 construction requests,
-- moves priests, consumes inventory, or certifies a train route.
local M={version="0.1.676.1405",read_only=true,rethink_ticks=60}
local stages={
  {key="outpost-stop",name="train-stop",count="loading_train_stops"},
  {key="command-anchor",name="senior-cogitator-station",count="remote_cogitator_stations"},
  {key="power-link",name="medium-electric-pole",dynamic=true},
  {key="drills",name="burner-mining-drill",count="drills"},
  {key="ore-belts",name="transport-belt",dynamic=true},
  {key="loading-buffers",name="steel-chest",count="loading_buffer_chests"},
  {key="feeder-inserters",name="inserter",count="feed_inserters"},
  {key="load-inserters",name="inserter",count="loading_inserters"},
  {key="cargo-wagons",name="cargo-wagon",count="cargo_wagons"},
  {key="home-unloaders",name="inserter",count="home_unloading_inserters"},
}
M.stage_count=#stages
local function integer(n,minimum,maximum)
  return type(n)=="number"and n==n and n==math.floor(n)
    and n>=minimum and n<=maximum
end
local function point(p)
  return type(p)=="table" and type(p.x)=="number"
    and type(p.y)=="number" and p.x==p.x and p.y==p.y
    and math.abs(p.x)<1000000 and math.abs(p.y)<1000000
end
local function fail(why)return nil,why end
local function get_state(mission)
  local state=mission.outpost_jit_1405
  if type(state)~="table"then
    state={stage=1,accepted_count=0,accepted_units={},
      ticket=nil,last_world_revision=0,next_think_tick=0}
    mission.outpost_jit_1405=state
  end
  return state
end
function M.current_stage(mission)
  local s=mission and mission.outpost_jit_1405
  return stages[s and s.stage or 1]
end

-- The role observer must pass the *actual* Factorio LuaEntity.  A ghost,
-- blueprint preview, cached name, foreign entity or duplicate item is NOT
-- proof. The caller still owns exact role/connection preflight and station
-- hierarchy; physical existence does not imply working material flow.
local function native_object(mission,stage,observation,state)
  local role=observation and observation.native_role
  local entity=observation and observation.native_entity
  if not(role==stage.key and observation.role_verified==true
    and entity and entity.valid==true and entity.name==stage.name
    and integer(entity.unit_number,1,9007199254740991)
    and entity.force and entity.force.index==mission.force_index
    and entity.surface and entity.surface.index==mission.surface_index
    and point(entity.position)
    and not state.accepted_units[entity.unit_number])then return nil end
  -- A real home-unloading interface belongs to the home area, not ore;
  -- its exact native coverage must be confirmed by the caller. All other
  -- outpost objects must be within a conservative local work envelope.
  if stage.key~="home-unloaders" then
    if not point(mission.target)then return nil end
    local dx=entity.position.x-mission.target.x
    local dy=entity.position.y-mission.target.y
    if dx*dx+dy*dy>96*96 then return nil end
  end
  return entity
end

-- One call may recognize ONE physical object, finish ONE stage, or issue
-- ONE virtual candidate. It cannot perform two of those transitions.
-- No tick-driven replanning while an object is pending. Only an actual
-- native completion/adoption or relevant world revision changes the state.
function M.next(mission,layout,observation,tick)
  if type(mission)~="table" or type(layout)~="table"
    or not(integer(mission.root_station_unit,1,9007199254740991)
      and integer(mission.force_index,1,1000000)
      and integer(mission.surface_index,1,1000000)
      and point(mission.target))
    or layout.read_only~=true
    or layout.construction_authorized~=false
    or not(type(layout.counts)=="table")
    or not(integer(tick,0,9007199254740991))then
    return fail("invalid-original-rail-outpost-plan")
  end
  if type(observation)~="table" then
    return fail("missing-current-world-observation")
  end
  local revision=observation.world_revision
  if not integer(revision,0,9007199254740991)then
    return fail("invalid-world-revision")
  end
  local state=get_state(mission)
  if not integer(state.stage,1,#stages+1)then
    return fail("invalid-staged-outpost-cursor")
  end
  local stage=stages[state.stage]
  if not stage then return nil,"awaiting-real-outpost-commissioning"end
  local goal=stage.dynamic and observation.stage_required_objects
    or layout.counts[stage.count]
  if not integer(goal,1,512)then
    return fail(stage.dynamic and "native-stage-geometry-unresolved"
      or "unmeasured-outpost-stage-quantity")
  end
  local entity=native_object(mission,stage,observation,state)
  if entity then
    -- Accept an alternative correctly verified player-built position just
    -- as we would a priest-built one. Do not destroy/rebuild or credit stock.
    state.accepted_units[entity.unit_number]=true
    state.accepted_count=state.accepted_count+1
    state.ticket=nil
    state.last_world_revision=revision
    state.next_think_tick=tick+M.rethink_ticks
    state.last_native_unit=entity.unit_number
    state.last_adopted_role=stage.key
    return nil,"native-object-accepted-rethink-after-interval"
  end
  if state.accepted_count>=goal then
    if state.ticket then return nil,"pending-object-ownership-unresolved"end
    state.stage=state.stage+1
    state.accepted_count=0
    state.accepted_units={}
    state.last_world_revision=revision
    state.next_think_tick=tick+M.rethink_ticks
    return nil,"stage-finished-reinspect-next-interval"
  end
  if state.ticket then
    if revision>state.last_world_revision then
      -- Never retract an admitted 0338 carrier or physical reservation
      -- merely because a player placed something else on the map.
      if observation.physical_custody_active==true then
        return nil,"physical-item-custody-preserved"
      end
      state.ticket=nil
      state.last_world_revision=revision
      state.next_think_tick=tick+M.rethink_ticks
      return nil,"changed-world-invalidated-uncommitted-intent"
    end
    return nil,"awaiting-one-original-object"
  end
  if tick<(tonumber(state.next_think_tick)or 0) then
    return nil,"planning-interval-not-due"
  end
  local candidate=observation.candidate
  if not(type(candidate)=="table" and candidate.role==stage.key
    and candidate.entity_name==stage.name
    and point(candidate.position)
    and candidate.native_site_verified==true
    and candidate.real_item_available==true)then
    return nil,"waiting-native-next-object-preflight"
  end
  local request={
    stage=state.stage,role=stage.key,entity_name=stage.name,
    position={x=candidate.position.x,y=candidate.position.y},
    direction=candidate.direction,
    world_revision=revision,created_tick=tick,
    item=candidate.item_name or stage.name,
    physical_build_authorized=false,
    read_only=true,construction_ghosts=0,
  }
  state.ticket=request
  state.last_world_revision=revision
  state.last_intent_tick=tick
  return request,"one-virtual-object-proposed"
end
return M
