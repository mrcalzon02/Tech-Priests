-- Bounded dense scans must enumerate when possible and fail closed otherwise.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local M = require("scripts.core.catalog_dense_scan_1478")
local function entity(id, x, y)
  return {unit_number=id, name="steel-chest",valid=true,position={x=x,y=y}}
end
local function surface(entities)
  local n=0
  return {find_entities_filtered=function(options)
    n=n+1
    local a,b=options.area[1],options.area[2]
    local out={}
    for _,e in ipairs(entities) do
      if e.position.x>=a[1] and e.position.x<b[1]
        and e.position.y>=a[2] and e.position.y<b[2] then
        out[#out+1]=e
        if #out>=options.limit then break end
      end
    end
    return out
  end, calls=function() return n end}
end
local area={{0,0},{64,64}}
local quiet={}
for i=1,500 do quiet[i]=entity(i,i%60+0.2,math.floor(i/60)+0.3) end
local q=surface(quiet)
local got,meta=M.scan(q,area,{limit=768})
assert(meta.complete and #got==500 and meta.queries==1 and q.calls()==1,
  "ordinary uncapped scan changed")
local crowd={}
for i=1,1100 do crowd[i]=entity(i,((i-1)%33)*1.7+0.1,math.floor((i-1)/33)*1.7+0.1) end
local c=surface(crowd)
local all,info=M.scan(c,area,{limit=768})
assert(info.complete and #all==1100 and info.queries==5 and info.splits==1,
  "dense 1,100-entity station area was not fully enumerated")
local unique={}
for _,e in ipairs(all) do assert(not unique[e.unit_number],"duplicate entity returned") unique[e.unit_number]=true end
local exact={}
for i=1,768 do exact[i]=entity(i,i%55+0.1,math.floor(i/55)+0.2) end
local e,em=M.scan(surface(exact),area,{limit=768})
assert(em.complete and #e==768 and em.queries==5,
  "exact-limit result was assumed complete or lost")
local tightly={}
for i=1,2400 do tightly[i]=entity(i,1+(i%13)*0.001,2+(i%19)*0.001) end
local many,m=M.scan(surface(tightly),area,{limit=768})
assert(not m.complete and m.truncated_leaves>=1 and m.queries<=13 and #many>=768,
  "unresolvable dense region falsely reported complete")
local low,lm=M.scan(surface(crowd),area,{limit=768,max_queries=1})
assert(not lm.complete and lm.budget_exhausted and lm.queries==1,
  "query budget exceeded or hidden truncation")
local capped,cm=M.scan(surface(quiet),area,{limit=768,max_entities=200})
assert(not cm.complete and cm.reason=="entity-budget" and #capped==200,
  "total results cap not enforced")
local neg={}
for i=1,800 do neg[i]=entity(i,-60+(i%45),-60+math.floor(i/45)) end
local ng,nm=M.scan(surface(neg),{{-64,-64},{0,0}},{limit=768})
assert(nm.complete and #ng==800,"negative coordinates lost entities")
local failures={find_entities_filtered=function() error("forced-failure") end}
local empty,err=M.scan(failures,area,{limit=768})
assert(not empty and not err.complete and err.reason=="surface-query-failed",
  "engine query failure was concealed")
-- Deterministic stress across both sides of the native query limit.
for _,population in ipairs({1,767,768,769,1500,2000,3000,5000}) do
  local samples={}
  for i=1,population do
    samples[i]=entity(i,((i*37)%6398)/100+0.01,
      ((i*71)%6398)/100+0.01)
  end
  local scanned,check=M.scan(surface(samples),area,{limit=768})
  assert(scanned and check.queries<=13 and #scanned<=3072,
    "population scan exceeded a resource budget")
  local got={}
  for _,item in ipairs(scanned) do
    assert(not got[item.unit_number],"population scan duplicated an entity")
    got[item.unit_number]=true
  end
  if check.complete then
    assert(#scanned==population,
      "complete population scan failed to enumerate the world")
  end
end
-- Two resources without unit_number share the catalog's quantized fallback key.
-- They are physically distinct and must not be merged by dense deduplication.
local a={valid=true,name="stone",type="simple-entity",position={x=10.011,y=11.02}}
local b={valid=true,name="stone",type="simple-entity",position={x=10.019,y=11.02}}
local collision,proof=M.scan(surface({a,b}),area,{
  limit=768,key_of=function(e)
    return e.name..":"..math.floor(e.position.x*10)..":"..math.floor(e.position.y*10)
  end})
assert(not proof.complete and proof.reason=="identity-collision"
  and #collision==2 and collision[1]~=collision[2]
  and proof.identity_collisions==1,
  "a fallback key collision must not silently drop or certify distinct entities")
-- The replacement identity helper distinguishes their actual positions.
local Identity=require("scripts.core.entity_identity_1481")
local precise,exact=M.scan(surface({a,b}),area,{limit=768,key_of=Identity.key})
assert(exact.complete and #precise==2 and exact.identity_collisions==0,
  "precise keys failed to preserve both real resources")
print("[catalog-dense-scan-1478] PASS: 500/768/800/1100/2400, budgets and failures")
