-- Railway scope regression: paid construction may cross station leash ONLY
-- on the original verified 0836 physical corridor. No native engine claim.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=5000}
storage={tech_priests={pairs_by_station={}}}
defines={
  command={stop=1,go_to_location=2},
  distraction={none=0,by_enemy=1},
  direction={east=4},
  rail_direction={front=0,back=1},
  rail_connection_direction={straight=1},
}
local original_scan_routing_1401=_G.TechPriestsScanRouting0610
_G.TechPriestsScanRouting0610=nil
_G.TechPriestsPairBucketRegistry0600={force_bucket=function() end}
local force={index=1}
local sites={}
local ghosts_created=0
local surface={valid=true,index=1}
surface.create_entity=function()
  ghosts_created=ghosts_created+1
  error("rail route planning attempted an in-world ghost/entity")
end
surface.find_entities_filtered=function(filters)
  if filters.name~="straight-rail" then return {} end
  local e=sites[filters.position.x]
  if e and e.valid and e.position.y==filters.position.y then return {e} end
  return {}
end
local units={}
for i=1,44 do
  local x=13+(i-1)*2
  local e={valid=true,unit_number=2100+i,name="straight-rail",
    direction=4,position={x=x,y=1},force=force,surface=surface}
  e.get_connected_rail=function(args)
    if args.rail_connection_direction~=defines.rail_connection_direction.straight
      then return nil end
    if args.rail_direction==defines.rail_direction.front then return sites[x+2] end
    if args.rail_direction==defines.rail_direction.back then return sites[x-2] end
    return nil
  end
  sites[x]=e
  units[i]=e.unit_number
end
local station={valid=true,name="planetary-magos-cogitator-station",
  unit_number=104,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,unit_number=105,position={x=80,y=1},
  force=force,surface=surface,
  commandable={valid=true,set_command=function() end}}
local pair={station=station,priest=priest,radius=28}
storage.tech_priests.pairs_by_station[104]=pair
local source={valid=true,unit_number=700,name="steel-chest",
  position={x=0,y=0},force=force,surface=surface}
local source_stock=10
local source_inv={valid=true,get_item_count=function(item)
  return item=="rail" and source_stock or 0 end}
local rail_request={item_name="rail",entity_name="straight-rail",
  site_reason="remote-rail-physical-frontier-0836",
  rail_mission_station_unit_0836=104,rail_segment_0836=45,
  position={x=101,y=1},direction=4}
local mission={
  status="building-physical-rail",root_station_unit=104,
  force_index=1,surface_index=1,target={x=512,y=0},
  rail_frontier_0836={segment=44,start_position={x=13,y=1},
    last_position={x=99,y=1},direction=4,built_units=units},
  pending_rail_0836={request=rail_request,position=rail_request.position,
    direction=4,segment=45}}
pair.remote_rail_outpost_0835=mission
pair.construction_request=rail_request
local task={
  phase="move-site",request_field="construction_request",
  request_value=rail_request,
  site_reason="remote-rail-physical-frontier-0836",
  item_name="rail",entity_name="straight-rail",
  direction=4,position={x=101,y=1},
  carried={item_name="rail",count=1},
  original_rail_source_debit_0836={source_unit=700,before=10,
    after=9,item="rail"},source_entity=source,source_inv=source_inv,
}
pair.construction_task_0338=task
local Track=require("scripts.core.rail_track_frontier_0836")
_G.TechPriestsRailTrackFrontier0836=Track
local Corridor=require("scripts.core.authority_corridor_pathing_0574")
local Movement=require("scripts.core.movement_controller")
assert(Corridor.install(),"canonical 0574 corridor not installed")
local goal={x=102,y=3}
local function check(ok,msg)
  assert(ok,"[rail-expedition-transit-1401] "..msg)
end
local function offer(where,reason)
  return Movement.request(pair,where,reason,{
    owner="construction-planner-0338",priority=968,ttl=720,radius=0.3})
end
local offered,why=offer(goal,"construction-site-standoff-0338")
check(offered==true,"original paid rail destination refused: "..tostring(why))
local original=pair.movement_request_0418
check(original and original.owner=="construction-planner-0338"
  and original.reason=="construction-site-standoff-0338"
  and original.ground_route_chunked==true
  and original.ground_route_final_destination
  and original.ground_route_final_destination.x==goal.x
  and original.x<goal.x,
  "paid site journey must use original-owned bounded physical waypoints")
check(Track.authorized_paid_rail_transit_0836(pair,priest.position,original),
  "counted original railway corridor disallowed between station and frontier")
local kept,reason=Movement.enforce_pair(pair,"original-physical-rail-midroute")
check(not kept and reason=="original-paid-rail-transit-owned-0836"
  and pair.movement_request_0418==original,
  "generic hard leash stole the paid outbound Magos movement")
-- A visible 18-tile waypoint has to inherit only the original verified
-- final destination, never gain a broad station-range bypass.
check(Movement.position_allowed(pair,{x=81,y=1},
  "construction-site-standoff-0338",{
    owner="construction-planner-0338",ground_route_chunked=true,
    ground_route_final_destination=goal}),
  "bounded intermediate waypoint lost original physical rail authorization")
check(not Movement.position_allowed(pair,{x=81,y=1},
  "ordinary-construction-move",{owner="ordinary-priest"}),
  "ordinary work inherited rail expedition exemption")
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,{
  owner="ordinary-priest",reason="construction-site-standoff-0338",
  ground_route_final_destination=goal}),
  "forged non-rail owner inherited original 0338 railway authority")
