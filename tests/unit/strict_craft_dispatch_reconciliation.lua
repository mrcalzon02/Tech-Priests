-- Lua 5.2: canonical 0488/0510 strict craft versus direct-acquisition ownership.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=16000}
storage={tech_priests={pairs_by_station={}}}
local counts={craft=0,direct=0,stops=0,repair=0,construction=0}
local physical={valid=true,name="iron-ore",type="resource",
  unit_number=90,position={x=8,y=0},surface={index=1}}
local function make_pair()
  storage={tech_priests={pairs_by_station={}}}
  counts={craft=0,direct=0,stops=0,repair=0,construction=0}
  local surface={index=1,name="nauvis"}
  local force={index=1,name="player"}
  local station={valid=true,name="junior-cogitator-station",unit_number=11,
    position={x=0,y=0},surface=surface,force=force}
  local priest={valid=true,name="priest",unit_number=12,
    position={x=8,y=0},surface=surface,force=force}
  local p={station=station,priest=priest,mode="direct-acquisition-working",
    station_unit=11,priest_unit=12}
  storage.tech_priests.pairs_by_station[11]=p
  return p
end
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local Dispatcher=require("scripts.core.single_dispatcher_0510")
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
_G.TechPriestsEmergencyProductionExecutor0514={
  service_pair=function()counts.craft=counts.craft+1;return true,"station-craft" end}
_G.TechPriestsDirectAcquisitionExecutor0513={
  current_direct_task=function(p)
    local t=p.direct_acquisition_task_0336
    return t,t and t.current,"direct_acquisition_task_0336"
  end,
  service_pair=function()counts.direct=counts.direct+1;return true,"working"end,
}
_G.TechPriestsRepairExecutor0516={service_pair=function()
  counts.repair=counts.repair+1;return true,"repair"end}
_G.TechPriestsConstructionPlanner0338={
  recommend_action=function(p)
    local task=p.construction_task_0338
    if not task then return nil end
    return {kind="construction",active=true,item=task.item_name,
      phase=task.phase,position=task.position,source="construction-planner-0338"}
  end,
  service_pair=function(p)
    counts.construction=counts.construction+1
    assert(p.construction_task_0338 and
      (p.construction_task_0338.carried or
       (p.construction_task_0338.phase=="move-source"
        and p.construction_task_0338.source_inv)),
      "test must preserve actual 0338 held item or real source approach")
    return {processed=1,waiting=1,detail="physical-build-in-flight"}
  end
}
_G.TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={
  request_status=function(p)
    return p.movement_request_0418 and {active=true,owner=p.movement_request_0418.owner}
      or {active=false}
  end,
  stop=function(p)
    counts.stops=counts.stops+1;p.movement_request_0418=nil;return true
  end
}
local total=0
local function check(ok,why)if not ok then error("strict-dispatch: "..why,2)end end
local function test(label,fn)
  fn();total=total+1;print("[strict-craft-dispatch] PASS "..label)
end
local function setup(p)
  local raw={kind="direct-mine-0336",bootstrap_resource_0637=true,
    output_item="iron-ore",current={kind="direct-mine-0336",
      output_item="iron-ore",entity=physical}}
  p.direct_acquisition_task_0336=raw
  p.emergency_craft={strict_recipe_0647=true,output_item="iron-gear-wheel",
    count=1,target_stock_0647=2,craft_due_tick_0514=15900,
    current={kind="direct-mine-0336",entity=physical}}
  p.movement_request_0418={owner="direct-acquisition-0513",
    priority=650,expires_tick=16500}
  return raw
end

test("timed strict craft wins over stray direct current and route",function()
  local p=make_pair();setup(p)
  local action=Arbiter.action(p)
  check(action.kind=="crafting","arbiter selected "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"regression")
  check(result.acted==1 and counts.craft==1 and counts.direct==0,
    "dispatcher did not execute strict production")
  check(counts.stops==1 and p.movement_request_0418==nil,
    "stale direct movement lease survived")
  check(p.emergency_craft.strict_recipe_0647==true,"strict craft was cleared")
end)

