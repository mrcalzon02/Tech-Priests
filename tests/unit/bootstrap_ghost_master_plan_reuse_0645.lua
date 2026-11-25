-- The master planner owns surveys. Ghost planning consumes its current
-- station-domain snapshot, including after a long interval or module reload.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={direction={north=0}}
local first_item="assembling-machine-1"
local next_item="lab"
prototypes={entity={
  [first_item]={type="assembling-machine"},[next_item]={type="lab"}
},item={}}
local force={valid=true,index=1,technologies={}}
local surface={index=1}
local station={valid=true,unit_number=11,position={x=0,y=0},
  force=force,surface=surface}
local pair={station=station,priest={valid=true,unit_number=12},radius=36,
  self_construction_frustration_unlocked_1504=true}
storage.tech_priests.pairs_by_station[11]=pair
local surveys,creates,stock_reads=0,0,0
local stocks={}
local function current_radius()
  local radius=pair.radius or 36
  if _G.get_station_operating_radius then
    radius=_G.get_station_operating_radius(station)
  end
  return math.max(8,math.min(96,radius))
end
local function snapshot(stage,item)
  return {version="0.1.653",tick=game.tick,station=station.unit_number,
    priest=pair.priest.unit_number,radius=current_radius(),
    surface_index=station.surface.index,force_index=station.force.index,
    station_position={x=station.position.x,y=station.position.y},
    stage=stage or "ready",target={preferred_item=item,class="crafting"}}
end
_G.TechPriestsMasterInfrastructurePlan0644={default_radius=36,
  build_plan=function(p)
    assert(p==pair)
    surveys=surveys+1
    local plan=snapshot()
    p.master_infrastructure_plan_0644=plan
    return plan,"planned"
  end}
_G.TechPriestsPlanningConstraints0646={entity_unlocked=function()return true end}
_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359={
  plan_site=function()return {x=8,y=0},"permitted-site" end}
_G.TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)
  stock_reads=stock_reads+1
  return stocks[item] or 0
end}
surface.find_entities_filtered=function()return {} end
surface.create_entity=function(args)
  creates=creates+1
  local ghost={valid=true,unit_number=100+creates,name="entity-ghost",
    ghost_name=args.inner_name,position=args.position,force=force,surface=surface}
  ghost.destroy=function()ghost.valid=false;return true end
  return ghost
end
local module="scripts.core.construction_bootstrap_ghost_planner_0645"
local Ghost=require(module)
local function service_without_survey(reason)
  local before=surveys
  Ghost.service_pair(pair,reason)
  assert(surveys==before,"ghost planner repeated master survey: "..reason)
end

pair.master_infrastructure_plan_0644=snapshot()
for _,tick in ipairs({1000,1001,1083,1800,36000,120000}) do
  game.tick=tick
  service_without_survey("existing-plan-at-"..tick)
end
package.loaded[module]=nil
Ghost=require(module)
service_without_survey("reload-keeps-owner-snapshot")
assert(surveys==0,"valid snapshot was replaced by a second survey authority")

local function refresh_once(reason,change)
  change()
  local before=surveys
  local acted,why=Ghost.service_pair(pair,reason)
  assert(not acted and why=="not-bootstrap" and surveys==before+1,
    "missing or mismatched plan did not refresh once: "..reason)
  service_without_survey("after-"..reason)
end
refresh_once("cold-station",function()pair.master_infrastructure_plan_0644=nil end)
refresh_once("old-schema",function()
  pair.master_infrastructure_plan_0644.station_position=nil
end)
refresh_once("station-replaced",function()station.unit_number=21 end)
refresh_once("force-change",function()station.force={valid=true,index=2,technologies={}} end)
refresh_once("surface-change",function()
  station.surface={index=2,find_entities_filtered=surface.find_entities_filtered,
    create_entity=surface.create_entity}
end)
refresh_once("station-moved-x",function()station.position.x=2 end)
refresh_once("station-moved-y",function()station.position.y=3 end)
refresh_once("radius-change",function()pair.radius=48 end)
_G.get_station_operating_radius=function()return 60 end
refresh_once("canonical-radius-change",function()end)
pair.radius=80
service_without_survey("canonical-radius-overrides-pair-radius")
_G.get_station_operating_radius=function()return 120 end
refresh_once("radius-clamped-to-domain",function()end)
_G.get_station_operating_radius=function()return 150 end
service_without_survey("same-clamped-radius")
refresh_once("malformed-target",function()
  pair.master_infrastructure_plan_0644.target=nil
end)

