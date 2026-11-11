-- Only canonical 0510 may dispatch real 0338 physical rail construction.
-- Physical cargo and urgent defense must retain precedence.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Dispatcher=require("scripts.core.single_dispatcher_0510")
game={tick=4000}
local force={index=1}
local surface={index=1}
local pair={station={valid=true,unit_number=104,
  name="planetary-magos-cogitator-station",
  position={x=0,y=0},force=force,surface=surface},
  priest={valid=true,unit_number=105,position={x=3,y=0}}}
storage={tech_priests={pairs_by_station={[104]=pair}}}
-- This suite is chained after the dedicated defense canonical test, whose
-- fixture-level stub remains installed globally. Clear its mock only here;
-- the new rail pair has no hostile incident until this test creates one.
_G.TechPriestsDefensePerimeter0259=nil
local pending={item_name="rail",entity_name="straight-rail",
  position={x=13,y=1},direction=4}
pair.construction_request=pending
pair.remote_rail_outpost_0835={
  status="building-physical-rail",
  root_station_unit=104,surface_index=1,force_index=1,
  target={x=512,y=0},pending_rail_0836={request=pending,position=pending.position},
}
local observations,services,discoveries=0,0,0
_G.TechPriestsRemoteRailOutpost0835={
  observe_pair=function()observations=observations+1;return false,"already-owned"end}
_G.TechPriestsRailTrackFrontier0836={
  service_pair=function(p)
    assert(p==pair,"wrong Magos rail mission ownership")
    return true,"waiting-for-physical-builder"
  end,
}
_G.TechPriestsConstructionPlanner0338={
  discover_pair=function(p,force_replan)
    assert(p==pair and force_replan==true,"rail assignment skipped 0338")
    discoveries=discoveries+1
    return {position=pending.position,item_name="rail"}
  end,
  service_pair=function(p,reason)
    assert(p==pair and reason:find("dispatcher%-0510:rail%-frontier"),
      "physical 0338 builder was bypassed")
    services=services+1
    return {processed=1,waiting=1,detail="moving-to-real-rail-site"}
  end,
}
local result=Dispatcher.service_pair(pair,"rail-headless-test")
assert(result.waiting==1 and discoveries==1 and services==1
    and pair.canonical_action_0744.family=="construction"
    and pair.canonical_action_0744.item=="rail"
    and pair.construction_request==pending,
  "rail mission was not owned by physical construction dispatcher")
pair.direct_acquisition_custody_0513={item="iron-ore",count=1}
_G.TechPriestsDirectAcquisitionExecutor0513={
  service_pair=function(p)
    assert(p==pair and p.direct_acquisition_custody_0513.count==1,
      "rail stole actual incoming ore before deposit")
    return {processed=1,waiting=1,detail="returning-real-ore"}
  end,
}
result=Dispatcher.service_pair(pair,"incoming-ore-must-finish")
assert(result.waiting==1 and services==1
    and pair.construction_request==pending
    and pair.canonical_action_0744.family=="direct-acquisition",
  "rail building preempted a live physical cargo-return writ")
pair.direct_acquisition_custody_0513=nil
_G.TechPriestsDefensePerimeter0259={
  has_pending=function()return true end,
  service_pair=function()return{processed=1,acted=1,detail="hostile-turret-priority"}end,
}
result=Dispatcher.service_pair(pair,"real-hostile-damage")
assert(result.acted==1 and services==1
    and pair.construction_request==pending
    and pair.canonical_action_0744.family=="defense",
  "rail construction overrode genuine hostile-defense priority")
_G.TechPriestsDefensePerimeter0259=nil
_G.TechPriestsDirectAcquisitionExecutor0513=nil
_G.TechPriestsConstructionPlanner0338=nil
_G.TechPriestsRailTrackFrontier0836=nil
_G.TechPriestsRemoteRailOutpost0835=nil
print("[rail-dispatcher-0836] PASS physical constructor ownership, incoming ore custody and urgent defense priority")
-- Ensure a pending ore courier cannot starve behind newly issued routine jobs.
dofile("tests/unit/resource_courier_dispatch_reservation_0840.lua")

