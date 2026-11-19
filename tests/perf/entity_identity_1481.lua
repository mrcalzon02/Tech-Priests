-- Diagnostic only: 1/256 fixed-point entity keys versus long float formatting.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Identity=require("scripts.core.entity_identity_1481")
local entities={}
local surface,force={index=1},{index=2}
for i=1,1000 do
  entities[i]={valid=true,name="iron-ore",type="resource",surface=surface,
    force=force,position={x=(i%50)+0.00390625,y=math.floor(i/50)+0.00390625}}
end
local function previous_precise(e)
  local p=e.position
  local name,kind=tostring(e.name or e.type or "?"),tostring(e.type or "?")
  return "p:"..tostring(e.surface.index)..":"..tostring(e.force.index)
    ..":"..tostring(#name)..":"..name..":"..tostring(#kind)..":"..kind
    ..":"..string.format("%.17g",p.x)..":"..string.format("%.17g",p.y)
end
local function measure(label,func)
  local begin=os.clock()
  local sink
  for pass=1,100 do
    for i=1,#entities do sink=func(entities[i]) end
  end
  local elapsed=(os.clock()-begin)*1000
  print(string.format("[entity-identity-1481-perf] %s 100000 keys %.3f ms",label,elapsed))
  return elapsed
end
local old=measure("float-format",previous_precise)
local new=measure("fixed-point",Identity.key)
print(string.format("[entity-identity-1481-perf] observed ratio %.2fx (diagnostic)",old/new))