test("strict craft without due tick beats stale direct-mine current",function()
  local p=make_pair();setup(p)
  p.emergency_craft.craft_due_tick_0514=nil
  local action=Arbiter.action(p)
  check(action.kind=="crafting","stale direct-mine alias disguised strict recipe as "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"strict-no-due")
  check(result.acted==1 and counts.craft==1 and counts.direct==0,
    "strict recipe was not serviced before its fallback due tick")
  check(counts.stops==1 and p.movement_request_0418==nil,
    "stale direct movement lease blocked the manufacturing handoff")
end)

test("strict assembler permits its marked real coal refuel run",function()
  local p=make_pair();local raw=setup(p)
  p.emergency_craft.craft_due_tick_0514=nil
  raw.output_item="coal";raw.current.output_item="coal"
  raw.fuel_for_strict_recipe_0637=true
  local action=Arbiter.action(p)
  check(action.kind=="acquisition",
    "strict recipe stole its own explicitly authorized fuel extraction")
  local result=Dispatcher.service_pair(p,"strict-fuel-physical-acquisition")
  check(result.acted==1 and counts.direct==1 and counts.craft==0,
    "physical coal recovery was not executed by direct acquisition")
  check(p.emergency_craft.strict_recipe_0647==true,
    "fuel transport erased parent strict recipe")
end)
test("strict smelter permits its marked real ingredient acquisition",function()
 local p=make_pair();local raw=setup(p)
 p.emergency_craft.output_item="stone-brick";p.emergency_craft.craft_due_tick_0514=nil
 raw.output_item="stone";raw.current.output_item="stone";raw.material_for_strict_recipe_0637=true
 check(Arbiter.action(p).kind=="acquisition","strict batch stole its missing stone extraction")
 local result=Dispatcher.service_pair(p,"strict-material-physical-acquisition")
 check(result.acted==1 and counts.direct==1 and counts.craft==0 and p.emergency_craft.output_item=="stone-brick",
  "material extraction did not preserve strict smelting parent")
end)

test("physical custody returns before strict station crafting",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_custody_0513={item="iron-ore",count=1}
  local result=Dispatcher.service_pair(p,"cargo-return")
  check(result.acted==1 and counts.direct==1 and counts.craft==0,
    "carried mined output lost its executor")
  check(counts.stops==0,"custody return movement was stopped")
  check(p.direct_acquisition_custody_0513.count==1,"physical custody changed")
end)

-- Native Method II frontier: the Magos walked to a pole contact with a
-- physically debited item, then returned home while 0338 stayed in move-site.
-- A newly due strict craft must not starve that original construction custody.
test("physically carried 0338 pole resumes ahead of strict crafting",function()
  local p=make_pair();setup(p)
  local task={phase="move-site",item_name="medium-electric-pole",
    position={x=25,y=6},carried={item_name="medium-electric-pole",count=1}}
  p.construction_task_0338=task
  p.construction_custody_0338={item_name="medium-electric-pole",count=1}
  local action=Arbiter.action(p)
  check(action.kind=="construction",
    "held pole classified as "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"native-frontier-physical-custody")
  check(result.waiting==1 and counts.construction==1
      and counts.craft==0 and counts.direct==0,
    "original 0338 builder did not receive its incumbent work")
  check(p.construction_task_0338==task and task.carried.count==1
      and p.construction_custody_0338.count==1
      and p.emergency_craft.strict_recipe_0647==true,
    "construction custody or deferred strict craft was modified")
  check(counts.stops==0,"foreign movement route was forcibly retired")
end)

test("explicit strict craft cannot strand an already carried pole",function()
  local p=make_pair();setup(p)
  p.order_queue_0469={current={kind="crafting",status="active",key="craft-due"},
    pending={},pending_keys={}}
  local task={phase="move-site",item_name="medium-electric-pole",
    position={x=25,y=6},carried={item_name="medium-electric-pole",count=1}}
  p.construction_task_0338=task
  local result=Dispatcher.service_pair(p,"strict-craft-vs-real-build")
  check(result.waiting==1 and counts.construction==1 and counts.craft==0,
    "strict recipe preempted physically removed 0338 item")
  check(p.order_queue_0469.current.key=="craft-due"
    and task.carried.count==1,
    "deferred craft order or carried pole was discarded")
end)