-- A legitimate empty-handed return to the REAL home source must not be
-- interrupted just because the next rail has not yet been picked up.
Movement.stop(pair,"physical-source-leg")
task.phase="move-source"
task.carried=nil
task.original_rail_source_debit_0836=nil
local home={x=0,y=3}
offered,why=offer(home,"construction-source-0338")
check(offered==true,"original source collection refused: "..tostring(why))
local source_route=pair.movement_request_0418
check(source_route and source_route.ground_route_chunked==true
  and source_route.ground_route_final_destination
  and source_route.ground_route_final_destination.x==home.x
  and source_route.x>home.x,
  "original source return must travel as bounded 18-tile waypoints")
check(Track.authorized_paid_rail_transit_0836(pair,priest.position,source_route),
  "original 0338 collection journey lost its verified railway")
kept,reason=Movement.enforce_pair(pair,"original-source-midroute")
check(not kept and reason=="original-paid-rail-transit-owned-0836"
  and pair.movement_request_0418==source_route,
  "overleash safety forced a new destination over original stock collection")
-- A source on another surface, a depleted original inventory, a task
-- with foreign cargo or a forged pending writ must not authorize pickup.
source_stock=0
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,source_route),
  "empty station stock allowed a meaningless out-of-station collection writ")
source_stock=10
-- A source on another surface, a task with foreign cargo, or a forged
-- pending writ must NOT gain an empty-handed rail pass.
task.source_entity={valid=true,unit_number=701,
  position={x=0,y=0},force=force,surface={index=90}}
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,source_route),
  "foreign-surface supply permitted a rail expedition")
task.source_entity=source
task.carried={item_name="rail",count=1}
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,source_route),
  "source pickup while already carrying another item granted")
task.carried=nil
mission.pending_rail_0836.request={}
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,source_route),
  "revoked original pending segment still authorized movement")
mission.pending_rail_0836.request=rail_request
task.phase="move-site"
task.carried={item_name="rail",count=1}
task.original_rail_source_debit_0836={source_unit=700,before=10,
  after=9,item="rail"}
Movement.stop(pair,"broken-rail-negative")
offered,why=offer(goal,"construction-site-standoff-0338")
check(offered==true,"negative setup lost authentic rail-site offer")
local live=pair.movement_request_0418
local original_rail=sites[81]
sites[81]=nil
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,live),
  "missing local paid rail accepted as walkable expedition corridor")
kept,reason=Movement.enforce_pair(pair,"midroute-paid-track-destroyed")
check(kept and reason=="overleash-return"
  and pair.movement_request_0418
  and pair.movement_request_0418.owner=="movement-controller-enforcement-0566",
  "broken physical track did not reinstate the ordinary safety leash")
sites[81]=original_rail
Movement.stop(pair,"mission-finished")
storage.tech_priests.pairs_by_station[104]=nil
check(not Track.authorized_paid_rail_transit_0836(pair,priest.position,live),
  "orphan/unregistered Magos retained station-wide travel permission")
storage.tech_priests.pairs_by_station[104]=pair
check(ghosts_created==0,"rail mission planning generated physical ghosts")
-- Factorio-native extension geometry is observed only AFTER the last
-- original 0338 rail has been physically built and its unit ID is known.
-- Probe is read-only: no blueprint ghosts, new executor, item removal or
-- early credit for either curved or straight candidate.
prototypes={item={rail={name="rail"}},entity={
  ["straight-rail"]={name="straight-rail"},
  ["curved-rail-a"]={name="curved-rail-a"},
  ["rail-ramp"]={name="rail-ramp"},
}}
surface.can_place_entity=function(spec)
  return spec.name~="rail-ramp"
end
sites[99].get_rail_end=function(direction)
  return {valid=true,get_rail_extensions=function(planner)
    check(planner=="rail","native extension probe used wrong rail item")
    if direction==defines.rail_direction.front then
      return {
        {name="straight-rail",position={x=101,y=1},direction=4},
        {name="curved-rail-a",position={x=103,y=5},direction=2},
        {name="curved-rail-a",position={x=103,y=5},direction=2},
        {name="rail-ramp",position={x=105,y=7},direction=4},
      }
    end
    return {}
  end}
end
local candidate,probe_reason=Track.inspect_native_rail_extensions_0836(pair)
check(probe_reason=="native-rail-options-observed"
  and type(candidate)=="table" and #candidate==2
  and candidate[1].name=="curved-rail-a"
  and candidate[2].name=="straight-rail"
  and candidate[1].from_rail_unit==sites[99].unit_number,
  "original connected rail did not provide sorted, deduplicated native options")
check(ghosts_created==0,
  "native geometry inspection created ghosts instead of pure route intent")
pair.construction_task_0338=nil
pair.construction_request=nil
mission.pending_rail_0836=nil
mission.status="building-physical-rail"
local planned,next_reason=Track.plan_next(pair)
check(planned and next_reason=="rail-segment-requested"
  and pair.construction_request
  and pair.construction_request.item_name=="rail"
  and pair.construction_request.position.x==101
  and mission.rail_frontier_0836.segment==44
  and mission.rail_frontier_0836.native_probe_segment_1402==44
  and mission.rail_frontier_0836.native_probe_reason_1402
    =="native-rail-options-observed"
  and #mission.rail_frontier_0836.native_probe_options_1402==2
  and ghosts_created==0,
  "native probe rewrote original single-rail physical execution or emitted ghosts")
_G.TechPriestsScanRouting0610=original_scan_routing_1401
print("[rail-expedition-transit-1401] PASS real source/site transit, bounded lane, physical rail identity, revoked mission, ordinary leash, zero ghosts")
