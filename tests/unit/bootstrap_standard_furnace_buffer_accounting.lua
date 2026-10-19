-- Lua 5.2: normal furnaces, not only emergency smelters, hold actual
-- bootstrap ore and coal; the acquisition governor must count that inventory.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={}}
defines={inventory={chest=1,fuel=2,furnace_source=3}}
prototypes={item={["iron-ore"]={},["coal"]={},["copper-ore"]={}}}
local station_items={}
local furnace_items={fuel={coal=2},source={["iron-ore"]=4}}
local function inv(items)
  return {valid=true,get_item_count=function(name)return items[name] or 0 end}
end
local station_inv=inv(station_items)
local fuel_inv=inv(furnace_items.fuel)
local ore_inv=inv(furnace_items.source)
local surface={index=1}
local force={index=1}
local furnace={valid=true,name="stone-furnace",type="furnace",
  unit_number=25,position={x=2,y=0},force=force,surface=surface}
furnace.get_inventory=function(id)
  if id==defines.inventory.fuel then return fuel_inv end
  if id==defines.inventory.furnace_source then return ore_inv end
end
local resources={}
for i,name in ipairs({"coal","iron-ore","copper-ore"})do
  resources[name]={valid=true,name=name,type="resource",amount=100,
    position={x=i*3+2,y=3}}
end
surface.find_entities_filtered=function(opts)
  if opts.type=="resource" and opts.name then
    return {resources[opts.name]}
  end
  if type(opts.type)=="table" then return {furnace} end
  return {}
end
local station={valid=true,name="junior-cogitator-station",unit_number=10,
  position={x=0,y=0},surface=surface,force=force,
  get_inventory=function(id)
    if id==defines.inventory.chest then return station_inv end
  end}
local pair={station=station,priest={valid=true,unit_number=11},
  station_unit=10,mode="infrastructure-first-0643",radius=24,
  emergency_craft={output_item="iron-plate",facility_only_0647=true},
  local_infrastructure_gate_0640={
    item="iron-plate",state="waiting-recipe-material"}}
storage.tech_priests.pairs_by_station={[10]=pair}
package.loaded["scripts.core.direct_acquisition_executor_0513"]={
  service_pair=function()return true end
}
local Governor=require("scripts.core.bootstrap_resource_governor_0637")
Governor.root().enabled=true
local function check(ok,why)
  if not ok then error("standard-furnace-buffer regression: "..why,2) end
end
local enough,why=Governor.service_pair(pair,"standard-furnace-has-ore-and-fuel")
check(enough==false and why=="infrastructure-prerequisite-priority"
  and not pair.direct_acquisition_task_0336,
  "physical furnace fuel and ore were mistaken for absent inputs")
check(pair.emergency_craft.facility_only_0647==true,
  "furnace stock inspection retired an active iron-plate production task")

furnace_items.fuel.coal=0
local coal=Governor.service_pair(pair,"missing-real-fuel")
check(coal==true and pair.direct_acquisition_task_0336
  and pair.direct_acquisition_task_0336.output_item=="coal",
  "genuinely missing furnace coal was not physically requested")
pair.direct_acquisition_task_0336=nil
pair.mode="infrastructure-first-0643"
furnace_items.fuel.coal=2
furnace_items.source["iron-ore"]=0
local ore=Governor.service_pair(pair,"missing-real-ore")
check(ore==true and pair.direct_acquisition_task_0336
  and pair.direct_acquisition_task_0336.output_item=="iron-ore",
  "genuinely missing furnace ore was not physically requested")
check(pair.emergency_craft.facility_only_0647==true,
  "acquisition of real furnace inputs erased parent plate production")
-- A completed physical workshop must request its first copper batch even
-- when no other task or infrastructure gate currently makes the priest
-- "emergencyish". An old survey cannot authorize the request.
pair.direct_acquisition_task_0336=nil
pair.emergency_craft=nil
pair.local_infrastructure_gate_0640=nil
pair.mode="idle"
pair.master_infrastructure_plan_0644={
  tick=game.tick,roles={["emergency-assembler"]=1}
}
local copper=Governor.service_pair(pair,"idle-workshop-needs-first-copper")
check(copper==true and pair.direct_acquisition_task_0336
  and pair.direct_acquisition_task_0336.output_item=="copper-ore",
  "idle physical workshop did not begin its first real copper acquisition")
-- Simulate the physical direct executor's completed/deposited transaction:
-- it retires both compatibility aliases for the same acquisition task.
check(pair.emergency_craft==pair.direct_acquisition_task_0336,
  "test setup lost the physical acquisition's compatibility alias")
pair.direct_acquisition_task_0336=nil
pair.emergency_craft=nil
pair.mode="idle"
pair.master_infrastructure_plan_0644.tick=game.tick-1000
local stale,why=Governor.service_pair(pair,"stale-snapshot-fails-closed")
check(stale==false and why=="not-emergencyish"
  and pair.direct_acquisition_task_0336==nil,
  "outdated workshop survey triggered unsolicited resource mining")
print("[standard-furnace-buffer-regression] PASS scenarios=5")