-- The native frontier reached the pole's real build radius but stopped
-- receiving 0338 service while a routine bootstrap ore order was current.
-- A physical held pole is not a fresh construction candidate.
test("marked bootstrap acquisition yields to physically held 0338 pole",function()
  local p=make_pair();setup(p)
  p.order_queue_0469={current={kind="acquisition",status="active",
    key="bootstrap-ore"},pending={},pending_keys={}}
  local task={phase="move-site",item_name="medium-electric-pole",
    position={x=25,y=6},carried={item_name="medium-electric-pole",count=1}}
  p.construction_task_0338=task
  p.construction_custody_0338={item_name="medium-electric-pole",count=1}
  check(Arbiter.action(p).kind=="construction",
    "bootstrap acquisition displaced real 0338 carried pole")
  local result=Dispatcher.service_pair(p,"bootstrap-vs-physical-pole")
  check(result.waiting==1 and counts.construction==1
      and counts.direct==0 and counts.craft==0,
    "dispatcher did not resume the existing physical builder")
  check(task.carried.count==1 and p.construction_custody_0338.count==1
      and p.order_queue_0469.current.key=="bootstrap-ore",
    "carried item, custody or deferred bootstrap order changed")
end)

-- Native 1088 Factorio: current.kind was literally "logistics" throughout
-- a physically held first-pole move-site. Normalization maps it to acquisition;
-- the existing bootstrap exception did not cover this queue owner.
test("generic logistics yields to the exact physically held move-site pole",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="routine-supply"},
    pending={},pending_keys={}}
  local task={phase="move-site",item_name="medium-electric-pole",
    position={x=25,y=6},carried={item_name="medium-electric-pole",count=1}}
  p.construction_task_0338=task
  p.construction_custody_0338={item_name="medium-electric-pole",count=1}
  local action=Arbiter.action(p)
  check(action.kind=="construction",
    "generic logistics displaced the native held pole: "..tostring(action.kind))
  local result=Dispatcher.service_pair(p,"native-logistics-vs-physical-pole")
  check(result.waiting==1 and counts.construction==1
      and counts.direct==0 and counts.craft==0,
    "original physical 0338 executor was not dispatched")
  check(p.order_queue_0469.current.key=="routine-supply"
      and task.carried.count==1 and p.construction_custody_0338.count==1,
    "queued logistics or counted construction cargo was modified")
end)

-- Native run 41516621302: the first pole was accepted at tick 19580,
-- but a second already-funded frontier task never reached physical pickup.
-- Generic logistics repeatedly selected acquisition while 0338 remained in
-- move-source. The classifier must dispatch that exact source-backed task;
-- 0338 alone may walk, debit the item, and create the real pole.
test("stocked second frontier pole gets move-source dispatcher service",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="routine-supply"},
    pending={},pending_keys={}}
  local stock=1
  local source_inv={valid=true,get_item_count=function(item)
    return item=="medium-electric-pole" and stock or 0
  end}
  local request={frontier_root_unit_1076=p.station.unit_number}
  p.construction_request=request
  local task={phase="move-source",item_name="medium-electric-pole",
    site_reason="powered-roboport-frontier-1076",
    request_field="construction_request",request_value=request,
    position={x=33,y=5},source_entity=p.station,source_inv=source_inv}
  p.construction_task_0338=task
  check(Arbiter.action(p).kind=="construction",
    "stocked source-backed pole remained starved by generic logistics")
  local result=Dispatcher.service_pair(p,"second-frontier-pole-real-pickup")
  check(result.waiting==1 and counts.construction==1
      and counts.direct==0 and counts.craft==0,
    "canonical 0338 was not dispatched for its physical source approach")
  check(stock==1 and task.carried==nil and p.construction_custody_0338==nil
      and p.construction_request==request
      and p.order_queue_0469.current.key=="routine-supply",
    "classifier spent a pole, forged cargo, or removed deferred logistics")
end)

