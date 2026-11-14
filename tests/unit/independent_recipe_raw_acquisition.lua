package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
package.loaded["scripts.core.direct_acquisition_executor_0513"]={service_pair=function()return false end}
local Raw=require("scripts.core.bootstrap_resource_governor_0637")
game={tick=1000};defines={inventory={chest=1}}
local force={name="tp-arena-3"}
local resource={valid=true,name="stone",type="resource",amount=100,
  position={x=10,y=0}}
local surface={find_entities_filtered=function(opts)
  assert(opts.name==resource.name and opts.radius==40)
  return {resource}
end}
local function fixture()
  storage={tech_priests={pairs_by_station={}}}
  local inv={valid=true,get_item_count=function()return 0 end}
  local pair={station={valid=true,unit_number=1,force=force,surface=surface,
      position={x=0,y=0},get_inventory=function()return inv end},
    priest={valid=true,unit_number=2},radius=40,
    independent_emergency_operation_0184={enabled=true,phase="survival-ammo"},
    infrastructure_recipe_request_0647={item="stone-furnace",missing="stone",
      ingredients={{name="stone",count=5}}}}
  storage.tech_priests.pairs_by_station[1]=pair
  return pair
end
local pair=fixture()
assert(Raw.root().enabled==false,"generic reserve policy changed")
local acted,why=Raw.service_pair(pair,"independent-recipe-test")
assert(acted,tostring(why))
assert(pair.direct_acquisition_task_0336.required_count==5)
assert(pair.direct_acquisition_task_0336.current.entity==resource)
assert(pair.infrastructure_recipe_request_0647.item=="stone-furnace")
assert(resource.amount==100,"planner fabricated mined stock")
for _,field in ipairs({"combat_target","construction_task_0338",
    "direct_acquisition_custody_0513","machine_logistics_custody_0528",
    "emergency_production_custody_0514","station_crafting_task_0337"}) do
  pair=fixture();pair[field]={valid=true}
  acted=Raw.service_pair(pair)
  assert(not acted and pair.direct_acquisition_task_0336==nil,field.." was preempted")
end
pair=fixture();pair.independent_emergency_operation_0184=nil
assert(not Raw.service_pair(pair) and pair.emergency_craft==nil,"maintenance force began factory work")
pair=fixture();pair.infrastructure_recipe_request_0647=nil
assert(not Raw.service_pair(pair),"independent mode began generic reserve sweep")
pair=fixture();Raw.root().recipe_acquisition_disabled=true
assert(not Raw.service_pair(pair),"explicit off ignored")
pair=fixture();pair.order_queue_0469={current={status="active"}}
assert(not Raw.service_pair(pair),"active player order preempted")
pair=fixture();TechPriestsResourceReturnCourier0837={worker_reserved=function()return true end}
assert(not Raw.service_pair(pair),"physical ore courier reservation preempted")
TechPriestsResourceReturnCourier0837=nil
pair=fixture();pair.infrastructure_recipe_request_0647=nil
resource.name="coal"
local boiler={valid=true,force=force,surface=surface}
pair.energy_family_logistics_0707={family="energy-fuel",phase="waiting-source",
 target=boiler,item="coal",count=2}
TechPriestsEnergyFamilyReadiness0705={inspect_entity=function(p,target)
 assert(p==pair and target==boiler);return {state="fuel-service-eligible"}end}
assert(Raw.service_pair(pair) and pair.direct_acquisition_task_0336.required_count==2,
 "canonical missing energy fuel never reached real raw acquisition")
assert(pair.energy_family_logistics_0707.phase=="waiting-source" and resource.amount==100)
pair=fixture();pair.infrastructure_recipe_request_0647=nil
pair.energy_family_logistics_0707={family="energy-fuel",phase="waiting-source",
 target={valid=true,force={},surface=surface},item="coal",count=2}
assert(not Raw.service_pair(pair),"foreign energy machine authorized raw work")
TechPriestsEnergyFamilyReadiness0705=nil
resource.name="stone"
pair=fixture();pair.infrastructure_recipe_request_0647=nil
defines.inventory.crafter_input=33;defines.inventory.crafter_output=34
local strict={item_name="stone-brick",output_item="stone-brick",strict_recipe_0647=true,
 facility_only_0647=true,infrastructure_first_0640=true,target_stock_0647=5,
 strict_recipe_ingredients_0647={{name="stone",count=2}}}
pair.emergency_craft=strict
local furnace={valid=true,type="furnace",force=force,surface=surface,crafting_progress=.5,
 get_recipe=function()return {name="stone-brick"}end,
 get_inventory=function(id)return {valid=true,get_item_count=function(name)
  if id==33 and name=="stone"then return 2 end
  if id==34 and name=="stone-brick"then return 1 end
  return 0
 end}end}
storage.tech_priests.emergency_facility_doctrine_0343={by_station={[1]={[10]=true}},facilities={[10]={role="smelter",entity=furnace}}}
assert(Raw.service_pair(pair),"blocked strict native brick batch could not acquire remaining real stone")
local material=pair.direct_acquisition_task_0336
assert(pair.emergency_craft==strict and material.material_for_strict_recipe_0637==true
 and material.required_count==4 and resource.amount==100,
 "strict material acquisition lost its parent or ignored real in-flight furnace stock")
assert(not Raw.service_pair(pair)and pair.direct_acquisition_task_0336==material,
 "existing material acquisition was overwritten")
print("PASS strict native smelting replenishment counts actual furnace inputs, completed output and active craft")
-- A bounded service must eventually visit every force/station, including
-- stations after the first twelve in a large four-way factory population.
fixture()
local original=Raw.service_pair;local seen={}
Raw.service_pair=function(p)seen[p.station.unit_number]=true;return false end
for i=1,30 do
  storage.tech_priests.pairs_by_station[i]={station={valid=true,unit_number=i},priest={valid=true}}
end
for _=1,3 do assert(Raw.service_all("fairness")==12)end
for i=1,30 do assert(seen[i],"station starved: "..i)end
Raw.service_pair=original
print("PASS independent raw recipe leaf, maintenance isolation, custody priority and 30-station fairness")
