package.path="tech-priests_src/?.lua;"..package.path
game={tick=100};defines={build_check_type={manual=1},inventory={chest=1}}
local M=require("scripts.core.factory_output_links_1282")
local force,surface={},{}
local stock={inserter=2,["wooden-chest"]=2}
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)return stock[item]or 0 end}
local recipe={name="iron-gear-wheel"}
local machine={valid=true,unit_number=3,type="assembling-machine",name="assembling-machine-1",
 force=force,surface=surface,position={x=5,y=0},get_recipe=function()return recipe end}
local p={station={valid=true,unit_number=1,force=force,surface=surface,position={x=0,y=0}},
 priest={valid=true},radius=40,independent_emergency_operation_0184={enabled=true}}
local plan={factory_component_jobs_1150={[recipe.name]={researched=true,output_item=recipe.name}}}
storage={tech_priests={emergency_facility_doctrine_0343={by_station={[1]={[3]=true}},
 facilities={[3]={station_unit=1,role="assembler",entity=machine}}}}}
local linked={}
surface.find_entities_filtered=function()return linked end
surface.can_place_entity=function()return true end
surface.create_entity=function()error("coordinator must never create entities")end
local function receipt()
 local req=p.construction_requested_item
 assert(req and req.source=="factory-output-links-1282")
 local e={valid=true,unit_number=10,name=req.entity_name,force=force,surface=surface,
  position=req.position,type=req.entity_name=="inserter"and"inserter"or"container",energy=100}
 if e.type=="inserter"then e.pickup_target=machine;e.drop_target=p.factory_output_link_plan_1282.chest
 else e.get_inventory=function()return{valid=true,get_insertable_count=function()return 100 end}end end
 p.construction_last_task_0338={phase="complete",request_value=req,built_entity=e}
 p.construction_requested_item=nil
 return e
end
p.independent_emergency_operation_0184.enabled=false
assert(not M.service(p,plan)and not p.construction_requested_item)
p.independent_emergency_operation_0184.enabled=true
p.machine_logistics_0528={custody={count=1}}
assert(not M.service(p,plan));p.machine_logistics_0528=nil
stock.inserter=0;assert(not M.service(p,plan));stock.inserter=2
local foreign={item_name="lab"};p.construction_requested_item=foreign
assert(not M.service(p,plan)and p.construction_requested_item==foreign)
p.construction_requested_item=nil
assert(M.service(p,plan))
local req=p.construction_requested_item
assert(req.item_name=="wooden-chest"and req.position.x==5.5 and req.position.y==3.5)
assert(M.service(p,plan)and p.construction_requested_item==req,"duplicate request replaced original")
local chest=receipt()
p.factory_output_link_plan_1282.receipt=p.construction_last_task_0338
p.construction_last_task_0338={phase="complete",built_entity=machine}
assert(M.service(p,plan),"later unrelated terminal slot replaced the exact paid receipt")
req=p.construction_requested_item
assert(req.item_name=="inserter"and req.direction==0 and req.position.y==2.5)
local arm=receipt();assert(M.service(p,plan))
assert(M.owns_output_inserter(p,arm,machine)and M.output_automated(p,machine))
assert(stock.inserter==2 and stock["wooden-chest"]==2,"coordinator debited stock")
local inventory=chest.get_inventory;chest.get_inventory=function()
 return{valid=true,get_insertable_count=function()return 0 end}end
assert(not M.output_automated(p,machine),"full output chest blocked fallback manual collection")
chest.get_inventory=inventory
arm.energy=0;assert(not M.output_automated(p,machine))
assert(M.owns_output_inserter(p,arm,machine),"unpowered arm must not block manual input")
arm.energy=100;arm.drop_target=machine
assert(not M.owns_output_inserter(p,arm,machine)and not M.output_automated(p,machine))
arm.drop_target=chest;recipe={name="copper-cable"}
assert(not M.owns_output_inserter(p,arm,machine),"changed player recipe inherited ownership")
recipe={name="iron-gear-wheel"};linked={arm}
assert(not M.service(p,plan),"existing native connection was duplicated")
p.independent_emergency_operation_0184.enabled=false
assert(not M.output_automated(p,machine)and not M.owns_output_inserter(p,arm,machine))
-- A native target mismatch never becomes an automation receipt.
p.independent_emergency_operation_0184.enabled=true;linked={};p.factory_output_links_1282=nil
assert(M.service(p,plan));receipt();assert(M.service(p,plan));arm=receipt();arm.drop_target=machine
assert(not M.service(p,plan)and not p.factory_output_links_1282)
assert(p.factory_output_link_failure_1282.reason=="native-pickup-drop-targets-disconnected")
storage.tech_priests.emergency_facility_doctrine_0343.by_station[1]={}
p.factory_output_link_refusals_1282=nil
p.factory_component_last_receipt_1150={configured=true,station_unit=2,
 entity_unit=3,built_entity=machine,recipe="iron-gear-wheel"}
assert(not M.service(p,plan),"another station's recipe receipt granted ownership")
p.factory_component_last_receipt_1150.station_unit=1
assert(M.service(p,plan),"exact paid dedicated recipe machine lacked output automation")
p.factory_output_link_plan_1282=nil;p.construction_requested_item=nil
p.factory_component_receipts_1282={[3]=p.factory_component_last_receipt_1150}
p.factory_component_last_receipt_1150=nil
assert(M.service(p,plan),"earlier preserved paid recipe receipt was ignored")
print("PASS paid original-builder output links, native targets, custody, recipe and maintenance isolation")