test("unfunded, foreign or superseded source cannot preempt logistics",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="routine-supply"},
    pending={},pending_keys={}}
  local stock=0
  local inv={valid=true,get_item_count=function()return stock end}
  local request={frontier_root_unit_1076=p.station.unit_number}
  p.construction_request=request
  local task={phase="move-source",item_name="medium-electric-pole",
    site_reason="powered-roboport-frontier-1076",
    request_field="construction_request",request_value=request,
    source_entity=p.station,source_inv=inv,position={x=33,y=5}}
  p.construction_task_0338=task
  check(Arbiter.action(p).kind~="construction",
    "empty physical source stole routine logistics")
  stock=1
  task.source_entity={valid=true,surface=p.station.surface,
    force={index=99},position={x=0,y=0}}
  check(Arbiter.action(p).kind~="construction",
    "foreign-force inventory was accepted as frontier stock")
  task.source_entity=p.station
  task.request_value={frontier_root_unit_1076=p.station.unit_number}
  check(Arbiter.action(p).kind~="construction",
    "superseded frontier request retained builder priority")
  task.request_value=request
  inv.valid=false
  check(Arbiter.action(p).kind~="construction",
    "invalid source inventory was accepted as physical stock")
end)

test("real logistics cargo outranks stocked frontier source approach",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="cargo-supply"},
    pending={},pending_keys={}}
  local request={frontier_root_unit_1076=p.station.unit_number}
  p.construction_request=request
  p.construction_task_0338={phase="move-source",
    item_name="medium-electric-pole",position={x=33,y=5},
    site_reason="powered-roboport-frontier-1076",
    request_field="construction_request",request_value=request,
    source_entity=p.station,
    source_inv={valid=true,get_item_count=function()return 1 end}}
  p.machine_logistics_0528={custody={item="iron-plate",count=1}}
  check(Arbiter.action(p).kind~="construction"
      and p.machine_logistics_0528.custody.count==1,
    "funded frontier approach bypassed real competing logistics custody")
end)

test("logistics with real competing cargo retains custody priority",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="cargo-supply"},
    pending={},pending_keys={}}
  p.construction_task_0338={phase="move-site",item_name="medium-electric-pole",
    carried={item_name="medium-electric-pole",count=1}}
  p.construction_custody_0338={item_name="medium-electric-pole",count=1}
  p.machine_logistics_0528={custody={item="iron-plate",count=1}}
  check(Arbiter.action(p).kind~="construction",
    "real logistics cargo was bypassed by construction")
  check(p.machine_logistics_0528.custody.count==1
      and p.construction_task_0338.carried.count==1,
    "either physical custody was modified")
end)

test("unfunded construction never steals routine logistics",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="logistics",status="active",key="routine-supply"},
    pending={},pending_keys={}}
  p.construction_task_0338={phase="waiting-source",item_name="medium-electric-pole",
    position={x=25,y=6}}
  check(Arbiter.action(p).kind~="construction",
    "unfunded construction displaced logistics without a physical item")
end)

test("unmarked explicit acquisition retains priority over held 0338 pole",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="acquisition",status="active",
    key="explicit-ore"},pending={},pending_keys={}}
  p.construction_task_0338={phase="move-site",item_name="medium-electric-pole",
    position={x=25,y=6},carried={item_name="medium-electric-pole",count=1}}
  check(Arbiter.action(p).kind=="acquisition",
    "unmarked explicit foreign acquisition was preempted")
  local result=Dispatcher.service_pair(p,"explicit-ore-vs-physical-pole")
  check(result.acted==1 and counts.direct==1 and counts.construction==0,
    "explicit nonbootstrap acquisition lost its owner")
  check(p.construction_task_0338.carried.count==1,
    "foreign acquisition changed held construction inventory")
end)

test("unfunded construction never steals strict-craft priority",function()
  local p=make_pair();setup(p)
  p.construction_task_0338={phase="waiting-source",
    item_name="medium-electric-pole",position={x=25,y=6}}
  local action=Arbiter.action(p)
  check(action.kind=="crafting","unfunded builder displaced strict craft")
  local result=Dispatcher.service_pair(p,"unfunded-construction")
  check(result.acted==1 and counts.craft==1 and counts.construction==0,
    "unfunded construction monopolized dispatcher")
end)

test("direct physical ore custody still outranks held construction",function()
  local p=make_pair();setup(p)
  p.construction_task_0338={phase="move-site",item_name="medium-electric-pole",
    carried={item_name="medium-electric-pole",count=1}}
  p.direct_acquisition_custody_0513={item="iron-ore",count=1}
  local result=Dispatcher.service_pair(p,"physical-ore-first")
  check(result.acted==1 and counts.direct==1 and counts.construction==0,
    "incumbent construction bypassed earlier physical ore custody")
  check(p.construction_task_0338.carried.count==1,
    "construction cargo was changed during ore return")
end)

