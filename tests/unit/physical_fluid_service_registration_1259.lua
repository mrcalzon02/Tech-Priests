-- 1259: the real control entrypoint must install the 0689 and 0691
-- broker services. Unit fixtures loading a module are not runtime wiring.
-- This standalone test uses only source inspection and a read-only broker
-- double: it never creates fluids, pipes, construction tasks or Factorio items.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path

local file=assert(io.open("tech-priests_src/control.lua","r"),
 "missing actual Factorio control entrypoint")
local src=file:read("*a")
file:close()
local first='local NativeFluid0689=require("scripts.core.fluid_network_doctrine_0689")'
local second='local NativePipe0691=require("scripts.core.fluid_connection_planner_0691")'
local third='local NativeEnergy0705=require("scripts.core.energy_family_readiness_0705")'
local fourth='local NativeFuel0707=require("scripts.core.energy_family_logistics_0707")'
assert(src:find(first,1,true) and src:find(second,1,true)
 and src:find(third,1,true) and src:find(fourth,1,true),
 "native steam fluid, pipe and burner/fuel services not loaded by control")
assert(src:find("NativeFluid0689.install()==true",1,true)
 and src:find("NativePipe0691.install()==true",1,true)
 and src:find("NativeEnergy0705.install()==true",1,true)
 and src:find("NativeFuel0707.install()==true",1,true),
 "native fluid broker registration failures were hidden instead of refusing startup")
assert(src:find(first,1,true)<src:find(second,1,true)
 and src:find(second,1,true)<src:find(third,1,true)
 and src:find(third,1,true)<src:find(fourth,1,true),
 "native steam services installed in an unsafe dependency order")

storage={tech_priests={}}
game={tick=0}
local services={}
local installed_count=0
_G.TechPriestsRuntimeTickBroker0600={
 install=function()installed_count=installed_count+1;return true end,
 register_service=function(spec)
  assert(type(spec)=="table" and type(spec.name)=="string"
   and type(spec.fn)=="function" and tonumber(spec.interval)>0
   and tonumber(spec.budget)>0, "invalid broker service spec")
  services[spec.name]=spec
  return spec
 end,
}
local Doctrine=require("scripts.core.fluid_network_doctrine_0689")
local Planner=require("scripts.core.fluid_connection_planner_0691")
local Readiness=require("scripts.core.energy_family_readiness_0705")
local Fuel=require("scripts.core.energy_family_logistics_0707")
assert(Doctrine.install()==true and Planner.install()==true
 and Readiness.install()==true and Fuel.install()==true,
 "physical native fluid services could not register in existing broker")
local a=services.fluid_network_doctrine_0689
local b=services.standard_fluid_route_discovery_0691
local e=services.energy_family_readiness_0705
local f=services.energy_family_discovery_0707
assert(a and b and e and f
 and a.name~=b.name and b.name~=e.name and e.name~=f.name
 and type(a.fn)=="function" and type(b.fn)=="function"
 and type(e.fn)=="function" and type(f.fn)=="function"
 and _G.TechPriestsFluidNetworkDoctrine0689==Doctrine
 and _G.TechPriestsFluidConnectionPlanner0691==Planner
 and _G.TechPriestsEnergyFamilyReadiness0705==Readiness
 and _G.TechPriestsEnergyFamilyLogistics0707==Fuel
 and installed_count==2,
 "missing distinct registered scan and real-pipe planning authority")
-- The canonical broker replaces by name rather than duplicating service
-- ownership on re-install. Stubs also prove both names remain stable.
assert(Doctrine.install()==true and Planner.install()==true
 and Readiness.install()==true and Fuel.install()==true
 and services[a.name] and services[a.name].name==a.name
 and services[b.name] and services[b.name].name==b.name
 and services[e.name] and services[e.name].name==e.name
 and services[f.name] and services[f.name].name==f.name
 and installed_count==4,
 "reinstallation failed to preserve distinct native fluid service names")
print("[physical-fluid-service-registration-1259] PASS explicit control startup installation, ordered fluid, pipe, boiler readiness and counted fuel broker registration, stable service ownership")