-- A canonical refresh remains visible immediately and ghost creation still
-- runs. Changing real stock can supersede the old ghost without a survey.
pair.master_infrastructure_plan_0644=snapshot("basic-crafting",first_item)
local before=surveys
local acted,why=Ghost.service_pair(pair,"current-owner-proposal")
assert(acted and why=="ghost-created" and creates==1 and surveys==before,
  "snapshot reuse disabled bootstrap ghost creation")
local original=pair.construction_bootstrap_ghost_0645.ghost
pair.master_infrastructure_plan_0644=snapshot("research-readiness",next_item)
service_without_survey("replacement-not-yet-physically-stocked")
assert(original.valid and creates==1,"unfunded replacement destroyed an owned ghost")
stocks[next_item]=1
service_without_survey("replacement-now-physically-stocked")
assert(not original.valid and creates==2 and stocks[next_item]==1
  and pair.construction_bootstrap_ghost_0645.entity_name==next_item
  and stock_reads>=3,"snapshot reuse hid live stock or consumed construction material")
pair.construction_task_0338={phase="build"}
pair.construction_custody_0338={item_name=next_item,count=1}
pair.master_infrastructure_plan_0644=snapshot("basic-crafting",first_item)
stocks[first_item]=1;stocks[next_item]=0
service_without_survey("in-flight-custody-still-owns-ghost")
assert(creates==2 and pair.construction_bootstrap_ghost_0645.entity_name==next_item,
  "reusing a plan bypassed active construction custody")
pair.construction_task_0338=nil;pair.construction_custody_0338=nil

-- Observed construction completes the previous proposal. One fresh owner
-- survey advances it; reusing that obsolete target would duplicate a ghost.
pair.master_infrastructure_plan_0644=snapshot("research-readiness",next_item)
local completed=pair.construction_bootstrap_ghost_0645
station.surface.find_entities_filtered=function()
  return {{valid=true,name=next_item,type="lab",position=completed.position}}
end
before=surveys
local built,built_reason=Ghost.service_pair(pair,"physical-construction-completed")
assert(not built and built_reason=="not-bootstrap" and surveys==before+1
  and creates==2 and pair.construction_bootstrap_ghost_0645==nil,
  "observed completion reused its obsolete target and duplicated a ghost")
service_without_survey("completed-target-already-refreshed")
station.surface.find_entities_filtered=function()return {} end

-- A failed domain refresh must not authorize a ghost from a former station.
pair.construction_bootstrap_ghost_0645=nil
station.position.x=station.position.x+1
_G.TechPriestsMasterInfrastructurePlan0644.build_plan=function()
  surveys=surveys+1;error("temporary master planner failure")
end
local failed,failure=Ghost.service_pair(pair,"refresh-unavailable")
assert(not failed and failure=="not-bootstrap" and creates==2,
  "failed refresh reused a stale-domain construction proposal")
-- Explicit requests remain independent of the autonomous master proposal.
before=surveys
local requested,result=Ghost.service_pair(pair,"explicit-network-reservation",first_item)
assert(requested and result=="ghost-created" and creates==3 and surveys==before,
  "explicit construction reservation unexpectedly invoked the master survey")
-- If advancing a physically completed proposal fails, later polling must
-- retry the owner rather than treating the completed target as reusable.
pair.master_infrastructure_plan_0644=snapshot("basic-crafting",first_item)
local final_record=pair.construction_bootstrap_ghost_0645
station.surface.find_entities_filtered=function()
  return {{valid=true,name=first_item,type="assembling-machine",
    position=final_record.position}}
end
before=surveys
local advanced=Ghost.service_pair(pair,"completed-target-refresh-failed")
assert(not advanced and surveys==before+1 and creates==3
  and pair.master_infrastructure_plan_0644==nil,
  "failed completion refresh left a completed proposal eligible for reuse")
Ghost.service_pair(pair,"retry-owner-after-failed-completion-refresh")
assert(surveys==before+2 and creates==3,
  "later ghost polling reused a completed proposal after owner failure")
print("[bootstrap-master-plan-reuse-0645] PASS retained owner snapshot, cold/domain refresh, live stock, custody, explicit request")