test("active repair order is not displaced by pending manufacturing",function()
  local p=make_pair();setup(p)
  p.order_queue_0469={current={kind="repair",status="active",key="repair-unique",
    priority=800,target=physical},pending={},pending_keys={}}
  local result=Dispatcher.service_pair(p,"repair-priority")
  check(result.acted==1 and counts.repair==1 and counts.craft==0,
    "repair order was preempted without authorization")
  check(counts.stops==0,"repair-owned movement was modified")
  check(p.order_queue_0469.current.key=="repair-unique","repair order changed")
end)

test("ordinary explicit acquisition retains its order priority",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336.bootstrap_resource_0637=nil
  p.order_queue_0469={current={kind="acquisition",status="active",
    key="deliberate-acquisition",priority=570},pending={},pending_keys={}}
  local result=Dispatcher.service_pair(p,"explicit-acquisition")
  check(result.acted==1 and counts.direct==1 and counts.craft==0,
    "nonbootstrap acquisition was displaced")
  check(counts.stops==0,"explicit acquisition movement was stopped")
end)

test("no movement owner means no unrelated stop",function()
  local p=make_pair();setup(p)
  p.movement_request_0418.owner="movement-controller-enforcement-0566"
  Dispatcher.service_pair(p,"enforced-return")
  check(counts.craft==1 and counts.stops==0,
    "safety enforcement movement was stopped")
end)

test("blocked canonical production preserves its reason without a nonexistent fallback",function()
  local p=make_pair();setup(p)
  local original=_G.TechPriestsEmergencyProductionExecutor0514.service_pair
  _G.TechPriestsEmergencyProductionExecutor0514.service_pair=function()
    return false,"missing-ingredient:iron-plate"
  end
  local result=Dispatcher.service_pair(p,"blocked-production")
  _G.TechPriestsEmergencyProductionExecutor0514.service_pair=original
  check(result.failed==0 and result.blocked==1 and result.detail=="missing-ingredient:iron-plate",
    "canonical missing ingredient was replaced by a nonexistent crafting method error")
end)
test("facility-only native furnace resumes without a handcraft timer",function()
  local p=make_pair();setup(p)
  p.emergency_craft={facility_only_0647=true,item_name="iron-plate",
    output_item="iron-plate",count=1,current={kind="direct-mine-0273",entity=physical}}
  p.direct_acquisition_task_0336=nil
  check(Arbiter.action(p).kind=="crafting","native furnace task was classified as idle acquisition")
  Dispatcher.service_pair(p,"native-furnace")
  check(counts.craft==1 and counts.direct==0 and counts.stops==1,
    "canonical furnace did not receive service or kept its obsolete mining lease")
end)
test("facility-only furnace preserves its marked physical ore child",function()
  local p=make_pair();setup(p)
  p.emergency_craft={facility_only_0647=true,item_name="iron-plate",count=1}
  p.direct_acquisition_task_0336.material_for_strict_recipe_0637=true
  check(Arbiter.action(p).kind~="crafting","native furnace displaced its own actual ore task")
end)
test("adopted recipe-fanout assignment uses its canonical native recipe",function()
  local p=make_pair();setup(p)
  p.direct_acquisition_task_0336=nil
  p.emergency_craft={infrastructure_first_0640=true,facility_only_0647=true,
    output_item="iron-plate",count=4}
  local task={item="iron-plate"};p.active_task=task
  local o={kind="assignment",source="adopt-active",purpose="recipe-fanout",
    status="active",item="iron-plate",task=task}
  p.order_queue_0469={current=o}
  check(Arbiter.action(p).kind=="crafting","automatic recipe assignment bypassed its native owner")
  o.source="player"
  check(Arbiter.action(p).kind~="crafting","explicit assignment was mistaken for an automatic recipe")
end)
test("unpowered native recipe admits its exact funded steam pipe prerequisite",function()
  local p=make_pair();p.mode="idle";p.radius=40
  p.emergency_craft={infrastructure_first_0640=true,facility_only_0647=true,
    strict_recipe_0647=true,output_item="lab",count=1}
  local boiler={valid=true,type="boiler",force=p.station.force,surface=p.station.surface}
  local request={item_name="pipe",entity_name="pipe",source="standard-fluid-route-0691",route_plan_id="native-steam"}
  p.construction_request=request
  p.standard_fluid_route_plan_0691={id="native-steam",state="construction-requested",fluid="water",machine=boiler}
  local source={valid=true,get_item_count=function()return 10 end}
  p.construction_task_0338={phase="move-source",item_name="pipe",request_field="construction_request",
    request_value=request,source_inv=source,position={x=2,y=1}}
  local assembler={valid=true,type="assembling-machine",name="assembling-machine-1",unit_number=70,
    force=p.station.force,surface=p.station.surface,energy=0,position={x=3,y=0},get_recipe=function()return{name="lab"}end}
  storage.tech_priests.emergency_facility_doctrine_0343={by_station={[11]={[70]=true}},
    facilities={[70]={entity=assembler,role="assembler",station_unit=11}}}
  local old=TechPriestsStorageRoleAuthority0686
  TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)return item=="pipe"and 10 or 0 end}
  check(Arbiter.action(p).kind=="construction","fully fed but unpowered lab recipe starved its steam pipe")
  local recipe=p.emergency_craft;Dispatcher.service_pair(p,"native-power-prerequisite")
  check(counts.construction==1 and counts.craft==0 and p.emergency_craft==recipe,
    "power prerequisite dropped or executed the blocked parent recipe")
  assembler.energy=1
  check(Arbiter.action(p).kind=="crafting","powered recipe yielded to an unnecessary construction exception")
  assembler.energy=0;p.standard_fluid_route_plan_0691.id="another-route"
  check(Arbiter.action(p).kind=="crafting","unrelated fluid route displaced strict production")
  p.standard_fluid_route_plan_0691.id="native-steam";boiler.force={}
  check(Arbiter.action(p).kind=="crafting","foreign steam machinery gained production priority")
  TechPriestsStorageRoleAuthority0686=old
