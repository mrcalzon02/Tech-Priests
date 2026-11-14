package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1,fuel=1,crafter_input=3,crafter_output=4}}
prototypes={item={coal={},["iron-plate"]={}}}
local empty={valid=true,get_contents=function()return {}end,get_item_count=function()return 0 end}
local force,surface={index=1},{index=1}
local station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface}
local pair={station=station,priest={valid=true,unit_number=2,position={x=0,y=0},force=force,surface=surface}}
storage={tech_priests={pairs_by_station={[1]=pair}}}
local receiver={valid=true,unit_number=3,name="wooden-chest",type="container",position={x=4,y=0},force=force,surface=surface,
 get_inventory=function(id)assert(id==1);return empty end}
local drill={valid=true,unit_number=4,name="electric-mining-drill",type="mining-drill",position={x=3,y=0},force=force,surface=surface,drop_target=receiver,
 get_inventory=function()return nil end,get_fuel_inventory=function()return nil end}
local machine={valid=true,unit_number=5,name="assembling-machine-1",type="assembling-machine",position={x=5,y=0},force=force,surface=surface,
 get_inventory=function(id)if id==1 then error("electric machine fuel enum read")end;return empty end,
 get_fuel_inventory=function()return nil end,
 get_recipe=function()return {name="iron-gear-wheel",ingredients={{name="iron-plate",amount=2,type="item"}}}end}
surface.find_entities_filtered=function(spec)
 if spec.limit==64 then return {}end
 return {receiver,drill,machine}
end
TechPriestsStorageRoleAuthority0686={generic_item_count=function()return 20 end}
local discover
TechPriestsRuntimeTickBroker0600={register_service=function(s)discover=s.fn;return true end}
local M=require("scripts.core.logistics_machine_fulfillment_0528");assert(M.install());discover(nil,1)
local c=pair.machine_logistics_candidate_0528
assert(c and c.machine==machine and c.action=="supply-ingredient"and c.item=="iron-plate",
 "native chest/fuel inventory alias starved real recipe ingredient delivery")
print("PASS receiver chest excluded from burner service and electric native fuel nil respected")
local custody={item="coal",count=3,kind="supply"}
pair.machine_logistics_0528={phase="move-to-machine",action="supply-fuel",machine=receiver,item="coal",custody=custody}
pair.machine_logistics_custody_0528=custody
pair.priest.position={x=4,y=0}
M.service_pair(pair,"old-save-fuel-alias")
assert(pair.machine_logistics_0528.phase=="return-custody-to-station"and custody.count==3,
 "legacy false fuel target stranded or deleted carried coal")
local refunded=0
TechPriestsStorageRoleAuthority0686.deposit_exact=function(_,item,n)
 assert(item=="coal");refunded=refunded+n;return true,"deposited",n
end
pair.priest.position={x=0,y=0};M.service_pair(pair,"old-save-return")
assert(refunded==3 and pair.machine_logistics_0528.phase=="failed"and pair.machine_logistics_custody_0528==nil,
 "legacy false fuel cargo did not return exactly")
print("PASS prior-save false fuel duty releases only after exact physical coal restitution")
