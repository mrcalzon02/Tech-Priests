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
  position={x=12,y=0},direction=4}
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
