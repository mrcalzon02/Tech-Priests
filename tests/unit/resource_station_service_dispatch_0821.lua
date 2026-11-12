-- Regression: a real known-resource relay must advance from the Magos'
-- installed emergency-service wrapper even during the discovery cooldown.
-- All station records are physical-executor fixtures; no free items or ore.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Chain=require("scripts.core.resource_station_chain_0820")
game={tick=100}
local force={name="player"}
local surface={index=1}
local function pair(id,x,rank)
  return {
    station={valid=true,unit_number=id,position={x=x,y=0},
      force=force,surface=surface,name="station-"..rank},
    priest={valid=true,position={x=x,y=0}},
    rank_test=rank,radius=30,
  }
end
local magos=pair(100,0,4)
storage={tech_priests={
  pairs_by_station={[100]=magos},
  station_expansion_0256={},
  station_expansion_next_id_0256=1,
}}
tech_priests_0252_rank_number=function(p)return p.rank_test end
tech_priests_0255_pair_is_magos_planner=function(p)return p==magos end
TECH_PRIESTS_COMMAND_HIERARCHY_0480={
  rank=function(p)return p.rank_test end,
  direct_capacity_remaining=function()return 1 end,
  is_direct_subordinate=function(parent,child)
    return parent.rank_test==child.rank_test+1
  end,
}
local requests={}
TECH_PRIESTS_STATION_EXPANSION_0256={
  request_station_expansion=function(commander,need,_,note,angle)
    assert(need=="resource:iron-ore"
      and note=="ranked-remote-resource-chain"
      and math.abs(angle)<0.01)
    local id=storage.tech_priests.station_expansion_next_id_0256
    storage.tech_priests.station_expansion_next_id_0256=id+1
    local rec={id=id,status="active",phase="awaiting-physical-construction",
      requester_station_unit=commander.station.unit_number,
      blocked_item=need,
      ghost_position={x=commander.station.position.x+27,y=0}}
    storage.tech_priests.station_expansion_0256[id]=rec
    requests[#requests+1]=rec
    return true
  end,
}
local original_calls=0
tech_priests_service_independent_emergency_operation_0184=function()
  original_calls=original_calls+1
  return false
end
assert(Chain.start(magos,"iron-ore",{x=160,y=0},"iron-ore"))
-- Resource discovery is intentionally suppressed for far longer than the
-- five-second relay scheduler: the active chain must still be serviced.
magos.resource_expansion_0259.next_tick=999999
dofile("tech-priests_src/scripts/resource_expansion.lua")
assert(tech_priests_service_independent_emergency_operation_0184(magos)==false)
local mission=Chain.status(magos)
assert(original_calls==1 and #requests==1
  and mission.status=="building-station"
  and mission.pending_expansion_id==1
  and mission.segments==0,
  "emergency wrapper failed to dispatch first physical relay")
game.tick=101
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==1 and mission.pending_expansion_id==1,
  "relay bypassed its own bounded service interval")
-- An expansion record cannot advance the hierarchy until an actual
-- registered subordinate pair exists at the completed physical station.
game.tick=401
requests[1].status="complete"
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==1 and mission.status=="awaiting-new-station-pair",
  "completed station record without a priest was treated as delegated")
storage.tech_priests.pairs_by_station[101]=pair(101,27,3)
game.tick=701
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==2 and mission.segments==1
  and mission.current_station_unit==101
  and requests[2].requester_station_unit==101
  and mission.pending_expansion_id==2
  and magos.resource_expansion_0259.next_tick==999999,
  "Magos did not delegate next physical ghost to newly paired Senior")
-- A blocked mission must remain visible, not silently spawn a replacement.
mission.status="blocked"
game.tick=1001
tech_priests_service_independent_emergency_operation_0184(magos)
assert(#requests==2 and mission.status=="blocked",
  "blocked physical relay was silently replaced")
-- Explicit powered-robot expansion must win over a NEW automatic 0259
-- station chain, but may never cancel an already active physical writ.
local original_is_magos=tech_priests_0255_pair_is_magos_planner
local robot_magos=pair(200,0,4)
tech_priests_0255_pair_is_magos_planner=function(p)
  return p==magos or p==robot_magos
end
robot_magos.roboport_expansion_goal_1076={
  target={x=94,y=0},root_station_unit=200,
  surface_index=surface.index,force_index=force.index}
