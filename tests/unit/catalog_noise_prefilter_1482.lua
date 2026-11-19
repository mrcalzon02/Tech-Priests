-- Regression 1482: irrelevant belts must not saturate station Auspex reads.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Scanner=require("scripts.core.catalog_dense_scan_1478")
local ignored={"transport-belt","underground-belt","splitter","loader","loader-1x1","linked-belt","character","player"}
local excluded={};for _,t in ipairs(ignored)do excluded[t]=true end
local area={{0,0},{64,64}}
local entities={}
local function entity(id,kind,x,y)
 return {valid=true,unit_number=id,type=kind,name=kind,
   position={x=x,y=y}}
end
for i=1,2400 do
 entities[#entities+1]=entity(i,"transport-belt",(i%50)+0.1,math.floor(i/50)+0.1)
end
for i=1,500 do
 entities[#entities+1]=entity(3000+i,"assembling-machine",(i%50)+0.1,math.floor(i/50)+0.1)
end
local calls=0
local function surface(reject_filter)
 return {find_entities_filtered=function(filter)
  calls=calls+1
  if reject_filter and filter.invert then error("unsupported inverted filter") end
  local aa,bb=filter.area[1],filter.area[2]
  local results={}
  for _,e in ipairs(entities)do
   local x,y=e.position.x,e.position.y
   if x>=aa[1]and x<bb[1]and y>=aa[2]and y<bb[2]
     and(not filter.invert or not excluded[e.type])then
    results[#results+1]=e
    if #results>=filter.limit then break end
   end
  end
  return results
 end}
end
local a,ai=Scanner.scan(surface(false),area,{limit=768,exclude_types=ignored})
assert(ai.complete and ai.queries==1 and ai.filtered_queries==1
 and ai.prefilter_fallbacks==0 and #a==500 and calls==1,
 "irrelevant belts triggered dense queries or lost real machines")
-- The same query without a native prefilter remains bounded but incomplete.
calls=0
local b,bi=Scanner.scan(surface(false),area,{limit=768})
assert(bi.complete and bi.queries>1 and bi.queries<=13 and bi.filtered_queries==0,
 "unfiltered baseline did not require additional subdivision")
-- On an older/incompatible query API, immediately retry unfiltered.
calls=0
local c,ci=Scanner.scan(surface(true),area,{limit=768,exclude_types=ignored})
assert(ci.prefilter_fallbacks==1 and ci.queries==bi.queries+1,
 "incompatible filter did not retry while respecting query budget")
assert(c and ci.complete and #c==2900,
 "unfiltered fallback incorrectly claimed full coverage")
-- One-call budget cannot afford fallback; fail closed and never exceed it.
calls=0
local d,di=Scanner.scan(surface(true),area,{limit=768,
 exclude_types=ignored,max_queries=1})
assert(d and #d==0 and not di.complete and di.budget_exhausted
 and di.queries==1 and calls==1 and di.reason=="prefilter-fallback-budget",
 "filter fallback exceeded one-query budget")
-- Filter-disabled is always the exact legacy query shape.
local last
local empty={find_entities_filtered=function(query)
 last=query
 return {}
end}
local result,info=Scanner.scan(empty,area,{limit=768})
assert(info.complete and #result==0 and last.type==nil and last.invert==nil,
 "default scanner changed query semantics")
print("[catalog-noise-prefilter-1482] PASS")
