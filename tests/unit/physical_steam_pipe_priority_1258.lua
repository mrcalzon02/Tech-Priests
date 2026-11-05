-- 1258: 0691 may publish a genuine dry-steam physical pipe request even
-- with a cached UNSTARTED routine 0338 candidate. It may NOT override a
-- physical 0338 task/custody, create fluid or produce a pipe from nothing.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=18000}
local force={index=1}
local surface={index=1}
surface.find_entities_filtered=function()return{}end
surface.can_place_entity=function()return true end
local station={valid=true,unit_number=3,surface=surface,force=force,
 position={x=0,y=0}}
local priest={valid=true,unit_number=4,surface=surface,force=force}
local machine={valid=true,unit_number=5,surface=surface,force=force,
 name="boiler",position={x=5,y=0}}
local remote={valid=true,unit_number=6,surface=surface,force=force,
 name="offshore-pump",position={x=1,y=0}}
local pair={station=station,priest=priest,radius=32}
storage={tech_priests={pairs_by_station={[3]=pair}}}
_G.TechPriestsFluidNetworkDoctrine0689={
 inspect_machine=function(p,m)
  assert(p==pair and m==machine)
  return{records={{index=1,requirement={name="water"},connected=false}}}
 end,
 validate_proposal=function(p,proposal)
  assert(p==pair and proposal.action=="connect-fluid-input")
  return true,"safe"
 end,
}
local plan={id="3:input:5:18000",state="planned",
 direction="input",fluid="water",machine=machine,
 machine_fluidbox_index=1,remote={entity=remote},
 tiles={{x=3,y=0}},current_index=1,
 proposal={action="connect-fluid-input"}}
pair.standard_fluid_route_plan_0691=plan
pair.construction_candidate_0338={item_name="stone-furnace",
 request_value={item_name="stone-furnace"},position={x=2,y=2}}
local candidate=pair.construction_candidate_0338
local Route=require("scripts.core.fluid_connection_planner_0691")
local result=Route.refresh_pair(pair)
local req=pair.construction_request
assert(result.waiting==1 and result.detail=="request-published"
 and req and req.source=="standard-fluid-route-0691"
 and req.item_name=="pipe" and req.route_plan_id==plan.id
 and req.position.x==3 and req.position.y==0
 and pair.construction_candidate_0338==candidate
 and plan.state=="construction-requested",
 "cached ordinary candidate prevented native water route publication")
-- Incumbent real 0338 construction MUST win. Do not overwrite cargo/movement.
pair.construction_request=nil
pair.construction_task_0338={phase="move-source",item_name="iron-chest"}
local blocked=Route.refresh_pair(pair)
assert(blocked.detail=="construction-busy"
 and not pair.construction_request
 and pair.construction_task_0338.item_name=="iron-chest",
 "native route seized active physical builder")
print("[physical-steam-pipe-priority-1258] PASS unstarted discovery yields, real construction remains incumbent, no free fluids or material")