local count_before=#requests
assert(tech_priests_0259_resource_expansion_service(robot_magos)==false
  and #requests==count_before
  and not Chain.status(robot_magos)
  and robot_magos.resource_expansion_0259.last_reason==
    "explicit-powered-robot-frontier-priority",
  "explicit robot frontier launched a competing unstocked Method I ghost")
magos.roboport_expansion_goal_1076={
  target={x=94,y=0},root_station_unit=100,
  surface_index=surface.index,force_index=force.index}
local preserved=Chain.status(magos)
tech_priests_0259_resource_expansion_service(magos)
assert(Chain.status(magos)==preserved and preserved.status=="blocked"
  and #requests==count_before,
  "new robot intent silently overwrote an existing physical relay writ")
tech_priests_0255_pair_is_magos_planner=original_is_magos
-- An autonomous 0259 deficit may select Method II ONLY when actual native
-- logistic coverage, charting, original Senior rank and one physical robot
-- supplied Intermediate item all exist. No fixture counts as engine proof.
do
  local old_provider=tech_priests_prototype_table_0440
  local old_surface_search=surface.find_entities_filtered
  local old_can_place=surface.can_place_entity
  local old_chart=force.is_chunk_charted
  local old_readiness=_G.TechPriestsRoboportReadiness0714
  local old_frontier=_G.TechPriestsRoboportExpansionFrontier1076
  local native_anchor_ready=true
  local native_preflight_calls=0
  _G.TechPriestsRoboportExpansionFrontier1076={
    native_covered_ore_admission_1076=function(owner,target,site)
      native_preflight_calls=native_preflight_calls+1
      assert(owner and target and site and target.x==65 and site.x==59)
      return native_anchor_ready
    end}
  local old_magos=tech_priests_0255_pair_is_magos_planner
  local old_max_link=TECH_PRIESTS_COMMAND_HIERARCHY_0480.max_link_distance
  local old_force_index=force.index
  local ore={valid=true,type="resource",name="iron-ore",
    amount=2,surface=surface,position={x=65,y=0},
    prototype={mineable_properties={products={
      {type="item",name="iron-ore",amount=1}}}}}
  local native_available,native_stock=2,1
  local net={valid=true,force=force,
    get_item_count=function(item)
      assert(item=="intermediate-cogitator-station")
      return native_stock
    end}
  local cell={valid=true,transmitting=true,logistic_network=net,
    -- Site/ore lie outside orange logistic range but inside green
    -- construction range. Provider stock is still in the real network.
    is_in_logistic_range=function(pos)return pos.x>=0 and pos.x<=40 end,
    is_in_construction_range=function(pos)return pos.x>=0 and pos.x<=90 end}
  local port={valid=true,type="roboport",force=force,surface=surface,
    position={x=15,y=0},energy=1000,logistic_cell=cell,
    is_connected_to_electric_network=function()return true end}
  local auto=pair(300,0,4)
  auto.station.name="planetary-magos-cogitator-station"
  local senior=pair(301,40,3)
  senior.station.name="senior-cogitator-station"
  senior.priest.unit_number=9301
  storage.tech_priests.pairs_by_station[300]=auto
  storage.tech_priests.pairs_by_station[301]=senior
  force.index=1
  net.available_construction_robots=native_available
  net.all_construction_robots=2
  force.is_chunk_charted=function()return true end
  TECH_PRIESTS_COMMAND_HIERARCHY_0480.max_link_distance=90
  tech_priests_prototype_table_0440=function(kind)
    assert(kind=="entity")
    return {["iron-ore"]={type="resource",
      mineable_properties=ore.prototype.mineable_properties}}
  end
  surface.find_entities_filtered=function(spec)
    if spec.name~="iron-ore" then return {} end
    return spec.area and {ore} or {}
  end
  surface.can_place_entity=function(spec)
    return spec.name=="intermediate-cogitator-station"
      and spec.force==force and spec.position.x==59
  end
  _G.TechPriestsRoboportReadiness0714={
    scan_pair=function(p)
      assert(p==auto)
      p.roboport_reports_0714={{entity=port}}
      return true
    end}
  tech_priests_0255_pair_is_magos_planner=function(p)
    return p==auto or old_magos(p)
  end
  -- Runtime regression: native 1380 first saw the natural patch in a
  -- generated but UNCHARTED chunk, reserved a blocked Method I chain,
  -- and could never reconsider the stocked robot route after radar scanning.
  -- An unseen patch may cause honest exploratory intent, never a persistent
  -- known-resource chain or a synthetic robot goal.
  local original_request=TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion
  local exploratory_attempts=0
  TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion=function()
    exploratory_attempts=exploratory_attempts+1
    return false
  end
  local before_unseen=#requests
  force.is_chunk_charted=function()return false end
  game.tick=1200
  assert(tech_priests_0259_resource_expansion_service(auto)==false
    and not Chain.status(auto) and not auto.roboport_expansion_goal_1076
    and #requests==before_unseen and exploratory_attempts>0,
    "uncharted generated ore reserved a persistent ranked relay")
  -- A later genuine radar chart must be visible to the next normal pass;
  -- no injected objective, force.chart or source inventory grant is used.
  force.is_chunk_charted=function()return true end
  TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion=original_request
  game.tick=2401
  assert(cell.is_in_logistic_range(ore.position)==false
    and cell.is_in_construction_range(ore.position)==true,
    "regression fixture did not exercise outer construction-only zone")
  local before=#requests
  local goal=tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore)
  assert(goal and goal.target.x==65
    and goal.remote_station_position_1076.x==59
    and goal.root_station_unit==300
    and goal.remote_resource_item_1076=="iron-ore"
    and not auto.roboport_expansion_goal_1076
    and #requests==before and native_preflight_calls==1,
    "read-only native covered-robot admission fabricated or lost source")
  native_anchor_ready=false
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore) and not auto.roboport_expansion_goal_1076,
    "unanchored native grid was selected and starved Method I")
  native_anchor_ready=true
  _G.TechPriestsRoboportExpansionFrontier1076=nil
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore) and not auto.roboport_expansion_goal_1076,
    "missing canonical 1076 preflight authorized a dead robot goal")
  _G.TechPriestsRoboportExpansionFrontier1076={
    native_covered_ore_admission_1076=function(owner,target,site)
      native_preflight_calls=native_preflight_calls+1
      assert(owner==auto and target.x==65 and site.x==59)
      return true
    end}
  assert(tech_priests_0259_resource_expansion_service(auto)==false
    and auto.roboport_expansion_goal_1076
    and auto.roboport_expansion_goal_1076.remote_station_position_1076.x==59
    and auto.resource_expansion_0259.last_reason==
      "autonomous-covered-powered-robot-resource-frontier"
    and not Chain.status(auto) and #requests==before,
    "actual 0259 shortage discovery did not choose covered robot route")
  auto.roboport_expansion_goal_1076=nil
  net.available_construction_robots=0
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore),"zero robots authorized the remote station")
  net.available_construction_robots=2
  native_stock=0
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore),"missing physical robot-network item passed")
  native_stock=1
  force.is_chunk_charted=function()return false end
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore),"uncharted resource selected autonomous route")
  force.is_chunk_charted=function()return true end
  auto.construction_custody_0338={item_name="roboport",count=1}
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore) and auto.construction_custody_0338.count==1,
    "robot goal preempted original Magos item custody")
  auto.construction_custody_0338=nil
  senior.priest.valid=false
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore),"missing original ranked Senior was substituted")
  senior.priest.valid=true
  local prior_surface=ore.surface
  ore.surface={}
  assert(not tech_priests_0259_autonomous_robot_goal_for_known_ore(
    auto,"iron-ore",ore),"foreign-surface ore was credited")
  ore.surface=prior_surface
  storage.tech_priests.pairs_by_station[300]=nil
  storage.tech_priests.pairs_by_station[301]=nil
  tech_priests_prototype_table_0440=old_provider
  surface.find_entities_filtered=old_surface_search
  surface.can_place_entity=old_can_place
  force.is_chunk_charted=old_chart
  force.index=old_force_index
  _G.TechPriestsRoboportReadiness0714=old_readiness
  _G.TechPriestsRoboportExpansionFrontier1076=old_frontier
  tech_priests_0255_pair_is_magos_planner=old_magos
  TECH_PRIESTS_COMMAND_HIERARCHY_0480.max_link_distance=old_max_link
end
print("[resource-station-service-dispatch-0821] PASS live wrapper, bounded relay, physical pairing, delegated next link and explicit/autonomous native-covered robot priority")

-- Existing source-validation workflow exercises the physical ore courier.
dofile("tests/unit/resource_return_courier_0837.lua")

-- The same ore must cross every rank using separate real inventory debits.
dofile("tests/unit/resource_return_multihop_0838.lua")

-- The same installed Magos service may request a real native drill, but
-- only the 0338 constructor may debit the terminal station or create it.
dofile("tests/unit/remote_machine_drill_1011.lua")