-- Exercise the REAL 0338 selection, not just the dispatcher test double.
-- Native rail connectivity and item debit still require Factorio engine proof.
do
 local old_prototypes=prototypes
 local old_storage_authority=_G.TechPriestsStorageRoleAuthority0686
 local old_reservations=_G.TechPriestsWorkReservations0601
 local old_move=_G.tech_priests_request_movement_0418
 local old_find,old_can=surface.find_entity,surface.can_place_entity
 local previous=storage.tech_priests.pairs_by_station[104]
 local stock={rail=3,["stone-furnace"]=1}
 local inventory={valid=true,get_item_count=function(item)return stock[item]or 0 end}
 local source={valid=true,position={x=0,y=0},force=force,
  surface=surface,type="container",unit_number=650}
 _G.TechPriestsStorageRoleAuthority0686={generic_storage_sources=function()
  return{{entity=source,inv=inventory,source="real-inventory"}}end}
 _G.TechPriestsWorkReservations0601={categories={},
  root=function()return{reservations={}}end,
  claim=function()return true end,release=function()return true end}
 _G.tech_priests_request_movement_0418=function()return true end
 prototypes={item={
  rail={place_result={name="straight-rail"}},
  ["stone-furnace"]={place_result={name="stone-furnace"}}},
  entity={["straight-rail"]={type="straight-rail"},
   ["stone-furnace"]={type="furnace"}}}
 local ghost={valid=true,name="entity-ghost",ghost_name="stone-furnace",
  position={x=6,y=6},force=force,surface=surface}
 surface.find_entity=function()return ghost end
 surface.can_place_entity=function()return true end
 local station={valid=true,unit_number=104,
  name="planetary-magos-cogitator-station",position={x=0,y=0},
  force=force,surface=surface}
 local priest={valid=true,unit_number=105,position={x=3,y=0},
  force=force,surface=surface}
 local req={item_name="rail",entity_name="straight-rail",category="rail",
  site_reason="remote-rail-physical-frontier-0836",
  rail_mission_station_unit_0836=104,rail_segment_0836=1,
  position={x=13,y=1},direction=4}
 local bootstrap={item="stone-furnace",entity_name="stone-furnace",
  position=ghost.position,ghost=ghost,status="ghosted"}
 local mission={status="building-physical-rail",root_station_unit=104,
  force_index=1,surface_index=1,
  rail_frontier_0836={segment=0,built_units={}},
  pending_rail_0836={request=req,position=req.position,direction=4,segment=1}}
 local p={station=station,priest=priest,construction_request=req,
  construction_bootstrap_ghost_0645=bootstrap,remote_rail_outpost_0835=mission}
 storage.tech_priests.pairs_by_station[104]=p
 local Builder=require("scripts.core.construction_planner")
 local function choose()p.construction_candidate_0338=nil;return Builder.discover_pair(p,true)end
 local chosen=choose()
 assert(chosen and chosen.request_value==req and chosen.item_name=="rail"
  and chosen.direction==4 and chosen.position.x==13
  and p.construction_bootstrap_ghost_0645==bootstrap
  and stock.rail==3 and stock["stone-furnace"]==1,
  "verified 0836 request lost to an unstarted funded bootstrap ghost")
 -- Discovery alone is not authorization to spend an original rail.
 -- Revoke exactly the pending 0836 receipt before dispatcher admission.
 mission.pending_rail_0836.request={}
 local refused=Builder.service_pair(p,"stale-rail-before-admission")
 assert(refused and refused.blocked==1
   and not p.construction_task_0338 and not p.construction_custody_0338
   and p.construction_request==req and stock.rail==3
   and p.construction_bootstrap_ghost_0645==bootstrap,
   "stale discovered rail entered physical builder or lost actual stock")
 mission.pending_rail_0836.request=req
 p.construction_candidate_0338=nil
 req.rail_mission_station_unit_0836=999
 local foreign=choose()
 assert(foreign and foreign.request_value==bootstrap and stock.rail==3,
  "foreign rail marker gained unauthorized construction authority")
 req.rail_mission_station_unit_0836=104
 mission.pending_rail_0836.request={}
 local stale=choose()
 assert(stale and stale.request_value==bootstrap,
  "stale rail request was treated as original custody")
 mission.pending_rail_0836.request=req
 mission.force_index=999
 local other_force=choose()
 assert(other_force and other_force.request_value==bootstrap,
  "wrong force rail request stole funded routine builder")
 mission.force_index=1
 local active={item_name="stone-furnace",phase="move-source"}
 p.construction_task_0338=active
 Builder.discover_pair(p,true)
 assert(p.construction_task_0338==active and stock["stone-furnace"]==1,
  "already-active physical builder was preempted")
 p.construction_task_0338=nil
 p.construction_candidate_0338={item_name="stone-furnace",
  request_field="construction_bootstrap_ghost_0645",request_value=bootstrap,
  position=bootstrap.position}
 Builder.service_pair(p,"pending-rail-over-cached-funded-ghost")
 assert(p.construction_task_0338 and p.construction_task_0338.request_value==req
  and p.construction_task_0338.item_name=="rail"
  and p.construction_bootstrap_ghost_0645==bootstrap
  and stock.rail==3 and stock["stone-furnace"]==1
  and not p.construction_custody_0338,
  "cached funded ghost stole exact rail or fabricated item debit")
 -- An already admitted but not yet debited 0338 rail task is not allowed
 -- to continue once the original Magos/force mission ownership disappears.
 mission.force_index=999
 local revoked=Builder.service_pair(p,"rail-owner-changed-before-item-debit")
 assert(revoked and revoked.blocked==1
   and p.construction_last_task_0338
   and p.construction_last_task_0338.phase=="aborted"
   and p.construction_last_task_0338.result
     =="rail-original-physical-request-stale"
   and not p.construction_task_0338 and not p.construction_custody_0338
   and stock.rail==3 and stock["stone-furnace"]==1,
   "admitted but revoked rail task debited stock or kept unauthorized custody")
 -- If a funded rail mission loses its real supply *after* 0338
 -- admission, no permanent waiting-source task may monopolize the builder.
 -- The no-cargo refusal must retain the original request and pending
 -- mission for 0836 to observe; neither physical item nor ghost is spent.
 mission.force_index=1
 stock.rail=0
 -- An administrator may enable creative construction for unrelated jobs,
 -- but original 0836 rails must still wait for a real item and must never
 -- receive a completion receipt from the creative source-bypass path.
 local creative_root=Builder.root()
 local previous_creative=creative_root.creative_instant_build
 creative_root.creative_instant_build=true
 p.construction_last_task_0338=nil
 p.construction_candidate_0338=nil
 p.construction_cooldown_0338=0
 local start_tick=game.tick
 local waiting=Builder.service_pair(p,"rail-source-exhausted-after-discovery")
 assert(waiting and waiting.waiting==1
   and p.construction_task_0338
   and p.construction_task_0338.phase=="waiting-source"
   and p.construction_task_0338.request_value==req
   and not p.construction_custody_0338
   and p.construction_request==req
   and p.construction_task_0338.creative_build~=true
   and stock.rail==0 and stock["stone-furnace"]==1,
   "creative mode let an unstocked original rail bypass 0338 physical source accounting")
 game.tick=start_tick+Builder.rail_source_wait_ticks_0836
 local at_limit=Builder.service_pair(p,"rail-source-wait-boundary")
 assert(at_limit and at_limit.waiting==1
   and p.construction_task_0338
   and p.construction_task_0338.phase=="waiting-source",
   "valid bounded source wait was interrupted before expiry")
 game.tick=game.tick+1
 local expired=Builder.service_pair(p,"rail-source-exhausted-bounded-refusal")
 assert(expired and expired.blocked==1
   and p.construction_last_task_0338
   and p.construction_last_task_0338.phase=="aborted"
   and p.construction_last_task_0338.result=="rail-physical-source-unavailable"
   and p.construction_last_task_0338.request_value==req
   and not p.construction_task_0338
   and not p.construction_custody_0338
   and p.construction_request==req
   and mission.pending_rail_0836.request==req
   and stock.rail==0 and stock["stone-furnace"]==1
   and p.construction_bootstrap_ghost_0645==bootstrap,
   "expired original rail blocked forever or damaged real item/request custody")
 -- A persisted creative-marked rail must also fail closed if it entered
 -- a previous save with the creative shortcut already active. It cannot
 -- build a free rail or publish a valid paid construction receipt.
 game.tick=start_tick
 p.construction_last_task_0338=nil
 p.construction_candidate_0338=nil
 p.construction_cooldown_0338=0
 local restored=Builder.service_pair(p,"reenter-original-rail-after-timeout")
 assert(restored and p.construction_task_0338
   and p.construction_task_0338.phase=="waiting-source"
   and not p.construction_task_0338.creative_build,
   "original no-stock rail could not reenter the real-source wait")
 p.construction_task_0338.phase="move-site"
 p.construction_task_0338.creative_build=true
 local denied=Builder.service_pair(p,"persisted-creative-rail-rejected")
 assert(denied and denied.blocked==1
   and p.construction_last_task_0338
   and p.construction_last_task_0338.phase=="aborted"
   and p.construction_last_task_0338.result=="rail-creative-item-bypass-forbidden"
   and p.construction_last_task_0338.request_value==req
   and not p.construction_task_0338 and not p.construction_custody_0338
   and p.construction_request==req
   and mission.pending_rail_0836.request==req
   and stock.rail==0 and stock["stone-furnace"]==1,
   "persisted creative rail bypass produced unpaid rail or lost original custody")
 -- Source-observed functional blocker: a railway that reaches the
 -- remote resource can require its original Magos to walk from the last rail
 -- all the way HOME for a physically stocked next rail, then return outward.
 -- The legacy 7200-tick travel cap expired before the ~25960-tick journey.
 -- This test never manufactures rail, forces a move, or accepts engine track.
 creative_root.creative_instant_build=previous_creative
 game.tick=start_tick
 stock.rail=3
 req.position={x=650,y=0}
 req.rail_segment_0836=320
 mission.rail_frontier_0836.segment=319
 mission.pending_rail_0836={request=req,position=req.position,
   direction=4,segment=320}
 priest.position={x=648,y=0}
 p.construction_last_task_0338=nil
 p.construction_candidate_0338=nil
 p.construction_custody_0338=nil
 local far={phase="move-source",started_tick=game.tick,
   item_name="rail",entity_name="straight-rail",
   site_reason="remote-rail-physical-frontier-0836",
   request_field="construction_request",request_value=req,
   position=req.position,direction=4,source_entity=station}
 p.construction_task_0338=far
 local outbound=Builder.service_pair(p,"counted-distant-rail-source-return")
 local physical_ticks=math.ceil((648+650)*Builder.travel_ticks_per_tile)
 assert(outbound and outbound.detail=="moving-source"
   and far.travel_allowance_ticks_0338==physical_ticks
   and physical_ticks>Builder.max_travel_extra_ticks
   and physical_ticks<=Builder.rail_max_travel_extra_ticks_0836
   and p.construction_task_0338==far
   and not p.construction_custody_0338 and stock.rail==3,
   "distant original rail cannot physically walk to source and back")
 game.tick=start_tick+Builder.request_timeout
   +Builder.max_travel_extra_ticks+1
 local still=Builder.service_pair(p,"rail-has-real-travel-budget")
 assert(still and still.detail=="moving-source"
   and p.construction_task_0338==far
   and p.construction_request==req
   and stock.rail==3 and not p.construction_custody_0338,
   "original 0836 rail timed out at short generic building distance")
 game.tick=start_tick+Builder.request_timeout+physical_ticks+1
 local expired_far=Builder.service_pair(p,"rail-still-has-bounded-deadline")
 assert(expired_far and expired_far.blocked==1
   and p.construction_last_task_0338==far
   and far.phase=="aborted"
   and not p.construction_task_0338 and not p.construction_custody_0338
   and p.construction_request==req
   and stock.rail==3,
   "distant rail deadline lost bounded physical accounting/refusal")
 -- The longer cap belongs ONLY to the original 0836 rail request:
 -- regular remote builds still abort under the generic finite deadline.
 game.tick=start_tick
 p.construction_last_task_0338=nil
 local ordinary={phase="move-source",started_tick=game.tick,
   item_name="stone-furnace",entity_name="stone-furnace",
   request_field="construction_bootstrap_ghost_0645",
   request_value=bootstrap,position={x=650,y=0},
   source_entity=station}
 p.construction_task_0338=ordinary
 local normal=Builder.service_pair(p,"ordinary-build-cap-unchanged")
 assert(normal and normal.detail=="moving-source"
   and ordinary.travel_allowance_ticks_0338
      ==Builder.max_travel_extra_ticks
   and stock["stone-furnace"]==1,
   "ordinary construction acquired expanded rail-only timeout")
 game.tick=start_tick+Builder.request_timeout
   +Builder.max_travel_extra_ticks+1
 local normal_expired=Builder.service_pair(p,"ordinary-build-expiry")
 assert(normal_expired and normal_expired.blocked==1
   and p.construction_last_task_0338==ordinary
   and ordinary.phase=="aborted"
   and not p.construction_task_0338 and not p.construction_custody_0338
   and stock["stone-furnace"]==1 and stock.rail==3,
   "ordinary construction timeout bypassed or item stock changed")
 game.tick=start_tick
 storage.tech_priests.pairs_by_station[104]=previous
 prototypes=old_prototypes
 surface.find_entity, surface.can_place_entity=old_find,old_can
 _G.TechPriestsStorageRoleAuthority0686=old_storage_authority
 _G.TechPriestsWorkReservations0601=old_reservations
 _G.tech_priests_request_movement_0418=old_move
end
print("[rail-builder-0836] PASS exact 0338 rail priority, stale/foreign refusal, live task retention")