end)
test("missing native workshop admits its exact paid bootstrap machine",function()
  local p=make_pair();p.mode="idle";p.radius=40
  local recipe={output_item="lab",facility_only_0647=true,strict_recipe_0647=true,infrastructure_first_0640=true}
  p.emergency_craft=recipe;p.dispatcher_emergency_production_0514={phase="need-machine",tick=game.tick}
  local ghost={valid=true,name="entity-ghost",ghost_name="assembling-machine-1",
    force=p.station.force,surface=p.station.surface}
  local req={item="assembling-machine-1",entity_name="assembling-machine-1",ghost=ghost}
  p.construction_bootstrap_ghost_0645=req
  p.construction_task_0338={phase="move-source",item_name="assembling-machine-1",entity_name="assembling-machine-1",
    request_field="construction_bootstrap_ghost_0645",request_value=req,ghost=ghost,
    source_inv={valid=true,get_item_count=function()return 1 end},position={x=3,y=0}}
  local old=TechPriestsStorageRoleAuthority0686
  TechPriestsStorageRoleAuthority0686={generic_item_count=function()return 1 end}
  check(Arbiter.action(p).kind=="construction","missing native workshop never received its stocked constructor")
  Dispatcher.service_pair(p,"build-original-workshop")
  check(counts.construction==1 and p.emergency_craft==recipe,"workshop bootstrap lost the original recipe")
  p.dispatcher_emergency_production_0514.tick=game.tick-1000
  check(Arbiter.action(p).kind=="crafting","stale machine refusal authorized new construction priority")
  p.dispatcher_emergency_production_0514.tick=game.tick;ghost.force={}
  check(Arbiter.action(p).kind=="crafting","foreign workshop ghost gained the production owner's priority")
  ghost.force=p.station.force;p.emergency_facility_feed_custody_0357={count=2}
  check(Arbiter.action(p).kind=="crafting","held native input custody was displaced by workshop planning")
  TechPriestsStorageRoleAuthority0686=old
end)
print("[strict-craft-dispatch] PASS scenarios="..total)
