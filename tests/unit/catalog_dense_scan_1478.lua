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
print("[catalog-dense-scan-1478] PASS: 500/768/800/1100/2400, budgets and failures")
