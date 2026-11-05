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
assert(src:find(first,1,true) and src:find(second,1,true),
 "native fluid and pipe services not loaded by the actual control entrypoint")
assert(src:find("NativeFluid0689.install()==true",1,true)
 and src:find("NativePipe0691.install()==true",1,true),
 "native fluid broker registration failures were hidden instead of refusing startup")
assert(src:find(first,1,true)<src:find(second,1,true),
 "pipe coordinator loaded before dry-fluid inspection authority")

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
assert(Doctrine.install()==true and Planner.install()==true,
 "physical native fluid services could not register in existing broker")
local a=services.fluid_network_doctrine_0689
local b=services.standard_fluid_route_discovery_0691
assert(a and b and a.name~=b.name
 and type(a.fn)=="function" and type(b.fn)=="function"
 and _G.TechPriestsFluidNetworkDoctrine0689==Doctrine
 and _G.TechPriestsFluidConnectionPlanner0691==Planner
 and installed_count==2,
 "missing distinct registered scan and real-pipe planning authority")
-- The canonical broker replaces by name rather than duplicating service
-- ownership on re-install. Stubs also prove both names remain stable.
assert(Doctrine.install()==true and Planner.install()==true
 and services[a.name] and services[a.name].name==a.name
 and services[b.name] and services[b.name].name==b.name
 and installed_count==4,
 "reinstallation failed to preserve distinct native fluid service names")
print("[physical-fluid-service-registration-1259] PASS explicit control startup installation, ordered dry-fluid and physical pipe broker registration, stable service ownership")
